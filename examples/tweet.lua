#!/usr/bin/env lua
--
-- Sends a tweet with the text in the command line arguments.
--
local cfg = require "_config"()
local lapp = require "pl.lapp"
local pretty = require "pl.pretty"
local twitter = require "luatwit"
local util = require "luatwit.util"

-- read tweet text from arguments
local args = lapp [[
Sends a tweet.
    -m,--media (default "")     Image file to be included with the tweet
    -c,--chunked (default "")   Upload file as chunked with specified mimetype
    -a,--alt (default "")       Set image alt text
    <text...>  (string)         Tweet text
]]

local msg = table.concat(args.text, " ")

local assert = _VERSION >= "Lua 5.3" and assert or function(val, ...)
    if val then return val, ... end
    error(tostring(select(1, ...)))
end

-- initialize the twitter client
local oauth_params = util.load_keys(cfg.app_keys, cfg.user_keys)
local client = twitter.api.new(oauth_params)

-- upload the file
local media
if args.media ~= "" then
    if args.chunked ~= "" then
        -- chunked upload
        print("reading file: " .. args.media)
        local file = io.open(args.media, "rb")
        local chunks, total = {}, 0
        while true do
            local buf = file:read(524288)
            if buf == nil then break end
            total = total + #buf
            chunks[#chunks + 1] = buf
        end
        file:close()
        print("upload INIT")
        local handle = assert(client:upload_media_chunked{
            command = "INIT",
            media_type = args.chunked,
            total_bytes = total,
        })
        pretty.dump(handle)
        for i, data in ipairs(chunks) do
            print(("upload APPEND %d/%d"):format(i, #chunks))
            assert(client:upload_media_chunked{
                command = "APPEND",
                media_id = handle.media_id_string,
                segment_index = i-1,
                media = { filename = "media", data = data },
            })
        end
        print("upload FINALIZE")
        media = assert(client:upload_media_chunked{ command = "FINALIZE", media_id = handle.media_id_string })
    else
        -- regular upload
        print("uploading file: " .. args.media)
        local img = assert(util.attach_file(args.media))
        media = assert(client:upload_media{ media = img })
        media._request = nil  -- don't print binary data to the tty
    end

    if args.alt ~= "" then
        print "setting alt text"
        assert(client:set_media_metadata{ media_id = media.media_id_string, alt_text = { text = args.alt } })
    end
end

-- send the tweet
local tw, err
if media then
    print("media = " .. pretty.write(media))
    tw, err = media:tweet{ status = msg }
else
    tw, err = client:tweet{ status = msg }
end

-- the second return value contains the error if something went wrong, or http headers on success
assert(tw, err)

-- the result is json data in a Lua table
print("user: @" .. tw.user.screen_name .. " (" .. tw.user.name .. ")")
print("text: " .. tw.text)
print("tweet id: " .. tw.id_str)

