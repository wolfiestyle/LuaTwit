--- Lua library for accessing the Twitter REST API v1.1
--
-- @module  luatwit
-- @license MIT
local error, pairs, select, setmetatable, table_concat, tostring, type, unpack =
      error, pairs, select, setmetatable, table.concat, tostring, type, unpack
local oauth = require "OAuth"
local json = require "cjson"
local util = require "luatwit.util"

local _M = {}

--- API resource data.
-- @see luatwit.resources
_M.resources = require "luatwit.resources"

--- API object definitions.
-- @see luatwit.objects
_M.objects = require "luatwit.objects"

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

-- Checks if the arguments in a table match the rules.
local function check_args(args, rules, res_name)
    if type(args) ~= "table" then
        return res_name .. ": arguments must be passed in a table"
    end
    if not rules then return nil end
    -- check for valid args (names starting with _ are ignored)
    for name, val in pairs(args) do
        if rules[name] == nil and name:sub(1, 1) ~= "_" then
            return res_name .. ": invalid argument '" .. name .. "' not in (" .. build_args_str(rules) .. ")"
        end
        local val_type = type(val)
        if val_type ~= "string" and val_type ~= "number" and val_type ~= "boolean" then
            return res_name .. ": argument '" .. name .. "' must be a scalar type"
        end
    end
    -- check if required args are present
    for name, required in pairs(rules) do
        if required and args[name] == nil then
            return res_name .. ": missing required argument '" .. name .. "' in (" .. build_required_str(rules) .. ")"
        end
    end
    return nil
end

-- Applies type metatables to the json data recursively.
local function apply_types(node, tname)
    local type_decl = _M.objects[tname]
    util.bless(node, type_decl)
    local st = type_decl._subtypes
    if st == nil then return end
    local type_st = type(st)
    if type_st == "string" then
        for _, item in pairs(node) do
            apply_types(item, st)
        end
    elseif type_st == "table" then
        for k, tn in pairs(st) do
            local item = node[k]
            if item ~= nil and item ~= json.null then
                apply_types(item, tn)
            end
        end
    else
        error("subtype declaration must be string or table")
    end
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
    util.assertx(#decl >= 2, "invalid resource declaration", 2)
    args = args or {}
    name = name or "raw_call"
    local method, url, rules, tname = unpack(decl)
    local err = check_args(args, rules, name)
    util.assertx(not err, err, 3)
    local args_str = {}
    if defaults then
        for k, v in pairs(defaults) do
            args_str[k] = tostring(v)
        end
    end
    for k, v in pairs(args) do
        if k:sub(1, 1) ~= "_" then
            args_str[k] = tostring(v)
        end
    end
    url = url:gsub(":([%w_]+)", function(key)
        local val = args_str[key]
        util.assertx(val ~= nil, "invalid token ':" .. key .. "' in resource URL", 2)
        args_str[key] = nil
        return val
    end)
    url = _M.resources._base_url .. url .. ".json"
    local res_code, headers, status_line, body = self.oauth_client:PerformRequest(method, url, args_str)
    util.bless(headers, _M.objects.headers)
    if args._raw then
        if type(body) ~= "string" then body = nil end
        return body, status_line, res_code, headers, tname
    end
    local json_data = type(body) == "string" and self:parse_json(body, tname) or nil
    if type(json_data) == "table" then
        json_data._context = {
            client = self,
            source_method = function(_args)
                return self:raw_call(decl, _args, name, args_str)
            end,
        }
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
            apply_types(json_data, tname)
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
    return util.bless(token, _M.objects.access_token), status_line, res_code, headers
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
    util.assertx(not err, err, 2)
    local self = util.new(_M.api)
    self.oauth_client = oauth.new(args.consumer_key, args.consumer_secret, _M.resources._endpoints, { OAuthToken = args.oauth_token, OAuthTokenSecret = args.oauth_token_secret })
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
            util.assertx(err, res, 2)
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
