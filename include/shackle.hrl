%% records
-record(cast, {
    client         :: shackle:client(),
    pid            :: undefined | pid(),
    batch_ref      :: shackle:batch_ref(),
    request_id     :: shackle:request_id(),
    timeout        :: timeout(),
    timestamp      :: erlang:timestamp()
}).

-record(reconnect_state, {
    current :: undefined | shackle:time(),
    max     :: shackle:time() | infinity,
    min     :: shackle:time()
}).
