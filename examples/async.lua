#!/usr/bin/lua
--
-- Performs an asyncronous API call.
--
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"
local pretty = require "pl.pretty"
local socket = require "socket"

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.api.new(oauth_params)

-- When the option _async is set, the methods exit immeditately and
-- return a future value. The request is done in a background thread.
-- The main thread can get the result calling :peek() or :wait()
-- on the future object.
local f = client:verify_credentials{ skip_status = true, _async = true }
print "request sent..."

-- do something else until it's ready
local ready, res, err
repeat
    print "waiting for response..."
    socket.sleep(0.25)
    -- uses the same return format of normal api calls
    ready, res, err = f:peek()
until ready

-- the second return value contains the error if something went wrong
assert(res, tostring(err))

pretty.dump(res)
