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
- environment and secret-file configuration.

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

Publishing and request/reply use the same connection:

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
publish/subscribe, protocol flushing, and a complete request/reply exchange.

## Scope

This is a Core NATS client on the direct Linux TCP backend. TLS, NKeys/JWT,
JetStream management, reconnect server pools, and asynchronous dispatch are
future layers. The parser already preserves headers and binary payloads for
those additions.

Licensed under the Mozilla Public License 2.0.
