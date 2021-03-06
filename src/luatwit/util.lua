--- Misc utility functions provided by the `luatwit` library.
--
-- @module  luatwit.util
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local error, io_lines, io_open, ipairs, select, setmetatable, type =
      error, io.lines, io.open, ipairs, select, setmetatable, type

local _M = {}

--- Gets the type of the supplied object.
--
-- @param obj       Any value.
-- @return          The `_type` field if it's a table. If not present or not a table, the Lua type.
function _M.type(obj)
    local t_obj = type(obj)
    return t_obj == "table" and obj._type or t_obj
end

--- Reads a simple `key = value` style config file.
--
-- @param filename  File to be read.
-- @return          Table with the config values.
function _M.read_config(filename)
    local cfg = {}
    local n = 1
    for line in io_lines(filename) do
        if line:sub(1, 1) ~= "#" then
            local k, v = line:match "^%s*([^%s=]+)%s*=%s*(.*)"
            if not k then
                error("error parsing config at line " .. n)
            end
            cfg[k] = v
        end
        n = n + 1
    end
    return cfg
end

local oauth_key_names = { "consumer_key", "consumer_secret", "oauth_token", "oauth_token_secret" }

--- Helper to load OAuth keys from text files.
-- Key files are loaded as `key = value` pairs.
-- It also accepts tables as arguments (useful when using `require`).
--
-- @param ...   Filenames (config files) or tables with the keys to load.
-- @return      Table with the keys found.
function _M.load_keys(...)
    local keys = {}
    for i = 1, select('#', ...) do
        local source = select(i, ...)
        local ts = type(source)
        if ts == "string" then
            source = _M.read_config(source)
        elseif ts == "nil" then
            source = {}
        elseif ts ~= "table" then
            error("argument #" .. i .. ": invalid type " .. ts, 2)
        end
        for _, k in ipairs(oauth_key_names) do
            local v = source[k]
            if v ~= nil then
                keys[k] = v
            end
        end
    end
    return keys
end

--- Loads a file and prepares it for a multipart request.
--
-- @param filename  File to be read.
-- @return          On success, a table with the file contents. On error `nil`.
-- @return          The error message in case of failure.
-- @see luatwit.resources.upload_media
function _M.attach_file(filename)
    local file, err = io_open(filename, "rb")
    if file == nil then
        return nil, err
    end
    local res = {
        filename = filename:match "[^/]*$",
        data = file:read "*a",
    }
    file:close()
    return res
end

--- Compares two string ids (id_str fields).
--
-- @param a         First id_str to compare.
-- @param b         Second id_str to compare.
-- @return          0 if both are equal, 1 if `a > b` or -1 if `a < b`.
function _M.id_cmp(a, b)
    if a == b then return 0 end
    local dl = #a - #b
    if dl ~= 0 then return dl > 0 and 1 or -1 end
    return a > b and 1 or -1
end

--- Operator `<` for string ids (id_str fields).
--
-- @param a         First id_str to compare.
-- @param b         Second id_str to compare.
-- @return          `true` if a < b, otherwise `false`.
function _M.id_lt(a, b)
    if a == b then return false end
    local dl = #a - #b
    if dl ~= 0 then return dl < 0 end
    return a < b
end

-- identity function
local function ident(...) return ... end

--- A pipeline of functions.
-- It composes all functions added to it, forming a call chain.
-- @type pipe
local pipe = {}
pipe.__index = pipe
_M.pipe = pipe

--- Creates a new pipe
--
-- @return          New pipe object.
function pipe.new()
    return setmetatable({ chain = ident }, pipe)
end

--- Appends a new function to the pipe.
--
-- @param f         Function to be composed with the current chain.
-- @return          The current pipe object with an updated chain.
function pipe:add(f)
    local g = self.chain
    self.chain = g == ident and f or function(...) return f(g(...)) end
    return self
end

--- Calls the function chain stored in the pipe.
--
-- @param ...       Arguments for the first function in the chain.
-- @return          The result of the last function.
function pipe:__call(...)
    return self.chain(...)
end

return _M
