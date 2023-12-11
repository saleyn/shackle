-module(chunking_udp_client).
-include("test.hrl").

-export([
    seq/1,
    start/0,
    start/1,
    start/2,
    stop/0,
    wait_until_all_available/1
]).

-behavior(shackle_client).
-export([
    init/1,
    setup/2,
    handle_request/2,
    handle_data/2,
    terminate/1
]).

wait_until_all_available(Timeout) ->
    shackle_pool:wait_until_all_available(?POOL_NAME_UDP, Timeout).

seq(N) ->
    shackle:call(?POOL_NAME_UDP, {seq, N}).

start() ->
    start([
        {backlog_size, ?BACKLOG_SIZE},
        {pool_size, 1}
    ]).

-spec start(shackle_pool:options()) ->
    ok | {error, shackle_not_started | pool_already_started}.
start(PoolOptions) ->
    start(PoolOptions, []).

-spec start(shackle_pool:options(), shackle_client:options()) ->
    ok | {error, shackle_not_started | pool_already_started}.
start(PoolOptions, ClientOptions) ->
    shackle_pool:start(?POOL_NAME_UDP, chunking_udp_client, ClientOptions ++ [
        {port, ?PORT},
        {reconnect, true},
        {reconnect_time_min, 1},
        {protocol, shackle_udp},
        {socket_options, [binary]}
    ], PoolOptions).

-spec stop() ->
    ok | {error, pool_not_started}.

stop() ->
    shackle_pool:stop(?POOL_NAME_UDP).

%% shackle_server callbacks

% initialize state as a request number
init(_) ->
    {ok, 1}.

% no-op
setup(_Socket, State) ->
    {ok, State}.

% decode response chunk
handle_data(<<ReqId:32, ChId:32, Last:8, Chunk:32>>, State) ->
    {progress, ReqId, {ChId, Chunk, to_bool(Last)}, fun proc/3, State}.

% decode boolean encoded as integer
to_bool(X) -> X == 0.

% encode request
handle_request({seq, N}, Id) ->
    {ok, Id, <<Id:32, N:32, "seq">>, Id + 1}.

% no-op
terminate(_State) ->
    ok.

% proc response chunk
proc(Data, undefined, State) ->
    proc(Data, {undefined, #{}}, State);
proc({Id, Chunk, Last}, {Count, Chunks}, State) ->
    check(count(Last, Id, Count), Chunks#{Id => Chunk}, State).

% maybe update number of chunks
count(true, Id, _) -> Id + 1;
count(false, _, N) -> N.

% check if all chunks received (assuming no gaps in chunk ids)
check(N, Map, State) when is_integer(N), map_size(Map) == N ->
    {ok, aggregate(Map), State};
check(N, Map, State) ->
    {continue, {N, Map}, State}.

% prepare reply - convert map to values sorted by chunk ids
aggregate(Map) ->
    L = maps:to_list(Map),
    [X || {_, X} <- lists:sort(L)].
