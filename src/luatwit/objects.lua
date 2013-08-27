--- Metatables used to create objects from the data returned by the Twitter API.
--
-- @module  luatwit.objects
-- @license MIT
local assert, io_open =
      assert, io.open

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
_M.user = new_type{ status = "tweet" }

--- List of `user` objects.
_M.user_list = new_type("user")

--- Cursor of `user` objects.
_M.user_cursor = new_type{ users = "user_list" }

--- Tweet object.
_M.tweet = new_type{ user = "user" }

--- List of `tweet` objects.
_M.tweet_list = new_type("tweet")

--- Results of a `tweet` search.
_M.tweet_search = new_type{ statuses = "tweet_list" }

--- Direct message object.
_M.dm = new_type{ recipient = "user", sender = "user" }

--- List of `dm` objects.
_M.dm_list = new_type("dm")

--- OEmbed output.
_M.oembed = new_type()

--- List of user ids.
_M.userid_list = new_type()

--- Cursor of user ids.
_M.userid_cursor = new_type{ ids = "userid_list" }

--- Follow relation between the authenticated user and another one.
_M.friendship = new_type()

--- List of `friendship` objects.
_M.friendship_list = new_type("friendship")

--- Follow relation between two users.
_M.relationship = new_type()

--- Contains a single `relationship` object.
_M.relationship_container = new_type{ relationship = "relationship" }

--- Account settings info.
_M.account_settings = new_type{ trend_location = "trend_location" }

--- Profile banner.
_M.profile_banner = new_type()

--- Suggestion category.
_M.suggestion_category = new_type{ users = "user_list" }

--- List of `suggestion_category` objects.
_M.suggestion_category_list = new_type("suggestion_category")

--- User list.
_M.userlist = new_type{ user = "user" }

--- List of `userlist` objects.
_M.userlist_list = new_type("userlist")

--- Cursor of `userlist` objects.
_M.userlist_cursor = new_type{ lists = "userlist_list" }

--- Saved search object.
_M.saved_search = new_type()

--- List of `saved_search` objects.
_M.saved_search_list = new_type("saved_search")

--- Place object.
_M.place = new_type()

--- List of `place` objects.
_M.place_list = new_type("place")

--- Container of a `place` search with query info.
_M.place_search = new_type{ result = "place_search_result" }

--- Results of a `place` search.
_M.place_search_result = new_type{ places = "place_list" }

--- Trends object.
_M.trends = new_type{ trends = "trends_elem_list", locations = "trend_location_list" }

--- Container of a `trends` object.
_M.trends_list = new_type("trends")

--- Trending item.
_M.trends_elem = new_type()

--- List of `trends_elem` objects.
_M.trends_elem_list = new_type("trends_elem")

--- Location info for trends.
_M.trend_location = new_type()

--- List of `trend_location` objects.
_M.trend_location_list = new_type("trend_location")

--- Service config info.
_M.service_config = new_type()

--- Language description.
_M.language = new_type()

--- List of `language` objects.
_M.language_list = new_type("language")

--- Privacy policy.
_M.privacy = new_type()

--- Terms of service.
_M.tos = new_type()

--- Rate limit info.
_M.rate_limit = new_type()

-- fill in the _type field
for name, obj in pairs(_M) do
    obj._type = name
end

return _M
