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
-- @type access_token
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
-- @type error
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

_M.user = new_type{ status = "tweet" }

_M.user_list = new_type("user")

_M.user_cursor = new_type{ users = "user_list" }

_M.tweet = new_type{ user = "user" }

_M.tweet_list = new_type("tweet")

_M.tweet_search = new_type{ statuses = "tweet_list" }

_M.dm = new_type{ recipient = "user", sender = "user" }

_M.dm_list = new_type("dm")

_M.oembed = new_type()

_M.userid_list = new_type()

_M.userid_cursor = new_type{ ids = "userid_list" }

_M.friendship = new_type()

_M.friendship_list = new_type("friendship")

_M.relationship = new_type()

_M.relationship_container = new_type{ relationship = "relationship" }

_M.account_settings = new_type{ trend_location = "trend_location" }

_M.profile_banner = new_type()

_M.suggestion_category = new_type{ users = "user_list" }

_M.suggestion_category_list = new_type("suggestion_category")

_M.userlist = new_type{ user = "user" }

_M.userlist_list = new_type("userlist")

_M.userlist_cursor = new_type{ lists = "userlist_list" }

_M.saved_search = new_type()

_M.saved_search_list = new_type("saved_search")

_M.place = new_type()

_M.place_list = new_type("place")

_M.place_search = new_type{ result = "place_search_result" }

_M.place_search_result = new_type{ places = "place_list" }

_M.trends = new_type{ trends = "trends_elem_list", locations = "trend_location_list" }

_M.trends_list = new_type("trends")

_M.trends_elem = new_type()

_M.trends_elem_list = new_type("trends_elem")

_M.trend_location = new_type()

_M.trend_location_list = new_type("trend_location")

_M.service_config = new_type()

_M.language = new_type()

_M.language_list = new_type("language")

_M.privacy = new_type()

_M.tos = new_type()

_M.rate_limit = new_type()

-- fill in the _type field
for name, _ in pairs(_M) do
    _M[name]._type = name
end

return _M
