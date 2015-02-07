#!/usr/bin/lua -i
--
-- Interactive Lua session with a Twitter client logged in.
-- It uses pl.pretty to display the returned data.
--
package.path = "../src/?.lua;" .. package.path
pl = require "pl.import_into" ()
twitter = require "luatwit"
util = require "luatwit.util"
objects = require "luatwit.objects"

-- used to display raw json data
local table_inspect_mt = {}
table_inspect_mt.__index = table_inspect_mt

function table_inspect_mt:__tostring()
    return pl.pretty.write(self)
end

function table_inspect_mt:save(filename)
    filename = filename or "tw.out"
    pl.file.write(filename, tostring(self) .. "\n")
    return self
end

-- get a function name from the resource URL
function get_resource_by_url(url)
    for name, decl in pairs(twitter.resources) do
        if decl[2] == url then
            return setmetatable({ name = name, decl = decl }, table_inspect_mt)
        end
    end
    return nil
end

-- initialize the twitter client
oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
client = twitter.api.new(oauth_params)

-- used to display tweets
function client.objects.tweet:__tostring()
    return "<" .. self.user.screen_name .. "> " .. self.text
end

-- used to display DMs
function client.objects.dm:__tostring()
    return "<" .. self.sender.screen_name .. "> (to: " .. self.recipient.screen_name .. ") " .. self.text
end

-- used to display user profiles
local user_tmpl = pl.text.Template(
[[Name: @$screen_name ($name)
Bio: $description
Location: $location
Followers: $followers_count, Following: $friends_count, Listed: $listed_count
Tweets: $statuses_count
---
]])

function client.objects.user:__tostring()
    return user_tmpl:safe_substitute(self)
end

-- used to display object lists
local function list_tostring(self)
    return table.concat(pl.tablex.pairmap(function(k, v) return k .. ": " .. tostring(v) end, self), "\n") .. "\n"
end

-- add default __tostring methods to all objects
for name, _ in pairs(objects) do
    local obj = client.objects[name]
    if not obj.__tostring then
        obj.__tostring = name:match("_list$") and list_tostring or table_inspect_mt.__tostring
    end
    obj.save = obj.save or table_inspect_mt.save
end

-- avoid headers spam
client.objects.headers.__tostring = nil


