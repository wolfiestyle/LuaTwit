#!/usr/bin/env lua
--
-- Prints an user's profile.
--
local cfg = require "_config"()
local twitter = require "luatwit"
local util = require "luatwit.util"

-- initialize the twitter client
local oauth_params = util.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- get an username from arguments
local username = select(1, ...)

local user, err
if username then
    -- get info about the specified user
    user, err = client:get_user{ screen_name = username }
else
    -- get info about the logged user
    user, err = client:verify_credentials()
end
assert(user, tostring(err))

-- print it
local profile = [[
Name: @$screen_name ($name)
Bio: $description
Location: $location
Followers: $followers_count, Following: $friends_count, Listed: $listed_count
Tweets: $statuses_count, Favs: $favourites_count
Member since: $created_at]]

print((profile:gsub("$([%w_]+)", user)))
