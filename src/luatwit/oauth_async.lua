--- Implements a service for performing asyncronous OAuth requests.
--
-- @module  luatwit.oauth_async
-- @license MIT/X11
local pcall, select, setmetatable, unpack =
      pcall, select, setmetatable, unpack
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

function future.new(id, svc, callback)
    local self = { id = id, svc = svc, callback = callback }
    return setmetatable(self, future)
end

local function future_get(self, method)
    local value = self.value
    if not value then
        local svc = self.svc
        local data = svc[method](svc, self.id)
        if data ~= nil then
            if self.callback then
                value = table_pack(self.callback(unpackn(data)))
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
local start_worker_thread = lanes.gen("*", function(args, message)
    set_debug_threadname("oauth_async")
    local oauth_client = require("OAuth").new(unpack(args))

    while true do
        local msg, req = message:receive(nil, "request", "quit")
        if msg == "request" then
            local ok, result = pcall(function()
                return table_pack(oauth_client[req.method](oauth_client, unpackn(req.args)))
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

--- Creates a new async OAuth client.
--
-- @param keys  Table with the OAuth keys (consumer_key, consumer_secret, oauth_token, oauth_token_secret).
-- @param endp  Table with OAuth endpoints.
-- @param threads Number of threads to create (default 1).
-- @return      New instance of the oauth async client.
function service.new(keys, endp, threads)
    local self = {
        cur_id = 1,
        store = {},
        args = { keys.consumer_key, keys.consumer_secret, endp, { OAuthToken = keys.oauth_token, OAuthTokenSecret = keys.oauth_token_secret } },
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
            self.threads[i] = start_worker_thread(self.args, self.message)
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

--- Performs an asynchronous OAuth request.
--
-- @param name      Method name.
-- @param callback  Function that processes the response output (called when reading the `future`).
-- @param ...       Method arguments.
-- @return          `future` object with the result.
function service:call_method(name, callback, ...)
    local args = { id = self:_gen_id(), method = name, args = table_pack(...) }
    self:start()
    self.message:send("request", args)
    return future.new(args.id, self, callback)
end

--- Async wrapper for `OAuth.PerformRequest`.
--
-- @param method    HTTP method.
-- @param url       Request URL.
-- @param request   Table with request pairs.
-- @param headers   Custom HTTP headers.
-- @param callback  Function that processes the response output.
-- @return          `future` object with the result.
function service:PerformRequest(method, url, request, headers, callback)
    return self:call_method("PerformRequest", callback, method, url, request, headers)
end

return _M
