#!/usr/bin/env lua
local https = require "ssl.https"
local htmlparser = require "htmlparser"
local pretty = require "pl.pretty"

local out_file = "api_desc"

local function get_interwebz(url)
    if not url:find "^https?://" then
        url = "https://dev.twitter.com" .. url
    end
    print("-- fetching " .. url)
    local body, status = https.request(url)
    assert(body ~= nil and status == 200, status)
    return htmlparser.parse(body)
end

local function strip_tags(str)
    return str:gsub("<[^>]*>", "")
end

-- get the index page
local home = get_interwebz "https://dev.twitter.com/rest/public"

-- extract the documentation links
local links = {}
for _, item in ipairs(home:select "a") do
    local href = item.attributes.href
    if href and href:find "/rest/reference" then
        local text = item:getcontent()
        local name = strip_tags(text):gsub("%s/%s", "/")
        links[name] = href
    end
end

-- fetch every doc page
local api_desc = {}
for name, url in pairs(links) do
    local doc = get_interwebz(url)
    for _, item in ipairs(doc:select "meta[name='description']") do
        local text = item.attributes.content
        api_desc[name] = text
    end
end

print("-- writing " .. out_file)
pretty.dump(api_desc, out_file)
