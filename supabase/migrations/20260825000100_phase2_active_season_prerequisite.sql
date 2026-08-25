-- Surface the missing active Season as an explicit onboarding prerequisite.
-- Keep this correction narrowly scoped: unrelated NO_DATA_FOUND (P0002)
-- errors retain their original meaning.

create or replace function public.phase2_complete_onboarding(
  requested_actor_auth_user_id uuid,
  requested_character_code text,
  requested_rank public.sf6_rank,
  requested_rank_tier smallint,
  requested_master_rating integer,
  requested_idempotency_key text,
  requested_hash text,
  requested_preview_parameter_version text
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

  if requested_preview_parameter_version is null
    or requested_preview_parameter_version <> calculated.parameter_version
  then
    raise exception using errcode = '23514', message = 'rating_preview_stale';
  end if;

  select season.id
  into active_season_id
  from public.seasons as season
  where season.status = 'active';

  if active_season_id is null then
    raise exception using
      errcode = '55000',
      message = 'active_season_required';
  end if;

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

revoke execute on function public.phase2_complete_onboarding(
  uuid, text, public.sf6_rank, smallint, integer, text, text, text
) from public, anon, authenticated;

grant execute on function public.phase2_complete_onboarding(
  uuid, text, public.sf6_rank, smallint, integer, text, text, text
) to service_role;
