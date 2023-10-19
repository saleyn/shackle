-module(shackle_batch_tests).
-import(shackle_tests, [setup/2]).

-ifdef(BATCH_TESTS).
-include_lib("eunit/include/eunit.hrl").
-include("test.hrl").
-include("shackle_defaults.hrl").

-define(N, 30).
-define(LONG_TEST_BACKLOG_SIZE, 10_000).
-define(LONG_TEST_TIMEOUT, 10).
-define(LONG_TEST_POOL_SIZE, 32).

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
            ?_test(batch_cast_modulo_novalue_value(?CLIENT_TCP)),
            ?_test(batch_empty(?CLIENT_TCP)),
            ?_test(batch_element(?CLIENT_TCP)),
            ?_test(batch_element_element(?CLIENT_TCP)),
            ?_test(batch_noop(?CLIENT_TCP)),
            ?_test(batch_noop_element(?CLIENT_TCP)),
            ?_test(batch_element_noop(?CLIENT_TCP)),
            ?_test(batch_element_noop_element(?CLIENT_TCP)),
            ?_test(batch_element_noop_element_noop_element(?CLIENT_TCP)),
            ?_test(batch_modulovalue(?CLIENT_TCP)),
            ?_test(batch_modulonovalue(?CLIENT_TCP)),
            ?_test(batch_element_modulovalue(?CLIENT_TCP)),
            ?_test(batch_element_modulonovalue(?CLIENT_TCP)),
            ?_test(batch_modulonovalue_element(?CLIENT_TCP)),
            ?_test(batch_element_modulonovalue_element(?CLIENT_TCP))
        ]}.

shackle_batch_timeout_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 4},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        [
            ?_test(batch_element_timeout(?CLIENT_TCP)),
            ?_test(batch_element_timeout_element(?CLIENT_TCP)),
            ?_test(batch_element_timeout_element_timeout(?CLIENT_TCP)),
            ?_test(batch_element_timeout_noop_element(?CLIENT_TCP)),
            ?_test(batch_timeout(?CLIENT_TCP))
        ]}.

shackle_round_robin_batch_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            ?_test(batch_tests(fun () -> batch_random(?CLIENT_TCP) end))
        ]}
    }.

shackle_random_batch_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, [
            ?_test(batch_tests(fun () -> batch_random(?CLIENT_TCP) end))
        ]}
    }.

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
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () -> batch_cast_random(?CLIENT_TCP, ?N, 10, 20) end)}
    }.

shackle_random_batch_cast_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () -> batch_cast_random(?CLIENT_TCP, ?N, 10, 20) end)}
    }.

shackle_round_robin_batch_cast_partial_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () -> batch_cast_random_partial(?CLIENT_TCP, ?N, 10, 20) end)}
    }.

shackle_random_batch_cast_partial_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () -> batch_cast_random_partial(?CLIENT_TCP, ?N, 10, 20) end)}
    }.

shackle_batch_expect_ordered_replies_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {pool_size, 1},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        [
            fun () -> batch_expect_ordered_replies_value(?CLIENT_TCP) end,
            fun () -> batch_expect_ordered_replies_novalue(?CLIENT_TCP) end,
            fun () -> batch_expect_ordered_replies_value_value(
                          ?CLIENT_TCP) end,
            fun () -> batch_expect_ordered_replies_novalue_value(
                ?CLIENT_TCP) end,
            fun () -> batch_expect_ordered_replies_novalue_novalue_value(
                ?CLIENT_TCP) end,
            fun () -> batch_expect_ordered_replies_novalue_value_value(
                ?CLIENT_TCP) end,
            fun () ->
                batch_expect_ordered_replies_novalue_value_novalue_value(
                    ?CLIENT_TCP) end,
            fun () ->
            batch_expect_ordered_replies_novalue_value_novalue_value_novalue(
                    ?CLIENT_TCP) end,
            fun () ->
                batch_expect_ordered_replies_novalue_value_novalue_novalue(
                    ?CLIENT_TCP) end
        ]}.

batch_expect_ordered_ops_test_() ->
    [
        fun batch_expect_ordered_ops/0
    ].

shackle_round_robin_batch_expect_ordered_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, round_robin}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () ->
          batch_cast_random_ordered(?CLIENT_TCP, 1, 10, 20)
        end)}
    }.

shackle_random_batch_expect_ordered_test_() ->
    {setup,
        fun () ->
            setup(?CLIENT_TCP, [
                {backlog_size, ?LONG_TEST_BACKLOG_SIZE},
                {pool_size, ?LONG_TEST_POOL_SIZE},
                {pool_strategy, random}
            ])
        end,
        fun (_) -> cleanup(?CLIENT_TCP) end,
        {inparallel, batch_tests(fun () ->
          batch_cast_random_ordered(?CLIENT_TCP, ?N, 10, 20)
        end)}
    }.

%% tests
batch_tests(Fun) ->
    [
        {timeout, ?LONG_TEST_TIMEOUT, Fun},
        {timeout, ?LONG_TEST_TIMEOUT, Fun},
        {timeout, ?LONG_TEST_TIMEOUT, Fun}
    ].

batch_empty(Client) ->
    RetList = Client:batch([]),
    ?assertEqual(0, length(RetList)).

batch_element(Client) ->
    RetList = Client:batch([{add, 1, 2}]),
    ?assertEqual(1, length(RetList)),
    [V] = RetList,
    ?assertEqual({ok, 3}, V).

batch_element_element(Client) ->
    RetList = Client:batch([{add, 1, 2}, {multiply, 3, 4}]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual({ok, 3}, V1),
    ?assertEqual({ok, 12}, V2).

batch_noop(Client) ->
    RetList = Client:batch([noop]),
    ?assertEqual(1, length(RetList)),
    [{ok, ok}] = RetList.

batch_noop_element(Client) ->
    RetList = Client:batch([noop, {add, 1, 2}]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual({ok, ok}, V1),
    ?assertEqual({ok, 3}, V2).

batch_element_noop(Client) ->
    RetList = Client:batch([{add, 1, 2}, noop]),
    ?assertEqual(2, length(RetList)),
    [V1, V2] = RetList,
    ?assertEqual({ok, 3}, V1),
    ?assertEqual({ok, ok}, V2).

batch_element_noop_element(Client) ->
    RetList = Client:batch([{add, 1, 2}, noop, {multiply, 3, 4}]),
    ?assertEqual(3, length(RetList)),
    [V1, V2, V3] = RetList,
    ?assertEqual({ok, 3}, V1),
    ?assertEqual({ok, ok}, V2),
    ?assertEqual({ok, 12}, V3).

batch_element_noop_element_noop_element(Client) ->
    RetList = Client:batch([
        {add, 1, 2}, noop, {multiply, 3, 4}, noop, {multiply, 5, 6}]),
    ?assertEqual(5, length(RetList)),
    [V1, V2, V3, V4, V5] = RetList,
    ?assertEqual({ok, 3}, V1),
    ?assertEqual({ok, ok}, V2),
    ?assertEqual({ok, 12}, V3),
    ?assertEqual({ok, ok}, V4),
    ?assertEqual({ok, 30}, V5).

batch_modulovalue(Client) ->
    RetList = Client:batch([{modulo, 5, 3}]),
    ?assertEqual([{ok, 5 rem 3}], RetList).

batch_modulonovalue(Client) ->
    RetList = Client:batch([{modulo, 5, 0}]),
    ?assertEqual([{error, timeout_handled}], RetList).

batch_element_modulovalue(Client) ->
    RetList = Client:batch([{add, 1, 2}, {modulo, 5, 3}]),
    ?assertEqual([{ok, 3}, {ok, 5 rem 3}], RetList).

batch_element_modulonovalue(Client) ->
    RetList = Client:batch([{add, 1, 2}, {modulo, 5, 0}]),
    ?assertEqual([{ok, 3}, {error, timeout_handled}], RetList).

batch_modulonovalue_element(Client) ->
    RetList = Client:batch([{modulo, 5, 0}, {add, 1, 2}]),
    ?assertEqual([{error, timeout_handled}, {ok, 3}], RetList).

batch_element_modulonovalue_element(Client) ->
    RetList = Client:batch([{add, 1, 2}, {modulo, 5, 0}, {multiply, 3, 4}]),
    ?assertEqual([{ok, 3}, {error, timeout_handled}, {ok, 12}], RetList).

batch_timeout(Client) ->
    RetList = Client:batch([{add, 255, 255}], 100, infinity),
    ?assertEqual([{error, timeout_handled}], RetList).

batch_element_timeout(Client) ->
    RetList = Client:batch([{add, 1, 2}, {add, 255, 255}], 100, infinity),
    ?assertEqual([{ok, 3}, {error, timeout_handled}], RetList).

batch_element_timeout_element(Client) ->
    RetList =
        Client:batch([{add, 1, 2}, {add, 255, 255}, {multiply, 3, 4}], 100, infinity),
    ?assertEqual([{ok, 3}, {error, timeout_handled}, {error, timeout_handled}],
        RetList).

batch_element_timeout_element_timeout(Client) ->
    PoolName = pool_name(Client),
    RetList1 = shackle:batch_call(PoolName,
        [{add, 1, 2}, {add, 255, 255}], 100, infinity),
    RetList2 = shackle:batch_call(PoolName,
        [{add, 3, 4}, {add, 255, 255}], 100, infinity),
    ?assertEqual([{ok, 3}, {error, timeout_handled}], RetList1),
    ?assertEqual([{ok, 7}, {error, timeout_handled}], RetList2).

batch_element_timeout_noop_element(Client) ->
    RetList =
        Client:batch([{add, 1, 2}, {add, 255, 255}, noop, {multiply, 3, 4}],
                     300, infinity),
    ?assertEqual([{ok, 3}, {error, timeout_handled}, {ok, ok}, {error, timeout_handled}],
        RetList).

batch_random(Client) ->
    lists:duplicate(?N, assert_random_batch(Client)).

assert_random_batch(Client) ->
    PoolName = pool_name(Client),
    {Ops, Expect} = batch_mk_random(20, 10),
    Values = shackle:batch_call(PoolName, Ops),
    ?assertNotMatch({error, _}, Expect),
    ?assertNotMatch({error, _}, Values),
    ?assertEqual(length(Expect), length(Values)),
    L = lists:zip(Expect, Values),
    assert_list(L).

cast_cast_in_order(Client) ->
    PoolName = pool_name(Client),
    {ok, RequestId1} = shackle:cast(PoolName, {add, 1, 2}),
    {ok, RequestId2} = shackle:cast(PoolName, {multiply, 3, 4}),
    V1 = shackle:receive_response(RequestId1),
    V2 = shackle:receive_response(RequestId2),
    ?assertEqual(3, V1),
    ?assertEqual(12, V2).

cast_cast_reverse_order(Client) ->
    PoolName = pool_name(Client),
    {ok, RequestId1} = shackle:cast(PoolName, {add, 1, 2}),
    {ok, RequestId2} = shackle:cast(PoolName, {multiply, 3, 4}),
    V2 = shackle:receive_response(RequestId2),
    V1 = shackle:receive_response(RequestId1),
    ?assertEqual(3, V1),
    ?assertEqual(12, V2).

cast_batch_cast_in_order(Client) ->
    PoolName = pool_name(Client),
    {ok, RequestId} = shackle:cast(PoolName, {add, 1, 2}),
    {ok,  {_BatchRef, 1, [{RequestRef, _Request}]} = BatchState} =
        shackle:batch_cast(PoolName, [{multiply, 3, 4}]),
    ?assertEqual(3, shackle:receive_response(RequestId)),
    ?assertEqual([{RequestRef, {ok, 12}}], shackle:receive_batch_response(BatchState)).

cast_batch_cast_reverse_order(Client) ->
    PoolName = pool_name(Client),
    {ok, RequestId} = shackle:cast(PoolName, {add, 1, 2}),
    {ok,  {_BatchRef, 1, [{RequestRef, _Request}]} = BatchState} =
        shackle:batch_cast(PoolName, [{multiply, 3, 4}]),
    ?assertEqual(3, shackle:receive_response(RequestId)),
    [{RequestRef, {ok, 12}}] = shackle:receive_batch_response(BatchState).

batch_cast_batch_cast_in_order(Client) ->
    test_batch_cast(Client, fifo).

batch_cast_batch_cast_reverse_order(Client) ->
    test_batch_cast(Client, lifo).

test_batch_cast(Client, Direction) ->
    PoolName = pool_name(Client),
    {ok,  {_BatchRef1, 1, [{RequestRef1, _Request1}]} = BatchState1} =
        shackle:batch_cast(PoolName, [{add, 1, 2}]),
    {ok,  {_BatchRef2, 1, [{RequestRef2, _Request2}]} = BatchState2} =
        shackle:batch_cast(PoolName, [{multiply, 3, 4}]),
    case Direction of
        fifo ->
            ?assertEqual([{RequestRef1, {ok, 3}}], shackle:receive_batch_response(BatchState1)),
            ?assertEqual([{RequestRef2, {ok, 12}}], shackle:receive_batch_response(BatchState2));
        lifo ->
            ?assertEqual([{RequestRef2, {ok, 12}}], shackle:receive_batch_response(BatchState2)),
            ?assertEqual([{RequestRef1, {ok, 3}}], shackle:receive_batch_response(BatchState1))
    end.

batch_cast_modulo_novalue_value(Client) ->
    PoolName = pool_name(Client),
    {ok,  {BatchRef, 2,
        [{_RequestRef1, _Request1}, {RequestRef2, _Request2}]}} =
        shackle:batch_cast(PoolName, [{modulo, 3, 0}, {modulo, 3, 2}]),
    BatchState = {BatchRef, 1, []},
    [{RequestRef2, {ok, (3 rem 2)}}] = shackle:receive_batch_response(BatchState).

batch_expect_ordered_ops() ->
    [E1] = batch_expect_ordered([{modulo, 1, 1}]),
    ?assertEqual({ok, (1 rem 1)}, E1),
    [E2] = batch_expect_ordered([{modulo, 1, 0}]),
    ?assertEqual({error, timeout_handled}, E2),
    E3 = batch_expect_ordered([{modulo, 1, 0}, {modulo, 1, 1}]),
    ?assertEqual([{error, no_reply}, {ok, (1 rem 1)}], E3),
    E4 = batch_expect_ordered([{modulo, 1, 0}, {modulo, 1, 5},
                               {modulo, 1, 0}, {modulo, 2, 5}]),
    ?assertEqual([{error, no_reply}, {ok, (1 rem 5)}, {error, no_reply}, {ok, (2 rem 5)}], E4),
    E5 = batch_expect_ordered([{modulo, 1, 0}, {modulo, 1, 5},
                               {modulo, 1, 0}, {modulo, 2, 5}, {modulo, 1, 0}]),
    ?assertEqual([{error, no_reply}, {ok, (1 rem 5)}, {error, no_reply}, {ok, (2 rem 5)},
                  {error, timeout_handled}], E5).

batch_expect_ordered_replies_value(Client) ->
    PoolName = pool_name(Client),
    [Value] =
        shackle:batch_call_expect_ordered_replies(PoolName, [{modulo, 3, 2}]),
    ?assertEqual({ok, (3 rem 2)}, Value).

batch_expect_ordered_replies_novalue(Client) ->
    PoolName = pool_name(Client),
    [Value] =
        shackle:batch_call_expect_ordered_replies(PoolName, [{modulo, 3, 0}]),
    ?assertEqual({error, timeout_handled}, Value).

batch_expect_ordered_replies_value_value(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 4}, {modulo, 5, 3}]),
    ?assertEqual({ok, (5 rem 4)}, Value1),
    ?assertEqual({ok, (5 rem 3)}, Value2).

batch_expect_ordered_replies_novalue_value(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 3, 0}, {modulo, 3, 2}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({ok, (3 rem 2)}, Value2).

batch_expect_ordered_replies_novalue_novalue_value(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2, Value3] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 0}, {modulo, 7, 0}, {modulo, 5, 3}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({error, no_reply}, Value2),
    ?assertEqual({ok, (5 rem 3)}, Value3).

batch_expect_ordered_replies_novalue_value_value(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2, Value3] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 0}, {modulo, 5, 4}, {modulo, 5, 3}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({ok, (5 rem 4)}, Value2),
    ?assertEqual({ok, (5 rem 3)}, Value3).

batch_expect_ordered_replies_novalue_value_novalue_value(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2, Value3, Value4] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 0}, {modulo, 5, 4}, {modulo, 7, 0}, {modulo, 5, 3}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({ok, (5 rem 4)}, Value2),
    ?assertEqual({error, no_reply}, Value3),
    ?assertEqual({ok, (5 rem 3)}, Value4).

batch_expect_ordered_replies_novalue_value_novalue_value_novalue(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2, Value3, Value4, Value5] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 0}, {modulo, 5, 4},
                {modulo, 7, 0}, {modulo, 5, 3},
                {modulo, 9, 0}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({ok, (5 rem 4)}, Value2),
    ?assertEqual({error, no_reply}, Value3),
    ?assertEqual({ok, (5 rem 3)}, Value4),
    ?assertEqual({error, timeout_handled}, Value5).

batch_expect_ordered_replies_novalue_value_novalue_novalue(Client) ->
    PoolName = pool_name(Client),
    [Value1, Value2, Value3, Value4] =
        shackle:batch_call_expect_ordered_replies(PoolName,
            [{modulo, 5, 0}, {modulo, 5, 4},
                {modulo, 7, 0}, {modulo, 9, 0}]),
    ?assertEqual({error, no_reply}, Value1),
    ?assertEqual({ok, (5 rem 4)}, Value2),
    ?assertEqual({error, timeout_handled}, Value3),
    ?assertEqual({error, timeout_handled}, Value4).

batch_cast_random_ordered(Client, NBatches, MinLen, LenVariation) ->
    PoolName = pool_name(Client),
    Req = batch_mk_random_ordered(MinLen, LenVariation),
    BatchExpectPairs = lists:duplicate(NBatches, Req),
    {Batch, BatchesOfExpects} = lists:unzip(BatchExpectPairs),
    BatchesOfReplies =
        [shackle:batch_call_expect_ordered_replies(PoolName, Ops) ||
            Ops <- Batch],
    PairsOfExpectsReplies= lists:zip(BatchesOfExpects, BatchesOfReplies),
    [assert_list(lists:zip(Expects, Replies)) ||
        {Expects, Replies} <- PairsOfExpectsReplies].

batch_mk_random_ordered_terminated(Len) ->
    Ops = [mk_random_ordered_op(7) || _ <- lists:seq(1, Len)],
    lists:append([Ops, [{modulo, 1, 1}]]).

batch_mk_random_ordered(Len) ->
    Ops = batch_mk_random_ordered_terminated(Len),
    Expect = batch_expect(Ops),
    {Ops, Expect}.

batch_mk_random_ordered(MinLen, 0) ->
    batch_mk_random_ordered(MinLen);
batch_mk_random_ordered(MinLen, LenVariation) ->
    L = MinLen + shackle_utils:random(LenVariation),
    Ops = batch_mk_random_ordered_terminated(L),
    Expect = batch_expect_ordered(Ops),
    {Ops, Expect}.

batch_cast_random(Client, NBatches, MinLen, LenVariation) ->
    BatchStateExpectPairs = [mk_random_batch_cast(Client, MinLen, LenVariation) ||
        _ <- lists:seq(1, NBatches)],
    BatchRefWithPairsOfRequestRefExpect =
        [{BatchRef, to_requestref_expect(PairsOfRequestRefRequest, Expects)} ||
            {{BatchRef, _Count, PairsOfRequestRefRequest}, Expects}
                <- BatchStateExpectPairs],
    {BatchStates, _Expects} = lists:unzip(BatchStateExpectPairs),
    ShuffledBatchStates = shuffle(BatchStates),
    BatchRefWithPairsOfRequestRefReply =
        [{BatchRef, shackle:receive_batch_response(BatchState)}
        ||  {BatchRef, _Count, _PairsOfRequestRefRequest} = BatchState
            <- ShuffledBatchStates],

    BatchRefWithPairsOfPairs = left_join(BatchRefWithPairsOfRequestRefExpect,
        BatchRefWithPairsOfRequestRefReply),

    NoReplyBatches = lists:filter(fun ({_K, {_V1, V2}}) -> V2 == null end,
        BatchRefWithPairsOfPairs),
    ?assertEqual([], NoReplyBatches),

    BatchRefRequestRefs = [{BatchRef, left_join(Expects, Replies)} ||
        {BatchRef, {Expects, Replies}} <- BatchRefWithPairsOfPairs],

    [?assertEqual(Expect, Reply) ||
        {_BatchRef, RequestRefs} <- BatchRefRequestRefs,
        {_Key, {Expect, Reply}} <- RequestRefs].

batch_cast_random_partial(Client, NBatches, MinLen, LenVariation) ->
    Cast = mk_random_batch_cast(Client, MinLen, LenVariation),
    Batches = lists:duplicate(NBatches, Cast),
    Splitted = [ mk_random_batch_split(B) || B <- Batches],
    {Part1, Part2} = lists:unzip(Splitted),
    Shuffled1 = shuffle(Part1),
    Shuffled2 = shuffle(Part2),
    Shuffled = lists:append([Shuffled1, Shuffled2]),

    BatchStateExpectPairs = Shuffled,
    BatchRefWithPairsOfRequestRefExpect =
        [{BatchRef, to_requestref_expect(PairsOfRequestRefRequest, Expects)} ||
            {{BatchRef, _Count, PairsOfRequestRefRequest}, Expects}
                <- BatchStateExpectPairs],

    {BatchStates, _Expects} = lists:unzip(BatchStateExpectPairs),
    ShuffledBatchStates = BatchStates,

    BatchRefWithPairsOfRequestRefReply =
        [{BatchRef, shackle:receive_batch_response(BatchState)}
            ||  {BatchRef, _Count, _PairsOfRequestRefRequest} = BatchState
            <- ShuffledBatchStates],

    GroupedExpect = [{Ref, lists:append(Xs)} ||
        {Ref, Xs} <- groupby(BatchRefWithPairsOfRequestRefExpect)],
    GroupedReply = [{Ref, lists:append(Xs)} ||
        {Ref, Xs} <- groupby(BatchRefWithPairsOfRequestRefReply)],

    BatchRefWithPairsOfPairs = left_join(GroupedExpect, GroupedReply),

    NoReplyBatches = lists:filter(fun ({_K, {_V1, V2}}) -> V2 == null end,
        BatchRefWithPairsOfPairs),
    ?assertEqual([], NoReplyBatches),

    BatchRefRequestRefs = [{BatchRef, left_join(Expects, Replies)} ||
        {BatchRef, {Expects, Replies}} <- BatchRefWithPairsOfPairs],

    [?assertEqual(Expect, Reply) ||
        {_BatchRef, RequestRefs} <- BatchRefRequestRefs,
        {_Key, {Expect, Reply}} <- RequestRefs].

%% utils
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
    Ops = lists:duplicate(Len, mk_random_op()),
    Expect = batch_expect(Ops),
    {Ops, Expect}.

batch_mk_random(MinLen, 0) ->
    batch_mk_random(MinLen);
batch_mk_random(MinLen, LenVariation) ->
    L = MinLen + shackle_utils:random(LenVariation),
    Ops = lists:duplicate(L, mk_random_op()),
    Expect = batch_expect(Ops),
    {Ops, Expect}.

batch_expect(Ops) ->
    lists:map(fun op_result_wrap_ok/1, Ops).

batch_expect_ordered(Ops) ->
    Results = batch_expect(Ops),
    {ErrAcc, Acc} = lists:foldl(fun (X, {ErrA, A}) ->
            case X of
                {error, _} = Err ->
                    {[Err|ErrA], A};
                V ->
                    {[], [op_result_wrap_ok(V)|append_to_constant(ErrA, {error, no_reply}, A)]}
            end
        end,
        {[], []}, Results),
    lists:reverse(append_to_constant(ErrAcc, {error, timeout_handled}, Acc)).

append_to_constant(Xs, C, Ys) ->
    lists:append(lists:map(fun (_) -> C end, Xs), Ys).

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

mk_random_ordered_op(N) ->
    case shackle_utils:random(N) of
        N ->
            A = rand(),
            B = rand(),
            {modulo, A, B};
        _ ->
            A = rand(),
            {modulo, A, 0}
    end.

to_requestref_expect(PairsOfRequestRefRequest, Expects) ->
    [{RequestRef, Expect} ||
        {{RequestRef, _Request}, Expect}
            <- lists:zip(PairsOfRequestRefRequest, Expects)].

mk_random_batch_split({{BatchRef, _Count, RequestRefs}, Expect}) ->
    RequestRefExpectPairs = lists:zip(RequestRefs, Expect),
    {{L1, RequestRefExpectPairs1}, {L2, RequestRefExpectPairs2}} =
        split_random(RequestRefExpectPairs),
    {RequestRefs1, Expect1} = lists:unzip(RequestRefExpectPairs1),
    {RequestRefs2, Expect2} = lists:unzip(RequestRefExpectPairs2),
    {{{BatchRef, L1, RequestRefs1}, Expect1},
        {{BatchRef, L2, RequestRefs2}, Expect2}}.

mk_random_batch_cast(Client, MinLen, LenVariation) ->
    PoolName = pool_name(Client),
    {Ops, Expects} = batch_mk_random(MinLen, LenVariation),
    {ok, {_BatchRef, Count, _RequestRefs} = BatchState} =
        shackle:batch_cast(PoolName, Ops),
    ?assertEqual(length(Expects), Count),
    {BatchState, Expects}.

op_result_wrap_ok({ok, _} = V) ->
    V;
op_result_wrap_ok(V) ->
    try
        {ok, op_result(V)}
    catch throw:invalid_argument ->
        {error, invalid_argument}
    end.

op_result(noop) -> ok;
op_result({add, A, B}) -> A + B;
op_result({multiply, A, B}) -> A * B;
op_result({modulo, _A, 0}) -> throw(invalid_argument);
op_result({modulo, A, B}) -> A rem B.

left_join(Left, Right) ->
    left_join(Left, Right, []).

left_join([], _Right, Acc) ->
    Acc;
left_join([{Key, L}|T], Right, Acc) ->
    {{Key, R}, Right1} = takeout(Key, Right),
    left_join(T, Right1, [{Key, {L, R}}|Acc]).

takeout(Key, L) when is_list(L) ->
    takeout(Key, L, []);
takeout(Key, _L) ->
    takeout(Key, [], []).

takeout(Key, [], Acc) ->
    {{Key, null}, Acc};
takeout(Key, [{Key, V}|T], Acc) ->
    {{Key, V}, lists:append(Acc, T)};
takeout(Key, [H|T], Acc) ->
    takeout(Key, T, [H|Acc]).

takeout_all(K, L) ->
    takeout_all(K, L, []).

takeout_all(K, L, Acc) ->
    {{K, V}, L1} = takeout(K, L),
    case V of
        null -> Acc;
        _ -> takeout_all(K, L1, [V|Acc])
    end.

uniq(Xs) ->
    Ys = lists:sort(Xs),
    {_, Uniq} = lists:foldl(fun (Y, {Curr, Acc}) ->
        case Y == Curr of
            true -> {Curr, Acc};
            false -> {Y, [Y|Acc]}
        end
                            end,
        {undefined, []}, Ys),
    Uniq.

groupby(Xs) ->
    Ks = uniq(lists:map(fun ({X, _}) -> X end, Xs)),
    lists:map(fun (K) -> {K, takeout_all(K, Xs)} end, Ks).

split_random([]) ->
    {{0, []}, {0, []} };
split_random(Xs) ->
    L = length(Xs),
    N = round(rand:uniform() * (L-1)) + 1,
    {Ys, Zs} = lists:split(N, Xs),
    {{N, Ys}, {L-N, Zs}}.

shuffle(Xs) ->
    [X || {_, X} <- lists:sort([{rand:uniform(), X} || X <- Xs])].

server(?CLIENT_SSL) -> arithmetic_ssl_server;
server(?CLIENT_TCP) -> arithmetic_tcp_server;
server(?CLIENT_UDP) -> arithmetic_udp_server.

pool_name(?CLIENT_SSL) -> arithmetic_ssl;
pool_name(?CLIENT_TCP) -> arithmetic_tcp;
pool_name(?CLIENT_UDP) -> arithmetic_udp.

setup() ->
    error_logger:tty(false),
    shackle_app:start().

-endif.
