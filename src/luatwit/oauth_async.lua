--- Implements a service for performing asyncronous OAuth requests.
--
-- @module  luatwit.oauth_async
-- @license MIT/X11
local setmetatable, unpack =
      setmetatable, unpack
local lanes = require "lanes".configure()

local table_pack = table.pack or function(...) return { n = select("#", ...), ... } end

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
    if not self.value then
        local svc = self.svc
        local data = svc[method](svc, self.id)
        if data ~= nil then
            self.value = table_pack(self.callback(data.res_code, data.headers, data.body))
        end
    end
    if self.value then
        return unpack(self.value, 1, self.value.n)
    end
end

--- Checks (non-blocking) and returns the value of the future if it's ready.
--
-- @return      The API call result, or <tt>nil</tt> if it's not ready yet.
function future:peek()
    return future_get(self, "_poll_data_for")
end

--- Waits (blocks) until the value of the future is ready.
--
-- @return      The API call result.
function future:wait()
    return future_get(self, "_wait_data_for")
end

--- @section end

--- Worker object.
-- Executes OAuth requests on a background thread.
-- @type worker
local worker = {}
worker.__index = worker
_M.worker = worker

-- worker thread
local start_service_thread = lanes.gen("*", function(args, message)
    local oauth_client = require("OAuth").new(unpack(args))

    while true do
        local k, v = message:receive(nil, "request", "quit")
        if k == "request" then
            local res_code, headers, _, body = oauth_client:PerformRequest(v.method, v.url, v.request, v.headers)
            message:send("response", { id = v.id, data = { res_code = res_code, headers = headers, body = body } })
        elseif k == "quit" then
            break
        end
    end
end)

--- Creates a new async OAuth client.
--
-- @param keys  Table with the OAuth keys (consumer_key, consumer_secret, oauth_token, oauth_token_secret).
-- @param endp  Table with OAuth endpoints.
-- @return      New instance of the oauth async client.
function worker.new(keys, endp)
    local self = {
        cur_id = 1,
        data = {},
        args = { keys.consumer_key, keys.consumer_secret, endp, { OAuthToken = keys.oauth_token, OAuthTokenSecret = keys.oauth_token_secret } },
    }
    self.message = lanes.linda()

    return setmetatable(self, worker)
end

--- Starts the service thread.
function worker:start()
    if not self.thread then
        self.thread = start_service_thread(self.args, self.message)
    end
end

--- Stops the service thread.
function worker:stop()
    if self.thread then
        self.message:send("quit", true)
        self.thread:join()
        self.thread = nil
    end
end

--- Checks if there is data pending to be received.
-- @return      <tt>true</tt> if there is data pending on the message queue, otherwise <tt>false</tt>.
function worker:data_available()
    local count = self.message:count("response")
    return count ~= nil and count > 0
end

-- Non-blocking consumer
function worker:_poll_data_for(id)
    local data = self.data[id]
    if data == nil and self:data_available() then
        while true do
            local k, v = self.message:receive(0, "response")
            if k == nil then break end
            self.data[v.id] = v.data
        end
        data = self.data[id]
    end
    if data ~= nil then
        self.data[id] = nil
    end
    return data
end

-- Blocking consumer
function worker:_wait_data_for(id)
    local data = self.data[id]
    if data == nil then
        repeat
            local k, v = self.message:receive(nil, "response")
            if k ~= nil then
                self.data[v.id] = v.data
            end
            data = self.data[id]
        until data ~= nil
    end
    if data ~= nil then
        self.data[id] = nil
    end
    return data
end

--- Performs an asynchronous OAuth request.
--
-- @param method    HTTP method.
-- @param url       Request URL.
-- @param request   Table with request pairs.
-- @param headers   Custom HTTP headers.
-- @param callback  Function that processes the response output.
function worker:PerformRequest(method, url, request, headers, callback)
    local args = { method = method, url = url, request = request, headers = headers }
    args.id = self.cur_id
    self.cur_id = self.cur_id + 1
    self:start()
    self.message:send("request", args)
    return future.new(args.id, self, callback)
end

return _M
