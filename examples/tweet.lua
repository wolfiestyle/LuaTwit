#!/usr/bin/env lua
--
-- Sends a tweet with the text in the command line arguments.
--
local cfg = require "_config"()
local lapp = require "pl.lapp"
local pretty = require "pl.pretty"
local twitter = require "luatwit"

-- read tweet text from arguments
local args = lapp [[
Sends a tweet.
    -m,--media (default "")     Image file to be included with the tweet
    <text...>  (string)         Tweet text
]]

local msg = table.concat(args.text, " ")
local img_file = args.media ~= "" and args.media or nil

-- initialize the twitter client
local oauth_params = twitter.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- send the tweet
local tw, err
if img_file then
    local media, err_ = client:upload_media{ media = assert(twitter.attach_file(img_file)) }
    assert(media, tostring(err_))
    media._request = nil  -- don't print binary data to the tty
    print("media = " .. pretty.write(media))
    tw, err = media:tweet{ status = msg }
else
    tw, err = client:tweet{ status = msg }
end

-- the second return value contains the error if something went wrong, or http headers on success
assert(tw, tostring(err))

-- the result is json data in a Lua table
print("user: @" .. tw.user.screen_name .. " (" .. tw.user.name .. ")")
print("text: " .. tw.text)
print("tweet id: " .. tw.id_str)

