package = "LuaTwit"
version = "scm-1"

source = {
    url = "git://github.com/darkstalker/LuaTwit.git",
}

description = {
    summary = "Lua library for accessing the Twitter REST and Streaming API v1.1",
    detailed = [[
        Lua library for accessing the Twitter REST and Streaming API v1.1.
        It implements simple parameter checking and returns metatable-typed JSON data.
    ]],
    homepage = "https://github.com/darkstalker/LuaTwit",
    license = "MIT/X11",
}

dependencies = {
    "lua >= 5.1",
    "dkjson >= 2.5",
    "lua-curl >= 0.3.1",
    "oauth_light >= 0.1",
}

build = {
    type = "builtin",
    modules = {
        luatwit = "src/luatwit.lua",
        ["luatwit.common"] = "src/luatwit/common.lua",
        ["luatwit.http"] = "src/luatwit/http.lua",
        ["luatwit.objects"] = "src/luatwit/objects.lua",
        ["luatwit.resources"] = "src/luatwit/resources.lua",
        ["luatwit.util"] = "src/luatwit/util.lua",
    },
    copy_directories = { "examples" },
}
