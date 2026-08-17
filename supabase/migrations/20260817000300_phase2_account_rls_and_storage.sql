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

create policy avatars_owner_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = private.current_profile_id()::text
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

create policy avatars_owner_update
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and owner_id = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and owner_id = auth.uid()::text
  and (storage.foldername(name))[1] = private.current_profile_id()::text
);

create policy avatars_owner_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and owner_id = auth.uid()::text
);

revoke all on table public.countries from anon, authenticated;
revoke all on table public.broad_regions from anon, authenticated;
revoke all on table public.sf6_characters from anon, authenticated;
revoke all on table public.avatar_assets from anon, authenticated;

grant select on table public.countries to anon, authenticated;
grant select on table public.broad_regions to anon, authenticated;
grant select on table public.sf6_characters to anon, authenticated;
grant select on table public.avatar_assets to authenticated;

grant all privileges on table public.countries to service_role;
grant all privileges on table public.broad_regions to service_role;
grant all privileges on table public.sf6_characters to service_role;
grant all privileges on table public.avatar_assets to service_role;

comment on policy avatars_owner_insert on storage.objects is
  'Authenticated users may upload only to their immutable Public User ID folder. Content is decoded and re-encoded by the trusted server before upload.';
comment on policy avatar_assets_owner_or_admin_read on public.avatar_assets is
  'Public profiles expose only avatar_url; internal object metadata remains owner/admin only.';

