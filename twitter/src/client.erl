-module(client).

-author("srish").

-export([tweet/3, register/4, retweet/3, subscribe/3, search_hashtag/3, search_mention/3,
         message_handl/1, get_feed/2, search_subscribe/3]).

message_handl(My_Profile) ->
    {ok, Fd} = file:open("output.txt", [append]),
    Size = maps:size(My_Profile),
    if Size > 0 ->
           maps:get("server", My_Profile)
           ! {add_profile, maps:get("username", My_Profile), My_Profile};
       true ->
           ok
    end,
    receive
        {subscribe, Friend_Profile, User_Id} ->
            Profile_Subscription = maps:get("subscriptions", My_Profile),
            New_Profile_Subscription = lists:append([Friend_Profile], Profile_Subscription),
            Updated_Profile = maps:put("subscriptions", New_Profile_Subscription, My_Profile),
            User_Id ! {ok, "Subscription_Done"},
            message_handl(Updated_Profile);
        {subscribed_to, Username2, User_Id} ->
            Profile_Subscription = maps:get("subscribed", My_Profile),
            New_Profile_Subscription = lists:append([Username2], Profile_Subscription),
            Updated_Profile = maps:put("subscribed", New_Profile_Subscription, My_Profile),
            User_Id ! {ok, "Subscription_Done"},
            message_handl(Updated_Profile);
        {feed, Tweet} ->
            Feed = maps:get("feed", My_Profile),
            New_Tweets = lists:append(Feed, [Tweet]),
            Updated_Profile = maps:put("feed", New_Tweets, My_Profile),
            io:fwrite("~p:Adding to Feed ~n", [maps:get("username", My_Profile)]),
            message_handl(Updated_Profile);
        {search_hashtag, Hashtag, Tweets, User_Id} ->
            io:fwrite(Fd,
                      "~p:SEARCHED HASTAGS ~p Results : ~p ~n",
                      [maps:get("username", My_Profile), Hashtag, Tweets]),
            User_Id ! {ok, Tweets},
            message_handl(My_Profile);
        {search_mention, Mention, Tweets, User_Id} ->
            io:fwrite(Fd,
                      "~p:SEARCHED MENTIONS ~p Results : ~p ~n",
                      [maps:get("username", My_Profile), Mention, Tweets]),
            User_Id ! {ok, Tweets},
            message_handl(My_Profile);
        {tweet, Tweet, User_Id} ->
            Splited_Tweet = string:split(Tweet, " ", all),
            helper:help_hashtags_tweets(Splited_Tweet,
                                               1,
                                               maps:get("server", My_Profile),
                                               Tweet),
            Mentions =
                helper:help_mentions_tweets(Splited_Tweet,
                                                   1,
                                                   maps:get("server", My_Profile),
                                                   [],
                                                   Tweet),
            Tweets = maps:get("tweets", My_Profile),
            New_Tweets = lists:append(Tweets, [Tweet]),
            Updated_Profile = maps:put("tweets", New_Tweets, My_Profile),
            L = lists:append(Mentions, maps:get("subscriptions", My_Profile)),
            helper:help_send_tweet_subscriptions(L, 1, Tweet, maps:get("server", My_Profile)),
            io:fwrite("~p:Tweet was Added ~n", [maps:get("username", My_Profile)]),
            User_Id ! {ok, "Tweet_Added"},
            message_handl(Updated_Profile);
        {start, Profile} ->
            message_handl(Profile)
    end.

subscribe(Username1, Username2, Server_Id) ->
    Server_Id ! {subscribe, Username1, Username2, self()},
    receive
        {ok, S} ->
            S
    end.

search_hashtag(Username, Hashtag, Server_Id) ->
    Server_Id ! {search_hashtag, Username, Hashtag, self()},
    receive
        {ok, S} ->
            S
    end.

search_mention(Username, Hashtag, Server_Id) ->
    Server_Id ! {search_mention, Username, Hashtag, self()},
    receive
        {ok, S} ->
            S
    end.

search_subscribe(Username1, Username2, Server_Id) ->
    Server_Id ! {search_subscribe, Username1, Username2, self()},
    receive
        {ok, S} ->
            S
    end.

get_feed(Username, Server_Id) ->
    Server_Id ! {get_feed, Username, self()},
    receive
        {ok, S} ->
            S
    end.

tweet(Username, Tweet, Server_Id) ->
    Server_Id ! {tweet, Username, Tweet, self()},
    receive
        {ok, S} ->
            S
    end.

retweet(Username, Tweet, Server_Id) ->
    Server_Id ! {retweet, Username, Tweet, self()},
    receive
        {ok, S} ->
            S
    end.

register(Username, Password, Email, Server_Id) ->
    Pid = spawn(client, message_handl, [#{}]),
    Profile = #{"server" => Server_Id},
    Profile_Username = maps:put("username", Username, Profile),
    Profile_Password = maps:put("password", Password, Profile_Username),
    Profile_Email = maps:put("email", Email, Profile_Password),
    Profile_Tweet_List = maps:put("tweets", [], Profile_Email),
    Profile_Subscription = maps:put("subscriptions", [], Profile_Tweet_List),
    Profile_Feed = maps:put("feed", [], Profile_Subscription),
    Profile_Sub = maps:put("subscribed", [], Profile_Feed),
    Profile_Id = maps:put("id", Pid, Profile_Sub),

    Pid ! {start, Profile_Id},
    Server_Id ! {add_profile, Username, Profile_Id, self()},
    receive
        {ok, S} ->
            S;
        {error} ->
            []
    end.
