--- Table with the Twitter API resources.
-- This is the data used to construct the `luatwit.api` function calls.
--
-- @module  luatwit.resources
-- @license MIT/X11
local setmetatable =
      setmetatable
local util = require "luatwit.util"

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

-- Default members for all resources.
_M._resource_base = {
    _type = "resource",
    default_args = {
        stringify_ids = true,
    },
}

local resource_mt = {
    __index = _M._resource_base,
}

-- Sets the mt of each resource.
local function api(tbl)
    return setmetatable(tbl, resource_mt)
end

--( Timeline )--

--- Returns the 20 most recent mentions (tweets containing a users's @screen_name) for the authenticating user.
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
--- Returns a collection of the most recent Tweets posted by the user indicated by the screen_name or user_id parameters.
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
--- Returns a collection of the most recent Tweets and retweets posted by the authenticating user and the users they follow.
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
--- Returns the most recent tweets authored by the authenticating user that have been retweeted by others.
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

--- Returns a collection of the 100 most recent retweets of the tweet specified by the id parameter.
_M.get_retweets = api{ GET, "statuses/retweets/:id", {
        id = true,
        count = false,
        trim_user = false,
    },
    "tweet_list"
}
--- Returns a single Tweet, specified by the id parameter.
_M.get_tweet = api{ GET, "statuses/show/:id", {
        id = true,
        trim_user = false,
        include_my_retweet = false,
        include_entities = false,
    },
    "tweet"
}
--- Destroys the status specified by the required ID parameter.
_M.delete_tweet = api{ POST, "statuses/destroy/:id", {
        id = true,
        trim_user = false,
    },
    "tweet"
}
--- Updates the authenticating user's current status, also known as tweeting.
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
--- Retweets a tweet.
_M.retweet = api{ POST, "statuses/retweet/:id", {
        id = true,
        trim_user = false,
    },
    "tweet"
}
--- Returns information allowing the creation of an embedded representation of a Tweet on third party sites.
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
--- Returns a collection of up to 100 user IDs belonging to users who have retweeted the tweet specified by the id parameter.
_M.get_retweeter_ids = api{ GET, "statuses/retweeters/ids", {
        id = true,
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
--- Updates the authenticating user's current status and attaches media for upload.
_M.tweet_with_media = api{ POST, "statuses/update_with_media", {
        status = true,
        ["media[]"] = { required = true, types = util.set("table") },
        possibly_sensitive = false,
        in_reply_to_status_id = false,
        lat = false,
        long = false,
        place_id = false,
        display_coordinates = false,
    },
    "tweet",
    _multipart = true
}
--- Returns fully-hydrated  tweet objects for up to 100 tweets per request, as specified by comma-separated values passed to the id parameter.
_M.lookup_tweets = api{ GET, "statuses/lookup", {
        id = true,
        include_entities = false,
        trim_user = false,
        map = false,
    },
    "tweet_list"
}

--( Search )--

--- Returns a collection of relevant Tweets matching a specified query.
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

--- Returns the 20 most recent direct messages sent to the authenticating user.
_M.get_received_dms = api{ GET, "direct_messages", {
        since_id = false,
        max_id = false,
        count = false,
        include_entities = false,
        skip_status = false,
    },
    "dm_list"
}
--- Returns the 20 most recent direct messages sent by the authenticating user.
_M.get_sent_dms = api{ GET, "direct_messages/sent", {
        since_id = false,
        max_id = false,
        count = false,
        page = false,
        include_entities = false,
    },
    "dm_list"
}
--- Returns a single direct message, specified by an id parameter.
_M.get_dm = api{ GET, "direct_messages/show", {
        id = true,
    },
    "dm"
}
--- Destroys the direct message specified in the required ID parameter.
_M.delete_dm = api{ POST, "direct_messages/destroy", {
        id = true,
        include_entities = false,
    },
    "dm"
}
--- Sends a new direct message to the specified user from the authenticating user.
_M.send_dm = api{ POST, "direct_messages/new", {
        user_id = false,
        screen_name = false,
        text = true,
    },
    "dm"
}

--( Friends & Followers )--

--- Returns a collection of user_ids that the currently authenticated user does not want to receive retweets from.
_M.get_disabled_rt_ids = api{ GET, "friendships/no_retweets/ids", {
        stringify_ids = false,
    },
    "userid_array"
}
--- Returns a cursored collection of user IDs for every user the specified user is following (otherwise known as their "friends").
_M.get_following_ids = api{ GET, "friends/ids", {
        user_id = false,
        screen_name = false,
        cursor = false,
        stringify_ids = false,
        count = false,
    },
    "userid_cursor"
}
--- Returns a cursored collection of user IDs for every user following the specified user.
_M.get_followers_ids = api{ GET, "followers/ids", {
        user_id = false,
        screen_name = false,
        cursor = false,
        stringify_ids = false,
        count = false,
    },
    "userid_cursor"
}
--- Returns the relationships of the authenticating user to the comma-separated list of up to 100 screen_names or user_ids provided.
_M.lookup_friendships = api{ GET, "friendships/lookup", {
        screen_name = false,
        user_id = false,
    },
    "friendship_list"
}
--- Returns a collection of numeric IDs for every user who has a pending request to follow the authenticating user.
_M.get_incoming_follow_requests = api{ GET, "friendships/incoming", {
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
--- Returns a collection of numeric IDs for every protected user for whom the authenticating user has a pending follow request.
_M.get_outgoing_follow_requests = api{ GET, "friendships/outgoing", {
        cursor = false,
        stringify_ids = false,
    },
    "userid_cursor"
}
--- Allows the authenticating users to follow the user specified in the ID parameter.
_M.follow = api{ POST, "friendships/create", {
        screen_name = false,
        user_id = false,
        follow = false,
    },
    "user"
}
--- Allows the authenticating user to unfollow the user specified in the ID parameter.
_M.unfollow = api{ POST, "friendships/destroy", {
        screen_name = false,
        user_id = false,
    },
    "user"
}
--- Allows one to enable or disable retweets and device notifications from the specified user.
_M.set_follow_settings = api{ POST, "friendships/update", {
        screen_name = false,
        user_id = false,
        device = false,
        retweets = false,
    },
    "relationship_container"
}
--- Returns detailed information about the relationship between two arbitrary users.
_M.get_friendship = api{ GET, "friendships/show", {
        source_id = false,
        source_screen_name = false,
        target_id = false,
        target_screen_name = false,
    },
    "relationship_container"
}
--- Returns a cursored collection of user objects for every user the specified user is following (otherwise known as their "friends").
_M.get_following = api{ GET, "friends/list", {
        user_id = false,
        screen_name = false,
        cursor = false,
        skip_status = false,
        include_user_entities = false,
    },
    "user_cursor"
}
--- Returns a cursored collection of user objects for users following the specified user.
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

--- Returns settings (including current trend, geo and sleep time information) for the authenticating user.
_M.get_account_settings = api{ GET, "account/settings", {
        -- empty
    },
    "account_settings"
}
--- Returns an HTTP 200 OK response code and a representation of the requesting user if authentication was successful; returns a 401 status code and an error message if not.
_M.verify_credentials = api{ GET, "account/verify_credentials", {
        include_entities = false,
        skip_status = false,
    },
    "user"
}
--- Updates the authenticating user's settings.
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
--- Sets which device Twitter delivers updates to for the authenticating user.
_M.update_delivery_device = api{ POST, "account/update_delivery_device", {
        device = true,
        include_entities = false,
    }
}
--- Sets values that users are able to set under the "Account" tab of their settings page.
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
--- Updates the authenticating user's profile background image.
_M.set_profile_background_image = api{ POST, "account/update_profile_background_image", {
        image = false,
        tile = false,
        include_entities = false,
        skip_status = false,
        use = false,
    },
    "user"
}
--- Sets one or more hex values that control the color scheme of the authenticating user's profile page on twitter.
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
--- Updates the authenticating user's profile image.
_M.set_profile_image = api{ POST, "account/update_profile_image", {
        image = true,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
--- Returns a collection of user objects that the authenticating user is blocking.
_M.get_blocked_users = api{ GET, "blocks/list", {
        include_entities = false,
        skip_status = false,
        cursor = false,
    },
    "user_cursor"
}
--- Returns an array of numeric user ids the authenticating user is blocking.
_M.get_blocked_ids= api{ GET, "blocks/ids", {
        stringify_ids = false,
        cursor = false,
    },
    "userid_cursor"
}
--- Blocks the specified user from following the authenticating user.
_M.block_user = api{ POST, "blocks/create", {
        screen_name = false,
        user_id = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
--- Un-blocks the user specified in the ID parameter for the authenticating user.
_M.unblock_user = api{ POST, "blocks/destroy", {
        screen_name = false,
        user_id = false,
        include_entities = false,
        skip_status = false,
    },
    "user"
}
--- Returns fully-hydrated user objects for up to 100 users per request, as specified by comma-separated values passed to the user_id and/or screen_name parameters.
_M.lookup_users = api{ GET, "users/lookup", {
        screen_name = false,
        user_id = false,
        include_entities = false,
    },
    "user_list"
}
--- Returns a variety of information about the user specified by the required user_id or screen_name parameter.
_M.get_user = api{ GET, "users/show", {
        user_id = false,
        screen_name = false,
        include_entities = false,
    },
    "user"
}
--- Provides a simple, relevance-based search interface to public user accounts on Twitter.
_M.search_users = api{ GET, "users/search", {
        q = true,
        page = false,
        count = false,
        include_entities = false,
    },
    "user_list"
}
--- Returns a collection of users that the specified user can "contribute" to.
_M.get_contributees = api{ GET, "users/contributees", {
        user_id = false,
        screen_name = false,
        include_entities = false,
        skip_status = false,
    },
    "user_list"
}
--- Returns a collection of users who can contribute to the specified account.
_M.get_contributors = api{ GET, "users/contributors", {
        user_id = false,
        screen_name = false,
        include_entities = false,
        skip_status = false,
    },
    "user_list"
}
--- Removes the uploaded profile banner for the authenticating user.
_M.remove_profile_banner = api{ POST, "account/remove_profile_banner", {
        -- empty
    }
}
--- Uploads a profile banner on behalf of the authenticating user.
_M.set_profile_banner = api{ POST, "account/update_profile_banner", {
        banner = true,
        width = false,
        height = false,
        offset_left = false,
        offset_top = false,
    }
}
--- Returns a map of the available size variations of the specified user's profile banner.
_M.get_profile_banner = api{ GET, "users/profile_banner", {
        user_id = false,
        screen_name = false,
    },
    "profile_banner"
}
--- Mutes the user specified in the ID parameter for the authenticating user.
_M.mute_user = api{ POST, "mutes/users/create", {
        screen_name = false,
        user_id = false,
    },
    "user"
}
--- Un-mutes the user specified in the ID parameter for the authenticating user.
_M.unmute_user = api{ POST, "mutes/users/destroy", {
        screen_name = false,
        user_id = false,
    },
    "user"
}
--- Returns an array of numeric user ids the authenticating user has muted.
_M.get_muted_ids = api{ GET, "mutes/users/ids", {
        cursor = false,
    },
    "userid_cursor"
}
--- Returns an array of user objects the authenticating user has muted.
_M.get_muted_users = api{ GET, "mutes/users/list", {
        cursor = false,
        include_entities = false,
        skip_status = false,
    },
    "user_cursor"
}

--( Suggested Users )--

--- Access the users in a given category of the Twitter suggested user list.
_M.get_suggestion_category = api{ GET, "users/suggestions/:slug", {
        slug = true,
        lang = false,
    },
    "suggestion_category"
}
--- Access to Twitter's suggested user list.
_M.get_suggestion_categories = api{ GET, "users/suggestions", {
        lang = false,
    },
    "suggestion_category_list"
}
--- Access the users in a given category of the Twitter suggested user list and return their most recent status if they are not a protected user.
_M.get_suggestion_users = api{ GET, "users/suggestions/:slug/members", {
        slug = true,
    },
    "user_list"
}

--( Favorites )--

--- Returns the 20 most recent Tweets favorited by the authenticating or specified user.
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
--- Un-favorites the status specified in the ID parameter as the authenticating user.
_M.unset_favorite = api{ POST, "favorites/destroy", {
        id = true,
        include_entities = false,
    },
    "tweet"
}
--- Favorites the status specified in the ID parameter as the authenticating user.
_M.set_favorite = api{ POST, "favorites/create", {
        id = true,
        include_entities = false,
    },
    "tweet"
}

--( Lists )--

--- Returns all lists the authenticating or specified user subscribes to, including their own.
_M.get_all_lists = api{ GET, "lists/list", {
        user_id = false,
        screen_name = false,
        reverse = false,
    },
    "userlist_list"
}
--- Returns a timeline of tweets authored by members of the specified list.
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
--- Removes the specified member from the list.
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
--- Returns the lists the specified user has been added to.
_M.get_lists_following_user = api{ GET, "lists/memberships", {
        user_id = false,
        screen_name = false,
        cursor = false,
        filter_to_owned_lists = false,
    },
    "userlist_cursor"
}
--- Returns the subscribers of the specified list.
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
--- Subscribes the authenticated user to the specified list.
_M.follow_list = api{ POST, "lists/subscribers/create", {
        owner_screen_name = false,
        owner_id = false,
        list_id = false,
        slug = false,
    },
    "userlist"
}
--- Check if the specified user is a subscriber of the specified list.
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
--- Unsubscribes the authenticated user from the specified list.
_M.unfollow_list = api{ POST, "lists/subscribers/destroy", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
--- Adds multiple members to a list, by specifying a comma-separated list of member ids or screen names.
_M.add_multiple_list_members = api{ POST, "lists/members/create_all", {
        list_id = false,
        slug = false,
        user_id = false,
        screen_name = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
--- Check if the specified user is a member of the specified list.
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
--- Returns the members of the specified list.
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
--- Add a member to a list.
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
--- Deletes the specified list.
_M.delete_list = api{ POST, "lists/destroy", {
        owner_screen_name = false,
        owner_id = false,
        list_id = false,
        slug = false,
    },
    "userlist"
}
--- Updates the specified list.
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
--- Creates a new list for the authenticated user.
_M.create_list = api{ POST, "lists/create", {
        name = true,
        mode = false,
        description = false,
    },
    "userlist"
}
--- Returns the specified list.
_M.get_list = api{ GET, "lists/show", {
        list_id = false,
        slug = false,
        owner_screen_name = false,
        owner_id = false,
    },
    "userlist"
}
--- Obtain a collection of the lists the specified user is subscribed to, 20 lists per page by default.
_M.get_followed_lists = api{ GET, "lists/subscriptions", {
        user_id = false,
        screen_name = false,
        count = false,
        cursor = false,
    },
    "userlist_cursor"
}
--- Removes multiple members from a list, by specifying a comma-separated list of member ids or screen names.
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
--- Returns the lists owned by the specified Twitter user.
_M.get_own_lists = api{ GET, "lists/ownerships", {
        user_id = false,
        screen_name = false,
        count = false,
        cursor = false,
    },
    "userlist_cursor"
}

--( Saved Searches )--

--- Returns the authenticated user's saved search queries.
_M.get_saved_searches = api{ GET, "saved_searches/list", {
        -- empty
    },
    "saved_search_list"
}
--- Retrieve the information for the saved search represented by the given id.
_M.get_saved_search = api{ GET, "saved_searches/show/:id", {
        id = true,
    },
    "saved_search"
}
--- Create a new saved search for the authenticated user.
_M.create_saved_search = api{ POST, "saved_searches/create", {
        query = true,
    },
    "saved_search"
}
--- Destroys a saved search for the authenticating user.
_M.delete_saved_search = api{ POST, "saved_searches/destroy/:id", {
        id = true,
    },
    "saved_search"
}

--( Places & Geo )--

--- Returns all the information about a known place.
_M.get_place = api{ GET, "geo/id/:place_id", {
        place_id = true,
    },
    "place"
}
--- Given a latitude and a longitude, searches for up to 20 places that can be used as a place_id when updating a status.
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
--- Search for places that can be attached to a statuses/update.
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
--- Locates places near the given coordinates which are similar in name.
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
--- As of December 2nd, 2013, this endpoint is deprecated and retired and no longer functions.
_M.create_place = api{ POST, "geo/place", {
        name = true,
        contained_within = true,
        token = true,
        lat = true,
        long = true,
        --attribute = false,    -- misc attribute:<key> values
        --callback = false,     -- generates JSONP, only for web apps
    },
    "place"
}

--( Trends )--

--- Returns the top 10 trending topics for a specific WOEID, if trending information is available for it.
_M.get_trends = api{ GET, "trends/place", {
        id = true,
        exclude = false,
    },
    "trends_container_list"
}
--- Returns the locations that Twitter has trending topic information for.
_M.get_all_trends_locations = api{ GET, "trends/available", {
        -- empty
    },
    "trend_location_list"
}
--- Returns the locations that Twitter has trending topic information for, closest to a specified location.
_M.find_trends_location = api{ GET, "trends/closest", {
        lat = true,
        long = true,
    },
    "trend_location_list"
}

--( Spam Reporting )--

--- Report the specified user as a spam account to Twitter.
_M.report_spam = api{ POST, "users/report_spam", {
        screen_name = false,
        user_id = false,
    },
    "user"
}

--( Help )--

--- Returns the current configuration used by Twitter including twitter.
_M.get_service_config = api{ GET, "help/configuration", {
        -- empty
    },
    "service_config"
}
--- Returns the list of languages supported by Twitter along with the language code supported by Twitter.
_M.get_languages = api{ GET, "help/languages", {
        -- empty
    },
    "language_list"
}
--- Returns Twitter's Privacy Policy.
_M.get_privacy_policy = api{ GET, "help/privacy", {
        -- empty
    },
    "privacy"
}
--- Returns the Twitter Terms of Service.
_M.get_tos = api{ GET, "help/tos", {
        -- empty
    },
    "tos"
}
--- Returns the current rate limits for methods belonging to the specified resource families.
_M.get_rate_limit = api{ GET, "application/rate_limit_status", {
        resources = false,
    },
    "rate_limit"
}

return _M
