package = "LuaTwit"
version = "0.1.0-1"

source = {
    url = "git://github.com/darkstalker/LuaTwit.git",
    tag = "0.1.0",
}

description = {
    summary = "Lua library for accessing the Twitter REST API v1.1",
    detailed = [[
        Lua library for accessing the Twitter REST API v1.1.
        It implements simple parameter checking and returns metatable-typed JSON data.
    ]],
    homepage = "https://github.com/darkstalker/LuaTwit",
    license = "MIT/X11",
}

dependencies = {
    "lua >= 5.1",
    "oauth >= 0.0.5",
    "dkjson >= 2.5",
    "lanes >= 3.9.4",
    "penlight >= 1.3.1",
}

build = {
    type = "builtin",
    modules = {
        luatwit = "src/luatwit.lua",
        ["luatwit.async"] = "src/luatwit/async.lua",
        ["luatwit.objects"] = "src/luatwit/objects.lua",
        ["luatwit.resources"] = "src/luatwit/resources.lua",
        ["luatwit.util"] = "src/luatwit/util.lua",
    },
    copy_directories = { "examples" },
}
