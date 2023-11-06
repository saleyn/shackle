-module(shackle_utils).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.

%% public
-export([
    ets_options/0,
    info_msg/3,
    lookup/3,
    random/1,
    random_element/1,
    warning_msg/3,
    default_options/2,
    merge_options/1,
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

%% @doc Return global shackle options that get overriden by `Options' that are
%% provided by a shackle client library upon startup of a client or pool.
-spec default_options(client|pool, map()|[{atom(), any()}]) -> [{atom(), any()}].
default_options(Node, Options) when Node==pool; Node==client ->
    DefOptions = ?GET_ENV(Node, []),
    maps:to_list(maps:merge(to_map(DefOptions), to_map(Options))).

%% @doc Shackle clients can use this function to merge their provided
%% options for a shackle client and pool with the global shackle options
%% defined in the `shackle' application.  The global options are overriden
%% by the client options passed to this function. If a client provides an
%% option `{Option, Value}' in the `Options' list with the value equal to
%% the default value for that option in shackle, and shackle defines a global
%% value different from this default, then the global value will be used.
%%
%% Example:
%% ```
%% Config: {shackle, [{pool, [{pool_size, 2}]}]}
%%
%% Here the returned pool_size will be 2, because 16 is the default for
%% shackle pool size:
%%
%%   shackle_utils:merge_options([{pool_size, 16}])
%%
%% And here pool_size will be 4, because it's defined in the client's config:
%%
%% Config:
%% [
%%   {shackle, [{pool, [{pool_size, 2}]}]},
%%   {barker, [{pool_size, 4}]}
%% ].
%%
%% shackle_utils:merge_options([{}])
-spec merge_options([{atom(), any()}]) ->
    {[{atom(), any()}], [{atom(), any()}]}.
merge_options(AppShackleOptions) when is_list(AppShackleOptions) ->
    F = fun({I, {Type, D}}) ->
        case proplists:get_value(I, AppShackleOptions, undefined) of
            undefined -> {I, proplists:get_value(I, ?GET_ENV(Type, []), D)};
            Value when Value =:= D -> {I, proplists:get_value(I, ?GET_ENV(Type, []), D)};
            Value -> {I, Value}
        end
    end,
    PoolConfig = lists:map(F, [
        {backlog_size, {pool, ?DEFAULT_BACKLOG_SIZE}},
        {max_retries, {pool, ?DEFAULT_MAX_RETRIES}},
        {pool_size, {pool, ?DEFAULT_POOL_SIZE}},
        {pool_strategy, {pool, ?DEFAULT_POOL_STRATEGY}}
    ]),
    ClientConfig = lists:map(F, [
        {ip, {client, ?DEFAULT_ADDRESS}},
        {address, {client, ?DEFAULT_ADDRESS}},
        {protocol, {client, ?DEFAULT_PROTOCOL}},
        {reconnect, {client, ?DEFAULT_RECONNECT}},
        {reconnect_time_max, {client, ?DEFAULT_RECONNECT_MAX}},
        {reconnect_time_min, {client, ?DEFAULT_RECONNECT_MIN}},
        {socket_options, {client, ?DEFAULT_SOCKET_OPTS}},
        {bounce_interval_secs, {client, ?DEFAULT_BOUNCE_INTERVAL}},
        {on_bounce_event, {client, undefined}}
    ]),
    {ClientConfig, PoolConfig}.

-spec merge_options(atom(), [{atom(), any()}]) ->
    {[{atom(), any()}], [{atom(), any()}]}.
merge_options(App, DefaultOpts) when is_atom(App), is_list(DefaultOpts) ->
    Env = application:get_all_env(App),
    % Merge shackle globals with what's provided in the application environment
    Opts = lists:foldl(fun({K, _} = KV, Acc) ->
        case proplists:lookup(K, Acc) of
            none -> [KV | Acc];       % Value provided in the default options
            _ -> Acc                  % Value provided by client's environment
        end
    end, Env, DefaultOpts),
    merge_options(Opts).

to_map(L) when is_list(L) -> maps:from_list(L);
to_map(M) when is_map(M)  -> M.

%%%----------------------------------------------------------------------------
%%% Testing
%%%----------------------------------------------------------------------------
-ifdef(EUNIT).

shackle_settings_test_() ->
    {setup,
        fun() ->
            Old = application:get_all_env(shackle),
            application:set_env(shackle, client, [{bounce_interval_secs, 100}]),
            application:set_env(abcdef, bounce_interval_secs, 10),
            Old
        end,
        fun(Old) ->
            application:unset_env(abcdef, bounce_interval_secs),
            [application:set_env(shackle, K, V) || {K, V} <- Old]
        end,
        [
            ?_assertEqual(300, check(shackle_utils:merge_options([{bounce_interval_secs, 300}]))),
            % Provided option is the same as shackle default value for this option,
            % but there's a global shackle value provided (100):
            ?_assertEqual(100, check(shackle_utils:merge_options([{bounce_interval_secs, infinity}]))),
            ?_assertEqual(ok, application:unset_env(shackle, client)),
            ?_assertEqual(infinity, check(shackle_utils:merge_options([{bounce_interval_secs, infinity}]))),
            ?_assertEqual(10, check(shackle_utils:merge_options(abcdef, []))),
            ?_assertEqual(10, check(shackle_utils:merge_options(abcdef, [{bounce_interval_secs, infinity}])))
        ]
    }.

check({L, _}) ->
    proplists:get_value(bounce_interval_secs, L, undefined).

-endif.