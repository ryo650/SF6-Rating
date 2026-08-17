-- Phase 2: trusted service-role domain actions. Browser roles never receive
-- direct write privileges; every action re-resolves the actor through the
-- Auth-to-profile mapping and rechecks current database state.

create or replace function private.require_phase2_actor(
  requested_actor_auth_user_id uuid
)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  resolved_profile_id uuid;
begin
  select account.profile_id
  into resolved_profile_id
  from public.profile_accounts as account
  where account.auth_user_id = requested_actor_auth_user_id
    and account.account_status <> 'anonymized';

  if resolved_profile_id is null then
    raise exception using
      errcode = '42501',
      message = 'actor is not mapped to an active application account';
  end if;

  return resolved_profile_id;
end;
$$;

create or replace function private.consume_phase2_rate_limit(
  requested_actor_key text,
  requested_action_name text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  rule private.action_rate_limit_rules%rowtype;
  current_window timestamptz;
  observed_count integer;
begin
  select configured_rule.*
  into strict rule
  from private.action_rate_limit_rules as configured_rule
  where configured_rule.action_name = requested_action_name;

  current_window := date_bin(
    make_interval(secs => rule.window_seconds),
    statement_timestamp(),
    '2000-01-01 00:00:00+00'::timestamptz
  );

  insert into private.action_rate_limits (
    actor_key,
    action_name,
    window_started_at,
    request_count
  )
  values (
    requested_actor_key,
    requested_action_name,
    current_window,
    1
  )
  on conflict (actor_key, action_name, window_started_at)
  do update set
    request_count = private.action_rate_limits.request_count + 1,
    updated_at = statement_timestamp()
  returning request_count into observed_count;

  if observed_count > rule.max_requests then
    raise exception using
      errcode = 'P0001',
      message = 'rate_limit_exceeded';
  end if;
end;
$$;

create or replace function private.phase2_has_active_match(
  requested_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.match_participants as participant
    join public.matches as match on match.id = participant.match_id
    where participant.profile_id = requested_profile_id
      and participant.is_active
      and match.status in ('matched', 'room_setup', 'reporting', 'disputed')
  );
$$;

create or replace function private.phase2_deletion_blockers(
  requested_profile_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_agg(blocker order by blocker), '[]'::jsonb)
  from (
    select 'active_match'::text as blocker
    where private.phase2_has_active_match(requested_profile_id)
    union all
    select 'unresolved_result'::text
    where exists (
      select 1
      from public.result_reports as report
      join public.matches as match on match.id = report.match_id
      where report.reporting_profile_id = requested_profile_id
        and report.status in ('submitted', 'mismatch_review')
        and match.status not in ('completed', 'cancelled')
    )
    union all
    select 'open_dispute'::text
    where exists (
      select 1
      from public.disputes as dispute
      join public.match_participants as participant
        on participant.match_id = dispute.match_id
      where participant.profile_id = requested_profile_id
        and dispute.status = 'open'
    )
  ) as blockers;
$$;

create or replace function private.phase2_assert_user_code_available(
  requested_code_digest text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if requested_code_digest !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'invalid_user_code_digest';
  end if;

  if exists (
    select 1
    from private.deleted_user_code_reclaims as reclaim
    where reclaim.code_digest = requested_code_digest
      and reclaim.released_at is null
  ) then
    raise exception using errcode = '23505', message = 'sf6_user_code_reserved';
  end if;
end;
$$;

create or replace function private.phase2_calculate_starting_rating(
  requested_rank public.sf6_rank,
  requested_rank_tier smallint,
  requested_master_rating integer
)
returns table (
  starting_rating integer,
  source public.starting_rating_source,
  parameter_version text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  parameter public.starting_rating_parameter_sets%rowtype;
  calculated numeric;
begin
  select configured_parameter.*
  into strict parameter
  from public.starting_rating_parameter_sets as configured_parameter
  where configured_parameter.is_active;

  if requested_rank = 'master' then
    if requested_rank_tier is not null
      or requested_master_rating is null
      or requested_master_rating < parameter.mr_validation_minimum
      or requested_master_rating > parameter.mr_validation_maximum
    then
      raise exception using errcode = '22023', message = 'invalid_master_rating';
    end if;

    calculated := parameter.master_base_rating
      + parameter.master_mr_coefficient
      * (requested_master_rating - parameter.master_mr_center);

    return query select
      round(least(
        parameter.master_maximum::numeric,
        greatest(parameter.master_minimum::numeric, calculated)
      ))::integer,
      'master_rating'::public.starting_rating_source,
      parameter.version;
    return;
  end if;

  if requested_rank_tier is null
    or requested_rank_tier not between 1 and 5
    or requested_master_rating is not null
    or not (parameter.rank_base_ratings ? requested_rank::text)
  then
    raise exception using errcode = '22023', message = 'invalid_rank_setup';
  end if;

  return query select
    (parameter.rank_base_ratings ->> requested_rank::text)::integer
      + (parameter.subrank_adjustments ->> requested_rank_tier::text)::integer,
    'rank'::public.starting_rating_source,
    parameter.version;
end;
$$;

create or replace function private.phase2_claim_action(
  requested_scope text,
  requested_key text,
  requested_actor_auth_user_id uuid,
  requested_profile_id uuid,
  requested_hash text
)
returns table (
  receipt_id uuid,
  is_new boolean,
  receipt_status public.domain_action_status,
  response_payload jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if requested_key is null or btrim(requested_key) = '' then
    raise exception using errcode = '22023', message = 'idempotency_key_required';
  end if;

  if requested_hash !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'invalid_request_hash';
  end if;

  return query
  select claimed.receipt_id, claimed.is_new, claimed.receipt_status, claimed.response_payload
  from private.claim_domain_action(
    requested_scope,
    requested_key,
    requested_actor_auth_user_id::text,
    requested_profile_id,
    requested_hash
  ) as claimed;
end;
$$;

create or replace function public.phase2_onboarding_state(
  requested_actor_auth_user_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  result jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);

  select jsonb_build_object(
    'profile_id', profile.id,
    'account_status', account.account_status,
    'onboarding_status', account.onboarding_status,
    'current_step', account.onboarding_current_step,
    'username', profile.username,
    'avatar_url', profile.avatar_url,
    'avatar_source', profile.avatar_source,
    'country_code', profile.country_code,
    'sf6_player_name', identity.sf6_player_name,
    'sf6_user_code', identity.sf6_user_code,
    'broad_region_code', detail.broad_region_code,
    'main_character_code', detail.main_character_code,
    'sf6_rank', detail.current_sf6_rank,
    'sf6_rank_tier', detail.current_sf6_rank_tier,
    'master_rating', detail.current_master_rating,
    'current_rating', profile.current_rating,
    'placement_status', profile.placement_status,
    'username_changed_at', account.username_changed_at,
    'sf6_user_code_changed_at', identity.sf6_user_code_changed_at,
    'deletion_requested_at', account.deletion_requested_at
  )
  into result
  from public.profiles as profile
  join public.profile_accounts as account on account.profile_id = profile.id
  join public.profile_sf6_identities as identity on identity.profile_id = profile.id
  join public.profile_private_details as detail on detail.profile_id = profile.id
  where profile.id = actor_profile_id;

  return result;
end;
$$;

create or replace function public.phase2_save_account_step(
  requested_actor_auth_user_id uuid,
  requested_username text,
  requested_username_normalized text,
  requested_oauth_avatar_url text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(
    requested_actor_auth_user_id::text,
    'onboarding_step_save'
  );

  select * into receipt
  from private.phase2_claim_action(
    'phase2.onboarding.account',
    requested_idempotency_key,
    requested_actor_auth_user_id,
    actor_profile_id,
    requested_hash
  );

  if not receipt.is_new then
    return receipt.response_payload;
  end if;

  select current_account.*
  into strict account
  from public.profile_accounts as current_account
  where current_account.profile_id = actor_profile_id
  for update;

  if account.account_status <> 'onboarding' then
    raise exception using errcode = '23514', message = 'onboarding_already_completed';
  end if;

  if requested_username is null
    or requested_username_normalized is null
    or char_length(requested_username) not between 3 and 80
    or char_length(requested_username_normalized) not between 3 and 160
    or requested_username ~ '[[:space:][:cntrl:]]'
  then
    raise exception using errcode = '22023', message = 'invalid_username';
  end if;

  if exists (
    select 1
    from private.username_reservations as reserved
    where reserved.username_normalized = requested_username_normalized
  ) then
    raise exception using errcode = '23505', message = 'username_reserved';
  end if;

  update public.profiles
  set
    username = requested_username,
    username_normalized = requested_username_normalized,
    avatar_source = case
      when avatar_source = 'upload' then avatar_source
      when requested_oauth_avatar_url is null then 'default'::public.avatar_source_type
      else 'oauth'::public.avatar_source_type
    end,
    avatar_url = case
      when avatar_source = 'upload' then avatar_url
      else requested_oauth_avatar_url
    end
  where id = actor_profile_id;

  update public.profile_accounts
  set
    onboarding_status = 'sf6_info_in_progress',
    onboarding_current_step = 2
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'onboarding_status', 'sf6_info_in_progress',
    'current_step', 2
  );

  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_save_sf6_info_step(
  requested_actor_auth_user_id uuid,
  requested_player_name text,
  requested_user_code text,
  requested_user_code_digest text,
  requested_country_code text,
  requested_broad_region_code text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(
    requested_actor_auth_user_id::text,
    'onboarding_step_save'
  );
  perform private.phase2_assert_user_code_available(requested_user_code_digest);

  select * into receipt
  from private.phase2_claim_action(
    'phase2.onboarding.sf6-info',
    requested_idempotency_key,
    requested_actor_auth_user_id,
    actor_profile_id,
    requested_hash
  );

  if not receipt.is_new then
    return receipt.response_payload;
  end if;

  select current_account.*
  into strict account
  from public.profile_accounts as current_account
  where current_account.profile_id = actor_profile_id
  for update;

  if account.account_status <> 'onboarding'
    or account.onboarding_current_step < 2
  then
    raise exception using errcode = '23514', message = 'account_step_required';
  end if;

  if requested_player_name is null
    or btrim(requested_player_name) = ''
    or char_length(requested_player_name) > 128
    or requested_player_name ~ '[[:cntrl:]]'
  then
    raise exception using errcode = '22023', message = 'invalid_player_name';
  end if;

  if requested_user_code !~ '^[0-9]{10}$' then
    raise exception using errcode = '22023', message = 'invalid_sf6_user_code';
  end if;

  if not exists (
    select 1
    from public.broad_regions as region
    join public.countries as country on country.code = region.country_code
    where region.code = requested_broad_region_code
      and region.country_code = requested_country_code
      and region.is_active
      and country.is_active
  ) then
    raise exception using errcode = '22023', message = 'invalid_country_region';
  end if;

  update public.profile_private_details
  set broad_region_code = null
  where profile_id = actor_profile_id;

  update public.profiles
  set country_code = requested_country_code
  where id = actor_profile_id;

  update public.profile_private_details
  set broad_region_code = requested_broad_region_code
  where profile_id = actor_profile_id;

  update public.profile_sf6_identities
  set
    sf6_player_name = requested_player_name,
    sf6_user_code = requested_user_code,
    sf6_user_code_normalized = requested_user_code
  where profile_id = actor_profile_id;

  update public.profile_accounts
  set
    onboarding_status = 'rating_setup_in_progress',
    onboarding_current_step = 3
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'onboarding_status', 'rating_setup_in_progress',
    'current_step', 3
  );

  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_preview_starting_rating(
  requested_actor_auth_user_id uuid,
  requested_character_code text,
  requested_rank public.sf6_rank,
  requested_rank_tier smallint,
  requested_master_rating integer
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  calculated record;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);

  if not exists (
    select 1
    from public.profile_accounts as account
    where account.profile_id = actor_profile_id
      and account.account_status = 'onboarding'
      and account.onboarding_current_step = 3
  ) then
    raise exception using errcode = '23514', message = 'sf6_info_step_required';
  end if;

  if not exists (
    select 1
    from public.sf6_characters as character
    where character.code = requested_character_code
      and character.is_active
  ) then
    raise exception using errcode = '22023', message = 'invalid_character';
  end if;

  select * into calculated
  from private.phase2_calculate_starting_rating(
    requested_rank,
    requested_rank_tier,
    requested_master_rating
  );

  return jsonb_build_object(
    'starting_rating', calculated.starting_rating,
    'source', calculated.source,
    'parameter_version', calculated.parameter_version
  );
end;
$$;

create or replace function public.phase2_complete_onboarding(
  requested_actor_auth_user_id uuid,
  requested_character_code text,
  requested_rank public.sf6_rank,
  requested_rank_tier smallint,
  requested_master_rating integer,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  profile public.profiles%rowtype;
  identity public.profile_sf6_identities%rowtype;
  calculated record;
  active_season_id uuid;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(
    requested_actor_auth_user_id::text,
    'onboarding_step_save'
  );

  select * into receipt
  from private.phase2_claim_action(
    'phase2.onboarding.complete',
    requested_idempotency_key,
    requested_actor_auth_user_id,
    actor_profile_id,
    requested_hash
  );

  if not receipt.is_new then
    return receipt.response_payload;
  end if;

  select current_account.*
  into strict account
  from public.profile_accounts as current_account
  where current_account.profile_id = actor_profile_id
  for update;

  if account.account_status = 'active'
    and account.onboarding_status = 'completed'
  then
    select jsonb_build_object(
      'profile_id', existing_profile.id,
      'starting_rating', existing_profile.current_rating,
      'placement_status', existing_profile.placement_status,
      'completed', true
    )
    into response
    from public.profiles as existing_profile
    where existing_profile.id = actor_profile_id;

    perform private.complete_domain_action(receipt.receipt_id, response);
    return response;
  end if;

  if account.account_status <> 'onboarding'
    or account.onboarding_current_step <> 3
  then
    raise exception using errcode = '23514', message = 'onboarding_steps_incomplete';
  end if;

  if not exists (
    select 1
    from auth.users as auth_user
    where auth_user.id = requested_actor_auth_user_id
      and auth_user.email_confirmed_at is not null
  ) then
    raise exception using errcode = '42501', message = 'email_verification_required';
  end if;

  select current_profile.*
  into strict profile
  from public.profiles as current_profile
  where current_profile.id = actor_profile_id
  for update;

  select current_identity.*
  into strict identity
  from public.profile_sf6_identities as current_identity
  where current_identity.profile_id = actor_profile_id
  for update;

  if profile.username is null
    or profile.country_code is null
    or identity.sf6_player_name is null
    or identity.sf6_user_code is null
    or not exists (
      select 1
      from public.profile_private_details as detail
      where detail.profile_id = actor_profile_id
        and detail.broad_region_code is not null
    )
  then
    raise exception using errcode = '23514', message = 'onboarding_steps_incomplete';
  end if;

  if not exists (
    select 1
    from public.sf6_characters as character
    where character.code = requested_character_code
      and character.is_active
  ) then
    raise exception using errcode = '22023', message = 'invalid_character';
  end if;

  select * into calculated
  from private.phase2_calculate_starting_rating(
    requested_rank,
    requested_rank_tier,
    requested_master_rating
  );

  select season.id
  into strict active_season_id
  from public.seasons as season
  where season.status = 'active';

  update public.profile_private_details
  set
    main_character_code = requested_character_code,
    current_sf6_rank = requested_rank,
    current_sf6_rank_tier = requested_rank_tier,
    current_master_rating = requested_master_rating
  where profile_id = actor_profile_id;

  insert into public.placement_initializations (
    profile_id,
    source,
    source_rank,
    source_rank_tier,
    source_master_rating,
    starting_rating,
    parameter_version
  )
  values (
    actor_profile_id,
    calculated.source,
    requested_rank,
    requested_rank_tier,
    requested_master_rating,
    calculated.starting_rating,
    calculated.parameter_version
  );

  insert into public.rating_history (
    profile_id,
    season_id,
    entry_type,
    rating_before,
    rounded_final_change,
    rating_after,
    reason_category,
    idempotency_key
  )
  values (
    actor_profile_id,
    active_season_id,
    'initial_placement',
    calculated.starting_rating,
    0,
    calculated.starting_rating,
    'onboarding_initial_rating',
    'phase2-initial-rating:' || actor_profile_id::text
  );

  update public.profiles
  set
    current_rating = calculated.starting_rating,
    rating_reached_at = statement_timestamp(),
    placement_status = 'active',
    placement_completed_count = 0,
    ranking_eligible = false,
    is_public = true
  where id = actor_profile_id;

  update public.profile_accounts
  set
    account_status = 'active',
    onboarding_status = 'completed',
    onboarding_current_step = 3,
    onboarding_completed_at = statement_timestamp()
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'starting_rating', calculated.starting_rating,
    'placement_status', 'active',
    'completed', true
  );

  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_update_username(
  requested_actor_auth_user_id uuid,
  requested_username text,
  requested_username_normalized text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  current_profile public.profiles%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'profile_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.profile.username', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  select * into strict account
  from public.profile_accounts
  where profile_id = actor_profile_id
  for update;

  select * into strict current_profile
  from public.profiles
  where id = actor_profile_id
  for update;

  if account.account_status <> 'active' then
    raise exception using errcode = '23514', message = 'active_account_required';
  end if;

  if requested_username is null
    or requested_username_normalized is null
    or char_length(requested_username) not between 3 and 80
    or char_length(requested_username_normalized) not between 3 and 160
    or requested_username ~ '[[:space:][:cntrl:]]'
  then
    raise exception using errcode = '22023', message = 'invalid_username';
  end if;

  if exists (
    select 1 from private.username_reservations
    where username_normalized = requested_username_normalized
  ) then
    raise exception using errcode = '23505', message = 'username_reserved';
  end if;

  if current_profile.username is distinct from requested_username
    and account.username_changed_at is not null
    and statement_timestamp() < account.username_changed_at + interval '30 days'
  then
    raise exception using errcode = '23514', message = 'username_cooldown';
  end if;

  if current_profile.username is distinct from requested_username then
    update public.profiles
    set username = requested_username, username_normalized = requested_username_normalized
    where id = actor_profile_id;

    update public.profile_accounts
    set username_changed_at = statement_timestamp()
    where profile_id = actor_profile_id;
  end if;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'username', requested_username,
    'next_change_at', case
      when current_profile.username is distinct from requested_username
        then statement_timestamp() + interval '30 days'
      when account.username_changed_at is not null
        then account.username_changed_at + interval '30 days'
      else null
    end
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_update_sf6_identity(
  requested_actor_auth_user_id uuid,
  requested_player_name text,
  requested_user_code text,
  requested_user_code_digest text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  current_identity public.profile_sf6_identities%rowtype;
  receipt record;
  code_changed boolean;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'profile_mutation');
  perform private.phase2_assert_user_code_available(requested_user_code_digest);

  select * into receipt
  from private.phase2_claim_action(
    'phase2.profile.sf6-identity', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if private.phase2_has_active_match(actor_profile_id) then
    raise exception using errcode = '23514', message = 'sf6_identity_locked_by_active_match';
  end if;

  if requested_player_name is null
    or btrim(requested_player_name) = ''
    or char_length(requested_player_name) > 128
    or requested_player_name ~ '[[:cntrl:]]'
    or requested_user_code !~ '^[0-9]{10}$'
  then
    raise exception using errcode = '22023', message = 'invalid_sf6_identity';
  end if;

  select * into strict current_identity
  from public.profile_sf6_identities
  where profile_id = actor_profile_id
  for update;

  code_changed := current_identity.sf6_user_code is distinct from requested_user_code;

  if code_changed
    and current_identity.sf6_user_code_changed_at is not null
    and statement_timestamp() < current_identity.sf6_user_code_changed_at + interval '30 days'
  then
    raise exception using errcode = '23514', message = 'sf6_user_code_cooldown';
  end if;

  update public.profile_sf6_identities
  set
    sf6_player_name = requested_player_name,
    sf6_user_code = requested_user_code,
    sf6_user_code_normalized = requested_user_code,
    sf6_user_code_changed_at = case
      when code_changed then statement_timestamp()
      else sf6_user_code_changed_at
    end
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'sf6_player_name', requested_player_name,
    'sf6_user_code', requested_user_code,
    'next_user_code_change_at', case
      when code_changed then statement_timestamp() + interval '30 days'
      when current_identity.sf6_user_code_changed_at is not null
        then current_identity.sf6_user_code_changed_at + interval '30 days'
      else null
    end
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_update_profile_details(
  requested_actor_auth_user_id uuid,
  requested_country_code text,
  requested_broad_region_code text,
  requested_character_code text,
  requested_rank public.sf6_rank,
  requested_rank_tier smallint,
  requested_master_rating integer,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'profile_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.profile.details', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if not exists (
    select 1
    from public.profile_accounts
    where profile_id = actor_profile_id and account_status = 'active'
  ) then
    raise exception using errcode = '23514', message = 'active_account_required';
  end if;

  if not exists (
    select 1
    from public.broad_regions as region
    join public.countries as country on country.code = region.country_code
    where region.code = requested_broad_region_code
      and region.country_code = requested_country_code
      and region.is_active and country.is_active
  ) then
    raise exception using errcode = '22023', message = 'invalid_country_region';
  end if;

  if not exists (
    select 1 from public.sf6_characters
    where code = requested_character_code and is_active
  ) then
    raise exception using errcode = '22023', message = 'invalid_character';
  end if;

  perform private.phase2_calculate_starting_rating(
    requested_rank, requested_rank_tier, requested_master_rating
  );

  update public.profile_private_details
  set broad_region_code = null
  where profile_id = actor_profile_id;

  update public.profiles
  set country_code = requested_country_code
  where id = actor_profile_id;

  update public.profile_private_details
  set
    broad_region_code = requested_broad_region_code,
    main_character_code = requested_character_code,
    current_sf6_rank = requested_rank,
    current_sf6_rank_tier = requested_rank_tier,
    current_master_rating = requested_master_rating
  where profile_id = actor_profile_id;

  response := jsonb_build_object('profile_id', actor_profile_id, 'updated', true);
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_attach_avatar(
  requested_actor_auth_user_id uuid,
  requested_storage_path text,
  requested_public_url text,
  requested_byte_size integer,
  requested_width integer,
  requested_height integer,
  requested_content_sha256 text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  new_asset_id uuid;
  old_asset_id uuid;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'avatar_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.avatar.attach', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if requested_storage_path !~ ('^' || actor_profile_id::text || '/[0-9a-f-]+[.]webp$')
    or requested_public_url is null
    or requested_content_sha256 !~ '^[0-9a-f]{64}$'
  then
    raise exception using errcode = '22023', message = 'invalid_avatar_metadata';
  end if;

  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'avatars'
      and object.name = requested_storage_path
      and object.owner_id = requested_actor_auth_user_id::text
  ) then
    raise exception using errcode = '42501', message = 'avatar_object_not_owned';
  end if;

  select avatar_asset_id into old_asset_id
  from public.profiles
  where id = actor_profile_id
  for update;

  insert into public.avatar_assets (
    profile_id, storage_path, content_type, byte_size,
    width, height, content_sha256
  )
  values (
    actor_profile_id, requested_storage_path, 'image/webp', requested_byte_size,
    requested_width, requested_height, requested_content_sha256
  )
  returning id into new_asset_id;

  update public.profiles
  set
    avatar_source = 'upload',
    avatar_url = requested_public_url,
    avatar_asset_id = new_asset_id
  where id = actor_profile_id;

  if old_asset_id is not null then
    update public.avatar_assets
    set deleted_at = statement_timestamp()
    where id = old_asset_id;
  end if;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'avatar_asset_id', new_asset_id,
    'avatar_url', requested_public_url
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_detach_avatar(
  requested_actor_auth_user_id uuid,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  old_asset_id uuid;
  old_storage_path text;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'avatar_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.avatar.detach', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  select profile.avatar_asset_id, asset.storage_path
  into old_asset_id, old_storage_path
  from public.profiles as profile
  left join public.avatar_assets as asset on asset.id = profile.avatar_asset_id
  where profile.id = actor_profile_id
  for update of profile;

  update public.profiles
  set avatar_source = 'default', avatar_url = null, avatar_asset_id = null
  where id = actor_profile_id;

  if old_asset_id is not null then
    update public.avatar_assets
    set deleted_at = coalesce(deleted_at, statement_timestamp())
    where id = old_asset_id;
  end if;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'storage_path', old_storage_path
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_avatar_cleanup_paths(
  requested_actor_auth_user_id uuid
)
returns text[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  paths text[];
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);

  select coalesce(array_agg(asset.storage_path order by asset.created_at), '{}'::text[])
  into paths
  from public.avatar_assets as asset
  where asset.profile_id = actor_profile_id;

  return paths;
end;
$$;

create or replace function public.phase2_request_account_deletion(
  requested_actor_auth_user_id uuid,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  blockers jsonb;
  job private.account_deletion_jobs%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'account_deletion');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.account.delete-request', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  select * into strict account
  from public.profile_accounts
  where profile_id = actor_profile_id
  for update;

  if account.account_status not in ('active', 'deletion_pending') then
    raise exception using errcode = '23514', message = 'account_not_deletable';
  end if;

  blockers := private.phase2_deletion_blockers(actor_profile_id);

  insert into private.account_deletion_jobs (
    profile_id, auth_user_id, status, blocking_reasons
  )
  values (
    actor_profile_id,
    requested_actor_auth_user_id,
    case when jsonb_array_length(blockers) = 0
      then 'requested'::private.account_deletion_job_status
      else 'blocked'::private.account_deletion_job_status
    end,
    blockers
  )
  on conflict (profile_id)
  do update set
    status = case when jsonb_array_length(excluded.blocking_reasons) = 0
      then 'requested'::private.account_deletion_job_status
      else 'blocked'::private.account_deletion_job_status
    end,
    blocking_reasons = excluded.blocking_reasons,
    last_error_code = null
  returning * into job;

  update public.profile_accounts
  set
    account_status = 'deletion_pending',
    deletion_requested_at = coalesce(deletion_requested_at, statement_timestamp())
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'job_id', job.id,
    'status', job.status,
    'blocking_reasons', blockers,
    'ready_to_finalize', jsonb_array_length(blockers) = 0
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_detach_avatars_for_deletion(
  requested_actor_auth_user_id uuid
)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  paths text[];
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);

  if not exists (
    select 1 from public.profile_accounts
    where profile_id = actor_profile_id and account_status = 'deletion_pending'
  ) then
    raise exception using errcode = '23514', message = 'deletion_pending_required';
  end if;

  select coalesce(array_agg(storage_path order by created_at), '{}'::text[])
  into paths
  from public.avatar_assets
  where profile_id = actor_profile_id;

  update public.profiles
  set avatar_source = 'default', avatar_url = null, avatar_asset_id = null
  where id = actor_profile_id;

  update public.avatar_assets
  set deleted_at = coalesce(deleted_at, statement_timestamp())
  where profile_id = actor_profile_id;

  return paths;
end;
$$;

create or replace function public.phase2_prepare_account_anonymization(
  requested_actor_auth_user_id uuid,
  requested_user_code_digest text,
  requested_idempotency_key text,
  requested_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  identity public.profile_sf6_identities%rowtype;
  job private.account_deletion_jobs%rowtype;
  blockers jsonb;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);

  select * into receipt
  from private.phase2_claim_action(
    'phase2.account.anonymize', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  select * into strict account
  from public.profile_accounts
  where profile_id = actor_profile_id
  for update;

  if account.account_status <> 'deletion_pending' then
    raise exception using errcode = '23514', message = 'deletion_pending_required';
  end if;

  blockers := private.phase2_deletion_blockers(actor_profile_id);
  if jsonb_array_length(blockers) > 0 then
    update private.account_deletion_jobs
    set status = 'blocked', blocking_reasons = blockers
    where profile_id = actor_profile_id;
    raise exception using errcode = '23514', message = 'deletion_blocked';
  end if;

  if exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'avatars'
      and object.name like actor_profile_id::text || '/%'
  ) then
    raise exception using errcode = '23514', message = 'avatar_cleanup_required';
  end if;

  select * into strict identity
  from public.profile_sf6_identities
  where profile_id = actor_profile_id
  for update;

  if identity.sf6_user_code is not null
    and requested_user_code_digest !~ '^[0-9a-f]{64}$'
  then
    raise exception using errcode = '22023', message = 'user_code_digest_required';
  end if;

  update private.account_deletion_jobs
  set
    status = 'anonymizing',
    attempt_count = attempt_count + 1,
    last_attempted_at = statement_timestamp(),
    blocking_reasons = '[]'::jsonb,
    last_error_code = null
  where profile_id = actor_profile_id
  returning * into strict job;

  if identity.sf6_user_code is not null then
    insert into private.deleted_user_code_reclaims (
      code_digest, deleted_profile_id, deletion_job_id
    )
    values (requested_user_code_digest, actor_profile_id, job.id)
    on conflict (deletion_job_id) do nothing;
  end if;

  update public.profile_private_details
  set
    broad_region_code = null,
    main_character_code = null,
    current_sf6_rank = null,
    current_sf6_rank_tier = null,
    current_master_rating = null
  where profile_id = actor_profile_id;

  update public.profile_sf6_identities
  set
    sf6_player_name = null,
    sf6_user_code = null,
    sf6_user_code_normalized = null,
    sf6_user_code_changed_at = null
  where profile_id = actor_profile_id;

  update public.profiles
  set
    username = null,
    username_normalized = null,
    avatar_source = 'default',
    avatar_url = null,
    avatar_asset_id = null,
    country_code = null,
    is_public = false,
    deleted_at = statement_timestamp()
  where id = actor_profile_id;

  update public.profile_accounts
  set
    auth_user_id = null,
    account_status = 'anonymized',
    username_changed_at = null,
    anonymized_at = statement_timestamp()
  where profile_id = actor_profile_id;

  update private.account_deletion_jobs
  set status = 'auth_delete_pending'
  where id = job.id;

  response := jsonb_build_object(
    'job_id', job.id,
    'profile_id', actor_profile_id,
    'auth_user_id', requested_actor_auth_user_id,
    'status', 'auth_delete_pending'
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

create or replace function public.phase2_mark_auth_deletion_complete(
  requested_job_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  job private.account_deletion_jobs%rowtype;
begin
  select * into strict job
  from private.account_deletion_jobs
  where id = requested_job_id
  for update;

  if job.status = 'completed' then
    return jsonb_build_object('job_id', job.id, 'status', 'completed');
  end if;

  if job.status not in ('auth_delete_pending', 'failed') then
    raise exception using errcode = '23514', message = 'auth_deletion_not_pending';
  end if;

  update private.account_deletion_jobs
  set status = 'completed', completed_at = statement_timestamp(), last_error_code = null
  where id = job.id;

  return jsonb_build_object('job_id', job.id, 'status', 'completed');
end;
$$;

create or replace function public.phase2_mark_auth_deletion_failed(
  requested_job_id uuid,
  requested_error_code text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.account_deletion_jobs
  set
    status = 'failed',
    last_error_code = left(coalesce(requested_error_code, 'unknown'), 100),
    last_attempted_at = statement_timestamp()
  where id = requested_job_id
    and status in ('auth_delete_pending', 'failed');

  if not found then
    raise exception using errcode = '23514', message = 'auth_deletion_not_retryable';
  end if;

  return jsonb_build_object('job_id', requested_job_id, 'status', 'failed');
end;
$$;

create or replace function public.phase2_retryable_auth_deletion_job(
  requested_profile_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  job private.account_deletion_jobs%rowtype;
begin
  select * into strict job
  from private.account_deletion_jobs
  where profile_id = requested_profile_id
    and status in ('auth_delete_pending', 'failed');

  return jsonb_build_object(
    'job_id', job.id,
    'profile_id', job.profile_id,
    'auth_user_id', job.auth_user_id,
    'status', job.status,
    'attempt_count', job.attempt_count
  );
end;
$$;

comment on function public.phase2_complete_onboarding(uuid, text, public.sf6_rank, smallint, integer, text, text) is
  'Atomically snapshots starting-rating inputs, creates the initial rating history entry, starts Placement, publishes the profile, and activates the account.';
comment on function public.phase2_prepare_account_anonymization(uuid, text, text, text) is
  'Irreversibly anonymizes application data only after blockers and Storage objects are absent. Auth deletion is a separately retryable final step.';

revoke all on function private.require_phase2_actor(uuid) from public, anon, authenticated;
revoke all on function private.consume_phase2_rate_limit(text, text) from public, anon, authenticated;
revoke all on function private.phase2_has_active_match(uuid) from public, anon, authenticated;
revoke all on function private.phase2_deletion_blockers(uuid) from public, anon, authenticated;
revoke all on function private.phase2_assert_user_code_available(text) from public, anon, authenticated;
revoke all on function private.phase2_calculate_starting_rating(public.sf6_rank, smallint, integer) from public, anon, authenticated;
revoke all on function private.phase2_claim_action(text, text, uuid, uuid, text) from public, anon, authenticated;

revoke execute on function public.phase2_onboarding_state(uuid) from public, anon, authenticated;
revoke execute on function public.phase2_save_account_step(uuid, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_save_sf6_info_step(uuid, text, text, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_preview_starting_rating(uuid, text, public.sf6_rank, smallint, integer) from public, anon, authenticated;
revoke execute on function public.phase2_complete_onboarding(uuid, text, public.sf6_rank, smallint, integer, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_update_username(uuid, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_update_sf6_identity(uuid, text, text, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_update_profile_details(uuid, text, text, text, public.sf6_rank, smallint, integer, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_attach_avatar(uuid, text, text, integer, integer, integer, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_detach_avatar(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_avatar_cleanup_paths(uuid) from public, anon, authenticated;
revoke execute on function public.phase2_request_account_deletion(uuid, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_detach_avatars_for_deletion(uuid) from public, anon, authenticated;
revoke execute on function public.phase2_prepare_account_anonymization(uuid, text, text, text) from public, anon, authenticated;
revoke execute on function public.phase2_mark_auth_deletion_complete(uuid) from public, anon, authenticated;
revoke execute on function public.phase2_mark_auth_deletion_failed(uuid, text) from public, anon, authenticated;
revoke execute on function public.phase2_retryable_auth_deletion_job(uuid) from public, anon, authenticated;

grant execute on function public.phase2_onboarding_state(uuid) to service_role;
grant execute on function public.phase2_save_account_step(uuid, text, text, text, text, text) to service_role;
grant execute on function public.phase2_save_sf6_info_step(uuid, text, text, text, text, text, text, text) to service_role;
grant execute on function public.phase2_preview_starting_rating(uuid, text, public.sf6_rank, smallint, integer) to service_role;
grant execute on function public.phase2_complete_onboarding(uuid, text, public.sf6_rank, smallint, integer, text, text) to service_role;
grant execute on function public.phase2_update_username(uuid, text, text, text, text) to service_role;
grant execute on function public.phase2_update_sf6_identity(uuid, text, text, text, text, text) to service_role;
grant execute on function public.phase2_update_profile_details(uuid, text, text, text, public.sf6_rank, smallint, integer, text, text) to service_role;
grant execute on function public.phase2_attach_avatar(uuid, text, text, integer, integer, integer, text, text, text) to service_role;
grant execute on function public.phase2_detach_avatar(uuid, text, text) to service_role;
grant execute on function public.phase2_avatar_cleanup_paths(uuid) to service_role;
grant execute on function public.phase2_request_account_deletion(uuid, text, text) to service_role;
grant execute on function public.phase2_detach_avatars_for_deletion(uuid) to service_role;
grant execute on function public.phase2_prepare_account_anonymization(uuid, text, text, text) to service_role;
grant execute on function public.phase2_mark_auth_deletion_complete(uuid) to service_role;
grant execute on function public.phase2_mark_auth_deletion_failed(uuid, text) to service_role;
grant execute on function public.phase2_retryable_auth_deletion_job(uuid) to service_role;
