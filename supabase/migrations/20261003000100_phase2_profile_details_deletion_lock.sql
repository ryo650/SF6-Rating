-- Serialize profile details with account deletion before taking rate-limit or
-- receipt locks and before reading active status. Existing applied migrations
-- remain unchanged; CREATE OR REPLACE preserves the signature and grants.

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
  perform private.phase2_lock_account(actor_profile_id);
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
