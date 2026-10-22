# Abla NATS

A Core NATS client written in [Abla](https://github.com/AndreBaltazar8/ablac).
It speaks the NATS text protocol over Abla's bounded TCP transport without a C
client library or sidecar.

## Features

- authenticated reusable connections using tokens or username/password;
- `PUB`, `SUB`, queue subscriptions, `UNSUB`, `PING`, and `PONG`;
- synchronous request/reply with generated inboxes;
- ordinary `MSG` and header-bearing `HMSG` payloads;
- server `PING` handling while waiting for application messages;
- bounded connection, line, header, and payload reads;
- subject validation and JSON-safe `CONNECT` generation;
- Docker/Icy service-name resolution; and
- environment and secret-file configuration; and
- a nonblocking client for event loops (`src/async.ab`): poller-driven
  connect, optional TLS (verified, upgraded when the server's INFO requires it
  or `tls://`), hostnames resolved without blocking (`abla/dns/async`),
  reconnects across a server list with subscriptions replayed, publishes
  buffered while disconnected, delivery limits, and pings.

## Import

```abla
import github("AndreBaltazar8/abla-nats")
```

For sibling-checkout development:

```abla
import "../../abla-nats/src/nats.ab"
```

## Example

```abla
import github("AndreBaltazar8/abla-nats")

fun main: int {
    val nats = natsClient(natsConfigFromEnvironment())
    val sid = nats.subscribe("orders.created")
    val message = nats.nextMessage()
    nats.unsubscribe(sid)
    nats.close()
    if (message.succeeded()) 0 else 1
}
```

For a service loop that must never block, use the async client:

```abla
import "../../abla-nats/src/async.ab"

fun main: int {
    var nats = natsAsyncClient(NatsAsyncOptions(["nats.internal:4222"], token = "secret"))
    val sid = nats.subscribe("orders.>")
    nats.publish("orders.created", "{}")
    while (true) {
        nats.step(50)
        for (message in nats.takeMessages()) handleOrder(message)
        for (event in nats.takeEvents()) logEvent(event.kind, event.detail)
    }
    0
}
```

Publishing and request/reply on the blocking client use the same connection:

```abla
val published = nats.publish("orders.created", payload)
val response = nats.request("inventory.reserve", payload)
```

## Configuration

- `NATS_HOST` (default `127.0.0.1`)
- `NATS_PORT` (default `4222`)
- `NATS_NAME` (default `abla`)
- `NATS_TOKEN` or `NATS_TOKEN_FILE`
- `NATS_USERNAME`
- `NATS_PASSWORD` or `NATS_PASSWORD_FILE`
- `NATS_CONNECT_TIMEOUT_MS` (default `3000`)
- `NATS_READ_TIMEOUT_MS` (default `5000`)

In Icy, expose those values on the application service and point `NATS_HOST`
at the NATS service name on the shared deployment network. No localhost port
publishing is required between the services.

## Testing

`make check` runs deterministic protocol fixtures. `make test` additionally
starts a temporary `nats:2-alpine` server and verifies authentication,
publish/subscribe, protocol flushing, and a complete request/reply exchange;
for the async client it also restarts the server mid-run (reconnect), runs a
TLS server with a throwaway CA (verification passes, a wrong CA is refused),
and checks that a lookup against a nameserver that never answers leaves
`step(0)` nonblocking and then times out.

## Scope

This is a Core NATS client on the direct Linux TCP backend. The blocking
client is plain TCP; the async client adds TLS, reconnect server pools, and
nonblocking dispatch. NKeys/JWT and JetStream management are future layers. The parser already preserves headers and binary payloads for
those additions.

Licensed under the Mozilla Public License 2.0.
