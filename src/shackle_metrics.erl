-module(shackle_metrics).

-export([init/1, increment/2, increment/3, timing_microseconds/3]).
-export([
    generate_counters/1,
    generate_timing_gauges/1,
    generate_specs/1,
    generate_name/1,
    generate_help/1,
    normalize_name/1,
    join_binaries/2
]).

-define(COUNTERS, [
    backlog_full,
    disabled,
    connect,
    cast,
    request,
    response,
    response_found,
    response_not_found,
    reply,
    timeout,
    no_server,
    no_socket,
    send_error,
    handle_request_error,
    handle_timeout_error,
    client_connect_error,
    socket_connect_error,
    socket_error,
    connection_closed,
    received_messages,
    received_bytes
]).

-define(TIMINGS, [
    reply
]).

-type pool_name() :: atom().


-spec increment(pool_name(), atom()) -> ok.
increment(PoolName, Metric) ->
    prometheus_counter:inc(generate_name([PoolName, Metric, total])).


-spec increment(pool_name(), atom(), integer()) -> ok.
increment(PoolName, Metric, Value) ->
    prometheus_counter:inc(generate_name([PoolName, Metric, total]), Value).


-spec timing_microseconds(pool_name(), atom(), integer()) -> ok.
timing_microseconds(PoolName, Metric, Value) ->
    prometheus_gauge:set(generate_name([PoolName, Metric, time, microseconds]),
                         Value).


-spec init(pool_name()) -> ok.
init(PoolName) ->
    lists:map(fun prometheus_counter:declare/1, generate_counters(PoolName)),
    lists:map(fun prometheus_gauge:declare/1, generate_timing_gauges(PoolName)),
    ok.


-spec generate_counters(PoolName :: atom()) ->
    list(prometheus_metric_spec:spec()).
generate_counters(PoolName) ->
    generate_specs([[PoolName, C, total] || C <- ?COUNTERS]).


-spec generate_timing_gauges(PoolName :: atom()) ->
    list(prometheus_metric_spec:spec()).
generate_timing_gauges(PoolName) ->
    generate_specs([[PoolName, T, time, microseconds] || T <- ?TIMINGS]).


-spec generate_specs(list(list(atom()))) ->
    list(prometheus_metric_spec:spec()).
generate_specs(Names) ->
    [[{name, generate_name(N)}, {help, generate_help(N)}] || N <- Names].


-spec generate_name(list(atom())) -> atom().
generate_name(Parts) ->
    Tokens0 = lists:map(fun atom_to_binary/1, Parts),
    Tokens1 = lists:map(fun normalize_name/1, Tokens0),
    erlang:binary_to_atom(join_binaries(Tokens1, <<"_">>), utf8).


-spec generate_help(list(atom())) -> binary().
generate_help(Tokens) ->
    join_binaries(lists:map(fun atom_to_binary/1, Tokens), <<" ">>).


-spec normalize_name(binary()) -> binary().
normalize_name(Name) ->
    binary:replace(Name, <<".">>, <<"_">>, [global]).


-spec join_binaries(BinList :: list(binary()), JoinWith :: binary()) ->
    binary().
join_binaries([], _) ->
    <<"">>;
join_binaries([S], _) ->
    S;
join_binaries([S0, S1|R], J) ->
    join_binaries([<<S0/binary, J/binary, S1/binary>>|R], J).


-spec atom_to_binary(atom()) -> binary().
atom_to_binary(A) ->
    erlang:atom_to_binary(A, utf8).
