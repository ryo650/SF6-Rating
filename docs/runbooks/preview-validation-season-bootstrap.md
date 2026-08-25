# Preview Validation Season Bootstrap

Status: Human approval required before execution

Environment: Preview / Staging only

Allowed Supabase project: `SF6-Rating` (`zeervsxefloyvuvzaakg`)

## Purpose

Create the single active `Preview Validation Season` needed for hosted
onboarding and Placement verification. This is operational Preview data, not a
migration or seed. `Local Test Season` remains local-only, and a future
Production project must receive its own formally managed Production Season.

## Safety boundary

- Do not run this procedure on a Production project.
- Do not add the Preview Season to migrations or `supabase/seed.sql`.
- Obtain Human approval immediately before execution.
- The SQL engine cannot discover a Supabase project ref. The linked-project
  check below is therefore mandatory and must match exactly.
- Stop if any active Season or a conflicting row already exists. Do not edit,
  complete, or delete it as part of this runbook.

## Preflight

From the repository root, confirm the linked project without changing it:

```sh
supabase projects list
cat supabase/.temp/project-ref
```

The linked ref must be exactly `zeervsxefloyvuvzaakg`. Also confirm in the
Supabase Dashboard that the selected project is named `SF6-Rating` and is the
Preview / Staging project. Stop on any mismatch.

Run these read-only queries in that project's SQL Editor:

```sql
select id, name, starts_at, ends_at, status, completed_at
from public.seasons
order by starts_at, id;

select count(*) as active_season_count
from public.seasons
where status = 'active';
```

The first execution requires `active_season_count = 0`. A repeat execution is
allowed only when the one active row is already the exact
`Preview Validation Season` created by this runbook.

## Apply after approval

Open and review
`supabase/runbooks/preview_validation_season.sql`, then execute the complete
file in the SQL Editor for project `zeervsxefloyvuvzaakg`.

The script is idempotent:

- the exact active Preview row is a no-op;
- any row with the reserved ID or name but a different shape fails closed;
- any other active Season fails the zero-active-Season precondition;
- creation uses the current UTC quarter and the schema-required three-month
  duration.

## Post-apply verification

```sql
select id, name, starts_at, ends_at, status, completed_at
from public.seasons
where id = '00000000-0000-4000-8000-000000000002';

select count(*) as active_season_count
from public.seasons
where status = 'active';
```

Expected result:

- one row named `Preview Validation Season`;
- `status = 'active'`;
- `ends_at = starts_at + interval '3 months'`;
- `completed_at is null`;
- `active_season_count = 1`.

Then repeat the SQL file once. It must emit the no-change notice and leave the
same row unchanged. Finally, perform the hosted onboarding smoke with a
disposable Preview test account. Test-account cleanup and future Preview Season
rollover are separate approved operational actions; do not copy Preview Rating
History into the future Production project.
