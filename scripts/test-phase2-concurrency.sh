#!/usr/bin/env bash

set -euo pipefail

project_name="$(sed -n 's/^project_id = "\([^"]*\)"/\1/p' supabase/config.toml)"
database_container="${SUPABASE_DB_CONTAINER:-supabase_db_${project_name}}"
temporary_directory="$(mktemp -d)"

cleanup_sql="
delete from private.domain_action_receipts
where actor_identity in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);
delete from private.action_rate_limits
where actor_key in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);
delete from public.rating_history
where profile_id in (
  select profile_id from public.profile_accounts
  where auth_user_id in (
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003'
  )
);
delete from public.placement_initializations
where profile_id in (
  select profile_id from public.profile_accounts
  where auth_user_id in (
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003'
  )
);
delete from public.profile_sf6_identities
where profile_id in (
  select profile_id from public.profile_accounts
  where auth_user_id in (
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003'
  )
);
delete from public.profile_private_details
where profile_id in (
  select profile_id from public.profile_accounts
  where auth_user_id in (
    '40000000-0000-4000-8000-000000000001',
    '40000000-0000-4000-8000-000000000002',
    '40000000-0000-4000-8000-000000000003'
  )
);
create temporary table if not exists phase2_cleanup_profiles on commit drop as
select profile_id from public.profile_accounts
where auth_user_id in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);
delete from public.profile_accounts where profile_id in (select profile_id from phase2_cleanup_profiles);
delete from public.profiles where id in (select profile_id from phase2_cleanup_profiles);
delete from auth.users where id in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);
"

cleanup() {
  docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
    -v ON_ERROR_STOP=1 -c "$cleanup_sql" >/dev/null 2>&1 || true
  rm -rf "$temporary_directory"
}

trap cleanup EXIT

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$cleanup_sql" >/dev/null

setup_sql="
insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('40000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-complete@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('40000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-name-a@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('40000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'concurrent-name-b@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp());
select public.phase2_save_account_step('40000000-0000-4000-8000-000000000001', 'ConcurrentComplete', 'concurrentcomplete', null, 'complete-account', repeat('a', 64));
select public.phase2_save_sf6_info_step('40000000-0000-4000-8000-000000000001', 'Concurrent', '9876543210', repeat('9', 64), 'JP', 'JP-KANTO', 'complete-sf6', repeat('b', 64));
"

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$setup_sql" >/dev/null

first_completion="
begin;
select public.phase2_complete_onboarding(
  '40000000-0000-4000-8000-000000000001', 'ryu', 'gold',
  3::smallint, null::integer, 'complete-race-a', repeat('c', 64)
) ->> 'starting_rating';
select pg_sleep(2);
commit;
"
second_completion="
select public.phase2_complete_onboarding(
  '40000000-0000-4000-8000-000000000001', 'ryu', 'gold',
  3::smallint, null::integer, 'complete-race-b', repeat('d', 64)
) ->> 'starting_rating';
"

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$first_completion" >"$temporary_directory/complete-first" &
first_pid=$!
sleep 0.2
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$second_completion" >"$temporary_directory/complete-second" &
second_pid=$!
wait "$first_pid"
wait "$second_pid"

completion_counts="$(docker exec "$database_container" psql -X -qAt -U postgres -d postgres -v ON_ERROR_STOP=1 -c "
select
  (select count(*) from public.placement_initializations where profile_id = (select profile_id from public.profile_accounts where auth_user_id = '40000000-0000-4000-8000-000000000001'))::text
  || ':' ||
  (select count(*) from public.rating_history where profile_id = (select profile_id from public.profile_accounts where auth_user_id = '40000000-0000-4000-8000-000000000001') and entry_type = 'initial_placement')::text;
")"

if [[ "$completion_counts" != "1:1" ]]; then
  echo "Concurrent completion created unexpected rows: $completion_counts" >&2
  exit 1
fi

username_a="select public.phase2_save_account_step('40000000-0000-4000-8000-000000000002', 'ConcurrentName', 'concurrentname', null, 'name-race-a', repeat('e', 64));"
username_b="select public.phase2_save_account_step('40000000-0000-4000-8000-000000000003', 'CONCURRENTNAME', 'concurrentname', null, 'name-race-b', repeat('f', 64));"

set +e
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$username_a" >"$temporary_directory/name-a" 2>&1 &
name_a_pid=$!
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$username_b" >"$temporary_directory/name-b" 2>&1 &
name_b_pid=$!
wait "$name_a_pid"
name_a_status=$?
wait "$name_b_pid"
name_b_status=$?
set -e

if [[ "$name_a_status:$name_b_status" != "0:1" && "$name_a_status:$name_b_status" != "1:0" ]]; then
  echo "Expected one Username winner and one unique-conflict loser, got $name_a_status:$name_b_status" >&2
  exit 1
fi

username_count="$(docker exec "$database_container" psql -X -qAt -U postgres -d postgres -v ON_ERROR_STOP=1 -c "select count(*) from public.profiles where username_normalized = 'concurrentname';")"
if [[ "$username_count" != "1" ]]; then
  echo "Concurrent Username race stored $username_count rows" >&2
  exit 1
fi

echo "Phase 2 concurrency: PASS (single completion, single normalized Username winner)"

