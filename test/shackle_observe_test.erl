-module(shackle_observe_test).

-include_lib("eunit/include/eunit.hrl").

%%% Tests

disabled_by_default_test() ->
    % When no backend is configured, observability should be disabled
    ?assertEqual(false, shackle_observe:enabled()),
    ?assertEqual(shackle_observe_noop, shackle_observe:dispatcher()).

noop_dispatcher_test() ->
    % Noop dispatcher should just call the fun
    Fun = fun() -> result end,
    ?assertEqual(result, shackle_observe_noop:call(test_pool, test_client, Fun)),
    ?assertEqual(result, shackle_observe_noop:cast(test_pool, test_client, Fun)),
    ?assertEqual(result, shackle_observe_noop:connect(test_pool, test_client, Fun)),
    ?assertEqual(result, shackle_observe_noop:timeout(test_pool, test_client, Fun)),
    ?assertEqual(result, shackle_observe_noop:error(test_pool, test_client, Fun)).

span_dispatcher_test() ->
    % Span dispatcher should call span/3
    % This test just verifies the span dispatcher exists and has the right signature
    Module = shackle_observe_span,
    code:ensure_loaded(Module),
    ?assert(erlang:function_exported(Module, call, 3)),
    ?assert(erlang:function_exported(Module, cast, 3)),
    ?assert(erlang:function_exported(Module, connect, 3)),
    ?assert(erlang:function_exported(Module, timeout, 3)),
    ?assert(erlang:function_exported(Module, error, 3)).

backends_exist_test() ->
    % Verify backend modules exist
    ?assert(code:is_loaded(shackle_observe_telemetry) =/= false
            orelse code:ensure_loaded(shackle_observe_telemetry) == {module, shackle_observe_telemetry}),
    ?assert(code:is_loaded(shackle_observe_prometheus) =/= false
            orelse code:ensure_loaded(shackle_observe_prometheus) == {module, shackle_observe_prometheus}).
