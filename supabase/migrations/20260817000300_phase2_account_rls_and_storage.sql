-- Phase 2: read projections, default-deny RLS, and owner-only Avatar Storage.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'avatars',
  'avatars',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

alter table public.countries enable row level security;
alter table public.broad_regions enable row level security;
alter table public.sf6_characters enable row level security;
alter table public.avatar_assets enable row level security;

create policy countries_read
on public.countries
for select
to anon, authenticated
using (is_active);

create policy broad_regions_read
on public.broad_regions
for select
to anon, authenticated
using (is_active);

create policy sf6_characters_read
on public.sf6_characters
for select
to anon, authenticated
using (is_active);

create policy avatar_assets_owner_or_admin_read
on public.avatar_assets
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy avatars_owner_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (
    owner_id = auth.uid()::text
    or private.is_admin()
  )
);

revoke all on table public.countries from anon, authenticated;
revoke all on table public.broad_regions from anon, authenticated;
revoke all on table public.sf6_characters from anon, authenticated;
revoke all on table public.avatar_assets from anon, authenticated;

grant select on table public.countries to anon, authenticated;
grant select on table public.broad_regions to anon, authenticated;
grant select on table public.sf6_characters to anon, authenticated;
grant select on table public.avatar_assets to authenticated;

-- Security-invoker projections retain RLS while column grants prevent callers
-- from bypassing the approved public/active-opponent field sets.
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

grant all privileges on table public.countries to service_role;
grant all privileges on table public.broad_regions to service_role;
grant all privileges on table public.sf6_characters to service_role;
grant all privileges on table public.avatar_assets to service_role;

comment on policy avatars_owner_select on storage.objects is
  'Owners may inspect their object metadata. All mutations use the server-only trusted image pipeline; browser writes are denied.';
comment on policy avatar_assets_owner_or_admin_read on public.avatar_assets is
  'Public profiles expose only avatar_url; internal object metadata remains owner/admin only.';
