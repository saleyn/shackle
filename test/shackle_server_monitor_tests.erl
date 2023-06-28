-module(shackle_server_monitor_tests).

-include_lib("eunit/include/eunit.hrl").

-compile(nowarn_export_all).
-compile(export_all).

-define(AN_INTERVAL, 50).
-define(A_NAME, name).
-define(A_BACKLOG_SIZE, 128).
-define(TIMEOUT, 500).
-define(A_TABLE_NAME, a_table).

shackle_server_monitor_test_() ->
    {setup,
        fun() ->
            meck:new(shackle_queue),
            meck:new(shackle_backlog),
            meck:expect(shackle_backlog, size, [{['_', '_'], 10}]),
            meck:expect(shackle_backlog, table_name, [{['_'], ?A_TABLE_NAME}]),
            meck:expect(shackle_queue, table_name, [{['_'], ?A_TABLE_NAME}]),
            meck:expect(shackle_queue, pending, [{['_', '_'], []}]),
            application:set_env(shackle, monitoring_interval, ?AN_INTERVAL)
        end,
        fun(_) ->
            meck:unload()
        end,
        [
            fun should_reset_backlog_once_it_is_abnormal/0
        ]}.

%%%===================================================================
%%% Test cases
%%%===================================================================

should_reset_backlog_once_it_is_abnormal() ->
    {ok, Pid} = shackle_server_monitor:start_link(
        ?A_NAME,
        {?A_NAME, [{self(), 1}, {self(), 2}], ?A_BACKLOG_SIZE}
    ),
    unlink(Pid),
    meck:expect(shackle_backlog, size, [{['_', '_'], ?A_BACKLOG_SIZE}]),

    assert_message(fun(Message) -> ?assertEqual(reset, Message) end),

    exit(Pid, normal).

%%%===================================================================
%%% Internal functions
%%%===================================================================

assert_message(Assert) ->
    receive
        Message ->
            Assert(Message)
    after ?TIMEOUT -> throw(message_timeout)
    end.
