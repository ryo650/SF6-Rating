-- Forward-only correction for the Phase 2 review findings.
-- This migration intentionally succeeds both after the originally committed
-- Phase 2 migrations and after a clean install containing their hardened form.

alter table public.profile_sf6_identities
  add column if not exists sf6_user_code_digest text;

do $$
begin
  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'profile_sf6_identities_digest_shape'
      and conrelid = 'public.profile_sf6_identities'::regclass
  ) then
    alter table public.profile_sf6_identities
      add constraint profile_sf6_identities_digest_shape check (
        sf6_user_code_digest is null
        or sf6_user_code_digest ~ '^[0-9a-f]{64}$'
      );
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conname = 'profile_sf6_identities_code_digest_pair'
      and conrelid = 'public.profile_sf6_identities'::regclass
  ) then
    alter table public.profile_sf6_identities
      add constraint profile_sf6_identities_code_digest_pair check (
        sf6_user_code_digest is null or sf6_user_code is not null
      );
  end if;
end;
$$;

create unique index if not exists profile_sf6_identities_user_code_digest_unique
  on public.profile_sf6_identities (sf6_user_code_digest)
  where sf6_user_code_digest is not null;

-- The originally committed OAuth path stored a raw provider URL without an
-- internal asset. Do not preserve or render that external URL after upgrade.
update public.profiles
set avatar_source = 'default', avatar_url = null
where avatar_source = 'oauth' and avatar_asset_id is null;

alter table public.profiles
  drop constraint if exists profiles_avatar_shape;
alter table public.profiles
  add constraint profiles_avatar_shape check (
    (avatar_source = 'default' and avatar_url is null and avatar_asset_id is null)
    or (
      avatar_source in ('oauth', 'upload')
      and avatar_url is not null
      and avatar_asset_id is not null
    )
  );

create table if not exists private.sf6_user_code_claims (
  code_digest text primary key,
  live_profile_id uuid unique references public.profiles (id) on delete restrict,
  deleted_reclaim_id uuid unique references private.deleted_user_code_reclaims (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint sf6_user_code_claims_digest_shape check (
    code_digest ~ '^[0-9a-f]{64}$'
  ),
  constraint sf6_user_code_claims_single_owner check (
    (live_profile_id is not null)::integer
    + (deleted_reclaim_id is not null)::integer = 1
  )
);

-- Backfill every claim for which the keyed digest was already persisted.
-- Legacy live rows without a digest are claimed lazily by the trusted server
-- because the HMAC pepper is deliberately unavailable to SQL migrations.
insert into private.sf6_user_code_claims (code_digest, live_profile_id)
select identity.sf6_user_code_digest, identity.profile_id
from public.profile_sf6_identities as identity
where identity.sf6_user_code_digest is not null
on conflict (code_digest) do nothing;

insert into private.sf6_user_code_claims (code_digest, deleted_reclaim_id)
select reclaim.code_digest, reclaim.id
from private.deleted_user_code_reclaims as reclaim
where reclaim.released_at is null
on conflict (code_digest) do nothing;

-- Scrub identifiers left by the originally committed deletion workflow before
-- strengthening the job completion invariant.
delete from private.action_rate_limits as rate_limit
using private.account_deletion_jobs as job
join public.profile_accounts as account on account.profile_id = job.profile_id
where account.account_status = 'anonymized'
  and job.auth_user_id is not null
  and rate_limit.actor_key = job.auth_user_id::text;

update private.domain_action_receipts as receipt
set
  actor_identity = 'deleted-profile:' || receipt.actor_profile_id::text,
  request_hash = repeat('0', 64),
  response_payload = jsonb_build_object('status', 'redacted'),
  error_code = null
from public.profile_accounts as account
where account.profile_id = receipt.actor_profile_id
  and account.account_status = 'anonymized';

alter table private.account_deletion_jobs
  alter column auth_user_id drop not null;

update private.account_deletion_jobs
set auth_user_id = null
where status = 'completed';

alter table private.account_deletion_jobs
  drop constraint if exists account_deletion_jobs_completion_shape;
alter table private.account_deletion_jobs
  add constraint account_deletion_jobs_completion_shape check (
    (status = 'completed' and completed_at is not null and auth_user_id is null)
    or (status <> 'completed' and completed_at is null and auth_user_id is not null)
  );

create or replace function private.phase2_lock_account(
  requested_profile_id uuid
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('sf6-rating-account:' || requested_profile_id::text, 0)
  );
$$;

create or replace function private.phase2_lock_match_participant_account()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.phase2_lock_account(new.profile_id);

  if new.is_active and not exists (
    select 1
    from public.profile_accounts as account
    where account.profile_id = new.profile_id
      and account.account_status = 'active'
  ) then
    raise exception using
      errcode = '23514',
      message = 'match_participant_active_account_required';
  end if;

  return new;
end;
$$;

create or replace function private.phase2_claim_user_code(
  requested_code_digest text,
  requested_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  claim private.sf6_user_code_claims%rowtype;
begin
  if requested_code_digest !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'invalid_user_code_digest';
  end if;

  -- One account may own only one live code. The surrounding account lock
  -- serializes mutation; if the new digest is unavailable, the exception
  -- rolls this deletion back and preserves the prior claim.
  delete from private.sf6_user_code_claims
  where live_profile_id = requested_profile_id
    and code_digest <> requested_code_digest;

  insert into private.sf6_user_code_claims (code_digest, live_profile_id)
  values (requested_code_digest, requested_profile_id)
  on conflict (code_digest) do nothing;

  select * into strict claim
  from private.sf6_user_code_claims
  where code_digest = requested_code_digest
  for update;

  if claim.live_profile_id is distinct from requested_profile_id then
    raise exception using errcode = '23505', message = 'sf6_user_code_reserved';
  end if;
end;
$$;

create or replace function private.phase2_release_live_user_code(
  requested_code_digest text,
  requested_profile_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from private.sf6_user_code_claims
  where code_digest = requested_code_digest
    and live_profile_id = requested_profile_id;
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
    'deletion_requested_at', account.deletion_requested_at,
    'deletion_blocking_reasons', coalesce(
      (
        select job.blocking_reasons
        from private.account_deletion_jobs as job
        where job.profile_id = profile.id
      ),
      '[]'::jsonb
    )
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
  requested_idempotency_key text,
  requested_hash text,
  requested_storage_path text default null,
  requested_public_url text default null,
  requested_byte_size integer default null,
  requested_width integer default null,
  requested_height integer default null,
  requested_content_sha256 text default null,
  requested_avatar_source public.avatar_source_type default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  new_asset_id uuid;
  old_asset_id uuid;
  old_storage_path text;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.phase2_lock_account(actor_profile_id);
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

  if requested_storage_path is not null then
    if requested_storage_path !~ ('^' || actor_profile_id::text || '/[0-9a-f]{64}[.]webp$')
      or requested_public_url is null
      or requested_byte_size is null
      or requested_byte_size not between 1 and 5242880
      or requested_width is null
      or requested_width not between 1 and 512
      or requested_height is null
      or requested_height <> requested_width
      or requested_content_sha256 is null
      or requested_content_sha256 !~ '^[0-9a-f]{64}$'
      or requested_avatar_source is null
      or requested_avatar_source not in ('oauth', 'upload')
    then
      raise exception using errcode = '22023', message = 'invalid_avatar_metadata';
    end if;

    if not exists (
      select 1 from storage.objects as object
      where object.bucket_id = 'avatars'
        and object.name = requested_storage_path
    ) then
      raise exception using errcode = '42501', message = 'avatar_object_missing';
    end if;

    select profile.avatar_asset_id, asset.storage_path
    into old_asset_id, old_storage_path
    from public.profiles as profile
    left join public.avatar_assets as asset on asset.id = profile.avatar_asset_id
    where profile.id = actor_profile_id
    for update of profile;

    insert into public.avatar_assets (
      profile_id, storage_path, content_type, byte_size,
      width, height, content_sha256
    ) values (
      actor_profile_id, requested_storage_path, 'image/webp', requested_byte_size,
      requested_width, requested_height, requested_content_sha256
    )
    on conflict (storage_path) do update set
      deleted_at = null
    returning id into new_asset_id;
  end if;

  update public.profiles
  set
    username = requested_username,
    username_normalized = requested_username_normalized,
    avatar_source = case
      when requested_storage_path is not null then requested_avatar_source
      when avatar_source in ('oauth', 'upload') then avatar_source
      else 'default'::public.avatar_source_type
    end,
    avatar_url = case
      when requested_storage_path is not null then requested_public_url
      when avatar_source in ('oauth', 'upload') then avatar_url
      else null
    end,
    avatar_asset_id = case
      when requested_storage_path is not null then new_asset_id
      else avatar_asset_id
    end
  where id = actor_profile_id;

  if old_asset_id is not null and old_asset_id is distinct from new_asset_id then
    update public.avatar_assets
    set deleted_at = statement_timestamp()
    where id = old_asset_id;
  end if;

  update public.profile_accounts
  set
    onboarding_status = 'sf6_info_in_progress',
    onboarding_current_step = 2
  where profile_id = actor_profile_id;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'onboarding_status', 'sf6_info_in_progress',
    'current_step', 2,
    'old_storage_path', old_storage_path
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
  current_identity public.profile_sf6_identities%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.phase2_lock_account(actor_profile_id);
  perform private.consume_phase2_rate_limit(
    requested_actor_auth_user_id::text,
    'onboarding_step_save'
  );
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

  select * into strict current_identity
  from public.profile_sf6_identities
  where profile_id = actor_profile_id
  for update;

  if current_identity.sf6_user_code_digest is distinct from requested_user_code_digest then
    perform private.phase2_claim_user_code(
      requested_user_code_digest,
      actor_profile_id
    );
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
    sf6_user_code_normalized = requested_user_code,
    sf6_user_code_digest = requested_user_code_digest
  where profile_id = actor_profile_id;

  if current_identity.sf6_user_code_digest is not null
    and current_identity.sf6_user_code_digest is distinct from requested_user_code_digest
  then
    perform private.phase2_release_live_user_code(
      current_identity.sf6_user_code_digest,
      actor_profile_id
    );
  end if;

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
  account public.profile_accounts%rowtype;
  current_identity public.profile_sf6_identities%rowtype;
  receipt record;
  code_changed boolean;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.phase2_lock_account(actor_profile_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'profile_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.profile.sf6-identity', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if requested_player_name is null
    or btrim(requested_player_name) = ''
    or char_length(requested_player_name) > 128
    or requested_player_name ~ '[[:cntrl:]]'
    or requested_user_code !~ '^[0-9]{10}$'
  then
    raise exception using errcode = '22023', message = 'invalid_sf6_identity';
  end if;

  select * into strict account
  from public.profile_accounts
  where profile_id = actor_profile_id
  for update;

  if account.account_status <> 'active' then
    raise exception using errcode = '23514', message = 'active_account_required';
  end if;

  select * into strict current_identity
  from public.profile_sf6_identities
  where profile_id = actor_profile_id
  for update;

  if private.phase2_has_active_match(actor_profile_id) then
    raise exception using errcode = '23514', message = 'sf6_identity_locked_by_active_match';
  end if;

  code_changed := current_identity.sf6_user_code is distinct from requested_user_code;

  if current_identity.sf6_user_code_digest is distinct from requested_user_code_digest then
    perform private.phase2_claim_user_code(
      requested_user_code_digest,
      actor_profile_id
    );
  end if;

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
    sf6_user_code_digest = requested_user_code_digest,
    sf6_user_code_changed_at = case
      when code_changed then statement_timestamp()
      else sf6_user_code_changed_at
    end
  where profile_id = actor_profile_id;

  if current_identity.sf6_user_code_digest is not null
    and current_identity.sf6_user_code_digest is distinct from requested_user_code_digest
  then
    perform private.phase2_release_live_user_code(
      current_identity.sf6_user_code_digest,
      actor_profile_id
    );
  end if;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'identity_updated', true,
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
  old_storage_path text;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.phase2_lock_account(actor_profile_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'avatar_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.avatar.attach', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if not exists (
    select 1 from public.profile_accounts
    where profile_id = actor_profile_id and account_status = 'active'
  ) then
    raise exception using errcode = '23514', message = 'active_account_required';
  end if;

  if requested_storage_path is null
    or requested_storage_path !~ ('^' || actor_profile_id::text || '/[0-9a-f]{64}[.]webp$')
    or requested_public_url is null
    or requested_byte_size is null
    or requested_byte_size not between 1 and 5242880
    or requested_width is null
    or requested_width not between 1 and 512
    or requested_height is null
    or requested_height <> requested_width
    or requested_content_sha256 is null
    or requested_content_sha256 !~ '^[0-9a-f]{64}$'
  then
    raise exception using errcode = '22023', message = 'invalid_avatar_metadata';
  end if;

  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'avatars'
      and object.name = requested_storage_path
  ) then
    raise exception using errcode = '42501', message = 'avatar_object_not_owned';
  end if;

  select profile.avatar_asset_id, asset.storage_path
  into old_asset_id, old_storage_path
  from public.profiles as profile
  left join public.avatar_assets as asset on asset.id = profile.avatar_asset_id
  where profile.id = actor_profile_id
  for update of profile;

  insert into public.avatar_assets (
    profile_id, storage_path, content_type, byte_size,
    width, height, content_sha256
  )
  values (
    actor_profile_id, requested_storage_path, 'image/webp', requested_byte_size,
    requested_width, requested_height, requested_content_sha256
  )
  on conflict (storage_path) do update set
    deleted_at = null
  returning id into new_asset_id;

  update public.profiles
  set
    avatar_source = 'upload',
    avatar_url = requested_public_url,
    avatar_asset_id = new_asset_id
  where id = actor_profile_id;

  if old_asset_id is not null and old_asset_id is distinct from new_asset_id then
    update public.avatar_assets
    set deleted_at = statement_timestamp()
    where id = old_asset_id;
  end if;

  response := jsonb_build_object(
    'profile_id', actor_profile_id,
    'avatar_asset_id', new_asset_id,
    'avatar_url', requested_public_url,
    'old_storage_path', old_storage_path
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
  perform private.phase2_lock_account(actor_profile_id);
  perform private.consume_phase2_rate_limit(requested_actor_auth_user_id::text, 'avatar_mutation');

  select * into receipt
  from private.phase2_claim_action(
    'phase2.avatar.detach', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  if not exists (
    select 1 from public.profile_accounts
    where profile_id = actor_profile_id and account_status = 'active'
  ) then
    raise exception using errcode = '23514', message = 'active_account_required';
  end if;

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
  perform private.phase2_lock_account(actor_profile_id);
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
  receipt_actor_profile_id uuid;
  account public.profile_accounts%rowtype;
  identity public.profile_sf6_identities%rowtype;
  job private.account_deletion_jobs%rowtype;
  reclaim_id uuid;
  blockers jsonb;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  receipt_actor_profile_id := actor_profile_id;
  perform private.phase2_lock_account(actor_profile_id);

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

  if identity.sf6_user_code is not null then
    if requested_user_code_digest !~ '^[0-9a-f]{64}$' then
      raise exception using errcode = '22023', message = 'user_code_digest_required';
    end if;

    if identity.sf6_user_code_digest is null then
      perform private.phase2_claim_user_code(
        requested_user_code_digest,
        actor_profile_id
      );
      update public.profile_sf6_identities
      set sf6_user_code_digest = requested_user_code_digest
      where profile_id = actor_profile_id;
      identity.sf6_user_code_digest := requested_user_code_digest;
    elsif identity.sf6_user_code_digest <> requested_user_code_digest then
      raise exception using errcode = '22023', message = 'user_code_digest_mismatch';
    end if;
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
    values (identity.sf6_user_code_digest, actor_profile_id, job.id)
    on conflict (deletion_job_id) do update
      set code_digest = excluded.code_digest
    returning id into reclaim_id;

    update private.sf6_user_code_claims
    set
      live_profile_id = null,
      deleted_reclaim_id = reclaim_id,
      updated_at = statement_timestamp()
    where code_digest = identity.sf6_user_code_digest
      and live_profile_id = actor_profile_id;

    if not found then
      raise exception using errcode = '23514', message = 'user_code_claim_missing';
    end if;
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
    sf6_user_code_digest = null,
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
    'status', 'auth_delete_pending'
  );
  perform private.complete_domain_action(receipt.receipt_id, response);

  update private.domain_action_receipts as receipt_row
  set
    actor_identity = 'deleted-profile:' || receipt_actor_profile_id::text,
    request_hash = repeat('0', 64),
    response_payload = jsonb_build_object('status', 'redacted'),
    error_code = null
  where receipt_row.actor_profile_id = receipt_actor_profile_id;

  delete from private.action_rate_limits
  where actor_key = requested_actor_auth_user_id::text;

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
  set
    status = 'completed',
    auth_user_id = null,
    completed_at = statement_timestamp(),
    last_error_code = null
  where id = job.id;

  return jsonb_build_object('job_id', job.id, 'status', 'completed');
end;
$$;

create or replace function public.phase2_release_deleted_user_code(
  requested_actor_auth_user_id uuid,
  requested_code_digest text,
  requested_reason text,
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
  reclaim private.deleted_user_code_reclaims%rowtype;
  receipt record;
  response jsonb;
begin
  actor_profile_id := private.require_phase2_actor(requested_actor_auth_user_id);
  perform private.phase2_lock_account(actor_profile_id);

  select * into strict account
  from public.profile_accounts
  where profile_id = actor_profile_id
  for update;

  if account.account_status <> 'active' or account.application_role <> 'admin' then
    raise exception using errcode = '42501', message = 'admin_required';
  end if;

  if requested_code_digest !~ '^[0-9a-f]{64}$'
    or btrim(coalesce(requested_reason, '')) = ''
  then
    raise exception using errcode = '22023', message = 'invalid_reclaim_release';
  end if;

  select * into receipt
  from private.phase2_claim_action(
    'phase2.admin.user-code-release', requested_idempotency_key,
    requested_actor_auth_user_id, actor_profile_id, requested_hash
  );
  if not receipt.is_new then return receipt.response_payload; end if;

  select * into strict reclaim
  from private.deleted_user_code_reclaims
  where code_digest = requested_code_digest
  for update;

  if reclaim.released_at is null then
    update private.deleted_user_code_reclaims
    set
      released_at = statement_timestamp(),
      released_by_admin_profile_id = actor_profile_id,
      release_reason = requested_reason
    where id = reclaim.id;

    delete from private.sf6_user_code_claims
    where deleted_reclaim_id = reclaim.id;

    insert into public.admin_audit_logs (
      admin_profile_id, action, target_type, target_id,
      before_state, after_state, reason_category, idempotency_key
    )
    values (
      actor_profile_id, 'release_deleted_sf6_user_code',
      'deleted_user_code_reclaim', reclaim.id,
      jsonb_build_object('released', false),
      jsonb_build_object('released', true),
      requested_reason, requested_idempotency_key
    );
  end if;

  response := jsonb_build_object(
    'reclaim_id', reclaim.id,
    'released', true
  );
  perform private.complete_domain_action(receipt.receipt_id, response);
  return response;
end;
$$;

drop trigger if exists phase2_match_participant_account_lock
  on public.match_participants;
create trigger phase2_match_participant_account_lock
before insert or update on public.match_participants
for each row execute function private.phase2_lock_match_participant_account();

-- Remove RPC overloads from the originally committed and interim local forms.
drop function if exists public.phase2_save_account_step(
  uuid, text, text, text, text, text
);
drop function if exists public.phase2_save_account_step(
  uuid, text, text, text, text, text, text, integer, integer, integer, text
);
drop function if exists public.phase2_complete_onboarding(
  uuid, text, public.sf6_rank, smallint, integer, text, text
);
drop function if exists private.phase2_assert_user_code_available(text);

drop policy if exists avatars_owner_insert on storage.objects;
drop policy if exists avatars_owner_update on storage.objects;
drop policy if exists avatars_owner_delete on storage.objects;

revoke select on table public.profiles from anon, authenticated;
grant select (
  id, username, avatar_url, country_code, current_rating, rating_reached_at,
  placement_status, placement_completed_count, ranking_eligible,
  is_public, deleted_at, created_at, updated_at
) on table public.profiles to anon, authenticated;

revoke select on table public.profile_sf6_identities from authenticated;
grant select (
  profile_id, sf6_player_name, sf6_user_code
) on table public.profile_sf6_identities to authenticated;

revoke all on table private.sf6_user_code_claims
  from public, anon, authenticated;
grant all privileges on table private.sf6_user_code_claims to service_role;

revoke all on function private.phase2_lock_account(uuid)
  from public, anon, authenticated;
revoke all on function private.phase2_lock_match_participant_account()
  from public, anon, authenticated;
revoke all on function private.phase2_claim_user_code(text, uuid)
  from public, anon, authenticated;
revoke all on function private.phase2_release_live_user_code(text, uuid)
  from public, anon, authenticated;

revoke execute on function public.phase2_save_account_step(
  uuid, text, text, text, text, text, text, integer, integer, integer, text,
  public.avatar_source_type
) from public, anon, authenticated;
grant execute on function public.phase2_save_account_step(
  uuid, text, text, text, text, text, text, integer, integer, integer, text,
  public.avatar_source_type
) to service_role;

revoke execute on function public.phase2_complete_onboarding(
  uuid, text, public.sf6_rank, smallint, integer, text, text, text
) from public, anon, authenticated;
grant execute on function public.phase2_complete_onboarding(
  uuid, text, public.sf6_rank, smallint, integer, text, text, text
) to service_role;

revoke execute on function public.phase2_release_deleted_user_code(
  uuid, text, text, text, text
) from public, anon, authenticated;
grant execute on function public.phase2_release_deleted_user_code(
  uuid, text, text, text, text
) to service_role;

comment on function public.phase2_save_account_step(
  uuid, text, text, text, text, text, text, integer, integer, integer, text,
  public.avatar_source_type
) is
  'Atomically saves Account Step 1 and swaps an immutable, server-processed Avatar pointer. The response names only the prior committed Storage path.';
