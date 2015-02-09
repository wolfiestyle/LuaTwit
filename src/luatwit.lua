--- Lua library for accessing the Twitter REST API v1.1
--
-- @module  luatwit
-- @license MIT/X11
local assert, error, next, pairs, pcall, require, select, setmetatable, tostring, type, unpack =
      assert, error, next, pairs, pcall, require, select, setmetatable, tostring, type, unpack
local oauth = require "OAuth"
local oauth_as = require "luatwit.oauth_async"
local json = require "dkjson"
local util = require "luatwit.util"
local helpers = require "OAuth.helpers"

local _M = {}

--- Class prototype that implements the API calls.
-- Methods are created on demand from the definitions in the `self.resources` table (by default `luatwit.resources`).
-- @type api
local api = {}
_M.api = api

-- Builds the request url and arguments for the OAuth call.
local function build_request(base_url, path, args, defaults, multipart)
    local request = {}
    if defaults then
        util.map_copy(request, defaults)
    end
    util.map_copy(request, args, function(v, k)
        if k:sub(1, 1) ~= "_" then return v end
    end)
    path = path:gsub(":([%w_]+)", function(key)
        local val = request[key]
        assert(val ~= nil, "invalid token ':" .. key .. "' in resource URL")
        request[key] = nil
        return val
    end)
    local url = base_url .. path .. ".json"
    if multipart then
        local mp = helpers.multipart.Request(request)
        return url, mp.body, mp.headers
    end
    return url, request
end

--- Applies type metatables to the supplied JSON data recursively.
--
-- @param node  Table with JSON data.
-- @param tname String with the name of an object defined in `objects`.
-- @return      The `node` argument after the processing is done.
function api:apply_types(node, tname)
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
            if item ~= nil then
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
-- @param method    HTTP method.
-- @param path  API method path.
-- @param args  Table with the method arguments.
-- @param tname Type name as defined in `resources`.
-- @param mp    `true` if the request should be done as multipart.
-- @param rules Rules for checking args (with `luatwit.util.check_args`).
-- @param defaults  Default method arguments.
-- @param name  API method name. Used internally for building error messages.
-- @return      A table with the decoded JSON data from the response, or `nil` on error.
--              If the option `_raw` is set, instead returns an unprocessed JSON string.
--              If the option `_async` is set, instead it returns a `luatwit.oauth_async.future` object.
-- @return      HTTP headers. On error, instead it will be a string or a `luatwit.objects.error` describing the error.
-- @return      If the option `_raw` is set, the type name from `resources`.
--              This value is needed to use `api:parse_json` with the returned string.
--              If an API error ocurred, instead it will be the HTTP headers of the request.
function api:raw_call(method, path, args, tname, mp, rules, defaults, name)
    args = args or {}
    name = name or "raw_call"
    assert(util.check_args(args, rules, name))

    local url, request, req_headers = build_request(self.resources._base_url, path, args, defaults, mp)

    local function parse_response(res_code, headers, _, body)
        -- The method crashed, error is on second arg
        if res_code == nil then
            return nil, headers
        end
        -- OAuth.PerformRequest returns body = {} on error and the error string in 'res_code'
        if type(body) ~= "string" then
            return nil, res_code
        end
        if args._raw then
            return body, headers, tname
        end
        self:apply_types(headers, "headers")
        local json_data, err = self:parse_json(body, tname)
        if json_data == nil then
            return nil, err, headers
        end
        if json_data._type == "error" then
            return nil, json_data, headers
        end
        if method == "GET" and type(json_data) == "table" and type(request) == "table" then
            json_data._source_method = function(_args)
                return self:raw_call(method, path, _args, tname, mp, rules, request, name)
            end
        end
        return json_data, headers
    end

    if args._async then
        return self.oauth_async:PerformRequest(method, url, request, req_headers, parse_response)
    else
        local client = self.oauth_sync
        return parse_response(util.shift_pcall_error(pcall(client.PerformRequest, client, method, url, request, req_headers)))
    end
end

--- Parses a JSON string and applies type metatables.
--
-- @param str   JSON string.
-- @param tname Type name as defined in `resources`.
--              If set, the function will set type metatables.
-- @return      A table with the decoded JSON data, or `nil` on error.
function api:parse_json(str, tname)
    local json_data, _, err = json.decode(str, nil, nil, nil)
    if json_data == nil then
        return nil, err
    end
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
function api:start_login()
    self.oauth_sync:RequestToken{ oauth_callback = "oob" }
    return self.oauth_sync:BuildAuthorizationUrl()
end

--- Finishes the OAuth authorization.
-- This method receives the PIN number obtained in the `api:start_login` step and authorizes the client to make API calls.
--
-- @param pin   PIN number obtained after the user succefully authorized the app.
-- @return      An `access_token` object.
-- @return      HTTP Status line.
-- @return      HTTP result code.
-- @return      HTTP headers.
function api:confirm_login(pin)
    local token, res_code, headers, status_line = self.oauth_sync:GetAccessToken{ oauth_verifier = tostring(pin) }
    -- send the keys to the async service
    if token then
        --FIXME: could update the keys with a message, but not worth the trouble because the OAuth client should be outside of the
        --       thread and only raw HTTP requests should be done in background. Can't do this without ugly hacks using the oauth
        --       lib internals. Or with another OAuth lib that lets me do my own HTTP requests.
        self.oauth_async:stop()
        self.oauth_async.args[4].OAuthToken = token.oauth_token
        self.oauth_async.args[4].OAuthTokenSecret = token.oauth_token_secret
    end
    return self:apply_types(token, "access_token"), status_line, res_code, headers
end

--- Constructs an `api` method from the declarations in `self.resources`.
--
-- @param name  Function name as defined in `self.resources`.
-- @return      Function implementation.
function api:build_method(name)
    if type(name) ~= "string" or name:sub(1, 1) == "_" then return nil end
    local decl = self.resources[name]
    if not decl then return nil end
    assert(type(decl) == "table" and #decl >= 2, "invalid resource declaration for: " .. name)
    local mp, method, path, rules, tname = decl._multipart, unpack(decl)
    local impl = util.make_callable(function(_self, parent, args)
        return parent:raw_call(method, path, args, tname, mp, rules, _self.defaults, name)
    end)
    impl._type = "api"
    impl.path = path
    if decl.default_args then
        local def = util.map_copy({}, decl.default_args, function(v, k)
            if rules[k] ~= nil then return v end
        end)
        if next(def) ~= nil then
            impl.defaults = def
        end
    end
    self[name] = impl
    return impl
end

-- inherit from `api` and build missing methods
local api_index = function(self, key)
    local val = api[key]
    if not val then
        return api.build_method(self, key)
    end
    return val
end

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
-- @param args      Table with the OAuth keys (consumer_key, consumer_secret, oauth_token, oauth_token_secret).
-- @param threads   Number of threads for the async requests (default 1).
-- @param resources Table with the API interface definition (default `luatwit.resources`).
-- @param objects   Table with the API objects definition (default `luatwit.objects`).
-- @return          New instance of the `api` class.
-- @see luatwit.objects.access_token
function api.new(args, threads, resources, objects)
    assert(util.check_args(args, oauth_key_args, "api.new"))
    resources = resources or require("luatwit.resources")
    objects = objects or require("luatwit.objects")
    local self = util.make_class(api_index)
    self.resources = resources
    self.oauth_sync = oauth.new(args.consumer_key, args.consumer_secret, resources._endpoints, { OAuthToken = args.oauth_token, OAuthTokenSecret = args.oauth_token_secret })
    self.oauth_async = oauth_as.service.new(args, resources._endpoints, threads)
    -- create per-client copies of `objects` items with an extra _client field
    self.objects = setmetatable({}, {
        __index = function(_self, key)
            local mt = objects[key]
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
        local res, err = self:verify_credentials()
        assert(res, tostring(err))
        return res
    end)
    return self
end

--- @section end

--- Helper to load OAuth keys from text files.
-- Key files are loaded as Lua files in an empty environment and the values are extracted from their global namespace.
-- It also accepts tables as arguments (useful when using `require`).
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
