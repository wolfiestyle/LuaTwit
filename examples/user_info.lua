#!/usr/bin/env lua
--
-- Prints the logged user's profile.
--
local cfg = require "_config"()
local twitter = require "luatwit"

-- initialize the twitter client
local oauth_params = twitter.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- get info about the logged user
local user, err = client:verify_credentials()
assert(user, tostring(err))

-- print it
local profile = ([[
Name: @$screen_name ($name)
Bio: $description
Location: $location
Followers: $followers_count, Following: $friends_count, Listed: $listed_count
Tweets: $statuses_count]]):gsub("$([%w_]+)", user)

print(profile)
