-- Phase 2: account/profile schema, managed masters, Auth provisioning, and
-- durable state for avatar and account-deletion workflows.

create type public.avatar_source_type as enum (
  'default',
  'oauth',
  'upload'
);

create type private.account_deletion_job_status as enum (
  'requested',
  'blocked',
  'anonymizing',
  'auth_delete_pending',
  'completed',
  'failed'
);

create table public.countries (
  code text primary key,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint countries_iso_alpha_2 check (code ~ '^[A-Z]{2}$')
);

insert into public.countries (code)
select code
from unnest(string_to_array(
  'AD AE AF AG AI AL AM AO AQ AR AS AT AU AW AX AZ BA BB BD BE BF BG BH BI BJ BL BM BN BO BQ BR BS BT BV BW BY BZ CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG EH ER ES ET FI FJ FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GS GT GU GW GY HK HM HN HR HT HU ID IE IL IM IN IO IQ IR IS IT JE JM JO JP KE KG KH KI KM KN KP KR KW KY KZ LA LB LC LI LK LR LS LT LU LV LY MA MC MD ME MF MG MH MK ML MM MN MO MP MQ MR MS MT MU MV MW MX MY MZ NA NC NE NF NG NI NL NO NP NR NU NZ OM PA PE PF PG PH PK PL PM PN PR PS PT PW PY QA RE RO RS RU RW SA SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV SX SY SZ TC TD TF TG TH TJ TK TL TM TN TO TR TT TV TW TZ UA UG UM US UY UZ VA VC VE VG VI VN VU WF WS YE YT ZA ZM ZW',
  ' '
)) as code;

create table public.broad_regions (
  code text primary key,
  country_code text not null references public.countries (code) on delete restrict,
  name_ja text not null,
  name_en text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (country_code, code),
  constraint broad_regions_code_not_blank check (btrim(code) <> ''),
  constraint broad_regions_names_not_blank check (
    btrim(name_ja) <> '' and btrim(name_en) <> ''
  )
);

insert into public.broad_regions (
  code,
  country_code,
  name_ja,
  name_en,
  sort_order
)
select
  country.code || '-ALL',
  country.code,
  '国内全域',
  'Country-wide',
  1
from public.countries as country
where country.code <> 'JP';

insert into public.broad_regions (
  code,
  country_code,
  name_ja,
  name_en,
  sort_order
)
values
  ('JP-HOKKAIDO', 'JP', '北海道', 'Hokkaido', 10),
  ('JP-TOHOKU', 'JP', '東北', 'Tohoku', 20),
  ('JP-KANTO', 'JP', '関東', 'Kanto', 30),
  ('JP-CHUBU', 'JP', '中部', 'Chubu', 40),
  ('JP-KANSAI', 'JP', '関西', 'Kansai', 50),
  ('JP-CHUGOKU-SHIKOKU', 'JP', '中国・四国', 'Chugoku / Shikoku', 60),
  ('JP-KYUSHU-OKINAWA', 'JP', '九州・沖縄', 'Kyushu / Okinawa', 70);

create table public.sf6_characters (
  code text primary key,
  name text not null,
  sort_order integer not null,
  is_active boolean not null default true,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (name),
  constraint sf6_characters_code_not_blank check (btrim(code) <> ''),
  constraint sf6_characters_name_not_blank check (btrim(name) <> '')
);

insert into public.sf6_characters (code, name, sort_order)
values
  ('luke', 'Luke', 10),
  ('jamie', 'Jamie', 20),
  ('manon', 'Manon', 30),
  ('kimberly', 'Kimberly', 40),
  ('marisa', 'Marisa', 50),
  ('lily', 'Lily', 60),
  ('jp', 'JP', 70),
  ('juri', 'Juri', 80),
  ('dee-jay', 'Dee Jay', 90),
  ('cammy', 'Cammy', 100),
  ('ryu', 'Ryu', 110),
  ('e-honda', 'E. Honda', 120),
  ('blanka', 'Blanka', 130),
  ('guile', 'Guile', 140),
  ('ken', 'Ken', 150),
  ('chun-li', 'Chun-Li', 160),
  ('zangief', 'Zangief', 170),
  ('dhalsim', 'Dhalsim', 180),
  ('rashid', 'Rashid', 190),
  ('aki', 'A.K.I.', 200),
  ('ed', 'Ed', 210),
  ('akuma', 'Akuma', 220),
  ('m-bison', 'M. Bison', 230),
  ('terry', 'Terry', 240),
  ('mai', 'Mai', 250),
  ('elena', 'Elena', 260),
  ('sagat', 'Sagat', 270),
  ('c-viper', 'C. Viper', 280),
  ('alex', 'Alex', 290),
  ('ingrid', 'Ingrid', 300);

create table public.avatar_assets (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete restrict,
  storage_path text not null unique,
  content_type text not null,
  byte_size integer not null,
  width integer not null,
  height integer not null,
  content_sha256 text not null,
  created_at timestamptz not null default statement_timestamp(),
  deleted_at timestamptz,
  constraint avatar_assets_storage_path_not_blank check (btrim(storage_path) <> ''),
  constraint avatar_assets_content_type check (content_type = 'image/webp'),
  constraint avatar_assets_size check (byte_size between 1 and 5242880),
  constraint avatar_assets_dimensions check (
    width between 1 and 512 and height between 1 and 512 and width = height
  ),
  constraint avatar_assets_sha256 check (content_sha256 ~ '^[0-9a-f]{64}$')
);

alter table public.profiles
  add column avatar_source public.avatar_source_type not null default 'default',
  add column avatar_asset_id uuid references public.avatar_assets (id) on delete restrict;

create unique index profiles_one_current_avatar_asset_idx
  on public.profiles (avatar_asset_id)
  where avatar_asset_id is not null;

alter table public.profiles
  add constraint profiles_avatar_shape check (
    (avatar_source = 'default' and avatar_url is null and avatar_asset_id is null)
    or (
      avatar_source in ('oauth', 'upload')
      and avatar_url is not null
      and avatar_asset_id is not null
    )
  ),
  add constraint profiles_username_phase2_length check (
    username is null or char_length(username) between 3 and 80
  ),
  add constraint profiles_username_normalized_phase2_length check (
    username_normalized is null or char_length(username_normalized) between 3 and 160
  ),
  add constraint profiles_username_no_whitespace_or_control check (
    username is null or username !~ '[[:space:][:cntrl:]]'
  ),
  add constraint profiles_country_master_fk
    foreign key (country_code) references public.countries (code) on delete restrict;

alter table public.profile_sf6_identities
  add column sf6_user_code_digest text,
  add constraint profile_sf6_identities_name_phase2_length check (
    sf6_player_name is null or char_length(sf6_player_name) between 1 and 128
  ),
  add constraint profile_sf6_identities_code_phase2_shape check (
    sf6_user_code is null
    or (
      sf6_user_code ~ '^[0-9]{10}$'
      and sf6_user_code_normalized = sf6_user_code
    )
  ),
  add constraint profile_sf6_identities_digest_shape check (
    sf6_user_code_digest is null
    or sf6_user_code_digest ~ '^[0-9a-f]{64}$'
  ),
  add constraint profile_sf6_identities_code_digest_pair check (
    sf6_user_code_digest is null or sf6_user_code is not null
  );

create unique index profile_sf6_identities_user_code_digest_unique
  on public.profile_sf6_identities (sf6_user_code_digest)
  where sf6_user_code_digest is not null;

alter table public.profile_private_details
  add constraint profile_private_details_region_master_fk
    foreign key (broad_region_code)
    references public.broad_regions (code)
    on delete restrict,
  add constraint profile_private_details_character_master_fk
    foreign key (main_character_code)
    references public.sf6_characters (code)
    on delete restrict,
  add constraint profile_private_details_master_rating_range check (
    current_master_rating is null or current_master_rating between 1 and 5000
  ),
  add constraint profile_private_details_rank_input_shape check (
    (
      current_sf6_rank is null
      and current_sf6_rank_tier is null
      and current_master_rating is null
    )
    or (
      current_sf6_rank = 'master'
      and current_sf6_rank_tier is null
      and current_master_rating is not null
    )
    or (
      current_sf6_rank is not null
      and current_sf6_rank <> 'master'
      and current_sf6_rank_tier is not null
      and current_master_rating is null
    )
  );

create table private.username_reservations (
  username_normalized text primary key,
  reason text not null,
  created_at timestamptz not null default statement_timestamp(),
  constraint username_reservations_not_blank check (
    btrim(username_normalized) <> '' and btrim(reason) <> ''
  )
);

insert into private.username_reservations (username_normalized, reason)
values
  ('admin', 'system role'),
  ('administrator', 'system role'),
  ('api', 'route'),
  ('auth', 'route'),
  ('login', 'route'),
  ('logout', 'route'),
  ('me', 'route'),
  ('moderator', 'system role'),
  ('profile', 'route'),
  ('settings', 'route'),
  ('support', 'system role'),
  ('system', 'system role');

create table private.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles (id) on delete restrict,
  auth_user_id uuid,
  status private.account_deletion_job_status not null default 'requested',
  attempt_count integer not null default 0,
  blocking_reasons jsonb not null default '[]'::jsonb,
  last_error_code text,
  requested_at timestamptz not null default statement_timestamp(),
  last_attempted_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  constraint account_deletion_jobs_attempts check (attempt_count >= 0),
  constraint account_deletion_jobs_blocking_reasons_array check (
    jsonb_typeof(blocking_reasons) = 'array'
  ),
  constraint account_deletion_jobs_completion_shape check (
    (status = 'completed' and completed_at is not null and auth_user_id is null)
    or (status <> 'completed' and completed_at is null and auth_user_id is not null)
  )
);

create table private.deleted_user_code_reclaims (
  id uuid primary key default gen_random_uuid(),
  code_digest text not null unique,
  deleted_profile_id uuid not null references public.profiles (id) on delete restrict,
  deletion_job_id uuid not null unique references private.account_deletion_jobs (id) on delete restrict,
  released_at timestamptz,
  released_by_admin_profile_id uuid references public.profiles (id) on delete restrict,
  release_reason text,
  created_at timestamptz not null default statement_timestamp(),
  constraint deleted_user_code_reclaims_digest_shape check (
    code_digest ~ '^[0-9a-f]{64}$'
  ),
  constraint deleted_user_code_reclaims_release_shape check (
    (
      released_at is null
      and released_by_admin_profile_id is null
      and release_reason is null
    )
    or (
      released_at is not null
      and released_by_admin_profile_id is not null
      and btrim(release_reason) <> ''
    )
  )
);

create table private.sf6_user_code_claims (
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

create table private.action_rate_limits (
  actor_key text not null,
  action_name text not null,
  window_started_at timestamptz not null,
  request_count integer not null default 0,
  updated_at timestamptz not null default statement_timestamp(),
  primary key (actor_key, action_name, window_started_at),
  constraint action_rate_limits_not_blank check (
    btrim(actor_key) <> '' and btrim(action_name) <> ''
  ),
  constraint action_rate_limits_nonnegative check (request_count >= 0)
);

create table private.action_rate_limit_rules (
  action_name text primary key,
  max_requests integer not null,
  window_seconds integer not null,
  updated_at timestamptz not null default statement_timestamp(),
  constraint action_rate_limit_rules_not_blank check (btrim(action_name) <> ''),
  constraint action_rate_limit_rules_positive check (
    max_requests > 0 and window_seconds > 0
  )
);

insert into private.action_rate_limit_rules (
  action_name,
  max_requests,
  window_seconds
)
values
  ('onboarding_step_save', 30, 300),
  ('profile_mutation', 10, 3600),
  ('avatar_mutation', 5, 3600),
  ('account_deletion', 3, 86400);

update public.starting_rating_parameter_sets
set is_active = false
where version = 'starting-rating-v1';

insert into public.starting_rating_parameter_sets (
  version,
  rank_base_ratings,
  subrank_adjustments,
  master_base_rating,
  master_mr_coefficient,
  master_mr_center,
  master_minimum,
  master_maximum,
  mr_validation_minimum,
  mr_validation_maximum,
  effective_from,
  is_active
)
select
  'starting-rating-v2',
  rank_base_ratings,
  subrank_adjustments,
  master_base_rating,
  master_mr_coefficient,
  master_mr_center,
  master_minimum,
  master_maximum,
  1,
  5000,
  '2026-08-17 00:00:00+00',
  true
from public.starting_rating_parameter_sets
where version = 'starting-rating-v1';

create or replace function private.guard_profile_region_country()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  profile_country text;
begin
  if new.broad_region_code is null then
    return new;
  end if;

  select profile.country_code
  into profile_country
  from public.profiles as profile
  where profile.id = new.profile_id;

  if not exists (
    select 1
    from public.broad_regions as region
    where region.code = new.broad_region_code
      and region.country_code = profile_country
      and region.is_active
  ) then
    raise exception using
      errcode = '23514',
      message = 'broad region must be active and belong to profile country';
  end if;

  return new;
end;
$$;

create trigger profile_private_details_guard_region_country
before insert or update of broad_region_code on public.profile_private_details
for each row execute function private.guard_profile_region_country();

create or replace function private.guard_profile_country_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.country_code is distinct from old.country_code
    and exists (
      select 1
      from public.profile_private_details as detail
      join public.broad_regions as region
        on region.code = detail.broad_region_code
      where detail.profile_id = new.id
        and region.country_code is distinct from new.country_code
    )
  then
    raise exception using
      errcode = '23514',
      message = 'country and broad region must be changed together';
  end if;

  return new;
end;
$$;

create trigger profiles_guard_country_change
before update of country_code on public.profiles
for each row execute function private.guard_profile_country_change();

create trigger countries_set_updated_at
before update on public.countries
for each row execute function private.set_updated_at();

create trigger broad_regions_set_updated_at
before update on public.broad_regions
for each row execute function private.set_updated_at();

create trigger sf6_characters_set_updated_at
before update on public.sf6_characters
for each row execute function private.set_updated_at();

create trigger account_deletion_jobs_set_updated_at
before update on private.account_deletion_jobs
for each row execute function private.set_updated_at();

create or replace function private.provision_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  provisioned_profile_id uuid;
begin
  if exists (
    select 1
    from public.profile_accounts as account
    where account.auth_user_id = new.id
  ) then
    return new;
  end if;

  provisioned_profile_id := gen_random_uuid();

  insert into public.profiles (id)
  values (provisioned_profile_id);

  insert into public.profile_accounts (profile_id, auth_user_id)
  values (provisioned_profile_id, new.id);

  insert into public.profile_sf6_identities (profile_id)
  values (provisioned_profile_id);

  insert into public.profile_private_details (profile_id)
  values (provisioned_profile_id);

  return new;
end;
$$;

create trigger auth_users_provision_profile
after insert on auth.users
for each row execute function private.provision_profile_for_auth_user();

do $$
declare
  existing_auth_user auth.users%rowtype;
  backfilled_profile_id uuid;
begin
  for existing_auth_user in
    select auth_user.*
    from auth.users as auth_user
    where not exists (
      select 1
      from public.profile_accounts as account
      where account.auth_user_id = auth_user.id
    )
  loop
    backfilled_profile_id := gen_random_uuid();

    insert into public.profiles (id)
    values (backfilled_profile_id);

    insert into public.profile_accounts (profile_id, auth_user_id)
    values (backfilled_profile_id, existing_auth_user.id);

    insert into public.profile_sf6_identities (profile_id)
    values (backfilled_profile_id);

    insert into public.profile_private_details (profile_id)
    values (backfilled_profile_id);
  end loop;
end;
$$;

comment on table public.countries is
  'Managed ISO 3166-1 alpha-2 country codes. Display names are localized in the application with Intl.DisplayNames.';
comment on table public.broad_regions is
  'Stable internal matchmaking regions. Labels may change without changing the code.';
comment on table private.deleted_user_code_reclaims is
  'Contains only a keyed digest, never the deleted raw SF6 User Code. Release is an audited Admin action.';

revoke all on table private.username_reservations from public, anon, authenticated;
revoke all on table private.account_deletion_jobs from public, anon, authenticated;
revoke all on table private.deleted_user_code_reclaims from public, anon, authenticated;
revoke all on table private.sf6_user_code_claims from public, anon, authenticated;
revoke all on table private.action_rate_limits from public, anon, authenticated;
revoke all on table private.action_rate_limit_rules from public, anon, authenticated;

grant all privileges on table private.username_reservations to service_role;
grant all privileges on table private.account_deletion_jobs to service_role;
grant all privileges on table private.deleted_user_code_reclaims to service_role;
grant all privileges on table private.sf6_user_code_claims to service_role;
grant all privileges on table private.action_rate_limits to service_role;
grant all privileges on table private.action_rate_limit_rules to service_role;
