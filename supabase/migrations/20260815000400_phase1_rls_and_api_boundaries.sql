-- Phase 1: deny-by-default API privileges, RLS read boundaries, and safe
-- public/limited projections. All domain writes remain reserved for trusted
-- RPCs or server transactions added by the owning feature phase.

create or replace function private.current_profile_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select account.profile_id
  from public.profile_accounts as account
  where account.auth_user_id = auth.uid()
    and account.account_status <> 'anonymized'
  limit 1;
$$;

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select account.application_role = 'admin'
      from public.profile_accounts as account
      where account.auth_user_id = auth.uid()
        and account.account_status = 'active'
      limit 1
    ),
    false
  );
$$;

create or replace function private.is_profile_public(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select profile.is_public and profile.deleted_at is null
      from public.profiles as profile
      where profile.id = target_profile_id
    ),
    false
  );
$$;

create or replace function private.is_match_participant(target_match_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.match_participants as participant
    where participant.match_id = target_match_id
      and participant.profile_id = private.current_profile_id()
  );
$$;

create or replace function private.can_view_active_match_identity(
  target_profile_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.matches as match
    join public.match_participants as viewer
      on viewer.match_id = match.id
    join public.match_participants as target
      on target.match_id = match.id
    where viewer.profile_id = private.current_profile_id()
      and target.profile_id = target_profile_id
      and match.status in ('matched', 'room_setup', 'reporting', 'disputed')
  );
$$;

create or replace function private.active_match_profile_projection()
returns table (
  match_id uuid,
  profile_id uuid,
  username text,
  avatar_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    participant.match_id,
    participant.profile_id,
    profile.username,
    profile.avatar_url
  from public.match_participants as participant
  join public.matches as match
    on match.id = participant.match_id
  join public.profiles as profile
    on profile.id = participant.profile_id
  where match.status in ('matched', 'room_setup', 'reporting', 'disputed')
    and (
      private.is_admin()
      or (
        profile.deleted_at is null
        and exists (
          select 1
          from public.match_participants as viewer
          where viewer.match_id = match.id
            and viewer.profile_id = private.current_profile_id()
        )
      )
    );
$$;

revoke all on function private.current_profile_id() from public;
revoke all on function private.is_admin() from public;
revoke all on function private.is_profile_public(uuid) from public;
revoke all on function private.is_match_participant(uuid) from public;
revoke all on function private.can_view_active_match_identity(uuid) from public;
revoke all on function private.active_match_profile_projection() from public;

grant usage on schema private to anon, authenticated, service_role;
grant execute on function private.current_profile_id() to authenticated, service_role;
grant execute on function private.is_admin() to authenticated, service_role;
grant execute on function private.is_profile_public(uuid) to anon, authenticated, service_role;
grant execute on function private.is_match_participant(uuid) to authenticated, service_role;
grant execute on function private.can_view_active_match_identity(uuid)
  to authenticated, service_role;
grant execute on function private.active_match_profile_projection()
  to authenticated, service_role;

alter table public.rating_parameter_sets enable row level security;
alter table public.starting_rating_parameter_sets enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_accounts enable row level security;
alter table public.profile_sf6_identities enable row level security;
alter table public.profile_private_details enable row level security;
alter table public.placement_initializations enable row level security;
alter table public.seasons enable row level security;
alter table public.season_player_records enable row level security;
alter table public.matches enable row level security;
alter table public.match_participants enable row level security;
alter table public.waiting_entries enable row level security;
alter table public.rated_pair_cooldowns enable row level security;
alter table public.result_reports enable row level security;
alter table public.result_report_revisions enable row level security;
alter table public.rating_history enable row level security;
alter table public.match_events enable row level security;
alter table public.incidents enable row level security;
alter table public.disputes enable row level security;
alter table public.user_restrictions enable row level security;
alter table public.restriction_incidents enable row level security;
alter table public.rating_corrections enable row level security;
alter table public.admin_audit_logs enable row level security;

create policy rating_parameter_sets_read
on public.rating_parameter_sets
for select
to anon, authenticated
using (true);

create policy starting_rating_parameter_sets_read
on public.starting_rating_parameter_sets
for select
to anon, authenticated
using (true);

create policy profiles_public_read
on public.profiles
for select
to anon, authenticated
using (is_public and deleted_at is null);

create policy profiles_owner_or_admin_read
on public.profiles
for select
to authenticated
using (
  id = private.current_profile_id()
  or private.is_admin()
);

create policy profile_accounts_owner_or_admin_read
on public.profile_accounts
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy profile_sf6_identities_limited_read
on public.profile_sf6_identities
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
  or private.can_view_active_match_identity(profile_id)
);

create policy profile_private_details_owner_or_admin_read
on public.profile_private_details
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy placement_initializations_owner_or_admin_read
on public.placement_initializations
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy seasons_read
on public.seasons
for select
to anon, authenticated
using (true);

create policy season_player_records_public_read
on public.season_player_records
for select
to anon, authenticated
using (private.is_profile_public(profile_id));

create policy season_player_records_owner_or_admin_read
on public.season_player_records
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy matches_participant_or_admin_read
on public.matches
for select
to authenticated
using (
  private.is_match_participant(id)
  or private.is_admin()
);

create policy match_participants_participant_or_admin_read
on public.match_participants
for select
to authenticated
using (
  private.is_match_participant(match_id)
  or private.is_admin()
);

create policy waiting_entries_owner_or_admin_read
on public.waiting_entries
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy rated_pair_cooldowns_involved_or_admin_read
on public.rated_pair_cooldowns
for select
to authenticated
using (
  private.current_profile_id() in (profile_low_id, profile_high_id)
  or private.is_admin()
);

create policy result_reports_blind_owner_or_admin_read
on public.result_reports
for select
to authenticated
using (
  reporting_profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy result_report_revisions_owner_or_admin_read
on public.result_report_revisions
for select
to authenticated
using (
  exists (
    select 1
    from public.result_reports as report
    where report.id = result_report_id
      and report.reporting_profile_id = private.current_profile_id()
  )
  or private.is_admin()
);

create policy rating_history_owner_or_admin_read
on public.rating_history
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy match_events_participant_or_admin_read
on public.match_events
for select
to authenticated
using (
  (
    visibility = 'participants'
    and private.is_match_participant(match_id)
  )
  or private.is_admin()
);

create policy incidents_reporter_or_admin_read
on public.incidents
for select
to authenticated
using (
  reporter_profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy disputes_admin_read
on public.disputes
for select
to authenticated
using (private.is_admin());

create policy user_restrictions_owner_or_admin_read
on public.user_restrictions
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy restriction_incidents_admin_read
on public.restriction_incidents
for select
to authenticated
using (private.is_admin());

create policy rating_corrections_owner_or_admin_read
on public.rating_corrections
for select
to authenticated
using (
  profile_id = private.current_profile_id()
  or private.is_admin()
);

create policy admin_audit_logs_admin_read
on public.admin_audit_logs
for select
to authenticated
using (private.is_admin());

create view public.public_profiles
with (security_invoker = true, security_barrier = true)
as
select
  profile.id,
  profile.username,
  profile.avatar_url,
  profile.country_code,
  profile.current_rating,
  profile.rating_reached_at,
  profile.placement_status,
  profile.placement_completed_count,
  profile.ranking_eligible,
  profile.created_at,
  profile.updated_at
from public.profiles as profile
where profile.is_public
  and profile.deleted_at is null;

create view public.active_match_private_profiles
with (security_invoker = true, security_barrier = true)
as
select
  participant.match_id,
  participant.profile_id,
  participant.side,
  profile.username,
  profile.avatar_url,
  participant.rating_snapshot,
  participant.placement_status_snapshot,
  participant.placement_completed_count_snapshot,
  identity.sf6_player_name,
  identity.sf6_user_code,
  match.host_profile_id,
  match.status
from public.match_participants as participant
join public.matches as match
  on match.id = participant.match_id
join private.active_match_profile_projection() as profile
  on profile.match_id = participant.match_id
  and profile.profile_id = participant.profile_id
join public.profile_sf6_identities as identity
  on identity.profile_id = participant.profile_id
where match.status in ('matched', 'room_setup', 'reporting', 'disputed');

comment on view public.public_profiles is
  'Public-only profile projection. Private region, character, auth, SF6 identity, moderation, and pending match data are structurally excluded.';

comment on view public.active_match_private_profiles is
  'Limited projection for current match participants and admins. Profile fields come from a column-limited active-match helper; all other security-invoker joins preserve underlying RLS policies.';

create or replace function public.phase1_database_health()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'schema_version', 'phase1-20260815',
    'active_rating_parameter_version', (
      select parameter.version
      from public.rating_parameter_sets as parameter
      where parameter.is_active
    ),
    'active_starting_rating_parameter_version', (
      select parameter.version
      from public.starting_rating_parameter_sets as parameter
      where parameter.is_active
    )
  );
$$;

revoke all on all tables in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke execute on all functions in schema public from public, anon, authenticated;
revoke all on table private.domain_action_receipts from public, anon, authenticated;
revoke execute on function private.claim_domain_action(text, text, text, uuid, text)
  from public, anon, authenticated;
revoke execute on function private.complete_domain_action(uuid, jsonb)
  from public, anon, authenticated;

grant select on public.rating_parameter_sets to anon, authenticated;
grant select on public.starting_rating_parameter_sets to anon, authenticated;
grant select on public.profiles to anon, authenticated;
grant select on public.seasons to anon, authenticated;
grant select on public.season_player_records to anon, authenticated;
grant select on public.public_profiles to anon, authenticated;

grant select on public.profile_accounts to authenticated;
grant select on public.profile_sf6_identities to authenticated;
grant select on public.profile_private_details to authenticated;
grant select on public.placement_initializations to authenticated;
grant select on public.matches to authenticated;
grant select on public.match_participants to authenticated;
grant select on public.waiting_entries to authenticated;
grant select on public.rated_pair_cooldowns to authenticated;
grant select on public.result_reports to authenticated;
grant select on public.result_report_revisions to authenticated;
grant select on public.rating_history to authenticated;
grant select on public.match_events to authenticated;
grant select on public.incidents to authenticated;
grant select on public.disputes to authenticated;
grant select on public.user_restrictions to authenticated;
grant select on public.restriction_incidents to authenticated;
grant select on public.rating_corrections to authenticated;
grant select on public.admin_audit_logs to authenticated;
grant select on public.active_match_private_profiles to authenticated;

grant all privileges on all tables in schema public to service_role;
grant all privileges on all sequences in schema public to service_role;
grant all privileges on table private.domain_action_receipts to service_role;
grant execute on function private.claim_domain_action(text, text, text, uuid, text)
  to service_role;
grant execute on function private.complete_domain_action(uuid, jsonb)
  to service_role;
grant execute on function public.phase1_database_health() to service_role;

alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
