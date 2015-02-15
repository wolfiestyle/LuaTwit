--- Lua library for accessing the Twitter REST API v1.1
--
-- @module  luatwit
-- @license MIT/X11
local assert, error, ipairs, next, pairs, pcall, require, select, setmetatable, tostring, type, unpack =
      assert, error, ipairs, next, pairs, pcall, require, select, setmetatable, tostring, type, unpack
local oauth = require "OAuth"
local lt_async = require "luatwit.async"
local json = require "dkjson"
local util = require "luatwit.util"
local helpers = require "OAuth.helpers"
local config = require "pl.config"

local _M = {}

--- Class prototype that implements the API calls.
-- Methods are created on demand from the definitions in the `self.resources` table (by default `luatwit.resources`).
-- @type api
local api = {}
_M.api = api

-- Builds the request url and arguments for the OAuth call.
local function build_request(base_url, path, args, rules, defaults)
    local request = {}
    if defaults then
        util.map_copy(request, defaults, function(v, k)
            if rules[k] ~= nil then return v end
        end)
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
    return url, request
end

-- Applies type metatables to the supplied JSON data recursively.
local function apply_types(objects, node, tname)
    local type_decl = objects[tname]
    assert(type(type_decl) == "table", "invalid object type")
    if type(node) == "table" then
        setmetatable(node, type_decl)
    end
    local st = type_decl._subtypes
    if st == nil then return node end
    local type_st = type(st)
    if type_st == "string" then
        for _, item in pairs(node) do
            apply_types(objects, item, st)
        end
    elseif type_st == "table" then
        for k, tn in pairs(st) do
            local item = node[k]
            if item ~= nil then
                apply_types(objects, item, tn)
            end
        end
    else
        error("subtype declaration must be string or table")
    end
    return node
end

-- Sets the _get_client field on each object recursively.
local function set_client_field(node, value)
    if node._type then
        node._get_client = value
    end
    for _, item in pairs(node) do
        if type(item) == "table" then
            set_client_field(item, value)
        end
    end
end

--- Generic call to the Twitter API.
-- This is the backend method that performs all the API calls.
--
-- @param method    HTTP method.
-- @param path      API method path.
-- @param args      Table with the method arguments.
-- @param mp        `true` if the request should be done as multipart.
-- @param base_url  Base URL for the method endpoint.
-- @param tname     Result type name as defined in `resources`.
-- @param rules     Rules for checking args (with `luatwit.util.check_args`).
-- @param defaults  Default method arguments.
-- @param name      API method name. Used internally for building error messages.
-- @return      A table with the decoded JSON data from the response, or `nil` on error.
--              If the option `_raw` is set, instead returns an unprocessed JSON string.
--              If the option `_async` or `_callback` is set, instead it returns a `luatwit.async.future` object.
-- @return      HTTP headers. On error, instead it will be a string or a `luatwit.objects.error` describing the error.
-- @return      If the option `_raw` is set, the type name from `resources`.
--              This value is needed to use `api:parse_json` with the returned string.
--              If an API error ocurred, instead it will be the HTTP headers of the request.
function api:raw_call(method, path, args, mp, base_url, tname, rules, defaults, name)
    args = args or {}
    name = name or "raw_call"
    base_url = base_url or self.resources._base_url
    assert(util.check_args(args, rules, name))
    assert(not args._callback or self.callback_handler, "need callback handler")

    local url, request = build_request(base_url, path, args, rules.optional, defaults)

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
        apply_types(self.objects, headers, "headers")
        local json_data, err = self:parse_json(body, tname)
        if json_data == nil then
            return nil, err, headers
        end
        set_client_field(json_data, self._get_client)
        json_data._source = name
        if next(request) then
            json_data._request = request
        end
        if json_data._type == "error" then
            return nil, json_data, headers
        end
        return json_data, headers
    end

    local req_body, req_headers = request
    if mp then
        local req = helpers.multipart.Request(request)
        req_body, req_headers = req.body, req.headers
    end

    if args._async or args._callback then
        local fut = self.async:oauth_request(method, url, req_body, req_headers, parse_response)
        if args._callback then
            return fut, self.callback_handler(fut, args._callback)
        end
        return fut
    else
        local client = self.oauth_client
        return parse_response(util.shift_pcall_error(pcall(client.PerformRequest, client, method, url, req_body, req_headers)))
    end
end

--- Parses a JSON string and applies type metatables.
--
-- @param str   JSON string.
-- @param tname Result type name as defined in `resources`.
--              If set, the function will set type metatables.
-- @return      A table with the decoded JSON data, or `nil` on error.
function api:parse_json(str, tname)
    local json_data, _, err = json.decode(str, nil, nil, nil)
    if json_data == nil then
        return nil, err
    end
    if type(json_data) ~= "table" then
        return nil, "root json element is not an object"
    end
    if json_data.errors then
        tname = "error"
    end
    if tname then
        apply_types(self.objects, json_data, tname)
    end
    return json_data
end

--- Begins the OAuth authorization.
-- This method generates the URL that the user must visit to authorize the app and get the PIN needed for `api:confirm_login`.
--
-- @return      Authorization URL.
-- @return      HTTP Authorization header.
function api:start_login()
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
function api:confirm_login(pin)
    local token, res_code, headers, status_line = self.oauth_client:GetAccessToken{ oauth_verifier = tostring(pin) }
    -- send the keys to the async service
    if token then
        --FIXME: could update the keys with a message, but not worth the trouble because the OAuth client should be outside of the
        --       thread and only raw HTTP requests should be done in background. Can't do this without ugly hacks using the oauth
        --       lib internals. Or with another OAuth lib that lets me do my own HTTP requests.
        self.async:stop()
        self.async.args[4].OAuthToken = token.oauth_token
        self.async.args[4].OAuthTokenSecret = token.oauth_token_secret
    end
    return apply_types(self.objects, token, "access_token"), status_line, res_code, headers
end

--- Sets the callback handler function.
-- The callback handler is called after every async request that uses the `_callback` option. This function has to do the
-- necessary setup to watch the future and send the result to the callback when it's ready.
-- This way we can work with external event loops in a transparent way.
--
-- @param fn    Callback handler function. This is called as `fn(fut, callback)`, where `fut` is the result from an async
--              API call and `callback` is the value passed in the request's `_callback` argument.
function api:set_callback_handler(fn)
    self.callback_handler = fn
end

local http_async_args = {
    required = {
        url = "string",
    },
    optional = {
        body = "string",
    },
}

--- Performs an asynchronous HTTP request.
--
-- @param args  Table with request arguments (url, body, _callback).
-- @return      `luatwit.async.future` object with the result.
function api:http_async(args)
    assert(util.check_args(args, http_async_args, "http_async"))
    assert(not args._callback or self.callback_handler, "need callback handler")

    local fut = self.async:http_request(args.url, args.body)
    if args._callback then
        return fut, self.callback_handler(fut, args._callback)
    end
    return fut
end

-- inherit from `api` and `resources`
local function api_index(self, key)
    return api[key] or self.resources[key]
end

local api_new_args = {
    required = {
        consumer_key = "string",
        consumer_secret = "string",
    },
    optional = {
        oauth_token = "string",
        oauth_token_secret = "string",
    },
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
    assert(util.check_args(args, api_new_args, "api.new"))

    local self = {
        __index = api_index,
        resources = resources or require("luatwit.resources"),
        objects = objects or require("luatwit.objects"),
    }
    local endpoints = self.resources._endpoints
    self.oauth_client = oauth.new(args.consumer_key, args.consumer_secret, endpoints, { OAuthToken = args.oauth_token, OAuthTokenSecret = args.oauth_token_secret })
    self.async = lt_async.service.new(args, endpoints, threads)
    self._get_client = function() return self end

    return setmetatable(self, self)
end

local oauth_key_names = { "consumer_key", "consumer_secret", "oauth_token", "oauth_token_secret" }

--- @section end

--- Helper to load OAuth keys from text files.
-- Key files are loaded with `pl.config`.
-- It also accepts tables as arguments (useful when using `require`).
--
-- @param ...   Filenames (Lua code) or tables with the keys to load.
-- @return      Table with the keys found.
function _M.load_keys(...)
    local keys = {}
    for i = 1, select('#', ...) do
        local source = select(i, ...)
        local ts = type(source)
        if ts == "string" then
            local cfg, err = config.read(source, { trim_quotes = true })
            assert(cfg, err)
            source = cfg
        elseif ts ~= "table" then
            error("argument #" .. i .. ": invalid type " .. ts, 2)
        end
        for _, k in ipairs(oauth_key_names) do
            local v = source[k]
            if v ~= nil then
                keys[k] = v
            end
        end
    end
    return keys
end

return _M
