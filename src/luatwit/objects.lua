--- Metatables used to create objects from the data returned by the Twitter API.
--
-- @module  luatwit.objects
-- @license MIT
local assert, io_open, ipairs, pairs, setmetatable, table_concat, type =
      assert, io.open, ipairs, pairs, setmetatable, table.concat, type
local util = require "luatwit.util"
local json = require "cjson"

local _M = {}

-- Creates a new type table.
local function new_type(subtypes)
    local self = {
        _subtypes = subtypes,
    }
    self.__index = self
    return self
end

--- Access token returned by `luatwit.api:confirm_login`.
-- It's the result of the user authorizing the app, and contains the keys necessary to make API calls.
_M.access_token = new_type()

--- Saves the content of an `access_token` object into a file.
-- The output file can be loaded with `luatwit.load_keys`.
--
-- @param filename  Name of the destination file.
-- @return          The `access_token` itself.
function _M.access_token:save(filename)
    local file, err = io_open(filename, "w")
    assert(file, err)
    for k, v in pairs(self) do
        if not k:match("^oauth") then
            k = "--" .. k
        end
        file:write(k, ' = "', v, '"\n');
    end
    file:close()
    return self
end

--- HTTP Headers returned by the API calls.
_M.headers = new_type()

--- Extracts the rate limit info from the HTTP headers.
--
-- @return          Table with rate limit values.
function _M.headers:get_rate_limit()
    return {
        remaining = self["x-rate-limit-remaining"],
        limit = self["x-rate-limit-limit"],
        reset = self["x-rate-limit-reset"],
    }
end

--- Error description returned by the API calls.
_M.error = new_type()

--- Returns the error message.
--
-- @return          Error string.
function _M.error:__tostring()
    return self.errors[1].message
end

--- Returns the numeric error code.
--
-- @return          Error code.
function _M.error:code()
    return self.errors[1].code
end

--- User object.
-- @type user
_M.user = new_type{ status = "tweet", entities = "entities" }

-- Calls an API method referencing this user.
local function user_method(self, fn, args)
    args = args or {}
    args.user_id = self.id_str
    local client = self._client
    return client[fn](client, args)
end

--- Gets a list of tweets posted by this user.
--
-- @param args      Extra arguments for the `resources.get_user_timeline` API method.
-- @return          A `tweet_list` object.
function _M.user:get_tweets(args)
    return user_method(self, "get_user_timeline", args)
end

--- Sends a DM to this user.
--
-- @param args      Extra arguments for the `resources.send_dm` API method.
-- @return          A `dm` object.
function _M.user:send_dm(args)
    return user_method(self, "send_dm", args)
end

--- Gets the users this user follows.
--
-- @param args      Extra arguments for the `resources.get_following` API method.
-- @return          An `user_cursor` object.
function _M.user:get_following(args)
    return user_method(self, "get_following", args)
end

--- Gets the followers of this user.
--
-- @param args      Extra arguments for the `resources.get_followers` API method.
-- @return          An `user_cursor` object.
function _M.user:get_followers(args)
    return user_method(self, "get_followers", args)
end

--- Gets the users this user follows as a list of ids.
--
-- @param args      Extra arguments for the `resources.get_following_ids` API method.
-- @return          An `userid_cursor` object.
function _M.user:get_following_ids(args)
    return user_method(self, "get_following_ids", args)
end

--- Gets the followers of this user as a list of ids.
--
-- @param args      Extra arguments for the `resources.get_followers_ids` API method.
-- @return          An `userid_cursor` object.
function _M.user:get_followers_ids(args)
    return user_method(self, "get_followers_ids", args)
end

--- Follows this user.
--
-- @param args      Extra arguments for the `resources.follow` API method.
-- @return          An `user` object.
function _M.user:follow(args)
    return user_method(self, "follow", args)
end

--- Unfollows this user.
--
-- @param args      Extra arguments for the `resources.unfollow` API method.
-- @return          An `user` object.
function _M.user:unfollow(args)
    return user_method(self, "unfollow", args)
end

--- Sets the follow settings of this user.
--
-- @param args      Extra arguments for the `resources.set_follow_settings` API method.
-- @return          A `relationship_container` object.
function _M.user:set_follow_settings(args)
    return user_method(self, "set_follow_settings", args)
end

--- Blocks this user.
--
-- @param args      Extra arguments for the `resources.block_user` API method.
-- @return          An `user` object.
function _M.user:block(args)
    return user_method(self, "block_user", args)
end

--- Unblocks this user.
--
-- @param args      Extra arguments for the `resources.unblock_user` API method.
-- @return          An `user` object.
function _M.user:unblock(args)
    return user_method(self, "unblock_user", args)
end

--- Gets the profile banner of this user.
--
-- @param args      Extra arguments for the `resources.get_profile_banner` API method.
-- @return          A `profile_banner` object.
function _M.user:get_profile_banner(args)
    return user_method(self, "get_profile_banner", args)
end

--- Gets the favorites of this user.
--
-- @param args      Extra arguments for the `resources.get_favorites` API method.
-- @return          A `tweet_list` object.
function _M.user:get_favorites(args)
    return user_method(self, "get_favorites", args)
end

--- Gets all suscribed and own lists of this user.
--
-- @param args      Extra arguments for the `resources.get_all_lists` API method.
-- @return          An `userlist_list` object.
function _M.user:get_all_lists(args)
    return user_method(self, "get_all_lists", args)
end

--- Gets all suscribed lists of this user.
--
-- @param args      Extra arguments for the `resources.get_followed_lists` API method.
-- @return          An `userlist_cursor` object.
function _M.user:get_followed_lists(args)
    return user_method(self, "get_followed_lists", args)
end

--- Gets all own lists of this user.
--
-- @param args      Extra arguments for the `resources.get_own_lists` API method.
-- @return          An `userlist_cursor` object.
function _M.user:get_own_lists(args)
    return user_method(self, "get_own_lists", args)
end

--- Gets all lists following this user.
--
-- @param args      Extra arguments for the `resources.get_lists_following_user` API method.
-- @return          An `userlist_cursor` object.
function _M.user:get_lists_following_this(args)
    return user_method(self, "get_lists_following_user", args)
end

--- Checks if this user is following the specified list.
--
-- @param args      Extra arguments for the `resources.is_following_list` API method.
-- @return          An `user` object.
function _M.user:is_following_list(args)
    return user_method(self, "is_following_list", args)
end

--- Checks if this user is member of the specified list.
--
-- @param args      Extra arguments for the `resources.is_member_of_list` API method.
-- @return          An `user` object.
function _M.user:is_member_of_list(args)
    return user_method(self, "is_member_of_list", args)
end

--- Adds this user to the specified list.
--
-- @param args      Extra arguments for the `resources.add_list_member` API method.
-- @return          An `userlist` object.
function _M.user:add_to_list(args)
    return user_method(self, "add_list_member", args)
end

--- Reports this user as a spam account.
--
-- @param args      Extra arguments for the `resources.report_spam` API method.
-- @return          An `user` object.
function _M.user:report_spam(args)
    return user_method(self, "report_spam", args)
end

--- Gets the friendship status bewteen the authenticated user and this user.
--
-- @param args      Extra arguments for the `resources.get_friendship` API method.
-- @return          A `relationship_container` object.
function _M.user:get_friendship(args)
    args = args or {}
    args.target_id = self.id_str
    return self._client:get_friendship(args)
end

--- @section end

--- List of `user` objects.
_M.user_list = new_type("user")

--- Constructs an `userid_array` from this object.
--
-- @return          An `userid_array` object.
function _M.user_list:get_ids()
    local ids = {}
    for _, user in ipairs(self) do
        ids[#ids + 1] = user.id_str
    end
    return setmetatable(ids, self._client.objects.userid_array)
end

--- Cursor of `user` objects.
_M.user_cursor = new_type{ users = "user_list" }

--- Loads the next page of an user cursored request.
--
-- @return          Next `user_cursor` page, or <tt>nil</tt> if the current page is the last.
function _M.user_cursor:next()
    if self.next_cursor == 0 then return nil end
    return self._source_method{ cursor = self.next_cursor_str }
end

--- Loads the previous page of an user cursored request.
--
-- @return          Previous `user_cursor` page, or <tt>nil</tt> if the current page is the first.
function _M.user_cursor:prev()
    if self.previous_cursor == 0 then return nil end
    return self._source_method{ cursor = self.previous_cursor_str }
end

--- Tweet object.
-- @type tweet
_M.tweet = new_type{ user = "user", entities = "entities", retweeted_status = "tweet" }

-- Calls an API method referencing this tweet.
local function tweet_method(self, fn, args)
    args = args or {}
    args.id = self.id_str
    local client = self._client
    return client[fn](client, args)
end

--- Sends a tweet as a reply to this tweet.
--
-- @param args      Extra arguments for the `resources.tweet` API method.
--                  The reply must text is passed in the <tt>status</tt> field.
--                  If the <tt>_mention</tt> option is set, it will prepend the @screen_name to the reply text.
-- @return          A `tweet` object.
function _M.tweet:reply(args)
    assert(type(args) == "table" and args.status, "must provide reply text in 'status' argument")
    args.in_reply_to_status_id = self.id_str
    if args._mention then
        args.status = "@" .. self.user.screen_name .. " " .. args.status
    end
    return self._client:tweet(args)
end

--- Retweets this tweet.
--
-- @param args      Extra arguments for the `resources.retweet` API method.
-- @return          A `tweet` object.
function _M.tweet:retweet(args)
    return tweet_method(self, "retweet", args)
end

--- Delete this tweet.
--
-- @param args      Extra arguments for the `resources.delete_tweet` API method.
-- @return          A `tweet` object.
function _M.tweet:delete(args)
    return tweet_method(self, "delete_tweet", args)
end

--- Add this tweet to favorites.
--
-- @param args      Extra arguments for the `resources.set_favorite` API method.
-- @return          A `tweet` object.
function _M.tweet:set_favorite(args)
    return tweet_method(self, "set_favorite", args)
end

--- Remove this tweet from favorites.
--
-- @param args      Extra arguments for the `resources.unset_favorite` API method.
-- @return          A `tweet` object.
function _M.tweet:unset_favorite(args)
    return tweet_method(self, "unset_favorite", args)
end

--- Get a list of retweets of this tweet.
--
-- @param args      Extra arguments for the `resources.get_retweets` API method.
-- @return          A `tweet_list` object.
function _M.tweet:get_retweets(args)
    return tweet_method(self, "get_retweets", args)
end

--- Get a list of user ids who retweeted this tweet.
--
-- @param args      Extra arguments for the `resources.get_retweeter_ids` API method.
-- @return          An `userid_cursor` object.
function _M.tweet:get_retweeter_ids(args)
    return tweet_method(self, "get_retweeter_ids", args)
end

--- Generates an OEmbed object for this tweet.
--
-- @param args      Extra arguments for the `resources.oembed` API method.
-- @return          An `oembed` object.
function _M.tweet:oembed(args)
    return tweet_method(self, "oembed", args)
end

--- Get the next tweet in a conversation thread.
--
-- @param args      Extra arguments for the `resources.get_tweet` API method.
-- @return          A `tweet` object, or <tt>nil</tt> if this tweet is the first in the reply chain.
function _M.tweet:get_next_in_thread(args)
    local reply_id = self.in_reply_to_status_id_str
    if reply_id == nil or reply_id == json.null then return nil end
    args = args or {}
    args.id = reply_id
    return self._client:get_tweet(args)
end

--- @section end

--- List of `tweet` objects.
_M.tweet_list = new_type("tweet")

--- Results of a `tweet` search.
_M.tweet_search = new_type{ statuses = "tweet_list" }

--- Direct message object.
-- @type dm
_M.dm = new_type{ recipient = "user", sender = "user", entities = "entities" }

--- Sends a reply to this DM.
--
-- @param args      Extra arguments for the `resources.send_dm` API method.
-- @return          A `dm` object.
function _M.dm:reply(args)
    assert(type(args) == "table" and args.text, "must provide reply text in 'text' argument")
    args.user_id = self.sender_id_str
    return self._client:send_dm(args)
end

--- Deletes this DM.
--
-- @param args      Extra arguments for the `resources.delete_dm` API method.
-- @return          A `dm` object.
function _M.dm:delete(args)
    args = args or {}
    args.id = self.id_str
    return self._client:delete_dm(args)
end

--- @section end

--- List of `dm` objects.
_M.dm_list = new_type("dm")

--- Entities object.
_M.entities = new_type()

--- OEmbed output.
_M.oembed = new_type()

--- Returns the HTML result of the OEmbed response.
--
--- @return         HTML string.
function _M.oembed:__tostring()
    return self.html
end

--- List of user ids.
_M.userid_array = new_type()

--- Requests a list of users from the ids in this object.
--
-- @param args      Extra arguments for the `resources.lookup_users` API method.
-- @return          An `user_list` object.
function _M.userid_array:get_users(args)
    args = args or {}
    args.user_id = table_concat(self, ",")
    return self._client:lookup_users(args)
end

--- Returns the ids in this object as a string.
--
-- @return          A comma-separated list with the ids in this object.
function _M.userid_array:__tostring()
    return table_concat(self, ",")
end

--- Cursor of user ids.
_M.userid_cursor = new_type{ ids = "userid_array" }

--- Loads the next page of an user id cursored request.
--
-- @return          Next `userid_cursor` page, or <tt>nil</tt> if the current page is the last.
function _M.userid_cursor:next()
    if self.next_cursor == 0 then return nil end
    return self._source_method{ cursor = self.next_cursor_str }
end

--- Loads the previous page of an user id cursored request.
--
-- @return          Previous `userid_cursor` page, or <tt>nil</tt> if the current page is the first.
function _M.userid_cursor:prev()
    if self.previous_cursor == 0 then return nil end
    return self._source_method{ cursor = self.previous_cursor_str }
end

--- Follow relation between the authenticated user and another one.
_M.friendship = new_type()

--- Gets the user profile referenced by this object.
--
-- @param args      Extra arguments for the `resources.get_user` API method.
-- @return          An `user` object.
function _M.friendship:get_user(args)
    args = args or {}
    args.user_id = self.id_str
    return self._client:get_user(args)
end

--- List of `friendship` objects.
_M.friendship_list = new_type("friendship")

--- Follow relation between two users.
_M.relationship = new_type()

--- Gets the user profile referenced by the source field.
--
-- @param args      Extra arguments for the `resources.get_user` API method.
-- @return          An `user` object.
function _M.relationship:get_source_user(args)
    args = args or {}
    args.user_id = self.source.id_str
    return self._client:get_user(args)
end

--- Gets the user profile referenced by the target field.
--
-- @param args      Extra arguments for the `resources.get_user` API method.
-- @return          An `user` object.
function _M.relationship:get_target_user(args)
    args = args or {}
    args.user_id = self.target.id_str
    return self._client:get_user(args)
end

--- Contains a single `relationship` object.
_M.relationship_container = new_type{ relationship = "relationship" }

--- Account settings info.
_M.account_settings = new_type{ trend_location = "trend_location" }

--- Profile banner.
_M.profile_banner = new_type()

--- Suggestion category.
_M.suggestion_category = new_type{ users = "user_list" }

--- Gets the user list of this suggestion category.
--
-- @return          An `user_list` object.
function _M.suggestion_category:get_users()
    if self.users then return self.users end
    return self._client:get_suggestion_users{ slug = self.slug }
end

--- List of `suggestion_category` objects.
_M.suggestion_category_list = new_type("suggestion_category")

--- User list.
-- @type userlist
_M.userlist = new_type{ user = "user" }

-- Calls an API method referencing this user list.
local function userlist_method(self, fn, args)
    args = args or {}
    args.list_id = self.id_str
    local client = self._client
    return client[fn](client, args)
end

--- Gets the tweet timeline of this list.
--
-- @param args      Extra arguments for the `resources.get_list_timeline` API method.
-- @return          A `tweet_list` object.
function _M.userlist:get_tweets(args)
    return userlist_method(self, "get_list_timeline", args)
end

--- Gets the members of this list.
--
-- @param args      Extra arguments for the `resources.get_list_members` API method.
-- @return          An `user_cursor` object.
function _M.userlist:get_members(args)
    return userlist_method(self, "get_list_members", args)
end

--- Adds a member to this list.
--
-- @param args      Extra arguments for the `resources.add_list_member` API method.
-- @return          An `userlist` object.
function _M.userlist:add_member(args)
    return userlist_method(self, "add_list_member", args)
end

--- Removes a member from this list.
--
-- @param args      Extra arguments for the `resources.remove_list_member` API method.
-- @return          An `userlist` object.
function _M.userlist:remove_member(args)
    return userlist_method(self, "remove_list_member", args)
end

--- Adds multiple members to this list.
--
-- @param args      Extra arguments for the `resources.add_multiple_list_members` API method.
-- @return          An `userlist` object.
function _M.userlist:add_multiple_members(args)
    return userlist_method(self, "add_multiple_list_members", args)
end

--- Removes multiple members from this list.
--
-- @param args      Extra arguments for the `resources.remove_multiple_list_members` API method.
-- @return          An `userlist` object.
function _M.userlist:remove_multiple_members(args)
    return userlist_method(self, "remove_multiple_list_members", args)
end

--- Check if the specified user is a member of this list.
--
-- @param args      Extra arguments for the `resources.is_member_of_list` API method.
-- @return          An `user` object.
function _M.userlist:has_member(args)
    return userlist_method(self, "is_member_of_list", args)
end

--- Gets the followers of this list.
--
-- @param args      Extra arguments for the `resources.get_list_followers` API method.
-- @return          An `user_cursor` object.
function _M.userlist:get_followers(args)
    return userlist_method(self, "get_list_followers", args)
end

--- Follows this list.
--
-- @param args      Extra arguments for the `resources.follow_list` API method.
-- @return          An `userlist` object.
function _M.userlist:follow(args)
    return userlist_method(self, "follow_list", args)
end

--- Unfollows this list.
--
-- @param args      Extra arguments for the `resources.unfollow_list` API method.
-- @return          An `userlist` object.
function _M.userlist:unfollow(args)
    return userlist_method(self, "unfollow_list", args)
end

--- Updates this list.
--
-- @param args      Extra arguments for the `resources.update_list` API method.
-- @return          An `userlist` object.
function _M.userlist:update(args)
    return userlist_method(self, "update_list", args)
end

--- Deletes this list.
--
-- @param args      Extra arguments for the `resources.delete_list` API method.
-- @return          An `userlist` object.
function _M.userlist:delete(args)
    return userlist_method(self, "delete_list", args)
end

--- @section end

--- List of `userlist` objects.
_M.userlist_list = new_type("userlist")

--- Cursor of `userlist` objects.
_M.userlist_cursor = new_type{ lists = "userlist_list" }

--- Loads the next page of an user list cursored request.
--
-- @return          Next `userlist_cursor` page, or <tt>nil</tt> if the current page is the last.
function _M.userlist_cursor:next()
    if self.next_cursor == 0 then return nil end
    return self._source_method{ cursor = self.next_cursor_str }
end

--- Loads the previous page of an user list cursored request.
--
-- @return          Previous `userlist_cursor` page, or <tt>nil</tt> if the current page is the first.
function _M.userlist_cursor:prev()
    if self.previous_cursor == 0 then return nil end
    return self._source_method{ cursor = self.previous_cursor_str }
end

--- Saved search object.
_M.saved_search = new_type()

--- Performs a tweet search using the query on this saved search.
--
-- @param args      Extra arguments for the `resources.search_tweets` API method.
-- @return          A `tweet_search` object.
function _M.saved_search:do_search(args)
    args = args or {}
    args.q = self.query
    return self._client:search_tweets(args)
end

--- List of `saved_search` objects.
_M.saved_search_list = new_type("saved_search")

--- Place object.
_M.place = new_type()

--- List of `place` objects.
_M.place_list = new_type("place")

--- Container of a `place` search with query info.
_M.place_search = new_type{ result = "place_search_result" }

--- Creates a new place using the token returned by `resources.get_similar_places`.
--
-- @param args      Extra arguments for the `resources.create_place` API method.
-- @return          A `place` object.
function _M.place_search:create_place(args)
    args = args or {}
    args.token = self.result.token
    return self._client:create_place(args)
end

--- Results of a `place` search.
_M.place_search_result = new_type{ places = "place_list" }

--- Trending item.
_M.trend = new_type()

--- Returns the contents of a trending item.
--
-- @return          Trending topic string.
function _M.trend:__tostring()
    return self.name
end

--- Performs a tweet search using the query on this trending topic.
--
-- @param args      Extra arguments for the `resources.search_tweets` API method.
-- @return          A `tweet_search` object.
function _M.trend:do_search(args)
    args = args or {}
    args.q = self.query
    return self._client:search_tweets(args)
end

--- List of `trend` objects.
_M.trend_list = new_type("trend")

--- Trends container object.
_M.trends_container = new_type{ trends = "trend_list", locations = "trend_location_list" }

--- Contains a single `trends_container` object.
_M.trends_container_list = new_type("trends_container")

--- Location info for trends.
_M.trend_location = new_type()

--- Gets the trending topics for this location.
--
-- @param args      Extra arguments for the `resources.get_trends` API method.
-- @return          A `trends_container_list` object.
function _M.trend_location:get_trends(args)
    args = args or {}
    args.id = self.woeid
    return self._client:get_trends(args)
end

--- List of `trend_location` objects.
_M.trend_location_list = new_type("trend_location")

--- Service config info.
_M.service_config = new_type()

--- Language description.
_M.language = new_type()

--- Returns the language name.
--
-- @return          Language string.
function _M.language:__tostring()
    return self.name
end

--- List of `language` objects.
_M.language_list = new_type("language")

--- Privacy policy.
_M.privacy = new_type()

--- Returns the privacy policy content.
--
-- @return          Privacy policy string.
function _M.privacy:__tostring()
    return self.privacy
end

--- Terms of service.
_M.tos = new_type()

--- Returns the terms of service content.
--
-- @return          Terms of service string.
function _M.tos:__tostring()
    return self.tos
end

--- Rate limit info.
_M.rate_limit = new_type()

--- Get the rate limit info of the specified object.
--
-- @param obj       Endpoint URL, Resource declaration (`luatwit.resources` field) or API method (`luatwit.api` field).
-- @return          Table with rate limit info.
function _M.rate_limit:get_for(obj)
    local url
    local t_obj = util.type(obj)
    if t_obj == "string" then
        url = obj
    elseif t_obj == "api" then
        url = obj.url
    elseif t_obj == "resource" then
        url = obj[2]
    end
    assert(url, "invalid argument")
    for _, category in pairs(self.resources) do
        for name, item in pairs(category) do
            name = name:gsub("^/", "")
            if name == url then
                return item
            end
        end
    end
    return nil
end


-- fill in the _type field
for name, obj in pairs(_M) do
    obj._type = name
end

return _M
