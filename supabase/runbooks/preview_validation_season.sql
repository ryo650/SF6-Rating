-- Preview/Staging only.
-- Approved Supabase project ref: zeervsxefloyvuvzaakg
--
-- This SQL cannot discover the Supabase project ref from PostgreSQL. Follow
-- docs/runbooks/preview-validation-season-bootstrap.md and verify the linked
-- ref before execution. Never run this file against a Production project.

do $$
declare
  preview_season_id constant uuid := '00000000-0000-4000-8000-000000000002';
  preview_season_name constant text := 'Preview Validation Season';
  active_season_count bigint;
begin
  select count(*)
  into active_season_count
  from public.seasons
  where status = 'active';

  if exists (
    select 1
    from public.seasons
    where id = preview_season_id
      and name = preview_season_name
      and status = 'active'
      and ends_at = starts_at + interval '3 months'
  ) then
    if active_season_count <> 1 then
      raise exception 'preview_validation_season_invariant_failed';
    end if;

    raise notice 'Preview Validation Season already active; no changes made';
    return;
  end if;

  if exists (
    select 1
    from public.seasons
    where id = preview_season_id
      or name = preview_season_name
  ) then
    raise exception 'preview_validation_season_conflict';
  end if;

  if active_season_count <> 0 then
    raise exception 'preview_validation_season_requires_zero_active_seasons';
  end if;

  insert into public.seasons (id, name, starts_at, ends_at, status)
  values (
    preview_season_id,
    preview_season_name,
    date_trunc('quarter', statement_timestamp()),
    date_trunc('quarter', statement_timestamp()) + interval '3 months',
    'active'
  );
end;
$$;
