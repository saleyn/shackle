-module(shackle_observe_span).

-behaviour(shackle_observe_dispatcher).

-doc """
Observability dispatcher used when a backend is configured.
Each function wraps the operation in `shackle_observe:span/3`, emitting start/stop events.
Returned by `shackle_observe:dispatcher/0` when `enabled/0` is true.
""".

-export([
    call/3,
    cast/3,
    connect/3,
    timeout/3,
    error/3
]).

-spec call(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
call(PoolName, ClientName, Fun) ->
    shackle_observe:span([call], #{pool => PoolName, client => ClientName}, Fun).

-spec cast(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
cast(PoolName, ClientName, Fun) ->
    shackle_observe:span([cast], #{pool => PoolName, client => ClientName}, Fun).

-spec connect(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
connect(PoolName, ClientName, Fun) ->
    shackle_observe:span([connect], #{pool => PoolName, client => ClientName}, Fun).

-spec timeout(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
timeout(PoolName, ClientName, Fun) ->
    shackle_observe:span([timeout], #{pool => PoolName, client => ClientName}, Fun).

-spec error(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
error(PoolName, ClientName, Fun) ->
    shackle_observe:span([error], #{pool => PoolName, client => ClientName}, Fun).
