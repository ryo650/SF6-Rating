-- Phase 1: lifecycle guards, immutable audit records, and reusable
-- transaction/idempotency primitives for later trusted domain actions.

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  return new;
end;
$$;

create or replace function private.set_updated_at_and_increment_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := statement_timestamp();
  new.version := old.version + 1;
  return new;
end;
$$;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create or replace function private.preserve_placement_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.placement_completed_count < old.placement_completed_count then
    raise exception using
      errcode = '23514',
      message = 'placement progress cannot be rolled back';
  end if;

  if old.placement_status = 'completed'
    and (
      new.placement_status <> 'completed'
      or new.placement_completed_count <> 10
      or not new.ranking_eligible
    )
  then
    raise exception using
      errcode = '23514',
      message = 'completed placement cannot be reopened';
  end if;

  return new;
end;
$$;

create trigger profiles_preserve_placement_completion
before update on public.profiles
for each row execute function private.preserve_placement_completion();

create trigger profile_accounts_set_updated_at
before update on public.profile_accounts
for each row execute function private.set_updated_at();

create trigger profile_sf6_identities_set_updated_at
before update on public.profile_sf6_identities
for each row execute function private.set_updated_at();

create trigger profile_private_details_set_updated_at
before update on public.profile_private_details
for each row execute function private.set_updated_at();

create trigger seasons_set_updated_at
before update on public.seasons
for each row execute function private.set_updated_at();

create or replace function private.guard_season_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status = 'completed' then
    raise exception using
      errcode = '23514',
      message = 'completed seasons are immutable';
  end if;

  if new.starts_at <> old.starts_at or new.ends_at <> old.ends_at then
    raise exception using
      errcode = '23514',
      message = 'season time attribution is immutable after creation';
  end if;

  if new.status <> old.status
    and not (
      (old.status = 'upcoming' and new.status = 'active')
      or (old.status = 'active' and new.status = 'completed')
    )
  then
    raise exception using
      errcode = '23514',
      message = format('invalid season transition: %s -> %s', old.status, new.status);
  end if;

  return new;
end;
$$;

create trigger seasons_guard_lifecycle
before update on public.seasons
for each row execute function private.guard_season_lifecycle();

create trigger season_player_records_set_updated_at
before update on public.season_player_records
for each row execute function private.set_updated_at();

create trigger waiting_entries_set_updated_at
before update on public.waiting_entries
for each row execute function private.set_updated_at_and_increment_version();

create or replace function private.guard_result_report_payload()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  winner_side public.match_side;
begin
  select participant.side
  into winner_side
  from public.match_participants as participant
  where participant.match_id = new.match_id
    and participant.profile_id = new.reported_winner_profile_id;

  if winner_side is null then
    raise exception using
      errcode = '23503',
      message = 'reported winner must be a match participant';
  end if;

  if new.report_type = 'normal'
    and not (
      (winner_side = 'player_a' and new.player_a_score = 3)
      or (winner_side = 'player_b' and new.player_b_score = 3)
    )
  then
    raise exception using
      errcode = '23514',
      message = 'reported winner must be the side with three wins';
  end if;

  return new;
end;
$$;

create trigger result_reports_guard_payload
before insert or update on public.result_reports
for each row execute function private.guard_result_report_payload();

create trigger result_reports_set_updated_at
before update on public.result_reports
for each row execute function private.set_updated_at();

create trigger incidents_set_updated_at
before update on public.incidents
for each row execute function private.set_updated_at();

create trigger disputes_set_updated_at
before update on public.disputes
for each row execute function private.set_updated_at_and_increment_version();

create trigger user_restrictions_set_updated_at
before update on public.user_restrictions
for each row execute function private.set_updated_at();

create or replace function private.is_valid_match_transition(
  from_status public.match_status,
  to_status public.match_status
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select case from_status
    when 'matched' then to_status in ('room_setup', 'cancelled')
    when 'room_setup' then to_status in ('reporting', 'cancelled')
    when 'reporting' then to_status in ('completed', 'disputed', 'cancelled')
    when 'disputed' then to_status in ('completed', 'cancelled')
    when 'completed' then false
    when 'cancelled' then false
  end;
$$;

create or replace function private.is_valid_rating_status_transition(
  from_status public.match_rating_status,
  to_status public.match_rating_status
)
returns boolean
language sql
immutable
strict
set search_path = ''
as $$
  select from_status = to_status
    or (from_status = 'pending' and to_status in ('applied', 'not_applicable'))
    or (from_status = 'applied' and to_status = 'correction_pending')
    or (from_status = 'correction_pending' and to_status = 'corrected');
$$;

create or replace function private.guard_match_lifecycle()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  winner_side public.match_side;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'matched' then
      raise exception using
        errcode = '23514',
        message = 'a match must be created in matched status';
    end if;

    new.created_at := statement_timestamp();
    new.matched_at := new.created_at;
    new.updated_at := new.created_at;
    new.version := 1;
  else
    if new.season_id <> old.season_id
      or new.is_rated <> old.is_rated
      or new.creation_source <> old.creation_source
      or new.rating_parameter_version is distinct from old.rating_parameter_version
      or new.created_at <> old.created_at
      or new.matched_at <> old.matched_at
    then
      raise exception using
        errcode = '23514',
        message = 'match attribution and rating snapshots are immutable';
    end if;

    if new.status <> old.status
      and not private.is_valid_match_transition(old.status, new.status)
    then
      raise exception using
        errcode = '23514',
        message = format(
          'invalid match transition: %s -> %s',
          old.status,
          new.status
        );
    end if;

    if new.status <> old.status
      and (
        (
          new.status = 'completed'
          and (
            new.resolution_type is null
            or not (
            (
              old.status = 'reporting'
              and new.resolution_type in ('normal', 'forfeit')
            )
            or (
              old.status = 'disputed'
              and new.resolution_type = 'admin_result'
            )
            )
          )
        )
        or (
          new.status = 'cancelled'
          and (
            new.resolution_type is null
            or not (
            (
              new.resolution_type = 'season_boundary_no_rating'
              and new.is_rated
            )
            or (
              old.status in ('matched', 'room_setup')
              and new.resolution_type in (
                'mutual_cancel',
                'admin_invalid_no_rating'
              )
            )
            or (
              old.status = 'reporting'
              and new.resolution_type in (
                'mutual_cancel',
                'nonresponse_no_rating',
                'mutual_no_rating'
              )
            )
            or (
              old.status = 'disputed'
              and new.resolution_type in (
                'mutual_no_rating',
                'admin_invalid_no_rating'
              )
            )
            )
          )
        )
      )
    then
      raise exception using
        errcode = '23514',
        message = format(
          'resolution %s is not valid for transition %s -> %s',
          new.resolution_type,
          old.status,
          new.status
        );
    end if;

    if new.rating_status <> old.rating_status
      and not private.is_valid_rating_status_transition(
        old.rating_status,
        new.rating_status
      )
    then
      raise exception using
        errcode = '23514',
        message = format(
          'invalid rating status transition: %s -> %s',
          old.rating_status,
          new.rating_status
        );
    end if;

    if old.result_validity = 'invalidated'
      and new.result_validity is distinct from old.result_validity
    then
      raise exception using
        errcode = '23514',
        message = 'an invalidated result cannot become valid again';
    end if;

    if old.status in ('completed', 'cancelled') then
      if new.status <> old.status
        or new.resolution_type is distinct from old.resolution_type
        or new.winner_profile_id is distinct from old.winner_profile_id
        or new.loser_profile_id is distinct from old.loser_profile_id
        or new.player_a_score is distinct from old.player_a_score
        or new.player_b_score is distinct from old.player_b_score
        or new.termination_player_a_score is distinct from old.termination_player_a_score
        or new.termination_player_b_score is distinct from old.termination_player_b_score
        or new.completed_at is distinct from old.completed_at
        or new.cancelled_at is distinct from old.cancelled_at
      then
        raise exception using
          errcode = '23514',
          message = 'terminal match result fields are immutable';
      end if;
    end if;

    if new.host_profile_id is distinct from old.host_profile_id
      and old.status <> 'room_setup'
    then
      raise exception using
        errcode = '23514',
        message = 'host can only change during room_setup';
    end if;

    new.updated_at := statement_timestamp();
    new.version := old.version + 1;
  end if;

  if new.status = 'room_setup' and new.room_setup_started_at is null then
    new.room_setup_started_at := statement_timestamp();
  elsif new.status = 'reporting' and new.reporting_started_at is null then
    new.reporting_started_at := statement_timestamp();
  elsif new.status = 'disputed' and new.disputed_at is null then
    new.disputed_at := statement_timestamp();
  elsif new.status = 'completed' and new.completed_at is null then
    new.completed_at := statement_timestamp();
  elsif new.status = 'cancelled' and new.cancelled_at is null then
    new.cancelled_at := statement_timestamp();
  end if;

  if new.host_profile_id is null then
    raise exception using
      errcode = '23514',
      message = 'match host must be one of the two participants';
  end if;

  if new.status in ('matched', 'room_setup', 'reporting', 'disputed') then
    if new.resolution_type is not null
      or new.result_validity is not null
      or new.winner_profile_id is not null
      or new.loser_profile_id is not null
      or new.player_a_score is not null
      or new.player_b_score is not null
      or new.termination_player_a_score is not null
      or new.termination_player_b_score is not null
      or new.completed_at is not null
      or new.cancelled_at is not null
      or (new.status <> 'disputed' and new.disputed_at is not null)
      or (new.is_rated and new.rating_status <> 'pending')
      or (not new.is_rated and new.rating_status <> 'not_applicable')
    then
      raise exception using
        errcode = '23514',
        message = 'nonterminal match contains terminal result data';
    end if;

    if new.status in ('reporting', 'disputed')
      and (
        new.room_setup_started_at is null
        or new.reporting_started_at is null
      )
    then
      raise exception using
        errcode = '23514',
        message = 'reporting requires room_setup and reporting timestamps';
    end if;
  elsif new.status = 'completed' then
    if new.resolution_type is null
      or new.resolution_type not in ('normal', 'forfeit', 'admin_result')
      or new.result_validity is null
      or new.winner_profile_id is null
      or new.loser_profile_id is null
      or new.completed_at is null
      or new.cancelled_at is not null
      or (new.is_rated and new.rating_status not in (
        'applied',
        'correction_pending',
        'corrected'
      ))
      or (not new.is_rated and new.rating_status <> 'not_applicable')
      or (
        new.is_rated
        and new.result_validity = 'valid'
        and new.rating_status <> 'applied'
      )
      or (
        new.is_rated
        and new.result_validity = 'invalidated'
        and new.rating_status not in ('correction_pending', 'corrected')
      )
    then
      raise exception using
        errcode = '23514',
        message = 'completed match is missing a coherent result';
    end if;

    if new.resolution_type = 'normal'
      and (new.player_a_score is null or new.player_b_score is null)
    then
      raise exception using
        errcode = '23514',
        message = 'normal completion requires an FT3 score';
    end if;

    if new.resolution_type = 'forfeit'
      and (new.player_a_score is not null or new.player_b_score is not null)
    then
      raise exception using
        errcode = '23514',
        message = 'forfeit must not invent a normal FT3 score';
    end if;

    if new.player_a_score is not null then
      if not (
        (new.player_a_score = 3 and new.player_b_score between 0 and 2)
        or (new.player_b_score = 3 and new.player_a_score between 0 and 2)
      ) then
        raise exception using
          errcode = '23514',
          message = 'completed normal score must be 3-0, 3-1, or 3-2';
      end if;

      select mp.side
      into winner_side
      from public.match_participants as mp
      where mp.match_id = new.id
        and mp.profile_id = new.winner_profile_id;

      if winner_side is null
        or (winner_side = 'player_a' and new.player_a_score <> 3)
        or (winner_side = 'player_b' and new.player_b_score <> 3)
      then
        raise exception using
          errcode = '23514',
          message = 'winner does not match the normalized FT3 score';
      end if;
    end if;
  elsif new.status = 'cancelled' then
    if new.resolution_type is null
      or new.resolution_type not in (
      'mutual_cancel',
      'nonresponse_no_rating',
      'mutual_no_rating',
      'admin_invalid_no_rating',
      'season_boundary_no_rating'
    )
      or new.result_validity is not null
      or new.winner_profile_id is not null
      or new.loser_profile_id is not null
      or new.player_a_score is not null
      or new.player_b_score is not null
      or new.termination_player_a_score is not null
      or new.termination_player_b_score is not null
      or new.rating_status <> 'not_applicable'
      or new.cancelled_at is null
      or new.completed_at is not null
    then
      raise exception using
        errcode = '23514',
        message = 'cancelled match must end without winner or rating';
    end if;
  end if;

  return new;
end;
$$;

create trigger matches_guard_lifecycle
before insert or update on public.matches
for each row execute function private.guard_match_lifecycle();

create or replace function private.preserve_match_participant_snapshot()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.match_id <> old.match_id
    or new.profile_id <> old.profile_id
    or new.side <> old.side
    or new.rating_snapshot <> old.rating_snapshot
    or new.placement_status_snapshot <> old.placement_status_snapshot
    or new.placement_completed_count_snapshot <> old.placement_completed_count_snapshot
    or new.joined_at <> old.joined_at
  then
    raise exception using
      errcode = '23514',
      message = 'match participant identity, side, and competitive snapshots are immutable';
  end if;

  return new;
end;
$$;

create trigger match_participants_preserve_snapshot
before update on public.match_participants
for each row execute function private.preserve_match_participant_snapshot();

create or replace function private.sync_match_participant_activity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_status public.match_status;
begin
  select m.status
  into parent_status
  from public.matches as m
  where m.id = new.match_id;

  if parent_status is null then
    raise exception using
      errcode = '23503',
      message = 'match participant requires an existing match';
  end if;

  new.is_active := parent_status in (
    'matched',
    'room_setup',
    'reporting',
    'disputed'
  );
  new.cleared_at := case
    when new.is_active then null
    else coalesce(new.cleared_at, statement_timestamp())
  end;

  return new;
end;
$$;

create trigger match_participants_sync_activity_on_write
before insert or update on public.match_participants
for each row execute function private.sync_match_participant_activity();

create or replace function private.propagate_match_activity()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status in ('completed', 'cancelled')
    and old.status not in ('completed', 'cancelled')
  then
    update public.match_participants
    set
      is_active = false,
      cleared_at = coalesce(cleared_at, statement_timestamp())
    where match_id = new.id;
  end if;

  return null;
end;
$$;

create trigger matches_propagate_activity
after update of status on public.matches
for each row execute function private.propagate_match_activity();

create or replace function private.enforce_match_participant_cardinality()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_match_id uuid;
  participant_count integer;
  side_count integer;
begin
  if tg_table_name = 'matches' then
    target_match_id := case when tg_op = 'DELETE' then old.id else new.id end;
  else
    target_match_id := case
      when tg_op = 'DELETE' then old.match_id
      else new.match_id
    end;
  end if;

  if not exists (
    select 1
    from public.matches as m
    where m.id = target_match_id
  ) then
    return null;
  end if;

  select count(*), count(distinct mp.side)
  into participant_count, side_count
  from public.match_participants as mp
  where mp.match_id = target_match_id;

  if participant_count <> 2 or side_count <> 2 then
    raise exception using
      errcode = '23514',
      message = 'a match must have exactly one player_a and one player_b';
  end if;

  return null;
end;
$$;

create constraint trigger matches_participant_cardinality
after insert or update of host_profile_id, winner_profile_id, loser_profile_id
on public.matches
deferrable initially deferred
for each row execute function private.enforce_match_participant_cardinality();

create constraint trigger match_participants_cardinality
after insert or update or delete on public.match_participants
deferrable initially deferred
for each row execute function private.enforce_match_participant_cardinality();

create or replace function private.prevent_completed_season_record_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_status public.season_status;
begin
  select season.status
  into parent_status
  from public.seasons as season
  where season.id = new.season_id
  for share;

  if parent_status = 'completed' then
    raise exception using
      errcode = '23514',
      message = 'completed season snapshot membership is immutable';
  end if;

  return new;
end;
$$;

create trigger season_player_records_prevent_completed_season_insert
before insert on public.season_player_records
for each row execute function private.prevent_completed_season_record_insert();

create or replace function private.prevent_finalized_season_record_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.record_status = 'finalized' then
    raise exception using
      errcode = '23514',
      message = 'finalized season snapshots are immutable';
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;

  return new;
end;
$$;

create trigger season_player_records_preserve_final_snapshot
before update or delete on public.season_player_records
for each row execute function private.prevent_finalized_season_record_mutation();

create or replace function private.enforce_season_record_state()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  parent_status public.season_status;
begin
  select season.status
  into parent_status
  from public.seasons as season
  where season.id = new.season_id;

  if (new.record_status = 'finalized' and parent_status <> 'completed')
    or (new.record_status = 'live' and parent_status = 'completed')
  then
    raise exception using
      errcode = '23514',
      message = 'season record status must agree with the parent season state';
  end if;

  return null;
end;
$$;

create constraint trigger season_player_records_require_matching_season_state
after insert or update of record_status, season_id on public.season_player_records
deferrable initially immediate
for each row execute function private.enforce_season_record_state();

create or replace function private.enforce_completed_season_records()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'completed'
    and exists (
      select 1
      from public.season_player_records as record
      where record.season_id = new.id
        and record.record_status <> 'finalized'
    )
  then
    raise exception using
      errcode = '23514',
      message = 'a completed season cannot retain live player records';
  end if;

  return null;
end;
$$;

create constraint trigger seasons_require_finalized_player_records
after update of status on public.seasons
deferrable initially immediate
for each row execute function private.enforce_completed_season_records();

create or replace function private.prevent_append_only_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '23514',
    message = format('%s is append-only', tg_table_name);
end;
$$;

create trigger rating_history_append_only
before update or delete on public.rating_history
for each row execute function private.prevent_append_only_mutation();

create trigger result_report_revisions_append_only
before update or delete on public.result_report_revisions
for each row execute function private.prevent_append_only_mutation();

create trigger match_events_append_only
before update or delete on public.match_events
for each row execute function private.prevent_append_only_mutation();

create trigger admin_audit_logs_append_only
before update or delete on public.admin_audit_logs
for each row execute function private.prevent_append_only_mutation();

create or replace function private.guard_parameter_set_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception using
      errcode = '23514',
      message = 'versioned parameter sets cannot be deleted';
  end if;

  if (to_jsonb(new) - 'is_active') <> (to_jsonb(old) - 'is_active') then
    raise exception using
      errcode = '23514',
      message = 'versioned parameter values are immutable';
  end if;

  return new;
end;
$$;

create trigger rating_parameter_sets_versioned_immutable
before update or delete on public.rating_parameter_sets
for each row execute function private.guard_parameter_set_mutation();

create trigger starting_rating_parameter_sets_versioned_immutable
before update or delete on public.starting_rating_parameter_sets
for each row execute function private.guard_parameter_set_mutation();

alter table public.rating_history
  add constraint rating_history_parameter_version_fk
  foreign key (parameter_version)
  references public.rating_parameter_sets (version)
  on delete restrict;

alter table public.rating_history
  add constraint rating_history_match_participant_fk
  foreign key (match_id, profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.rating_corrections
  add constraint rating_corrections_match_participant_fk
  foreign key (source_match_id, profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.incidents
  add constraint incidents_subject_participant_fk
  foreign key (match_id, subject_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.match_events
  add constraint match_events_actor_participant_fk
  foreign key (match_id, actor_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.match_events
  add constraint match_events_previous_host_participant_fk
  foreign key (match_id, previous_host_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.match_events
  add constraint match_events_new_host_participant_fk
  foreign key (match_id, new_host_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.rating_history
  add constraint rating_history_correction_shape
  check (
    (entry_type = 'compensating_correction' and correction_id is not null)
    or (entry_type <> 'compensating_correction' and correction_id is null)
  );

create or replace function private.guard_result_report_revision()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  source_match_id uuid;
  source_report_type public.result_report_type;
  source_reporting_profile_id uuid;
  winner_side public.match_side;
begin
  select
    report.match_id,
    report.report_type,
    report.reporting_profile_id
  into
    source_match_id,
    source_report_type,
    source_reporting_profile_id
  from public.result_reports as report
  where report.id = new.result_report_id;

  select participant.side
  into winner_side
  from public.match_participants as participant
  where participant.match_id = source_match_id
    and participant.profile_id = new.reported_winner_profile_id;

  if winner_side is null then
    raise exception using
      errcode = '23503',
      message = 'report revision winner must be a match participant';
  end if;

  if source_report_type = 'normal'
    and not (
      new.player_a_score is not null
      and new.player_b_score is not null
      and (
        (
          winner_side = 'player_a'
          and new.player_a_score = 3
          and new.player_b_score between 0 and 2
        )
        or (
          winner_side = 'player_b'
          and new.player_b_score = 3
          and new.player_a_score between 0 and 2
        )
      )
    )
  then
    raise exception using
      errcode = '23514',
      message = 'normal report revision must identify the side with three wins';
  end if;

  if source_report_type = 'forfeit'
    and not (
      new.player_a_score is null
      and new.player_b_score is null
      and new.reported_winner_profile_id <> source_reporting_profile_id
    )
  then
    raise exception using
      errcode = '23514',
      message = 'forfeit report revision must keep score empty and name the opponent';
  end if;

  return new;
end;
$$;

create trigger result_report_revisions_guard_participant
before insert on public.result_report_revisions
for each row execute function private.guard_result_report_revision();

create or replace function private.guard_restriction_incident_link()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.user_restrictions as restriction
    join public.incidents as incident
      on incident.id = new.incident_id
    where restriction.id = new.restriction_id
      and incident.status = 'confirmed'
      and incident.subject_profile_id = restriction.profile_id
  ) then
    raise exception using
      errcode = '23514',
      message = 'restrictions can only reference confirmed incidents for the same profile';
  end if;

  return new;
end;
$$;

create trigger restriction_incidents_guard_link
before insert or update on public.restriction_incidents
for each row execute function private.guard_restriction_incident_link();

create or replace function private.claim_domain_action(
  requested_scope text,
  requested_key text,
  requested_actor_identity text,
  requested_actor_profile_id uuid,
  requested_hash text
)
returns table (
  receipt_id uuid,
  is_new boolean,
  receipt_status public.domain_action_status,
  response_payload jsonb
)
language plpgsql
set search_path = ''
as $$
declare
  claimed private.domain_action_receipts%rowtype;
begin
  insert into private.domain_action_receipts (
    action_scope,
    idempotency_key,
    actor_identity,
    actor_profile_id,
    request_hash
  )
  values (
    requested_scope,
    requested_key,
    requested_actor_identity,
    requested_actor_profile_id,
    requested_hash
  )
  on conflict (action_scope, idempotency_key, actor_identity) do nothing
  returning * into claimed;

  if found then
    return query select claimed.id, true, claimed.status, claimed.response_payload;
    return;
  end if;

  select receipt.*
  into strict claimed
  from private.domain_action_receipts as receipt
  where receipt.action_scope = requested_scope
    and receipt.idempotency_key = requested_key
    and receipt.actor_identity = requested_actor_identity
  for update;

  if claimed.request_hash <> requested_hash then
    raise exception using
      errcode = '22023',
      message = 'idempotency key was reused with a different request';
  end if;

  return query
  select claimed.id, false, claimed.status, claimed.response_payload;
end;
$$;

create or replace function private.complete_domain_action(
  requested_receipt_id uuid,
  requested_response_payload jsonb
)
returns boolean
language sql
set search_path = ''
as $$
  with completed as (
    update private.domain_action_receipts
    set
      status = 'succeeded',
      response_payload = coalesce(requested_response_payload, '{}'::jsonb),
      completed_at = statement_timestamp()
    where id = requested_receipt_id
      and status = 'in_progress'
    returning id
  )
  select exists (select 1 from completed);
$$;

comment on function private.claim_domain_action(text, text, text, uuid, text) is
  'Must be called inside the same transaction as its domain mutation. A retry with the same request hash returns the prior receipt; a mismatched payload is rejected.';

comment on function private.complete_domain_action(uuid, jsonb) is
  'Marks an idempotent domain transaction successful before commit.';
