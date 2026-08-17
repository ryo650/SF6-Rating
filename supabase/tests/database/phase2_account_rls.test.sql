begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

select is(
  (
    select count(*)
    from pg_catalog.pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname like 'avatars_%'
  ),
  4::bigint,
  'Avatar Storage has explicit insert/select/update/delete policies'
);
select is(
  (
    select count(*)
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in ('countries', 'broad_regions', 'sf6_characters', 'avatar_assets')
      and grantee in ('anon', 'authenticated')
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE')
  ),
  0::bigint,
  'new Phase 2 public tables expose no browser mutation grants'
);
select ok(has_table_privilege('anon', 'public.countries', 'SELECT'), 'anonymous users can read active country master data');
select ok(has_table_privilege('authenticated', 'public.broad_regions', 'SELECT'), 'authenticated users can read active region master data');
select ok(not has_table_privilege('anon', 'public.avatar_assets', 'SELECT'), 'anonymous users cannot inspect Avatar object metadata');

insert into auth.users (
  id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('30000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-owner@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp()),
  ('30000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rls-other@example.test', '', statement_timestamp(), '{}'::jsonb, '{}'::jsonb, statement_timestamp(), statement_timestamp());

do $$
begin
  perform public.phase2_save_account_step('30000000-0000-4000-8000-000000000001', 'RlsOwner', 'rlsowner', null, 'rls-owner-account', repeat('a', 64));
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-4000-8000-000000000002', true);
select is((select count(*) from public.profile_accounts), 1::bigint, 'an authenticated user sees only their own account row');
select is((select count(*) from public.profile_sf6_identities), 1::bigint, 'an authenticated user sees only their own identity row outside Active Match');
select is((select count(*) from public.profile_private_details), 1::bigint, 'an authenticated user sees only their own private details row');
select is((select count(*) from public.public_profiles), 0::bigint, 'an unfinished private profile is absent from public projection');
select ok(
  not has_function_privilege('authenticated', 'public.phase2_request_account_deletion(uuid,text,text)', 'EXECUTE'),
  'browser role cannot invoke deletion RPC with a spoofed actor UUID'
);

select * from finish();
rollback;
