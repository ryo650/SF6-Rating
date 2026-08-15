-- Phase 1: relational schema, durable snapshots, and database-level uniqueness.

create table public.rating_parameter_sets (
  version text primary key,
  center_rating integer not null,
  expected_score_scale numeric(12, 4) not null,
  k_factor numeric(12, 4) not null,
  rounding_rule text not null,
  placement_multiplier_1_3 numeric(6, 3) not null,
  placement_multiplier_4_7 numeric(6, 3) not null,
  placement_multiplier_8_10 numeric(6, 3) not null,
  placement_cap integer not null,
  effective_from timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  constraint rating_parameter_sets_version_not_blank check (btrim(version) <> ''),
  constraint rating_parameter_sets_positive_values check (
    expected_score_scale > 0
    and k_factor > 0
    and placement_multiplier_1_3 > 0
    and placement_multiplier_4_7 > 0
    and placement_multiplier_8_10 > 0
    and placement_cap > 0
  ),
  constraint rating_parameter_sets_rounding_rule check (
    rounding_rule = 'half_away_from_zero'
  )
);

create unique index rating_parameter_sets_one_active_idx
  on public.rating_parameter_sets (is_active)
  where is_active;

create table public.starting_rating_parameter_sets (
  version text primary key,
  rank_base_ratings jsonb not null,
  subrank_adjustments jsonb not null,
  master_base_rating numeric(12, 4) not null,
  master_mr_coefficient numeric(8, 4) not null,
  master_mr_center integer not null,
  master_minimum integer not null,
  master_maximum integer not null,
  mr_validation_minimum integer,
  mr_validation_maximum integer,
  effective_from timestamptz not null,
  is_active boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  constraint starting_rating_parameter_sets_version_not_blank check (
    btrim(version) <> ''
  ),
  constraint starting_rating_parameter_sets_json_objects check (
    jsonb_typeof(rank_base_ratings) = 'object'
    and jsonb_typeof(subrank_adjustments) = 'object'
  ),
  constraint starting_rating_parameter_sets_master_bounds check (
    master_minimum < master_maximum
  ),
  constraint starting_rating_parameter_sets_mr_validation_bounds check (
    (mr_validation_minimum is null and mr_validation_maximum is null)
    or (
      mr_validation_minimum is not null
      and mr_validation_maximum is not null
      and mr_validation_minimum < mr_validation_maximum
    )
  )
);

create unique index starting_rating_parameter_sets_one_active_idx
  on public.starting_rating_parameter_sets (is_active)
  where is_active;

insert into public.rating_parameter_sets (
  version,
  center_rating,
  expected_score_scale,
  k_factor,
  rounding_rule,
  placement_multiplier_1_3,
  placement_multiplier_4_7,
  placement_multiplier_8_10,
  placement_cap,
  effective_from,
  is_active
)
values (
  'rating-v1',
  1500,
  250,
  64,
  'half_away_from_zero',
  2.0,
  1.5,
  1.25,
  96,
  '2026-08-15 00:00:00+00',
  true
);

insert into public.starting_rating_parameter_sets (
  version,
  rank_base_ratings,
  subrank_adjustments,
  master_base_rating,
  master_mr_coefficient,
  master_mr_center,
  master_minimum,
  master_maximum,
  mr_validation_minimum,
  mr_validation_maximum,
  effective_from,
  is_active
)
values (
  'starting-rating-v1',
  '{"rookie":900,"iron":1000,"bronze":1100,"silver":1200,"gold":1300,"platinum":1450,"diamond":1650}'::jsonb,
  '{"1":-40,"2":-20,"3":0,"4":20,"5":40}'::jsonb,
  1850,
  0.75,
  1500,
  1800,
  2200,
  null,
  null,
  '2026-08-15 00:00:00+00',
  true
);

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  username text,
  username_normalized text,
  avatar_url text,
  country_code text,
  current_rating integer,
  rating_reached_at timestamptz,
  placement_status public.placement_status not null default 'not_started',
  placement_completed_count smallint not null default 0,
  ranking_eligible boolean not null default false,
  is_public boolean not null default false,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  deleted_at timestamptz,
  constraint profiles_username_pair check (
    (username is null) = (username_normalized is null)
  ),
  constraint profiles_username_not_blank check (
    username is null or btrim(username) <> ''
  ),
  constraint profiles_username_normalized_not_blank check (
    username_normalized is null or btrim(username_normalized) <> ''
  ),
  constraint profiles_country_code_shape check (
    country_code is null or country_code ~ '^[A-Z]{2}$'
  ),
  constraint profiles_placement_count check (
    placement_completed_count between 0 and 10
  ),
  constraint profiles_placement_state check (
    (
      placement_status in ('not_started', 'preview')
      and placement_completed_count = 0
      and not ranking_eligible
    )
    or (
      placement_status = 'active'
      and placement_completed_count between 0 and 9
      and not ranking_eligible
    )
    or (
      placement_status = 'completed'
      and placement_completed_count = 10
      and ranking_eligible
    )
  ),
  constraint profiles_rating_when_placement_started check (
    placement_status = 'not_started' or current_rating is not null
  ),
  constraint profiles_public_shape check (
    not is_public
    or (
      username is not null
      and current_rating is not null
      and deleted_at is null
    )
  ),
  constraint profiles_deleted_not_public check (
    deleted_at is null or not is_public
  )
);

create unique index profiles_username_normalized_uidx
  on public.profiles (username_normalized)
  where username_normalized is not null;

create index profiles_public_rating_idx
  on public.profiles (current_rating desc, rating_reached_at, id)
  where is_public and deleted_at is null and ranking_eligible;

create table public.profile_accounts (
  profile_id uuid primary key references public.profiles (id) on delete restrict,
  auth_user_id uuid unique references auth.users (id) on delete set null,
  application_role public.application_role not null default 'user',
  account_status public.account_status not null default 'onboarding',
  onboarding_status public.onboarding_status not null default 'not_started',
  onboarding_current_step smallint not null default 1,
  username_changed_at timestamptz,
  onboarding_completed_at timestamptz,
  deletion_requested_at timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint profile_accounts_onboarding_step check (
    onboarding_current_step between 1 and 3
  ),
  constraint profile_accounts_auth_lifecycle check (
    (
      account_status = 'anonymized'
      and auth_user_id is null
      and anonymized_at is not null
    )
    or (
      account_status <> 'anonymized'
      and auth_user_id is not null
      and anonymized_at is null
    )
  ),
  constraint profile_accounts_active_is_onboarded check (
    account_status <> 'active' or onboarding_status = 'completed'
  ),
  constraint profile_accounts_completed_timestamp check (
    (onboarding_status = 'completed') = (onboarding_completed_at is not null)
  ),
  constraint profile_accounts_deletion_timestamp check (
    account_status <> 'deletion_pending' or deletion_requested_at is not null
  )
);

create index profile_accounts_auth_user_idx
  on public.profile_accounts (auth_user_id)
  where auth_user_id is not null;

create table public.profile_sf6_identities (
  profile_id uuid primary key references public.profiles (id) on delete restrict,
  sf6_player_name text,
  sf6_user_code text,
  sf6_user_code_normalized text,
  sf6_user_code_changed_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  constraint profile_sf6_identities_code_pair check (
    (sf6_user_code is null) = (sf6_user_code_normalized is null)
  ),
  constraint profile_sf6_identities_name_not_blank check (
    sf6_player_name is null or btrim(sf6_player_name) <> ''
  ),
  constraint profile_sf6_identities_code_not_blank check (
    sf6_user_code is null or btrim(sf6_user_code) <> ''
  ),
  constraint profile_sf6_identities_normalized_not_blank check (
    sf6_user_code_normalized is null or btrim(sf6_user_code_normalized) <> ''
  )
);

create unique index profile_sf6_identities_code_normalized_uidx
  on public.profile_sf6_identities (sf6_user_code_normalized)
  where sf6_user_code_normalized is not null;

create table public.profile_private_details (
  profile_id uuid primary key references public.profiles (id) on delete restrict,
  broad_region_code text,
  main_character_code text,
  current_sf6_rank public.sf6_rank,
  current_sf6_rank_tier smallint,
  current_master_rating integer,
  updated_at timestamptz not null default statement_timestamp(),
  constraint profile_private_details_region_not_blank check (
    broad_region_code is null or btrim(broad_region_code) <> ''
  ),
  constraint profile_private_details_character_not_blank check (
    main_character_code is null or btrim(main_character_code) <> ''
  ),
  constraint profile_private_details_rank_tier check (
    current_sf6_rank_tier is null or current_sf6_rank_tier between 1 and 5
  ),
  constraint profile_private_details_master_fields check (
    current_sf6_rank is distinct from 'master'
    or current_sf6_rank_tier is null
  )
);

create table public.placement_initializations (
  profile_id uuid primary key references public.profiles (id) on delete restrict,
  source public.starting_rating_source not null,
  source_rank public.sf6_rank,
  source_rank_tier smallint,
  source_master_rating integer,
  starting_rating integer not null,
  parameter_version text not null references public.starting_rating_parameter_sets (version),
  calculated_at timestamptz not null default statement_timestamp(),
  locked_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  constraint placement_initializations_rank_tier check (
    source_rank_tier is null or source_rank_tier between 1 and 5
  ),
  constraint placement_initializations_source_shape check (
    (
      source = 'rank'
      and source_rank is not null
      and source_rank <> 'master'
      and source_rank_tier is not null
      and source_master_rating is null
    )
    or (
      source = 'master_rating'
      and source_rank = 'master'
      and source_rank_tier is null
      and source_master_rating is not null
    )
  )
);

create table public.seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  status public.season_status not null,
  rollover_key text unique,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  constraint seasons_name_not_blank check (btrim(name) <> ''),
  constraint seasons_three_month_duration check (
    ends_at = starts_at + interval '3 months'
  ),
  constraint seasons_completed_timestamp check (
    (status = 'completed') = (completed_at is not null)
  )
);

create unique index seasons_one_active_idx
  on public.seasons (status)
  where status = 'active';

create index seasons_time_window_idx
  on public.seasons (starts_at, ends_at);

create table public.season_player_records (
  season_id uuid not null references public.seasons (id) on delete restrict,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  record_status public.season_record_status not null default 'live',
  current_rating integer not null,
  ranking_eligible boolean not null,
  rated_wins integer not null default 0,
  rated_losses integer not null default 0,
  rated_match_count integer not null default 0,
  wins_3_0 integer not null default 0,
  wins_3_1 integer not null default 0,
  wins_3_2 integer not null default 0,
  losses_0_3 integer not null default 0,
  losses_1_3 integer not null default 0,
  losses_2_3 integer not null default 0,
  final_rating integer,
  final_ranking integer,
  final_rated_wins integer,
  final_rated_losses integer,
  final_rated_match_count integer,
  final_win_rate numeric(7, 6),
  snapshot_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  primary key (season_id, profile_id),
  constraint season_player_records_nonnegative_stats check (
    rated_wins >= 0
    and rated_losses >= 0
    and rated_match_count >= 0
    and wins_3_0 >= 0
    and wins_3_1 >= 0
    and wins_3_2 >= 0
    and losses_0_3 >= 0
    and losses_1_3 >= 0
    and losses_2_3 >= 0
  ),
  constraint season_player_records_match_count check (
    rated_match_count = rated_wins + rated_losses
  ),
  constraint season_player_records_score_breakdown check (
    wins_3_0 + wins_3_1 + wins_3_2 <= rated_wins
    and losses_0_3 + losses_1_3 + losses_2_3 <= rated_losses
  ),
  constraint season_player_records_snapshot_shape check (
    (
      record_status = 'live'
      and final_rating is null
      and final_ranking is null
      and final_rated_wins is null
      and final_rated_losses is null
      and final_rated_match_count is null
      and final_win_rate is null
      and snapshot_at is null
    )
    or (
      record_status = 'finalized'
      and final_rating is not null
      and final_rating = current_rating
      and (
        (ranking_eligible and final_ranking is not null and final_ranking > 0)
        or (not ranking_eligible and final_ranking is null)
      )
      and final_rated_wins is not null
      and final_rated_wins >= 0
      and final_rated_wins = rated_wins
      and final_rated_losses is not null
      and final_rated_losses >= 0
      and final_rated_losses = rated_losses
      and final_rated_match_count is not null
      and final_rated_match_count >= 0
      and final_rated_match_count = rated_match_count
      and final_rated_match_count = final_rated_wins + final_rated_losses
      and final_win_rate is not null
      and final_win_rate between 0 and 1
      and final_win_rate = case
        when final_rated_match_count = 0 then 0::numeric
        else round(
          final_rated_wins::numeric / final_rated_match_count,
          6
        )
      end
      and snapshot_at is not null
    )
  )
);

create index season_player_records_ranking_idx
  on public.season_player_records (
    season_id,
    ranking_eligible,
    current_rating desc,
    profile_id
  )
  where record_status = 'live';

create table public.matches (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.seasons (id) on delete restrict,
  is_rated boolean not null,
  creation_source public.match_creation_source not null,
  status public.match_status not null default 'matched',
  resolution_type public.match_resolution_type,
  result_validity public.match_result_validity,
  rating_status public.match_rating_status not null,
  rating_parameter_version text references public.rating_parameter_sets (version),
  host_profile_id uuid,
  winner_profile_id uuid,
  loser_profile_id uuid,
  player_a_score smallint,
  player_b_score smallint,
  termination_player_a_score smallint,
  termination_player_b_score smallint,
  version bigint not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  matched_at timestamptz not null default statement_timestamp(),
  room_setup_started_at timestamptz,
  reporting_started_at timestamptz,
  first_reported_at timestamptz,
  disputed_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  constraint matches_version_positive check (version > 0),
  constraint matches_rating_parameter_shape check (
    (is_rated and rating_parameter_version is not null)
    or (not is_rated and rating_parameter_version is null)
  ),
  constraint matches_score_bounds check (
    (player_a_score is null or player_a_score between 0 and 3)
    and (player_b_score is null or player_b_score between 0 and 3)
    and (
      termination_player_a_score is null
      or termination_player_a_score between 0 and 2
    )
    and (
      termination_player_b_score is null
      or termination_player_b_score between 0 and 2
    )
  ),
  constraint matches_score_pairs check (
    (player_a_score is null) = (player_b_score is null)
    and (termination_player_a_score is null) = (termination_player_b_score is null)
  ),
  constraint matches_distinct_result_players check (
    winner_profile_id is null
    or loser_profile_id is null
    or winner_profile_id <> loser_profile_id
  )
);

create index matches_season_status_idx
  on public.matches (season_id, status, matched_at);

create index matches_first_reported_idx
  on public.matches (first_reported_at)
  where status = 'reporting' and first_reported_at is not null;

create table public.match_participants (
  match_id uuid not null references public.matches (id) on delete restrict,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  side public.match_side not null,
  rating_snapshot integer not null,
  placement_status_snapshot public.placement_status not null,
  placement_completed_count_snapshot smallint not null,
  is_active boolean not null default true,
  joined_at timestamptz not null default statement_timestamp(),
  cleared_at timestamptz,
  primary key (match_id, profile_id),
  unique (match_id, side),
  constraint match_participants_placement_count check (
    placement_completed_count_snapshot between 0 and 10
  ),
  constraint match_participants_placement_state check (
    (
      placement_status_snapshot in ('not_started', 'preview')
      and placement_completed_count_snapshot = 0
    )
    or (
      placement_status_snapshot = 'active'
      and placement_completed_count_snapshot between 0 and 9
    )
    or (
      placement_status_snapshot = 'completed'
      and placement_completed_count_snapshot = 10
    )
  ),
  constraint match_participants_activity_shape check (
    (is_active and cleared_at is null)
    or (not is_active and cleared_at is not null)
  )
);

create unique index match_participants_one_active_match_idx
  on public.match_participants (profile_id)
  where is_active;

create index match_participants_profile_history_idx
  on public.match_participants (profile_id, match_id);

alter table public.matches
  add constraint matches_host_participant_fk
  foreign key (id, host_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.matches
  add constraint matches_winner_participant_fk
  foreign key (id, winner_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

alter table public.matches
  add constraint matches_loser_participant_fk
  foreign key (id, loser_profile_id)
  references public.match_participants (match_id, profile_id)
  deferrable initially deferred;

create table public.waiting_entries (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete restrict,
  mode public.waiting_mode not null,
  status public.waiting_status not null default 'active',
  auto_match_eligible boolean not null,
  rating_snapshot integer not null,
  placement_status_snapshot public.placement_status not null,
  placement_completed_count_snapshot smallint not null,
  country_code_snapshot text not null,
  broad_region_code_snapshot text not null,
  version bigint not null default 1,
  started_at timestamptz not null default statement_timestamp(),
  expires_at timestamptz not null,
  last_active_at timestamptz not null default statement_timestamp(),
  cancelled_at timestamptz,
  matched_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  constraint waiting_entries_mode_eligibility check (
    (mode = 'quick_match' and auto_match_eligible)
    or (mode = 'accepting_challenges' and not auto_match_eligible)
  ),
  constraint waiting_entries_placement_count check (
    placement_completed_count_snapshot between 0 and 10
  ),
  constraint waiting_entries_placement_state check (
    (
      placement_status_snapshot in ('not_started', 'preview')
      and placement_completed_count_snapshot = 0
    )
    or (
      placement_status_snapshot = 'active'
      and placement_completed_count_snapshot between 0 and 9
    )
    or (
      placement_status_snapshot = 'completed'
      and placement_completed_count_snapshot = 10
    )
  ),
  constraint waiting_entries_country_code_shape check (
    country_code_snapshot ~ '^[A-Z]{2}$'
  ),
  constraint waiting_entries_region_not_blank check (
    btrim(broad_region_code_snapshot) <> ''
  ),
  constraint waiting_entries_ten_minute_window check (
    expires_at = started_at + interval '10 minutes'
  ),
  constraint waiting_entries_version_positive check (version > 0),
  constraint waiting_entries_terminal_timestamps check (
    (status <> 'cancelled' or cancelled_at is not null)
    and (status <> 'matched' or matched_at is not null)
  )
);

create unique index waiting_entries_one_active_per_profile_idx
  on public.waiting_entries (profile_id)
  where status = 'active';

create index waiting_entries_candidate_search_idx
  on public.waiting_entries (
    status,
    mode,
    broad_region_code_snapshot,
    country_code_snapshot,
    rating_snapshot,
    started_at
  )
  where status = 'active';

create index waiting_entries_expiry_idx
  on public.waiting_entries (expires_at)
  where status = 'active';

create table public.rated_pair_cooldowns (
  profile_low_id uuid not null references public.profiles (id) on delete restrict,
  profile_high_id uuid not null references public.profiles (id) on delete restrict,
  source_match_id uuid not null unique references public.matches (id) on delete restrict,
  last_rated_result_confirmed_at timestamptz not null,
  next_rated_eligible_at timestamptz not null,
  updated_at timestamptz not null default statement_timestamp(),
  primary key (profile_low_id, profile_high_id),
  constraint rated_pair_cooldowns_canonical_order check (
    profile_low_id < profile_high_id
  ),
  constraint rated_pair_cooldowns_duration check (
    next_rated_eligible_at = last_rated_result_confirmed_at + interval '24 hours'
  )
);

create index rated_pair_cooldowns_eligibility_idx
  on public.rated_pair_cooldowns (next_rated_eligible_at);

create table public.result_reports (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete restrict,
  reporting_profile_id uuid not null references public.profiles (id) on delete restrict,
  report_type public.result_report_type not null,
  reported_winner_profile_id uuid not null,
  player_a_score smallint,
  player_b_score smallint,
  revision_number smallint not null default 0,
  status public.result_report_status not null default 'submitted',
  idempotency_key text not null,
  submitted_at timestamptz not null default statement_timestamp(),
  last_revised_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (match_id, reporting_profile_id),
  unique (reporting_profile_id, idempotency_key),
  constraint result_reports_idempotency_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint result_reports_revision_limit check (
    revision_number between 0 and 1
  ),
  constraint result_reports_payload_shape check (
    (
      report_type = 'normal'
      and player_a_score is not null
      and player_b_score is not null
      and (
        (player_a_score = 3 and player_b_score between 0 and 2)
        or (player_b_score = 3 and player_a_score between 0 and 2)
      )
    )
    or (
      report_type = 'forfeit'
      and player_a_score is null
      and player_b_score is null
      and reported_winner_profile_id <> reporting_profile_id
    )
  ),
  constraint result_reports_revision_timestamp check (
    (revision_number = 0 and last_revised_at is null)
    or (revision_number = 1 and last_revised_at is not null)
  ),
  foreign key (match_id, reporting_profile_id)
    references public.match_participants (match_id, profile_id)
    deferrable initially deferred,
  foreign key (match_id, reported_winner_profile_id)
    references public.match_participants (match_id, profile_id)
    deferrable initially deferred
);

create index result_reports_match_status_idx
  on public.result_reports (match_id, status, submitted_at);

create table public.result_report_revisions (
  id uuid primary key default gen_random_uuid(),
  result_report_id uuid not null references public.result_reports (id) on delete restrict,
  revision_number smallint not null,
  reported_winner_profile_id uuid not null references public.profiles (id) on delete restrict,
  player_a_score smallint,
  player_b_score smallint,
  submitted_at timestamptz not null default statement_timestamp(),
  unique (result_report_id, revision_number),
  constraint result_report_revisions_revision_limit check (
    revision_number between 0 and 1
  ),
  constraint result_report_revisions_score_pair check (
    (player_a_score is null) = (player_b_score is null)
  )
);

create table public.rating_history (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete restrict,
  match_id uuid references public.matches (id) on delete restrict,
  season_id uuid not null references public.seasons (id) on delete restrict,
  entry_type public.rating_entry_type not null,
  rating_before integer not null,
  opponent_rating_snapshot integer,
  expected_score numeric(12, 10),
  raw_base_change numeric(16, 8),
  placement_match_number smallint,
  placement_multiplier numeric(6, 3),
  change_after_multiplier numeric(16, 8),
  cap_value integer,
  cap_applied boolean,
  change_after_cap numeric(16, 8),
  rounded_final_change integer not null,
  rating_after integer not null,
  k_factor numeric(12, 4),
  expected_score_scale numeric(12, 4),
  parameter_version text,
  reason_category text,
  correction_id uuid,
  idempotency_key text not null unique,
  created_at timestamptz not null default statement_timestamp(),
  constraint rating_history_rating_arithmetic check (
    rating_after = rating_before + rounded_final_change
  ),
  constraint rating_history_expected_score check (
    expected_score is null or expected_score between 0 and 1
  ),
  constraint rating_history_placement_number check (
    placement_match_number is null or placement_match_number between 1 and 10
  ),
  constraint rating_history_idempotency_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint rating_history_match_entry_shape check (
    entry_type <> 'match_result'
    or (
      match_id is not null
      and opponent_rating_snapshot is not null
      and expected_score is not null
      and raw_base_change is not null
      and placement_multiplier is not null
      and change_after_multiplier is not null
      and cap_applied is not null
      and change_after_cap is not null
      and k_factor is not null
      and expected_score_scale is not null
      and parameter_version is not null
    )
  )
);

create unique index rating_history_one_match_result_idx
  on public.rating_history (match_id, profile_id)
  where entry_type = 'match_result';

create unique index rating_history_one_season_reset_idx
  on public.rating_history (season_id, profile_id)
  where entry_type = 'season_reset';

create unique index rating_history_one_correction_entry_idx
  on public.rating_history (correction_id)
  where entry_type = 'compensating_correction';

create index rating_history_profile_created_idx
  on public.rating_history (profile_id, created_at desc, id desc);

create index rating_history_season_profile_idx
  on public.rating_history (season_id, profile_id, created_at);

create table public.match_events (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete restrict,
  actor_profile_id uuid references public.profiles (id) on delete restrict,
  event_type public.match_event_type not null,
  preset_message_type public.preset_message_type,
  previous_host_profile_id uuid references public.profiles (id) on delete restrict,
  new_host_profile_id uuid references public.profiles (id) on delete restrict,
  visibility public.event_visibility not null default 'participants',
  idempotency_key text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default statement_timestamp(),
  unique (match_id, idempotency_key),
  constraint match_events_idempotency_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint match_events_metadata_object check (
    jsonb_typeof(metadata) = 'object'
  ),
  constraint match_events_preset_shape check (
    (event_type = 'preset_message') = (preset_message_type is not null)
  ),
  constraint match_events_host_change_shape check (
    event_type <> 'host_changed'
    or (
      previous_host_profile_id is not null
      and new_host_profile_id is not null
      and previous_host_profile_id <> new_host_profile_id
    )
  )
);

create index match_events_timeline_idx
  on public.match_events (match_id, created_at, id);

create table public.incidents (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.matches (id) on delete restrict,
  reporter_profile_id uuid not null references public.profiles (id) on delete restrict,
  subject_profile_id uuid references public.profiles (id) on delete restrict,
  incident_type public.incident_type not null,
  status public.incident_status not null default 'reported',
  occurred_at timestamptz,
  reported_at timestamptz not null default statement_timestamp(),
  unresponsive_since timestamptz,
  confirmed_at timestamptz,
  reviewed_at timestamptz,
  review_admin_profile_id uuid references public.profiles (id) on delete restrict,
  reason_category text,
  idempotency_key text not null,
  created_at timestamptz not null default statement_timestamp(),
  updated_at timestamptz not null default statement_timestamp(),
  unique (reporter_profile_id, idempotency_key),
  constraint incidents_idempotency_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint incidents_subject_not_reporter check (
    subject_profile_id is null or subject_profile_id <> reporter_profile_id
  ),
  constraint incidents_confirmation_timestamp check (
    (status = 'confirmed') = (confirmed_at is not null)
  ),
  foreign key (match_id, reporter_profile_id)
    references public.match_participants (match_id, profile_id)
    deferrable initially deferred
);

create unique index incidents_one_reliability_strike_per_match_user_idx
  on public.incidents (match_id, subject_profile_id)
  where status = 'confirmed' and subject_profile_id is not null;

create index incidents_review_queue_idx
  on public.incidents (status, reported_at);

create index incidents_rolling_window_idx
  on public.incidents (subject_profile_id, confirmed_at)
  where status = 'confirmed';

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.matches (id) on delete restrict,
  entry_reason public.dispute_entry_reason not null,
  status public.dispute_status not null default 'open',
  assigned_admin_profile_id uuid references public.profiles (id) on delete restrict,
  resolved_admin_profile_id uuid references public.profiles (id) on delete restrict,
  resolution_action public.dispute_resolution_action,
  resolution_reason_category text,
  version bigint not null default 1,
  created_at timestamptz not null default statement_timestamp(),
  resolved_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  constraint disputes_version_positive check (version > 0),
  constraint disputes_resolution_shape check (
    (
      status = 'open'
      and resolved_admin_profile_id is null
      and resolution_action is null
      and resolved_at is null
    )
    or (
      status = 'resolved'
      and resolution_action is not null
      and resolution_reason_category is not null
      and btrim(resolution_reason_category) <> ''
      and resolved_at is not null
      and (
        resolution_action = 'mutual_no_rating'
        or resolved_admin_profile_id is not null
      )
    )
  )
);

create index disputes_queue_idx
  on public.disputes (status, created_at);

create table public.user_restrictions (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles (id) on delete restrict,
  restriction_type public.restriction_type not null default 'matchmaking',
  status public.restriction_status not null,
  reason_category text not null,
  starts_at timestamptz not null,
  expires_at timestamptz,
  applied_by_admin_profile_id uuid references public.profiles (id) on delete restrict,
  revoked_by_admin_profile_id uuid references public.profiles (id) on delete restrict,
  created_at timestamptz not null default statement_timestamp(),
  revoked_at timestamptz,
  updated_at timestamptz not null default statement_timestamp(),
  constraint user_restrictions_reason_not_blank check (
    btrim(reason_category) <> ''
  ),
  constraint user_restrictions_time_window check (
    expires_at is null or expires_at > starts_at
  ),
  constraint user_restrictions_status_shape check (
    (
      status = 'warning'
      and expires_at is null
      and revoked_at is null
    )
    or (
      status = 'active'
      and expires_at is not null
      and revoked_at is null
    )
    or (
      status = 'expired'
      and expires_at is not null
      and revoked_at is null
    )
    or (
      status = 'revoked'
      and revoked_at is not null
      and revoked_by_admin_profile_id is not null
    )
  )
);

create index user_restrictions_profile_status_idx
  on public.user_restrictions (profile_id, status, expires_at);

create unique index user_restrictions_one_active_idx
  on public.user_restrictions (profile_id, restriction_type)
  where status = 'active';

create table public.restriction_incidents (
  restriction_id uuid not null references public.user_restrictions (id) on delete restrict,
  incident_id uuid not null references public.incidents (id) on delete restrict,
  primary key (restriction_id, incident_id),
  unique (incident_id, restriction_id)
);

create table public.rating_corrections (
  id uuid primary key default gen_random_uuid(),
  source_match_id uuid not null references public.matches (id) on delete restrict,
  profile_id uuid not null references public.profiles (id) on delete restrict,
  correction_type public.rating_correction_type not null,
  original_rating_change integer not null,
  compensating_rating_change integer not null,
  reason_category text not null,
  applied_by_admin_profile_id uuid references public.profiles (id) on delete restrict,
  applied_at timestamptz,
  created_at timestamptz not null default statement_timestamp(),
  unique (source_match_id, profile_id, correction_type),
  constraint rating_corrections_inverse_delta check (
    compensating_rating_change = -original_rating_change
  ),
  constraint rating_corrections_reason_not_blank check (
    btrim(reason_category) <> ''
  )
);

alter table public.rating_history
  add constraint rating_history_correction_fk
  foreign key (correction_id)
  references public.rating_corrections (id)
  on delete restrict;

create table public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_profile_id uuid not null references public.profiles (id) on delete restrict,
  action text not null,
  target_type text not null,
  target_id uuid not null,
  before_state jsonb,
  after_state jsonb,
  reason_category text not null,
  match_id uuid references public.matches (id) on delete restrict,
  incident_id uuid references public.incidents (id) on delete restrict,
  restriction_id uuid references public.user_restrictions (id) on delete restrict,
  rating_correction_id uuid references public.rating_corrections (id) on delete restrict,
  idempotency_key text not null unique,
  created_at timestamptz not null default statement_timestamp(),
  constraint admin_audit_logs_action_not_blank check (btrim(action) <> ''),
  constraint admin_audit_logs_target_type_not_blank check (
    btrim(target_type) <> ''
  ),
  constraint admin_audit_logs_reason_not_blank check (
    btrim(reason_category) <> ''
  ),
  constraint admin_audit_logs_idempotency_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint admin_audit_logs_before_object check (
    before_state is null or jsonb_typeof(before_state) = 'object'
  ),
  constraint admin_audit_logs_after_object check (
    after_state is null or jsonb_typeof(after_state) = 'object'
  )
);

create index admin_audit_logs_target_idx
  on public.admin_audit_logs (target_type, target_id, created_at);

create table private.domain_action_receipts (
  id uuid primary key default gen_random_uuid(),
  action_scope text not null,
  idempotency_key text not null,
  actor_identity text not null,
  actor_profile_id uuid references public.profiles (id) on delete restrict,
  request_hash text not null,
  status public.domain_action_status not null default 'in_progress',
  response_payload jsonb,
  error_code text,
  created_at timestamptz not null default statement_timestamp(),
  completed_at timestamptz,
  unique (action_scope, idempotency_key, actor_identity),
  constraint domain_action_receipts_scope_not_blank check (
    btrim(action_scope) <> ''
  ),
  constraint domain_action_receipts_key_not_blank check (
    btrim(idempotency_key) <> ''
  ),
  constraint domain_action_receipts_actor_not_blank check (
    btrim(actor_identity) <> ''
  ),
  constraint domain_action_receipts_request_hash_not_blank check (
    btrim(request_hash) <> ''
  ),
  constraint domain_action_receipts_completion_shape check (
    (status = 'in_progress' and completed_at is null)
    or (status in ('succeeded', 'failed') and completed_at is not null)
  ),
  constraint domain_action_receipts_response_object check (
    response_payload is null or jsonb_typeof(response_payload) = 'object'
  )
);
