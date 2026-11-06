-module(shackle_observe_dispatcher).

-doc """
Behavior for observability dispatcher modules.

A dispatcher wraps operations in observability instrumentation (spans, events).
Dispatchers are selected based on whether an observability backend is configured:
- `shackle_observe_noop` - no instrumentation (backend disabled)
- `shackle_observe_span` - wraps in spans (backend enabled)
""".

-type pool_name()   :: atom().
-type client_name() :: atom().
-type fun_result()  :: term().

-doc """
Dispatch a call operation through the configured observability backend.
The function `Fun/0` is executed and its result returned.
`ClientName` is the protocol client module (e.g. tcp_client) used for metric tracking.
""".
-callback call(pool_name(), client_name(), fun(() -> fun_result())) -> fun_result().

-doc """
Dispatch a cast operation through the configured observability backend.
The function `Fun/0` is executed and its result returned.
`ClientName` is the protocol client module (e.g. tcp_client) used for metric tracking.
""".
-callback cast(pool_name(), client_name(), fun(() -> fun_result())) -> fun_result().

-doc """
Dispatch a connect operation through the configured observability backend.
The function `Fun/0` is executed and its result returned.
`ClientName` is the protocol client module (e.g. tcp_client) used for metric tracking.
""".
-callback connect(pool_name(), client_name(), fun(() -> fun_result())) -> fun_result().

-doc """
Dispatch a timeout operation through the configured observability backend.
The function `Fun/0` is executed and its result returned.
`ClientName` is the protocol client module (e.g. tcp_client) used for metric tracking.
""".
-callback timeout(pool_name(), client_name(), fun(() -> fun_result())) -> fun_result().

-doc """
Dispatch an error operation through the configured observability backend.
The function `Fun/0` is executed and its result returned.
`ClientName` is the protocol client module (e.g. tcp_client) used for metric tracking.
""".
-callback error(pool_name(), client_name(), fun(() -> fun_result())) -> fun_result().
