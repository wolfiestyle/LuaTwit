#!/bin/sh
_=[[
exec lua -i "$0" "$@"
]]
--
-- Interactive Lua session with a Twitter client logged in.
-- It uses pl.pretty and custom __tostring methods to display the returned data.
--
local cfg = require "_config"()
pl = require "pl.import_into" ()
pretty = pl.pretty
twitter = require "luatwit"
objects = require "luatwit.objects"

-- initialize the twitter client
oauth_params = twitter.load_keys(cfg.app_keys, cfg.user_keys)
client = twitter.api.new(oauth_params)

-- pretty print for resource items
client.resources._resource_base.__tostring = pl.pretty.write

-- pretty print for tweets
function client.objects.tweet:__tostring()
    return "<" .. self.user.screen_name .. "> " .. self.text
end

-- pretty print for DMs
function client.objects.dm:__tostring()
    return "<" .. self.sender.screen_name .. "> (to: " .. self.recipient.screen_name .. ") " .. self.text
end

-- pretty print for user profiles
local user_tmpl =
[[Name: @$screen_name ($name)
Bio: $description
Location: $location
Followers: $followers_count, Following: $friends_count, Listed: $listed_count
Tweets: $statuses_count
---]]
function client.objects.user:__tostring()
    return (user_tmpl:gsub("$([%w_]+)", self))
end

-- used to display object lists
local function list_tostring(self)
    local res = {}
    for i, item in ipairs(self) do
        res[#res + 1] = i .. ": " .. tostring(item)
    end
    return table.concat(res, "\n") .. "\n"
end

-- writes the contents of a table to a file
function table_save(tbl, filename)
    filename = filename or "tw.out"
    pretty.dump(tbl, filename)
    return tbl
end

-- add default __tostring methods to all objects
for name, _ in pairs(objects) do
    local obj = client.objects[name]
    if not obj.__tostring then
        obj.__tostring = name:match("_list$") and list_tostring or pretty.write
    end
    obj.save = obj.save or table_save
end

-- avoid headers spam
client.objects.headers.__tostring = nil

-- lists the keys of a table and the type of its values
function keys(obj)
    if type(obj) ~= "table" then
        print(tostring(obj) .. " = " .. type(obj))
        return
    end
    for k, v in pairs(obj) do
        print(tostring(k) .. " = " .. type(v))
    end
end

-- finds a resource item with the specified api path
function get_resource(path)
    for name, decl in pairs(client.resources) do
        if decl.path == path then
            return decl
        end
    end
end
