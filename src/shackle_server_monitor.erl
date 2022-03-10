-module(shackle_server_monitor).

-include("shackle_internal.hrl").

-behaviour(gen_server).

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-record(state, {
    timer_ref :: reference(),
    monitoring_interval :: pos_integer(),
    pool_name :: pool_name(),
    backlog_size :: pos_integer() | infinity,
    backlog :: table(),
    queue :: table(),
    servers :: [{server_name(), pos_integer()}],
    on_watch = sets:new() :: sets:set(server_name())
}).

-type state() :: #state{}.

-define(DEFAULT_INTERVAL_IN_MS, timer:minutes(5)).

%%%===================================================================
%%% API
%%%===================================================================

-spec start_link(MonitorName :: atom(), MonitorOptions :: term()) ->
    {ok, pid()} | ignore | {error, term()}.
start_link(MonitorName, MonitorOptions) ->
    gen_server:start_link({local, MonitorName}, ?MODULE, MonitorOptions, []).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

-spec init(term()) -> {ok, state()}.
init({PoolName, Servers, BacklogSize}) ->
    MonitoringInterval = ?GET_ENV(monitoring_interval, ?DEFAULT_INTERVAL_IN_MS),
    {ok, #state{
        timer_ref = erlang:start_timer(MonitoringInterval, self(), check),
        monitoring_interval = MonitoringInterval,
        pool_name = PoolName,
        backlog_size = BacklogSize,
        backlog = shackle_backlog:table_name(PoolName),
        queue = shackle_queue:table_name(PoolName),
        servers = Servers
    }}.

-spec handle_call(term(), term(), state()) -> {noreply, state()}.
handle_call(_Request, _From, State) ->
    {noreply, State}.

-spec handle_cast(term(), state()) -> {noreply, state()}.
handle_cast(_Msg, State) ->
    {noreply, State}.

-spec handle_info(term(), state()) -> {noreply, state()}.
handle_info(
    {timeout, TimerRef, check},
    State = #state{
        monitoring_interval = MonitoringInterval,
        timer_ref = TimerRef,
        servers = Servers
    }
) ->
    IsBlocked = is_blocked(State),
    ToWatch = lists:foldl(IsBlocked, sets:new(), Servers),
    ToRestart = sets:intersection(ToWatch, State#state.on_watch),
    lists:foreach(
        fun(ServerId) -> ServerId ! reset end,
        sets:to_list(ToRestart)
    ),
    {noreply, State#state{
        timer_ref = erlang:start_timer(MonitoringInterval, self(), check),
        on_watch = sets:subtract(ToWatch, ToRestart)
    }};
handle_info(_Info, State) ->
    {noreply, State}.

-spec terminate(term(), state()) -> ok.
terminate(_Reason, _State) ->
    ok.

-spec code_change(term(), state(), term()) -> {ok, state()}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

-spec is_blocked(State :: state()) ->
    fun(
        (
            {server_name(), pos_integer()},
            sets:set(server_name())
        ) -> sets:set(server_name())
    ).
is_blocked(#state{
    queue = Queue,
    backlog = Backlog,
    backlog_size = BacklogSize
}) ->
    fun({ServerId, Id}, ToWatch) ->
        Pending = shackle_queue:pending(Queue, Id),
        case {shackle_backlog:size(Backlog, Id), length(Pending)} of
            {BacklogSize, Size} when Size < BacklogSize ->
                sets:add_element(ServerId, ToWatch);
            {_, _} ->
                ToWatch
        end
    end.
