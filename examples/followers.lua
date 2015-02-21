#!/usr/bin/env lua
--
-- Lists the logged user's followers and finds new follows/unfollows.
--
local cfg = require "_config"()
local twitter = require "luatwit"
local pl_file = require "pl.file"
local tablex = require "pl.tablex"

-- initialize the twitter client
local oauth_params = twitter.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- get logged user info
local me, err = client:verify_credentials()
assert(me, tostring(err))
print("getting followers for: " .. me.screen_name)

-- get the followers cursor
local fw_cur, err = client:get_followers{ user_id = me.id_str, count = 100, skip_status = true }
assert(fw_cur, tostring(err))

local followers = {}

-- iterates the cursor
local pos = 0
repeat
    for i, user in ipairs(fw_cur.users) do
        followers[user.id_str] = user.screen_name
        print(pos + i .. ": " .. user.screen_name .. " (" .. user.name .. ")")
    end
    pos = pos + #fw_cur.users
    -- requests the next page
    fw_cur, err = fw_cur:next()
    assert(fw_cur ~= nil, tostring(err))
until not fw_cur

-- load saved follower list
local followers_file = cfg.config_dir .. "followers"
local file = pl_file.read(followers_file)

-- detect follower changes
if file then
    local old_followers = {}

    print "\n-- unfollows detected since last run:"
    for id, name in file:gmatch "(%d+)%s*=%s*([%w_]+)" do
        old_followers[id] = name
        if not followers[id] then
            print(name)
        end
    end

    print "\n-- new followers since last run:"
    for id, name in pairs(followers) do
        if not old_followers[id] then
            print(name)
        end
    end
end

-- save the followers file
assert(pl_file.write(followers_file, table.concat(tablex.pairmap(function(k, v) return k.." = "..v end, followers), "\n") .. "\n"))
