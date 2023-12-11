-module(chunking_udp_server).
-include("test.hrl").

-export([
    start/0,
    stop/0
]).

%% public
-spec start() ->
    ok | {error, already_started}.

start() ->
    case whereis(?MODULE) of
        undefined ->
            Self = self(),
            spawn(fun () -> Sock = open(), Self ! ready, loop(Sock) end),
            receive
                ready -> ok
            end;
        _Socket ->
            {error, already_started}
    end.

-spec stop() ->
    ok | {error, not_started}.

stop() ->
    case whereis(?MODULE) of
        undefined ->
            {error, not_started};
        Pid ->
            Pid ! {kill, self()},
            receive
                dead ->
                    ok
            end
    end.

%% private
loop(Socket) ->
    case gen_udp:recv(Socket, 0) of
        {ok, {{127, 0, 0, 1}, Port, Request}} ->
            % process request, generate randomly shaffled chunks
            Chunks = process_request(Request),
            % send chunks back
            lists:foreach(fun (Chunk) ->
                ok = gen_udp:send(Socket, "127.0.0.1", Port, Chunk)
            end, Chunks),
            loop(Socket);
        {error, closed} ->
            ok
    end.

open() ->
    Self = self(),
    spawn(fun () ->
        register(?MODULE, self()),
        Options = [
            binary,
            {active, false},
            {reuseaddr, true}
        ],
        {ok, Socket} = gen_udp:open(?PORT, Options),
        Self ! Socket,
        receive
            {kill, Pid} ->
                gen_udp:close(Socket),
                unregister(?MODULE),
                Pid ! dead
        end
    end),
    receive
        Socket ->
            Socket
    end.

% generate sequence of even numbers, place each number in a chunk
process_request(<<Id:32, N:32, "seq">>) ->
    % create randomly shaffled chunks
    L = [{rand:uniform(), encode(Id, X, N)} || X <- lists:seq(1, N)],
    [X || {_, X} <- lists:sort(L)].

% encode chunk, chink-ids started with zero
encode(Id, X, N) ->
    Y = X + X,
    ChId = X - 1,
    Last = X - N,
    <<Id:32, ChId:32, Last:8, Y:32>>.
