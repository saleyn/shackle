%% Test client for shackle_socket / shackle_ssl_socket (CODE_REVIEW_3 regression tests).
%% Wire format: a request is <<Id:32, Delay:32>>; the listener sleeps Delay ms and
%% answers <<Id:32, 0:32>>. The reply delivered to the caller is <<0:32>>.
-module(shackle_review_socket_client).
-behavior(shackle_client).

-export([
    init/1,
    setup/2,
    handle_request/2,
    handle_data/2,
    terminate/1
]).

-record(state, {buffer = <<>> :: binary(), counter = 0 :: non_neg_integer()}).

init(_InitOptions) ->
    {ok, #state{}}.

%% Gives the peer time to close during setup (finding 4).
setup(_Socket, State) ->
    timer:sleep(200),
    {ok, State}.

handle_request({ping, Delay}, #state{counter = Counter} = State) ->
    Id = Counter band 16#7FFFFFFF,
    {ok, Id, <<Id:32, Delay:32>>, State#state{counter = Counter + 1}}.

handle_data(Data, #state{buffer = Buffer} = State) ->
    {Replies, Rest} = parse(<<Buffer/binary, Data/binary>>, []),
    {ok, Replies, State#state{buffer = Rest}}.

terminate(_State) ->
    ok.

parse(<<Id:32, Payload:32, Rest/binary>>, Acc) ->
    parse(Rest, [{Id, <<Payload:32>>} | Acc]);
parse(Buffer, Acc) ->
    {lists:reverse(Acc), Buffer}.
