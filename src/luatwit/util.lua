--- Misc utility functions used by the `luatwit` library.
--
-- @module  luatwit.util
-- @license MIT
local assert, getmetatable, jit, loadfile, pairs, pcall, rawget, setfenv, setmetatable, type =
      assert, getmetatable, jit, loadfile, pairs, pcall, rawget, setfenv, setmetatable, type

local _M = {}

--- Create a new class prototype or instance.
--
-- @param base      Table used as a base class. Creates a new empty table if omitted.
-- @param mt        Metatable for the new class. Sets <tt>base</tt> as metatable if omitted.
--                  The <tt>__index</tt> metamethod of this table will be set to the <tt>base</tt> argument.
-- @return          New class table.
function _M.new(base, mt)
    local self = {}
    local mt = mt or self
    mt.__index = base
    return setmetatable(self, mt)
end

--- Converts a table into a class instance of the supplied type.
--
-- @param tbl       Table to be converted. If it's not a table it will be returned unmodified.
-- @param mt        Metatable that defines the type of the object.
-- @return          The <tt>table</tt> argument with <tt>type</tt> as it's metatable.
function _M.bless(tbl, mt)
    if type(tbl) ~= "table" then return tbl end
    assert(type(mt) == "table", "argument #2 must be a table")
    return setmetatable(tbl, mt)
end

--- Loads a Lua chunk from a file and executes it on it's own environment.
--
-- @param filename  Lua source file.
-- @param env       Environment used to run the code. Creates a new empty table if omitted.
-- @return          The environment where the code was executed.
-- @return          <tt>true</tt> if no errors found when executing the code.
-- @return          Value(s) returned by the Lua chunk, or the error message.
function _M.load_file(filename, env)
    env = env or {}
    local code, err = loadfile(filename, nil, env)
    if not code then
        return env, false, err
    end
    if setfenv and not jit then
        setfenv(code, env)
    end
    return env, pcall(code)
end

--- Creates a function object.
--
-- @param fn        Function.
-- @return          Table with the <tt>__call</tt> metamethod set to the provided function.
function _M.make_functor(fn)
    local self = {}
    self.__call = fn
    return setmetatable(self, self)
end

--- Gets the type of the supplied object or the _type value if present.
--
-- @param obj       Any value.
-- @return          The type of the supplied object.
function _M.type(obj)
    local t_obj = type(obj)
    if t_obj == "table" then
        return obj._type or t_obj
    else
        return t_obj
    end
end

local metamethods = {"__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__eq", "__lt", "__le", "__index", "__newindex", "__call", "__tostring"}

--- Inherits methamethods from one table to another by copying them.
--
-- @param dest      Destination table.
-- @param src       Source table.
function _M.inherit_mt(dest, src)
    for _, name in pairs(metamethods) do
        if dest[name] == nil then
            dest[name] = src[name]
        end
    end
end

--- Copies key-value pairs from one table to another and applies a function to the values.
-- @param dest      Destination table.
-- @param src       Source table.
-- @param fn        Function applied to values before assigning them.
--                  It's called as <tt>fn(value, key)</tt> for each key in <tt>src</tt>,
--                  then the result is assigned to <tt>dest[key]</tt>, unless it's <tt>nil</tt>.
-- @return          The <tt>dest</tt> argument.
function _M.map_copy(dest, src, fn)
    for k, v in pairs(src) do
        local res = fn(v, k)
        if res ~= nil then
            dest[k] = res
        end
    end
    return dest
end

--- Creates a lazy table that loads its contents on field access.
--
-- @param fn        Function that returns the table content.
--                  This function will be called on the first field read attempt.
--                  The returned table fields will be copied to this table.
-- @return          New lazy table.
function _M.lazy_loader(fn)
    return setmetatable({}, {
        __index = function(self, key)
            local obj = fn()
            for k, v in pairs(obj) do
                if rawget(self, k) == nil then
                    self[k] = v
                end
            end
            setmetatable(self, getmetatable(obj))
            return self[key]
        end
    })
end

return _M