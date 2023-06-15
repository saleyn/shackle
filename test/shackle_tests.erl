-module(shackle_tests).
-include_lib("eunit/include/eunit.hrl").
-include("test.hrl").
-include("shackle_defaults.hrl").

-define(N, 1000).

%% runners
shackle_app_stop_start_test_() ->
    {setup,
        fun () ->
            setup(),
            ?CLIENT_TCP:start()
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun app_stop_start_subtest/0]}.

shackle_backlog_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, 1},
                {pool_size, 1}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun backlog_full_subtest/0]}.

shackle_backlog_infinity_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, infinity},
                {pool_size, 1}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun () -> add_subtest(?CLIENT_TCP) end]}.

shackle_call_crash_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun call_crash_subtest/0]}.

shackle_random_ssl_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_SSL, [
                {pool_size, 1},
                {pool_strategy, random}
        ]) end,
        fun (_) -> cleanup(?CLIENT_SSL) end,
    {inparallel, [
        fun () -> add_subtest(?CLIENT_SSL) end,
        fun () -> multiply_subtest(?CLIENT_SSL) end,
        fun () -> noop_subtest(?CLIENT_SSL) end
    ]}}.

shackle_random_tcp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    {inparallel, [
        fun () -> add_subtest(?CLIENT_TCP) end,
        fun () -> multiply_subtest(?CLIENT_TCP) end,
        fun () -> noop_subtest(?CLIENT_TCP) end
    ]}}.

shackle_random_udp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_UDP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_UDP) end,
    {inparallel, [
        fun () -> add_subtest(?CLIENT_UDP) end,
        fun () -> multiply_subtest(?CLIENT_UDP) end,
        fun () -> noop_subtest(?CLIENT_UDP) end
    ]}}.

shackle_reconnect_ssl_test_() ->
    {setup,
        fun () ->
            setup(),
            ?CLIENT_SSL:start()
        end,
        fun (_) -> cleanup(?CLIENT_SSL) end,
    [fun () -> reconnect_subtest(?CLIENT_SSL) end]}.

shackle_reconnect_tcp_test_() ->
    {setup,
        fun () ->
            setup(),
            ?CLIENT_TCP:start()
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun () -> reconnect_subtest(?CLIENT_TCP) end]}.

shackle_reconnect_udp_test_() ->
    {setup,
        fun () ->
            setup(),
            ?CLIENT_UDP:start()
        end,
        fun (_) -> cleanup(?CLIENT_UDP) end,
    [fun () -> reconnect_subtest(?CLIENT_UDP) end]}.

shackle_round_robin_tcp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_strategy, round_robin}
            ]) end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    {inparallel, [
        fun () -> add_subtest(?CLIENT_TCP) end,
        fun () -> multiply_subtest(?CLIENT_TCP) end,
        fun () -> noop_subtest(?CLIENT_TCP) end
    ]}}.

shackle_round_robin_udp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_UDP, [
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_UDP) end,
    {inparallel, [
        fun () -> add_subtest(?CLIENT_UDP) end,
        fun () -> multiply_subtest(?CLIENT_UDP) end,
        fun () -> noop_subtest(?CLIENT_UDP) end
    ]}}.

shackle_timeout_ssl_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_SSL, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_SSL) end,
    [fun () -> timeout_subtest(?CLIENT_SSL) end]}.

shackle_timeout_tcp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
    [fun () -> timeout_subtest(?CLIENT_TCP) end]}.

shackle_timeout_udp_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_UDP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_UDP) end,
    [fun () -> timeout_subtest(?CLIENT_UDP) end]}.

shackle_batch_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        [
            fun () -> batch_empty(?CLIENT_TCP) end,
            fun () -> batch_element(?CLIENT_TCP) end,
            fun () -> batch_element_element(?CLIENT_TCP) end,
            fun () -> batch_noop(?CLIENT_TCP) end,
            fun () -> batch_noop_element(?CLIENT_TCP) end,
            fun () -> batch_element_noop(?CLIENT_TCP) end,
            fun () -> batch_element_noop_element(?CLIENT_TCP) end,
            fun () -> batch_element_noop_element_noop_element(?CLIENT_TCP) end,
            fun () -> batch_timeout(?CLIENT_TCP) end,
            fun () -> batch_element_timeout(?CLIENT_TCP) end,
            fun () -> batch_element_timeout_element_timeout(?CLIENT_TCP) end,
            fun () -> batch_element_timeout_element(?CLIENT_TCP) end,
            fun () -> batch_element_timeout_noop_element(?CLIENT_TCP) end
        ]}.

shackle_round_robin_batch_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 32},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_random(?CLIENT_TCP) end,
            fun () -> batch_random(?CLIENT_TCP) end,
            fun () -> batch_random(?CLIENT_TCP) end
        ]}}.

shackle_random_batch_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_random(?CLIENT_TCP) end,
            fun () -> batch_random(?CLIENT_TCP) end,
            fun () -> batch_random(?CLIENT_TCP) end
        ]}}.

shackle_batch_cast_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        [
            fun () -> cast_cast_in_order(?CLIENT_TCP) end,
            fun () -> cast_cast_reverse_order(?CLIENT_TCP) end,
            fun () -> cast_batch_cast_in_order(?CLIENT_TCP) end,
            fun () -> cast_batch_cast_reverse_order(?CLIENT_TCP) end,
            fun () -> batch_cast_batch_cast_in_order(?CLIENT_TCP) end,
            fun () -> batch_cast_batch_cast_reverse_order(?CLIENT_TCP) end
        ]}.

shackle_round_robin_batch_cast_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 64},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_cast_random() end,
            fun () -> batch_cast_random() end,
            fun () -> batch_cast_random() end
        ]}}.

shackle_random_batch_cast_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 64},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_cast_random() end,
            fun () -> batch_cast_random() end,
            fun () -> batch_cast_random() end
        ]}}.

shackle_round_robin_batch_cast_partial_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 64},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_cast_random_partial() end,
            fun () -> batch_cast_random_partial() end,
            fun () -> batch_cast_random_partial() end
        ]}}.

shackle_random_batch_cast_partial_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 64},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            fun () -> batch_cast_random_partial() end,
            fun () -> batch_cast_random_partial() end,
            fun () -> batch_cast_random_partial() end
        ]}}.

%% tests
add_subtest(Client) ->
    [assert_random_add(Client) || _ <- lists:seq(1, ?N)].

app_stop_start_subtest() ->
    ?assertEqual({error, no_server}, arithmetic_tcp_client:add(1, 1)),
    ok = arithmetic_tcp_server:start(),
    timer:sleep(1000),
    ?assertEqual(2, arithmetic_tcp_client:add(1, 1)),
    ok = arithmetic_tcp_client:stop(),

    shackle_app:stop(),
    shackle_app:start(),

    arithmetic_tcp_client:start(),
    timer:sleep(1000),
    ?assertEqual(2, arithmetic_tcp_client:add(1, 1)).

backlog_full_subtest() ->
    Pid = self(),
    [spawn(fun () ->
        X = arithmetic_tcp_client:add(1, 1),
        Pid ! {response, X}
    end) || _ <- lists:seq(1, 20)],

    ?assert(lists:any(fun
        ({error, no_server}) -> true;
        (_) -> false
    end, receive_loop(20))).

call_crash_subtest() ->
    ?assertEqual({error, client_crash}, arithmetic_tcp_client:add(a, b)),
    ?assertEqual(2, arithmetic_tcp_client:add(1, 1)).

multiply_subtest(Client) ->
    [assert_random_multiply(Client) || _ <- lists:seq(1, ?N)].

noop_subtest(Client) ->
    [Client:noop() || _ <- lists:seq(1, 10)].

reconnect_subtest(Client) ->
    Server = server(Client),
    ?assertEqual({error, no_server}, Client:add(1, 1)),
    ok = Server:start(),
    timer:sleep(100),
    ?assertEqual(2, Client:add(1, 1)),
    ok = Server:stop(),
    timer:sleep(100),
    {error, _} = Client:add(1, 1),
    ok = Server:start(),
    timer:sleep(100),
    ?assertEqual(2, Client:add(1, 1)).

timeout_subtest(Client) ->
    ?assertEqual({error, timeout_handled}, Client:add(255, 255)).

batch_empty(Client) ->
    RetList = Client:batch([]),
    ?assertEqual(0, length(RetList)).

batch_element(Client) ->
    RetList = Client:batch([{add, 1, 2}]),
    ?assertEqual(1, length(RetList)),
    [V] = RetList,
    ?assertEqual(3, V).

batch_element_element(Client) ->
    RetList = Client:batch([{add, 1, 2}, {multiply, 3, 4}]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual(3, V1),
    ?assertEqual(12, V2).

batch_noop(Client) ->
    RetList = Client:batch([noop]),
    ?assertEqual(1, length(RetList)),
    [ok] = RetList.

batch_noop_element(Client) ->
    RetList = Client:batch([noop, {add, 1, 2}]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual(ok, V1),
    ?assertEqual(3, V2).

batch_element_noop(Client) ->
    RetList = Client:batch([{add, 1, 2}, noop]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual(ok, V1),
    ?assertEqual(3, V2).

batch_element_noop_element(Client) ->
    RetList = Client:batch([{add, 1, 2}, noop, {multiply, 3, 4}]),
    ?assertEqual(3, length(RetList)),
    [V1, V2, V3] = RetList,
    ?assertEqual(ok, V1),
    ?assertEqual(3, V2),
    ?assertEqual(12, V3).

batch_element_noop_element_noop_element(Client) ->
    RetList = Client:batch([
        {add, 1, 2}, noop, {multiply, 3, 4}, noop, {multiply, 5, 6}]),
    ?assertEqual(5, length(RetList)),
    [V1, V2, V3, V4, V5] = RetList,
    ?assertEqual(ok, V1),
    ?assertEqual(ok, V2),
    ?assertEqual(3, V3),
    ?assertEqual(12, V4),
    ?assertEqual(30, V5).

batch_timeout(Client) ->
    RetList = Client:batch([{add, 255, 255}]),
    ?assertEqual(1, length(RetList)),
    [{Ret, Reason}] = RetList,
    ?assertEqual(error, Ret),
    ?assertEqual(timeout_handled, Reason).

batch_element_timeout(Client) ->
    RetList = Client:batch([{add, 1, 2}, {add, 255, 255}], ?DEFAULT_TIMEOUT),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual(3, V1),
    ?assertEqual({error, timeout_handled}, V2).

batch_element_timeout_element_timeout(Client) ->
    RetList = Client:batch([{add, 1, 2}, {add, 255, 255}], ?DEFAULT_TIMEOUT),
    RetList2 = Client:batch([{add, 3, 4}, {add, 255, 255}], ?DEFAULT_TIMEOUT),
    [V1, V2] = RetList,
    ?assertEqual(3, V1),
    ?assertEqual({error, timeout_handled}, V2),
    [V3, V4] = RetList2,
    ?assertEqual(7, V3),
    ?assertEqual({error, timeout_handled}, V4).

batch_element_timeout_element(Client) ->
    RetList =
        Client:batch([{add, 1, 2}, {add, 255, 255}, {multiply, 3, 4}],
            ?DEFAULT_TIMEOUT),
    ?assertEqual(3, length(RetList)),
    [V1, V2, V3] = RetList,
    ?assertEqual(3, V1),
    ?assertEqual({error, timeout_handled}, V2),
    ?assertEqual({error, timeout_handled}, V3).

batch_element_timeout_noop_element(Client) ->
    RetList =
        Client:batch([{add, 1, 2}, {add, 255, 255}, noop, {multiply, 3, 4}],
            ?DEFAULT_TIMEOUT),
    ?assertEqual(4, length(RetList)),
    [V1, V2, V3, V4] = RetList,
    ?assertEqual(ok, V1),
    ?assertEqual(3, V2),
    ?assertEqual({error, timeout_handled}, V3),
    ?assertEqual({error, timeout_handled}, V4).

batch_random(Client) ->
    [assert_random_batch(Client) || _ <- lists:seq(1, ?N)].

assert_random_batch(Client) ->
    {Ops, Expect} = batch_mk_random(20, 10),
    RetList = Client:batch(Ops),
    ?assertEqual(length(Expect), length(RetList)),
    L = lists:zip(Expect, RetList),
    assert_list(L).

cast_cast_in_order(_Client) ->
    {ok, RequestId1} = shackle:cast(?POOL_NAME, {add, 1, 2}),
    {ok, RequestId2} = shackle:cast(?POOL_NAME, {multiply, 3, 4}),
    V1 = shackle:receive_response(RequestId1),
    V2 = shackle:receive_response(RequestId2),
    ?assertEqual(3, V1),
    ?assertEqual(12, V2).

cast_cast_reverse_order(_Client) ->
    {ok, RequestId1} = shackle:cast(?POOL_NAME, {add, 1, 2}),
    {ok, RequestId2} = shackle:cast(?POOL_NAME, {multiply, 3, 4}),
    V2 = shackle:receive_response(RequestId2),
    V1 = shackle:receive_response(RequestId1),
    ?assertEqual(3, V1),
    ?assertEqual(12, V2).

cast_batch_cast_in_order(_Client) ->
    {ok, RequestId} = shackle:cast(?POOL_NAME, {add, 1, 2}),
    {ok, BatchState} = shackle:batch_cast(?POOL_NAME, [{multiply, 3, 4}]),
    V1 = shackle:receive_response(RequestId),
    V2 = shackle:receive_batch_response(BatchState),
    ?assertEqual(3, V1),
    ?assertEqual([12], V2).

cast_batch_cast_reverse_order(_Client) ->
    {ok, RequestId} = shackle:cast(?POOL_NAME, {add, 1, 2}),
    {ok, BatchState} = shackle:batch_cast(?POOL_NAME, [{multiply, 3, 4}]),
    V2 = shackle:receive_batch_response(BatchState),
    V1 = shackle:receive_response(RequestId),
    ?assertEqual(3, V1),
    ?assertEqual([12], V2).

batch_cast_batch_cast_in_order(_Client) ->
    {ok, BatchState1} = shackle:batch_cast(?POOL_NAME, [{add, 1, 2}]),
    {ok, BatchState2} = shackle:batch_cast(?POOL_NAME, [{multiply, 3, 4}]),
    V1 = shackle:receive_batch_response(BatchState1),
    V2 = shackle:receive_batch_response(BatchState2),
    ?assertEqual([3], V1),
    ?assertEqual([12], V2).

batch_cast_batch_cast_reverse_order(_Client) ->
    {ok, BatchState1} = shackle:batch_cast(?POOL_NAME, [{add, 1, 2}]),
    {ok, BatchState2} = shackle:batch_cast(?POOL_NAME, [{multiply, 3, 4}]),
    V2 = shackle:receive_batch_response(BatchState2),
    V1 = shackle:receive_batch_response(BatchState1),
    ?assertEqual([3], V1),
    ?assertEqual([12], V2).

batch_cast_random() ->
    Batches = [mk_random_batch_cast() || _ <- lists:seq(1, ?N)],
    Shuffled = shuffle(Batches),
    {BatchStates, Expects} = lists:unzip(Shuffled),
    Responses = [shackle:receive_batch_response(BatchState)
        || BatchState <- BatchStates],
    ExpectResponse = lists:zip(Expects, Responses),
    assert_list(ExpectResponse).

batch_cast_random_partial() ->
    Batches = [mk_random_batch_cast() || _ <- lists:seq(1, ?N)],
    Splitted = [ mk_random_batch_split(B) || B <- Batches],
    {Part1, Part2} = lists:unzip(Splitted),
    Shuffled1 = shuffle(Part1),
    Shuffled2 = shuffle(Part2),
    Shuffled = lists:append([Shuffled1, Shuffled2]),
    {BatchStates, Expects} = lists:unzip(Shuffled),
    Responses = [shackle:receive_batch_response(BatchState)
        || BatchState <- BatchStates],
    ExpectResponse = lists:zip(Expects, Responses),
    assert_list(ExpectResponse).

mk_random_batch_cast() ->
    {Ops, Expect} = batch_mk_random(10, 20),
    {ok, {_, Count} = BatchState} = shackle:batch_cast(?POOL_NAME, Ops),
    ?assertEqual(length(Expect), Count),
    {BatchState, Expect}.

mk_random_batch_split({{BatchRef, _Count}, Expect}) ->
    {{L1, Expect1}, {L2, Expect2}} = split_random(Expect),
    {{{BatchRef, L1}, Expect1}, {{BatchRef, L2}, Expect2}}.

%% utils
assert_random_add(Client) ->
    A = rand(),
    B = rand(),
    ?assertEqual(A + B, Client:add(A, B)).

assert_random_multiply(Client) ->
    A = rand(),
    B = rand(),
    ?assertEqual(A * B, Client:multiply(A, B)).

cleanup() ->
    shackle_app:stop().

cleanup(Client) ->
    Client:stop(),
    Server = server(Client),
    Server:stop(),
    cleanup().

rand() ->
    shackle_utils:random(254).

assert_list(L) ->
    lists:map(fun ({E, V}) -> ?assertEqual(E, V) end, L).

batch_mk_random(Len) ->
    Ops = [mk_random_op() || _ <- lists:seq(1, Len)],
    Expect = batch_expect(Ops),
    {Ops, Expect}.

batch_mk_random(MinLen, 0) ->
    batch_mk_random(MinLen);
batch_mk_random(MinLen, LenVariation) ->
    L = MinLen + shackle_utils:random(LenVariation),
    Ops = [mk_random_op() || _ <- lists:seq(1, L)],
    Expect = batch_expect(Ops),
    {Ops, Expect}.

batch_expect(Ops) ->
    {WithoutReply, WithReply} = select_expecting_reply(Ops),
    L = lists:append(WithoutReply, WithReply),
    lists:map(fun op_result/1, L).

mk_random_op() ->
    case shackle_utils:random(3) of
        1 ->
            A = rand(),
            B = rand(),
            {add, A, B};
        2 ->
            A = rand(),
            B = rand(),
            {multiply, A, B};
        3 ->
            noop
    end.

op_result(noop) -> ok;
op_result({add, A, B}) -> A + B;
op_result({multiply, A, B}) -> A * B.

select_expecting_reply(Ops) ->
    {WithoutReply, WithReply} = lists:partition(
        fun (Op) -> case Op of
                        noop -> true;
                        _ -> false
                    end end,
        Ops),
    {WithoutReply, WithReply}.

split_random([]) ->
    {{0, []}, {0, []} };
split_random(Xs) ->
    L = length(Xs),
    N = round(rand:uniform() * (L-1)) + 1,
    {Ys, Zs} = lists:split(N, Xs),
    {{N, Ys}, {L-N, Zs}}.

shuffle([]) -> [];
shuffle(Xs) ->
    randomize(round(math:log(length(Xs))+0.5), Xs).

randomize(1, Xs) ->
    randomize(Xs);
randomize(Count, Xs) ->
    lists:foldl(
        fun (_, Acc) -> randomize(Acc) end,
        randomize(Xs), lists:seq(1, Count-1)).

randomize(Xs) ->
    RXs = lists:map(fun (X) -> {rand:uniform(), X} end, Xs),
    {_, Ys} = lists:unzip(lists:keysort(1, RXs)),
    Ys.

receive_loop(0) ->
    [];
receive_loop(N) ->
    receive
        {response, X} ->
            [X | receive_loop(N - 1)]
    end.

server(?CLIENT_SSL) ->
    arithmetic_ssl_server;
server(?CLIENT_TCP) ->
    arithmetic_tcp_server;
server(?CLIENT_UDP) ->
    arithmetic_udp_server.

setup() ->
    error_logger:tty(false),
    shackle_app:start().

setup(Client, Options) ->
    setup(),
    Server = server(Client),
    Server:start(),
    timer:sleep(100),
    Client:start(Options),
    timer:sleep(500).