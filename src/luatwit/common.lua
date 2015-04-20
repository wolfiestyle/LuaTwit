--- Common functions used internally by the `luatwit` library.
--
-- @module  luatwit.common
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local assert, error, ipairs, pairs, setmetatable, table_concat, tonumber, tostring, type =
      assert, error, ipairs, pairs, setmetatable, table.concat, tonumber, tostring, type

local _M = {}

--- Performs an API call with the data on a resource object.
--
-- @param res       Resource object (from `luatwit.resources`).
-- @param client    API client (`luatwit.api` instance).
-- @param args      Table with method arguments.
-- @return          The result of the API call.
-- @see luatwit.api.raw_call
function _M.resource_call(res, client, args)
    return client:raw_call(res, args, res.default_args)
end

--- Performs an API call with the data from an object returned by other API calls.
--
-- @param obj       Table returned by `luatwit.api.raw_call`.
-- @param args      Table with method arguments.
-- @return          The result of the API call.
function _M.object_call(obj, args)
    local client = obj._get_client()
    local res = client.resources[obj._source]
    return client:raw_call(res, args, obj._request)
end

-- Returns a string with the arguments on a set of rules.
local function build_args_str(rules, only_req)
    local res = {}
    for name, _ in pairs(rules.required) do
        res[#res + 1] = name
    end
    if not only_req then
        for name, _ in pairs(rules.optional) do
            res[#res + 1] = name
        end
    end
    return "(" .. table_concat(res, ", ") .. ")"
end

local type_handlers = {}

local rule_mt   -- (defined below)

-- Builds a rule table from it's declaration in resources.
local function build_rules(args_decl)
    local req_list, opt_list = {}, {}
    for name, decl in pairs(args_decl) do
        assert(type(name) == "string", "argument name must be a string")
        local td = type(decl)
        local required, handler
        if td == "boolean" then
            required = decl
            handler = "any"
        elseif td == "string" then
            handler = decl
        elseif td == "table" then
            required = decl.required
            handler = decl.type
        else
            error "invalid argument declaration"
        end
        assert(type_handlers[handler], "unknown type handler: " .. handler)
        local list = required and req_list or opt_list
        list[name] = handler
    end
    return setmetatable({ required = req_list, optional = opt_list }, rule_mt)
end

-- type "any": accept anything
function type_handlers.any(x)
    return x
end

-- type "boolean": accept only boolean
function type_handlers.boolean(x)
    if type(x) == "boolean" then
        return x
    end
end

-- type "integer": accept valid integer, reject decimals
function type_handlers.integer(x)
    local t = type(x)
    if t == "number" and x % 1 == 0 or t == "string" and x:find "^%-?%d+$" then
        return x
    end
end

-- type "real": accept valid number
function type_handlers.real(x)
    local t = type(x)
    if t == "number" or t == "string" then
        return tonumber(x)
    end
end

-- type "string": coerce non-object types to string
function type_handlers.string(x)
    local t = type(x)
    if t == "string" or t == "number" or t == "boolean" then
        return tostring(x)
    end
end

-- type "integer_list": concat tables and check valid int
function type_handlers.integer_list(x)
    local t = type(x)
    if t == "table" then
        local ints = {}
        for i, v in ipairs(x) do
            local p = type_handlers.integer(v)
            if p == nil then return end
            ints[i] = p
        end
        return table_concat(ints, ",")
    elseif t == "string" then
        -- rough check, should parse each number individually
        if x:find "^%d[%d,]*%d$" then
            return x
        end
    end
    return type_handlers.integer(x)
end

-- type "string_list": concat tables or conv to string
function type_handlers.string_list(x)
    if type(x) == "table" then
        return table_concat(x, ",")
    end
    return type_handlers.string(x)
end

-- type "date": accept YYYY-MM-DD
function type_handlers.date(x)
    if type(x) == "string" and x:find "^%d%d%d%d%-%d%d%-%d%d$" then
        return x
    end
end

-- type "base64": accept valid base64
function type_handlers.base64(x)
    if type(x) == "string" and #x % 4 == 0 and x:find "^[%w+/\n]+=?=?$" then
        return x
    end
end

-- type "file": accept tables with the 'data' field (created by `attach_file`)
function type_handlers.file(x)
    if type(x) == "table" and x.data then
        return x
    end
end

-- type "table": accept only tables
function type_handlers.table(x)
    if type(x) == "table" then
        return x
    end
end

--- Checks if the arguments in the specified table match the rules.
--
-- @param rules     Rules to check against.
-- @param args      Table with arguments to be checked.
-- @param r_name    Name of the resource that is being checked (for error messages).
-- @return          The `args` table with the values coerced to their types, or `nil` on error.
-- @return          The error string if `args` is invalid.
function _M.check_args(rules, args, r_name)
    r_name = r_name or "error"
    if type(args) ~= "table" then
        return nil, r_name .. ": arguments must be passed in a table"
    end
    if not rules then return args end
    for name, _ in pairs(rules.required) do
        if args[name] == nil then
            return nil, r_name .. ": missing required argument '" .. name .. "' in " .. build_args_str(rules, true)
        end
    end
    for name, val in pairs(args) do
        if type(name) ~= "string" then
            return nil, r_name .. ": argument name not a string"
        end
        if name:sub(1, 1) ~= "_" then
            local handler = rules.optional[name] or rules.required[name]
            if handler == nil then
                return nil, r_name .. ": invalid argument '" .. name .. "' not in " .. build_args_str(rules)
            end
            local handler_fn = type_handlers[handler]
            if not handler_fn then
                return nil, r_name .. ": unknown type '" .. handler .. "' in resource declaration"
            end
            local parsed = handler_fn(val)
            if parsed == nil then
                return nil, r_name .. ": invalid " .. handler .. " value for '" .. name .."'"
            end
            args[name] = parsed
        end
    end
    return args
end

-- Allows calling check_args as method.rules()
rule_mt = {
    __call = _M.check_args,
}

local resource_builder_mt = {
    _type = "resource_builder",
}
resource_builder_mt.__index = resource_builder_mt

function resource_builder_mt:args(args_decl)
    self.rules = build_rules(args_decl)
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

function resource_builder_mt:stream()
    self.stream = true
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

--- Base class for objects.
-- @type object
local object = {}
_M.object = object

--- Creates a new class that extends this object.
--
-- @return      New class.
function object:extend()
    local class = { __index = self }
    return setmetatable(class, class)
end

--- Creates a new instance of the class.
--
-- @param ...   Constructor arguments, passed to `self:_init()`.
-- @return      New instance of the class.
function object:new(...)
    local obj = { __index = self }
    setmetatable(obj, obj)
    obj:_init(...)
    return obj
end

-- This will be called when the derived class has no constructor.
function object._init()
    -- empty
end

return _M
