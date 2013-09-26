--- Lua library for accessing the Twitter REST API v1.1
--
-- @module  luatwit
-- @license MIT
local assert, error, next, pairs, select, setmetatable, table_concat, tostring, type, unpack =
      assert, error, next, pairs, select, setmetatable, table.concat, tostring, type, unpack
local oauth = require "OAuth"
local json = require "cjson"
local util = require "luatwit.util"
local multipart = require("OAuth.helpers").multipart

local _M = {}

--- API resource data.
-- @see luatwit.resources
_M.resources = require "luatwit.resources"

--- API object definitions.
-- @see luatwit.objects
_M.objects = require "luatwit.objects"

--- JSON null value.
_M.null = json.null

--- Class prototype that implements the API calls.
-- Methods are created on demand from the definitions in the `resources` table.
-- @type api
_M.api = util.new()

local function build_args_str(rules)
    local res = {}
    for name, _ in pairs(rules) do
        res[#res + 1] = name
    end
    return table_concat(res, ", ")
end

local function build_required_str(rules)
    local res = {}
    for name, req in pairs(rules) do
        if req then
            res[#res + 1] = name
        end
    end
    return table_concat(res, ", ")
end

local scalar_types = { string = true, number = true, boolean = true }

-- Checks if the arguments in a table match the rules.
local function check_args(args, rules, res_name)
    if type(args) ~= "table" then
        return res_name .. ": arguments must be passed in a table"
    end
    if not rules then return nil end
    -- check for valid args (names starting with _ are ignored)
    for name, val in pairs(args) do
        if type(name) ~= "string" then
            return res_name .. ": keys must be strings"
        end
        local rule = rules[name]
        if rule == nil and name:sub(1, 1) ~= "_" then
            return res_name .. ": invalid argument '" .. name .. "' not in (" .. build_args_str(rules) .. ")"
        end
        local rule_type = type(rule)
        local allowed_type
        if rule_type == "boolean" then
            allowed_type = scalar_types
        elseif rule_type == "table" and #rule == 2 then
            allowed_type = {}
            allowed_type[rule[2]] = true
        else
            return res_name .. ": invalid rule for field '" .. name .. "'"
        end
        if not allowed_type[type(val)] then
            return res_name .. ": argument '" .. name .. "' must be of type (" .. build_args_str(allowed_type) .. ")"
        end
    end
    -- check if required args are present
    for name, rule in pairs(rules) do
        local required = rule
        if type(rule) == "table" then
            required = rule[1]
        end
        if required and args[name] == nil then
            return res_name .. ": missing required argument '" .. name .. "' in (" .. build_required_str(rules) .. ")"
        end
    end
    return nil
end

-- Builds the request url and arguments for the OAuth call.
local function build_request(decl, args, name, defaults)
    local method, url, rules = unpack(decl)
    local err = check_args(args, rules, name)
    assert(not err, err)
    local request = {}
    if defaults then
        util.map_copy(request, defaults)
    end
    util.map_copy(request, args, function(v, k)
        if k:sub(1, 1) ~= "_" then return v end
        return nil
    end)
    url = url:gsub(":([%w_]+)", function(key)
        local val = request[key]
        assert(val ~= nil, "invalid token ':" .. key .. "' in resource URL")
        request[key] = nil
        return val
    end)
    url = _M.resources._base_url .. url .. ".json"
    if decl._multipart then
        local mp = multipart.Request(request)
        return method, url, mp.body, mp.headers
    end
    return method, url, request
end

-- Applies type metatables to the supplied JSON data recursively.
--
-- @param node  Table with JSON data.
-- @param tname String with the name of an object defined in `objects`.
-- @return      The <tt>node</tt> argument after the processing is done.
function _M.api:apply_types(node, tname)
    local type_decl = self.objects[tname]
    assert(type(type_decl) == "table", "invalid object type")
    if type(node) == "table" then
        setmetatable(node, type_decl)
    end
    local st = type_decl._subtypes
    if st == nil then return node end
    local type_st = type(st)
    if type_st == "string" then
        for _, item in pairs(node) do
            self:apply_types(item, st)
        end
    elseif type_st == "table" then
        for k, tn in pairs(st) do
            local item = node[k]
            if item ~= nil and item ~= json.null then
                self:apply_types(item, tn)
            end
        end
    else
        error("subtype declaration must be string or table")
    end
    return node
end

--- Generic call to the Twitter API.
-- This is the backend method that performs all the API calls.
--
-- @param decl  API method declaration. This is taken from the `resources` table.
-- @param args  Table with the method arguments.
-- @param name  Method name. Used internally for building error messages.
-- @param defaults  Default method arguments.
-- @return      A table with the decoded JSON data from the response, or <tt>nil</tt> on error.
--              If the option <tt>_raw</tt> is set, instead returns an unprocessed JSON string.
-- @return      HTTP status line.
-- @return      HTTP result code.
-- @return      HTTP headers.
-- @return      If the option <tt>_raw</tt> is set, the type name from `resources`.
--              This value is needed to use the `api:parse_json` with the returned string.
function _M.api:raw_call(decl, args, name, defaults)
    assert(#decl >= 2, "invalid resource declaration")
    args = args or {}
    name = name or "raw_call"
    local method, url, request, req_headers = build_request(decl, args, name, defaults)
    local res_code, headers, status_line, body = self.oauth_client:PerformRequest(method, url, request, req_headers)
    self:apply_types(headers, "headers")
    local tname = decl[4]
    if args._raw then
        if type(body) ~= "string" then body = nil end
        return body, status_line, res_code, headers, tname
    end
    local json_data = type(body) == "string" and self:parse_json(body, tname) or nil
    if method == "GET" and type(json_data) == "table" and type(request) == "table" then
        json_data._source_method = function(_args)
            return self:raw_call(decl, _args, name, request)
        end
    end
    return json_data, status_line, res_code, headers
end

--- Parses a JSON string and applies type metatables.
--
-- @param str   JSON string.
-- @param tname Type name as defined in `resources`.
--              If set, the function will set type metatables.
-- @return      A table with the decoded JSON data.
function _M.api:parse_json(str, tname)
    local json_data = json.decode(str)
    if tname then
        if type(json_data) == "table" and json_data.errors then
            tname = "error"
        end
        if json_data then
            self:apply_types(json_data, tname)
        end
    end
    return json_data
end

--- Begins the OAuth authorization.
-- This method generates the URL that the user must visit to authorize the app and get the PIN needed for `api:confirm_login`.
--
-- @return      Authorization URL.
-- @return      HTTP Authorization header.
function _M.api:start_login()
    self.oauth_client:RequestToken{ oauth_callback = "oob" }
    return self.oauth_client:BuildAuthorizationUrl()
end

--- Finishes the OAuth authorization.
-- This method receives the PIN number obtained in the `api:start_login` step and authorizes the client to make API calls.
--
-- @param pin   PIN number obtained after the user succefully authorized the app.
-- @return      An `access_token` object.
-- @return      HTTP Status line.
-- @return      HTTP result code.
-- @return      HTTP headers.
function _M.api:confirm_login(pin)
    local token, res_code, headers, status_line = self.oauth_client:GetAccessToken{ oauth_verifier = tostring(pin) }
    return self:apply_types(token, "access_token"), status_line, res_code, headers
end

--- Constructs an `api` method from the declarations in `resources`.
--
-- @param key   Function name as defined in `luatwit.resources`.
-- @return      Function implementation.
function _M.api:__index(key)
    if key:sub(1, 1) == "_" then return nil end
    local decl = _M.resources[key]
    if not decl then return nil end
    local impl = util.make_functor(function(_self, parent, args)
        return parent:raw_call(decl, args, key, _self.defaults)
    end)
    impl._type = "api"
    impl.url = decl[2]
    if decl.default_args then
        local def = util.map_copy({}, decl.default_args, function(v, k)
            if decl[3][k] ~= nil then return v end
            return nil
        end)
        if next(def) ~= nil then
            impl.defaults = def
        end
    end
    self[key] = impl
    return impl
end

--- @section end

local oauth_key_args = {
    consumer_key = true,
    consumer_secret = true,
    oauth_token = false,
    oauth_token_secret = false,
}

--- Creates a new `api` object with the supplied keys.
-- An object created with only the consumer keys must call `api:start_login` and `api:confirm_login` to get the access token,
-- otherwise it won't be able to make API calls.
--
-- @param args  Table with the OAuth keys (consumer_key, consumer_secret, oauth_token, oauth_token_secret).
-- @return      New instance of the `api` class.
-- @see luatwit.objects.access_token
function _M.new(args)
    local err = check_args(args, oauth_key_args, "new")
    assert(not err, err)
    local self = util.new(_M.api)
    self.oauth_client = oauth.new(args.consumer_key, args.consumer_secret, _M.resources._endpoints, { OAuthToken = args.oauth_token, OAuthTokenSecret = args.oauth_token_secret })
    -- create per-client copies of _M.objects items with an extra _client field
    self.objects = setmetatable({}, {
        __index = function(_self, key)
            local mt = _M.objects[key]
            if mt == nil then return nil end
            local obj = {
                _client = self,
            }
            obj.__index = obj
            util.inherit_mt(obj, mt)
            _self[key] = setmetatable(obj, mt)
            return obj
        end
    })
    -- get info about the authenticated user
    self.me = util.lazy_loader(function()
        local res = self:verify_credentials()
        assert(not res.errors, tostring(res))
        return res
    end)
    return self
end

--- Helper to load OAuth keys from text files.
-- Key files are loaded as Lua files in an empty environment and the values are extracted from their global namespace.
-- It also accepts tables as arguments (useful when using <tt>require</tt>).
--
-- @param ...   Filenames (Lua code) or tables with the keys to load.
-- @return      Table with the keys found.
function _M.load_keys(...)
    local keys, env = {}, {}
    for i = 1, select('#', ...) do
        local source = select(i, ...)
        local ts = type(source)
        if ts == "table" then
            for k, _ in pairs(oauth_key_args) do
                keys[k] = source[k]
            end
        elseif ts == "string" then
            local _, err, res = util.load_file(source, env)
            assert(err, res)
        else
            error("argument #" .. i .. ": invalid type " .. ts, 2)
        end
    end
    for k, _ in pairs(oauth_key_args) do
        keys[k] = env[k]
    end
    return keys
end

return _M
