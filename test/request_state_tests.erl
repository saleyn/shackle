-module(request_state_tests).
-include_lib("eunit/include/eunit.hrl").

-export([
    % fake protocol
    connect/3, setopts/2, send/2, close/1,
    % client callbacks
    init/2, handle_request/2, handle_data/2, terminate/1
]).

% protocol stubs

connect(_Ip, fake_port, _SockOpts) -> {ok, fake_socket}.

setopts(fake_socket, _SockOpts) -> ok.

send(fake_socket, Data) ->
    self() ! {tcp, fake_socket, Data},
    ok.

close(fake_socket) -> ok.

% client callbacks

init(_Opts, _Ctx) -> {ok, 1}.

handle_request(N, Id) -> {ok, Id, <<Id:32, N:32>>, {input, N}, Id + 1}.

handle_data(<<Id:32, N:32>>, ClientState) ->
    {progress, Id, N + N, fun (Data, {input, X}, State) -> {ok, {X, Data}, State} end, ClientState}.

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
    catch shackle_app:stop(),
    shackle_test_utils:cleanup_mocks(Cleanup).

double_test_() ->
    {setup, fun setup/0, fun cleanup/1, [fun double_subtest/0]}.

double_subtest() ->
    ?assertEqual({123, 246}, shackle:call(simple, 123)).
