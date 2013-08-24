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

function get_resource_by_url(url)
    for name, decl in pairs(twitter.resources) do
        if decl[2] == url then
            return setmetatable({ name = name, decl = decl }, table_inspect_mt)
        end
    end
    return nil
end

oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
client = twitter.new(oauth_params)

client.raw_call = function(...)
    local json, status_line, res_code, headers = twitter.api.raw_call(...)
    util.bless(json, table_inspect_mt)
    return json, status_line, res_code, headers
end
