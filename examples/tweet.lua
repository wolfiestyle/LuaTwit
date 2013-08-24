#!/usr/bin/lua
--
-- Sends a tweet with the text in the command line arguments.
--
pcall(require, "luarocks.loader")
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"

-- read tweet text from arguments
local msg = table.concat({...}, " ")
assert(msg:len() > 0, "missing tweet text")

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.new(oauth_params)

-- send the tweet
local tw, status_line = client:tweet{ status = msg }
assert(tw, status_line)

-- the result is json data in a Lua table
print("user: @" .. tw.user.screen_name .. " (" .. tw.user.name .. ")")
print("text: " .. tw.text)
print("tweet id: " .. tw.id_str)
