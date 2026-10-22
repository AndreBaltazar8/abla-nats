#!/usr/bin/env bash
# Runs tests/async_test.ab against a temporary token-protected nats:2-alpine.
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compiler=${ABLAC:-ablac}
container="abla-nats-async-test-$$"
token='abla-async-token'

certs=$(mktemp -d)
cleanup() {
    docker rm -f "$container" "$container-tls" >/dev/null 2>&1 || true
    rm -rf "$certs"
}
trap cleanup EXIT

# a fixed host port, so the restart below keeps it
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
docker run --detach --name "$container" --publish "127.0.0.1:$port:4222" \
    nats:2-alpine --auth "$token" >/dev/null
wait_ready() {
    for _ in $(seq 1 50); do
        if [[ $(docker logs "$container" 2>&1 | grep -c 'Server is ready') -ge $1 ]]; then return; fi
        sleep 0.1
    done
}
wait_ready 1

mkdir -p "$project_root/build"
"$compiler" build "$project_root/tests/async_test.ab" -o "$project_root/build/async-test" --fast --no-cache
NATS_PORT="$port" NATS_TOKEN="$token" "$project_root/build/async-test"

"$compiler" build "$project_root/tests/async_reconnect_test.ab" -o "$project_root/build/async-reconnect-test" --fast --no-cache
NATS_PORT="$port" NATS_TOKEN="$token" "$project_root/build/async-reconnect-test" &
tester=$!
sleep 2
docker restart --time 0 "$container" >/dev/null
wait "$tester"

# TLS: a throwaway CA signs a localhost server certificate; a second CA is the untrusted one
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=abla test ca' \
    -keyout "$certs/ca.key" -out "$certs/ca.pem" 2>/dev/null
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj '/CN=other ca' \
    -keyout "$certs/other.key" -out "$certs/other.pem" 2>/dev/null
openssl req -newkey rsa:2048 -nodes -subj '/CN=localhost' \
    -keyout "$certs/server.key" -out "$certs/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:localhost\n' > "$certs/san.ext"
openssl x509 -req -in "$certs/server.csr" -CA "$certs/ca.pem" -CAkey "$certs/ca.key" -CAcreateserial \
    -days 1 -extfile "$certs/san.ext" -out "$certs/server.pem" 2>/dev/null
chmod 644 "$certs"/*
tls_port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
docker run --rm --detach --name "$container-tls" --publish "127.0.0.1:$tls_port:4222" -v "$certs:/certs:ro" \
    nats:2-alpine --auth "$token" --tls --tlscert /certs/server.pem --tlskey /certs/server.key >/dev/null
for _ in $(seq 1 50); do
    if docker logs "$container-tls" 2>&1 | grep -q 'Server is ready'; then break; fi
    sleep 0.1
done
"$compiler" build "$project_root/tests/async_tls_test.ab" -o "$project_root/build/async-tls-test" --fast --no-cache
NATS_TLS_PORT="$tls_port" NATS_TOKEN="$token" NATS_CA="$certs/ca.pem" NATS_OTHER_CA="$certs/other.pem" \
    "$project_root/build/async-tls-test"

printf '%s\n' 'NATS async buffering, replayed subscriptions, delivery limits, request/reply, nonblocking DNS, reconnect, and TLS passed'
