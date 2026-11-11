-module(shackle_socket).
-moduledoc """
NIF-based TCP socket protocol using the socket module (OTP 28+).

Socket-level gen_tcp options are applied with `socket:setopt/3`. Options that
have no meaning on this path are ignored. Any other option is rejected with
`{error, {unsupported_option, Opt}}` instead of being dropped.

Reads are driven by select notifications. When the socket becomes readable,
the owner process receives `{'$socket', Socket, select, Ref}`. shackle_server
then calls recv/1, which delivers the data to the client's handle_data/2 as if
it had arrived as a `{tcp, Socket, Data}` message.

Stream framing (`{packet, N}`) and list mode are not supported.
""".
-include("shackle_defaults.hrl").

-dialyzer({nowarn_function, [recv/1, send/2, sendv/2, setopts/2, ignorable/1]}).
-ignore_xref([
    {socket, sendv, 2}
]).

-behavior(shackle_protocol).
-export([
    close/1,
    connect/3,
    recv/1,
    send/2,
    setopts/2
]).

%% Used by shackle_ssl_socket, which applies the same socket-level options.
-export([apply_socket_options/2]).

-spec close(shackle:socket()) -> ok.
close(Socket) ->
    _ = socket:close(Socket),
    ok.

-spec connect(shackle:inet_address(), shackle:inet_port(), shackle:socket_options()) ->
    {ok, shackle:socket()} | {error, term()}.
connect(Address, Port, SocketOptions) ->
    Family = family(Address),
    case socket:open(Family, stream, tcp) of
        {ok, Socket} ->
            case apply_socket_options(Socket, SocketOptions) of
                {ok, Rest} ->
                    case check_ignorable(Rest) of
                        ok ->
                            connect_socket(Socket, Family, Address, Port);
                        {error, _} = Error ->
                            close(Socket),
                            Error
                    end;
                {error, _} = Error ->
                    close(Socket),
                    Error
            end;
        {error, _} = Error ->
            Error
    end.

connect_socket(Socket, Family, Address, Port) ->
    SockAddr = #{family => Family, addr => Address, port => Port},
    case socket:connect(Socket, SockAddr, ?DEFAULT_CONNECT_TIMEOUT) of
        ok ->
            {ok, Socket};
        {error, Reason} ->
            close(Socket),
            {error, Reason}
    end.

%% Reads whatever is available; with {otp, select_read} enabled the
%% successful recv re-arms the read select inside the same NIF call.
%% `armed' means the select was re-armed by this read, so the caller can stop
%% reading and wait for the next notification. `ok' means the caller must read
%% again until it gets `wait'.
-spec recv(shackle:socket()) ->
    {ok, binary()} | {armed, binary()} | wait | {error, atom()}.
recv(Socket) ->
    case socket:recv(Socket, 0, [], nowait) of
        {select_read, {_SelectInfo, Data}} ->
            {armed, Data};
        {select, {_SelectInfo, Data}} ->
            {ok, Data};
        {select, _SelectInfo} ->
            wait;
        {ok, Data} ->
            %% Data was read but the select may not be re-armed; callers keep
            %% calling recv/1 until it returns `wait', which arms it.
            {ok, Data};
        {error, {Reason, _Data}} ->
            {error, Reason};
        {error, Reason} ->
            {error, Reason}
    end.

-spec send(shackle:socket(), iodata()) ->
    ok | {error, atom()}.

send(Socket, Data) when is_binary(Data) ->
    case socket:send(Socket, Data) of
        ok ->
            ok;
        {error, {Reason, _RestData}} ->
            {error, Reason};
        {error, Reason} ->
            {error, Reason}
    end;
%% socket:send flattens iolists with list_to_binary; sendv keeps the
%% iovec and writes it in one NIF call. An empty iolist has an empty iovec,
%% which sendv rejects, so it is a no-op here (gen_tcp:send/2 also returns ok).
send(Socket, Data) ->
    case iolist_size(Data) of
        0 -> ok;
        _ -> sendv(Socket, erlang:iolist_to_iovec(Data))
    end.

-spec setopts(shackle:socket(), [gen_tcp:option()]) ->
    ok | {error, term()}.

setopts(Socket, [{active, false}]) ->
    _ = socket:setopt(Socket, {otp, select_read}, false),
    ok;
setopts(Socket, [{active, true}]) ->
    ok = socket:setopt(Socket, {otp, select_read}, true),
    arm_and_deliver(Socket);
setopts(Socket, Opts) ->
    case apply_socket_options(Socket, Opts) of
        {ok, Rest} -> check_ignorable(Rest);
        {error, _} = Error -> Error
    end.

%% Applies the socket-level options in Options and returns the rest, in their
%% original order.
-spec apply_socket_options(shackle:socket(), [gen_tcp:option()]) ->
    {ok, [gen_tcp:option()]} | {error, term()}.
apply_socket_options(Socket, Options) ->
    apply_socket_options(Socket, Options, []).

apply_socket_options(_Socket, [], Acc) ->
    {ok, lists:reverse(Acc)};
apply_socket_options(Socket, [Opt | T], Acc) ->
    case socket_settings(Opt) of
        not_socket_option ->
            apply_socket_options(Socket, T, [Opt | Acc]);
        Settings ->
            case set_all(Socket, Settings) of
                ok -> apply_socket_options(Socket, T, Acc);
                {error, _} = Error -> Error
            end
    end.

set_all(_Socket, []) ->
    ok;
set_all(Socket, [{Level, Name, Value} | T]) ->
    case socket:setopt(Socket, {Level, Name}, Value) of
        ok -> set_all(Socket, T);
        {error, _} = Error -> Error
    end.

%% Map a gen_tcp option to socket-module settings. Options that the socket
%% module does not set here (for example packet framing) are not socket-level.
socket_settings({nodelay, Flag})          -> [{tcp, nodelay, Flag}];
socket_settings({keepalive, Flag})        -> [{socket, keepalive, Flag}];
socket_settings({recbuf, Size})           -> [{socket, rcvbuf, Size}, {otp, rcvbuf, Size}];
socket_settings({buffer, Size})           -> [{otp, rcvbuf, Size}];
socket_settings({sndbuf, Size})           -> [{socket, sndbuf, Size}];
socket_settings({linger, {true, Secs}})   -> [{socket, linger, #{onoff => true, linger => Secs}}];
socket_settings({linger, {false, _}})     -> [{socket, linger, #{onoff => false, linger => 0}}];
socket_settings({reuseaddr, Flag})        -> [{socket, reuseaddr, Flag}];
socket_settings({dontroute, Flag})        -> [{socket, dontroute, Flag}];
socket_settings({priority, Priority})     -> [{socket, priority, Priority}];
socket_settings({send_timeout, Timeout})  -> [{socket, sndtimeo, Timeout}];
socket_settings({tos, ToS})               -> [{ip, tos, ToS}];
socket_settings({ttl, TTL})               -> [{ip, ttl, TTL}];
socket_settings({ipv6_v6only, Flag})      -> [{ipv6, v6only, Flag}];
socket_settings(_Other)                   -> not_socket_option.

%% Options with no effect on this path. Anything else left over is rejected, so
%% it cannot be silently dropped.
check_ignorable([]) ->
    ok;
check_ignorable([Opt | T]) ->
    case ignorable(Opt) of
        true -> check_ignorable(T);
        false -> {error, {unsupported_option, Opt}}
    end.

ignorable(binary)                   -> true;
ignorable(inet)                     -> true;
ignorable(inet6)                    -> true;
ignorable({active, _})              -> true;  %% handled by setopts/2
ignorable({packet, raw})            -> true;
ignorable({delay_send, _})          -> true;
ignorable({deliver, _})             -> true;
ignorable({exit_on_close, _})       -> true;
ignorable({high_msgq_watermark, _}) -> true;
ignorable({low_msgq_watermark, _})  -> true;
ignorable({high_watermark, _})      -> true;
ignorable({low_watermark, _})       -> true;
ignorable({send_timeout_close, _})  -> true;
ignorable(_Other)                   -> false.

%% Reads until recv/1 returns `wait', which leaves the select armed. Each chunk
%% is sent to the owner like an active-mode packet.
arm_and_deliver(Socket) ->
    case recv(Socket) of
        {armed, Data} ->
            self() ! {tcp, Socket, Data},
            ok;
        {ok, Data} ->
            self() ! {tcp, Socket, Data},
            arm_and_deliver(Socket);
        wait ->
            ok;
        {error, _} = Error ->
            Error
    end.

sendv(Socket, IOV) ->
    case socket:sendv(Socket, IOV) of
        ok ->
            ok;
        {ok, RestIOV} ->
            sendv(Socket, RestIOV);
        {error, {Reason, _RestIOV}} ->
            {error, Reason};
        {error, Reason} ->
            {error, Reason}
    end.

family(Address) when tuple_size(Address) =:= 8 -> inet6;
family(_Address) -> inet.
