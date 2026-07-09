-module(shackle_conn_timeout).
-include_lib("eunit/include/eunit.hrl").
-include("test.hrl").
-import(shackle_tests, [server/1, cleanup/1, cleanup/2]).

-define(CLIENT, arithmetic_tcp_client).

-define(BOUNCE_INTERVAL_SEC, 4).
-define(BOUNCE_INTERVAL_SHORT, 1).

conn_timeout_test_() ->
    {setup,
        fun () ->
            setup([
                {backlog_size, 1},
                {pool_size, 1}
            ], [
                {reconnect_time_min, 100},
                {bounce_interval_secs, ?BOUNCE_INTERVAL_SEC},
                {on_bounce_event, fun(N, I, E) ->
                    case whereis(?MODULE) of
                        Pid when is_pid(Pid) ->
                            Pid ! {event, {N, I, E}};
                        _ ->
                            ok
                    end
                end}
            ])
        end,
        fun (Cleanup) ->
            cleanup(?CLIENT, Cleanup),
            persistent_term:erase({?MODULE, requests})
        end,
        {timeout, 10000, [
            ?_assert(register(?MODULE, self())),
            % Check that bounce_interval is set to 1s
            ?_assertMatch({ok, #{connection_state := #{bounce_interval := ?BOUNCE_INTERVAL_SEC*1000}}},
                shackle_server:state(?POOL_NAME_TCP, 1)),
            % The following should execute quickly
            ?_assertEqual(2, ?CLIENT:add(1, 1)),
            % Normal 50ms delay on the server side
            ?_assertEqual(50, ?CLIENT:delayed_echo(50)),
            % Schedule an async request
            ?_assertEqual(ok,
                begin
                    {ok, R} = ?CLIENT:delayed_echo_cast(200, 1000),
                    persistent_term:put({?MODULE, requests}, [R])
                end),
            % Pool size is 1, and backlog_size is 1: there's no room for more requests
            ?_assertEqual({error, no_server}, ?CLIENT:delayed_echo_cast(200, 1000)),
            % Wait while the server is blocked and there's no room in the backlog
            ?_assertEqual(200, receive_response(next_request(), 1500)),
            ?_assertMatch(#{status := bounce_initiated, bounce_state := draining},
                wait_for(bounce_initiated)),
            ?_assertMatch(#{status := finalizing_bounce, bounce_state := reconnecting},
                wait_for(finalizing_bounce)),
            ?_assertMatch(#{status := connected, bounce_state := waiting},
                wait_for(connected))
        ]}
    }.

conn_timeout2_test_() ->
    {setup,
        fun () ->
            persistent_term:put({?MODULE, events}, #{}),
            setup([
                {backlog_size, 10},
                {pool_size, 1}
            ], [
                {reconnect_time_min, 0},
                {reconnect_time_max, 0},
                {bounce_interval_secs, ?BOUNCE_INTERVAL_SEC},
                {on_bounce_event, fun(N, I, E) ->
                    append_event(I, E),
                    try whereis(?MODULE) ! {event, {N, I, E}} catch _:_ -> ok end
                end}
            ])
        end,
        fun (Cleanup) ->
            cleanup(?CLIENT, Cleanup),
            persistent_term:erase({?MODULE, requests}),
            persistent_term:erase({?MODULE, events})
        end,
        {timeout, 15000, [
            ?_assert(register(?MODULE, self())),
            % Check that bounce_interval is set to 1s
            ?_assertMatch({ok, #{connection_state := #{bounce_interval := ?BOUNCE_INTERVAL_SEC*1000}}},
                shackle_server:state(?POOL_NAME_TCP, 1)),
            % The following should execute quickly
            ?_assertEqual(2, ?CLIENT:add(1, 1)),
            % Schedule async requests
            ?_assertEqual(ok,
                begin
                    Res = lists:map(fun(_) ->
                        {ok, R} = ?CLIENT:delayed_echo_cast(5, 3000),
                        R
                    end, lists:seq(1, 10)),
                    persistent_term:put({?MODULE, requests}, Res)
                end),
            ?_assert(shackle_sema:count(?POOL_NAME_TCP, 1) > 0),
            %?_assert(shackle_server:bounce(?POOL_NAME_TCP, 1)),

            % Wait while the server is blocked and there's no room in the backlog
            ?_assertMatch(#{status := bounce_initiated, bounce_state := draining},
                wait_for(bounce_initiated)),

            % Drain the queue
            ?_assertMatch([5,5,5,5,5,5,5,5,5,5],
                [receive_response(R, 2000) || R <- persistent_term:get({?MODULE, requests})]
            ),
            % Check that the bounce is property finalized
            ?_assertMatch(#{status := finalizing_bounce, bounce_state := reconnecting},
                wait_for(finalizing_bounce)),
            % Check if reconnected
            ?_assertMatch(#{status := connected, bounce_state := waiting},
                wait_for(connected)),
            ?_assert(check_bounce_events(1, 5000))
        ]}
  }.

two_conns_timeout_test_() ->
    {setup,
        fun () ->
            Cleanup = setup([
                {backlog_size, 1},
                {pool_size, 2}
            ], [
                {reconnect_time_min, 0},
                {reconnect_time_max, 0},
                {bounce_interval_secs, 1},
                {on_bounce_event, fun(_N, I, E) ->
                    try whereis(?MODULE) ! {event, {I, E}} catch _:_ -> ok end
                end}
            ]),
            persistent_term:put({?MODULE, events}, #{}),
            Self = self(),
            Pid = spawn_link(fun() ->
                register(?MODULE, self()),
                Self ! ready,
                append_events_loop()
            end),
            receive ready -> ok end,
            {Pid, Cleanup}
          end,
        fun ({Pid, Cleanup}) ->
            cleanup(?CLIENT, Cleanup),
            erlang:unlink(Pid),
            erlang:exit(Pid, kill),
            persistent_term:erase({?MODULE, events})
        end,
        {timeout, 15000, [
            % Check that bounce_interval is set to 1s
            ?_assertMatch({ok, #{connection_state := #{bounce_interval := 1000}}},
                shackle_server:state(?POOL_NAME_TCP, 1)),
            % Request delay on the server side
            ?_assertEqual(500, ?CLIENT:delayed_echo(500, 2000)),
            % For the 1st connection, make sure it's bounced
            ?_assert(check_bounce_events(1, 5000)),
            % For the 2st connection, make sure it's bounced
            ?_assert(check_bounce_events(2, 5000))
        ]}
    }.

delayed_echo_test_() ->
    {setup,
        fun () ->
            setup([
                {backlog_size, 1},
                {pool_size, 1}
            ])
        end,
        fun (Cleanup) -> cleanup(?CLIENT, Cleanup) end,
        {timeout, 10000, [
            ?_assertEqual([], application:get_all_env(shackle)),
            ?_assertEqual(2, ?CLIENT:add(1, 1)),
            % Normal 50ms delay on the server side
            ?_assertEqual(50, ?CLIENT:delayed_echo(50)),
            % Server-side timeout (?CLIENT:handle_timeout/2 called)
            ?_assertEqual({error, timeout_handled}, ?CLIENT:delayed_echo(100, 50)),
            % Client-side timeout in `receive' waiting for server response
            ?_assertEqual({error, timeout}, ?CLIENT:delayed_echo(1000, 200, 100)),
            ?_assertMatch({ok, #{connection_state := #{bounce_interval := infinity}}},
                shackle_server:state(?POOL_NAME_TCP, 1))
        ]}
    }.

%%%-----------------------------------------------------------------------------
%%% Internal functions
%%%-----------------------------------------------------------------------------

next_request() ->
    [H|T] = persistent_term:get({?MODULE, requests}),
    persistent_term:put({?MODULE, requests}, T),
    H.

wait_for(Status) ->
    wait_for(Status, 1, ?BOUNCE_INTERVAL_SEC*1000+100).

wait_for(Status, Instances, Timeout) ->
    receive
        {event, {?POOL_NAME_TCP, I, Msg = #{status := S}}}
            when S == Status andalso
                 ((is_integer(Instances) andalso I == Instances) orelse
                  (is_list(Instances) andalso
                    (I == hd(Instances) orelse [I] == tl(Instances)))) ->
            Msg
    after Timeout ->
        drain_all(),
        {error, timeout}
    end.

drain_all() ->
    receive
        M ->
            io:format(user, "===> Message: ~p\n", [M]),
            drain_all()
    after 0 ->
        ok
    end.

wait_for_events(Instance, Timeout) ->
    Now = os:system_time(millisecond),
    wait_for_events(Instance, Now, Now+Timeout).

wait_for_events(Instance, Now, Expiration) when Now < Expiration ->
    Map = persistent_term:get({?MODULE, events}),
    case maps:get(Instance, Map, []) of
        [#{status := connected} = H | T] ->
            TT = lists:takewhile(fun(#{status := S}) -> S /= connected end, T),
            LL = lists:dropwhile(fun(#{status := S}) -> S /= connected end, T),
            persistent_term:put({?MODULE, events}, maps:put(Instance, LL, Map)),
            case T of
                [] ->
                    timer:sleep(min(10, max(0, Expiration - Now))),
                    wait_for_events(Instance, os:system_time(millisecond), Expiration);
                _ ->
                    lists:reverse([H | TT])
            end;
        _ ->
            timer:sleep(min(10, max(0, Expiration - Now))),
            wait_for_events(Instance, os:system_time(millisecond), Expiration)
    end;
wait_for_events(_Instance, _Now, _Expiration) ->
    {error, timeout}.

append_event(Idx, #{status := Status} = Event) ->
    Map = persistent_term:get({?MODULE, events}),
    case maps:get(Idx, Map, []) of
        [#{status := LastStatus}|_] when LastStatus == Status ->
            ok;
        Events ->
            persistent_term:put({?MODULE, events}, maps:put(Idx, [Event | Events], Map))
    end.

append_events_loop() ->
    receive
        {event, {I, E}} ->
            append_event(I, E),
            append_events_loop()
    end.

check_bounce_events(SrvIdx, Timeout) ->
    case {SrvIdx, wait_for_events(SrvIdx, Timeout)} of
        {_, [
            #{reason := another_connection_bouncing, status := bounce_not_initiated},
            #{status := bounce_initiated,      bounce_state := draining},
            #{status := finalizing_bounce,     bounce_state := reconnecting},
            #{status := socket_close,          bounce_state := reconnecting},
            #{status := reconnect_timer,       bounce_state := reconnecting},
            #{status := connected,             bounce_state := waiting} | _
        ]} ->
            true;
        {_, [
            #{status := bounce_initiated,      bounce_state := draining},
            #{status := awaiting_empty_queue,  bounce_state := draining},
            #{status := finalizing_bounce,     bounce_state := reconnecting},
            #{status := socket_close,          bounce_state := reconnecting},
            #{status := reconnect_timer,       bounce_state := reconnecting},
            #{status := connected,             bounce_state := waiting} | _
        ]} ->
            true;
        {_, [
            #{status := schedule_bounce_check, bounce_state := waiting},
            #{status := bounce_initiated,      bounce_state := draining},
            #{status := awaiting_empty_queue,  bounce_state := draining},
            #{status := finalizing_bounce,     bounce_state := reconnecting},
            #{status := socket_close,          bounce_state := reconnecting},
            #{status := reconnect_timer,       bounce_state := reconnecting},
            #{status := connected,             bounce_state := waiting} | _
        ]} ->
            true;
        {_, [
            #{status := schedule_bounce_check, bounce_state := waiting},
            #{status := bounce_initiated,      bounce_state := draining},
            #{status := finalizing_bounce,     bounce_state := reconnecting},
            #{status := socket_close,          bounce_state := reconnecting},
            #{status := reconnect_timer,       bounce_state := reconnecting},
            #{status := connected,             bounce_state := waiting} | _
        ]} ->
            true;
        {_, [
            #{status := bounce_initiated,      bounce_state := draining},
            #{status := finalizing_bounce,     bounce_state := reconnecting},
            #{status := socket_close,          bounce_state := reconnecting},
            #{status := reconnect_timer,       bounce_state := reconnecting},
            #{status := connected,             bounce_state := waiting} | _
        ]} ->
            true;
        {_, {error, timeout}} ->
            false
    end.

receive_response(ReqID, Timeout) ->
  try
      shackle:receive_response(ReqID, Timeout)
  catch error:timeout ->
      {error, timeout}
  end.

setup(PoolOptions) ->
    setup(PoolOptions, []).

setup(PoolOptions, SrvOptions) ->
    shackle_tests:setup(?MODULE, ?CLIENT, PoolOptions, SrvOptions).