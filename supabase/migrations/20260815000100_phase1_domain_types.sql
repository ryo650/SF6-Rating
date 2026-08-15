-- Phase 1: stable domain vocabulary shared by later vertical slices.
-- Behavioural workflows are intentionally deferred; these enums only encode
-- terminology that is already canonical in the reviewed specifications.

create schema if not exists private;

revoke all on schema private from public, anon, authenticated;

create type public.application_role as enum (
  'user',
  'admin'
);

create type public.account_status as enum (
  'onboarding',
  'active',
  'deletion_pending',
  'anonymized'
);

create type public.onboarding_status as enum (
  'not_started',
  'account_in_progress',
  'sf6_info_in_progress',
  'rating_setup_in_progress',
  'completed'
);

create type public.placement_status as enum (
  'not_started',
  'preview',
  'active',
  'completed'
);

create type public.starting_rating_source as enum (
  'rank',
  'master_rating'
);

create type public.sf6_rank as enum (
  'rookie',
  'iron',
  'bronze',
  'silver',
  'gold',
  'platinum',
  'diamond',
  'master'
);

create type public.season_status as enum (
  'upcoming',
  'active',
  'completed'
);

create type public.season_record_status as enum (
  'live',
  'finalized'
);

create type public.match_creation_source as enum (
  'quick_match',
  'find_opponent'
);

create type public.match_status as enum (
  'matched',
  'room_setup',
  'reporting',
  'disputed',
  'completed',
  'cancelled'
);

create type public.match_resolution_type as enum (
  'normal',
  'forfeit',
  'admin_result',
  'mutual_cancel',
  'nonresponse_no_rating',
  'mutual_no_rating',
  'admin_invalid_no_rating',
  'season_boundary_no_rating'
);

create type public.match_result_validity as enum (
  'valid',
  'invalidated'
);

create type public.match_rating_status as enum (
  'not_applicable',
  'pending',
  'applied',
  'correction_pending',
  'corrected'
);

create type public.match_side as enum (
  'player_a',
  'player_b'
);

create type public.waiting_mode as enum (
  'quick_match',
  'accepting_challenges'
);

create type public.waiting_status as enum (
  'active',
  'matched',
  'cancelled',
  'expired',
  'restricted'
);

create type public.result_report_type as enum (
  'normal',
  'forfeit'
);

create type public.result_report_status as enum (
  'submitted',
  'mismatch_review',
  'confirmed',
  'superseded'
);

create type public.rating_entry_type as enum (
  'initial_placement',
  'match_result',
  'season_reset',
  'compensating_correction'
);

create type public.match_event_type as enum (
  'match_created',
  'host_assigned',
  'host_changed',
  'preset_message',
  'reporting_started',
  'match_cancelled',
  'dispute_opened'
);

create type public.preset_message_type as enum (
  'room_created',
  'joined',
  'cant_find_room',
  'please_try_again',
  'please_wait'
);

create type public.event_visibility as enum (
  'participants',
  'admins'
);

create type public.dispute_entry_reason as enum (
  'result_mismatch',
  'incident_conflict',
  'cancellation_conflict',
  'completed_match_review'
);

create type public.dispute_status as enum (
  'open',
  'resolved'
);

create type public.dispute_resolution_action as enum (
  'adopt_player_a_report',
  'adopt_player_b_report',
  'admin_invalid_no_rating',
  'mutual_no_rating'
);

create type public.incident_type as enum (
  'no_show',
  'abandonment',
  'result_nonresponse',
  'match_completion_failure'
);

create type public.incident_status as enum (
  'reported',
  'confirmed',
  'dismissed',
  'responsibility_unknown'
);

create type public.restriction_type as enum (
  'matchmaking'
);

create type public.restriction_status as enum (
  'warning',
  'active',
  'expired',
  'revoked'
);

create type public.rating_correction_type as enum (
  'match_invalidation'
);

create type public.domain_action_status as enum (
  'in_progress',
  'succeeded',
  'failed'
);
