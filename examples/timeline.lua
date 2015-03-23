#!/usr/bin/env lua
--
-- Prints the home timeline.
--
local cfg = require "_config"()
local twitter = require "luatwit"
local util = require "luatwit.util"

-- initialize the twitter client
local oauth_params = util.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- retrieve the timeline
local tl, err = client:get_home_timeline()
assert(tl, tostring(err))

-- print the tweets in reverse order (easier to read in console)
for i = #tl, 1, -1 do
    local tweet = tl[i]
    local rt, footer = "", {}
    if tweet.retweeted_status then
        rt = "[RT] "
        local f = "retweeted by @" .. tweet.user.screen_name
        if tweet.retweet_count > 1 then
            f = f .. " and " .. tweet.retweet_count .. " others"
        end
        footer[1] = f
        tweet = tweet.retweeted_status
    end
    if tweet.in_reply_to_screen_name then
        footer[#footer + 1] = "in reply to @" .. tweet.in_reply_to_screen_name
    end
    footer[#footer + 1] = "via " .. tweet.source:match(">(.+)</a>$")
    local text = tweet.text:gsub("&(%a+);", { lt = "<", gt = ">", amp = "&" })

    print(string.format("%s@%s (%s)", rt, tweet.user.screen_name, tweet.user.name))
    print(text)
    print("> " .. table.concat(footer, ", ") .. "\n")
end
