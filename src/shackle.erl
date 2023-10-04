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

%% types
-type batch_ref() :: undefined | reference().
-type batch_state() :: {batch_ref(), pos_integer(), [{request_ref(), term()}]}.
-type cast() :: #cast {}.
-type client() :: module().
-type external_request_id() :: term().
-type inet_address() :: inet:ip_address() | inet:hostname().
-type inet_port() :: inet:port_number().
-type protocol() :: shackle_ssl| shackle_tcp | shackle_udp.
-type request_id() :: {shackle_server:name(), reference()}.
-type request_ref() :: reference().
-type reply() :: term().
-type response() :: {external_request_id(), term()}.
-type socket() :: inet:socket() | ssl:sslsocket().
-type socket_option() :: gen_tcp:connect_option() | gen_udp:option() | ssl:tls_client_option().
-type socket_options() :: [socket_option()].
-type table() :: atom().
-type time() :: pos_integer().
-type metric_type() :: counter | timing.
-type metric_key() :: iodata().
-type metric_value() :: integer().

-export_type([
    batch_ref/0,
    batch_state/0,
    cast/0,
    client/0,
    external_request_id/0,
    inet_address/0,
    inet_port/0,
    metric_type/0,
    metric_key/0,
    metric_value/0,
    protocol/0,
    request_id/0,
    request_ref/0,
    reply/0,
    response/0,
    socket/0,
    socket_options/0,
    table/0,
    time/0
]).

-type request() :: term().

%% public
%% @doc Processes a list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>PoolName</dt><dd>The name of connection pool</dd>
%% <dt>Requests</dt><dd>The list of requests</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec batch_call(shackle_pool:name(), [term()]) ->
    [term()] | {error, term()}.
batch_call(_, []) ->
    [];
batch_call(PoolName, [_|_] = Requests) ->
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
-spec batch_call(atom(), [term()], infinity | timeout()) ->
    [term() | {error, term()}].
batch_call(_, [], _) ->
    [];
batch_call(PoolName, [_|_] = Requests, Timeout) ->
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
-spec batch_call_expect_ordered_replies(atom(), [request()]) ->
    [reply() | {error, term()} | {ok, no_reply}].
batch_call_expect_ordered_replies(_, []) ->
    [];
batch_call_expect_ordered_replies(PoolName, [_|_] = Requests) ->
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
-spec batch_call_expect_ordered_replies(
        atom(), [request()], infinity | timeout()) ->
    [reply() | {error, term()} | {ok, no_reply}].
batch_call_expect_ordered_replies(_, [], _) ->
    [];
batch_call_expect_ordered_replies(PoolName, [_|_] = Requests, Timeout) ->
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
-spec batch_cast(shackle_pool:name(), [term()]) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(_, []) ->
    {error, empty};
batch_cast(PoolName, [_|_] = Requests) ->
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
-spec batch_cast(shackle_pool:name(), [term()], undefined | pid()) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(_, [], _) ->
    {error, empty};
batch_cast(PoolName, [_|_] = Requests, Pid) ->
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
-spec batch_cast(
        shackle_pool:name(), [request()], undefined | pid(), infinity | timeout()) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(_, [], _, _) ->
    {error, empty};
batch_cast(PoolName, [_|_] = Requests, Pid, Timeout) ->
    Timestamp = os:timestamp(),
    Count = length(Requests),
    case shackle_pool:server(PoolName, Count) of
        {ok, Client, Server, ReleaseFun} ->
            BatchRef = make_ref(),
            CastsRequestRefs = [begin
                #cast{ request_id = {_, RequestRef}} = Cast =
                    mk_cast(BatchRef, Client, Server, Pid, Timestamp, Timeout),
                {Cast, {RequestRef, Request}}
            end || Request <- Requests],
            {Casts, RequestRefs} = lists:unzip(CastsRequestRefs),
            prometheus_counter:inc(
                shackle_cast_total, [Client, PoolName], Count),
            Server ! {Count, Requests, Casts, ReleaseFun},
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
-spec call(shackle_pool:name(), term()) ->
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
-spec call(atom(), term(), infinity | timeout()) ->
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
-spec cast(shackle_pool:name(), term()) ->
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
-spec cast(shackle_pool:name(), term(), undefined | pid()) ->
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
-spec cast(shackle_pool:name(), term(), undefined | pid(), infinity | timeout()) ->
    {ok, request_id()} | {error, atom()}.
cast(PoolName, Request, Pid, Timeout) ->
    Timestamp = os:timestamp(),
    case shackle_pool:server(PoolName) of
        {ok, Client, Server, ReleaseFun} ->
            Cast = mk_cast(Client, Server, Pid, Timestamp, Timeout),
            prometheus_counter:inc(shackle_cast_total, [Client, PoolName]),
            Server ! {Request, Cast, ReleaseFun},
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
    [Response] = receive_batch_response({BatchRef, 1, RequestRefs}),
    ProcessedResponse =
        process_ordered_response(Response, RequestRefs, {0, []}),
    {BatchState2, Acc2} =
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
