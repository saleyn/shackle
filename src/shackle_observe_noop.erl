-module(shackle_observe_noop).

-behaviour(shackle_observe_dispatcher).

-doc """
No-op observability dispatcher used when no backend is configured.
Each function calls through directly without any span wrapping or event emission.
Returned by `shackle_observe:dispatcher/0` when `enabled/0` is false.
""".

-export([
    call/3,
    cast/3,
    connect/3,
    timeout/3,
    error/3
]).

-spec call(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
call(_PoolName, _ClientName, Fun) ->
    Fun().

-spec cast(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
cast(_PoolName, _ClientName, Fun) ->
    Fun().

-spec connect(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
connect(_PoolName, _ClientName, Fun) ->
    Fun().

-spec timeout(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
timeout(_PoolName, _ClientName, Fun) ->
    Fun().

-spec error(atom(), atom(), fun(() -> Result)) -> Result when Result :: term().
error(_PoolName, _ClientName, Fun) ->
    Fun().
