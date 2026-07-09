-module(shackle_chunking_tests).
-include_lib("eunit/include/eunit.hrl").

setup() ->
    error_logger:tty(false),
    Cleanup = shackle_test_utils:with_prometheus(),
    shackle_app:start(),
    Cleanup.

cleanup(Cleanup) ->
    try chunking_udp_client:stop() catch _:_ -> ok end,
    try chunking_udp_server:stop() catch _:_ -> ok end,
    try shackle_app:stop() catch _:_ -> ok end,
    shackle_test_utils:cleanup_mocks(Cleanup).

seq_test_() ->
    {setup, fun setup/0, fun cleanup/1, [fun seq_subtest/0]}.

seq_subtest() ->
    ok = chunking_udp_client:start(),
    ok = chunking_udp_server:start(),
    ?assert(chunking_udp_client:wait_until_all_available(2000)),
    N_chunks = 100,
    Expected = [X + X || X <- lists:seq(1, N_chunks)],
    ?assertEqual(Expected, chunking_udp_client:seq(N_chunks)),
    ok = chunking_udp_server:stop().
