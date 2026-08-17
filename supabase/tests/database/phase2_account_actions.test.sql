begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(31);

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-a@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('20000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-b@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('20000000-0000-4000-8000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-unverified@example.test', '', null, '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('20000000-0000-4000-8000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-delete@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('20000000-0000-4000-8000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'phase2-reclaim@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp());

select is(
  public.phase2_save_account_step('20000000-0000-4000-8000-000000000001', 'プレイヤーA', 'プレイヤーa', null, 'a-account', repeat('a', 64)) ->> 'current_step',
  '2',
  'Account step advances to Step 2'
);
select is(
  public.phase2_save_account_step('20000000-0000-4000-8000-000000000001', 'プレイヤーA', 'プレイヤーa', null, 'a-account', repeat('a', 64)) ->> 'current_step',
  '2',
  'Account step retry returns the stored response'
);
select is(
  (select count(*) from private.domain_action_receipts where action_scope = 'phase2.onboarding.account' and actor_identity = '20000000-0000-4000-8000-000000000001'),
  1::bigint,
  'Account step retry creates one receipt'
);

do $$
begin
  perform public.phase2_save_account_step('20000000-0000-4000-8000-000000000002', 'PlayerB', 'playerb', null, 'b-account', repeat('b', 64));
  perform public.phase2_save_account_step('20000000-0000-4000-8000-000000000003', 'PlayerC', 'playerc', null, 'c-account', repeat('c', 64));
  perform public.phase2_save_account_step('20000000-0000-4000-8000-000000000004', 'DeleteMe', 'deleteme', null, 'd-account', repeat('d', 64));
  perform public.phase2_save_account_step('20000000-0000-4000-8000-000000000005', 'ReclaimTest', 'reclaimtest', null, 'e-account', repeat('e', 64));
end;
$$;

select throws_ok(
  $$select public.phase2_save_account_step('20000000-0000-4000-8000-000000000002', 'PLAYERB', 'プレイヤーa', null, 'b-account-conflict', repeat('f', 64))$$,
  '23505', null, 'normalized Username uniqueness rejects a competing account'
);

select is(
  public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000001', 'SF6 A', '1111111111', repeat('1', 64), 'JP', 'JP-KANTO', 'a-sf6', repeat('1', 64)) ->> 'current_step',
  '3',
  'SF6 info step advances to Step 3'
);
do $$
begin
  perform public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000002', 'SF6 A', '2222222222', repeat('2', 64), 'US', 'US-ALL', 'b-sf6', repeat('2', 64));
  perform public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000003', 'SF6 C', '3333333333', repeat('3', 64), 'JP', 'JP-KANSAI', 'c-sf6', repeat('3', 64));
  perform public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000004', 'SF6 D', '4444444444', repeat('4', 64), 'JP', 'JP-TOHOKU', 'd-sf6', repeat('4', 64));
end;
$$;

select throws_ok(
  $$select public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000005', 'Duplicate allowed', '1111111111', repeat('1', 64), 'JP', 'JP-HOKKAIDO', 'e-sf6-conflict', repeat('5', 64))$$,
  '23505', null, 'normalized SF6 User Code uniqueness rejects a competing account'
);

select is(
  public.phase2_preview_starting_rating('20000000-0000-4000-8000-000000000001', 'ryu', 'master', null::smallint, 1) ->> 'starting_rating',
  '1800',
  'Master preview clamps the low boundary to 1800'
);
select is(
  public.phase2_preview_starting_rating('20000000-0000-4000-8000-000000000001', 'ryu', 'master', null::smallint, 5000) ->> 'starting_rating',
  '2200',
  'Master preview clamps the high boundary to 2200'
);
select throws_ok(
  $$select public.phase2_preview_starting_rating('20000000-0000-4000-8000-000000000001', 'ryu', 'master', null::smallint, 0)$$,
  '22023', 'invalid_master_rating', 'MR below the configured range is rejected'
);

select is(
  public.phase2_complete_onboarding('20000000-0000-4000-8000-000000000001', 'ryu', 'diamond', 5::smallint, null::integer, 'a-complete', repeat('6', 64)) ->> 'starting_rating',
  '1690',
  'non-Master Starting Rating uses the reviewed base and tier adjustment'
);
select is(
  public.phase2_complete_onboarding('20000000-0000-4000-8000-000000000001', 'ryu', 'diamond', 5::smallint, null::integer, 'a-complete', repeat('6', 64)) ->> 'starting_rating',
  '1690',
  'completion retry returns the same Starting Rating'
);
select is((select count(*) from public.placement_initializations where profile_id = (select profile_id from public.profile_accounts where auth_user_id = '20000000-0000-4000-8000-000000000001')), 1::bigint, 'completion creates one Placement initialization');
select is((select count(*) from public.rating_history where profile_id = (select profile_id from public.profile_accounts where auth_user_id = '20000000-0000-4000-8000-000000000001') and entry_type = 'initial_placement'), 1::bigint, 'completion creates one initial Rating history entry');
select is((select placement_status from public.profiles where id = (select profile_id from public.profile_accounts where auth_user_id = '20000000-0000-4000-8000-000000000001')), 'active'::public.placement_status, 'completion starts Placement');
select ok((select is_public from public.profiles where id = (select profile_id from public.profile_accounts where auth_user_id = '20000000-0000-4000-8000-000000000001')), 'completion publishes the Profile');

select throws_ok(
  $$select public.phase2_complete_onboarding('20000000-0000-4000-8000-000000000003', 'cammy', 'gold', 3::smallint, null::integer, 'c-complete', repeat('7', 64))$$,
  '42501', 'email_verification_required', 'an unverified Email account cannot complete onboarding'
);

select is(
  public.phase2_update_username('20000000-0000-4000-8000-000000000001', 'PlayerA2', 'playera2', 'a-username-1', repeat('8', 64)) ->> 'username',
  'PlayerA2',
  'the first post-onboarding Username change succeeds'
);
select throws_ok(
  $$select public.phase2_update_username('20000000-0000-4000-8000-000000000001', 'PlayerA3', 'playera3', 'a-username-2', repeat('9', 64))$$,
  '23514', 'username_cooldown', 'a second Username change inside 30 days is rejected'
);

do $$
begin
  perform public.phase2_update_sf6_identity('20000000-0000-4000-8000-000000000001', 'SF6 A renamed', '1111111112', repeat('a', 64), 'a-code-1', repeat('a', 64));
end;
$$;
select is(
  public.phase2_update_sf6_identity('20000000-0000-4000-8000-000000000001', 'SF6 A name only', '1111111112', repeat('a', 64), 'a-name-only', repeat('b', 64)) ->> 'sf6_player_name',
  'SF6 A name only',
  'Player Name can change without consuming another User Code cooldown'
);
select throws_ok(
  $$select public.phase2_update_sf6_identity('20000000-0000-4000-8000-000000000001', 'SF6 A', '1111111113', repeat('c', 64), 'a-code-2', repeat('c', 64))$$,
  '23514', 'sf6_user_code_cooldown', 'a second User Code change inside 30 days is rejected'
);

do $$
begin
  perform public.phase2_complete_onboarding('20000000-0000-4000-8000-000000000002', 'ken', 'rookie', 1::smallint, null::integer, 'b-complete', repeat('d', 64));
end;
$$;

insert into public.matches (
  id, season_id, is_rated, creation_source, status, rating_status,
  rating_parameter_version, host_profile_id
)
select
  '20000000-0000-4000-8000-000000000100',
  '00000000-0000-4000-8000-000000000001',
  true, 'quick_match', 'matched', 'pending', 'rating-v1', account.profile_id
from public.profile_accounts as account
where account.auth_user_id = '20000000-0000-4000-8000-000000000001';
insert into public.match_participants (match_id, profile_id, side, rating_snapshot, placement_status_snapshot, placement_completed_count_snapshot)
select '20000000-0000-4000-8000-000000000100', account.profile_id, 'player_a', 1690, 'active', 0
from public.profile_accounts as account where account.auth_user_id = '20000000-0000-4000-8000-000000000001';
insert into public.match_participants (match_id, profile_id, side, rating_snapshot, placement_status_snapshot, placement_completed_count_snapshot)
select '20000000-0000-4000-8000-000000000100', account.profile_id, 'player_b', 860, 'active', 0
from public.profile_accounts as account where account.auth_user_id = '20000000-0000-4000-8000-000000000002';

select throws_ok(
  $$select public.phase2_update_sf6_identity('20000000-0000-4000-8000-000000000001', 'Blocked in match', '1111111112', repeat('a', 64), 'a-active-match', repeat('e', 64))$$,
  '23514', 'sf6_identity_locked_by_active_match', 'Active Match blocks Player Name and User Code edits'
);
select is(
  public.phase2_request_account_deletion('20000000-0000-4000-8000-000000000001', 'a-delete-blocked', repeat('f', 64)) ->> 'ready_to_finalize',
  'false',
  'Active Match keeps deletion pending instead of anonymizing immediately'
);

do $$
begin
  perform public.phase2_complete_onboarding('20000000-0000-4000-8000-000000000004', 'chun-li', 'master', null::smallint, 1500, 'd-complete', repeat('0', 64));
end;
$$;
select is(
  public.phase2_request_account_deletion('20000000-0000-4000-8000-000000000004', 'd-delete', repeat('1', 64)) ->> 'ready_to_finalize',
  'true',
  'an account without blockers is ready to finalize'
);
select is(
  cardinality(public.phase2_detach_avatars_for_deletion('20000000-0000-4000-8000-000000000004')),
  0,
  'deletion safely handles an account without uploaded Avatar objects'
);

create temporary table phase2_deletion_result on commit drop as
select public.phase2_prepare_account_anonymization(
  '20000000-0000-4000-8000-000000000004', repeat('4', 64),
  'd-anonymize', repeat('2', 64)
) as payload;

select is((select account_status from public.profile_accounts where profile_id = ((select payload ->> 'profile_id' from phase2_deletion_result))::uuid), 'anonymized'::public.account_status, 'deletion anonymizes the application account');
select is((select sf6_user_code from public.profile_sf6_identities where profile_id = ((select payload ->> 'profile_id' from phase2_deletion_result))::uuid), null, 'deletion removes the raw SF6 User Code');
select is((select count(*) from public.rating_history where profile_id = ((select payload ->> 'profile_id' from phase2_deletion_result))::uuid), 1::bigint, 'deletion retains anonymous Rating History');
select is((select count(*) from private.deleted_user_code_reclaims where deleted_profile_id = ((select payload ->> 'profile_id' from phase2_deletion_result))::uuid and released_at is null), 1::bigint, 'deletion reserves the keyed User Code digest');

do $$
begin
  perform public.phase2_save_sf6_info_step('20000000-0000-4000-8000-000000000005', 'Reclaim E', '4444444444', repeat('5', 64), 'JP', 'JP-HOKKAIDO', 'e-sf6-own', repeat('3', 64));
end;
$$;
select throws_ok(
  $$select public.phase2_update_sf6_identity('20000000-0000-4000-8000-000000000005', 'Reclaim E', '4444444444', repeat('4', 64), 'e-reclaim-blocked', repeat('4', 64))$$,
  '23505', 'sf6_user_code_reserved', 'a deleted User Code digest cannot be automatically reclaimed'
);

select is(
  public.phase2_mark_auth_deletion_failed(((select payload ->> 'job_id' from phase2_deletion_result))::uuid, 'injected_failure') ->> 'status',
  'failed',
  'Auth deletion failure is recorded for retry'
);
select is(
  public.phase2_mark_auth_deletion_complete(((select payload ->> 'job_id' from phase2_deletion_result))::uuid) ->> 'status',
  'completed',
  'a retry can complete a previously failed Auth deletion job'
);

select * from finish();
rollback;
