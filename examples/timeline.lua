#!/usr/bin/lua
--
-- Prints the home timeline.
--
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.api.new(oauth_params)

-- retrieve the timeline
local tl, err = client:get_home_timeline()
assert(tl, err)

-- print the tweets
for _, tweet in ipairs(tl) do
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

    print(rt .. ("@$screen_name ($name)"):gsub("$([%w_]+)", tweet.user))
    print(tweet.text)
    print("> " .. table.concat(footer, ", ") .. "\n")
end
