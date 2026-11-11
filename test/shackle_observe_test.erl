-module(shackle_observe_test).

-include_lib("eunit/include/eunit.hrl").

%%% Tests

disabled_by_default_test() ->
    % When no backend is configured, observability should be disabled
    ?assertEqual(false, shackle_observe:enabled()).

backends_exist_test() ->
    % Verify backend modules exist
    ?assert(code:is_loaded(shackle_observe_telemetry) =/= false
            orelse code:ensure_loaded(shackle_observe_telemetry) == {module, shackle_observe_telemetry}),
    ?assert(code:is_loaded(shackle_observe_prometheus) =/= false
            orelse code:ensure_loaded(shackle_observe_prometheus) == {module, shackle_observe_prometheus}).
