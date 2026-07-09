-module(shackle_probe).
-behaviour(gen_server).

-include("shackle_internal.hrl").

-export([
    start_link/3,
    stop/1
]).

-export([
    init/1,
    handle_info/2,
    handle_cast/2,
    handle_call/3,
    terminate/2
]).

-record(state, {
    pool_name :: shackle_pool:name(),
    pool_size :: pos_integer(),
    interval  :: pos_integer(),
    bytes     :: binary()
}).

-type state() :: #state{}.

-spec start_link(shackle_pool:name(), shackle:client(), map()) -> {ok, pid()} | {error, term()}.
start_link(PoolName, _Client, Opts) ->
    Name = probe_name(PoolName),
    gen_server:start_link({local, Name}, ?MODULE, {PoolName, Opts}, []).

-spec stop(shackle_pool:name()) -> ok.
stop(PoolName) ->
    gen_server:stop(probe_name(PoolName)).

%% gen_server callbacks

-spec init({shackle_pool:name(), map()}) -> {ok, state()}.
init({PoolName, Opts}) ->
    Interval = maps:get(interval, Opts, 1000),
    PayloadSize = maps:get(payload_size, Opts, 1024),
    {ok, PoolOpts} = shackle_pool:options(PoolName),
    PoolSize = element(5, PoolOpts),
    Bytes = crypto:strong_rand_bytes(PayloadSize),
    schedule_tick(Interval),
    {ok, #state{
        pool_name = PoolName,
        pool_size = PoolSize,
        interval = Interval,
        bytes = Bytes
    }}.

-spec handle_info(term(), state()) -> {noreply, state()}.
handle_info(tick, #state{pool_name = PoolName, pool_size = PoolSize,
                         interval = Interval, bytes = Bytes} = State) ->
    Idx = rand:uniform(PoolSize),
    ServerName = shackle_pool:server_name(PoolName, Idx),
    SentAt = erlang:monotonic_time(),
    try
        ServerName ! {probe, SentAt, Bytes}
    catch error:badarg ->
        ok
    end,
    schedule_tick(Interval),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_call(term(), gen_server:from(), state()) -> {reply, ok, state()}.
handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

-spec terminate(term(), state()) -> ok.
terminate(_Reason, _State) ->
    ok.

%% private

probe_name(PoolName) ->
    list_to_atom("shackle_probe_" ++ atom_to_list(PoolName)).

schedule_tick(Interval) ->
    erlang:send_after(Interval, self(), tick).
