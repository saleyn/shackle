-module(shackle_observe_prometheus_metrics_test).

-include_lib("eunit/include/eunit.hrl").

%%%
%%% Simple Tests - Each one verifies one metric is called
%%%

%% Test 1: shackle_request_total
shackle_request_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    % Trigger the event
    ok = shackle_observe_prometheus:event([shackle, call, stop], #{}, Metadata),

    % Verify call was recorded
    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_request_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 2: shackle_cast_total
shackle_cast_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, cast, stop], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_cast_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 3: shackle_connect_total
shackle_connect_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, connect, stop], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_connect_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 4: shackle_close_total
shackle_close_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, disconnect], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_close_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 5: shackle_error_total (timeout)
shackle_error_total_timeout_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, timeout], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_error_total, [_Client, _Pool, <<"timeout">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 6: shackle_error_total (exception)
shackle_error_total_exception_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, call, exception], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_error_total, [_Client, _Pool, <<"exception">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 7: shackle_reply_total
shackle_reply_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, reply], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C || {_, {prometheus_counter, inc, [shackle_reply_total, [_Client, _Pool], 1]}, _} = C <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 8: shackle_response_total
shackle_response_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, status => ok},

    ok = shackle_observe_prometheus:event([shackle, response], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_response_total, [_Client, _Pool, <<"ok">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 9: shackle_socket_total
shackle_socket_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, event => connect},

    ok = shackle_observe_prometheus:event([shackle, socket], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_socket_total, [_Client, _Pool, <<"connect">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 10: shackle_attempt_total
shackle_attempt_total_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Metadata = #{pool => Pool, client => Client, reason => first_attempt},

    ok = shackle_observe_prometheus:event([shackle, server_lookup, attempt], #{}, Metadata),

    History = meck:history(prometheus_counter),
    Calls = [C ||
        {_, {prometheus_counter, inc,
             [shackle_attempt_total, [_Client, _Pool, <<"first_attempt">>], 1]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).

%% Test 11: shackle_received_bytes_total and shackle_received_messages_total
shackle_data_received_test() ->
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Bytes = 2048,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, data, received], #{bytes => Bytes}, Metadata),

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
    Cleanup = shackle_test_utils:with_prometheus(),
    ok = shackle_observe_prometheus:start(),

    Client = <<"test_service">>,
    Pool = <<"pool1">>,
    Microseconds = 50000,
    Metadata = #{pool => Pool, client => Client},

    ok = shackle_observe_prometheus:event([shackle, response_time], #{microseconds => Microseconds}, Metadata),

    History = meck:history(prometheus_histogram),
    Calls = [C ||
        {_, {prometheus_histogram, observe,
             [shackle_response_time_microseconds, [_Client, _Pool], _Microseconds]}, _} = C
        <- History],

    shackle_test_utils:cleanup_mocks(Cleanup),
    ?assertEqual(1, length(Calls)).
