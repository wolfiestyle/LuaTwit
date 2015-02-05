#!/usr/bin/lua
--
-- Performs the Twitter app authorization procedure.
--
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"

-- load the app consumer keys from "oauth_app_keys"
-- you need to fill in valid app keys before using this script
local oauth_params = twitter.load_keys("oauth_app_keys")
local client = twitter.new(oauth_params)

-- First auth step: generate auth URL and obtain PIN
local auth_url = client:start_login()
print("-- auth url: " .. auth_url)

-- Second auth step: read the PIN and obtain access token
io.write("-- enter pin: ")
local pin = assert(io.read():match("%d+"), "invalid number")
local token, err = client:confirm_login(pin)
assert(token, err)

-- save the access token
print("-- logged in as " .. token.screen_name)
token:save("local_auth")
