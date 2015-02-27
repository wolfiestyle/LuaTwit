--- Implements a service for performing asyncronous HTTP requests.
--
-- @module  luatwit.async
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local select, setmetatable, table_concat, unpack =
      select, setmetatable, table.concat, unpack
local util = require "luatwit.util"
local curl = require "lcurl"

local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpackn = function(t) return unpack(t, 1, t.n) end

local _M = {}

--- Future object.
-- It contains the result of an asynchronous API call.
-- @type future
local future = { _type = "future" }
future.__index = future

function future.new(handle, svc, filter)
    local self = { handle = handle, svc = svc, filter = filter }
    return setmetatable(self, future)
end

local function future_get(self, method)
    local value = self.value
    if not value then
        local svc = self.svc
        local data = svc[method](svc, self.handle)
        if data ~= nil then
            if data.error then
                value = { nil, data.error, n = 2 }
            else
                local body = table_concat(data.body)
                local headers = util.parse_headers(data.headers)
                if self.filter then
                    value = table_pack(self.filter(body, data.code, headers))
                else
                    value = { body, data.code, headers, n = 3 }
                end
            end
            self.value = value
            self.handle = nil
        end
    end
    return value
end

--- Checks (non-blocking) and returns the value of the future if it's ready.
--
-- @return      `true` if the value is ready, otherwise `false`.
-- @return      List of return values from the API call.
function future:peek()
    local value = future_get(self, "_poll_data_for")
    if value then
        return true, unpackn(value)
    end
    return false
end

--- Waits (blocks) until the value of the future is ready.
--
-- @return      List of return values from the API call.
function future:wait()
    return unpackn(future_get(self, "_wait_data_for"))
end

--- @section end

--- HTTP service object.
-- Executes HTTP requests on background (with `curl.multi`).
-- @type service
local service = {}
service.__index = service
_M.service = service

--- Creates a new async http client.
--
-- @return          New instance of the async client.
function service.new()
    local self = {
        pending = 0,
        store = {},
    }
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

--- Checks if there is data pending to be received.
--
-- @return      If there is data available, the current number of unfinished requests. Otherwise `nil`.
function service:data_available()
    local n = self.curl_multi:perform()
    if n ~= self.pending then
        self.pending = n
        return n
    end
end

-- Reads the result from finished requests.
function service:_fetch_handle_results()
    while true do
        local handle, ok, err = self.curl_multi:info_read()
        if handle == 0 then break end
        if not ok then
            self.store[handle].error = err
        end
        self.store[handle].code = handle:getinfo(curl.INFO_RESPONSE_CODE)
        self.curl_multi:remove_handle(handle)
        handle:close()
    end
end

-- Non-blocking consumer
function service:_poll_data_for(handle)
    local data = self.store[handle]
    if data.code == nil and self:data_available() then
        self:_fetch_handle_results()
    end
    if data.code ~= nil then
        self.store[handle] = nil
        return data
    end
end

-- Blocking consumer
function service:_wait_data_for(handle)
    local data = self.store[handle]
    if data.code == nil then
        repeat
            while not self:data_available() do
                self.curl_multi:wait(1000)
            end
            self:_fetch_handle_results()
        until data.code ~= nil
        self.store[handle] = nil
    end
    return data
end

--- Performs an asynchronous HTTP request.
--
-- @param request   Request objected created by `curl.easy`.
-- @param filter    Function to be called on the result data.
-- @return          `future` object with the result.
function service:http_request(request, filter)
    local body, headers = {}, {}
    self.store[request] = { body = body, headers = headers }
    self.pending = self.pending + 1
    request:setopt_writefunction(util.table_writer, body)
    :setopt_headerfunction(util.table_writer, headers)
    self.curl_multi:add_handle(request):perform()
    return future.new(request, self, filter)
end

return _M
