#!/usr/bin/lua
--
-- Changes the user's avatar with the file passed as argument.
--
pcall(require, "luarocks.loader")
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"
local base64 = require "base64"

-- get filename from argument
local filename = select(1, ...)
assert(filename, "missing argument")

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.new(oauth_params)

-- read image file
local file, err = io.open(filename)
assert(file, err)
local img_data = file:read("*a")
file:close()

-- avatar must be sent as base64 encoded data
local user = client:set_profile_image{ image = base64.encode(img_data) }
print("user: @" .. user.screen_name .. " (" .. user.name .. ")")
print("avatar image: " .. user.profile_image_url)

