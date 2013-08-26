#!/usr/bin/lua -i
--
-- Interactive Lua session with a Twitter client logged in.
-- It uses pl.pretty to display the returned data.
--
pcall(require, "luarocks.loader")
pl = require "pl.import_into" ()
package.path = "../src/?.lua;" .. package.path
twitter = require "luatwit"
util = require "luatwit.util"
--debug.traceback = require("StackTracePlus").stacktrace

-- used to display raw json data
local table_inspect_mt = {}
table_inspect_mt.__index = table_inspect_mt

function table_inspect_mt:__tostring()
    return pl.stringx.replace(pl.pretty.write(self), '"userdata: (nil)"', "json.null")
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

-- used to display tweets
function twitter.objects.tweet:__tostring()
    return self.user.screen_name .. "\t| " .. self.id_str .. " | " .. self.text
end

-- used to display user profiles
local user_tmpl = pl.text.Template(
[[Name: @$screen_name ($name)
Bio: $description
Location: $location
Followers: $followers_count, Following: $friends_count, Listed: $listed_count
Tweets: $statuses_count
]])

function twitter.objects.user:__tostring()
    return user_tmpl:safe_substitute(self)
end

-- used to display user/tweet lists
local function list_tostring(self)
    return table.concat(pl.tablex.map(tostring, self), "\n") .. "\n"
end

twitter.objects.user_list.__tostring = list_tostring
twitter.objects.tweet_list.__tostring = list_tostring

-- add default __tostring methods to all objects
for _, obj in pairs(twitter.objects) do
    obj.__tostring = obj.__tostring or table_inspect_mt.__tostring
    obj.save = obj.save or table_inspect_mt.save
end

oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
client = twitter.new(oauth_params)
