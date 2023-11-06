-module(shackle_utils).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

%% public
-export([
    ets_options/0,
    info_msg/3,
    lookup/3,
    random/1,
    random_element/1,
    warning_msg/3,
    default_options/2,
    merge_options/2
]).

%% NOTE: use ?WARN(PoolName, Format, Data) macro instead
-deprecated([warning_msg/3]).

%% public
-spec ets_options() ->
  [atom() | {atom(), any()}].

-ifdef(DECENTRALIZED_COUNTERS).

ets_options() -> [
      named_table,
      public,
      {write_concurrency, true},
      {decentralized_counters, true}
  ].

-else.

ets_options() -> [
      named_table,
      public,
      {write_concurrency, true}
  ].

-endif.

-spec info_msg(shackle_pool:name(), string(), [term()]) ->
    ok.

info_msg(Pool, Format, Data) ->
    error_logger:info_msg("[~p] " ++ Format, [Pool | Data]).

-spec lookup(atom(), [{atom(), term()}], term()) ->
    term().

lookup(Key, List, Default) ->
    case lists:keyfind(Key, 1, List) of
        false -> Default;
        {_, Value} -> Value
    end.

-spec random(pos_integer()) ->
    non_neg_integer().

random(1) -> 1;
random(N) ->
    granderl:uniform(N).

-spec random_element([term()]) ->
    term().

random_element([X]) ->
    X;
random_element(L) when is_list(L) ->
    I = length(L),
    lists:nth(rand:uniform(I), L).

-spec warning_msg(shackle_pool:name(), string(), [term()]) ->
    ok.

warning_msg(Pool, Format, Data) ->
    ?WARN(Pool, Format, Data).

-spec default_options(client|pool, [{atom(), any()}]) -> [{atom(), any()}].
default_options(Node, Options) when Node==pool; Node==client ->
    DefOptions = ?GET_ENV(Node, []),
    maps:to_list(maps:merge(maps:from_list(DefOptions), maps:from_list(Options))).

%% @doc Shackle clients can use this function to merge their provided
%% options for a shackle client and pool with the global shackle options
%% defined in the `shackle' application.  The global options are overriden
%% by the client options passed to this function.
-spec merge_options([{atom(), any()}]|map(), [{atom(), any()}]|map()) ->
    {ClientConfig::list(), PoolConfig::list()}.
merge_options(ClientOptions, PoolOptions) ->
    ShackleConfig = application:get_all_env(shackle),
    ClientConfig = proplists:from_map(
        maps:merge(
            proplists:to_map(proplists:get_value(client, ShackleConfig, [])),
            to_map(ClientOptions)
        )
    ),
    PoolConfig = proplists:from_map(
        maps:merge(
            proplists:to_map(proplists:get_value(pool, ShackleConfig, [])),
            to_map(PoolOptions)
        )
    ),
    {ClientConfig, PoolConfig}.

to_map(L) when is_list(L) -> maps:from_list(L);
to_map(M) when is_map(M)  -> M.