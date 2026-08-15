#!/usr/bin/env bash

set -euo pipefail

project_name="$(sed -n 's/^project_id = "\([^"]*\)"/\1/p' supabase/config.toml)"

if [[ -z "$project_name" ]]; then
  echo "Could not resolve project_id from supabase/config.toml" >&2
  exit 1
fi

database_container="${SUPABASE_DB_CONTAINER:-supabase_db_${project_name}}"
temporary_directory="$(mktemp -d)"
action_scope="phase1.concurrency"
idempotency_key="simultaneous-claim"

cleanup() {
  docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
    -c "delete from private.domain_action_receipts where action_scope = '$action_scope' and idempotency_key = '$idempotency_key';" \
    >/dev/null 2>&1 || true
  rm -rf "$temporary_directory"
}

trap cleanup EXIT

if ! docker inspect "$database_container" >/dev/null 2>&1; then
  echo "Local Supabase database container is not running: $database_container" >&2
  exit 1
fi

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 \
  -c "delete from private.domain_action_receipts where action_scope = '$action_scope' and idempotency_key = '$idempotency_key';" \
  >/dev/null

claim_sql="
with claimed as materialized (
  select is_new
  from private.claim_domain_action(
    '$action_scope',
    '$idempotency_key',
    'system',
    null,
    'same-request-hash'
  )
), held as materialized (
  select pg_sleep(2)
  from claimed
  where is_new
)
select claimed.is_new::text
from claimed
left join held on true;
"

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$claim_sql" >"$temporary_directory/first" &
first_pid=$!

sleep 0.2

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$claim_sql" >"$temporary_directory/second" &
second_pid=$!

wait "$first_pid"
wait "$second_pid"

actual_results="$(sort "$temporary_directory/first" "$temporary_directory/second" | tr '\n' ' ')"

if [[ "$actual_results" != "false true " ]]; then
  echo "Expected one new and one reused concurrent claim, received: $actual_results" >&2
  exit 1
fi

echo "Concurrent idempotency claim: PASS (one new, one reused)"
