#!/usr/bin/env lua
--
-- Simple GUI client built with GTK.
-- It uses the 'lgi' library (Gtk 3) for building the UI.
--
package.path = "../src/?.lua;" .. package.path
local twitter = require "luatwit"
local pretty = require "pl.pretty"
local lgi = require "lgi"
local Gtk = lgi.Gtk
local GLib = lgi.GLib
local Gdk = lgi.Gdk
local GdkPixbuf = lgi.GdkPixbuf

-- load twitter keys (TODO: make a gui for the auth process)
local oauth_params = twitter.load_keys("oauth_app_keys", "local_auth")
local client = twitter.api.new(oauth_params, 4)

-- create the main window
local window = Gtk.Window{
    title = "LuaTwit demo",
    default_width = 420,
    default_height = 600,
    on_destroy = Gtk.main_quit,
    Gtk.Box{
        orientation = Gtk.Orientation.VERTICAL,
        spacing = 3,
        Gtk.Notebook{
            id = "nbkPages",
            vexpand = true,
            { Gtk.ScrolledWindow{ Gtk.ListBox{ id = "lstHome", selection_mode = "NONE" } }, tab_label = "Home" },
            { Gtk.ScrolledWindow{ Gtk.ListBox{ id = "lstMentions", selection_mode = "NONE" } }, tab_label = "Mentions" },
            { Gtk.ScrolledWindow{ Gtk.ListBox{ id = "lstFavs", selection_mode = "NONE" } }, tab_label = "Favs" },
        },
        Gtk.InfoBar{ id = "ibMessage", show_close_button = true, no_show_all = true },
        Gtk.Box{
            spacing = 3,
            Gtk.Label{ id = "lblChars", label = "0", width_chars = 3 },
            Gtk.Entry{ id = "txtTweet", placeholder_text = "Send a tweet", max_length = 140, hexpand = true },
            Gtk.Button{ id = "cmdTweet", label = "Tweet" },
        },
    },
}

-- builds a tweet row widget
local function build_tweet_item(header, text, footer)
    local w = Gtk.Box{
        id = "main",
        spacing = 10,
        Gtk.Image{ id = "icon", width = 48, yalign = 0, ypad = 3 },
        Gtk.EventBox{
            id = "content",
            Gtk.Box{
                orientation = Gtk.Orientation.VERTICAL,
                hexpand = true,
                spacing = 5,
                Gtk.Label{ label = header, use_markup = true, xalign = 0, ellipsize = "END" },
                Gtk.Label{ label = text, use_markup = true, xalign = 0, vexpand = true, wrap = true, wrap_mode = "WORD_CHAR" },
                Gtk.Label{ label = footer, use_markup = true, xalign = 0, wrap = true, wrap_mode = "WORD_CHAR" },
            },
        },
    }
    w:show_all()
    return w
end

-- obtain the widget handles from their id's
local _ = window.child
local nbkPages,   lstHome,   lstMentions,   lstFavs,   ibMessage,   lblChars,   txtTweet,   cmdTweet =
    _.nbkPages, _.lstHome, _.lstMentions, _.lstFavs, _.ibMessage, _.lblChars, _.txtTweet, _.cmdTweet

-- setup the update button
local cmdUpdate = Gtk.Button.new_from_icon_name("view-refresh", Gtk.IconSize.SMALL_TOOLBAR)
cmdUpdate:show()
nbkPages:set_action_widget(cmdUpdate, Gtk.PackType.END)

-- setup the info bar
local lblInfoText = Gtk.Label()
lblInfoText:show()
ibMessage:get_content_area():add(lblInfoText)

local function ui_hide_info()
    ibMessage:hide()
end

-- displays a message in the info bar
local function ui_show_info(msg, is_error)
    lblInfoText:set_label(msg)
    ibMessage:set_message_type(is_error and Gtk.MessageType.ERROR or Gtk.MessageType.INFO)
    ibMessage:show()
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 3000, ui_hide_info)
end

-- handle the infobar builtin close button
function ibMessage:on_response(resp_id)
    if resp_id == Gtk.ResponseType.CLOSE then
        ui_hide_info()
    end
end

-- compares two string ids (twitter id's are too big for Lua, we use id_str)
local function strnum_cmp(a, b)
    if a == b then return 0 end
    local la, lb = a:len(), b:len()
    if la ~= lb then return la - lb end
    return a > b and 1 or -1
end

local row_ids = {}

-- setup the ListBox sort functions
local function listbox_sort_func(ra, rb)
    local a = row_ids[ra:get_child()]
    local b = row_ids[rb:get_child()]
    return strnum_cmp(b, a)
end

lstHome:set_sort_func(listbox_sort_func)
lstMentions:set_sort_func(listbox_sort_func)
lstFavs:set_sort_func(listbox_sort_func)

local function escape_amp(text)
    return text:gsub("&", "&amp;")
end

-- pango processes HTML entities before anything else, so must escape all the &'s, even in the URL
local function pango_link(text, url)
    return ('<a href="%s">%s</a>'):format(escape_amp(url), escape_amp(text))
end

-- replaces t.co url's with links from entities
local function parse_entities(tweet, with_links)
    local urls = {}
    local fmt = with_links and pango_link or function(x) return x end
    for _, item in ipairs(tweet.entities.urls) do
        local key = item.url:match "https?://t%.co/(%w+)"
        urls[key] = fmt(item.display_url, item.expanded_url)
    end
    if tweet.entities.media then
        for _, item in ipairs(tweet.entities.media) do
            local key = item.url:match "https?://t%.co/(%w+)"
            urls[key] = fmt(item.display_url, item.expanded_url)
        end
    end
    return tweet.text:gsub("https?://t%.co/(%w+)", urls)
end

-- extracts and formats the relevant information from a tweet
local function parse_tweet(tweet, text_only)
    local header, footer = {}, {}
    if tweet.retweeted_status then
        if not text_only then
            header[1] = "🔃" -- symbol for retweets
            local f = "retweeted by @" .. tweet.user.screen_name
            if tweet.retweet_count > 1 then
                f = f .. " and " .. tweet.retweet_count .. " others"
            end
            footer[1] = f
        end
        tweet = tweet.retweeted_status
    end
    if text_only then
        return "<" .. tweet.user.screen_name .. "> " .. parse_entities(tweet)
    end
    header[#header + 1] = "<b>" .. tweet.user.screen_name .. "</b>"
    if tweet.user.protected then
        header[#header + 1] = "🔒" -- symbol for locked accounts
    end
    header[#header + 1] = '<span color="gray">' .. escape_amp(tweet.user.name) .. '</span>'
    if tweet.in_reply_to_screen_name then
        footer[#footer + 1] = "in reply to @" .. tweet.in_reply_to_screen_name
    end
    footer[#footer + 1] = "via " .. tweet.source:gsub('rel=".*"', '') -- it's a valid link, but pango chokes with the extra attribute
    return table.concat(header, " "),   -- header
           parse_entities(tweet, true), -- text
           '<small><span color="gray">' .. table.concat(footer, ", ") .. '</span></small>'  -- footer
end

-- generates the tooltip markup for an user
local function user_tooltip(user)
    local fmt = [[
<big><b>$screen_name</b></big>
<small>$statuses_count Tweets</small>

<b>Name:</b> $name
<b>Location:</b> $location
<b>Bio:</b> $description
<b>Followers:</b> $followers_count <b>Following:</b> $friends_count <b>Listed:</b> $listed_count]]
    return escape_amp(fmt:gsub("$([%w_]+)", user))
end

-- create a Pixbuf from image data
local function pixbuf_from_image_data(data)
    local loader = GdkPixbuf.PixbufLoader()
    loader:write(data)
    loader:close()
    return loader:get_pixbuf()
end

local avatar_store = {}
local avatar_pending = {}

-- requests user avatars
local function ui_request_avatar(item, user)
    local url = user.profile_image_url
    local image = avatar_store[url]
    if image then
        item.child.icon:set_from_pixbuf(image)
        return
    end
    item.child.icon:set_from_icon_name("image-loading", Gtk.IconSize.DIALOG)
    -- request already sent
    if image == false then
        local pending = avatar_pending[url]
        pending[#pending + 1] = item
        return
    end
    -- first request
    avatar_store[url] = false
    avatar_pending[url] = { item }
    client:http_request{
        url = url,
        _callback = function(data, code)
            if code == 200 then
                local pb = pixbuf_from_image_data(data)
                avatar_store[url] = pb
                for _, w in ipairs(avatar_pending[url]) do
                    w.child.icon:set_from_pixbuf(pb)
                end
            else
                avatar_store[url] = nil
                for _, w in ipairs(avatar_pending[url]) do
                    w.child.icon:set_from_icon_name("image-missing", Gtk.IconSize.DIALOG)
                end
            end
            avatar_pending[url] = nil
        end
    }
end

local seen_tweets = {}

local build_tweet_menu

-- displays the popup menu for a tweet
local function event_tweet_clicked(self, ev)
    if ev:triggers_context_menu() then
        local item = self:get_parent()   -- content -> main
        local tweet = seen_tweets[row_ids[item]]
        local menu = build_tweet_menu(tweet, item)
        menu:popup(nil, nil, nil, nil, ev.button, ev.time)
    end
end

local added_to_list = {}

-- adds a tweet to the specified ListBox
local function ui_append_tweet(list, tweet)
    local id_str = tweet.id_str
    seen_tweets[id_str] = tweet
    if not added_to_list[list] then
        added_to_list[list] = {}
    end
    if not added_to_list[list][id_str] then
        added_to_list[list][id_str] = true
        local item = build_tweet_item(parse_tweet(tweet))
        row_ids[item] = id_str
        item.child.content.on_button_press_event = event_tweet_clicked
        local user = tweet.retweeted_status and tweet.retweeted_status.user or tweet.user
        item.child.icon:set_tooltip_markup(user_tooltip(user))
        ui_request_avatar(item, user)
        list:add(item)
    end
end

-- removes a tweet from the specified ListBox
local function ui_remove_tweet(list, tweet)
    local id_str = tweet.id_str
    for item, id in pairs(row_ids) do
        if id == id_str then
            if added_to_list[list][id] then
                item:get_parent():destroy() -- delete the ListBoxRow
                row_ids[item] = nil
                added_to_list[list][id] = nil
                return true
            end
        end
    end
end

local replying_tweet

-- enables reply mode
local function ui_set_reply_to(tweet)
    replying_tweet = tweet
    cmdTweet:set_label("Reply")
    txtTweet:set_text("@" .. tweet.user.screen_name .. " ")
    txtTweet:grab_focus()
end

local function copy_to_clipboard(text)
    local clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard:set_text(text, -1)
end

-- builds the tweet popup menu
function build_tweet_menu(tweet, item)
    local menu = Gtk.Menu{
        Gtk.MenuItem{ id = "reply", label = "Reply" },
        Gtk.MenuItem{ id = "fav", label = tweet.favorited and "Un-favorite" or "Favorite" },
        Gtk.MenuItem{ id = "rt", label = "Retweet" },
        Gtk.SeparatorMenuItem(),
        Gtk.MenuItem{ id = "copy", label = "Copy text" },
        Gtk.MenuItem{ id = "dump", label = "Copy raw data" },
    }

    function menu.child.reply:on_activate()
        ui_set_reply_to(tweet)
    end
    function menu.child.fav:on_activate()
        if tweet.favorited then
            tweet:unset_favorite{
                _callback = function(tw)
                    ui_show_info("Successfully removed from favorites")
                    ui_remove_tweet(lstFavs, tweet)
                    seen_tweets[tw.id_str] = tw
                end
            }
        else
            tweet:set_favorite{
                _callback = function(tw)
                    ui_show_info("Successfully added to favorites")
                    ui_append_tweet(lstFavs, tw)
                end
            }
        end
    end
    function menu.child.rt:on_activate()
        tweet:retweet{
            _callback = function(tw)
                ui_show_info("Successfully retweeted " .. tw.user.screen_name)
            end
        }
    end
    function menu.child.copy:on_activate()
        copy_to_clipboard(parse_tweet(tweet, true))
    end
    function menu.child.dump:on_activate()
        copy_to_clipboard(pretty.write(tweet))
    end

    menu:show_all()
    return menu
end

local function ui_reset_entry()
    txtTweet:set_text ""
    lblChars:set_text "0"
    cmdTweet:set_label "Tweet"
    replying_tweet = nil
end

-- event for handling the Enter key
function txtTweet:on_activate()
    local text = self:get_text()
    if replying_tweet then
        replying_tweet:reply{
            status = text,
            _callback = function(tweet)
                ui_reset_entry()
                ui_show_info("Replied to " .. tweet.in_reply_to_screen_name)
                ui_append_tweet(lstHome, tweet)
            end
        }
        return
    end
    client:tweet{
        status = text,
        _callback = function(tweet)
            ui_reset_entry()
            ui_show_info("Tweet sent")
            ui_append_tweet(lstHome, tweet)
        end
    }
end

function cmdTweet:on_clicked()
    txtTweet:activate()
end

-- clear entry when pressing Esc
function txtTweet:on_key_press_event(ev)
    if ev.keyval == 0xff1b then
        ui_reset_entry()
    end
end

-- event for displaying the char count
function txtTweet:on_key_release_event(ev)
    lblChars:set_text(self:get_text_length())
end

-- adds the content of a tweet list to the specified ListBox
local function ui_append_tweet_list(list, tl)
    for _, tweet in ipairs(tl) do
        ui_append_tweet(list, tweet)
    end
end

-- defines how to fill in the pages
local pages = {
    { method = "get_home_timeline", list = lstHome },
    { method = "get_mentions",      list = lstMentions },
    { method = "get_favorites",     list = lstFavs },
}

-- updates the timeline on the specified page
local function ui_update_page(id)
    local page = pages[id]
    local args = {
        count = 50,
        since_id = page.last_id,
        _callback = function(tl)
            if #tl == 0 then return end
            page.last_id = tl[1].id_str -- assuming the first tweet is the newest one
            ui_append_tweet_list(page.list, tl)
        end
    }
    client[page.method](client, args)
end

-- event for manually updating the timelines
function cmdUpdate:on_clicked()
    local page = nbkPages:get_current_page()
    ui_update_page(page + 1)
end

-- pending requests will be stored here
local requests = {}

-- checks if any of the requests are done and dispatches the callbacks
local function update_requests()
    local n = #requests
    while n > 0 do
        local fut, callback = unpack(requests[n])
        local ready, res, hdr = fut:peek()
        if ready then
            table.remove(requests, n)
            if res == nil then  -- error
                ui_show_info(tostring(hdr), true)
            else
                callback(res, hdr)
            end
        end
        n = n - 1
    end
    return #requests > 0
end

-- setups a callback handler for interacting with the Gtk event loop
client:set_callback_handler(function(fut, cb)
    local n = #requests
    requests[n + 1] = { fut, cb }
    if n == 0 then
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 200, update_requests)
    end
end)

-- auto update every 1.5 minutes (10 req per 15 mins)
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000 * 60 * 1.5, function()
    ui_update_page(1)
    ui_update_page(2)
    return true
end)

-- fill in the timelines
ui_update_page(1)
ui_update_page(2)
ui_update_page(3)

-- enter the main loop
window:show_all()
Gtk.main()
