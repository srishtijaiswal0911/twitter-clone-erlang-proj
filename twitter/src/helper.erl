-module(helper).

-author("srish").

-export([help_hashtags_tweets/4, help_mentions_tweets/5,
         help_send_tweet_subscriptions/4, help_get_usernames/3, get_timestamp/0, get_id/0]).

get_random_string(Length, Allowed) ->
    L = lists:foldl(fun(_, Acc) ->
                        [lists:nth(
                            rand:uniform(length(Allowed)), Allowed)]
                        ++ Acc
                    end,
                    [],
                    lists:seq(1, Length)),
    L.

get_timestamp() ->
    {Mega, Sec, Micro} = os:timestamp(),
    (Mega * 1000000 + Sec) * 1000 + Micro / 1000.

get_id() ->
    {ok, Fd} = file:open("server.txt", [read]),
    {ok, A} = file:read(Fd, 1024),
    file:close(Fd),
    list_to_pid(A).



help_send_tweet_subscriptions(Subscriptions, Index, Tweet, Server_Id) ->
    if Index > length(Subscriptions) ->
           ok;
       true ->
           Server_Id ! {add_tweet_feed, lists:nth(Index, Subscriptions), Tweet},
           help_send_tweet_subscriptions(Subscriptions, Index + 1, Tweet, Server_Id)
    end.



help_hashtags_tweets(Splited_Tweet, Index, Server_Id, Tweet) ->
    if Index > length(Splited_Tweet) ->
           ok;
       true ->
           S = lists:nth(Index, Splited_Tweet),
           B = string:equal("#", string:sub_string(S, 1, 1)),
           if B ->
                  Server_Id ! {update_hashtag_mapping, S, Tweet},
                  help_hashtags_tweets(Splited_Tweet, Index + 1, Server_Id, Tweet);
              true ->
                  help_hashtags_tweets(Splited_Tweet, Index + 1, Server_Id, Tweet)
           end
    end.
help_mentions_tweets(Splited_Tweet, Index, Server_Id, L, Tweet) ->
    if Index > length(Splited_Tweet) ->
           L;
       true ->
           S = lists:nth(Index, Splited_Tweet),
           B = string:equal("@", string:sub_string(S, 1, 1)),
           if B ->
                  Server_Id ! {update_mention_mapping, S, Tweet},
                  L1 = lists:append(L, [string:sub_string(S, 2)]),
                  help_mentions_tweets(Splited_Tweet, Index + 1, Server_Id, L1, Tweet);
              true ->
                  help_mentions_tweets(Splited_Tweet, Index + 1, Server_Id, L, Tweet)
           end
    end.



help_get_usernames(0, L, _) ->
    L;
help_get_usernames(N, L, Id) ->
    Allowed = "abcdefghijklmnopqrstuvwxyz",
    S = get_random_string(4, Allowed),
    B = lists:any(fun(E) -> E == S end, L),
    if B ->
           help_get_usernames(N, L, Id);
       true ->
           client:register(S, S, S, Id),
           help_get_usernames(N - 1, lists:append([S], L), Id)
    end.



