--- Lua library for accessing the Twitter REST API v1.1
--
-- @module  luatwit
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local assert, error, io_open, ipairs, next, pairs, require, select, setmetatable, table_concat, type =
      assert, error, io.open, ipairs, next, pairs, require, select, setmetatable, table.concat, type
local oauth = require "oauth_light"
local json = require "dkjson"
local curl = require "lcurl"
local config = require "pl.config"
local lt_async = require "luatwit.async"
local util = require "luatwit.util"

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
--              If the option `_async` or `_callback` is set, instead it returns a `luatwit.async.future` object.
-- @return      HTTP headers. On error, instead it will be a string or a `luatwit.objects.error` describing the error.
-- @return      If an API error ocurred, the HTTP headers of the request.
function api:raw_call(method, path, args, mp, base_url, tname, rules, defaults, name)
    args = args or {}
    name = name or "raw_call"
    base_url = base_url or self.resources._base_url
    assert(util.check_args(args, rules, name))
    assert(not args._callback or self.callback_handler, "need callback handler")

    local url, request = build_request(base_url, path, args, rules and rules.optional, defaults)

    local function parse_response(body, res_code, headers)
        local data, err = self:_parse_response(body, res_code, headers, tname)
        if data == nil then
            return nil, err, headers
        end
        if type(data) == "table" and data._type then
            data._source = name
            if next(request) then
                data._request = request
            end
            if data._type == "error" then
                return nil, data, headers
            end
        end
        return data, headers
    end

    local req_url, req_body, req_headers = oauth.build_request(method, url, request, self.oauth_config, mp)

    return self:http_request{
        method = method, url = req_url, body = req_body, headers = req_headers,
        _async = args._async, _callback = args._callback, _filter = parse_response,
    }
end

-- Parses a JSON string and applies type metatables.
local function parse_json(self, str, tname)
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
        set_client_field(json_data, self._get_client)
    end
    return json_data
end

-- Parses a form encoded OAuth token.
local function parse_oauth_token(body, res_code, oauth_config)
    if body == nil then
        return nil, res_code
    end
    if res_code ~= 200 then
        return nil, headers[1]
    end
    local token = oauth.form_decode_pairs(body)
    if token.oauth_token == nil or token.oauth_token_secret == nil then
        return nil, "received invalid token"
    end
    oauth_config.oauth_token = token.oauth_token
    oauth_config.oauth_token_secret = token.oauth_token_secret
    return token
end

-- Parses the response body according to the content-type value.
function api:_parse_response(body, res_code, headers, tname)
    -- The method failed, error is on second arg
    if body == nil then
        return nil, res_code
    end
    -- HTTP request failed
    if res_code ~= 200 then
        return nil, headers[1]
    end
    apply_types(self.objects, headers, "headers")
    local content_type = headers:get_content_type()
    if content_type == "application/json" then
        return parse_json(self, body, tname)
    else
        return body
    end
end

--- Begins the OAuth authorization.
-- This method generates the URL that the user must visit to authorize the app and get the PIN needed for `api:confirm_login`.
--
-- @param args  Extra arguments for the request_token method.
-- @return      Authorization URL.
-- @return      The request token.
function api:start_login(args)
    args = args or {}
    args.oauth_callback = "oob"

    local function parse_response(body, res_code, headers)
        local token, err = parse_oauth_token(body, res_code, self.oauth_config)
        if not token then
            return nil, err
        end
        local auth_url = self.resources._endpoints.AuthorizeUser .. "?oauth_token=" .. oauth.url_encode(token.oauth_token)
        return auth_url, token
    end

    local url, body, headers = oauth.build_request("POST", self.resources._endpoints.RequestToken, args, self.oauth_config)

    return self:http_request{
        method = "POST", url = url, body = body, headers = headers,
        _async = args._async, _callback = args._callback, _filter = parse_response,
    }
end

--- Finishes the OAuth authorization.
-- This method receives the PIN number obtained in the `api:start_login` step and authorizes the client to make API calls.
--
-- @param pin   PIN number obtained after the user succefully authorized the app.
-- @param args  Extra arguments for the access_token method.
-- @return      An `access_token` object.
function api:confirm_login(pin, args)
    args = args or {}
    args.oauth_verifier = pin

    local function parse_response(body, res_code, headers)
        local token, err = parse_oauth_token(body, res_code, self.oauth_config)
        if not token then
            return nil, err
        end
        return apply_types(self.objects, token, "access_token")
    end

    local url, body, headers = oauth.build_request("POST", self.resources._endpoints.AccessToken, args, self.oauth_config)

    return self:http_request{
        method = "POST", url = url, body = body, headers = headers,
        _async = args._async, _callback = args._callback, _filter = parse_response,
    }
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

local http_request_args = {
    required = {
        url = "string",
    },
    optional = {
        method = "string",
        body = "any",   -- string or table
        headers = "table",
    },
}

--- Performs an HTTP request.
-- This method allows using the library features (like callback_handler) with regular HTTP requests.
--
-- @param args  Table with request arguments (url, body, _async, _callback).
-- @return      Request response, or a `luatwit.async.future` object if the `_async` or `_callback` options were used.
function api:http_request(args)
    assert(util.check_args(args, http_request_args, "http_request"))
    assert(not args._callback or self.callback_handler, "need callback handler")

    local req = curl.easy()
    req:setopt_url(args.url)
    :setopt_accept_encoding ""
    if args.method then req:setopt_customrequest(args.method) end
    if args.headers then req:setopt_httpheader(util.join_pairs(args.headers, ": ")) end

    if args.body then
        if type(args.body) == "table" then  -- multipart
            local form = curl.form()
            for k, v in pairs(args.body) do
                if type(v) == "table" then
                    form:add_buffer(k, v.filename, v.data)
                else
                    form:add_content(k, v)
                end
            end
            req:setopt_httppost(form)
        else
            req:setopt_postfields(args.body)
        end
    end

    if args._async or args._callback then
        local fut = self.async:http_request(req, args._filter)
        if args._callback then
            return fut, self.callback_handler(fut, args._callback)
        end
        return fut
    else
        local resp_body, resp_headers = {}, {}
        req:setopt_writefunction(util.table_writer, resp_body)
        :setopt_headerfunction(util.table_writer, resp_headers)

        local code = req:perform():getinfo(curl.INFO_RESPONSE_CODE)
        req:close()
        local body = table_concat(resp_body)
        local headers = util.parse_headers(resp_headers)

        if args._filter then
            return args._filter(body, code, headers)
        else
            return body, code, headers
        end
    end
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
-- @param keys      Table with the OAuth keys (consumer_key, consumer_secret, oauth_token, oauth_token_secret).
-- @param resources Table with the API interface definition (default `luatwit.resources`).
-- @param objects   Table with the API objects definition (default `luatwit.objects`).
-- @return          New instance of the `api` class.
-- @see luatwit.objects.access_token
function api.new(keys, resources, objects)
    assert(util.check_args(keys, api_new_args, "api.new"))

    local self = {
        __index = api_index,
        resources = resources or require("luatwit.resources"),
        objects = objects or require("luatwit.objects"),
        oauth_config = {
            consumer_key = keys.consumer_key,
            consumer_secret = keys.consumer_secret,
            oauth_token = keys.oauth_token,
            oauth_token_secret = keys.oauth_token_secret,
            sig_method = "HMAC-SHA1",
            use_auth_header = true,
        },
    }
    self.async = lt_async.service.new()
    self._get_client = function() return self end

    return setmetatable(self, self)
end

local oauth_key_names = { "consumer_key", "consumer_secret", "oauth_token", "oauth_token_secret" }

--- @section end

--- Helper to load OAuth keys from text files.
-- Key files are loaded with `pl.config`.
-- It also accepts tables as arguments (useful when using `require`).
--
-- @param ...   Filenames (config files) or tables with the keys to load.
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
        elseif ts == "nil" then
            source = {}
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

--- Loads a file and prepares it for a multipart request.
--
-- @param filename  File to be read.
-- @return          On success, a table with the file contents. On error `nil`.
-- @return          The error message in case of failure.
-- @see luatwit.resources.upload_media
function _M.attach_file(filename)
    local file, err = io_open(filename, "rb")
    if file == nil then
        return nil, err
    end
    local res = {
        filename = filename:match "([^/]*)$",
        data = file:read "*a",
    }
    file:close()
    return res
end

return _M
