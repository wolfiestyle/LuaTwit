#!/usr/bin/env lua
--
-- Reads data from a streaming API method.
--
local cfg = require "_config"()
local twitter = require "luatwit"
local pretty = require "pl.pretty"

-- initialize the twitter client
local oauth_params = twitter.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- open the streaming connection (must be async)
local stream = client:stream_user{ _async = true }

local function format_tweet(tweet)
    local rt = ""
    if tweet.retweeted_status then
        rt = "[RT] "
        tweet = tweet.retweeted_status
    end
    local text = tweet.text:gsub("&(%a+);", { lt = "<", gt = ">", amp = "&" })
    return string.format("%s<%s> %s" , rt, tweet.user.screen_name, text)
end

local function printf(fmt, ...)
    return print(fmt:format(...))
end

local n = 0

-- consume the stream data
while stream:is_active() do
    -- iterate over the received items
    for data in stream:iter() do
        local t_data = twitter.type(data)
        -- tweet
        if t_data == "tweet" then
            print(format_tweet(data))
        -- deleted tweet
        elseif t_data == "tweet_deleted" then
            printf("[tweet deleted] %s", data.delete.status.id_str)
        -- stream events (blocks, favs, follows, list operations, profile updates)
        elseif t_data == "stream_event" then
            local desc = ""
            local t_obj = twitter.type(data.target_object)
            if t_obj == "tweet" then
                desc = format_tweet(data.target_object)
            elseif t_obj == "userlist" then
                desc = data.target_object.full_name
            end
            printf("[%s] %s -> %s %s", data.event, data.source.screen_name, data.target.screen_name, desc)
        -- list of following user ids
        elseif t_data == "friend_list_str" then
            printf("[friend list] (%s users)", #data.friends_str)
        -- number sent when the option `delimited = "length"` is set
        elseif t_data == "number" then
            print("[size delimiter] " .. data)
        -- everything else
        else
            printf("[%s] %s", t_data, pretty.write(data))
        end
        n = n + 1
    end

    -- close the stream after receiving 100 messages
    if n > 100 then
        stream:close()
    end

    -- wait for data to arrive
    client.async:wait()
end
