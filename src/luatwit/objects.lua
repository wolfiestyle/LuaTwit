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

return _M
