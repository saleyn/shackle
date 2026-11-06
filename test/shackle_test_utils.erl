-module(shackle_test_utils).

-export([
    preload_modules/0,
    with_prometheus/0,
    with_prometheus/1,
    cleanup_mocks/1
]).

%% public
preload_modules() ->
    Filenames = filelib:wildcard("_build/default/lib/*/ebin/*.beam"),
    Rootnames = [filename:rootname(Filename, ".beam") || Filename <- Filenames],
    lists:foreach(fun code:load_abs/1, Rootnames).

with_prometheus(CleanupEnv) when is_list(CleanupEnv) ->
    List = lists:map(fun
        ({App, Key, undefined}) -> fun() -> application:unset_env(App, Key) end;
        ({App, Key, OldVal})    -> fun() -> application:set_env(App, Key, OldVal) end
    end, CleanupEnv),
    List ++ with_prometheus().

with_prometheus() ->
    with_mocks([
        {prometheus_counter, [no_link], [
            {inc,     fun(_)          -> ok end},
            {inc,     fun(_, _)       -> ok end},
            {inc,     fun(_, _, _)    -> ok end},
            {inc,     fun(_, _, _, _) -> ok end},
            {declare, fun(_)          -> ok end}
        ]},
        {prometheus_gauge, [no_link], [
            {declare, fun(_)          -> ok end},
            {set,     fun(_, _)       -> ok end},
            {set,     fun(_, _, _)    -> ok end},
            {set,     fun(_, _, _, _) -> ok end},
            {inc,     fun(_)          -> ok end},
            {inc,     fun(_, _)       -> ok end},
            {inc,     fun(_, _, _)    -> ok end},
            {inc,     fun(_, _, _, _) -> ok end}
        ]},
        {prometheus_histogram, [no_link], [
            {declare, fun(_)          -> ok end},
            {observe, fun(_, _)       -> ok end},
            {observe, fun(_, _, _)    -> ok end}
        ]},
        {prometheus_summary, [no_link], [{declare, fun(_) -> ok end}]}
    ]).

%% @doc Cleanup mocks.
%%
%% This function maybe called to cleanup prometheus mocks passing the
%% output of `with_prometheus/0'.
cleanup_mocks(Cleanups) when is_list(Cleanups) ->
    [F() || F <- Cleanups],
    ok.

%%%-----------------------------------------------------------------------------
%%% Private functions
%%%-----------------------------------------------------------------------------

-type mock_fun_spec() :: function() | meck:func_clause_spec().

-spec with_mock(atom(), [atom()], [{atom(), mock_fun_spec()}]) -> fun(() -> any()).
with_mock(Module, Options, Replacements) when
    is_atom(Module), is_list(Options), is_list(Replacements)
->
    application:ensure_all_started(meck),
    Unload =
        try
            ok = meck:new(Module, Options),
            true
        catch
            error:{already_started, _} ->
                false;
            _ ->
                false
        end,
    [ok = meck:expect(Module, F, ReplFun) || {F, ReplFun} <- Replacements],
    fun() -> case Unload of true -> try meck:unload(Module) catch _:_ -> ok end; false -> ok end end.

-spec with_mocks([{atom(), list(), list()} | {atom(), list()} | atom()]) -> [fun(() -> any())].
with_mocks(Mocks) when is_list(Mocks) ->
    lists:flatten([with_mock(Mod, Opts, Replacements) || {Mod, Opts, Replacements} <- Mocks]).