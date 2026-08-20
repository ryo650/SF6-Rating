begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(18);

select is((select count(*) from public.countries), 249::bigint, 'all ISO alpha-2 country codes are seeded');
select is((select count(*) from public.broad_regions where country_code = 'JP'), 7::bigint, 'Japan has the seven approved broad regions');
select is((select count(*) from public.broad_regions where country_code <> 'JP'), 248::bigint, 'every non-Japan country has a country-wide fallback');
select is((select version from public.starting_rating_parameter_sets where is_active), 'starting-rating-v2', 'starting-rating-v2 is active');
select is((select mr_validation_minimum from public.starting_rating_parameter_sets where is_active), 1, 'Master MR minimum is 1');
select is((select mr_validation_maximum from public.starting_rating_parameter_sets where is_active), 5000, 'Master MR maximum is 5000');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '10000000-0000-4000-8000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'authenticated', 'authenticated', 'phase2-schema@example.test', '',
  statement_timestamp(), '{}'::jsonb, '{}'::jsonb,
  statement_timestamp(), statement_timestamp()
);

select is(
  (select count(*) from public.profile_accounts where auth_user_id = '10000000-0000-4000-8000-000000000001'),
  1::bigint,
  'Auth insertion provisions one account mapping'
);
select is(
  (
    select count(*)
    from public.profile_sf6_identities as identity
    join public.profile_accounts as account on account.profile_id = identity.profile_id
    where account.auth_user_id = '10000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'Auth insertion provisions an SF6 identity skeleton'
);
select is(
  (
    select count(*)
    from public.profile_private_details as detail
    join public.profile_accounts as account on account.profile_id = detail.profile_id
    where account.auth_user_id = '10000000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'Auth insertion provisions a private details skeleton'
);

select throws_ok(
  $$
    update public.profile_sf6_identities
    set sf6_user_code = '123456789012', sf6_user_code_normalized = '123456789012'
    where profile_id = (
      select profile_id from public.profile_accounts
      where auth_user_id = '10000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514',
  null,
  'the database rejects non-10-digit SF6 User Codes'
);

select throws_ok(
  $$
    update public.profiles
    set username = 'bad name', username_normalized = 'bad name'
    where id = (
      select profile_id from public.profile_accounts
      where auth_user_id = '10000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514',
  null,
  'the database rejects whitespace in Username'
);

update public.profiles
set country_code = 'JP'
where id = (
  select profile_id from public.profile_accounts
  where auth_user_id = '10000000-0000-4000-8000-000000000001'
);

select throws_ok(
  $$
    update public.profile_private_details
    set broad_region_code = 'US-ALL'
    where profile_id = (
      select profile_id from public.profile_accounts
      where auth_user_id = '10000000-0000-4000-8000-000000000001'
    )
  $$,
  '23514',
  null,
  'a broad region from another country is rejected'
);

select is(
  (select file_size_limit from storage.buckets where id = 'avatars'),
  5242880::bigint,
  'Avatar bucket enforces the 5 MB limit'
);
select ok((select public from storage.buckets where id = 'avatars'), 'Avatar bucket supports public delivery');
select is(
  (select allowed_mime_types from storage.buckets where id = 'avatars'),
  array['image/jpeg', 'image/png', 'image/webp']::text[],
  'Avatar bucket accepts only the approved input MIME types'
);
select ok(
  not has_function_privilege('authenticated', 'public.phase2_complete_onboarding(uuid,text,public.sf6_rank,smallint,integer,text,text,text)', 'EXECUTE'),
  'authenticated browser role cannot execute trusted completion RPC'
);
select ok(
  has_function_privilege('service_role', 'public.phase2_complete_onboarding(uuid,text,public.sf6_rank,smallint,integer,text,text,text)', 'EXECUTE'),
  'service role can execute trusted completion RPC'
);
select is(
  (select count(*) from public.sf6_characters where is_active),
  30::bigint,
  'the current managed SF6 character roster is seeded'
);

select * from finish();
rollback;
