-module(arithmetic_protocol).
-include("shackle_internal.hrl").

-export([
    opcode/1,
    parse_replies/1,
    parse_requests/1,
    parse_request/1,
    request/4,
    request_id/1
]).

-define(MAX_REQUEST_ID, 4294967296).

-type int() :: 0..4294967295.
-type operation() :: add | multiply | noop | modulo.
-type tiny_int() :: 0..255.

%% public
-spec opcode(operation()) -> 1..3.

opcode(add) -> 1;
opcode(multiply) -> 2;
opcode(noop) -> 3;
opcode(modulo) -> 4.

-spec parse_replies(binary()) -> {[shackle:response()], binary()}.

parse_replies(Data) ->
    parse_replies(Data, []).

-spec parse_requests(binary()) -> {[binary()], binary()}.

parse_requests(Data) ->
    parse_requests(Data, []).

-spec request(int(), operation(), tiny_int(), tiny_int()) -> binary().

request(ReqId, Operation, A, B) ->
    <<ReqId:32/integer, (opcode(Operation)), A:8/integer, B:8/integer>>.

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
parse_requests(<<ReqId:32/integer, 1, 255, 255, Rest/binary>>, Acc) ->
    % special case to test timeouts add(255, 255)
    timer:sleep(?DEFAULT_TIMEOUT),
    parse_requests(Rest, [<<ReqId:32/integer, 510:16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, 1, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A + B):16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, 2, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A * B):16/integer>> | Acc]);
parse_requests(<<_ReqId:32/integer, 3, _A:8/integer, _B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, Acc);
parse_requests(<<_ReqId:32/integer, 4, _A, 0, Rest/binary>>, Acc) ->
    % special case to test cases
    % when reply is not provided for every rem(X, 0) request

    parse_requests(Rest, Acc);
%%    parse_requests(Rest, [<<ReqId:32/integer, A:16/integer>> | Acc]);
parse_requests(<<ReqId:32/integer, 4, A:8/integer, B:8/integer,
    Rest/binary>>, Acc) ->

    parse_requests(Rest, [<<ReqId:32/integer, (A rem B):16/integer>> | Acc]);
parse_requests(Buffer, Acc) ->
    {Acc, Buffer}.

parse_request(<<"INIT", Rest/binary>>) ->
    {<<"OK">>, Rest};
parse_request(<<ReqId:32/integer, 1, 255, 255, Rest/binary>>) ->
    % special case to test timeouts add(255, 255)
    timer:sleep(1000),
    {<<ReqId:32/integer, 510:16/integer>>, Rest};
parse_request(<<ReqId:32/integer, 1, A:8/integer, B:8/integer,
    Rest/binary>>) ->
    {<<ReqId:32/integer, (A + B):16/integer>>, Rest};
parse_request(<<ReqId:32/integer, 2, A:8/integer, B:8/integer,
    Rest/binary>>) ->
    {<<ReqId:32/integer, (A * B):16/integer>>, Rest};
parse_request(<<_ReqId:32/integer, 3, _A:8/integer, _B:8/integer,
    Rest/binary>>) ->
    {skip, Rest};
parse_request(<<_ReqId:32/integer, 4, _A, 0, Rest/binary>>) ->
    % special case to test cases
    % when reply is not provided for every rem(X, 0) request

    {skip, Rest};
%%    {<<ReqId:32/integer, A:16/integer>>, Rest};
parse_request(<<ReqId:32/integer, 4, A:8/integer, B:8/integer, Rest/binary>>) ->

    {<<ReqId:32/integer, (A rem B):16/integer>>, Rest};
parse_request(Buffer) ->
    {need_more, Buffer}.
