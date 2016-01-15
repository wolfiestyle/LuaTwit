--- Implements a service for performing HTTP requests.
--
-- @module  luatwit.http
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local ipairs, next, pairs, pcall, select, setmetatable, table_concat, table_remove, tostring, type =
      ipairs, next, pairs, pcall, select, setmetatable, table.concat, table.remove, tostring, type
local curl = require "lcurl"
local pipe = require "luatwit.util".pipe

local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local table_unpack = table.unpack or unpack
local unpackn = function(t) return table_unpack(t, 1, t.n) end

local _M = {}

-- HTTP user agent string
_M.user_agent = "LuaTwit/0.3.3 libcurl/" .. curl.version_info().version

-- HTTP Headers returned by the requests.
local headers_mt = {}
headers_mt.__index = headers_mt

-- Extracts the content-type info from the HTTP headers.
function headers_mt:get_content_type()
    local content_type = self["content-type"]
    if content_type then
        return content_type:match "^[^;]+"
    end
end

-- Extracts key-value pairs from a HTTP headers list.
local function parse_headers(list)
    local headers = {}
    for _, line in ipairs(list) do
        line = line:gsub("\r?\n$", "")
        local k, v = line:match "^([^:]+): (.*)"
        if not k then   -- status line
            if line ~= "" then
                headers[#headers + 1] = line
            end
        else
            headers[k:lower()] = v  -- case insensitive
        end
    end
    return setmetatable(headers, headers_mt)
end

--- Future object.
-- It contains the result of an asynchronous HTTP request.
-- @type future
local future = { _type = "future" }
future.__index = future

function future.new(handle, svc)
    local self = { handle = handle, svc = svc, pipe = pipe.new() }
    return setmetatable(self, future)
end

local function unpack_response(data)
    if data.error then
        return nil, data.error
    else
        local body = table_concat(data.body)
        local headers = parse_headers(data.headers)
        return body, data.code, headers
    end
end

local function future_get(self, method)
    local value = self.value
    if not value then
        local svc = self.svc
        local data = svc[method](svc, self.handle)
        if data ~= nil then
            value = table_pack(self.pipe(unpack_response(data)))
            self.value = value
            self.handle = nil
        end
    end
    return value
end

--- Checks (non-blocking) and returns the value of the future if it's ready.
--
-- @param no_upd Don't ask the service for new data, just return the current stored value (default `false`).
-- @return      `true` if the value is ready, otherwise `false`.
-- @return      List of return values from the HTTP request.
function future:peek(no_upd)
    local value = future_get(self, no_upd and "_get_data" or "_poll_data")
    if value then
        return true, unpackn(value)
    end
    return false
end

--- Waits (blocks) until the value of the future is ready.
--
-- @return      List of return values from the HTTP request.
function future:wait()
    return unpackn(future_get(self, "_wait_data"))
end

--- Cancels the HTTP request associated with this object.
--
-- @return      `nil` if successfully cancelled, or the result values if called after the request finished.
function future:cancel()
    return unpackn(future_get(self, "_cancel"))
end

--- Appends a function to the output processing of this object.
--
-- @param f     Function that will be added to the output pipe.
-- @return      Self with the updated chain.
-- @see luatwit.util.pipe
function future:map(f)
    self.pipe:add(f)
    return self
end

--- @section end

--- Stream object.
-- It represents an open connection that continuously receives data.
-- @type stream
local stream = { _type = "stream" }
stream.__index = stream

function stream.new(handle, svc, in_buffer)
    local self = {
        handle = handle,
        svc = svc,
        in_buffer = in_buffer,
        out_buffer = {},
        pipe = pipe.new(),
    }

    function self.get_headers()
        local headers = self.headers
        if not headers then
            local raw = svc.store[handle].headers
            if #raw > 0 then
                headers = parse_headers(raw)
                self.headers = headers
            end
        end
        return headers
    end

    return setmetatable(self, stream)
end

-- Extracts the stream data by splitting \r\n separated sections.
local function process_stream(input, output, run_pipe, get_headers)
    if next(input) == nil then return end
    local buffer = table_concat(input)
    local endpos = 1
    for line, pos in buffer:gmatch "(.-)\r\n()" do
        if #line > 0 then
            local val, err = run_pipe(line, 200, get_headers())
            if val == nil then
                val = { error = err, _type = "internal_error" }
            end
            output[#output + 1] = val
        end
        endpos = pos
    end

    for k, _ in pairs(input) do
        input[k] = nil
    end

    if #buffer > endpos - 1 then
        input[1] = buffer:sub(endpos)
    end
end

--- Checks if the stream connection is open.
--
-- @param no_upd    Don't ask the service for new data, just use the current stored state (default `false`).
-- @return          `true` if the connection is open, or `false` and the response if it's closed.
function stream:is_active(no_upd)
    local value = future_get(self, no_upd and "_get_data" or "_poll_data")
    if value then
        return false, unpackn(value)
    end
    return true
end

--- Returns the next object in the stream queue.
--
-- @param no_upd    Don't ask the service for new data, just use the current stored state (default `false`).
-- @return          A stream object, or `nil` if there is no more data available.
function stream:next(no_upd)
    if not no_upd then
        self.svc:update()
        process_stream(self.in_buffer, self.out_buffer, self.pipe, self.get_headers)
    end
    return table_remove(self.out_buffer, 1)
end

--- Convenience function for iterating the stream in a for loop.
--
-- @return          Stream iterator.
function stream:iter()
    return stream.next, self
end

--- Closes the stream connection.
--
-- @return          HTTP request result.
-- @see future:cancel
function stream:close()
    return unpackn(future_get(self, "_cancel"))
end

--- Appends a function to the output processing of this object.
--
-- @param f     Function that will be added to the output pipe.
-- @return      Self with the updated chain.
-- @see luatwit.util.pipe
function stream:map(f)
    self.pipe:add(f)
    return self
end

--- @section end

--- HTTP service object.
-- Executes HTTP requests on background (with `curl.multi`).
-- @type service
local service = {}
service.__index = service
_M.service = service

--- Creates a new async HTTP client.
--
-- @return          New instance of the async client.
function service.new()
    local self = {}
    self.pending = 0
    self.store = {}
    self.curl_multi = curl.multi()
    return setmetatable(self, service)
end

--- Sets the connection limits.
--
-- @param total_conn    Maximum number of total connections (default unlimited).
-- @param host_conn     Maximum number of connections per host (default unlimited).
function service:set_conn_limits(total_conn, host_conn)
    if total_conn then
        self.curl_multi:setopt_max_total_connections(total_conn)
    end
    if host_conn then
        self.curl_multi:setopt_max_host_connections(host_conn)
    end
end

--- Performs data transfers and checks for finished requests.
--
-- @return      If there was data available, the current number of unfinished requests. Otherwise `nil`.
function service:update()
    local n = self.curl_multi:perform()
    if n ~= self.pending then
        while true do
            local handle, ok, err = self.curl_multi:info_read()
            if handle == 0 then break end
            if not ok then
                self.store[handle].error = tostring(err)
            end
            self.store[handle].code = handle:getinfo(curl.INFO_RESPONSE_CODE)
            self.curl_multi:remove_handle(handle)
            handle:close()
        end
        self.pending = n
        return n
    end
end

--- Waits until data is received.
--
-- @param timeout   Time to wait, in milliseconds (default 1000).
-- @return          Number of objects with data to be read.
function service:wait(timeout)
    return self.curl_multi:wait(timeout)
end

-- Non-blocking consumer
function service:_poll_data(handle)
    local data = self.store[handle]
    if data.code == nil then
        self:update()
    end
    if data.code ~= nil then
        self.store[handle] = nil
        return data
    end
end

-- Blocking consumer
function service:_wait_data(handle)
    local data = self.store[handle]
    if data.code == nil then
        while true do
            self:update()
            if data.code ~= nil then break end
            self:wait()
        end
        self.store[handle] = nil
    end
    return data
end

-- Read value without updating
function service:_get_data(handle)
    local data = self.store[handle]
    if data.code ~= nil then
        self.store[handle] = nil
        return data
    end
end

-- Cancel the request
function service:_cancel(handle)
    local data = self.store[handle]
    self.store[handle] = nil
    if data.code ~= nil then
        return data
    end
    self.curl_multi:remove_handle(handle)
    handle:close()
    return { error = "cancelled" }
end

-- Appends data to a table.
local function table_writer(tbl, data)
    tbl[#tbl + 1] = data
end

-- Creates a list from a table by joining key-value pairs.
local function join_pairs(tbl, sep)
    local res = {}
    for k, v in pairs(tbl) do
        res[#res + 1] = k .. sep .. v
    end
    return res
end

-- Builds the curl.easy object that is used on both regular and async requests.
local function build_easy_handle(method, url, body, headers)
    local resp_body, resp_headers = {}, {}
    local handle = curl.easy()
    :setopt_url(url)
    :setopt_accept_encoding ""
    :setopt_low_speed_limit(1)
    :setopt_low_speed_time(90)
    :setopt_useragent(_M.user_agent)
    :setopt_writefunction(table_writer, resp_body)
    :setopt_headerfunction(table_writer, resp_headers)
    if method then handle:setopt_customrequest(method) end
    if headers then handle:setopt_httpheader(join_pairs(headers, ": ")) end

    if body then
        if type(body) == "table" then  -- multipart
            local form = curl.form()
            for k, v in pairs(body) do
                if type(v) == "table" then
                    form:add_buffer(k, v.filename, v.data)
                else
                    form:add_content(k, v)
                end
            end
            handle:setopt_httppost(form)
        else
            handle:setopt_postfields(body)
        end
    end

    return handle, resp_body, resp_headers
end

--- Performs an asynchronous HTTP request.
--
-- @param method    HTTP method.
-- @param url       Request URL.
-- @param body      Post body. Form-encoded string (single part) or table (multipart).
-- @param headers   Additional headers.
-- @param is_stream Indicates if it's a streaming connection or not.
-- @return          `future` object with the result.
function service:async_request(method, url, body, headers, is_stream)
    local request, resp_body, resp_headers = build_easy_handle(method, url, body, headers)
    self.store[request] = { body = resp_body, headers = resp_headers }
    self.pending = self.pending + 1
    self.curl_multi:add_handle(request):perform()
    if is_stream then
        return stream.new(request, self, resp_body)
    else
        return future.new(request, self)
    end
end

--- Performs an HTTP request.
--
-- @param method    HTTP method.
-- @param url       Request URL.
-- @param body      Post body. Form-encoded string (single part) or table (multipart).
-- @param headers   Additional headers.
-- @return          Response body or `nil` on error.
-- @return          Status code.
-- @return          Response headers.
function service.request(method, url, body, headers)
    local request, resp_body, resp_headers = build_easy_handle(method, url, body, headers)
    local ok, err = pcall(request.perform, request)
    if not ok then
        return nil, tostring(err)
    end
    local code = request:getinfo(curl.INFO_RESPONSE_CODE)
    request:close()
    resp_body = table_concat(resp_body)
    resp_headers = parse_headers(resp_headers)

    return resp_body, code, resp_headers
end

return _M
