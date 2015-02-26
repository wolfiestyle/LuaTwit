--- Implements a service for performing asyncronous HTTP requests.
--
-- @module  luatwit.async
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local select, setmetatable, unpack =
      select, setmetatable, unpack
local lanes = require "lanes"

if lanes.configure then
    lanes = lanes.configure()
end

local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end
local unpackn = function(t) return unpack(t, 1, t.n) end

local _M = {}

--- Future object.
-- It contains the result of an asynchronous API call.
-- @type future
local future = { _type = "future" }
future.__index = future

function future.new(id, svc, filter)
    local self = { id = id, svc = svc, filter = filter }
    return setmetatable(self, future)
end

local function future_get(self, method)
    local value = self.value
    if not value then
        local svc = self.svc
        local data = svc[method](svc, self.id)
        if data ~= nil then
            if self.filter then
                value = table_pack(self.filter(unpackn(data)))
            else
                value = data
            end
            self.value = value
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

--- OAuth service object.
-- Executes OAuth requests on background threads.
-- @type service
local service = {}
service.__index = service
_M.service = service

-- worker thread generator
local start_worker_thread = lanes.gen("*", function(message)
    set_debug_threadname("async worker")
    local ltn12 = require "ltn12"

    while true do
        local msg, req = message:receive(nil, "http", "quit")
        if msg == "http" then
            local ok, result = pcall(function()
                local client = require(req.url:find "^https:" and "ssl.https" or "socket.http")
                local resp_body = {}
                local ok, code, headers, status = client.request{
                    method = req.method,
                    url = req.url,
                    headers = req.headers,
                    source = req.body and ltn12.source.string(req.body) or nil,
                    sink = ltn12.sink.table(resp_body),
                }
                if ok then
                    return table_pack(table.concat(resp_body), code, headers, status)
                else
                    return { nil, code, n = 2 }
                end
            end)
            if not ok then
                result = { nil, result, n = 2 }
            end
            message:send("response", { id = req.id, data = result })
        elseif msg == "quit" then
            break
        end
    end
end)

--- Creates a new async http client.
--
-- @param threads Number of threads to create (default 1).
-- @return      New instance of the oauth async client.
function service.new(threads)
    local self = {
        cur_id = 1,
        store = {},
        num_th = threads or 1,
    }
    self.message = lanes.linda()
    return setmetatable(self, service)
end

--- Starts the worker threads.
function service:start()
    if not self.threads then
        self.threads = {}
        for i = 1, self.num_th do
            self.threads[i] = start_worker_thread(self.message)
        end
    end
end

--- Stops the worker threads.
function service:stop()
    if self.threads then
        local n = #self.threads
        for i = 1, n do
            self.message:send("quit", true)
        end
        -- join threads by reading their result
        for i = 1, n do
            local _ = self.threads[i][1]
        end
        self.threads = nil
    end
end

--- Checks if there is data pending to be received.
-- @return      `true` if there is data pending on the message queue, otherwise `false`.
function service:data_available()
    local count = self.message:count("response")
    return count ~= nil and count > 0
end

-- Non-blocking consumer
function service:_poll_data_for(id)
    local data = self.store[id]
    if data == nil and self:data_available() then
        while true do
            local k, v = self.message:receive(0, "response")
            if k == nil then break end
            self.store[v.id] = v.data
        end
        data = self.store[id]
    end
    if data ~= nil then
        self.store[id] = nil
    end
    return data
end

-- Blocking consumer
function service:_wait_data_for(id)
    local data = self.store[id]
    if data == nil then
        repeat
            local k, v = self.message:receive(nil, "response")
            if k ~= nil then
                self.store[v.id] = v.data
            end
            data = self.store[id]
        until data ~= nil
    end
    if data ~= nil then
        self.store[id] = nil
    end
    return data
end

-- Generates a request id
function service:_gen_id()
    local id = self.cur_id
    self.cur_id = id + 1
    return id
end

--- Performs an asynchronous HTTP request.
--
-- @param method    HTTP method.
-- @param url       Request URL.
-- @param body      Body for POST requests.
-- @param headers   Extra headers.
-- @param filter    Function to be called on the result data.
-- @return          `future` object with the result.
function service:http_request(method, url, body, headers, filter)
    local args = { id = self:_gen_id(), method = method, url = url, body = body, headers = headers }
    self:start()
    self.message:send("http", args)
    return future.new(args.id, self, filter)
end

return _M
