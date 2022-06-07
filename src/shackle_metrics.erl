-module(shackle_metrics).

-export([
    init/0
]).

-define(COUNTERS, [
    [
        {name, shackle_cast_total},
        {help, "Count of shackle cast calls"},
        {labels, [pool, client]}
    ],
    [
        {name, shackle_connect_total},
        {help, "Count of shackle connections"},
        {labels, [pool, server]}
    ],
    [
        {name, shackle_close_total},
        {help, "Count of shackle connect closes"},
        {labels, [pool, server]}
    ],
    [
        {name, shackle_error_total},
        {help, "Count of shackle errors"},
        {labels, [pool, server, reason]}
    ],
    [
        {name, shackle_reply_total},
        {help, "Count of shackle replies"},
        {labels, [pool, server]}
    ],
    [
        {name, shackle_request_total},
        {help, "Count of shackle requests"},
        {labels, [pool, server]}
    ],
    [
        {name, shackle_response_total},
        {help, "Count of shackle responses"},
        {labels, [pool, server, response]}
    ],
    [
        {name, shackle_received_bytes_total},
        {help, "Count of shackle received bytes"},
        {labels, [pool, server]}
    ],
    [
        {name, shackle_received_messages_total},
        {help, "Count of shackle received messages"},
        {labels, [pool, server]}
    ]
]).

-define(GAUGES, []).

-define(HISTOGRAMS, [
    [
        {name, shackle_response_time_microseconds},
        {help, "Shackle response time distribution"},
        {buckets, [1000, 2000, 4000, 8000, 16000, 32000, 64000, 96000,
                   128000, 160000, 192000, 224000, 256000, 512000]},
        {duration_unit, false},
        {labels, [pool, server]}
    ]
]).


-spec init() -> ok.
init() ->
    lists:map(fun prometheus_counter:declare/1, ?COUNTERS),
    lists:map(fun prometheus_gauge:declare/1, ?GAUGES),
    lists:map(fun prometheus_histogram:declare/1, ?HISTOGRAMS),
    ok.
