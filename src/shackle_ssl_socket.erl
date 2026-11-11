-module(shackle_ssl_socket).
-moduledoc """
TLS over the OTP socket module (OTP 28+).

The TCP socket is opened with `socket:open/3`. Socket-level options (for example
`nodelay`, `keepalive`, buffer sizes) are applied with `socket:setopt/3`. All other
options (TLS options, `binary`, `packet`, ...) are passed to `ssl:connect/3`, which
runs the handshake on the connected socket.

`shackle_ssl` uses `ssl:connect/4` with the gen_tcp transport and works on older
OTP releases. Use this module only when the socket NIF is wanted.

`{inet_backend, _}` is rejected: this module already uses the socket module. To run
TLS over the socket NIF through `ssl`, use `shackle_ssl` with `{inet_backend, socket}`.
""".
-include("shackle_defaults.hrl").

-behavior(shackle_protocol).
-export([
    close/1,
    connect/3,
    send/2,
    setopts/2
]).

-spec close(shackle:socket()) -> ok.
close(Socket) ->
    ssl:close(Socket),
    ok.

-spec connect(shackle:inet_address(), shackle:inet_port(), shackle:socket_options()) ->
    {ok, shackle:socket()} | {error, atom()}.
connect(Address, Port, SocketOptions) ->
    case lists:keyfind(inet_backend, 1, SocketOptions) of
        false -> do_connect(Address, Port, SocketOptions);
        InetBackend -> {error, {unsupported_option, InetBackend}}
    end.

do_connect(Address, Port, SocketOptions) ->
    Timestamp = erlang:monotonic_time(millisecond),
    Family = family(Address),
    case socket:open(Family, stream, tcp) of
        {ok, Socket} ->
            case apply_options(Socket, SocketOptions) of
                {ok, TlsOptions} ->
                    SockAddr = #{family => Family, addr => Address, port => Port},
                    case socket:connect(Socket, SockAddr, ?DEFAULT_CONNECT_TIMEOUT) of
                        ok ->
                            handshake(Socket, TlsOptions, Timestamp);
                        {error, Reason} ->
                            close_socket(Socket),
                            {error, Reason}
                    end;
                {error, Reason} ->
                    close_socket(Socket),
                    {error, Reason}
            end;
        {error, _} = Error ->
            Error
    end.

-spec send(shackle:socket(), iodata()) -> ok | {error, atom()}.
send(Socket, Data) ->
    ssl:send(Socket, Data).

-spec setopts(shackle:socket(), [gen_tcp:option()]) -> ok | {error, atom()}.
setopts(Socket, Opts) ->
    ssl:setopts(Socket, Opts).

%% private

family(Address) when tuple_size(Address) =:= 8 -> inet6;
family(_Address) -> inet.

%% Socket-level options are applied by shackle_socket, which shares the table.
%% The rest are TLS options (and binary/packet/active), kept in order for ssl.
apply_options(Socket, Options) ->
    shackle_socket:apply_socket_options(Socket, Options).

%% The remaining connect budget goes to the handshake, so the total connect
%% deadline matches shackle_ssl.
handshake(Socket, TlsOptions, Timestamp) ->
    Elapsed = erlang:monotonic_time(millisecond) - Timestamp,
    Timeout = max(?DEFAULT_CONNECT_TIMEOUT - Elapsed, 1),
    %% ssl:connect/3 on a socket handle defaults to active false, unlike
    %% ssl:connect/4, which shackle_ssl uses. Match shackle_ssl unless the caller says otherwise.
    Options = case lists:keymember(active, 1, TlsOptions) of
        true -> TlsOptions;
        false -> [{active, true} | TlsOptions]
    end,
    case ssl:connect(Socket, Options, Timeout) of
        {ok, SslSocket} ->
            {ok, SslSocket};
        {error, Reason} ->
            close_socket(Socket),
            {error, Reason}
    end.

close_socket(Socket) ->
    socket:close(Socket),
    ok.
