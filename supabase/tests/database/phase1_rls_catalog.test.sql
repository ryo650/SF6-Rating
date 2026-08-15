begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(10);

select is(
  (
    select count(*)
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and not relation.relrowsecurity
  ),
  0::bigint,
  'every current and future public base table must enable RLS'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relkind in ('r', 'p')
      and not exists (
        select 1
        from pg_catalog.pg_policies as policy
        where policy.schemaname = namespace.nspname
          and policy.tablename = relation.relname
      )
  ),
  0::bigint,
  'every current and future public base table must have an explicit policy'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_policies as policy
    where policy.schemaname = 'public'
      and policy.cmd <> 'SELECT'
  ),
  0::bigint,
  'browser policies do not authorize direct writes'
);

select is(
  (
    select count(*)
    from information_schema.role_table_grants as privilege
    where privilege.table_schema = 'public'
      and privilege.grantee in ('anon', 'authenticated')
      and privilege.privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER')
  ),
  0::bigint,
  'anon and authenticated roles have no direct table mutation grants'
);

select is(
  (
    select count(*)
    from pg_catalog.pg_class as relation
    join pg_catalog.pg_namespace as namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'public_profiles',
        'active_match_private_profiles'
      )
      and relation.reloptions @> array[
        'security_invoker=true',
        'security_barrier=true'
      ]
  ),
  2::bigint,
  'both browser views preserve invoker RLS and use a security barrier'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.phase1_database_health()',
    'EXECUTE'
  ),
  'authenticated users cannot execute the service health function'
);

select ok(
  has_function_privilege(
    'service_role',
    'public.phase1_database_health()',
    'EXECUTE'
  ),
  'the service role can execute the Phase 1 health function'
);

select is(
  pg_get_function_result(
    'private.active_match_profile_projection()'::regprocedure
  ),
  'TABLE(match_id uuid, profile_id uuid, username text, avatar_url text)',
  'the active-match profile helper exposes only its four reviewed projection columns'
);

select ok(
  not has_function_privilege(
    'anon',
    'private.active_match_profile_projection()',
    'EXECUTE'
  ),
  'anonymous users cannot execute the active-match profile helper'
);

select ok(
  has_function_privilege(
    'authenticated',
    'private.active_match_profile_projection()',
    'EXECUTE'
  ),
  'authenticated users can execute the guarded helper through the match-room view'
);

select * from finish();
rollback;
