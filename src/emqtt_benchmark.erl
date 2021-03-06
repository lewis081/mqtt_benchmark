%%%-----------------------------------------------------------------------------
%%% @Copyright (C) 2014-2016, Feng Lee <feng@emqtt.io>
%%%
%%% Permission is hereby granted, free of charge, to any person obtaining a copy
%%% of this software and associated documentation files (the "Software"), to deal
%%% in the Software without restriction, including without limitation the rights
%%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%%% copies of the Software, and to permit persons to whom the Software is
%%% furnished to do so, subject to the following conditions:
%%%
%%% The above copyright notice and this permission notice shall be included in all
%%% copies or substantial portions of the Software.
%%%
%%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%%% SOFTWARE.
%%%-----------------------------------------------------------------------------

-module(emqtt_benchmark).

-export([main/2, start/2, run/3, connect/4, loop/5]).

-define(TAB, eb_stats).

%ADD BY LEWIS----
time_stamp(Val) ->
    % list_to_binary(lists:concat([",\"time_stamp\":\"", 1505898000000+Val,"\"}"])).
    {MegaS1, S1, MicroS1} = os:timestamp(),
    % io:format("timestamp: [~w ~w ~6w] (~w)~n",
    %                             [MegaS1, S1, MicroS1, (MegaS1 * 1000000 + S1)*1000 + round(MicroS1/1000)]),
    list_to_binary(lists:concat([",\"time_stamp\":\"", (MegaS1 * 1000000 + S1)*1000 + round(MicroS1/1000),"\"}"])).

pay_load(N, Opts) ->
    case proplists:get_value(workmode, Opts) of
        "send"    ->  
            list_to_binary(lists:concat(["{\"datas\":{\"green\":\"010402000178F0\",\"ngnum\":\"01040270295D2E\",\"oknum\":\"010402B914CAAF\",\"red\":\"0104020000B930\",\"total\":\"0104020000B930\",\"yellow\":\"0104020000B930\"},\"uuid\":\"uuid_", N, "\""]));  
        "request" ->  
            list_to_binary(lists:concat(["{\"dbName\":\"key_", (N div 500) + 1, "\",\"sentense\":\"select * from oknum where uuid='uuid_", N, "' order by time desc limit 1\",\"id\":\"ecuuid_", N, "\"}"]))
    end.

sim_id(N, Opts) ->
    case proplists:get_value(workmode, Opts) of
        "send"    ->  
            list_to_binary(lists:concat(["uuidBox_", N]));
        "request" ->  
            list_to_binary(lists:concat(["uuidInfluxClient_", N]))
    end.

getPayload(Payload, Opts) ->
    case proplists:get_value(pl, Opts) == "none" of
        true ->
            case proplists:get_value(workmode, Opts) of
                "send"    ->  
                    [{_, Val}] = ets:lookup(?TAB, sent),
                    list_to_binary(string:concat(binary_to_list(Payload), binary_to_list(time_stamp(Val))));
                "request" ->  
                    Payload
            end;
        false ->
            list_to_binary(proplists:get_value(pl, Opts))
    end.
%ADD BY LEWIS****

main(sub, Opts) ->
    start(sub, Opts);

main(pub, Opts) ->
    Pid = self(),
    % Size    = proplists:get_value(size, Opts),
    %Payload = iolist_to_binary([O || O <- lists:duplicate(Size, "a")]),
    %start(pub, [{payload, Payload} | Opts]).
    
    start(pub, Opts).

start(PubSub, Opts) ->
    prepare(), init(),
    spawn(?MODULE, run, [self(), PubSub, Opts]),
    timer:send_interval(1000, stats),
    main_loop(os:timestamp(), 1+proplists:get_value(startnumber, Opts), 0).

prepare() ->
    application:ensure_all_started(emqtt_benchmark).

init() ->
    ets:new(?TAB, [public, named_table, {write_concurrency, true}]),
    put({stats, recv}, 0),
    ets:insert(?TAB, {recv, 0}),
    put({stats, sent}, 0),
    ets:insert(?TAB, {sent, 0}).

main_loop(Uptime, Count, PubCount) ->
	%io:format("count: ~w~n", [PubCount]),
	receive
		{connected, _N, _Client} ->
			io:format("conneted: ~w~n", [Count]),
			main_loop(Uptime, Count+1, PubCount+1);
        stats ->
            print_stats(Uptime),
			main_loop(Uptime, Count, PubCount+1);
        Msg ->
            io:format("~p~n", [Msg]),
            main_loop(Uptime, Count, PubCount+1 )
	end.

print_stats(Uptime) ->
    print_stats(Uptime, recv),
    print_stats(Uptime, sent).

print_stats(Uptime, Key) ->
    [{Key, Val}] = ets:lookup(?TAB, Key),
    LastVal = get({stats, Key}),
    case Val == LastVal of
        false ->
            Tdiff = timer:now_diff(os:timestamp(), Uptime) div 1000,
            io:format("~s(~w): total=~w, rate=~w(msg/sec)~n",
                        [Key, Tdiff, Val, Val - LastVal]),
	    %process_flag(trap_exit, true),
            put({stats, Key}, Val);
        true  ->
            ok
    end.


run(Parent, PubSub, Opts) ->
    run(Parent, proplists:get_value(count, Opts), PubSub, Opts).

run(_Parent, 0, _PubSub, _Opts) ->
    done;
run(Parent, N, PubSub, Opts) ->
    %io:format("run---"),
    Payload = pay_load(N, Opts),
    %opts = [{payload, Payload} | Opts],
    spawn(?MODULE, connect, [Parent, N+proplists:get_value(startnumber, Opts), PubSub, [{payload, Payload} | Opts]]),
	timer:sleep(proplists:get_value(interval, [{payload, Payload} | Opts])),
	run(Parent, N-1, PubSub, [{payload, Payload} | Opts]).
    
connect(Parent, N, PubSub, Opts) ->
    process_flag(trap_exit, true),

    random:seed(os:timestamp()),
    ClientId = client_id(PubSub, N, Opts),
    MqttOpts = [{client_id, ClientId} | mqtt_opts(Opts)],
    TcpOpts  = tcp_opts(Opts),
    AllOpts  = [{seq, N}, {client_id, ClientId} | Opts],
	case emqttc:start_link(MqttOpts, TcpOpts) of
    {ok, Client} ->
        Parent ! {connected, N, Client},
        case PubSub of
            sub ->
                subscribe(Client, AllOpts);
            pub ->
               Interval = proplists:get_value(interval_of_msg, Opts),
               timer:send_interval(Interval, publish)
        end,
        loop(Parent, N, Client, PubSub, AllOpts);
    {error, Error} ->
        io:format("client ~p connect error: ~p~n", [N, Error])
    end.



loop(Parent, N, Client, PubSub, Opts) ->
    receive
        publish ->
            % publish(Client, Opts),
            % ets:update_counter(?TAB, sent, {2, 1}),
            % loop(N, Client, PubSub, Opts);

            [{_, Val}] = ets:lookup(?TAB, sent),
            case proplists:get_value(pubcount, Opts) =< 0 of
                true ->
                    % io:format("total=~w ~n", [Val]),
                    publish(Client, Opts),
                    ets:update_counter(?TAB, sent, {2, 1}),
                    loop(Parent, N, Client, PubSub, Opts);
                false ->
            	    case Val =< (proplists:get_value(pubcount, Opts) - 1) of
                        true ->
                            % io:format("total=~w ~n", [Val]),
                            publish(Client, Opts),
                            ets:update_counter(?TAB, sent, {2, 1}),
                            loop(Parent, N, Client, PubSub, Opts);
                        false ->
                            exit(Parent, kill)
                    end
    	    end;
        {publish, _Topic, _Payload} ->
            ets:update_counter(?TAB, recv, {2, 1}),
            loop(Parent, N, Client, PubSub, Opts);
        {'EXIT', Client, Reason} ->
            io:format("client ~p EXIT: ~p~n", [N, Reason])
	end.

subscribe(Client, Opts) ->
    Qos = proplists:get_value(qos, Opts),
    emqttc:subscribe(Client, [{Topic, Qos} || Topic <- topics_opt(Opts)]).

% pub CORE
publish(Client, Opts) ->
    Flags   = [{qos, proplists:get_value(qos, Opts)},
               {retain, proplists:get_value(retain, Opts)}],
    Payload = proplists:get_value(payload, Opts),
    emqttc:publish(Client, topic_opt(Opts), getPayload(Payload, Opts), Flags).
    

mqtt_opts(Opts) ->
    SslOpts = ssl_opts(Opts),
    [{logger, error}|mqtt_opts([SslOpts|Opts], [])].
mqtt_opts([], Acc) ->
    Acc;
mqtt_opts([{host, Host}|Opts], Acc) ->
    mqtt_opts(Opts, [{host, Host}|Acc]);
mqtt_opts([{port, Port}|Opts], Acc) ->
    mqtt_opts(Opts, [{port, Port}|Acc]);
mqtt_opts([{username, Username}|Opts], Acc) ->
    mqtt_opts(Opts, [{username, list_to_binary(Username)}|Acc]);
mqtt_opts([{password, Password}|Opts], Acc) ->
    mqtt_opts(Opts, [{password, list_to_binary(Password)}|Acc]);
mqtt_opts([{keepalive, I}|Opts], Acc) ->
    mqtt_opts(Opts, [{keepalive, I}|Acc]);
mqtt_opts([{clean, Bool}|Opts], Acc) ->
    mqtt_opts(Opts, [{clean_sess, Bool}|Acc]);
mqtt_opts([{ssl, true} | Opts], Acc) ->
    mqtt_opts(Opts, [ssl|Acc]);
mqtt_opts([{ssl, false} | Opts], Acc) ->
    mqtt_opts(Opts, Acc);
mqtt_opts([{ssl, []} | Opts], Acc) ->
    mqtt_opts(Opts, Acc);
mqtt_opts([{ssl, SslOpts} | Opts], Acc) ->
    mqtt_opts(Opts, [{ssl, SslOpts}|Acc]);
mqtt_opts([_|Opts], Acc) ->
    mqtt_opts(Opts, Acc).

tcp_opts(Opts) ->
    tcp_opts(Opts, []).
tcp_opts([], Acc) ->
    Acc;
tcp_opts([{ifaddr, IfAddr} | Opts], Acc) ->
    {ok, IpAddr} = inet_parse:address(IfAddr),
    tcp_opts(Opts, [{ip, IpAddr}|Acc]);
tcp_opts([_|Opts], Acc) ->
    tcp_opts(Opts, Acc).

ssl_opts(Opts) ->
    ssl_opts(Opts, []).
ssl_opts([], Acc) ->
    {ssl, Acc};
ssl_opts([{keyfile, KeyFile} | Opts], Acc) ->
    ssl_opts(Opts, [{keyfile, KeyFile}|Acc]);
ssl_opts([{certfile, CertFile} | Opts], Acc) ->
    ssl_opts(Opts, [{certfile, CertFile}|Acc]);
ssl_opts([_|Opts], Acc) ->
    ssl_opts(Opts, Acc).


client_id(PubSub, N, Opts) ->
    _ = PubSub,
    %clientid = proplists:get_value(clientId, Opts),
    if
	true ->
        sim_id(N, Opts)
	% true->
	%     Prefix =
	%     case proplists:get_value(ifaddr, Opts) of
	% 	undefined ->
	% 	    {ok, Host} = inet:gethostname(), Host;
	% 	IfAddr    ->
	% 	    IfAddr
	%     end,
	%     list_to_binary(lists:concat([Prefix, "_bench_", atom_to_list(PubSub),
	% 	                            "_", N, "_", random:uniform(16#FFFFFFFF)]))
        
    end.

topics_opt(Opts) ->
    Topics = topics_opt(Opts, []),
    io:format("Topics: ~p~n", [Topics]),
    [feed_var(bin(Topic), Opts) || Topic <- Topics].

topics_opt([], Acc) ->
    Acc;
topics_opt([{topic, Topic}|Topics], Acc) ->
    topics_opt(Topics, [Topic | Acc]);
topics_opt([_Opt|Topics], Acc) ->
    topics_opt(Topics, Acc).

topic_opt(Opts) ->
    feed_var(bin(proplists:get_value(topic, Opts)), Opts).

feed_var(Topic, Opts) when is_binary(Topic) ->
    Props = [{Var, bin(proplists:get_value(Key, Opts))} || {Key, Var} <-
                [{seq, <<"%i">>}, {client_id, <<"%c">>}, {username, <<"%u">>}]],
    lists:foldl(fun({_Var, undefined}, Acc) -> Acc;
                   ({Var, Val}, Acc) -> feed_var(Var, Val, Acc)
        end, Topic, Props).

feed_var(Var, Val, Topic) ->
    feed_var(Var, Val, words(Topic), []).
feed_var(_Var, _Val, [], Acc) ->
    join(lists:reverse(Acc));
feed_var(Var, Val, [Var|Words], Acc) ->
    feed_var(Var, Val, Words, [Val|Acc]);
feed_var(Var, Val, [W|Words], Acc) ->
    feed_var(Var, Val, Words, [W|Acc]).

words(Topic) when is_binary(Topic) ->
    [word(W) || W <- binary:split(Topic, <<"/">>, [global])].

word(<<>>)    -> '';
word(<<"+">>) -> '+';
word(<<"#">>) -> '#';
word(Bin)     -> Bin.

join([]) ->
    <<>>;
join([W]) ->
    bin(W);
join(Words) ->
    {_, Bin} =
    lists:foldr(fun(W, {true, Tail}) ->
                        {false, <<W/binary, Tail/binary>>};
                   (W, {false, Tail}) ->
                        {false, <<W/binary, "/", Tail/binary>>}
                end, {true, <<>>}, [bin(W) || W <- Words]),
    Bin.

bin(A) when is_atom(A)   -> bin(atom_to_list(A));
bin(I) when is_integer(I)-> bin(integer_to_list(I));
bin(S) when is_list(S)   -> list_to_binary(S);
bin(B) when is_binary(B) -> B;
bin(undefined)           -> undefined.

