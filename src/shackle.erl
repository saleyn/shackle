-module(shackle).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

%% public
-export([
    batch_call/2,
    batch_call/3,
    batch_call_expect_ordered_replies/2,
    batch_call_expect_ordered_replies/3,
    batch_cast/2,
    batch_cast/3,
    batch_cast/4,
    call/2,
    call/3,
    cast/2,
    cast/3,
    cast/4,
    receive_batch_expect_ordered_replies/1,
    receive_batch_response/1,
    receive_response/1
]).

%% public
%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec batch_call(pool_name(), [term()]) ->
    [term()] | {error, term()}.
batch_call(PoolName, Requests) ->
    batch_call(PoolName, Requests, ?DEFAULT_TIMEOUT).

%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% <dt>Timeout</dt><dd>The time period allocated to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec batch_call(atom(), [term()], timeout()) ->
    [term() | {error, term()}].
batch_call(PoolName, Requests, Timeout) ->
    case batch_cast(PoolName, Requests, self(), Timeout) of
        {ok, {_BatchRef, _Count, RequestRefs} = BatchState} ->
            Replies = receive_batch_response(BatchState),
            lists:map(fun ({RequestRef, _Request}) ->
                    proplists:get_value(RequestRef, Replies, {error, no_reply})
                end, RequestRefs);
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Processes a list of requests.<br />
%% Assumes that replies arrives in the order of submitted requests.<br />
%% Allows requests that do not return replies.<br />
%% For the requests that do not return replies
%% '{ok, no_reply}' is returned.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec batch_call_expect_ordered_replies(atom(), [term()]) ->
    [term() | {error, term()} | {ok, no_reply}].
batch_call_expect_ordered_replies(PoolName, Requests) ->
    batch_call_expect_ordered_replies(PoolName, Requests, ?DEFAULT_TIMEOUT).

%% @doc Processes a list of requests.<br />
%% Assumes that replies arrives in the order of submitted requests.<br />
%% Allows requests that do not return replies.<br />
%% For the requests that do not return replies
%% '{ok, no_reply}' is returned.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% <dt>Timeout</dt><dd>The time period allocated to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec batch_call_expect_ordered_replies(atom(), [term()], timeout()) ->
    [term() | {error, term()} | {ok, no_reply}].
batch_call_expect_ordered_replies(PoolName, Requests, Timeout) ->
    {ok, BatchState} = batch_cast(PoolName, Requests, self(), Timeout),
    receive_batch_expect_ordered_replies(BatchState).

%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The state of the list of requests being processed</dd></dl>
-spec batch_cast(pool_name(), [term()]) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(PoolName, Requests) ->
    batch_cast(PoolName, Requests, self()).

%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% <dt>Pid</dt><dd>The process identifier to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The state of the list of requests being processed</dd></dl>
-spec batch_cast(pool_name(), [term()], undefined | pid()) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(PoolName, Requests, Pid) ->
    batch_cast(PoolName, Requests, Pid, ?DEFAULT_TIMEOUT).

%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% <dt>Pid</dt><dd>The process identifier to process the requests</dd>
%% <dt>Timeout</dt><dd>The time period allocated to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The state of the list of requests being processed</dd></dl>
-spec batch_cast(pool_name(), [request()], undefined | pid(), timeout()) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(PoolName, Requests, Pid, Timeout) ->
    Timestamp = os:timestamp(),
    case shackle_pool:server(PoolName) of
        {ok, Client, Server} ->
            BatchRef = make_ref(),
            {CastsRequestRefs, Count} = lists:mapfoldl(
                fun(X, Acc) ->
                    #cast{ request_id = {_, RequestRef}} = Cast =
                        mk_cast(BatchRef, Client, Server, Pid,
                            Timestamp, Timeout),
                    {{Cast, {RequestRef, X}}, Acc+1}
                end,
                0, Requests
            ),
            {Casts, RequestRefs} = lists:unzip(CastsRequestRefs),
            prometheus_counter:inc(
                shackle_cast_total, [Client, PoolName], Count),
            Server ! {Count, Requests, Casts},
            {ok, {BatchRef, Count, RequestRefs}};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Processes a request.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Request</dt><dd>The request to process</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A reply</dd></dl>
-spec call(pool_name(), term()) ->
    term() | {error, term()}.
call(PoolName, Request) ->
    call(PoolName, Request, ?DEFAULT_TIMEOUT).

%% @doc Processes a request.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Request</dt><dd>The request to process</dd>
%% <dt>Timeout</dt><dd>The time period allocated to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A reply</dd></dl>
-spec call(atom(), term(), timeout()) ->
    term() | {error, atom()}.
call(PoolName, Request, Timeout) ->
    case cast(PoolName, Request, self(), Timeout) of
        {ok, RequestId} ->
            receive_response(RequestId);
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Processes a request.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Request</dt><dd>The request to process</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The request ID of the request being processed</dd></dl>
-spec cast(pool_name(), term()) ->
    {ok, request_id()} | {error, atom()}.
cast(PoolName, Request) ->
    cast(PoolName, Request, self()).

%% @doc Processes a request.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Request</dt><dd>The request to process</dd>
%% <dt>Pid</dt><dd>The process identifier to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The request ID of the request being processed</dd></dl>
-spec cast(pool_name(), term(), undefined | pid()) ->
    {ok, request_id()} | {error, atom()}.
cast(PoolName, Request, Pid) ->
    cast(PoolName, Request, Pid, ?DEFAULT_TIMEOUT).

%% @doc Processes a request.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Request</dt><dd>The request to process</dd>
%% <dt>Pid</dt><dd>The process identifier to process the requests</dd>
%% <dt>Timeout</dt><dd>The time period allocated to process the requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>The request ID of the request being processed</dd></dl>
-spec cast(pool_name(), term(), undefined | pid(), timeout()) ->
    {ok, request_id()} | {error, atom()}.
cast(PoolName, Request, Pid, Timeout) ->
    Timestamp = os:timestamp(),
    case shackle_pool:server(PoolName) of
        {ok, Client, Server} ->
            Cast = mk_cast(Client, Server, Pid, Timestamp, Timeout),
            prometheus_counter:inc(shackle_cast_total, [Client, PoolName]),
            Server ! {Request, Cast},
            RequestId = Cast#cast.request_id,
            {ok, RequestId};
        {error, Reason} ->
            {error, Reason}
    end.

%% @doc Receive response for the list of requests.<br />
%% Assumes that replies arrives in the order of submitted requests.<br />
%% Allows requests that do not return replies.<br />
%% For the requests that do not return replies
%% '{ok, no_reply}' is returned.<p />
%% Parameters:
%% <dl>
%% <dt>BatchState</dt><dd>The state of the list of requests being processed</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec receive_batch_expect_ordered_replies(batch_state()) ->
    [reply() | {ok, no_reply} | {error, term()}].
receive_batch_expect_ordered_replies(BatchState) ->
    receive_batch_expect_ordered_replies(BatchState, []).

%% @doc Receive response for the list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>BatchState</dt><dd>The state of the list of requests being processed</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec receive_batch_response(batch_state()) ->
    [{request_ref(), reply()} | {error, term()}].
receive_batch_response(BatchState) ->
    receive_batch_response(BatchState, []).

%% @doc Receive response for the list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>RequestId</dt><dd>The request ID of the request being processed</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A reply</dd></dl>
-spec receive_response(request_id()) ->
    reply() | {error, term()}.
receive_response(RequestId) ->
    receive
        {#cast {request_id = RequestId}, Reply} ->
            Reply
    end.

%% private
receive_batch_response({_BatchRef, 0, _RequestRefs}, Acc) ->
    lists:reverse(Acc);
receive_batch_response({BatchRef, Count, RequestRefs}, Acc) ->
    receive
        {#cast {batch_ref = BatchRef, request_id = {_, RequestRef}}, Reply} ->
            receive_batch_response({BatchRef, Count-1, RequestRefs},
                [{RequestRef, Reply}|Acc])
    end.

receive_batch_expect_ordered_replies({_BatchRef, Count, _RequestRefs}, Acc)
    when Count =< 0 ->
    lists:foldl(fun({_RequestRef, {_Request, Reply}}, ReplyAcc) ->
        [Reply|ReplyAcc] end, [], Acc);
receive_batch_expect_ordered_replies(
    {BatchRef, _Count, RequestRefs} = BatchState, Acc) ->
    [{Ref, Reply}] = receive_batch_response({BatchRef, 1, RequestRefs}),
    ProcessedResponse =
        process_ordered_response({Ref, Reply}, RequestRefs, {0, []}),
    {{BatchRef, _Count2, _RequestRefs2} = BatchState2, Acc2} =
        handle_ordered_response(ProcessedResponse, BatchState, Acc),
    receive_batch_expect_ordered_replies(BatchState2, Acc2).

process_ordered_response({_RequestRef, _Reply}, [] = _RequestRefReplyPairs,
    {_Count, _Acc}) ->
    %% The case when RequestRef in {RequestRef, Reply}
    %% is not associated with any {RequestRef, Request}.
    {0, [], []};
process_ordered_response({RequestRef, Reply}, [{RequestRef, Request}|T],
    {Count, Acc}) ->
    {Count+1, [{RequestRef, {Request, Reply}}|Acc], T};
process_ordered_response(Ref, [{RequestRef, Request}|T], {Count, Acc}) ->
    process_ordered_response(Ref, T,
        {Count+1, [{RequestRef, {Request, {ok, no_reply}}}|Acc]}).

handle_ordered_response({ResponseCount, _, _}, BatchState, Acc)
    when ResponseCount =< 0 ->
    {BatchState, Acc};
handle_ordered_response(_, {_, Count, _} = BatchState, Acc) when Count =< 0 ->
    {BatchState, Acc};
handle_ordered_response({ResponseCount, ResponseAcc, RequestRefsTail},
    {BatchRef, Count, _RequestRefs} = _BatchState, Acc) ->
    {{BatchRef, Count-ResponseCount, RequestRefsTail},
        lists:append([ResponseAcc, Acc])}.

%% utils
mk_cast(Client, Server, Pid, Timestamp, Timeout) ->
    mk_cast(undefined, Client, Server, Pid, Timestamp, Timeout).

mk_cast(BatchRef, Client, Server, Pid, Timestamp, Timeout) ->
    #cast {
        client = Client,
        pid = Pid,
        batch_ref = BatchRef,
        request_id = {Server, make_ref()},
        timeout = Timeout,
        timestamp = Timestamp
    }.
