--- Table with the Twitter API resources.
-- This is the data used to construct the `luatwit.api` function calls.
--
-- @module  luatwit.resources
-- @author  darkstalker <https://github.com/darkstalker>
-- @license MIT/X11
local util = require "luatwit.util"

local _M = {}

local GET = function(path) return util.resource_builder("GET", path) end
local POST = function(path) return util.resource_builder("POST", path) end
local required = function(t) return { required = true, type = t } end

-- Base URL of the Twitter REST API.
_M._base_url = "https://api.twitter.com/1.1/%s.json"

-- URL of the OAuth authorization page
_M._authorize_url = "https://api.twitter.com/oauth/authorize"

-- Default members for all resources.
local resource_base = {
    _type = "resource",
    default_args = {
        stringify_ids = true,
        oauth_callback = "oob",
        stringify_friend_ids = true,
    },
    __call = util.resource_call,
}
resource_base.__index = resource_base
_M._resource_base = resource_base

--( OAuth )--

--- Allows a Consumer application to obtain an OAuth Request Token to request user authorization.
_M.oauth_request_token = POST "request_token"
    :args{
        oauth_callback = "string",
        x_auth_access_type = "string",
    }
    :base_url "https://api.twitter.com/oauth/%s"
    :type "access_token"

--- Allows a Consumer application to exchange the OAuth Request Token for an OAuth Access Token.
_M.oauth_access_token = POST "access_token"
    :args{
        oauth_verifier = required "string",
    }
    :base_url "https://api.twitter.com/oauth/%s"
    :type "access_token"

--( Timeline )--

--- Returns the 20 most recent mentions (tweets containing a users’s @screen_name) for the authenticating user.
_M.get_mentions = GET "statuses/mentions_timeline"
    :args{
        count = "integer",
        since_id = "integer",
        max_id = "integer",
        trim_user = "boolean",
        contributor_details = "boolean",
        include_entities = "boolean",
    }
    :type "tweet_list"

--- Returns a collection of the most recent Tweets posted by the user indicated by the screen_name or user_id parameters.
_M.get_user_timeline = GET "statuses/user_timeline"
    :args{
        user_id = "integer",
        screen_name = "string",
        since_id = "integer",
        count = "integer",
        max_id = "integer",
        trim_user = "boolean",
        exclude_replies = "boolean",
        contributor_details = "boolean",
        include_rts = "boolean",
    }
    :type "tweet_list"

--- Returns a collection of the most recent Tweets and retweets posted by the authenticating user and the users they follow.
_M.get_home_timeline = GET "statuses/home_timeline"
    :args{
        count = "integer",
        since_id = "integer",
        max_id = "integer",
        trim_user = "boolean",
        exclude_replies = "boolean",
        contributor_details = "boolean",
        include_entities = "boolean",
    }
    :type "tweet_list"

--- Returns the most recent tweets authored by the authenticating user that have been retweeted by others.
_M.get_retweets_of_me = GET "statuses/retweets_of_me"
    :args{
        count = "integer",
        since_id = "integer",
        max_id = "integer",
        trim_user = "boolean",
        include_entities = "boolean",
        include_user_entities = "boolean",
    }
    :type "tweet_list"

--( Tweets )--

--- Returns a collection of the 100 most recent retweets of the tweet specified by the id parameter.
_M.get_retweets = GET "statuses/retweets/:id"
    :args{
        id = required "integer",
        count = "integer",
        trim_user = "boolean",
    }
    :type "tweet_list"

--- Returns a single Tweet, specified by the id parameter.
_M.get_tweet = GET "statuses/show/:id"
    :args{
        id = required "integer",
        trim_user = "boolean",
        include_my_retweet = "boolean",
        include_entities = "boolean",
    }
    :type "tweet"

--- Destroys the status specified by the required ID parameter.
_M.delete_tweet = POST "statuses/destroy/:id"
    :args{
        id = required "integer",
        trim_user = "boolean",
    }
    :type "tweet"

--- Updates the authenticating user’s current status, also known as tweeting.
_M.tweet = POST "statuses/update"
    :args{
        status = required "string",
        in_reply_to_status_id = "integer",
        possibly_sensitive = "boolean",
        lat = "real",
        long = "real",
        place_id = "string",
        display_coordinates = "boolean",
        trim_user = "boolean",
        media_ids = "integer_list",
    }
    :type "tweet"

--- Retweets a tweet.
_M.retweet = POST "statuses/retweet/:id"
    :args{
        id = required "integer",
        trim_user = "boolean",
    }
    :type "tweet"

--- Returns information allowing the creation of an embedded representation of a Tweet on third party sites.
_M.oembed = GET "statuses/oembed"
    :args{
        id = required "integer",
        --url = "string",       -- full tweet url, only useful for web apps
        maxwidth = "integer",
        hide_media = "boolean",
        hide_thread = "boolean",
        omit_script = "boolean",
        align = "string",
        related = "string_list",
        lang = "string",
        widget_type = "string",
        hide_tweet = "boolean",
    }
    :type "oembed"

--- Returns a collection of up to 100 user IDs belonging to users who have retweeted the tweet specified by the id parameter.
_M.get_retweeter_ids = GET "statuses/retweeters/ids"
    :args{
        id = required "integer",
        cursor = "integer",
        stringify_ids = "boolean",
    }
    :type "userid_cursor"

--- Updates the authenticating user’s current status and attaches media for upload.
_M.tweet_with_media = POST "statuses/update_with_media"
    :args{
        status = required "string",
        ["media[]"] = required "file",
        possibly_sensitive = "boolean",
        in_reply_to_status_id = "integer",
        lat = "real",
        long = "real",
        place_id = "string",
        display_coordinates = "boolean",
    }
    :type "tweet"
    :multipart()

--- Returns fully-hydrated  tweet objects for up to 100 tweets per request, as specified by comma-separated values passed to the id parameter.
_M.lookup_tweets = GET "statuses/lookup"
    :args{
        id = required "integer_list",
        include_entities = "boolean",
        trim_user = "boolean",
        map = "boolean",
    }
    :type "tweet_list"

--- Upload media (images) to Twitter, to use in a Tweet or Twitter-hosted Card.
_M.upload_media = POST "media/upload"
    :args{
        media = required "file",
    }
    :type "media"
    :base_url "https://upload.twitter.com/1.1/%s.json"
    :multipart()

--( Search )--

--- Returns a collection of relevant Tweets matching a specified query.
_M.search_tweets = GET "search/tweets"
    :args{
        q = required "string",
        geocode = "string",
        lang = "string",
        locale = "string",
        result_type = "string",
        count = "integer",
        ["until"] = "date",
        since_id = "integer",
        max_id = "integer",
        include_entities = "boolean",
        --callback = "string",  -- generates JSONP, only for web apps
    }
    :type "tweet_search"

--( Direct Messages )--

--- Returns the most recent direct messages sent to the authenticating user.
_M.get_received_dms = GET "direct_messages"
    :args{
        since_id = "integer",
        max_id = "integer",
        count = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "dm_list"

--- Returns the 20 most recent direct messages sent by the authenticating user.
_M.get_sent_dms = GET "direct_messages/sent"
    :args{
        since_id = "integer",
        max_id = "integer",
        count = "integer",
        page = "integer",
        include_entities = "boolean",
    }
    :type "dm_list"

--- Returns a single direct message, specified by an id parameter.
_M.get_dm = GET "direct_messages/show"
    :args{
        id = required "integer",
    }
    :type "dm"

--- Destroys the direct message specified in the required ID parameter.
_M.delete_dm = POST "direct_messages/destroy"
    :args{
        id = required "integer",
        include_entities = "boolean",
    }
    :type "dm"

--- Sends a new direct message to the specified user from the authenticating user.
_M.send_dm = POST "direct_messages/new"
    :args{
        user_id = "integer",
        screen_name = "string",
        text = required "string",
    }
    :type "dm"

--( Friends & Followers )--

--- Returns a collection of user_ids that the currently authenticated user does not want to receive retweets from.
_M.get_disabled_rt_ids = GET "friendships/no_retweets/ids"
    :args{
        stringify_ids = "boolean",
    }
    :type "userid_array"

--- Returns a cursored collection of user IDs for every user the specified user is following (otherwise known as their “friends”).
_M.get_following_ids = GET "friends/ids"
    :args{
        user_id = "integer",
        screen_name = "string",
        cursor = "integer",
        stringify_ids = "boolean",
        count = "integer",
    }
    :type "userid_cursor"

--- Returns a cursored collection of user IDs for every user following the specified user.
_M.get_followers_ids = GET "followers/ids"
    :args{
        user_id = "integer",
        screen_name = "string",
        cursor = "integer",
        stringify_ids = "boolean",
        count = "integer",
    }
    :type "userid_cursor"

--- Returns the relationships of the authenticating user to the comma-separated list of up to 100 screen_names or user_ids provided.
_M.lookup_friendships = GET "friendships/lookup"
    :args{
        screen_name = "string_list",
        user_id = "integer_list",
    }
    :type "friendship_list"

--- Returns a collection of numeric IDs for every user who has a pending request to follow the authenticating user.
_M.get_incoming_follow_requests = GET "friendships/incoming"
    :args{
        cursor = "integer",
        stringify_ids = "boolean",
    }
    :type "userid_cursor"

--- Returns a collection of numeric IDs for every protected user for whom the authenticating user has a pending follow request.
_M.get_outgoing_follow_requests = GET "friendships/outgoing"
    :args{
        cursor = "integer",
        stringify_ids = "boolean",
    }
    :type "userid_cursor"

--- Allows the authenticating users to follow the user specified in the ID parameter.
_M.follow = POST "friendships/create"
    :args{
        screen_name = "string",
        user_id = "integer",
        follow = "boolean",
    }
    :type "user"

--- Allows the authenticating user to unfollow the user specified in the ID parameter.
_M.unfollow = POST "friendships/destroy"
    :args{
        screen_name = "string",
        user_id = "integer",
    }
    :type "user"

--- Allows one to enable or disable retweets and device notifications from the specified user.
_M.set_follow_settings = POST "friendships/update"
    :args{
        screen_name = "string",
        user_id = "integer",
        device = "boolean",
        retweets = "boolean",
    }
    :type "relationship_container"

--- Returns detailed information about the relationship between two arbitrary users.
_M.get_friendship = GET "friendships/show"
    :args{
        source_id = "integer",
        source_screen_name = "string",
        target_id = "integer",
        target_screen_name = "string",
    }
    :type "relationship_container"

--- Returns a cursored collection of user objects for every user the specified user is following (otherwise known as their “friends”).
_M.get_following = GET "friends/list"
    :args{
        user_id = "integer",
        screen_name = "string",
        cursor = "integer",
        count = "integer",
        skip_status = "boolean",
        include_user_entities = "boolean",
    }
    :type "user_cursor"

--- Returns a cursored collection of user objects for users following the specified user.
_M.get_followers = GET "followers/list"
    :args{
        user_id = "integer",
        screen_name = "string",
        cursor = "integer",
        count = "integer",
        skip_status = "boolean",
        include_user_entities = "boolean",
    }
    :type "user_cursor"

--( Users )--

--- Returns settings (including current trend, geo and sleep time information) for the authenticating user.
_M.get_account_settings = GET "account/settings"
    :args{
        -- empty
    }
    :type "account_settings"

--- Returns an HTTP 200 OK response code and a representation of the requesting user if authentication was successful; returns a 401 status code and an error message if not.
_M.verify_credentials = GET "account/verify_credentials"
    :args{
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Updates the authenticating user’s settings.
_M.set_account_settings = POST "account/settings"
    :args{
        trend_location_woeid = "integer",
        sleep_time_enabled = "boolean",
        start_sleep_time = "integer",
        end_sleep_time = "integer",
        time_zone = "string",
        lang = "string",
    }
    :type "account_settings"

--- Sets which device Twitter delivers updates to for the authenticating user.
_M.update_delivery_device = POST "account/update_delivery_device"
    :args{
        device = required "string",
        include_entities = "boolean",
    }

--- Sets some values that users are able to set under the “Account” tab of their settings page.
_M.update_profile = POST "account/update_profile"
    :args{
        name = "string",
        url = "string",
        location = "string",
        description = "string",
        profile_link_color = "string",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Updates the authenticating user’s profile background image.
_M.set_profile_background_image = POST "account/update_profile_background_image"
    :args{
        image = "base64",
        tile = "boolean",
        include_entities = "boolean",
        skip_status = "boolean",
        use = "boolean",
    }
    :type "user"

--- Updates the authenticating user’s profile image.
_M.set_profile_image = POST "account/update_profile_image"
    :args{
        image = required "base64",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Returns a collection of user objects that the authenticating user is blocking.
_M.get_blocked_users = GET "blocks/list"
    :args{
        include_entities = "boolean",
        skip_status = "boolean",
        cursor = "integer",
    }
    :type "user_cursor"

--- Returns an array of numeric user ids the authenticating user is blocking.
_M.get_blocked_ids= GET "blocks/ids"
    :args{
        stringify_ids = "boolean",
        cursor = "integer",
    }
    :type "userid_cursor"

--- Blocks the specified user from following the authenticating user.
_M.block_user = POST "blocks/create"
    :args{
        screen_name = "string",
        user_id = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Un-blocks the user specified in the ID parameter for the authenticating user.
_M.unblock_user = POST "blocks/destroy"
    :args{
        screen_name = "string",
        user_id = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Returns fully-hydrated user objects for up to 100 users per request, as specified by comma-separated values passed to the user_id and/or screen_name parameters.
_M.lookup_users = GET "users/lookup"
    :args{
        screen_name = "string_list",
        user_id = "integer_list",
        include_entities = "boolean",
    }
    :type "user_list"

--- Returns a variety of information about the user specified by the required user_id or screen_name parameter.
_M.get_user = GET "users/show"
    :args{
        user_id = "integer",
        screen_name = "string",
        include_entities = "boolean",
    }
    :type "user"

--- Provides a simple, relevance-based search interface to public user accounts on Twitter.
_M.search_users = GET "users/search"
    :args{
        q = required "string",
        page = "integer",
        count = "integer",
        include_entities = "boolean",
    }
    :type "user_list"

--[[ These methods always return the error "Your credentials do not allow access to this resource".
     Not documented in official site, so possibly retired or internal use.
--- Returns a collection of users that the specified user can "contribute" to.
_M.get_contributees = GET "users/contributees"
    :args{
        user_id = "integer",
        screen_name = "string",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user_list"

--- Returns a collection of users who can contribute to the specified account.
_M.get_contributors = GET "users/contributors"
    :args{
        user_id = "integer",
        screen_name = "string",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user_list"
]]

--- Removes the uploaded profile banner for the authenticating user.
_M.remove_profile_banner = POST "account/remove_profile_banner"
    :args{
        -- empty
    }

--- Uploads a profile banner on behalf of the authenticating user.
_M.set_profile_banner = POST "account/update_profile_banner"
    :args{
        banner = required "base64",
        width = "integer",
        height = "integer",
        offset_left = "integer",
        offset_top = "integer",
    }

--- Returns a map of the available size variations of the specified user’s profile banner.
_M.get_profile_banner = GET "users/profile_banner"
    :args{
        user_id = "integer",
        screen_name = "string",
    }
    :type "profile_banner"

--- Mutes the user specified in the ID parameter for the authenticating user.
_M.mute_user = POST "mutes/users/create"
    :args{
        screen_name = "string",
        user_id = "integer",
    }
    :type "user"

--- Un-mutes the user specified in the ID parameter for the authenticating user.
_M.unmute_user = POST "mutes/users/destroy"
    :args{
        screen_name = "string",
        user_id = "integer",
    }
    :type "user"

--- Returns an array of numeric user ids the authenticating user has muted.
_M.get_muted_ids = GET "mutes/users/ids"
    :args{
        cursor = "integer",
    }
    :type "userid_cursor"

--- Returns an array of user objects the authenticating user has muted.
_M.get_muted_users = GET "mutes/users/list"
    :args{
        cursor = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user_cursor"

--( Suggested Users )--

--- Access the users in a given category of the Twitter suggested user list.
_M.get_suggestion_category = GET "users/suggestions/:slug"
    :args{
        slug = required "string",
        lang = "string",
    }
    :type "suggestion_category"

--- Access to Twitter’s suggested user list.
_M.get_suggestion_categories = GET "users/suggestions"
    :args{
        lang = "string",
    }
    :type "suggestion_category_list"

--- Access the users in a given category of the Twitter suggested user list and return their most recent status if they are not a protected user.
_M.get_suggestion_users = GET "users/suggestions/:slug/members"
    :args{
        slug = required "string",
    }
    :type "user_list"

--( Favorites )--

--- Returns the 20 most recent Tweets favorited by the authenticating or specified user.
_M.get_favorites = GET "favorites/list"
    :args{
        user_id = "integer",
        screen_name = "string",
        count = "integer",
        since_id = "integer",
        max_id = "integer",
        include_entities = "boolean",
    }
    :type "tweet_list"

--- Un-favorites the status specified in the ID parameter as the authenticating user.
_M.unset_favorite = POST "favorites/destroy"
    :args{
        id = required "integer",
        include_entities = "boolean",
    }
    :type "tweet"

--- Favorites the status specified in the ID parameter as the authenticating user.
_M.set_favorite = POST "favorites/create"
    :args{
        id = required "integer",
        include_entities = "boolean",
    }
    :type "tweet"

--( Lists )--

--- Returns all lists the authenticating or specified user subscribes to, including their own.
_M.get_all_lists = GET "lists/list"
    :args{
        user_id = "integer",
        screen_name = "string",
        reverse = "boolean",
    }
    :type "userlist_list"

--- Returns a timeline of tweets authored by members of the specified list.
_M.get_list_timeline = GET "lists/statuses"
    :args{
        list_id = "integer",
        slug = "string",
        owner_screen_name = "string",
        owner_id = "integer",
        since_id = "integer",
        max_id = "integer",
        count = "integer",
        include_entities = "boolean",
        include_rts = "boolean",
    }
    :type "tweet_list"

--- Removes the specified member from the list.
_M.remove_list_member = POST "lists/members/destroy"
    :args{
        list_id = "integer",
        slug = "string",
        user_id = "integer",
        screen_name = "string",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Returns the lists the specified user has been added to.
_M.get_lists_following_user = GET "lists/memberships"
    :args{
        user_id = "integer",
        screen_name = "string",
        count = "integer",
        cursor = "integer",
        filter_to_owned_lists = "boolean",
    }
    :type "userlist_cursor"

--- Returns the subscribers of the specified list.
_M.get_list_followers = GET "lists/subscribers"
    :args{
        list_id = "integer",
        slug = "string",
        owner_screen_name = "string",
        owner_id = "integer",
        count = "integer",
        cursor = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user_cursor"

--- Subscribes the authenticated user to the specified list.
_M.follow_list = POST "lists/subscribers/create"
    :args{
        owner_screen_name = "string",
        owner_id = "integer",
        list_id = "integer",
        slug = "string",
    }
    :type "userlist"

--- Check if the specified user is a subscriber of the specified list.
_M.is_following_list = GET "lists/subscribers/show"
    :args{
        owner_screen_name = "string",
        owner_id = "integer",
        list_id = "integer",
        slug = "string",
        user_id = "integer",
        screen_name = "string",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Unsubscribes the authenticated user from the specified list.
_M.unfollow_list = POST "lists/subscribers/destroy"
    :args{
        list_id = "integer",
        slug = "string",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Adds multiple members to a list, by specifying a comma-separated list of member ids or screen names.
_M.add_multiple_list_members = POST "lists/members/create_all"
    :args{
        list_id = "integer",
        slug = "string",
        user_id = "integer_list",
        screen_name = "string_list",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Check if the specified user is a member of the specified list.
_M.is_member_of_list = GET "lists/members/show"
    :args{
        list_id = "integer",
        slug = "string",
        user_id = "integer",
        screen_name = "string",
        owner_screen_name = "string",
        owner_id = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user"

--- Returns the members of the specified list.
_M.get_list_members = GET "lists/members"
    :args{
        list_id = "integer",
        slug = "string",
        owner_screen_name = "string",
        owner_id = "integer",
        count = "integer",
        cursor = "integer",
        include_entities = "boolean",
        skip_status = "boolean",
    }
    :type "user_cursor"

--- Add a member to a list.
_M.add_list_member = POST "lists/members/create"
    :args{
        list_id = "integer",
        slug = "string",
        user_id = "integer",
        screen_name = "string",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Deletes the specified list.
_M.delete_list = POST "lists/destroy"
    :args{
        owner_screen_name = "string",
        owner_id = "integer",
        list_id = "integer",
        slug = "string",
    }
    :type "userlist"

--- Updates the specified list.
_M.update_list = POST "lists/update"
    :args{
        list_id = "integer",
        slug = "string",
        name = "string",
        mode = "string",
        description = "string",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Creates a new list for the authenticated user.
_M.create_list = POST "lists/create"
    :args{
        name = required "string",
        mode = "string",
        description = "string",
    }
    :type "userlist"

--- Returns the specified list.
_M.get_list = GET "lists/show"
    :args{
        list_id = "integer",
        slug = "string",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Obtain a collection of the lists the specified user is subscribed to, 20 lists per page by default.
_M.get_followed_lists = GET "lists/subscriptions"
    :args{
        user_id = "integer",
        screen_name = "string",
        count = "integer",
        cursor = "integer",
    }
    :type "userlist_cursor"

--- Removes multiple members from a list, by specifying a comma-separated list of member ids or screen names.
_M.remove_multiple_list_members = POST "lists/members/destroy_all"
    :args{
        list_id = "integer",
        slug = "string",
        user_id = "integer_list",
        screen_name = "string_list",
        owner_screen_name = "string",
        owner_id = "integer",
    }
    :type "userlist"

--- Returns the lists owned by the specified Twitter user.
_M.get_own_lists = GET "lists/ownerships"
    :args{
        user_id = "integer",
        screen_name = "string",
        count = "integer",
        cursor = "integer",
    }
    :type "userlist_cursor"

--( Saved Searches )--

--- Returns the authenticated user’s saved search queries.
_M.get_saved_searches = GET "saved_searches/list"
    :args{
        -- empty
    }
    :type "saved_search_list"

--- Retrieve the information for the saved search represented by the given id.
_M.get_saved_search = GET "saved_searches/show/:id"
    :args{
        id = required "integer",
    }
    :type "saved_search"

--- Create a new saved search for the authenticated user.
_M.create_saved_search = POST "saved_searches/create"
    :args{
        query = required "string",
    }
    :type "saved_search"

--- Destroys a saved search for the authenticating user.
_M.delete_saved_search = POST "saved_searches/destroy/:id"
    :args{
        id = required "integer",
    }
    :type "saved_search"

--( Places & Geo )--

--- Returns all the information about a known place.
_M.get_place = GET "geo/id/:place_id"
    :args{
        place_id = required "string",
    }
    :type "place"

--- Given a latitude and a longitude, searches for up to 20 places that can be used as a place_id when updating a status.
_M.reverse_geocode = GET "geo/reverse_geocode"
    :args{
        lat = required "real",
        long = required "real",
        accuracy = "string",
        granularity = "string",
        max_results = "integer",
        --callback = "string",  -- generates JSONP, only for web apps
    }
    :type "place_search"

--- Search for places that can be attached to a statuses/update.
_M.search_places = GET "geo/search"
    :args{
        lat = "real",
        long = "real",
        query = "string",
        ip = "string",
        granularity = "string",
        accuracy = "string",
        max_results = "integer",
        contained_within = "string",
        --attribute = "string", -- misc attribute:<key> values
        --callback = "string",  -- generates JSONP, only for web apps
    }
    :type "place_search"

--- Locates places near the given coordinates which are similar in name. UNDOCUMENTED
_M.get_similar_places = GET "geo/similar_places"
    :args{
        lat = required "real",
        long = required "real",
        name = required "string",
        contained_within = "string",
        --attribute = "string", -- misc attribute:<key> values
        --callback = "string",  -- generates JSONP, only for web apps
    }
    :type "place_search"

--( Trends )--

--- Returns the top 10 trending topics for a specific WOEID, if trending information is available for it.
_M.get_trends = GET "trends/place"
    :args{
        id = required "integer",
        exclude = "string",
    }
    :type "trends_container_list"

--- Returns the locations that Twitter has trending topic information for.
_M.get_all_trends_locations = GET "trends/available"
    :args{
        -- empty
    }
    :type "trend_location_list"

--- Returns the locations that Twitter has trending topic information for, closest to a specified location.
_M.find_trends_location = GET "trends/closest"
    :args{
        lat = required "real",
        long = required "real",
    }
    :type "trend_location_list"

--( Spam Reporting )--

--- Report the specified user as a spam account to Twitter.
_M.report_spam = POST "users/report_spam"
    :args{
        screen_name = "string",
        user_id = "integer",
    }
    :type "user"

--( Help )--

--- Returns the current configuration used by Twitter including twitter.com slugs which are not usernames, maximum photo resolutions, and t.co URL lengths.
_M.get_service_config = GET "help/configuration"
    :args{
        -- empty
    }
    :type "service_config"

--- Returns the list of languages supported by Twitter along with the language code supported by Twitter.
_M.get_languages = GET "help/languages"
    :args{
        -- empty
    }
    :type "language_list"

--- Returns Twitter’s Privacy Policy.
_M.get_privacy_policy = GET "help/privacy"
    :args{
        -- empty
    }
    :type "privacy"

--- Returns the Twitter Terms of Service.
_M.get_tos = GET "help/tos"
    :args{
        -- empty
    }
    :type "tos"

--- Returns the current rate limits for methods belonging to the specified resource families.
_M.get_rate_limit = GET "application/rate_limit_status"
    :args{
        resources = "string_list",
    }
    :type "rate_limit"

--( Streaming )--

--- Returns a small random sample of all public statuses.
_M.stream_sample = GET "statuses/sample"
    :args{
        delimited = "string",
        stall_warnings = "boolean",
    }
    :type "_guess"
    :base_url "https://stream.twitter.com/1.1/%s.json"
    :stream()

--- Returns public statuses that match one or more filter predicates.
_M.stream_filter = POST "statuses/filter"
    :args{
        follow = "integer_list",
        track = "string_list",
        locations = "string_list",
        delimited = "string",
        stall_warnings = "boolean",
    }
    :type "_guess"
    :base_url "https://stream.twitter.com/1.1/%s.json"
    :stream()

--- Streams messages for a single user, as described in User streams.
_M.stream_user = GET "user"
    :args{
        delimited = "string",
        stall_warnings = "boolean",
        with = "string",
        replies = "string",
        track = "string_list",
        locations = "string_list",
        stringify_friend_ids = "boolean",
    }
    :type "_guess"
    :base_url "https://userstream.twitter.com/1.1/%s.json"
    :stream()

--- Streams messages for a set of users, as described in Site streams.
_M.stream_site = GET "site"
    :args{
        follow = "integer_list",
        delimited = "string",
        stall_warnings = "boolean",
        with = "string",
        replies = "string",
        stringify_friend_ids = "boolean",
    }
    :type "_guess"
    :base_url "https://sitestream.twitter.com/1.1/%s.json"
    :stream()

--- Returns all public statuses.
_M.stream_firehose = GET "statuses/firehose"
    :args{
        count = "integer",
        delimited = "string",
        stall_warnings = "boolean",
    }
    :type "_guess"
    :base_url "https://stream.twitter.com/1.1/%s.json"
    :stream()

-- Stuff seen in the rate limit info:
-- "users/derived_info" -> error: Client is not permitted to perform this action.
-- "device/token" -> { token = <random string> }
-- "help/settings" -> lots of stuff, seem to be propietary app data
-- "direct_messages/sent_and_received" -> error: Sorry, that page does not exist
-- "account/login_verification_enrollment" -> error: Client is not permitted to perform this action.


-- fill in the name field and set the mt
for name, obj in pairs(_M) do
    if util.type(obj) == "resource_builder" then
        obj:finish(name, resource_base)
    end
end

return _M
