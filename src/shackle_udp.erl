-module(shackle_udp).

-behavior(shackle_protocol).
-export([
    close/1,
    connect/3,
    send/2,
    setopts/2
]).

%% callbacks
-spec close(shackle:socket()) ->
    ok.

close(Socket) ->
    gen_udp:close(Socket).

-spec connect(shackle:inet_address(), shackle:inet_port(), shackle:socket_options()) ->
    {ok, shackle:socket()} | {error, atom()}.

connect(Address, Port, SocketOptions) ->
    case gen_udp:open(0, [family_opt(Address) | SocketOptions]) of
        {ok, Socket} ->
            case gen_udp:connect(Socket, Address, Port) of
                ok ->
                    {ok, Socket};
                {error, Reason} ->
                    gen_udp:close(Socket),
                    {error, Reason}
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%% IPv6 literal addresses are 8-tuples; gen_udp needs the inet6 family for them.
family_opt(Address) when tuple_size(Address) =:= 8 -> inet6;
family_opt(_Address) -> inet.

-spec send(shackle:socket(), iodata()) ->
    ok | {error, atom()}.

send(Socket, Data) ->
    gen_udp:send(Socket, Data).

-spec setopts(shackle:socket(), [gen_udp:option()]) ->
    ok |
    {error, atom()}.

setopts(Socket, Opts) ->
    inet:setopts(Socket, Opts).
