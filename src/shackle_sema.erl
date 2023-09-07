-module(shackle_sema).
-include("shackle.hrl").

-export([
    acquire/1,
    acquire/2,
    acquire_n/2,
    acquire_n/3,
    delete/1,
    new/3
]).

-spec new(pool_name(), pos_integer(), pos_integer()) ->
    ok.

new(_PoolName, _PoolSize, infinity) ->
    ok;
new(PoolName, PoolSize, BacklogSize) ->
    SemaList = [sema_nif:create(BacklogSize) || _ <- lists:seq(1, PoolSize)],
    persistent_term:put({sema, PoolName}, list_to_tuple(SemaList)).

-spec acquire(server_id()) -> {ok, release_fun()} | error.

acquire(ServerId) -> acquire_n(ServerId, 1).

-spec acquire_n(server_id(), pos_integer()) -> {ok, release_fun()} | error.

acquire_n({PoolName, ServerIdx}, Count) ->
    Sema = element(ServerIdx, persistent_term:get({sema, PoolName})),
    case sema_nif:occupy(Sema, Count) of
        {ok, _} ->
            Pid = self(),
            {ok, fun (Cnt) -> sema_nif:vacate(Sema, Cnt, Pid) end};
        {error, backlog_full} ->
            error
    end.

-spec acquire(pool_name(), server_index()) -> {ok, release_fun()} | error.

acquire(PoolName, ServerIdx) -> acquire_n(PoolName, ServerIdx, 1).

-spec acquire_n(pool_name(), server_index(), pos_integer()) ->
    {ok, release_fun()} | error.

acquire_n(PoolName, ServerIdx, Count) ->
    Sema = element(ServerIdx, persistent_term:get({sema, PoolName})),
    case sema_nif:occupy(Sema, Count) of
        {ok, _} ->
            Pid = self(),
            {ok, fun (Cnt) -> sema_nif:vacate(Sema, Cnt, Pid) end};
        {error, backlog_full} ->
            error
    end.

-spec delete(pool_name()) ->
    ok.

delete(PoolName) ->
    persistent_term:erase(PoolName),
    ok.
