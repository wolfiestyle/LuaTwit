# LuaTwit

Lua library for accessing the Twitter REST API v1.1.
It implements simple parameter checking and returns metatable-typed JSON data.

## Dependencies

- oauth
- dkjson
- lanes

Also you'll need `penlight` to run the examples and `ldoc` if you want to generate the docs.

## Documentation

Available online [here](http://darkstalker.github.io/LuaTwit/).

## Usage

First, you need a set of app keys. You can get them from [here](https://dev.twitter.com/apps).

    local luatwit = require "luatwit"

    -- Fill in your app keys here
    local keys = {
        consumer_key = "<key>",
        consumer_secret = "<secret>",
        oauth_token = "<token>",
        oauth_token_secret= "<token_secret>",
    }

The twitter client is created by the method `luatwit.api.new`:

    local client = luatwit.api.new(keys)

Use this object to do API calls. The argument names are checked against the definitions in `luatwit.resources`:

    local result = client:get_home_timeline{ count = 1 }

The JSON data is returned in a table:

    print(result[1].user.screen_name, result[1].text)

The returned data has a metatable (from `luatwit.objects`) that describes the object type:

    print(result._type)         -- "tweet_list"
    print(result[1]._type)      -- "tweet"
    print(result[1].user._type) -- "user"

The type metatables also provide convenience methods:

    result[1]:set_favorite():retweet()
    result[1]:reply{ status = "answer!", _mention = true }

The methods can be called in async mode, and they'll return a future object that can be read with `peek()` and `wait()`:

    local res_f = client:get_user{ user_id = 174958347, _async = true }
    print(res_f._type)          -- "future"
    print(res_f:wait().screen_name)
