-module(shackle_sema).

-export([
    acquire/1,
    acquire/2,
    acquire/3,
    release/2,
    delete/1,
    new/3,
    count/2,
    count/1
]).

-compile({inline, [acquire/1, acquire/2, acquire/3, release/2]}).

-type sema_ref() :: sema_nif:sema_ref().

-export_type([sema_ref/0]).

-spec new(shackle_pool:name(), pos_integer(), pos_integer()) ->
    ok.

new(_PoolName, _PoolSize, infinity) ->
    ok;
new(PoolName, PoolSize, BacklogSize) ->
    SemaList = [sema_nif:create(BacklogSize) || _ <- lists:seq(1, PoolSize)],
    persistent_term:put({sema, PoolName}, list_to_tuple(SemaList)).

-spec acquire(shackle_server:id()) -> {ok, sema_ref()} | error.
acquire({PoolName, ServerIdx}) ->
    acquire(PoolName, ServerIdx, 1).

-spec acquire(shackle_pool:name(), shackle_server:index()) -> {ok, sema_ref()} | error.
acquire(PoolName, ServerIdx) ->
    acquire(PoolName, ServerIdx, 1).

-spec acquire(shackle_pool:name(), shackle_server:index(), pos_integer()) ->
    {ok, sema_ref()} | error.

acquire(PoolName, ServerIdx, Count) ->
    Sema = element(ServerIdx, persistent_term:get({sema, PoolName})),
    case sema_nif:acquire(Sema, Count) of
        {ok, _} ->
            {ok, Sema};
        {error, full} ->
            error
    end.

-spec release(sema_ref()|undefined, pid()) -> ok.
%% When backlog_size is infinity, `Sema' is `undefined' - there's nothing to do.
release(undefined, _Pid) ->
    ok;
release(Sema, Pid) when is_reference(Sema) ->
    sema_nif:release(Sema, 1, Pid),
    ok.

-doc "Return the size of current backlog".
-spec count({shackle_pool:name(), non_neg_integer()}) -> non_neg_integer().
count({PoolName, ServerIdx}) ->
    count(PoolName, ServerIdx).

-doc "Return the size of current backlog".
-spec count(shackle_pool:name(), non_neg_integer()) -> non_neg_integer().
count(PoolName, ServerIdx) ->
    Sema = element(ServerIdx, persistent_term:get({sema, PoolName})),
    #{cnt := Count} = sema_nif:info(Sema),
    Count.

-spec delete(shackle_pool:name()) ->
    ok.

delete(PoolName) ->
    persistent_term:erase(PoolName),
    ok.
