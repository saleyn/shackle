-module(multi_call_tests).
-include_lib("eunit/include/eunit.hrl").

-export([
    % fake protocol
    connect/3, setopts/2, send/2, close/1,
    % client callbacks
    init/1, setup/2, handle_request/2, handle_data/2, terminate/1
]).

% protocol stubs

connect(_Ip, fake_port, _SockOpts) -> {ok, fake_socket}.

setopts(fake_socket, _SockOpts) -> ok.

send(fake_socket, Data) ->
    self() ! {tcp, fake_socket, Data},
    ok.

close(fake_socket) -> ok.

% client callbacks

init(_Opts) -> {ok, 1}.

setup(fake_socket, Id) -> {ok, Id}.

handle_request(even, Id) -> {ok, Id, <<Id:32,1:8>>, Id + 1};
handle_request(odd, Id) -> {ok, Id, <<Id:32,0:8>>, Id + 1};
handle_request(N, Id) -> {ok, Id, <<Id:32,N:32>>, Id + 1}.

handle_data(<<Id:32,1:8>>, ClientState) -> {ok, [{Id, even}], ClientState};
handle_data(<<Id:32,0:8>>, ClientState) -> {ok, [{Id, odd}], ClientState};
handle_data(<<Id:32,N:32>>, ClientState) -> {ok, [{Id, N}], ClientState}.

terminate(_) -> ok.

% tests start here

setup() ->
    error_logger:tty(false),
    Cleanup = shackle_test_utils:with_prometheus(),
    shackle_app:start(),
    shackle_pool:start(simple, ?MODULE, [{protocol, ?MODULE}, {port, fake_port}], [{pool_size, 1}]),
    true = shackle_pool:wait_until_all_available(simple, 100),
    Cleanup.

cleanup(Cleanup) ->
    shackle_pool:stop(simple),
    try shackle_app:stop() catch _:_ -> ok end,
    shackle_test_utils:cleanup_mocks(Cleanup).

echo_test_() ->
    {setup, fun setup/0, fun cleanup/1, [fun echo_subtest/0]}.

echo_subtest() ->
    ?assertEqual(123, shackle:call(simple, 123)).

multi_test_() ->
    {setup, fun setup/0, fun cleanup/1, [fun multi_subtest/0]}.

multi_subtest() ->
    AddFunc = fun
        (recv, N, Acc) -> {continue, [N | Acc]};
        (_, _, Acc) -> {continue, Acc}
    end,

    EvenCall = [{simple, X, AddFunc} || X <- [0, 2, 4, 6, 8]],
    OddCall = [{simple, X, AddFunc} || X <- [1, 3, 5, 7, 9]],

    ChainFunc = fun
        (recv, even, Acc) -> {chain, EvenCall, Acc};
        (recv, odd, Acc) -> {chain, OddCall, Acc};
        (_, _, Acc) -> {continue, Acc}
    end,

    StartCalls = [
        {simple, even, ChainFunc},
        {simple, odd, ChainFunc}
    ],

    L = shackle:multi_call(StartCalls, 100, []),

    ?assertEqual(lists:seq(0, 9), lists:sort(L)).
