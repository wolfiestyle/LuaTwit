local lfs = require "lfs"
local pl_file = require "pl.file"

local function find_app_keys(config_dir)
    local filename = config_dir .. "oauth_app_keys"
    if lfs.attributes(filename) then
        return filename
    end

    assert(pl_file.write(filename, "# fill in your app keys here\nconsumer_key = key\nconsumer_secret = secret\n"))

    local msg = ([[
  Error: App keys not found.
  A file named '%s' was created.
  Fill it with the consumer keys of your app.
  If you don't have them, create an app at https://apps.twitter.com
  Then authorize the app with "authorize.lua".

  ]]):format(filename)
    io.stderr:write(msg)
end

local function find_user_keys(config_dir, is_auth)
    local filename = config_dir .. "local_auth"
    if is_auth or lfs.attributes(filename) then
        return filename
    end

    io.stderr:write [[
  Error: User keys not found.
  OAuth requests will fail until you authorize the app.
  Run "authorize.lua" in the examples dir to create the auth file.

]]
end

-- use the XDG spec to find a writable dir, should work on UNIX
local function get_config_dir()
    local base = os.getenv "XDG_CONFIG_HOME"
    if base == nil then
        local home = os.getenv "HOME"
        if home == nil then
            home = "."
        end
        base = home .. "/.config"
    end
    local dir = base .. "/luatwit/"
    if not lfs.attributes(dir) then
        assert(lfs.mkdir(dir))  --FIXME: should emulate 'mkdir -p', will fail if parents missing
    end
    return dir
end

local function do_config(is_auth)
    package.path = "../src/?.lua;" .. package.path  -- use the git repo files if available

    local config = {}
    local config_dir = get_config_dir()

    config.config_dir = config_dir
    config.app_keys = assert(find_app_keys(config_dir), "config failed")
    config.user_keys = assert(find_user_keys(config_dir, is_auth), "config failed")

    return config
end

return do_config
