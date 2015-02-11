#!/usr/bin/env lua
--
-- Sends a tweet with the text in the command line arguments.
--
package.path = "../src/?.lua;" .. package.path
local lapp = require "pl.lapp"
local twitter = require "luatwit"

-- read tweet text from arguments
local args = lapp [[
Sends a tweet.
    -m,--media (default "")     Image file to be included with the tweet
    <text...>  (string)         Tweet text
]]
local msg = table.concat(args.text, " ")

-- read the image file
local img_data
if args.media:len() > 0 then
    local file, err = io.open(args.media)
    assert(file, err)
    img_data = file:read("*a")
    file:close()
end

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.api.new(oauth_params)

-- send the tweet
local tw, headers
if img_data then
    tw, headers = client:tweet_with_media{
        status = msg,
        ["media[]"] = {
            filename = args.media:match("([^/]*)$"),
            data = img_data,
        },
    }
else
    tw, headers = client:tweet{ status = msg }
end

-- the second return value contains the error if something went wrong
assert(tw, tostring(headers))

-- the result is json data in a Lua table
print("user: @" .. tw.user.screen_name .. " (" .. tw.user.name .. ")")
print("text: " .. tw.text)
print("tweet id: " .. tw.id_str)

