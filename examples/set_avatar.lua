#!/usr/bin/env lua
--
-- Changes the user's avatar with the file passed as argument.
--
local cfg = require "_config"()
local twitter = require "luatwit"
local util = require "luatwit.util"
local base64 = require "base64"

-- get filename from argument
local filename = select(1, ...)
assert(filename, "missing argument")

-- initialize the twitter client
local oauth_params = util.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- read image file
local file, err = io.open(filename)
assert(file, err)
local img_data = file:read("*a")
file:close()

-- avatar must be sent as base64 encoded data
local user, err = client:set_profile_image{ image = base64.encode(img_data) }

-- the second return value contains the error if something went wrong
assert(user, tostring(err))

print("user: @" .. user.screen_name .. " (" .. user.name .. ")")
print("avatar image: " .. user.profile_image_url)

