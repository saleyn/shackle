-module(shackle_observe_prometheus_metrics_test).

-include_lib("eunit/include/eunit.hrl").

%%%
%%% Simple Tests - Each one verifies one metric is called
%%%

%% Test 1: shackle_request_total
shackle_request_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    % Trigger the event
    ok = shackle_observe:event([call, stop], #{}, Metadata),

    % Verify call was recorded
    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_request_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 2: shackle_cast_total
shackle_cast_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([cast, stop], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_cast_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 3: shackle_connect_total
shackle_connect_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([connect, stop], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_connect_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 4: shackle_close_total
shackle_close_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([disconnect], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_close_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 5: shackle_error_total (timeout)
shackle_error_total_timeout_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([timeout], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_error_total, [_Client, _Pool, <<"timeout">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 6: shackle_error_total (exception)
shackle_error_total_exception_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([call, exception], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_error_total, [_Client, _Pool, <<"exception">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 7: shackle_reply_total
shackle_reply_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([reply], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_reply_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 8: shackle_response_total
shackle_response_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, status => ok},

    ok = shackle_observe:event([response], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_response_total, [_Client, _Pool, <<"ok">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 9: shackle_socket_total
shackle_socket_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, event => connect},

    ok = shackle_observe:event([socket], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_socket_total, [_Client, _Pool, <<"connect">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 10: shackle_attempt_total
shackle_attempt_total_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, reason => first_attempt},

    ok = shackle_observe:event([server_lookup, attempt], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_attempt_total, [_Client, _Pool, <<"first_attempt">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 11: shackle_received_bytes_total and shackle_received_messages_total
shackle_data_received_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Bytes = 2048,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([data, received], #{bytes => Bytes}, Metadata),

    History = meck:history(prometheus_counter),
    BytesCalls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_received_bytes_total, [_Client, _Pool], _Bytes]}, _} = C
        <- History],
    MessagesCalls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_received_messages_total, [_Client, _Pool], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(BytesCalls)),
    ?assertEqual(1, length(MessagesCalls)).

%% Test 12: shackle_response_time_microseconds
shackle_response_time_microseconds_test() ->
    Cleanup = init_prometheus(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Microseconds = 50000,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe:event([response_time], #{microseconds => Microseconds}, Metadata),

    History = meck:history(prometheus_histogram),
    Calls = [C ||
        {_, {prometheus_histogram, observe,
             [shackle_response_time_microseconds, [_Client, _Pool], _Microseconds]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%%%
%%% Integration Tests - Verify no double-counting in cast/batch_cast
%%%

%% Test: cast/4 should only increment shackle_cast_total once
cast_no_double_counting_test() ->
    Cleanup = init_prometheus(),
    try
        % Setup a mock pool and server
        setup_test_pool(),

        % Call cast/4 which wraps with dispatcher
        Result = shackle:cast(test_pool, <<"request">>, undefined, 5000),

        % Verify the result is an error (because we don't have a real server)
        % but verify that shackle_cast_total was only incremented once
        case Result of
            {error, _} ->
                % Expected: pool not found or no server available
                ok;
            {ok, _} ->
                % If it succeeds, that's fine too
                ok
        end,

        % Verify shackle_cast_total was incremented exactly once
        History = meck:history(prometheus_counter),
        CastCalls = [C ||
            {_, {prometheus_counter, inc, [shackle_cast_total, _Labels, 1]}, _} = C
            <- History],

        % Should be exactly 1 call to shackle_cast_total
        ?assertEqual(1, length(CastCalls))
    after
        cleanup_test_pool(),
        shackle_test_utils:cleanup_mocks(Cleanup)
    end.

%% Test: batch_cast/4 should only increment shackle_cast_total once per batch
batch_cast_no_double_counting_test() ->
    Cleanup = init_prometheus(),
    try
        % Setup a mock pool and server
        setup_test_pool(),

        % Call batch_cast/4 which should now wrap with dispatcher
        Requests = [<<"req1">>, <<"req2">>, <<"req3">>],
        Result = shackle:batch_cast(test_pool, Requests, undefined, 5000),

        % Verify the result (expect error since we don't have real server)
        case Result of
            {error, _} ->
                % Expected: pool not found or no server available
                ok;
            {ok, _} ->
                % If it succeeds, that's fine too
                ok
        end,

        % Verify shackle_cast_total was incremented exactly once for the batch
        History = meck:history(prometheus_counter),
        CastCalls = [C ||
            {_, {prometheus_counter, inc, [shackle_cast_total, _Labels, 1]}, _} = C
            <- History],

        % Should be exactly 1 call to shackle_cast_total (not 3 for 3 requests)
        ?assertEqual(1, length(CastCalls))
    after
        cleanup_test_pool(),
        shackle_test_utils:cleanup_mocks(Cleanup)
    end.

%% Test: cast/4 and batch_cast/4 should count differently
cast_vs_batch_cast_test() ->
    Cleanup = init_prometheus(),
    try
        setup_test_pool(),

        % Call cast/4 once
        shackle:cast(test_pool, <<"req1">>, undefined, 5000),

        % Call batch_cast/4 with 3 requests
        shackle:batch_cast(test_pool, [<<"r1">>, <<"r2">>, <<"r3">>], undefined, 5000),

        % Verify shackle_cast_total was incremented exactly twice
        % (once for cast, once for batch_cast)
        History = meck:history(prometheus_counter),
        CastCalls = [C ||
            {_, {prometheus_counter, inc, [shackle_cast_total, _Labels, 1]}, _} = C
            <- History],

        % Should be exactly 2 calls (one per cast and batch_cast)
        ?assertEqual(2, length(CastCalls))
    after
        cleanup_test_pool(),
        shackle_test_utils:cleanup_mocks(Cleanup)
    end.

%% Helper: Setup a test pool
setup_test_pool() ->
    % Define a minimal client module for testing
    try shackle_pool:start(test_pool, test_client, []) of
        ok -> ok;
        {error, pool_already_started} -> ok;
        {error, pool_not_started} -> ok;
        _ -> ok
    catch
        _:_ -> ok
    end.

%% Helper: Cleanup test pool
cleanup_test_pool() ->
    try shackle_pool:stop(test_pool)
    catch
        _:_ -> ok
    end.

init_prometheus() ->
    OldVal = application:get_env(shackle, observability),
    persistent_term:erase(shackle_observe),
    application:set_env(shackle, observability, prometheus),
    Cleanup = shackle_test_utils:with_prometheus([{shackle, observability, OldVal}]),
    ok = shackle_observe_prometheus:start(),
    [fun() -> persistent_term:erase(shackle_observe) end | Cleanup].
