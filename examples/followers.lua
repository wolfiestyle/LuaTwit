#!/usr/bin/lua
--
-- List the logged user's followers.
--
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"

-- initialize the twitter client
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.api.new(oauth_params)

-- get logged user info
local me, err = client:verify_credentials()
assert(me, tostring(err))
print("getting followers for: " .. me.screen_name)

-- get the followers cursor
local fw_cur, err = client:get_followers{ user_id = me.id_str, count = 100, skip_status = true }
assert(fw_cur, tostring(err))

-- iterates the cursor
local pos = 0
repeat
    for i, user in ipairs(fw_cur.users) do
        print(pos + i .. ": " .. user.screen_name .. " (" .. user.name .. ")")
    end
    pos = pos + #fw_cur.users
    -- requests the next page
    fw_cur, err = fw_cur:next()
    assert(fw_cur ~= nil, tostring(err))
until not fw_cur
