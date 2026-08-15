-- Local/test-only baseline. Production season dates and names are an explicit
-- human operating decision and must be introduced by a reviewed migration.
insert into public.seasons (
  id,
  name,
  starts_at,
  ends_at,
  status
)
values (
  '00000000-0000-4000-8000-000000000001',
  'Local Test Season',
  date_trunc('quarter', statement_timestamp()),
  date_trunc('quarter', statement_timestamp()) + interval '3 months',
  'active'
)
on conflict (id) do update
set
  starts_at = excluded.starts_at,
  ends_at = excluded.ends_at,
  status = excluded.status,
  completed_at = null;
