#!/usr/bin/env bash
set -euo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
compiler=${ABLAC:-$project_root/../ablac/build/ablac}
container="abla-nats-test-$$"
username='abla'
password='abla-test-secret'

cleanup() {
    docker rm -f "$container" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker run --rm --detach --name "$container" --publish 127.0.0.1::4222 \
    nats:2-alpine --user "$username" --pass "$password" >/dev/null
port=$(docker port "$container" 4222/tcp | awk -F: 'NR == 1 { print $NF }')

ready=false
for _ in $(seq 1 40); do
    if docker logs "$container" 2>&1 | grep -q 'Server is ready'; then
        ready=true
        break
    fi
    sleep 0.1
done
if [[ $ready != true ]]; then
    printf '%s\n' 'NATS test container did not become ready' >&2
    exit 1
fi

mkdir -p "$project_root/build"
"$compiler" build "$project_root/tests/integration_test.ab" \
    -o "$project_root/build/integration-test" --fast --no-cache
"$compiler" build "$project_root/tests/auth_failure_test.ab" \
    -o "$project_root/build/auth-failure-test" --fast --no-cache
NATS_HOST=127.0.0.1 NATS_PORT="$port" NATS_USERNAME="$username" \
    NATS_PASSWORD="$password" "$project_root/build/integration-test"
NATS_HOST=127.0.0.1 NATS_PORT="$port" NATS_USERNAME="$username" \
    NATS_PASSWORD=definitely-wrong "$project_root/build/auth-failure-test"

printf '%s\n' 'NATS authentication rejection, publish/subscribe, flush, and request/reply passed'
