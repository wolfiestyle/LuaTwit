--- Metatables used to create objects from the data returned by the Twitter API.
--
-- @module  luatwit.objects
-- @license MIT
local assert, io_open, pairs, type =
      assert, io.open, pairs, type

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
_M.user = new_type{ status = "tweet", entities = "entities" }

--- List of `user` objects.
_M.user_list = new_type("user")

--- Cursor of `user` objects.
_M.user_cursor = new_type{ users = "user_list" }

--- Tweet object.
_M.tweet = new_type{ user = "user", entities = "entities", retweeted_status = "tweet" }

--- List of `tweet` objects.
_M.tweet_list = new_type("tweet")

--- Results of a `tweet` search.
_M.tweet_search = new_type{ statuses = "tweet_list" }

--- Direct message object.
_M.dm = new_type{ recipient = "user", sender = "user", entities = "entities" }

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

--- Cursor of user ids.
_M.userid_cursor = new_type{ ids = "userid_array" }

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

--- Trending item.
_M.trend = new_type()

--- Returns the contents of a trending item.
--
-- @return          Trending topic string.
function _M.trend:__tostring()
    return self.name
end

--- List of `trend` objects.
_M.trend_list = new_type("trend")

--- Trends container object.
_M.trends_container = new_type{ trends = "trend_list", locations = "trend_location_list" }

--- Contains a single `trends_container` object.
_M.trends_container_list = new_type("trends_container")

--- Location info for trends.
_M.trend_location = new_type()

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
    if type(obj) == "string" then
        url = obj
    elseif type(obj) == "table" then
        if obj._type == "api" then
            url = obj.url
        elseif obj._type == "resource" then
            url = obj[2]
        end
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
