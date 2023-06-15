-module(shackle).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

%% public
-export([
    batch_call/2,
    batch_call/3,
    batch_cast/2,
    batch_cast/3,
    batch_cast/4,
    call/2,
    call/3,
    cast/2,
    cast/3,
    cast/4,
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
        {ok, BatchState} ->
            receive_batch_response(BatchState);
        {error, Reason} ->
            {error, Reason}
    end.

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
-spec batch_cast(pool_name(), [term()], undefined | pid(), timeout()) ->
    {ok, batch_state()} | {error, atom()}.
batch_cast(PoolName, Requests, Pid, Timeout) ->
    Timestamp = os:timestamp(),
    case shackle_pool:server(PoolName) of
        {ok, Client, Server} ->
            BatchRef = make_ref(),
            {Casts, Count} = lists:mapfoldl(
                fun(_, Acc) ->
                    {mk_cast(BatchRef, Client, Server, Pid, Timestamp, Timeout),
                        Acc+1}
                end,
                0, Requests
            ),
            prometheus_counter:inc(
                shackle_cast_total, [Client, PoolName], Count),
            Server ! {Count, Requests, Casts},
            {ok, {BatchRef, Count}};
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

%% @doc Receive response for the list of requests.<p />
%% Parameters:
%% <dl>
%% <dt>BatchState</dt><dd>The state of the list of requests being processed</dd>
%% </dl>
%%  Returns:
%% <dl><dt></dt><dd>A list of replies</dd></dl>
-spec receive_batch_response(batch_state()) ->
    [term() | {error, term()}].
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
    term() | {error, term()}.
receive_response(RequestId) ->
    receive
        {#cast {request_id = RequestId}, Reply} ->
            Reply
    end.

%% private
receive_batch_response({_BatchRef, 0}, Acc) ->
    lists:reverse(Acc);
receive_batch_response({BatchRef, Count}, Acc) ->
    receive
        {#cast {batch_ref = BatchRef}, Reply} ->
            receive_batch_response({BatchRef, Count-1}, [Reply|Acc])
    end.

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
