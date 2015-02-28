#!/usr/bin/env lua
--
-- Performs the Twitter app authorization procedure.
--
local cfg = require "_config"(true)
local twitter = require "luatwit"

-- load the app consumer keys from "~/.config/luatwit/oauth_app_keys"
-- you need to fill in valid app keys before using this script
local oauth_params = twitter.load_keys(cfg.app_keys)
local client = twitter.api.new(oauth_params)

-- First auth step: obtain a temporary request token
client:oauth_request_token()

-- Second auth step: display the auth URL so the user can obtain a PIN
print("-- auth url: " .. client:oauth_authorize_url())
io.write("-- enter pin: ")
local pin = assert(io.read():match("%d+"), "invalid number")

-- Third auth step: use the PIN to obtain an access token
local token, err = client:oauth_access_token{ oauth_verifier = pin }
assert(token, err)

-- save the access token
print("-- logged in as " .. token.screen_name)
token:save(cfg.user_keys)
