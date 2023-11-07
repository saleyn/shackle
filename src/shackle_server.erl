%% @doc A process handling a pool of client connections to a server.
%%
%% Configuration options:
%% <du>
%% <dt>init_options</dt>
%%  <dd>Options passed to the client in the `init/3' callback.</dd>
%% <dt>address</dt><dd>IP address of the server's endpoint to connect to.</dd>
%% <dt>port</dt><dd>Server port to connect to.</dd>
%% <dt>protocol</dt>
%%  <dd>Connection protocol `shackle_ssl | shackle_tcp | shackle_udp'
%%      (default: `shackle_tcp').</dd>
%% <dt>reconnect</dt>
%%  <dd>When true (default), automatically reconnect upon a disconnect.</dd>
%% <dt>reconnect_time_min</dt>
%%  <dd>Min reconnect time in milliseconds (default: `500').</dd>
%% <dt>reconnect_time_max</dt>
%%  <dd>Max reconnect time in milliseconds (default: `120000').</dd>
%% <dt>socket_options</dt><dd>Options passed to the socket (default: `[]')</dd>
%% <dt>bounce_interval_secs</dt>
%%  <dd>Interval in seconds when a connection must be forcefully bounced.
%%      Defaults to `infinity', which disables the bouncing feature. A
%%      bounce is done on one connection at a time.</dd>
%% <dt>on_bounce_event</dt>
%%  <dd>A callback function called on various events related to connection
%%      bouncing.</dd>
%% </du>
-module(shackle_server).
-include("shackle_internal.hrl").

-compile(inline).
-compile({inline_size, 512}).

-export([
    start_link/2,
    state/2,
    bounce/2
]).

-behaviour(metal).
-export([
    init/3,
    handle_msg/2,
    terminate/2
]).

-ifndef(NO_BOUNCE_EVENT).
-define(ON_BOUNCE_EVENT(State, Event),
    (is_function(State#state.on_bounce_event, 3) andalso
        (State#state.on_bounce_event)(
            element(1, State#state.id), element(2, State#state.id), Event))).
-else.
-define(ON_BOUNCE_EVENT(_State, _Event), ok).
-endif.

-record(state, {
    address          :: shackle:inet_address(),
    client           :: shackle:client(),
    id               :: id(),
    srv_idx          :: binary(),
    init_options     :: init_options(),
    name             :: name(),
    parent           :: pid(),
    pool_name        :: shackle_pool:name(),
    port             :: shackle:inet_port(),
    protocol         :: shackle:protocol(),
    queue            :: shackle:table(),
    reconnect_state  :: undefined | reconnect_state(),
    socket           :: undefined | shackle:socket(),
    socket_options   :: shackle:socket_options(),
    bounce_interval  :: infinity  | pos_integer(),  %% # of ms for conn bounce
    bounce_state     :: waiting   |                 %% Waiting for next bounce
                        draining  |                 %% Draining request queue
                        reconnecting |              %% Reconnecting to server
                        disconnected,               %% Disconnected from server
    on_bounce_event  :: undefined | function(),
    next_bounce      :: undefined | pos_integer(),  %% Epoch timestamp when to close connection
    timer_ref        :: undefined | reference()
}).

-type state() :: #state {}.
-type client_state() :: term().
-type init_options() :: term().
-type id() :: {shackle_pool:name(), index()}.
-type index() :: pos_integer().
-type name() :: atom().
-type opts() :: {shackle_pool:name(), index(), shackle:client(), shackle_client:options()}.
-type reconnect_state() :: #reconnect_state{}.

-export_type([
    id/0,
    index/0,
    init_options/0,
    name/0,
    reconnect_state/0
]).

%% public
-spec start_link(name(), opts()) ->
    {ok, pid()}.

start_link(Name, Opts) ->
    metal:start_link(?MODULE, Name, Opts).

-spec state(shackle_pool:name(), pos_integer()) ->
    {ok, #{connection_state => map(), handler_state => any()}} | {error, noproc}.
state(PoolName, SrvIdx) ->
    SrvName = shackle_pool:server_name(PoolName, SrvIdx),
    try sys:get_state(SrvName) of
        {?MODULE, _SrvName, _Pid, {State, CliState}} ->
            {ok, #{
                connection_state =>
                    maps:from_list(lists:zip(
                        record_info(fields, state),
                        tl(tuple_to_list(State))
                    )),
                handler_state => CliState}
            }
    catch error:noproc ->
        {error, noproc}
    end.

-spec bounce(shackle_pool:name(), pos_integer()) -> boolean().
bounce(PoolName, SrvIdx) ->
    SrvName = shackle_pool:server_name(PoolName, SrvIdx),
    bounce_connection == catch (SrvName ! bounce_connection).

%% metal callbacks
-spec init(name(), pid(), opts()) ->
    {ok, {state(), term()}}.

init(Name, Parent, Opts) ->
    {PoolName, Index, Client, ServerOpts} = Opts,
    ServerOpts1 = shackle_utils:default_options(client, ServerOpts),

    self() ! ?MSG_CONNECT,
    Id = {PoolName, Index},
    SrvIdxBin = integer_to_binary(Index),
    InitOptions = ?LOOKUP(init_options, ServerOpts1, ?DEFAULT_INIT_OPTS),
    Address = address(ServerOpts1),
    Port = ?LOOKUP(port, ServerOpts1),
    Protocol = ?LOOKUP(protocol, ServerOpts1, ?DEFAULT_PROTOCOL),
    SocketOptions = ?LOOKUP(socket_options, ServerOpts1, ?DEFAULT_SOCKET_OPTS),
    ReconnectState = reconnect_state(ServerOpts1),
    BounceInt =
        case ?LOOKUP(bounce_interval_secs, ServerOpts1, ?DEFAULT_BOUNCE_INTERVAL) of
            I when is_integer(I) ->
                I * 1000;
            infinity = I ->
                I
        end,
    OnBounceEvent =
        case ?LOOKUP(on_bounce_event, ServerOpts1, undefined) of
            undefined ->
                undefined;
            Fun when is_function(Fun, 3) ->
                Fun;
            {M, F} when is_atom(M), is_atom(F) ->
                {module, M} == code:load_file(M)
                    orelse error({cannot_load_module, M}),
                erlang:function_exported(M, F, 3)
                    orelse error({function_not_exported, {M, F, 3}}),
                fun(Event) -> M:F(PoolName, Index, Event) end
        end,

    lists:member(Port, [undefined, 0]) andalso
        erlang:error({missing_port_option, Name, ServerOpts1}),

    {ok, {#state {
        address = Address,
        client = Client,
        id = Id,
        srv_idx = SrvIdxBin,
        init_options = InitOptions,
        name = Name,
        parent = Parent,
        pool_name = PoolName,
        port = Port,
        protocol = Protocol,
        queue = shackle_queue:table_name(PoolName),
        reconnect_state = ReconnectState,
        socket_options = SocketOptions,
        bounce_interval = BounceInt,
        on_bounce_event = OnBounceEvent,
        bounce_state = waiting
    }, undefined}}.

-spec handle_msg(term(), {state(), client_state()}) ->
    {ok, term()}.

handle_msg({request, [Casts | _]}, {#state {socket = undefined} = S, CliState}) ->
    log_metrics(S, shackle_error_total, <<"no socket">>),
    reply({error, no_socket}, wrap(Casts), S, CliState);

handle_msg({request, [Casts | _]}, {#state{bounce_state = BS} = S, CliState}) when BS /= waiting ->
    %% The server is either in the connection draining state or about to be
    %% bounced - reject the client's request.
    log_metrics(S, shackle_error_total, <<"send rejected">>),
    reply({error, send_rejected}, wrap(Casts), S, CliState);

handle_msg({request, [#cast {timeout = _Timeout} = Cast, Request]},
        {#state{bounce_state = waiting, client = Client} = State, ClientState}) ->
    try Client:handle_request(Request, ClientState) of
        {ok, ExtRequestId, Data, ClientState2} ->
            Protocol = State#state.protocol,
            Socket = State#state.socket,
            case Protocol:send(Socket, Data) of
                ok ->
                    log_metrics(State, shackle_request_total),
                    case ExtRequestId of
                        undefined ->
                            reply(ok, [Cast], State, ClientState2);
                        _ ->
                            Queue = State#state.queue,
                            Id = State#state.id,
                            set_receive_timeout(Queue, Id, ExtRequestId, Cast),
                            {ok, {State, ClientState2}}
                    end;
                {error, Reason} ->
                    Client = State#state.client,
                    PoolName = State#state.pool_name,
                    log_metrics(State, shackle_error_total, <<"send error">>),
                    ?WARN(PoolName, "SrvIdx=~s send error: ~p", [State#state.srv_idx, Reason]),
                    Protocol:close(Socket),
                    {ok, {State3, ClientState3}} =
                        reply({error, socket_closed}, [Cast], State, ClientState2),
                    close(State3, ClientState3)
            end
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            Client = State#state.client,
            PoolName = State#state.pool_name,
            log_metrics(State, shackle_error_total, <<"handle_request error">>),
            ?WARN(PoolName, "handle_request crash: ~p:~p~n  ~p~n",
                [E, R, ?GET_STACK(Stacktrace)]),
            reply({error, client_crash}, [Cast], State, ClientState)
    end;

handle_msg({request, [Casts, Requests, Count]}, {#state {client = Client} = State, ClientState})
    when is_integer(Count), Count >= 0 ->
    try Client:handle_request(Requests, ClientState) of
        {ok, ExtRequestIds, Data, ClientState2} ->
            Protocol = State#state.protocol,
            Socket = State#state.socket,
            case Protocol:send(Socket, Data) of
                ok ->
                    log_metrics(State, shackle_request_total, Count),
                    handle_request_ids_from_client(ExtRequestIds, Casts, State, ClientState),
                    {ok, {State, ClientState2}};
                {error, Reason} ->
                    log_metrics(State, shackle_error_total, <<"send error">>),
                    ?WARN(State#state.pool_name, "SrvIdx=~s send error: ~p",
                        [State#state.srv_idx, Reason]),
                    Protocol:close(Socket),
                    {ok, {State3, ClientState3}} =
                        reply({error, socket_closed}, Casts, State, ClientState2),
                    close(State3, ClientState3)
            end
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            log_metrics(State, shackle_error_total, <<"handle_request error">>),
            ?WARN(State#state.pool_name, "handle_request crash: ~p:~p~n~p~n",
                [E, R, ?GET_STACK(Stacktrace)]),
                reply({error, client_crash}, Casts, State, ClientState)
    end;

handle_msg({ssl, Socket, Data}, {State, ClientState}) ->
    handle_msg_data(Socket, Data, State, ClientState);
handle_msg({ssl_closed, Socket}, {State, ClientState}) ->
    handle_msg_close(Socket, State, ClientState);
handle_msg({ssl_error, Socket, Reason}, {State, ClientState}) ->
    handle_msg_error(Socket, Reason, State, ClientState);
handle_msg({tcp, Socket, Data}, {State, ClientState}) ->
    handle_msg_data(Socket, Data, State, ClientState);
handle_msg({tcp_closed, Socket}, {State, ClientState}) ->
    handle_msg_close(Socket, State, ClientState);
handle_msg({tcp_error, Socket, Reason}, {State, ClientState}) ->
    handle_msg_error(Socket, Reason, State, ClientState);
handle_msg({udp, Socket, _Ip, _InPortNo, Data}, {State, ClientState}) ->
    handle_msg_data(Socket, Data, State, ClientState);
handle_msg({udp_error, Socket, Reason}, {State, ClientState}) ->
    handle_msg_error(Socket, Reason, State, ClientState);
handle_msg(?MSG_CONNECT, {#state {
        address = Address,
        client = Client,
        id = Id,
        init_options = Init,
        pool_name = PoolName,
        port = Port,
        protocol = Protocol,
        reconnect_state = ReconnectState,
        socket_options = SocketOptions
    } = State, ClientState}) ->
    case connect(Protocol, Address, Port, SocketOptions, PoolName) of
        {ok, Socket} ->
            case client(Client, PoolName, Init, Protocol, Socket) of
                {ok, ClientState2} ->
                    ReconnectState2 = reconnect_state_reset(ReconnectState),
                    log_metrics(State, shackle_connect_total),
                    shackle_status:enable(Id),
                    State1 = schedule_bounce(State#state{
                        reconnect_state = ReconnectState2,
                        socket = Socket,
                        timer_ref = undefined,
                        bounce_state = waiting
                    }),
                    ?ON_BOUNCE_EVENT(State1, #{
                        status => connected,
                        next_bounce => State1#state.next_bounce,
                        bounce_state => State1#state.bounce_state,
                        bounce_interval => State1#state.bounce_interval,
                        src => {?MODULE, ?LINE}
                    }),
                    {ok, {State1, ClientState2}};
                {error, _Reason, ClientState2} ->
                    log_metrics(State, shackle_error_total, <<"client connect error">>),
                    Protocol:close(Socket),
                    reconnect(State#state{socket = undefined}, ClientState2)
            end;
        {error, _Reason} ->
            log_metrics(State, shackle_error_total, <<"socket connect error">>),
            reconnect(State, ClientState)
    end;
handle_msg({timeout, ExtRequestId}, {#state {
        client = Client,
        id = Id,
        pool_name = PoolName,
        protocol = Protocol,
        queue = Queue,
        socket = Socket
    } = State, ClientState}) ->

    log_metrics(State, shackle_error_total, <<"timeout">>),
    case erlang:function_exported(Client, handle_timeout, 2) of
        true ->
            try Client:handle_timeout(ExtRequestId, ClientState) of
                {ok, Reply, ClientState2} ->
                    process_responses([Reply], State, ClientState2);
                {error, Reason, ClientState2} ->
                    log_metrics(State, shackle_error_total, <<"handle_timeout error">>),
                    ?WARN(PoolName, "handle_timeout error: ~p", [Reason]),
                    Protocol:close(Socket),
                    close(State, ClientState2)
            catch
                ?EXCEPTION(E, R, Stacktrace) ->
                    log_metrics(State, shackle_error_total, <<"handle_timeout exception">>),
                    ?WARN(PoolName, "handle_timeout error: ~p:~p~n  ~p~n",
                        [E, R, ?GET_STACK(Stacktrace)]),
                    Protocol:close(Socket),
                    close(State, ClientState)
            end;
        false ->
            case shackle_queue:remove(Queue, Id, ExtRequestId) of
                {ok, Cast, _TimerRef} ->
                    reply({error, timeout}, [Cast], State, ClientState);
                {error, not_found} ->
                    {ok, {State, ClientState}}
            end
    end;
handle_msg(bounce_connection, {State, ClientState}) ->
    bounce_check(State, ClientState);
handle_msg(Msg, {#state{pool_name = PoolName} = State, ClientState}) ->
    ?WARN(PoolName, "unknown msg: ~p", [Msg]),
    {ok, {State, ClientState}}.

-spec terminate(term(), term()) ->
    ok.

terminate(_Reason, {#state {
        client = Client,
        pool_name = PoolName,
        timer_ref = TimerRef
    } = State, ClientState}) ->
    cancel_timer(TimerRef),
    try Client:terminate(ClientState)
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            ?WARN(PoolName, "terminate crash: ~p:~p~n  ~p~n",
                [E, R, ?GET_STACK(Stacktrace)])
    end,
    reply_all({error, shutdown}, State, undefined).

%% private
address(ClientOptions) ->
    case ?LOOKUP(address, ClientOptions) of
        undefined ->
            ?LOOKUP(ip, ClientOptions, ?DEFAULT_ADDRESS);
        Address ->
            Address
    end.

cancel_timer(Ref) when is_reference(Ref) ->
    erlang:cancel_timer(Ref);
cancel_timer(undefined) ->
    ok.

client(Client, PoolName, InitOptions, Protocol, Socket) ->
    case client_init(Client, PoolName, InitOptions) of
        {ok, ClientState} ->
            client_setup(Client, PoolName, Protocol, Socket, ClientState);
        {error, Reason} ->
            {error, Reason, undefined}
    end.

client_init(Client, PoolName, InitOptions) ->
    try Client:init(InitOptions) of
        {ok, ClientState} ->
            {ok, ClientState};
        {error, Reason} ->
            ?WARN(PoolName, "init error: ~p~n", [Reason]),
            {error, Reason}
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            ?WARN(PoolName, "init crash: ~p:~p~n  ~p~n",
                [E, R, ?GET_STACK(Stacktrace)]),
            {error, client_crash}
    end.

client_setup(Client, PoolName, Protocol, Socket, ClientState) ->
    Protocol:setopts(Socket, [{active, false}]),
    try Client:setup(Socket, ClientState) of
        {ok, ClientState2} ->
            Protocol:setopts(Socket, [{active, true}]),
            {ok, ClientState2};
        {error, Reason, ClientState2} ->
            ?WARN(PoolName, "setup error: ~p", [Reason]),
            {error, Reason, ClientState2}
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            ?WARN(PoolName, "handle_data error: ~p:~p~n  ~p~n",
                [E, R, ?GET_STACK(Stacktrace)]),
            {error, client_crash, ClientState}
    end.

close(State, ClientState) ->
    close(State, ClientState, disconnected).
close(#state {id = Id} = State, ClientState, Reason)
    when Reason == disconnected; Reason == reconnecting ->
    shackle_status:disable(Id),
    ?ON_BOUNCE_EVENT(State, #{
        status => socket_close,
        bounce_state => Reason,
        bounce_interval => State#state.bounce_interval,
        src => {?MODULE, ?LINE}
    }),
    reply_all({error, socket_closed}, State, ClientState),
    reconnect(State#state{socket = undefined, bounce_state = Reason}, ClientState).

connect(Protocol, Address, Port, SocketOptions, PoolName) ->
    case inet:getaddrs(Address, inet) of
        {ok, Ips} when Ips /= [] ->
            Ip = shackle_utils:random_element(Ips),
            case Protocol:connect(Ip, Port, SocketOptions) of
                {ok, Socket} ->
                    {ok, Socket};
                {error, Reason} ->
                    ?WARN(PoolName, "~s:~w connect error: ~p", [Address, Port, Reason]),
                    {error, Reason}
            end;
        {error, Reason} ->
            ?WARN(PoolName, "getaddrs error: ~p", [Reason]),
            {error, Reason}
    end.

handle_msg_close(S, #state {socket = S, pool_name = PoolName} = State, ClientState) ->
    log_metrics(State, shackle_close_total),
    ?WARN(PoolName, "SrvIdx=~s: connection closed", [State#state.srv_idx]),
    close(State, ClientState);
handle_msg_close(_Socket, State, ClientState) ->
    log_metrics(State, shackle_close_total),
    {ok, {State, ClientState}}.

handle_msg_data(Socket, Data, #state {
        client = Client,
        pool_name = PoolName,
        protocol = Protocol,
        socket = Socket
    } = State, ClientState) ->
    log_metrics(State, shackle_received_bytes_total, byte_size(Data)),
    log_metrics(State, shackle_received_messages_total, 1),

    try Client:handle_data(Data, ClientState) of
        {ok, Replies, ClientState2} ->
            process_responses(Replies, State, ClientState),
            {ok, {State, ClientState2}};
        {error, Reason, ClientState2} ->
            ?WARN(PoolName, "handle_data error: ~p", [Reason]),
            Protocol:close(Socket),
            close(State, ClientState2)
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            ?WARN(PoolName, "handle_data crash: ~p:~p~n~p~n",
                [E, R, ?GET_STACK(Stacktrace)]),
            Protocol:close(Socket),
            close(State, ClientState)
    end;
handle_msg_data(_Socket, _Data, State, ClientState) ->
    {ok, {State, ClientState}}.

handle_msg_error(Socket, Reason, #state {
        socket = Socket,
        pool_name = PoolName,
        protocol = Protocol
    } = State, ClientState) ->

    log_metrics(State, shackle_error_total, <<"socket error">>),
    ?WARN(PoolName, "connection error: ~p", [Reason]),
    Protocol:close(Socket),
    close(State, ClientState);
handle_msg_error(_Socket, _Reason, State, ClientState) ->
    {ok, {State, ClientState}}.

process_responses([], State, ClientState) ->
    {ok, {State, ClientState}};
process_responses([{ExtRequestId, Reply} | T], #state {
        client = Client,
        id = Id,
        pool_name = PoolName,
        queue = Queue
    } = State, ClientState) ->
    case shackle_queue:remove(Queue, Id, ExtRequestId) of
        {ok, #cast {timestamp = Timestamp} = Cast, TimerRef} ->
            log_metrics(State, shackle_response_total, <<"found">>),
            TimeDiff = os:system_time(microsecond) - Timestamp,
            prometheus_histogram:observe(shackle_response_time_microseconds, [
                Client, PoolName
            ], TimeDiff),
            erlang:cancel_timer(TimerRef),
            {ok, {State2, ClientState2}} =
                reply(Reply, [Cast], State, ClientState),
            process_responses(T, State2, ClientState2);
        {error, not_found} ->
            log_metrics(State, shackle_response_total, <<"not found">>),
            process_responses(T, State, ClientState)
    end.

reconnect(State, undefined) ->
    reconnect_timer(State, undefined);
reconnect(#state {
        client = Client,
        pool_name = PoolName
    } = State, ClientState) ->

    try Client:terminate(ClientState)
    catch
        ?EXCEPTION(E, R, Stacktrace) ->
            ?WARN(PoolName, "terminate crash: ~p:~p~n~p~n",
                [E, R, ?GET_STACK(Stacktrace)])
    end,
    reconnect_timer(State, ClientState).

reconnect_state(Options) ->
    Reconnect = ?LOOKUP(reconnect, Options, ?DEFAULT_RECONNECT),
    case Reconnect of
        true ->
            Max = ?LOOKUP(reconnect_time_max, Options,
                ?DEFAULT_RECONNECT_MAX),
            Min = ?LOOKUP(reconnect_time_min, Options,
                ?DEFAULT_RECONNECT_MIN),

            #reconnect_state {
                min = Min,
                max = Max
            };
        false ->
            undefined
    end.

reconnect_state_reset(undefined) ->
    undefined;
reconnect_state_reset(#reconnect_state {} = ReconnectState) ->
    ReconnectState#reconnect_state {
        current = undefined
    }.

reconnect_timer(#state {reconnect_state = undefined} = State, ClientState) ->
    {ok, {State, ClientState}};
reconnect_timer(#state {bounce_state = reconnecting} = State, ClientState) ->
    cancel_timer(State#state.timer_ref),
    TimerRef = erlang:send_after(0, self(), ?MSG_CONNECT),
    State1 = State#state {timer_ref = TimerRef, bounce_state = disconnected},
    {ok, {State1, ClientState}};

reconnect_timer(#state {reconnect_state = ReconState} = State, ClientState)  ->
    cancel_timer(State#state.timer_ref),
    ReconState2 = shackle_backoff:timeout(ReconState),
    Timeout = ReconState2#reconnect_state.current,
    TimerRef = erlang:send_after(Timeout, self(), ?MSG_CONNECT),

    {ok, {State#state {
        reconnect_state = ReconState2,
        timer_ref = TimerRef
    }, ClientState}}.

wrap(Casts) when is_list(Casts) ->
    Casts;
wrap(Cast) ->
    [Cast].

reply(Reply, Casts, State, ClientState) ->
    reply2(Reply, Casts, State),
    maybe_bounce(State, ClientState).

%% For batch replies Pid is the same in all casts in the list.
%% TODO: Optimize the batch replies to deliver them as 1 message to Pid?
reply2(_Reply, [], _State) ->
    ok;
reply2(Reply, [#cast {pid = Pid, send_reply = SendReply} = Cast | T], State) ->
    log_metrics(State, shackle_reply_total),
    release(Cast),
    SendReply andalso Pid ! {Cast, Reply},
    reply2(Reply, T, State).

release(#cast {sema = Sema, pid = Pid}) ->
    shackle_sema:release(Sema, Pid).

reply_all(Reply, #state {id = Id, queue = Queue} = State, ClientState) ->
    Requests = shackle_queue:clear(Queue, Id),
    reply_all(Reply, Requests, State, ClientState).

reply_all(_Reply, [], _State, _ClientState) ->
    ok;
reply_all(Reply, [{Cast, TimerRef} | T], State, ClientState) ->
    erlang:cancel_timer(TimerRef),
    reply(Reply, [Cast], State, ClientState),
    reply_all(Reply, T, State, ClientState).

handle_request_ids_from_client(ExtRequestIds, Casts, State, ClientState) ->
    ExtRequestIdsCasts = lists:zip(ExtRequestIds, Casts),
    [handle_request_id_from_client(IdCast, State, ClientState) || IdCast <- ExtRequestIdsCasts],
    ok.

handle_request_id_from_client({undefined, Cast}, State, ClientState) ->
    reply(ok, [Cast], State, ClientState);
handle_request_id_from_client({ExtRequestId, Cast}, State, _ClientState) ->
    set_receive_timeout(State#state.queue, State#state.id, ExtRequestId, Cast).

set_receive_timeout(Queue, Id, ExtRequestId,
    #cast{timeout = Timeout} = Cast) ->
    Msg = {timeout, ExtRequestId},
    TimerRef = erlang:send_after(Timeout, self(), Msg),
    shackle_queue:add(Queue, Id, ExtRequestId, Cast, TimerRef).

schedule_bounce(#state{bounce_interval = infinity} = State) ->
    State;
schedule_bounce(#state{bounce_interval = MSec} = State) ->
    Time = now_time_ms() + MSec,
    erlang:send_after(MSec, self(), bounce_connection),
    State#state{next_bounce = Time}.

maybe_bounce(#state{bounce_state = draining} = State, ClientState) ->
    %% If we are in the process of waiting for a connection bounce and draining
    %% the queue, when the queue has been drained, proceed with the bounce.
    case shackle_queue:length(State#state.queue) of
        0 ->
            Pool = State#state.pool_name,
            shackle_pool:finalize_bounce(Pool),
            ?LOG_DEBUG("[~p] connection ~p bounce finalized - reconnecting", [Pool, State#state.id]),
            ?ON_BOUNCE_EVENT(State, #{
                status => finalizing_bounce,
                bounce_state => reconnecting,
                bounce_interval => State#state.bounce_interval,
            src => {?MODULE, ?LINE}
            }),
            close(State, ClientState, reconnecting);
        _N ->
            ?ON_BOUNCE_EVENT(State, #{
                status => awaiting_empty_queue,
                queue_len => _N,
                bounce_state => draining,
                bounce_interval => State#state.bounce_interval,
            src => {?MODULE, ?LINE}
            }),
            {ok, {State, ClientState}}
    end;
maybe_bounce(State, ClientState) ->
    {ok, {State, ClientState}}.

%% If bounce timeout is set and the current time exceeds the timeout,
%% enter the connection draining state
bounce_check(#state{bounce_interval = I, socket = Sock} = State, ClientState)
    when I == infinity; Sock == undefined ->
    {ok, {State, ClientState}};
bounce_check(#state{bounce_state = waiting, next_bounce = Time} = State, ClientState) ->
    Interval = Time - now_time_ms(),
    case Interval =< 0 of
        true ->
            case shackle_pool:init_bounce(State#state.pool_name) of
                true ->
                    ?ON_BOUNCE_EVENT(State, #{
                        status => bounce_initiated,
                        bounce_state => draining,
                        server_status => disabled,
                        bounce_interval => State#state.bounce_interval,
                        src => {?MODULE, ?LINE}
                    }),
                    ?LOG_DEBUG("[~p] connection ~p bounce initiated", [State#state.pool_name, State#state.id]),
                    shackle_status:disable(State#state.id),
                    maybe_bounce(State#state{bounce_state = draining}, ClientState);
                false ->
                    %% Another connection is bouncing, wait for 1-4 seconds and
                    %% try bouncing again
                    NewInterval = 500 + rand:uniform(2000),
                    ?ON_BOUNCE_EVENT(State, #{
                        status => bounce_not_initiated,
                        reason => another_connection_bouncing,
                        next_bounce_check => NewInterval,
                        bounce_state => State#state.bounce_state,
                        bounce_interval => State#state.bounce_interval,
                        src => {?MODULE, ?LINE}
                    }),
                    erlang:send_after(NewInterval, self(), bounce_connection),
                    {ok, {State, ClientState}}
            end;
        false ->
            ?ON_BOUNCE_EVENT(State, #{
                status => schedule_bounce_check,
                next_bounce_check => Interval,
                bounce_state => State#state.bounce_state,
                bounce_interval => State#state.bounce_interval,
                src => {?MODULE, ?LINE}
            }),
            erlang:send_after(Interval, self(), bounce_connection),
            {ok, {State, ClientState}}
    end;
bounce_check(State, ClientState) ->
    {ok, {State, ClientState}}.

log_metrics(State, Metric) ->
    log_metrics(State, Metric, 1).
log_metrics(#state{srv_idx = SrvIdx, client = Cli, pool_name = Pool}, Metric, Inc) when is_integer(Inc) ->
    log_metrics2(Metric, [Cli, Pool, SrvIdx], Inc);
log_metrics(#state{srv_idx = SrvIdx, client = Cli, pool_name = Pool}, Metric, Reason) when is_binary(Reason) ->
    log_metrics2(Metric, [Cli, Pool, SrvIdx, Reason], 1).

log_metrics2(Metric, Args, N) ->
    prometheus_counter:inc(Metric, Args, N).

now_time_ms() ->
    os:system_time(millisecond).
