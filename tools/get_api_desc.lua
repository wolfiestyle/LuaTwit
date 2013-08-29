#!/usr/bin/lua
pcall(require, "luarocks.loader")
local pl = require "pl.import_into" ()
local https = require "ssl.https"

-- penlight 1.1 needs this
if not pl.xml.parsehtml then
    pl.xml.parsehtml = pl.xml.parse
end

-- get file from the interwebz
local html, err = https.request("https://dev.twitter.com/docs/api/1.1")
assert(html, err)

-- missing opening html tag on this page
if not html:match("<html>") then
    html = html:gsub("(<head>)", "<html>%1")
end

-- parse the html
local html = pl.xml.parsehtml(html)

-- find the descriptions in the html
local state, res, title, body = 0, {}
pl.xml.walk(html, false, function(tag, node)
    local class = node.attr.class
    if tag == "td" and class then
        if class:match("views%-field%-title") then
            state = 1
        elseif class:match("views%-field%-body") then
            state = 2
            if title == "GET statuses/firehose" then -- hack, this one is on second paragraph
                body = node[1]:match("^%s*.-%.%s*(.-%.)")
            else
                body = node[1]:match("^%s*(.-%.)")
            end
            res[title] = body
        end
    elseif tag == "a" and state == 1 then
        title = node[1]
        state = 0
    end
end)

-- save result
pl.pretty.dump(res, "api_desc")
