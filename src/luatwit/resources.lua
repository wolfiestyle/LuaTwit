--- Table with the Twitter API resources.
-- This is the data used to construct the `luatwit.api` function calls.
--
-- @module  luatwit.resources
-- @license MIT
local _M = {}

local GET, POST = "GET", "POST"

-- Base URL of the Twitter REST API.
_M._base_url = "https://api.twitter.com/1.1/"

-- OAuth endpoints for the Twitter API.
_M._endpoints = {
    RequestToken = "https://api.twitter.com/oauth/request_token",
    AuthorizeUser = { "https://api.twitter.com/oauth/authorize", method = GET },
    AccessToken = "https://api.twitter.com/oauth/access_token",
}

-- Hack to prevent ldoc 1.3.12 from parsing tables and producing broken output.
local function api(tbl)
    return tbl
end

--( Timeline )--

_M.get_mentions = api{ GET, "statuses/mentions_timeline", {
        count = false,
        since_id = false,
        max_id = false,
        trim_user = false,
        contributor_details = false,
        include_entities = false,
    },
    "tweet_list"
}
_M.get_user_timeline = api{ GET, "statuses/user_timeline", {
        user_id = false,
        screen_name = false,
        since_id = false,
        count = false,
        max_id = false,
        trim_user = false,
        exclude_replies = false,
        contributor_details = false,
        include_rts = false,
    },
    "tweet_list"
}
_M.get_home_timeline = api{ GET, "statuses/home_timeline", {
        count = false,
        since_id = false,
        max_id = false,
        trim_user = false,
        exclude_replies = false,
        contributor_details = false,
        include_entities = false,
    },
    "tweet_list"
}
_M.get_retweets_of_me = api{ GET, "statuses/retweets_of_me", {
        count = false,
        since_id = false,
        max_id = false,
        trim_user = false,
        include_entities = false,
        include_user_entities = false,
    },
    "tweet_list"
}

--( Tweets )--

_M.get_retweets = api{ GET, "statuses/retweets/:id", {
        id = true,
        count = false,
        trim_user = false,
    },
    "tweet_list"
}
_M.get_tweet = api{ GET, "statuses/show/:id", {
        id = true,
        trim_user = false,
        include_my_retweet = false,
        include_entities = false,
    },
    "tweet"
}
_M.delete_tweet = api{ POST, "statuses/destroy/:id", {
        id = true,
        trim_user = false,
    },
    "tweet"
}
_M.tweet = api{ POST, "statuses/update", {
        status = true,
        in_reply_to_status_id = false,
        lat = false,
        long = false,
        place_id = false,
        display_coordinates = false,
        trim_user = false,
    },
    "tweet"
}
_M.retweet = api{ POST, "statuses/retweet/:id", {
        id = true,
        trim_user = false,
    },
    "tweet"
}
_M.oembed = api{ GET, "statuses/oembed", {
        id = true,
        --url = false,          -- full tweet url, only useful for web apps
        maxwidth = false,
        hide_media = false,
        hide_thread = false,
        omit_script = false,
        align = false,
        related = false,
        lang = false,
    },
    "oembed"
}
_M.get_retweeter_ids = api{ GET, "statuses/retweeters/ids", {
        id = true,
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
-- POST statuses/update_with_media      --TODO: requires multipart/form-data request

--( Search )--

_M.search_tweets = api{ GET, "search/tweets", {
        q = true,
        geocode = false,
        lang = false,
        locale = false,
        result_type = false,
        count = false,
        ["until"] = false,
        since_id = false,
        max_id = false,
        include_entities = false,
        --callback = false,     -- generates JSONP, only for web apps
    },
    "tweet_search"
}

--( Streaming )--   TODO: streaming won't work with blocking oauth.PerformRequest()
-- POST statuses/filter
-- GET statuses/sample
-- GET statuses/firehose
-- GET user
-- GET site

--( Direct Messages )--

_M.get_received_dms = api{ GET, "direct_messages", {
        since_id = false,
        max_id = false,
        count = false,
        include_entities = false,
        skip_status = false,
    },
    "dm_list"
}
_M.get_sent_dms = api{ GET, "direct_messages/sent", {
        since_id = false,
        max_id = false,
        count = false,
        page = false,
        include_entities = false,
    },
    "dm_list"
}
_M.get_dm = api{ GET, "direct_messages/show", {
        id = true,
    },
    "dm"
}
_M.delete_dm = api{ POST, "direct_messages/destroy", {
        id = true,
        include_entities = false,
    },
    "dm"
}
_M.send_dm = api{ POST, "direct_messages/new", {
        user_id = false,
        screen_name = false,
        text = true,
    },
    "dm"
}

--( Friends & Followers )--

_M.get_disabled_rt_ids = api{ GET, "friendships/no_retweets/ids", {
        stringify_ids = false,
    },
    "userid_array"
}
_M.get_following_ids = api{ GET, "friends/ids", {
        user_id = false,
        screen_name = false,
        cursor = false,
        stringify_ids = false,
        count = false,
    },
    "userid_cursor"
}
_M.get_followers_ids = api{ GET, "followers/ids", {
        user_id = false,
        screen_name = false,
        cursor = false,
        stringify_ids = false,
        count = false,
    },
    "userid_cursor"
}
_M.lookup_friendships = api{ GET, "friendships/lookup", {
        screen_name = false,
        user_id = false,
    },
    "friendship_list"
}
_M.get_incoming_follow_requests = api{ GET, "friendships/incoming", {
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
_M.get_outgoing_follow_requests = api{ GET, "friendships/outgoing", {
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
_M.follow = api{ POST, "friendships/create", {
        screen_name = false,
        user_id = false,
        follow = false,
    },
    "user"
}
_M.unfollow = api{ POST, "friendships/destroy", {
        screen_name = false,
        user_id = false,
    },
    "user"
}
_M.set_follow_settings = api{ POST, "friendships/update", {
        screen_name = false,
        user_id = false,
        device = false,
        retweets = false,
    },
    "relationship_container"
}
_M.get_friendship = api{ GET, "friendships/show", {
        source_id = false,
        source_screen_name = false,
        target_id = false,
        target_screen_name = false,
    },
    "relationship_container"
}
_M.get_following = api{ GET, "friends/list", {
        user_id = false,
        screen_name = false,
        cursor = false,
        skip_status = false,
        include_user_entities = false,
    },
    "user_cursor"
}
_M.get_followers = api{ GET, "followers/list", {
        user_id = false,
        screen_name = false,
        cursor = false,
        skip_status = false,
        include_user_entities = false,
    },
    "user_cursor"
}

--( Users )--

_M.get_account_settings = api{ GET, "account/settings", {
        -- empty
    },
    "account_settings"
}
_M.verify_credentials = api{ GET, "account/verify_credentials", {
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.set_account_settings = api{ POST, "account/settings", {
        trend_location_woeid = false,
        sleep_time_enabled = false,
        start_sleep_time = false,
        end_sleep_time = false,
        time_zone = false,
        lang = false,
    },
    "account_settings"
}
_M.update_delivery_device = api{ POST, "account/update_delivery_device", {
        device = true,
        include_entities = false,
    }
}
_M.update_profile = api{ POST, "account/update_profile", {
        name = false,
        url = false,
        location = false,
        description = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.set_profile_background_image = api{ POST, "account/update_profile_background_image", {
        image = false,
        tile = false,
        include_entities = false,
        skip_status = false,
        use = false,
    },
    "user"
}
_M.set_profile_colors = api{ POST, "account/update_profile_colors", {
        profile_background_color = false,
        profile_link_color = false,
        profile_sidebar_border_color = false,
        profile_sidebar_fill_color = false,
        profile_text_color = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.set_profile_image = api{ POST, "account/update_profile_image", {
        image = true,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.get_blocked_users = api{ GET, "blocks/list", {
        include_entities = false,
        skip_status = false,
        cursor = false,
    },
    "user_cursor"
}
_M.get_blocked_ids= api{ GET, "blocks/ids", {
        stringify_ids = false,
        cursor = false,
    },
    "userid_cursor"
}
_M.block_user = api{ POST, "blocks/create", {
        screen_name = false,
        user_id = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.unblock_user = api{ POST, "blocks/destroy", {
        screen_name = false,
        user_id = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.lookup_users = api{ GET, "users/lookup", {
        screen_name = false,
        user_id = false,
        include_entities = false,
    },
    "user_list"
}
_M.get_user = api{ GET, "users/show", {
        user_id = false,
        screen_name = false,
        include_entities = false,
    },
    "user"
}
_M.search_users = api{ GET, "users/search", {
        q = true,
        page = false,
        count = false,
        include_entities = false,
    },
    "user_list"
}
_M.get_contributees = api{ GET, "users/contributees", {
        user_id = false,
        screen_name = false,
        include_entities = false,
        skip_status = false,
    },
    "user_list"
}
_M.get_contributors = api{ GET, "users/contributors", {
        user_id = false,
        screen_name = false,
        include_entities = false,
        skip_status = false,
    },
    "user_list"
}
_M.remove_profile_banner = api{ POST, "account/remove_profile_banner", {
        -- empty
    }
}
_M.set_profile_banner = api{ POST, "account/update_profile_banner", {
        banner = true,
        width = false,
        height = false,
        offset_left = false,
        offset_top = false,
    }
}
_M.get_profile_banner = api{ GET, "users/profile_banner", {
        user_id = false,
        screen_name = false,
    },
    "profile_banner"
}

--( Suggested Users )--

_M.get_suggestion_category = api{ GET, "users/suggestions/:slug", {
        slug = true,
        lang = false,
    },
    "suggestion_category"
}
_M.get_suggestion_categories = api{ GET, "users/suggestions", {
        lang = false,
    },
    "suggestion_category_list"
}
_M.get_suggestion_users = api{ GET, "users/suggestions/:slug/members", {
        slug = true,
    },
    "user_list"
}

--( Favorites )--

_M.get_favorites = api{ GET, "favorites/list", {
        user_id = false,
        screen_name = false,
        count = false,
        since_id = false,
        max_id = false,
        include_entities = false,
    },
    "tweet_list"
}
_M.unset_favorite = api{ POST, "favorites/destroy", {
        id = true,
        include_entities = false,
    },
    "tweet"
}
_M.set_favorite = api{ POST, "favorites/create", {
        id = true,
        include_entities = false,
    },
    "tweet"
}

--( Lists )--

_M.get_all_lists = api{ GET, "lists/list", {
        user_id = false,
        screen_name = false,
        reverse = false,
    },
    "userlist_list"
}
_M.get_list_timeline = api{ GET, "lists/statuses", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
        since_id = false,
        max_id = false,
        count = false,
        include_entities = false,
        include_rts = false,
    },
    "tweet_list"
}
_M.remove_list_member = api{ POST, "lists/members/destroy", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.get_lists_following_user = api{ GET, "lists/memberships", {
        user_id = false,
        screen_name = false,
        cursor = false,
        filter_to_owned_lists = false,
    },
    "userlist_cursor"
}
_M.get_list_followers = api{ GET, "lists/subscribers", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
        cursor = false,
        include_entities = false,
        skip_status = false,
    },
    "user_cursor"
}
_M.follow_list = api{ POST, "lists/subscribers/create", {
        owner_screen_name = false,
        owner_id = false,
        list_id = false,
        slug = false,
    },
    "userlist"
}
_M.is_following_list = api{ GET, "lists/subscribers/show", {
        owner_screen_name = false,
        owner_id = false,
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.unfollow_list = api{ POST, "lists/subscribers/destroy", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.list_add_multiple_users = api{ POST, "lists/members/create_all", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.is_member_of_list = api{ GET, "lists/members/show", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
_M.get_list_members = api{ GET, "lists/members", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
        cursor = false,
        include_entities = false,
        skip_status = false,
    },
    "user_cursor"
}
_M.add_list_member = api{ POST, "lists/members/create", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.delete_list = api{ POST, "lists/destroy", {
        owner_screen_name = false,
        owner_id = false,
        list_id = false,
        slug = false,
    },
    "userlist"
}
_M.update_list = api{ POST, "lists/update", {
        list_id = false,
        slug = false,
        name = false,
        mode = false,
        description = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.create_list = api{ POST, "lists/create", {
        name = true,
        mode = false,
        description = false,
    },
    "userlist"
}
_M.get_list = api{ GET, "lists/show", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.get_followed_lists = api{ GET, "lists/subscriptions", {
        user_id = false,
        screen_name = false,
        count = false,
        cursor = false,
    },
    "userlist_cursor"
}
_M.remove_multiple_list_members = api{ POST, "lists/members/destroy_all", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
_M.get_own_lists = api{ GET, "lists/ownerships", {
        user_id = false,
        screen_name = false,
        count = false,
        cursor = false,
    },
    "userlist_cursor"
}

--( Saved Searches )--

_M.get_saved_searches = api{ GET, "saved_searches/list", {
        -- empty
    },
    "saved_search_list"
}
_M.get_saved_search = api{ GET, "saved_searches/show/:id", {
        id = true,
    },
    "saved_search"
}
_M.create_saved_search = api{ POST, "saved_searches/create", {
        query = true,
    },
    "saved_search"
}
_M.delete_saved_search = api{ POST, "saved_searches/destroy/:id", {
        id = true,
    },
    "saved_search"
}

--( Places & Geo )--

_M.get_place = api{ GET, "geo/id/:place_id", {
        place_id = true,
    },
    "place"
}
_M.reverse_geocode = api{ GET, "geo/reverse_geocode", {
        lat = true,
        long = true,
        accuracy = false,
        granularity = false,
        max_results = false,
        --callback = false,     -- generates JSONP, only for web apps
    },
    "place_search"
}
_M.search_places = api{ GET, "geo/search", {
        lat = false,
        long = false,
        query = false,
        ip = false,
        granularity = false,
        accuracy = false,
        max_results = false,
        contained_within = false,
        --attribute = false,    -- misc attribute:<key> values
        --callback = false,     -- generates JSONP, only for web apps
    },
    "place_search"
}
_M.get_similar_places = api{ GET, "geo/similar_places", {
        lat = true,
        long = true,
        name = true,
        contained_within = false,
        --attribute = false,    -- misc attribute:<key> values
        --callback = false,     -- generates JSONP, only for web apps
    },
    "place_search"
}
_M.create_place = api{ POST, "geo/place", {
        name = true,
        contained_within = true,
        token = true,
        lat = true,
        long = true,
        --attribute = false,    -- misc attribute:<key> values
        --callback = false,     -- generates JSONP, only for web apps
    }
}

--( Trends )--

_M.get_trends = api{ GET, "trends/place", {
        id = true,
        exclude = false,
    },
    "trends_container_list"
}
_M.get_all_trends_locations = api{ GET, "trends/available", {
        -- empty
    },
    "trend_location_list"
}
_M.find_trends_location = api{ GET, "trends/closest", {
        lat = true,
        long = true,
    },
    "trend_location_list"
}

--( Spam Reporting )--

_M.report_spam = api{ POST, "users/report_spam", {
        screen_name = false,
        user_id = false,
    }
}

--( Help )--

_M.get_service_config = api{ GET, "help/configuration", {
        -- empty
    },
    "service_config"
}
_M.get_languages = api{ GET, "help/languages", {
        -- empty
    },
    "language_list"
}
_M.get_privacy_policy = api{ GET, "help/privacy", {
        -- empty
    },
    "privacy"
}
_M.get_tos = api{ GET, "help/tos", {
        -- empty
    },
    "tos"
}
_M.get_rate_limit = api{ GET, "application/rate_limit_status", {
        resources = false,
    },
    "rate_limit"
}

return _M
