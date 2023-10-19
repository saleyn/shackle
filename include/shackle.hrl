%% records
-record(cast, {
    client         :: shackle:client(),
    pid            :: pid(),
    send_reply     :: boolean(),   %% false when caller didn't provide its PID
    batch_ref      :: shackle:batch_ref(),
    request_id     :: shackle:request_id(),
    sema           :: shackle_sema:sema_ref(),
    timeout        :: timeout(),
    timestamp      :: non_neg_integer()
}).

-record(reconnect_state, {
    current :: undefined | shackle:time(),
    max     :: shackle:time() | infinity,
    min     :: shackle:time()
}).
