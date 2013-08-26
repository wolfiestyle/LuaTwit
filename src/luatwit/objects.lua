--- Metatables used to create objects from the data returned by the Twitter API.
--
-- @module  luatwit.objects
-- @license MIT
local assert, io_open =
      assert, io.open

local _M = {}

-- Creates a new type table.
local function new_type(name, subtypes)
    local self = {
        _type = name,
        _subtypes = subtypes,
    }
    self.__index = self
    _M[name] = self
end

--- Access token returned by `luatwit.api:confirm_login`.
-- It's the result of the user authorizing the app, and contains the keys necessary to make API calls.
-- @type access_token
new_type("access_token")

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
new_type("error")

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

new_type("user", { status = "tweet" })

new_type("user_list", "user")

new_type("user_cursor", { users = "user_list" })

new_type("tweet", { user = "user" })

new_type("tweet_list", "tweet")

new_type("tweet_search", { statuses = "tweet_list" })

new_type("dm", { recipient = "user", sender = "user" })

new_type("dm_list", "dm")

new_type("oembed")

new_type("userid_list")

new_type("userid_cursor", { ids = "userid_list" })

new_type("friendship")

new_type("friendship_list", "friendship")

new_type("relationship")

new_type("relationship_container", { relationship = "relationship" })

new_type("account_settings", { trend_location = "trend_location" })

new_type("profile_banner")

new_type("suggestion_category", { users = "user_list" })

new_type("suggestion_category_list", "suggestion_category")

new_type("userlist", { user = "user" })

new_type("userlist_list", "userlist")

new_type("userlist_cursor", { lists = "userlist_list" })

new_type("saved_search")

new_type("saved_search_list", "saved_search")

new_type("place")

new_type("place_list", "place")

new_type("place_search", { result = "place_search_result" })

new_type("place_search_result", { places = "place_list" })

new_type("trends", { trends = "trends_elem_list", locations = "trend_location_list" })

new_type("trends_list", "trends")

new_type("trends_elem")

new_type("trends_elem_list", "trends_elem")

new_type("trend_location")

new_type("trend_location_list", "trend_location")

new_type("service_config")

new_type("language")

new_type("language_list", "language")

new_type("privacy")

new_type("tos")

new_type("rate_limit")

return _M
