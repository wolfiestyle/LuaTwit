--- Misc utility functions used by the `luatwit` library.
--
-- @module  luatwit.util
-- @license MIT/X11
local assert, getmetatable, jit, loadfile, pairs, pcall, rawget, select, setfenv, setmetatable, table_concat, type =
      assert, getmetatable, jit, loadfile, pairs, pcall, rawget, select, setfenv, setmetatable, table.concat, type

local _M = {}

--- Create a new class prototype or instance.
--
-- @param base      Table used as a base class. Creates a new empty table if omitted.
-- @param mt        Metatable for the new class. Sets <tt>base</tt> as metatable if omitted.
--                  The <tt>__index</tt> metamethod of this table will be set to the <tt>base</tt> argument.
-- @return          New class table.
function _M.make_class(base, mt)
    local self = {}
    local mt = mt or self
    mt.__index = base
    return setmetatable(self, mt)
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

--- Creates a callable table.
--
-- @param fn        Function.
-- @return          Table with the <tt>__call</tt> metamethod set to the provided function.
function _M.make_callable(fn)
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

local metamethods = { "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__concat", "__len", "__eq", "__lt", "__le", "__index", "__newindex", "__call", "__tostring", "__pairs", "__ipairs" }

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
    if not fn then
        fn = function(v) return v end
    end
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

--- Creates a set table from the keys in the arguments.
--
-- @param ...       Keys of the table. The values will be set to <tt>true</tt>.
-- @return          New set table.
function _M.make_set(...)
    local tbl = {}
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        tbl[key] = true
    end
    return tbl
end

local function build_args_str(rules)
    local res = {}
    for name, _ in pairs(rules) do
        res[#res + 1] = name
    end
    return table_concat(res, ", ")
end

local function build_required_str(rules)
    local res = {}
    for name, req in pairs(rules) do
        if req then
            res[#res + 1] = name
        end
    end
    return table_concat(res, ", ")
end

local scalar_types = _M.make_set("string", "number", "boolean")

--- Checks if the arguments in the specified table match the rules.
--
-- @param args      Table with arguments to be checked.
-- @param rules     Rules to check against.
-- @param res_name  Name of the resource that is being checked (for error messages)
-- @return          Error string if the check failed, otherwise <tt>nil</tt>.
function _M.check_args(args, rules, res_name)
    res_name = res_name or "error"
    if type(args) ~= "table" then
        return res_name .. ": arguments must be passed in a table"
    end
    if not rules then return nil end
    -- check for valid args (names starting with _ are ignored)
    for name, val in pairs(args) do
        if type(name) ~= "string" then
            return res_name .. ": keys must be strings"
        end
        if name:sub(1, 1) ~= "_" then
            local rule = rules[name]
            if rule == nil then
                return res_name .. ": invalid argument '" .. name .. "' not in (" .. build_args_str(rules) .. ")"
            end
            local rule_type = type(rule)
            local allowed_types
            if rule_type == "boolean" then
                allowed_types = scalar_types
            elseif rule_type == "table" then
                allowed_types = rule.types
            else
                return res_name .. ": invalid rule for field '" .. name .. "'"
            end
            if not allowed_types[type(val)] then
                return res_name .. ": argument '" .. name .. "' must be of type (" .. build_args_str(allowed_types) .. ")"
            end
        end
    end
    -- check if required args are present
    for name, rule in pairs(rules) do
        local required = rule
        if type(rule) == "table" then
            required = rule.required
        end
        if required and args[name] == nil then
            return res_name .. ": missing required argument '" .. name .. "' in (" .. build_required_str(rules) .. ")"
        end
    end
end

return _M
