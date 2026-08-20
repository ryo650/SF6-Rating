#!/usr/bin/env bash

set -euo pipefail

project_name="$(sed -n 's/^project_id = "\([^"]*\)"/\1/p' supabase/config.toml)"
database_container="${SUPABASE_DB_CONTAINER:-supabase_db_${project_name}}"
temporary_directory="$(mktemp -d)"

cleanup_sql="
begin;
set local session_replication_role = replica;
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
delete from public.match_participants
where match_id in (
  '40000000-0000-4000-8000-000000000100',
  '40000000-0000-4000-8000-000000000101'
);
delete from public.matches
where id in (
  '40000000-0000-4000-8000-000000000100',
  '40000000-0000-4000-8000-000000000101'
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
delete from private.sf6_user_code_claims
where live_profile_id in (
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
delete from private.account_deletion_jobs where profile_id in (select profile_id from phase2_cleanup_profiles);
delete from public.profile_accounts where profile_id in (select profile_id from phase2_cleanup_profiles);
delete from public.profiles where id in (select profile_id from phase2_cleanup_profiles);
delete from auth.users where id in (
  '40000000-0000-4000-8000-000000000001',
  '40000000-0000-4000-8000-000000000002',
  '40000000-0000-4000-8000-000000000003'
);
commit;
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
select public.phase2_save_account_step('40000000-0000-4000-8000-000000000001', 'ConcurrentComplete', 'concurrentcomplete', 'complete-account', repeat('a', 64));
select public.phase2_save_sf6_info_step('40000000-0000-4000-8000-000000000001', 'Concurrent', '9876543210', repeat('9', 64), 'JP', 'JP-KANTO', 'complete-sf6', repeat('b', 64));
"

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$setup_sql" >/dev/null

first_completion="
begin;
select public.phase2_complete_onboarding(
  '40000000-0000-4000-8000-000000000001', 'ryu', 'gold',
  3::smallint, null::integer, 'complete-race-a', repeat('c', 64), 'starting-rating-v2'
) ->> 'starting_rating';
select pg_sleep(2);
commit;
"
second_completion="
select public.phase2_complete_onboarding(
  '40000000-0000-4000-8000-000000000001', 'ryu', 'gold',
  3::smallint, null::integer, 'complete-race-b', repeat('d', 64), 'starting-rating-v2'
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

username_a="select public.phase2_save_account_step('40000000-0000-4000-8000-000000000002', 'ConcurrentName', 'concurrentname', 'name-race-a', repeat('e', 64));"
username_b="select public.phase2_save_account_step('40000000-0000-4000-8000-000000000003', 'CONCURRENTNAME', 'concurrentname', 'name-race-b', repeat('f', 64));"

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

prepare_sf6_race="
select public.phase2_save_account_step('40000000-0000-4000-8000-000000000002', 'CodeRaceA', 'coderacea', 'code-account-a', repeat('1', 64));
select public.phase2_save_account_step('40000000-0000-4000-8000-000000000003', 'CodeRaceB', 'coderaceb', 'code-account-b', repeat('2', 64));
"
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$prepare_sf6_race" >/dev/null

user_code_a="select public.phase2_save_sf6_info_step('40000000-0000-4000-8000-000000000002', 'Code Race A', '1234567890', repeat('7', 64), 'JP', 'JP-KANTO', 'code-race-a', repeat('3', 64));"
user_code_b="select public.phase2_save_sf6_info_step('40000000-0000-4000-8000-000000000003', 'Code Race B', '1234567890', repeat('7', 64), 'JP', 'JP-KANSAI', 'code-race-b', repeat('4', 64));"

set +e
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$user_code_a" >"$temporary_directory/code-a" 2>&1 &
code_a_pid=$!
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$user_code_b" >"$temporary_directory/code-b" 2>&1 &
code_b_pid=$!
wait "$code_a_pid"
code_a_status=$?
wait "$code_b_pid"
code_b_status=$?
set -e

if [[ "$code_a_status:$code_b_status" != "0:1" && "$code_a_status:$code_b_status" != "1:0" ]]; then
  echo "Expected one SF6 User Code winner and one reserved loser, got $code_a_status:$code_b_status" >&2
  exit 1
fi

user_code_count="$(docker exec "$database_container" psql -X -qAt -U postgres -d postgres -v ON_ERROR_STOP=1 -c "select count(*) from private.sf6_user_code_claims where code_digest = repeat('7', 64) and live_profile_id is not null;")"
if [[ "$user_code_count" != "1" ]]; then
  echo "Concurrent SF6 User Code race stored $user_code_count claims" >&2
  exit 1
fi

activate_second_participant="
do \$\$
begin
  if exists (
    select 1 from public.profile_accounts
    where auth_user_id = '40000000-0000-4000-8000-000000000002'
      and onboarding_current_step = 2
  ) then
    perform public.phase2_save_sf6_info_step(
      '40000000-0000-4000-8000-000000000002', 'Code Race A',
      '2234567890', repeat('8', 64), 'JP', 'JP-KANTO',
      'code-race-a-recovery', repeat('8', 64)
    );
  end if;
end;
\$\$;
select public.phase2_complete_onboarding(
  '40000000-0000-4000-8000-000000000002', 'ken', 'silver',
  3::smallint, null::integer, 'participant-complete', repeat('8', 64),
  'starting-rating-v2'
);
"
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$activate_second_participant" >/dev/null

match_activation="
begin;
insert into public.matches (
  id, season_id, is_rated, creation_source, status, rating_status,
  rating_parameter_version, host_profile_id
)
select
  '40000000-0000-4000-8000-000000000100',
  '00000000-0000-4000-8000-000000000001',
  true, 'quick_match', 'matched', 'pending', 'rating-v1', account.profile_id
from public.profile_accounts as account
where account.auth_user_id = '40000000-0000-4000-8000-000000000001';
insert into public.match_participants (
  match_id, profile_id, side, rating_snapshot,
  placement_status_snapshot, placement_completed_count_snapshot
)
select '40000000-0000-4000-8000-000000000100', profile.id, 'player_a',
  profile.current_rating, profile.placement_status, profile.placement_completed_count
from public.profiles as profile
join public.profile_accounts as account on account.profile_id = profile.id
where account.auth_user_id = '40000000-0000-4000-8000-000000000001';
insert into public.match_participants (
  match_id, profile_id, side, rating_snapshot,
  placement_status_snapshot, placement_completed_count_snapshot
)
select '40000000-0000-4000-8000-000000000100', profile.id, 'player_b',
  coalesce(profile.current_rating, 1000), profile.placement_status, profile.placement_completed_count
from public.profiles as profile
join public.profile_accounts as account on account.profile_id = profile.id
where account.auth_user_id = '40000000-0000-4000-8000-000000000002';
select pg_sleep(2);
commit;
"
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$match_activation" >"$temporary_directory/match-activation" &
match_pid=$!
sleep 0.2
set +e
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "select public.phase2_update_sf6_identity('40000000-0000-4000-8000-000000000001', 'Blocked By Concurrent Match', '9876543210', repeat('9', 64), 'match-race-identity', repeat('5', 64));" >"$temporary_directory/match-identity" 2>&1
identity_status=$?
set -e
wait "$match_pid"

if [[ "$identity_status" != "1" ]] || ! grep -q "sf6_identity_locked_by_active_match" "$temporary_directory/match-identity"; then
  echo "Concurrent Match activation did not block SF6 identity mutation" >&2
  exit 1
fi

deletion_request="
begin;
select public.phase2_request_account_deletion(
  '40000000-0000-4000-8000-000000000002',
  'deletion-match-race', repeat('6', 64)
);
select pg_sleep(2);
commit;
"
late_match="
begin;
insert into public.matches (
  id, season_id, is_rated, creation_source, status, rating_status,
  rating_parameter_version, host_profile_id
)
select
  '40000000-0000-4000-8000-000000000101',
  '00000000-0000-4000-8000-000000000001',
  true, 'quick_match', 'matched', 'pending', 'rating-v1', account.profile_id
from public.profile_accounts as account
where account.auth_user_id = '40000000-0000-4000-8000-000000000001';
insert into public.match_participants (
  match_id, profile_id, side, rating_snapshot,
  placement_status_snapshot, placement_completed_count_snapshot
)
select '40000000-0000-4000-8000-000000000101', profile.id, 'player_a',
  profile.current_rating, profile.placement_status, profile.placement_completed_count
from public.profiles as profile
join public.profile_accounts as account on account.profile_id = profile.id
where account.auth_user_id = '40000000-0000-4000-8000-000000000002';
commit;
"

docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$deletion_request" >"$temporary_directory/deletion-request" &
deletion_pid=$!
sleep 0.2
set +e
docker exec "$database_container" psql -X -qAt -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -c "$late_match" >"$temporary_directory/late-match" 2>&1
late_match_status=$?
set -e
wait "$deletion_pid"

if [[ "$late_match_status" != "1" ]] || ! grep -q "match_participant_active_account_required" "$temporary_directory/late-match"; then
  echo "Deletion/Match race allowed a deletion-pending participant" >&2
  exit 1
fi

echo "Phase 2 concurrency: PASS (completion, Username, User Code, Active Match identity lock, deletion/Match lock)"
