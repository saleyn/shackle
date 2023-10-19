-module(arithmetic_protocol).
-include("shackle_internal.hrl").
-include("test.hrl").

-export([
    opcode/1,
    parse_replies/1,
    parse_requests/1,
    parse_request/1,
    request/3,
    request/4,
    request_id/1
]).

-define(MAX_REQUEST_ID, 4294967296).

-type int() :: 0..4294967295.
-type operation() :: add | multiply | noop | modulo | delayed_echo.
-type tiny_int() :: 0..255.

%% public
-spec opcode(operation()) -> 1..3.

-define(OP_ADD,          1).
-define(OP_MULTIPLY,     2).
-define(OP_NOOP,         3).
-define(OP_MODULO,       4).
-define(OP_DELAYED_ECHO, 5).

opcode(add)          -> ?OP_ADD;
opcode(multiply)     -> ?OP_MULTIPLY;
opcode(noop)         -> ?OP_NOOP;
opcode(modulo)       -> ?OP_MODULO;
opcode(delayed_echo) -> ?OP_DELAYED_ECHO.

-spec parse_replies(binary()) -> {[shackle:response()], binary()}.

parse_replies(Data) ->
    parse_replies(Data, []).

-spec parse_requests(binary()) -> {[binary()], binary()}.

parse_requests(Data) ->
    parse_requests(Data, []).

-spec request(int(), operation(), tiny_int(), tiny_int()) -> binary().

request(ReqId, Operation, A, B) ->
    <<ReqId:32/integer, (opcode(Operation)), A:8/integer, B:8/integer>>.

-spec request(int(), operation(), pos_integer()) -> binary().
request(ReqId, Operation, Arg) ->
    <<ReqId:32/integer, (opcode(Operation)), Arg:16/unsigned-integer>>.

-spec request_id(non_neg_integer()) -> int().

request_id(RequestCounter) ->
    RequestCounter rem ?MAX_REQUEST_ID.

%% private
parse_replies(<<ReqId:32/integer, A:16/integer, Rest/binary>>, Acc) ->
    parse_replies(Rest, [{ReqId, A} | Acc]);
parse_replies(Buffer, Acc) ->
    {lists:reverse(Acc), Buffer}.

parse_requests(<<"INIT", Rest/binary>>, Acc) ->
    parse_requests(Rest, [<<"OK">> | Acc]);
parse_requests(<<ReqId:32/integer, ?OP_ADD, 255, 255, Rest/binary>>, Acc) ->
    % special case to test timeouts add(255, 255)
    timer:sleep(trunc(1.5 * ?TIMEOUT)),
    parse_requests(Rest, [<<ReqId:32/integer, 510:16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, ?OP_ADD, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A + B):16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, ?OP_MULTIPLY, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A * B):16/integer>> | Acc]);
parse_requests(<<_ReqId:32/integer, ?OP_NOOP, _A:8/integer, _B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, Acc);
parse_requests(<<_ReqId:32/integer, ?OP_MODULO, _A, 0, Rest/binary>>, Acc) ->
    % special case to test cases
    % when reply is not provided for every rem(X, 0) request

    parse_requests(Rest, Acc);
parse_requests(<<ReqId:32/integer, 4, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A rem B):16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, ?OP_DELAYED_ECHO, A:16/unsigned-integer, Rest/binary>>, Acc) ->
    timer:sleep(A),
    parse_requests(Rest, [<<ReqId:32/integer, A:16/unsigned-integer>> | Acc]);
parse_requests(Buffer, Acc) ->
    {Acc, Buffer}.

parse_request(<<"INIT", Rest/binary>>) ->
    {<<"OK">>, Rest};
parse_request(<<ReqId:32/integer, ?OP_ADD, 255, 255, Rest/binary>>) ->
    % special case to test timeouts add(255, 255)
    timer:sleep(1000),
    {<<ReqId:32/integer, 510:16/integer>>, Rest};
parse_request(<<ReqId:32/integer, ?OP_ADD, A:8/integer, B:8/integer,
    Rest/binary>>) ->
    {<<ReqId:32/integer, (A + B):16/integer>>, Rest};
parse_request(<<ReqId:32/integer, ?OP_MULTIPLY, A:8/integer, B:8/integer,
    Rest/binary>>) ->
    {<<ReqId:32/integer, (A * B):16/integer>>, Rest};
parse_request(<<_ReqId:32/integer, ?OP_NOOP, _A:8/integer, _B:8/integer,
    Rest/binary>>) ->
    {skip, Rest};
parse_request(<<_ReqId:32/integer, ?OP_MODULO, _A, 0, Rest/binary>>) ->
    % special case to test cases
    % when reply is not provided for every rem(X, 0) request

    {skip, Rest};
%%    {<<ReqId:32/integer, A:16/integer>>, Rest};
parse_request(<<ReqId:32/integer, ?OP_MODULO, A:8/integer, B:8/integer, Rest/binary>>) ->
    {<<ReqId:32/integer, (A rem B):16/integer>>, Rest};
parse_request(<<ReqId:32/integer, ?OP_DELAYED_ECHO, A:16/unsigned-integer, Rest/binary>>) ->
    timer:sleep(A),
    {<<ReqId:32/integer, A:16/unsigned-integer>>, Rest};
parse_request(Buffer) ->
    {need_more, Buffer}.
