begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(53);

select is(
  (
    select jsonb_build_array(
      center_rating,
      expected_score_scale,
      k_factor,
      placement_multiplier_1_3,
      placement_multiplier_4_7,
      placement_multiplier_8_10,
      placement_cap
    )
    from public.rating_parameter_sets
    where is_active
  ),
  '[1500, 250.0000, 64.0000, 2.000, 1.500, 1.250, 96]'::jsonb,
  'the reviewed rating-v1 parameter set is active'
);

select is(
  (
    select jsonb_build_array(master_minimum, master_maximum)
    from public.starting_rating_parameter_sets
    where is_active
  ),
  '[1800, 2200]'::jsonb,
  'the starting rating bounds are versioned'
);

select is(
  (select count(*) from public.seasons where status = 'active'),
  1::bigint,
  'the local seed creates one active season'
);

select throws_ok(
  $$
    insert into public.seasons (
      name,
      starts_at,
      ends_at,
      status
    )
    values (
      'Second active season',
      '2027-01-01 00:00:00+00',
      '2027-04-01 00:00:00+00',
      'active'
    )
  $$,
  '23505',
  null,
  'a second active season is rejected'
);

select throws_ok(
  $$
    insert into public.profiles (
      id,
      username,
      username_normalized,
      current_rating,
      placement_status,
      placement_completed_count,
      ranking_eligible,
      is_public
    )
    values (
      '00000000-0000-4000-8000-000000000299',
      'BrokenPlacement',
      'brokenplacement',
      1500,
      'completed',
      9,
      true,
      true
    )
  $$,
  '23514',
  null,
  'inconsistent placement completion is rejected'
);

insert into auth.users (
  id,
  instance_id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-4000-8000-000000000101',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'player-a@example.test',
    '',
    statement_timestamp(),
    '{}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000102',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'player-b@example.test',
    '',
    statement_timestamp(),
    '{}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000103',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'player-c@example.test',
    '',
    statement_timestamp(),
    '{}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'admin@example.test',
    '',
    statement_timestamp(),
    '{}'::jsonb,
    '{}'::jsonb,
    statement_timestamp(),
    statement_timestamp()
  );

insert into public.profiles (
  id,
  username,
  username_normalized,
  country_code,
  current_rating,
  placement_status,
  placement_completed_count,
  ranking_eligible,
  is_public
)
values
  (
    '00000000-0000-4000-8000-000000000201',
    'PlayerA',
    'playera',
    'JP',
    1500,
    'active',
    2,
    false,
    true
  ),
  (
    '00000000-0000-4000-8000-000000000202',
    'PlayerB',
    'playerb',
    'US',
    1600,
    'completed',
    10,
    true,
    true
  ),
  (
    '00000000-0000-4000-8000-000000000203',
    'PlayerC',
    'playerc',
    'JP',
    1400,
    'active',
    1,
    false,
    false
  ),
  (
    '00000000-0000-4000-8000-000000000204',
    null,
    null,
    null,
    null,
    'not_started',
    0,
    false,
    false
  );

insert into public.profile_accounts (
  profile_id,
  auth_user_id,
  application_role,
  account_status,
  onboarding_status,
  onboarding_current_step,
  onboarding_completed_at
)
values
  (
    '00000000-0000-4000-8000-000000000201',
    '00000000-0000-4000-8000-000000000101',
    'user',
    'active',
    'completed',
    3,
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000202',
    '00000000-0000-4000-8000-000000000102',
    'user',
    'active',
    'completed',
    3,
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000203',
    '00000000-0000-4000-8000-000000000103',
    'user',
    'active',
    'completed',
    3,
    statement_timestamp()
  ),
  (
    '00000000-0000-4000-8000-000000000204',
    '00000000-0000-4000-8000-000000000104',
    'admin',
    'active',
    'completed',
    3,
    statement_timestamp()
  );

insert into public.profile_sf6_identities (
  profile_id,
  sf6_player_name,
  sf6_user_code,
  sf6_user_code_normalized
)
values
  (
    '00000000-0000-4000-8000-000000000201',
    'SF6 Player A',
    '1111-1111-1111',
    '111111111111'
  ),
  (
    '00000000-0000-4000-8000-000000000202',
    'SF6 Player B',
    '2222-2222-2222',
    '222222222222'
  ),
  (
    '00000000-0000-4000-8000-000000000203',
    'SF6 Player C',
    '3333-3333-3333',
    '333333333333'
  );

insert into public.profile_private_details (profile_id, broad_region_code)
values
  ('00000000-0000-4000-8000-000000000201', 'jp-east'),
  ('00000000-0000-4000-8000-000000000202', 'us-west'),
  ('00000000-0000-4000-8000-000000000203', 'jp-west');

insert into public.matches (
  id,
  season_id,
  is_rated,
  creation_source,
  status,
  rating_status,
  rating_parameter_version,
  host_profile_id
)
values (
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000001',
  true,
  'quick_match',
  'matched',
  'pending',
  'rating-v1',
  '00000000-0000-4000-8000-000000000201'
);

insert into public.match_participants (
  match_id,
  profile_id,
  side,
  rating_snapshot,
  placement_status_snapshot,
  placement_completed_count_snapshot
)
values
  (
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000201',
    'player_a',
    1500,
    'active',
    2
  ),
  (
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000202',
    'player_b',
    1600,
    'completed',
    10
  );

set constraints all immediate;
set constraints all deferred;

select throws_ok(
  $$
    update public.match_participants
    set rating_snapshot = 9999
    where match_id = '00000000-0000-4000-8000-000000000301'
      and profile_id = '00000000-0000-4000-8000-000000000202'
  $$,
  '23514',
  null,
  'match participant identity and competitive snapshots are immutable'
);

select throws_ok(
  $$
    update public.matches
    set
      status = 'completed',
      resolution_type = 'normal',
      result_validity = 'valid',
      rating_status = 'applied',
      winner_profile_id = '00000000-0000-4000-8000-000000000201',
      loser_profile_id = '00000000-0000-4000-8000-000000000202',
      player_a_score = 3,
      player_b_score = 1
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'matched cannot skip directly to completed'
);

select throws_ok(
  $$
    update public.matches
    set
      status = 'cancelled',
      resolution_type = 'nonresponse_no_rating',
      rating_status = 'not_applicable'
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'matched cannot use the reporting-only nonresponse resolution'
);

select throws_ok(
  $$
    update public.matches
    set
      status = 'cancelled',
      resolution_type = null,
      rating_status = 'not_applicable'
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'a terminal transition cannot omit its resolution type'
);

insert into public.matches (
  id,
  season_id,
  is_rated,
  creation_source,
  status,
  rating_status,
  rating_parameter_version,
  host_profile_id
)
values (
  '00000000-0000-4000-8000-000000000302',
  '00000000-0000-4000-8000-000000000001',
  false,
  'find_opponent',
  'matched',
  'not_applicable',
  null,
  '00000000-0000-4000-8000-000000000203'
);

insert into public.match_participants (
  match_id,
  profile_id,
  side,
  rating_snapshot,
  placement_status_snapshot,
  placement_completed_count_snapshot
)
values (
  '00000000-0000-4000-8000-000000000302',
  '00000000-0000-4000-8000-000000000204',
  'player_b',
  1300,
  'not_started',
  0
);

select throws_ok(
  $$
    insert into public.match_participants (
      match_id,
      profile_id,
      side,
      rating_snapshot,
      placement_status_snapshot,
      placement_completed_count_snapshot
    )
    values (
      '00000000-0000-4000-8000-000000000302',
      '00000000-0000-4000-8000-000000000203',
      'player_a',
      1400,
      'completed',
      0
    )
  $$,
  '23514',
  null,
  'match participant placement status and count snapshots must agree'
);

select throws_ok(
  $$
    insert into public.match_participants (
      match_id,
      profile_id,
      side,
      rating_snapshot,
      placement_status_snapshot,
      placement_completed_count_snapshot
    )
    values (
      '00000000-0000-4000-8000-000000000302',
      '00000000-0000-4000-8000-000000000201',
      'player_a',
      1500,
      'active',
      2
    )
  $$,
  '23505',
  null,
  'one profile cannot be in two active matches'
);

select throws_ok(
  $$
    insert into public.result_reports (
      match_id,
      reporting_profile_id,
      report_type,
      reported_winner_profile_id,
      player_a_score,
      player_b_score,
      idempotency_key
    )
    values (
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000201',
      'normal',
      '00000000-0000-4000-8000-000000000202',
      3,
      1,
      'invalid-winner-score-orientation'
    )
  $$,
  '23514',
  null,
  'a normal report winner must be the side with three wins'
);

insert into public.result_reports (
  id,
  match_id,
  reporting_profile_id,
  report_type,
  reported_winner_profile_id,
  player_a_score,
  player_b_score,
  idempotency_key
)
values
  (
    '00000000-0000-4000-8000-000000000401',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000201',
    'normal',
    '00000000-0000-4000-8000-000000000201',
    3,
    1,
    'report-a-v1'
  ),
  (
    '00000000-0000-4000-8000-000000000402',
    '00000000-0000-4000-8000-000000000301',
    '00000000-0000-4000-8000-000000000202',
    'normal',
    '00000000-0000-4000-8000-000000000201',
    3,
    1,
    'report-b-v1'
  );

select throws_ok(
  $$
    insert into public.result_report_revisions (
      result_report_id,
      revision_number,
      reported_winner_profile_id,
      player_a_score,
      player_b_score
    )
    values (
      '00000000-0000-4000-8000-000000000401',
      1,
      '00000000-0000-4000-8000-000000000202',
      3,
      1
    )
  $$,
  '23514',
  null,
  'a normal report revision winner must be the side with three wins'
);

insert into public.result_report_revisions (
  id,
  result_report_id,
  revision_number,
  reported_winner_profile_id,
  player_a_score,
  player_b_score
)
values (
  '00000000-0000-4000-8000-000000000403',
  '00000000-0000-4000-8000-000000000401',
  1,
  '00000000-0000-4000-8000-000000000201',
  3,
  1
);

insert into public.waiting_entries (
  id,
  profile_id,
  mode,
  auto_match_eligible,
  rating_snapshot,
  placement_status_snapshot,
  placement_completed_count_snapshot,
  country_code_snapshot,
  broad_region_code_snapshot,
  started_at,
  expires_at
)
values (
  '00000000-0000-4000-8000-000000000601',
  '00000000-0000-4000-8000-000000000203',
  'quick_match',
  true,
  1400,
  'active',
  1,
  'JP',
  'jp-west',
  statement_timestamp(),
  statement_timestamp() + interval '10 minutes'
);

select throws_ok(
  $$
    insert into public.waiting_entries (
      profile_id,
      mode,
      auto_match_eligible,
      rating_snapshot,
      placement_status_snapshot,
      placement_completed_count_snapshot,
      country_code_snapshot,
      broad_region_code_snapshot,
      started_at,
      expires_at
    )
    values (
      '00000000-0000-4000-8000-000000000202',
      'quick_match',
      true,
      1600,
      'completed',
      0,
      'US',
      'us-west',
      statement_timestamp(),
      statement_timestamp() + interval '10 minutes'
    )
  $$,
  '23514',
  null,
  'waiting placement status and count snapshots must agree'
);

insert into public.rated_pair_cooldowns (
  profile_low_id,
  profile_high_id,
  source_match_id,
  last_rated_result_confirmed_at,
  next_rated_eligible_at
)
values (
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000202',
  '00000000-0000-4000-8000-000000000301',
  statement_timestamp(),
  statement_timestamp() + interval '24 hours'
);

insert into public.match_events (
  id,
  match_id,
  actor_profile_id,
  event_type,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000602',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000201',
  'match_created',
  'event-match-301-created'
);

insert into public.incidents (
  id,
  match_id,
  reporter_profile_id,
  subject_profile_id,
  incident_type,
  status,
  confirmed_at,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000603',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000202',
  'abandonment',
  'confirmed',
  statement_timestamp(),
  'incident-match-301-player-b'
);

insert into public.disputes (id, match_id, entry_reason)
values (
  '00000000-0000-4000-8000-000000000604',
  '00000000-0000-4000-8000-000000000301',
  'result_mismatch'
);

insert into public.user_restrictions (
  id,
  profile_id,
  status,
  reason_category,
  starts_at
)
values (
  '00000000-0000-4000-8000-000000000605',
  '00000000-0000-4000-8000-000000000202',
  'warning',
  'confirmed_reliability_incident',
  statement_timestamp()
);

insert into public.restriction_incidents (restriction_id, incident_id)
values (
  '00000000-0000-4000-8000-000000000605',
  '00000000-0000-4000-8000-000000000603'
);

insert into public.rating_corrections (
  id,
  source_match_id,
  profile_id,
  correction_type,
  original_rating_change,
  compensating_rating_change,
  reason_category
)
values (
  '00000000-0000-4000-8000-000000000606',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000202',
  'match_invalidation',
  -91,
  91,
  'test_rls_fixture'
);

insert into public.rating_history (
  profile_id,
  season_id,
  entry_type,
  rating_before,
  rounded_final_change,
  rating_after,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000202',
  '00000000-0000-4000-8000-000000000001',
  'initial_placement',
  1600,
  0,
  1600,
  'test-rls-history-player-b'
);

insert into public.admin_audit_logs (
  id,
  admin_profile_id,
  action,
  target_type,
  target_id,
  reason_category,
  match_id,
  incident_id,
  restriction_id,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000607',
  '00000000-0000-4000-8000-000000000204',
  'confirm_incident',
  'incident',
  '00000000-0000-4000-8000-000000000603',
  'test_rls_fixture',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000603',
  '00000000-0000-4000-8000-000000000605',
  'audit-confirm-incident-603'
);

set local role anon;

select results_eq(
  $$select count(*) from public.public_profiles$$,
  $$values (2::bigint)$$,
  'anon can only see public profiles'
);

select throws_ok(
  $$select count(*) from public.profile_accounts$$,
  '42501',
  null,
  'anon cannot read account mappings'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000101","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;

select is(
  private.current_profile_id(),
  '00000000-0000-4000-8000-000000000201'::uuid,
  'authenticated identity resolves to an immutable profile id'
);

select results_eq(
  $$select count(*) from public.profile_accounts$$,
  $$values (1::bigint)$$,
  'owner sees only their account mapping'
);

select results_eq(
  $$select count(*) from public.profile_sf6_identities$$,
  $$values (2::bigint)$$,
  'active participants can see both limited SF6 identities'
);

select results_eq(
  $$select count(*) from public.result_reports$$,
  $$values (1::bigint)$$,
  'blind result RLS hides the opponent report'
);

select is(
  (
    select jsonb_build_array(
      (select count(*) from public.waiting_entries),
      (select count(*) from public.rated_pair_cooldowns),
      (select count(*) from public.match_events),
      (select count(*) from public.incidents),
      (select count(*) from public.disputes),
      (select count(*) from public.user_restrictions),
      (select count(*) from public.restriction_incidents),
      (select count(*) from public.rating_corrections),
      (select count(*) from public.admin_audit_logs),
      (select count(*) from public.rating_history),
      (select count(*) from public.result_report_revisions),
      (select count(*) from public.active_match_private_profiles)
    )
  ),
  '[0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 2]'::jsonb,
  'participant RLS exposes only the documented cross-domain rows'
);

select throws_ok(
  $$update public.profiles set current_rating = 9999 where id = '00000000-0000-4000-8000-000000000201'$$,
  '42501',
  null,
  'authenticated users cannot directly mutate competitive state'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000103","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000103',
  true
);
set local role authenticated;

select results_eq(
  $$select count(*) from public.matches$$,
  $$values (0::bigint)$$,
  'nonparticipants cannot read a match'
);

select results_eq(
  $$select count(*) from public.profile_sf6_identities$$,
  $$values (1::bigint)$$,
  'nonparticipants cannot read another player SF6 identity'
);

select is(
  (
    select jsonb_build_array(
      (select count(*) from public.waiting_entries),
      (select count(*) from public.rated_pair_cooldowns),
      (select count(*) from public.match_events),
      (select count(*) from public.incidents),
      (select count(*) from public.disputes),
      (select count(*) from public.user_restrictions),
      (select count(*) from public.restriction_incidents),
      (select count(*) from public.rating_corrections),
      (select count(*) from public.admin_audit_logs),
      (select count(*) from public.rating_history),
      (select count(*) from public.result_report_revisions),
      (select count(*) from public.active_match_private_profiles)
    )
  ),
  '[1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]'::jsonb,
  'nonparticipant RLS exposes only the users own waiting entry'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000102","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000102',
  true
);
set local role authenticated;

select is(
  (
    select jsonb_build_array(
      (select count(*) from public.waiting_entries),
      (select count(*) from public.rated_pair_cooldowns),
      (select count(*) from public.match_events),
      (select count(*) from public.incidents),
      (select count(*) from public.disputes),
      (select count(*) from public.user_restrictions),
      (select count(*) from public.restriction_incidents),
      (select count(*) from public.rating_corrections),
      (select count(*) from public.admin_audit_logs),
      (select count(*) from public.rating_history),
      (select count(*) from public.result_report_revisions),
      (select count(*) from public.active_match_private_profiles)
    )
  ),
  '[0, 1, 1, 0, 0, 1, 0, 1, 0, 1, 0, 2]'::jsonb,
  'affected-player RLS exposes own restriction, correction, and rating rows'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000104","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000104',
  true
);
set local role authenticated;

select results_eq(
  $$select count(*) from public.profile_accounts$$,
  $$values (4::bigint)$$,
  'admin can read account mappings through the admin policy'
);

select results_eq(
  $$select count(*) from public.result_reports$$,
  $$values (2::bigint)$$,
  'admin can inspect both reports without weakening participant blindness'
);

select is(
  (
    select jsonb_build_array(
      (select count(*) from public.waiting_entries),
      (select count(*) from public.rated_pair_cooldowns),
      (select count(*) from public.match_events),
      (select count(*) from public.incidents),
      (select count(*) from public.disputes),
      (select count(*) from public.user_restrictions),
      (select count(*) from public.restriction_incidents),
      (select count(*) from public.rating_corrections),
      (select count(*) from public.admin_audit_logs),
      (select count(*) from public.rating_history),
      (select count(*) from public.result_report_revisions),
      (select count(*) from public.active_match_private_profiles)
    )
  ),
  '[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2]'::jsonb,
  'admin RLS can inspect every Phase 1 operational data category'
);

reset role;

insert into public.match_participants (
  match_id,
  profile_id,
  side,
  rating_snapshot,
  placement_status_snapshot,
  placement_completed_count_snapshot
)
values (
  '00000000-0000-4000-8000-000000000302',
  '00000000-0000-4000-8000-000000000203',
  'player_a',
  1400,
  'active',
  1
);

set constraints all immediate;

select throws_ok(
  $$
    update public.matches
    set
      status = 'cancelled',
      resolution_type = 'season_boundary_no_rating'
    where id = '00000000-0000-4000-8000-000000000302'
  $$,
  '23514',
  null,
  'season boundary no-rating close is limited to rated matches'
);

select is(
  (
    select is_new
    from private.claim_domain_action(
      'test.finalize',
      'request-1',
      'system',
      null,
      'hash-a'
    )
  ),
  true,
  'the first idempotency claim owns the action'
);

select is(
  (
    select is_new
    from private.claim_domain_action(
      'test.finalize',
      'request-1',
      'system',
      null,
      'hash-a'
    )
  ),
  false,
  'an identical retry reuses the action receipt'
);

select throws_ok(
  $$
    select *
    from private.claim_domain_action(
      'test.finalize',
      'request-1',
      'system',
      null,
      'hash-b'
    )
  $$,
  '22023',
  null,
  'an idempotency key cannot be reused for a different request'
);

select lives_ok(
  $$
    update public.matches
    set status = 'room_setup'
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  'matched can transition to room_setup'
);

select lives_ok(
  $$
    update public.matches
    set status = 'reporting'
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  'room_setup can transition to reporting'
);

select throws_ok(
  $$
    update public.matches
    set
      status = 'completed',
      resolution_type = 'admin_result',
      result_validity = 'valid',
      rating_status = 'applied',
      winner_profile_id = '00000000-0000-4000-8000-000000000201',
      loser_profile_id = '00000000-0000-4000-8000-000000000202',
      player_a_score = 3,
      player_b_score = 1
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'reporting cannot use the disputed-only admin result resolution'
);

select throws_ok(
  $$
    update public.matches
    set
      status = 'completed',
      resolution_type = null,
      result_validity = 'valid',
      rating_status = 'applied',
      winner_profile_id = '00000000-0000-4000-8000-000000000201',
      loser_profile_id = '00000000-0000-4000-8000-000000000202',
      player_a_score = 3,
      player_b_score = 1
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'a completed match cannot omit its resolution type'
);

select lives_ok(
  $$
    update public.matches
    set
      status = 'completed',
      resolution_type = 'normal',
      result_validity = 'valid',
      rating_status = 'applied',
      winner_profile_id = '00000000-0000-4000-8000-000000000201',
      loser_profile_id = '00000000-0000-4000-8000-000000000202',
      player_a_score = 3,
      player_b_score = 1
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  'a coherent normalized result can complete the match'
);

select results_eq(
  $$
    select count(*)
    from public.match_participants
    where match_id = '00000000-0000-4000-8000-000000000301'
      and not is_active
      and cleared_at is not null
  $$,
  $$values (2::bigint)$$,
  'terminal match transition atomically clears both active participant gates'
);

select throws_ok(
  $$
    update public.matches
    set status = 'reporting'
    where id = '00000000-0000-4000-8000-000000000301'
  $$,
  '23514',
  null,
  'a terminal match cannot be reopened'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-000000000101","role":"authenticated"}',
  true
);
select set_config(
  'request.jwt.claim.sub',
  '00000000-0000-4000-8000-000000000101',
  true
);
set local role authenticated;

select results_eq(
  $$select count(*) from public.profile_sf6_identities$$,
  $$values (1::bigint)$$,
  'terminal matches immediately revoke opponent SF6 identity access'
);

select results_eq(
  $$select count(*) from public.active_match_private_profiles$$,
  $$values (0::bigint)$$,
  'terminal matches disappear from the active private projection'
);

reset role;

update public.matches
set status = 'room_setup'
where id = '00000000-0000-4000-8000-000000000302';

update public.matches
set status = 'reporting'
where id = '00000000-0000-4000-8000-000000000302';

update public.matches
set status = 'disputed'
where id = '00000000-0000-4000-8000-000000000302';

select throws_ok(
  $$
    update public.matches
    set
      status = 'completed',
      resolution_type = 'normal',
      result_validity = 'valid',
      winner_profile_id = '00000000-0000-4000-8000-000000000203',
      loser_profile_id = '00000000-0000-4000-8000-000000000204',
      player_a_score = 3,
      player_b_score = 1
    where id = '00000000-0000-4000-8000-000000000302'
  $$,
  '23514',
  null,
  'disputed cannot bypass the admin result resolution'
);

update public.matches
set
  status = 'completed',
  resolution_type = 'admin_result',
  result_validity = 'valid',
  winner_profile_id = '00000000-0000-4000-8000-000000000203',
  loser_profile_id = '00000000-0000-4000-8000-000000000204',
  player_a_score = 3,
  player_b_score = 1
where id = '00000000-0000-4000-8000-000000000302';

update public.seasons
set
  status = 'completed',
  completed_at = statement_timestamp()
where id = '00000000-0000-4000-8000-000000000001';

insert into public.seasons (
  id,
  name,
  starts_at,
  ends_at,
  status
)
values (
  '00000000-0000-4000-8000-000000000002',
  'Completed Test Season',
  '2025-01-01 00:00:00+00',
  '2025-04-01 00:00:00+00',
  'upcoming'
);

insert into public.season_player_records (
  season_id,
  profile_id,
  current_rating,
  ranking_eligible,
  rated_wins,
  rated_losses,
  rated_match_count
)
values
  (
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000202',
    1600,
    true,
    1,
    0,
    1
  ),
  (
    '00000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-000000000203',
    1400,
    false,
    1,
    1,
    2
  );

update public.seasons
set status = 'active'
where id = '00000000-0000-4000-8000-000000000002';

set constraints
  season_player_records_require_matching_season_state,
  seasons_require_finalized_player_records
deferred;

update public.seasons
set
  status = 'completed',
  completed_at = statement_timestamp()
where id = '00000000-0000-4000-8000-000000000002';

update public.season_player_records
set
  record_status = 'finalized',
  final_rating = current_rating,
  final_ranking = case
    when ranking_eligible then 1
    else null
  end,
  final_rated_wins = rated_wins,
  final_rated_losses = rated_losses,
  final_rated_match_count = rated_match_count,
  final_win_rate = case
    when rated_match_count = 0 then 0
    else round(rated_wins::numeric / rated_match_count, 6)
  end,
  snapshot_at = statement_timestamp()
where season_id = '00000000-0000-4000-8000-000000000002';

set constraints
  season_player_records_require_matching_season_state,
  seasons_require_finalized_player_records
immediate;

select throws_ok(
  $$
    update public.season_player_records
    set final_rating = 1700
    where season_id = '00000000-0000-4000-8000-000000000002'
      and profile_id = '00000000-0000-4000-8000-000000000202'
  $$,
  '23514',
  null,
  'a finalized season snapshot cannot be changed'
);

select ok(
  exists (
    select 1
    from public.season_player_records
    where season_id = '00000000-0000-4000-8000-000000000002'
      and profile_id = '00000000-0000-4000-8000-000000000203'
      and record_status = 'finalized'
      and not ranking_eligible
      and final_ranking is null
  ),
  'an ineligible player can be finalized without a ranking position'
);

select throws_ok(
  $$
    insert into public.season_player_records (
      season_id,
      profile_id,
      record_status,
      current_rating,
      ranking_eligible,
      final_rating,
      final_rated_wins,
      final_rated_losses,
      final_rated_match_count,
      final_win_rate,
      snapshot_at
    )
    values (
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000204',
      'finalized',
      1300,
      false,
      1300,
      0,
      0,
      0,
      0,
      statement_timestamp()
    )
  $$,
  '23514',
  null,
  'a completed season cannot accept a later finalized snapshot row'
);

select throws_ok(
  $$
    insert into public.season_player_records (
      season_id,
      profile_id,
      record_status,
      current_rating,
      ranking_eligible
    )
    values (
      '00000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-000000000201',
      'live',
      1500,
      false
    )
  $$,
  '23514',
  null,
  'a completed season cannot accept a live player record'
);

select lives_ok(
  $$
    insert into public.rating_history (
      profile_id,
      match_id,
      season_id,
      entry_type,
      rating_before,
      opponent_rating_snapshot,
      expected_score,
      raw_base_change,
      placement_match_number,
      placement_multiplier,
      change_after_multiplier,
      cap_value,
      cap_applied,
      change_after_cap,
      rounded_final_change,
      rating_after,
      k_factor,
      expected_score_scale,
      parameter_version,
      idempotency_key
    )
    values (
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000001',
      'match_result',
      1500,
      1600,
      0.2857142857,
      45.71428571,
      3,
      2,
      91.42857142,
      96,
      false,
      91.42857142,
      91,
      1591,
      64,
      250,
      'rating-v1',
      'rating-match-301-player-a'
    )
  $$,
  'one rating history row can be recorded for a rated match participant'
);

select throws_ok(
  $$
    insert into public.rating_history (
      profile_id,
      match_id,
      season_id,
      entry_type,
      rating_before,
      opponent_rating_snapshot,
      expected_score,
      raw_base_change,
      placement_multiplier,
      change_after_multiplier,
      cap_applied,
      change_after_cap,
      rounded_final_change,
      rating_after,
      k_factor,
      expected_score_scale,
      parameter_version,
      idempotency_key
    )
    values (
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000301',
      '00000000-0000-4000-8000-000000000001',
      'match_result',
      1500,
      1600,
      0.2857142857,
      45.71428571,
      2,
      91.42857142,
      false,
      91.42857142,
      91,
      1591,
      64,
      250,
      'rating-v1',
      'rating-match-301-player-a-retry'
    )
  $$,
  '23505',
  null,
  'a rated match cannot create duplicate rating history for one player'
);

insert into public.rating_history (
  profile_id,
  season_id,
  entry_type,
  rating_before,
  rounded_final_change,
  rating_after,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000002',
  'season_reset',
  1591,
  -46,
  1545,
  'season-reset-002-player-a'
);

select throws_ok(
  $$
    insert into public.rating_history (
      profile_id,
      season_id,
      entry_type,
      rating_before,
      rounded_final_change,
      rating_after,
      idempotency_key
    )
    values (
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000002',
      'season_reset',
      1591,
      -46,
      1545,
      'season-reset-002-player-a-retry'
    )
  $$,
  '23505',
  null,
  'a season reset cannot be applied twice to one player'
);

insert into public.rating_corrections (
  id,
  source_match_id,
  profile_id,
  correction_type,
  original_rating_change,
  compensating_rating_change,
  reason_category,
  applied_at
)
values (
  '00000000-0000-4000-8000-000000000501',
  '00000000-0000-4000-8000-000000000301',
  '00000000-0000-4000-8000-000000000201',
  'match_invalidation',
  91,
  -91,
  'test_invalidation',
  statement_timestamp()
);

insert into public.rating_history (
  profile_id,
  season_id,
  entry_type,
  rating_before,
  rounded_final_change,
  rating_after,
  reason_category,
  correction_id,
  idempotency_key
)
values (
  '00000000-0000-4000-8000-000000000201',
  '00000000-0000-4000-8000-000000000001',
  'compensating_correction',
  1591,
  -91,
  1500,
  'test_invalidation',
  '00000000-0000-4000-8000-000000000501',
  'correction-501-player-a'
);

select throws_ok(
  $$
    insert into public.rating_history (
      profile_id,
      season_id,
      entry_type,
      rating_before,
      rounded_final_change,
      rating_after,
      reason_category,
      correction_id,
      idempotency_key
    )
    values (
      '00000000-0000-4000-8000-000000000201',
      '00000000-0000-4000-8000-000000000001',
      'compensating_correction',
      1591,
      -91,
      1500,
      'test_invalidation',
      '00000000-0000-4000-8000-000000000501',
      'correction-501-player-a-retry'
    )
  $$,
  '23505',
  null,
  'one correction cannot create duplicate rating history entries'
);

insert into public.seasons (
  id,
  name,
  starts_at,
  ends_at,
  status
)
values (
  '00000000-0000-4000-8000-000000000003',
  'Deferred Rollover Test Season',
  '2027-04-01 00:00:00+00',
  '2027-07-01 00:00:00+00',
  'upcoming'
);

insert into public.season_player_records (
  season_id,
  profile_id,
  current_rating,
  ranking_eligible
)
values (
  '00000000-0000-4000-8000-000000000003',
  '00000000-0000-4000-8000-000000000201',
  1500,
  false
);

update public.seasons
set status = 'active'
where id = '00000000-0000-4000-8000-000000000003';

set constraints
  season_player_records_require_matching_season_state,
  seasons_require_finalized_player_records
deferred;

update public.seasons
set
  status = 'completed',
  completed_at = statement_timestamp()
where id = '00000000-0000-4000-8000-000000000003';

select throws_ok(
  $$
    update public.season_player_records
    set
      record_status = 'finalized',
      final_rating = current_rating + 1,
      final_ranking = null,
      final_rated_wins = rated_wins,
      final_rated_losses = rated_losses,
      final_rated_match_count = rated_match_count,
      final_win_rate = 0,
      snapshot_at = statement_timestamp()
    where season_id = '00000000-0000-4000-8000-000000000003'
  $$,
  '23514',
  null,
  'final season snapshot values must match the frozen live values'
);

update public.season_player_records
set
  record_status = 'finalized',
  final_rating = current_rating,
  final_ranking = null,
  final_rated_wins = rated_wins,
  final_rated_losses = rated_losses,
  final_rated_match_count = rated_match_count,
  final_win_rate = 0,
  snapshot_at = statement_timestamp()
where season_id = '00000000-0000-4000-8000-000000000003';

set constraints
  season_player_records_require_matching_season_state,
  seasons_require_finalized_player_records
immediate;

select pass(
  'season rollover can defer the cyclic season and snapshot state checks atomically'
);

select * from finish();
rollback;
