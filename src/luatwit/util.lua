--- Misc utility functions used by the `luatwit` library.
--
-- @module  luatwit.util
-- @license MIT/X11
local getmetatable, pairs, rawget, select, setmetatable, table_concat, type =
      getmetatable, pairs, rawget, select, setmetatable, table.concat, type
local tablex = require "pl.tablex"

local _M = {}

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

--- Copies key-value pairs from one table to another and applies a function to the values.
-- @param dest      Destination table.
-- @param src       Source table.
-- @param fn        Function applied to values before assigning them.
--                  It's called as `fn(value, key)` for each key in `src`,
--                  then the result is assigned to `dest[key]`, unless it's `nil`.
-- @return          The `dest` argument.
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

-- returns all the arguments on a set of rules
local function build_args_str(rules)
    local res = {}
    for name, _ in pairs(rules) do
        res[#res + 1] = name
    end
    return table_concat(res, ", ")
end

-- returns the required arguments on a set of rules
local function build_required_str(rules)
    local res = {}
    for name, req in pairs(rules) do
        if req then
            res[#res + 1] = name
        end
    end
    return table_concat(res, ", ")
end

local scalar_types = { string = true, number = true, boolean = true }

--- Checks if the arguments in the specified table match the rules.
--
-- @param args      Table with arguments to be checked.
-- @param rules     Rules to check against.
-- @param res_name  Name of the resource that is being checked (for error messages)
-- @return          `true` if `args` is valid, otherwise `false`.
-- @return          The error string if `args` is invalid.
function _M.check_args(args, rules, res_name)
    res_name = res_name or "error"
    if type(args) ~= "table" then
        return false, res_name .. ": arguments must be passed in a table"
    end
    if not rules then return true end
    -- check for valid args (names starting with _ are ignored)
    for name, val in pairs(args) do
        if type(name) ~= "string" then
            return false, res_name .. ": keys must be strings"
        end
        if name:sub(1, 1) ~= "_" then
            local rule = rules[name]
            if rule == nil then
                return false, res_name .. ": invalid argument '" .. name .. "' not in (" .. build_args_str(rules) .. ")"
            end
            local rule_type = type(rule)
            local allowed_types
            if rule_type == "boolean" then
                allowed_types = scalar_types
            elseif rule_type == "table" then
                allowed_types = tablex.makeset(rule.types)
            else
                return false, res_name .. ": invalid rule for field '" .. name .. "'"
            end
            if not allowed_types[type(val)] then
                return false, res_name .. ": argument '" .. name .. "' must be of type (" .. build_args_str(allowed_types) .. ")"
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
            return false, res_name .. ": missing required argument '" .. name .. "' in (" .. build_required_str(rules) .. ")"
        end
    end
    return true
end

--- Removes the first value from a `pcall` result and returns errors in Lua style.
--
-- @param ok        Success status from `pcall`.
-- @param ...       List of returned values.
-- @return          On success, the function return values. On failure `nil`.
-- @return          The error string.
function _M.shift_pcall_error(ok, ...)
    if not ok then
        return nil, ...
    end
    return ...
end

--- Performs an API call with the data on a resource object.
--
-- @param res       Resource object (from `luatwit.resources`).
-- @param client    API client (`luatwit.api` instance).
-- @param args      Table with method arguments.
-- @return          The result of the API call.
-- @see luatwit.api.raw_call
function _M.resource_call(res, client, args)
    return client:raw_call(res.method, res.path, args, res.res_type, res.multipart, res.rules, res.base_url, res.default_args, res.name)
end

--- Performs an API call with the data from an object returned by other API calls.
--
-- @param obj       Table returned by `luatwit.api.raw_call`.
-- @param args      Table with method arguments.
-- @return          The result of the API call.
function _M.object_call(obj, args)
    local client = obj._get_client()
    local res = client.resources[obj._source]
    return client:raw_call(res.method, res.path, args, res.res_type, res.multipart, res.rules, res.base_url, obj._request, obj._source)
end

local resource_builder_mt = {
    _type = "resource_builder",
}
resource_builder_mt.__index = resource_builder_mt

function resource_builder_mt:args(rules)
    self.rules = rules
    return self
end

function resource_builder_mt:type(tname)
    self.res_type = tname
    return self
end

function resource_builder_mt:multipart()
    self.multipart = true
    return self
end

function resource_builder_mt:base_url(url)
    self.base_url = url
    return self
end

function resource_builder_mt:finish(res_name, mt)
    self.name = res_name
    return setmetatable(self, mt)
end

--- Creates a resource builder object. It's used to construct the fields of `luatwit.resources`.
--
-- @param method    HTTP method.
-- @param path      Resource path.
-- @return          Resource builder object. Must call `:finish()` after the construction is done.
function _M.resource_builder(method, path)
    local res = {
        method = method,
        path = path,
    }
    return setmetatable(res, resource_builder_mt)
end

return _M
