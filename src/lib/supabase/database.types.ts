export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action: string;
          admin_profile_id: string;
          after_state: Json | null;
          before_state: Json | null;
          created_at: string;
          id: string;
          idempotency_key: string;
          incident_id: string | null;
          match_id: string | null;
          rating_correction_id: string | null;
          reason_category: string;
          restriction_id: string | null;
          target_id: string;
          target_type: string;
        };
        Insert: {
          action: string;
          admin_profile_id: string;
          after_state?: Json | null;
          before_state?: Json | null;
          created_at?: string;
          id?: string;
          idempotency_key: string;
          incident_id?: string | null;
          match_id?: string | null;
          rating_correction_id?: string | null;
          reason_category: string;
          restriction_id?: string | null;
          target_id: string;
          target_type: string;
        };
        Update: {
          action?: string;
          admin_profile_id?: string;
          after_state?: Json | null;
          before_state?: Json | null;
          created_at?: string;
          id?: string;
          idempotency_key?: string;
          incident_id?: string | null;
          match_id?: string | null;
          rating_correction_id?: string | null;
          reason_category?: string;
          restriction_id?: string | null;
          target_id?: string;
          target_type?: string;
        };
        Relationships: [
          {
            foreignKeyName: "admin_audit_logs_admin_profile_id_fkey";
            columns: ["admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "admin_audit_logs_admin_profile_id_fkey";
            columns: ["admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "admin_audit_logs_incident_id_fkey";
            columns: ["incident_id"];
            isOneToOne: false;
            referencedRelation: "incidents";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "admin_audit_logs_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "admin_audit_logs_rating_correction_id_fkey";
            columns: ["rating_correction_id"];
            isOneToOne: false;
            referencedRelation: "rating_corrections";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "admin_audit_logs_restriction_id_fkey";
            columns: ["restriction_id"];
            isOneToOne: false;
            referencedRelation: "user_restrictions";
            referencedColumns: ["id"];
          },
        ];
      };
      avatar_assets: {
        Row: {
          byte_size: number;
          content_sha256: string;
          content_type: string;
          created_at: string;
          deleted_at: string | null;
          height: number;
          id: string;
          profile_id: string;
          storage_path: string;
          width: number;
        };
        Insert: {
          byte_size: number;
          content_sha256: string;
          content_type: string;
          created_at?: string;
          deleted_at?: string | null;
          height: number;
          id?: string;
          profile_id: string;
          storage_path: string;
          width: number;
        };
        Update: {
          byte_size?: number;
          content_sha256?: string;
          content_type?: string;
          created_at?: string;
          deleted_at?: string | null;
          height?: number;
          id?: string;
          profile_id?: string;
          storage_path?: string;
          width?: number;
        };
        Relationships: [
          {
            foreignKeyName: "avatar_assets_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "avatar_assets_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      broad_regions: {
        Row: {
          code: string;
          country_code: string;
          created_at: string;
          is_active: boolean;
          name_en: string;
          name_ja: string;
          sort_order: number;
          updated_at: string;
        };
        Insert: {
          code: string;
          country_code: string;
          created_at?: string;
          is_active?: boolean;
          name_en: string;
          name_ja: string;
          sort_order?: number;
          updated_at?: string;
        };
        Update: {
          code?: string;
          country_code?: string;
          created_at?: string;
          is_active?: boolean;
          name_en?: string;
          name_ja?: string;
          sort_order?: number;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "broad_regions_country_code_fkey";
            columns: ["country_code"];
            isOneToOne: false;
            referencedRelation: "countries";
            referencedColumns: ["code"];
          },
        ];
      };
      countries: {
        Row: {
          code: string;
          created_at: string;
          is_active: boolean;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          is_active?: boolean;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          is_active?: boolean;
          updated_at?: string;
        };
        Relationships: [];
      };
      disputes: {
        Row: {
          assigned_admin_profile_id: string | null;
          created_at: string;
          entry_reason: Database["public"]["Enums"]["dispute_entry_reason"];
          id: string;
          match_id: string;
          resolution_action:
            Database["public"]["Enums"]["dispute_resolution_action"] | null;
          resolution_reason_category: string | null;
          resolved_admin_profile_id: string | null;
          resolved_at: string | null;
          status: Database["public"]["Enums"]["dispute_status"];
          updated_at: string;
          version: number;
        };
        Insert: {
          assigned_admin_profile_id?: string | null;
          created_at?: string;
          entry_reason: Database["public"]["Enums"]["dispute_entry_reason"];
          id?: string;
          match_id: string;
          resolution_action?:
            Database["public"]["Enums"]["dispute_resolution_action"] | null;
          resolution_reason_category?: string | null;
          resolved_admin_profile_id?: string | null;
          resolved_at?: string | null;
          status?: Database["public"]["Enums"]["dispute_status"];
          updated_at?: string;
          version?: number;
        };
        Update: {
          assigned_admin_profile_id?: string | null;
          created_at?: string;
          entry_reason?: Database["public"]["Enums"]["dispute_entry_reason"];
          id?: string;
          match_id?: string;
          resolution_action?:
            Database["public"]["Enums"]["dispute_resolution_action"] | null;
          resolution_reason_category?: string | null;
          resolved_admin_profile_id?: string | null;
          resolved_at?: string | null;
          status?: Database["public"]["Enums"]["dispute_status"];
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "disputes_assigned_admin_profile_id_fkey";
            columns: ["assigned_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "disputes_assigned_admin_profile_id_fkey";
            columns: ["assigned_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "disputes_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: true;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "disputes_resolved_admin_profile_id_fkey";
            columns: ["resolved_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "disputes_resolved_admin_profile_id_fkey";
            columns: ["resolved_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      incidents: {
        Row: {
          confirmed_at: string | null;
          created_at: string;
          id: string;
          idempotency_key: string;
          incident_type: Database["public"]["Enums"]["incident_type"];
          match_id: string;
          occurred_at: string | null;
          reason_category: string | null;
          reported_at: string;
          reporter_profile_id: string;
          review_admin_profile_id: string | null;
          reviewed_at: string | null;
          status: Database["public"]["Enums"]["incident_status"];
          subject_profile_id: string | null;
          unresponsive_since: string | null;
          updated_at: string;
        };
        Insert: {
          confirmed_at?: string | null;
          created_at?: string;
          id?: string;
          idempotency_key: string;
          incident_type: Database["public"]["Enums"]["incident_type"];
          match_id: string;
          occurred_at?: string | null;
          reason_category?: string | null;
          reported_at?: string;
          reporter_profile_id: string;
          review_admin_profile_id?: string | null;
          reviewed_at?: string | null;
          status?: Database["public"]["Enums"]["incident_status"];
          subject_profile_id?: string | null;
          unresponsive_since?: string | null;
          updated_at?: string;
        };
        Update: {
          confirmed_at?: string | null;
          created_at?: string;
          id?: string;
          idempotency_key?: string;
          incident_type?: Database["public"]["Enums"]["incident_type"];
          match_id?: string;
          occurred_at?: string | null;
          reason_category?: string | null;
          reported_at?: string;
          reporter_profile_id?: string;
          review_admin_profile_id?: string | null;
          reviewed_at?: string | null;
          status?: Database["public"]["Enums"]["incident_status"];
          subject_profile_id?: string | null;
          unresponsive_since?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "incidents_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_match_id_reporter_profile_id_fkey";
            columns: ["match_id", "reporter_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "incidents_match_id_reporter_profile_id_fkey";
            columns: ["match_id", "reporter_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "incidents_reporter_profile_id_fkey";
            columns: ["reporter_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_reporter_profile_id_fkey";
            columns: ["reporter_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_review_admin_profile_id_fkey";
            columns: ["review_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_review_admin_profile_id_fkey";
            columns: ["review_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_subject_participant_fk";
            columns: ["match_id", "subject_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "incidents_subject_participant_fk";
            columns: ["match_id", "subject_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "incidents_subject_profile_id_fkey";
            columns: ["subject_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "incidents_subject_profile_id_fkey";
            columns: ["subject_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      match_events: {
        Row: {
          actor_profile_id: string | null;
          created_at: string;
          event_type: Database["public"]["Enums"]["match_event_type"];
          id: string;
          idempotency_key: string;
          match_id: string;
          metadata: Json;
          new_host_profile_id: string | null;
          preset_message_type:
            Database["public"]["Enums"]["preset_message_type"] | null;
          previous_host_profile_id: string | null;
          visibility: Database["public"]["Enums"]["event_visibility"];
        };
        Insert: {
          actor_profile_id?: string | null;
          created_at?: string;
          event_type: Database["public"]["Enums"]["match_event_type"];
          id?: string;
          idempotency_key: string;
          match_id: string;
          metadata?: Json;
          new_host_profile_id?: string | null;
          preset_message_type?:
            Database["public"]["Enums"]["preset_message_type"] | null;
          previous_host_profile_id?: string | null;
          visibility?: Database["public"]["Enums"]["event_visibility"];
        };
        Update: {
          actor_profile_id?: string | null;
          created_at?: string;
          event_type?: Database["public"]["Enums"]["match_event_type"];
          id?: string;
          idempotency_key?: string;
          match_id?: string;
          metadata?: Json;
          new_host_profile_id?: string | null;
          preset_message_type?:
            Database["public"]["Enums"]["preset_message_type"] | null;
          previous_host_profile_id?: string | null;
          visibility?: Database["public"]["Enums"]["event_visibility"];
        };
        Relationships: [
          {
            foreignKeyName: "match_events_actor_participant_fk";
            columns: ["match_id", "actor_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_actor_participant_fk";
            columns: ["match_id", "actor_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_actor_profile_id_fkey";
            columns: ["actor_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_actor_profile_id_fkey";
            columns: ["actor_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_new_host_participant_fk";
            columns: ["match_id", "new_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_new_host_participant_fk";
            columns: ["match_id", "new_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_new_host_profile_id_fkey";
            columns: ["new_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_new_host_profile_id_fkey";
            columns: ["new_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_previous_host_participant_fk";
            columns: ["match_id", "previous_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_previous_host_participant_fk";
            columns: ["match_id", "previous_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "match_events_previous_host_profile_id_fkey";
            columns: ["previous_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_events_previous_host_profile_id_fkey";
            columns: ["previous_host_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      match_participants: {
        Row: {
          cleared_at: string | null;
          is_active: boolean;
          joined_at: string;
          match_id: string;
          placement_completed_count_snapshot: number;
          placement_status_snapshot: Database["public"]["Enums"]["placement_status"];
          profile_id: string;
          rating_snapshot: number;
          side: Database["public"]["Enums"]["match_side"];
        };
        Insert: {
          cleared_at?: string | null;
          is_active?: boolean;
          joined_at?: string;
          match_id: string;
          placement_completed_count_snapshot: number;
          placement_status_snapshot: Database["public"]["Enums"]["placement_status"];
          profile_id: string;
          rating_snapshot: number;
          side: Database["public"]["Enums"]["match_side"];
        };
        Update: {
          cleared_at?: string | null;
          is_active?: boolean;
          joined_at?: string;
          match_id?: string;
          placement_completed_count_snapshot?: number;
          placement_status_snapshot?: Database["public"]["Enums"]["placement_status"];
          profile_id?: string;
          rating_snapshot?: number;
          side?: Database["public"]["Enums"]["match_side"];
        };
        Relationships: [
          {
            foreignKeyName: "match_participants_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_participants_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_participants_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      matches: {
        Row: {
          cancelled_at: string | null;
          completed_at: string | null;
          created_at: string;
          creation_source: Database["public"]["Enums"]["match_creation_source"];
          disputed_at: string | null;
          first_reported_at: string | null;
          host_profile_id: string | null;
          id: string;
          is_rated: boolean;
          loser_profile_id: string | null;
          matched_at: string;
          player_a_score: number | null;
          player_b_score: number | null;
          rating_parameter_version: string | null;
          rating_status: Database["public"]["Enums"]["match_rating_status"];
          reporting_started_at: string | null;
          resolution_type:
            Database["public"]["Enums"]["match_resolution_type"] | null;
          result_validity:
            Database["public"]["Enums"]["match_result_validity"] | null;
          room_setup_started_at: string | null;
          season_id: string;
          status: Database["public"]["Enums"]["match_status"];
          termination_player_a_score: number | null;
          termination_player_b_score: number | null;
          updated_at: string;
          version: number;
          winner_profile_id: string | null;
        };
        Insert: {
          cancelled_at?: string | null;
          completed_at?: string | null;
          created_at?: string;
          creation_source: Database["public"]["Enums"]["match_creation_source"];
          disputed_at?: string | null;
          first_reported_at?: string | null;
          host_profile_id?: string | null;
          id?: string;
          is_rated: boolean;
          loser_profile_id?: string | null;
          matched_at?: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          rating_parameter_version?: string | null;
          rating_status: Database["public"]["Enums"]["match_rating_status"];
          reporting_started_at?: string | null;
          resolution_type?:
            Database["public"]["Enums"]["match_resolution_type"] | null;
          result_validity?:
            Database["public"]["Enums"]["match_result_validity"] | null;
          room_setup_started_at?: string | null;
          season_id: string;
          status?: Database["public"]["Enums"]["match_status"];
          termination_player_a_score?: number | null;
          termination_player_b_score?: number | null;
          updated_at?: string;
          version?: number;
          winner_profile_id?: string | null;
        };
        Update: {
          cancelled_at?: string | null;
          completed_at?: string | null;
          created_at?: string;
          creation_source?: Database["public"]["Enums"]["match_creation_source"];
          disputed_at?: string | null;
          first_reported_at?: string | null;
          host_profile_id?: string | null;
          id?: string;
          is_rated?: boolean;
          loser_profile_id?: string | null;
          matched_at?: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          rating_parameter_version?: string | null;
          rating_status?: Database["public"]["Enums"]["match_rating_status"];
          reporting_started_at?: string | null;
          resolution_type?:
            Database["public"]["Enums"]["match_resolution_type"] | null;
          result_validity?:
            Database["public"]["Enums"]["match_result_validity"] | null;
          room_setup_started_at?: string | null;
          season_id?: string;
          status?: Database["public"]["Enums"]["match_status"];
          termination_player_a_score?: number | null;
          termination_player_b_score?: number | null;
          updated_at?: string;
          version?: number;
          winner_profile_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "matches_host_participant_fk";
            columns: ["id", "host_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "matches_host_participant_fk";
            columns: ["id", "host_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "matches_loser_participant_fk";
            columns: ["id", "loser_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "matches_loser_participant_fk";
            columns: ["id", "loser_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "matches_rating_parameter_version_fkey";
            columns: ["rating_parameter_version"];
            isOneToOne: false;
            referencedRelation: "rating_parameter_sets";
            referencedColumns: ["version"];
          },
          {
            foreignKeyName: "matches_season_id_fkey";
            columns: ["season_id"];
            isOneToOne: false;
            referencedRelation: "seasons";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "matches_winner_participant_fk";
            columns: ["id", "winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "matches_winner_participant_fk";
            columns: ["id", "winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
        ];
      };
      placement_initializations: {
        Row: {
          calculated_at: string;
          created_at: string;
          locked_at: string | null;
          parameter_version: string;
          profile_id: string;
          source: Database["public"]["Enums"]["starting_rating_source"];
          source_master_rating: number | null;
          source_rank: Database["public"]["Enums"]["sf6_rank"] | null;
          source_rank_tier: number | null;
          starting_rating: number;
        };
        Insert: {
          calculated_at?: string;
          created_at?: string;
          locked_at?: string | null;
          parameter_version: string;
          profile_id: string;
          source: Database["public"]["Enums"]["starting_rating_source"];
          source_master_rating?: number | null;
          source_rank?: Database["public"]["Enums"]["sf6_rank"] | null;
          source_rank_tier?: number | null;
          starting_rating: number;
        };
        Update: {
          calculated_at?: string;
          created_at?: string;
          locked_at?: string | null;
          parameter_version?: string;
          profile_id?: string;
          source?: Database["public"]["Enums"]["starting_rating_source"];
          source_master_rating?: number | null;
          source_rank?: Database["public"]["Enums"]["sf6_rank"] | null;
          source_rank_tier?: number | null;
          starting_rating?: number;
        };
        Relationships: [
          {
            foreignKeyName: "placement_initializations_parameter_version_fkey";
            columns: ["parameter_version"];
            isOneToOne: false;
            referencedRelation: "starting_rating_parameter_sets";
            referencedColumns: ["version"];
          },
          {
            foreignKeyName: "placement_initializations_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "placement_initializations_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      profile_accounts: {
        Row: {
          account_status: Database["public"]["Enums"]["account_status"];
          anonymized_at: string | null;
          application_role: Database["public"]["Enums"]["application_role"];
          auth_user_id: string | null;
          created_at: string;
          deletion_requested_at: string | null;
          onboarding_completed_at: string | null;
          onboarding_current_step: number;
          onboarding_status: Database["public"]["Enums"]["onboarding_status"];
          profile_id: string;
          updated_at: string;
          username_changed_at: string | null;
        };
        Insert: {
          account_status?: Database["public"]["Enums"]["account_status"];
          anonymized_at?: string | null;
          application_role?: Database["public"]["Enums"]["application_role"];
          auth_user_id?: string | null;
          created_at?: string;
          deletion_requested_at?: string | null;
          onboarding_completed_at?: string | null;
          onboarding_current_step?: number;
          onboarding_status?: Database["public"]["Enums"]["onboarding_status"];
          profile_id: string;
          updated_at?: string;
          username_changed_at?: string | null;
        };
        Update: {
          account_status?: Database["public"]["Enums"]["account_status"];
          anonymized_at?: string | null;
          application_role?: Database["public"]["Enums"]["application_role"];
          auth_user_id?: string | null;
          created_at?: string;
          deletion_requested_at?: string | null;
          onboarding_completed_at?: string | null;
          onboarding_current_step?: number;
          onboarding_status?: Database["public"]["Enums"]["onboarding_status"];
          profile_id?: string;
          updated_at?: string;
          username_changed_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "profile_accounts_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "profile_accounts_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      profile_private_details: {
        Row: {
          broad_region_code: string | null;
          current_master_rating: number | null;
          current_sf6_rank: Database["public"]["Enums"]["sf6_rank"] | null;
          current_sf6_rank_tier: number | null;
          main_character_code: string | null;
          profile_id: string;
          updated_at: string;
        };
        Insert: {
          broad_region_code?: string | null;
          current_master_rating?: number | null;
          current_sf6_rank?: Database["public"]["Enums"]["sf6_rank"] | null;
          current_sf6_rank_tier?: number | null;
          main_character_code?: string | null;
          profile_id: string;
          updated_at?: string;
        };
        Update: {
          broad_region_code?: string | null;
          current_master_rating?: number | null;
          current_sf6_rank?: Database["public"]["Enums"]["sf6_rank"] | null;
          current_sf6_rank_tier?: number | null;
          main_character_code?: string | null;
          profile_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "profile_private_details_character_master_fk";
            columns: ["main_character_code"];
            isOneToOne: false;
            referencedRelation: "sf6_characters";
            referencedColumns: ["code"];
          },
          {
            foreignKeyName: "profile_private_details_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "profile_private_details_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "profile_private_details_region_master_fk";
            columns: ["broad_region_code"];
            isOneToOne: false;
            referencedRelation: "broad_regions";
            referencedColumns: ["code"];
          },
        ];
      };
      profile_sf6_identities: {
        Row: {
          profile_id: string;
          sf6_player_name: string | null;
          sf6_user_code: string | null;
          sf6_user_code_changed_at: string | null;
          sf6_user_code_normalized: string | null;
          updated_at: string;
        };
        Insert: {
          profile_id: string;
          sf6_player_name?: string | null;
          sf6_user_code?: string | null;
          sf6_user_code_changed_at?: string | null;
          sf6_user_code_normalized?: string | null;
          updated_at?: string;
        };
        Update: {
          profile_id?: string;
          sf6_player_name?: string | null;
          sf6_user_code?: string | null;
          sf6_user_code_changed_at?: string | null;
          sf6_user_code_normalized?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "profile_sf6_identities_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "profile_sf6_identities_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: true;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      profiles: {
        Row: {
          avatar_asset_id: string | null;
          avatar_source: Database["public"]["Enums"]["avatar_source_type"];
          avatar_url: string | null;
          country_code: string | null;
          created_at: string;
          current_rating: number | null;
          deleted_at: string | null;
          id: string;
          is_public: boolean;
          placement_completed_count: number;
          placement_status: Database["public"]["Enums"]["placement_status"];
          ranking_eligible: boolean;
          rating_reached_at: string | null;
          updated_at: string;
          username: string | null;
          username_normalized: string | null;
        };
        Insert: {
          avatar_asset_id?: string | null;
          avatar_source?: Database["public"]["Enums"]["avatar_source_type"];
          avatar_url?: string | null;
          country_code?: string | null;
          created_at?: string;
          current_rating?: number | null;
          deleted_at?: string | null;
          id?: string;
          is_public?: boolean;
          placement_completed_count?: number;
          placement_status?: Database["public"]["Enums"]["placement_status"];
          ranking_eligible?: boolean;
          rating_reached_at?: string | null;
          updated_at?: string;
          username?: string | null;
          username_normalized?: string | null;
        };
        Update: {
          avatar_asset_id?: string | null;
          avatar_source?: Database["public"]["Enums"]["avatar_source_type"];
          avatar_url?: string | null;
          country_code?: string | null;
          created_at?: string;
          current_rating?: number | null;
          deleted_at?: string | null;
          id?: string;
          is_public?: boolean;
          placement_completed_count?: number;
          placement_status?: Database["public"]["Enums"]["placement_status"];
          ranking_eligible?: boolean;
          rating_reached_at?: string | null;
          updated_at?: string;
          username?: string | null;
          username_normalized?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "profiles_avatar_asset_id_fkey";
            columns: ["avatar_asset_id"];
            isOneToOne: false;
            referencedRelation: "avatar_assets";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "profiles_country_master_fk";
            columns: ["country_code"];
            isOneToOne: false;
            referencedRelation: "countries";
            referencedColumns: ["code"];
          },
        ];
      };
      rated_pair_cooldowns: {
        Row: {
          last_rated_result_confirmed_at: string;
          next_rated_eligible_at: string;
          profile_high_id: string;
          profile_low_id: string;
          source_match_id: string;
          updated_at: string;
        };
        Insert: {
          last_rated_result_confirmed_at: string;
          next_rated_eligible_at: string;
          profile_high_id: string;
          profile_low_id: string;
          source_match_id: string;
          updated_at?: string;
        };
        Update: {
          last_rated_result_confirmed_at?: string;
          next_rated_eligible_at?: string;
          profile_high_id?: string;
          profile_low_id?: string;
          source_match_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "rated_pair_cooldowns_profile_high_id_fkey";
            columns: ["profile_high_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rated_pair_cooldowns_profile_high_id_fkey";
            columns: ["profile_high_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rated_pair_cooldowns_profile_low_id_fkey";
            columns: ["profile_low_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rated_pair_cooldowns_profile_low_id_fkey";
            columns: ["profile_low_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rated_pair_cooldowns_source_match_id_fkey";
            columns: ["source_match_id"];
            isOneToOne: true;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
        ];
      };
      rating_corrections: {
        Row: {
          applied_at: string | null;
          applied_by_admin_profile_id: string | null;
          compensating_rating_change: number;
          correction_type: Database["public"]["Enums"]["rating_correction_type"];
          created_at: string;
          id: string;
          original_rating_change: number;
          profile_id: string;
          reason_category: string;
          source_match_id: string;
        };
        Insert: {
          applied_at?: string | null;
          applied_by_admin_profile_id?: string | null;
          compensating_rating_change: number;
          correction_type: Database["public"]["Enums"]["rating_correction_type"];
          created_at?: string;
          id?: string;
          original_rating_change: number;
          profile_id: string;
          reason_category: string;
          source_match_id: string;
        };
        Update: {
          applied_at?: string | null;
          applied_by_admin_profile_id?: string | null;
          compensating_rating_change?: number;
          correction_type?: Database["public"]["Enums"]["rating_correction_type"];
          created_at?: string;
          id?: string;
          original_rating_change?: number;
          profile_id?: string;
          reason_category?: string;
          source_match_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "rating_corrections_applied_by_admin_profile_id_fkey";
            columns: ["applied_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_corrections_applied_by_admin_profile_id_fkey";
            columns: ["applied_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_corrections_match_participant_fk";
            columns: ["source_match_id", "profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "rating_corrections_match_participant_fk";
            columns: ["source_match_id", "profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "rating_corrections_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_corrections_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_corrections_source_match_id_fkey";
            columns: ["source_match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
        ];
      };
      rating_history: {
        Row: {
          cap_applied: boolean | null;
          cap_value: number | null;
          change_after_cap: number | null;
          change_after_multiplier: number | null;
          correction_id: string | null;
          created_at: string;
          entry_type: Database["public"]["Enums"]["rating_entry_type"];
          expected_score: number | null;
          expected_score_scale: number | null;
          id: string;
          idempotency_key: string;
          k_factor: number | null;
          match_id: string | null;
          opponent_rating_snapshot: number | null;
          parameter_version: string | null;
          placement_match_number: number | null;
          placement_multiplier: number | null;
          profile_id: string;
          rating_after: number;
          rating_before: number;
          raw_base_change: number | null;
          reason_category: string | null;
          rounded_final_change: number;
          season_id: string;
        };
        Insert: {
          cap_applied?: boolean | null;
          cap_value?: number | null;
          change_after_cap?: number | null;
          change_after_multiplier?: number | null;
          correction_id?: string | null;
          created_at?: string;
          entry_type: Database["public"]["Enums"]["rating_entry_type"];
          expected_score?: number | null;
          expected_score_scale?: number | null;
          id?: string;
          idempotency_key: string;
          k_factor?: number | null;
          match_id?: string | null;
          opponent_rating_snapshot?: number | null;
          parameter_version?: string | null;
          placement_match_number?: number | null;
          placement_multiplier?: number | null;
          profile_id: string;
          rating_after: number;
          rating_before: number;
          raw_base_change?: number | null;
          reason_category?: string | null;
          rounded_final_change: number;
          season_id: string;
        };
        Update: {
          cap_applied?: boolean | null;
          cap_value?: number | null;
          change_after_cap?: number | null;
          change_after_multiplier?: number | null;
          correction_id?: string | null;
          created_at?: string;
          entry_type?: Database["public"]["Enums"]["rating_entry_type"];
          expected_score?: number | null;
          expected_score_scale?: number | null;
          id?: string;
          idempotency_key?: string;
          k_factor?: number | null;
          match_id?: string | null;
          opponent_rating_snapshot?: number | null;
          parameter_version?: string | null;
          placement_match_number?: number | null;
          placement_multiplier?: number | null;
          profile_id?: string;
          rating_after?: number;
          rating_before?: number;
          raw_base_change?: number | null;
          reason_category?: string | null;
          rounded_final_change?: number;
          season_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "rating_history_correction_fk";
            columns: ["correction_id"];
            isOneToOne: false;
            referencedRelation: "rating_corrections";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_history_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_history_match_participant_fk";
            columns: ["match_id", "profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "rating_history_match_participant_fk";
            columns: ["match_id", "profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "rating_history_parameter_version_fk";
            columns: ["parameter_version"];
            isOneToOne: false;
            referencedRelation: "rating_parameter_sets";
            referencedColumns: ["version"];
          },
          {
            foreignKeyName: "rating_history_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_history_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "rating_history_season_id_fkey";
            columns: ["season_id"];
            isOneToOne: false;
            referencedRelation: "seasons";
            referencedColumns: ["id"];
          },
        ];
      };
      rating_parameter_sets: {
        Row: {
          center_rating: number;
          created_at: string;
          effective_from: string;
          expected_score_scale: number;
          is_active: boolean;
          k_factor: number;
          placement_cap: number;
          placement_multiplier_1_3: number;
          placement_multiplier_4_7: number;
          placement_multiplier_8_10: number;
          rounding_rule: string;
          version: string;
        };
        Insert: {
          center_rating: number;
          created_at?: string;
          effective_from: string;
          expected_score_scale: number;
          is_active?: boolean;
          k_factor: number;
          placement_cap: number;
          placement_multiplier_1_3: number;
          placement_multiplier_4_7: number;
          placement_multiplier_8_10: number;
          rounding_rule: string;
          version: string;
        };
        Update: {
          center_rating?: number;
          created_at?: string;
          effective_from?: string;
          expected_score_scale?: number;
          is_active?: boolean;
          k_factor?: number;
          placement_cap?: number;
          placement_multiplier_1_3?: number;
          placement_multiplier_4_7?: number;
          placement_multiplier_8_10?: number;
          rounding_rule?: string;
          version?: string;
        };
        Relationships: [];
      };
      restriction_incidents: {
        Row: {
          incident_id: string;
          restriction_id: string;
        };
        Insert: {
          incident_id: string;
          restriction_id: string;
        };
        Update: {
          incident_id?: string;
          restriction_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "restriction_incidents_incident_id_fkey";
            columns: ["incident_id"];
            isOneToOne: false;
            referencedRelation: "incidents";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "restriction_incidents_restriction_id_fkey";
            columns: ["restriction_id"];
            isOneToOne: false;
            referencedRelation: "user_restrictions";
            referencedColumns: ["id"];
          },
        ];
      };
      result_report_revisions: {
        Row: {
          id: string;
          player_a_score: number | null;
          player_b_score: number | null;
          reported_winner_profile_id: string;
          result_report_id: string;
          revision_number: number;
          submitted_at: string;
        };
        Insert: {
          id?: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          reported_winner_profile_id: string;
          result_report_id: string;
          revision_number: number;
          submitted_at?: string;
        };
        Update: {
          id?: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          reported_winner_profile_id?: string;
          result_report_id?: string;
          revision_number?: number;
          submitted_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "result_report_revisions_reported_winner_profile_id_fkey";
            columns: ["reported_winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "result_report_revisions_reported_winner_profile_id_fkey";
            columns: ["reported_winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "result_report_revisions_result_report_id_fkey";
            columns: ["result_report_id"];
            isOneToOne: false;
            referencedRelation: "result_reports";
            referencedColumns: ["id"];
          },
        ];
      };
      result_reports: {
        Row: {
          created_at: string;
          id: string;
          idempotency_key: string;
          last_revised_at: string | null;
          match_id: string;
          player_a_score: number | null;
          player_b_score: number | null;
          report_type: Database["public"]["Enums"]["result_report_type"];
          reported_winner_profile_id: string;
          reporting_profile_id: string;
          revision_number: number;
          status: Database["public"]["Enums"]["result_report_status"];
          submitted_at: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          idempotency_key: string;
          last_revised_at?: string | null;
          match_id: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          report_type: Database["public"]["Enums"]["result_report_type"];
          reported_winner_profile_id: string;
          reporting_profile_id: string;
          revision_number?: number;
          status?: Database["public"]["Enums"]["result_report_status"];
          submitted_at?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          idempotency_key?: string;
          last_revised_at?: string | null;
          match_id?: string;
          player_a_score?: number | null;
          player_b_score?: number | null;
          report_type?: Database["public"]["Enums"]["result_report_type"];
          reported_winner_profile_id?: string;
          reporting_profile_id?: string;
          revision_number?: number;
          status?: Database["public"]["Enums"]["result_report_status"];
          submitted_at?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "result_reports_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "result_reports_match_id_reported_winner_profile_id_fkey";
            columns: ["match_id", "reported_winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "result_reports_match_id_reported_winner_profile_id_fkey";
            columns: ["match_id", "reported_winner_profile_id"];
            isOneToOne: false;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "result_reports_match_id_reporting_profile_id_fkey";
            columns: ["match_id", "reporting_profile_id"];
            isOneToOne: true;
            referencedRelation: "active_match_private_profiles";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "result_reports_match_id_reporting_profile_id_fkey";
            columns: ["match_id", "reporting_profile_id"];
            isOneToOne: true;
            referencedRelation: "match_participants";
            referencedColumns: ["match_id", "profile_id"];
          },
          {
            foreignKeyName: "result_reports_reporting_profile_id_fkey";
            columns: ["reporting_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "result_reports_reporting_profile_id_fkey";
            columns: ["reporting_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      season_player_records: {
        Row: {
          created_at: string;
          current_rating: number;
          final_ranking: number | null;
          final_rated_losses: number | null;
          final_rated_match_count: number | null;
          final_rated_wins: number | null;
          final_rating: number | null;
          final_win_rate: number | null;
          losses_0_3: number;
          losses_1_3: number;
          losses_2_3: number;
          profile_id: string;
          ranking_eligible: boolean;
          rated_losses: number;
          rated_match_count: number;
          rated_wins: number;
          record_status: Database["public"]["Enums"]["season_record_status"];
          season_id: string;
          snapshot_at: string | null;
          updated_at: string;
          wins_3_0: number;
          wins_3_1: number;
          wins_3_2: number;
        };
        Insert: {
          created_at?: string;
          current_rating: number;
          final_ranking?: number | null;
          final_rated_losses?: number | null;
          final_rated_match_count?: number | null;
          final_rated_wins?: number | null;
          final_rating?: number | null;
          final_win_rate?: number | null;
          losses_0_3?: number;
          losses_1_3?: number;
          losses_2_3?: number;
          profile_id: string;
          ranking_eligible: boolean;
          rated_losses?: number;
          rated_match_count?: number;
          rated_wins?: number;
          record_status?: Database["public"]["Enums"]["season_record_status"];
          season_id: string;
          snapshot_at?: string | null;
          updated_at?: string;
          wins_3_0?: number;
          wins_3_1?: number;
          wins_3_2?: number;
        };
        Update: {
          created_at?: string;
          current_rating?: number;
          final_ranking?: number | null;
          final_rated_losses?: number | null;
          final_rated_match_count?: number | null;
          final_rated_wins?: number | null;
          final_rating?: number | null;
          final_win_rate?: number | null;
          losses_0_3?: number;
          losses_1_3?: number;
          losses_2_3?: number;
          profile_id?: string;
          ranking_eligible?: boolean;
          rated_losses?: number;
          rated_match_count?: number;
          rated_wins?: number;
          record_status?: Database["public"]["Enums"]["season_record_status"];
          season_id?: string;
          snapshot_at?: string | null;
          updated_at?: string;
          wins_3_0?: number;
          wins_3_1?: number;
          wins_3_2?: number;
        };
        Relationships: [
          {
            foreignKeyName: "season_player_records_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "season_player_records_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "season_player_records_season_id_fkey";
            columns: ["season_id"];
            isOneToOne: false;
            referencedRelation: "seasons";
            referencedColumns: ["id"];
          },
        ];
      };
      seasons: {
        Row: {
          completed_at: string | null;
          created_at: string;
          ends_at: string;
          id: string;
          name: string;
          rollover_key: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["season_status"];
          updated_at: string;
        };
        Insert: {
          completed_at?: string | null;
          created_at?: string;
          ends_at: string;
          id?: string;
          name: string;
          rollover_key?: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["season_status"];
          updated_at?: string;
        };
        Update: {
          completed_at?: string | null;
          created_at?: string;
          ends_at?: string;
          id?: string;
          name?: string;
          rollover_key?: string | null;
          starts_at?: string;
          status?: Database["public"]["Enums"]["season_status"];
          updated_at?: string;
        };
        Relationships: [];
      };
      sf6_characters: {
        Row: {
          code: string;
          created_at: string;
          is_active: boolean;
          name: string;
          sort_order: number;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          is_active?: boolean;
          name: string;
          sort_order: number;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          is_active?: boolean;
          name?: string;
          sort_order?: number;
          updated_at?: string;
        };
        Relationships: [];
      };
      starting_rating_parameter_sets: {
        Row: {
          created_at: string;
          effective_from: string;
          is_active: boolean;
          master_base_rating: number;
          master_maximum: number;
          master_minimum: number;
          master_mr_center: number;
          master_mr_coefficient: number;
          mr_validation_maximum: number | null;
          mr_validation_minimum: number | null;
          rank_base_ratings: Json;
          subrank_adjustments: Json;
          version: string;
        };
        Insert: {
          created_at?: string;
          effective_from: string;
          is_active?: boolean;
          master_base_rating: number;
          master_maximum: number;
          master_minimum: number;
          master_mr_center: number;
          master_mr_coefficient: number;
          mr_validation_maximum?: number | null;
          mr_validation_minimum?: number | null;
          rank_base_ratings: Json;
          subrank_adjustments: Json;
          version: string;
        };
        Update: {
          created_at?: string;
          effective_from?: string;
          is_active?: boolean;
          master_base_rating?: number;
          master_maximum?: number;
          master_minimum?: number;
          master_mr_center?: number;
          master_mr_coefficient?: number;
          mr_validation_maximum?: number | null;
          mr_validation_minimum?: number | null;
          rank_base_ratings?: Json;
          subrank_adjustments?: Json;
          version?: string;
        };
        Relationships: [];
      };
      user_restrictions: {
        Row: {
          applied_by_admin_profile_id: string | null;
          created_at: string;
          expires_at: string | null;
          id: string;
          profile_id: string;
          reason_category: string;
          restriction_type: Database["public"]["Enums"]["restriction_type"];
          revoked_at: string | null;
          revoked_by_admin_profile_id: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["restriction_status"];
          updated_at: string;
        };
        Insert: {
          applied_by_admin_profile_id?: string | null;
          created_at?: string;
          expires_at?: string | null;
          id?: string;
          profile_id: string;
          reason_category: string;
          restriction_type?: Database["public"]["Enums"]["restriction_type"];
          revoked_at?: string | null;
          revoked_by_admin_profile_id?: string | null;
          starts_at: string;
          status: Database["public"]["Enums"]["restriction_status"];
          updated_at?: string;
        };
        Update: {
          applied_by_admin_profile_id?: string | null;
          created_at?: string;
          expires_at?: string | null;
          id?: string;
          profile_id?: string;
          reason_category?: string;
          restriction_type?: Database["public"]["Enums"]["restriction_type"];
          revoked_at?: string | null;
          revoked_by_admin_profile_id?: string | null;
          starts_at?: string;
          status?: Database["public"]["Enums"]["restriction_status"];
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "user_restrictions_applied_by_admin_profile_id_fkey";
            columns: ["applied_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_restrictions_applied_by_admin_profile_id_fkey";
            columns: ["applied_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_restrictions_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_restrictions_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_restrictions_revoked_by_admin_profile_id_fkey";
            columns: ["revoked_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "user_restrictions_revoked_by_admin_profile_id_fkey";
            columns: ["revoked_by_admin_profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      waiting_entries: {
        Row: {
          auto_match_eligible: boolean;
          broad_region_code_snapshot: string;
          cancelled_at: string | null;
          country_code_snapshot: string;
          created_at: string;
          expires_at: string;
          id: string;
          last_active_at: string;
          matched_at: string | null;
          mode: Database["public"]["Enums"]["waiting_mode"];
          placement_completed_count_snapshot: number;
          placement_status_snapshot: Database["public"]["Enums"]["placement_status"];
          profile_id: string;
          rating_snapshot: number;
          started_at: string;
          status: Database["public"]["Enums"]["waiting_status"];
          updated_at: string;
          version: number;
        };
        Insert: {
          auto_match_eligible: boolean;
          broad_region_code_snapshot: string;
          cancelled_at?: string | null;
          country_code_snapshot: string;
          created_at?: string;
          expires_at: string;
          id?: string;
          last_active_at?: string;
          matched_at?: string | null;
          mode: Database["public"]["Enums"]["waiting_mode"];
          placement_completed_count_snapshot: number;
          placement_status_snapshot: Database["public"]["Enums"]["placement_status"];
          profile_id: string;
          rating_snapshot: number;
          started_at?: string;
          status?: Database["public"]["Enums"]["waiting_status"];
          updated_at?: string;
          version?: number;
        };
        Update: {
          auto_match_eligible?: boolean;
          broad_region_code_snapshot?: string;
          cancelled_at?: string | null;
          country_code_snapshot?: string;
          created_at?: string;
          expires_at?: string;
          id?: string;
          last_active_at?: string;
          matched_at?: string | null;
          mode?: Database["public"]["Enums"]["waiting_mode"];
          placement_completed_count_snapshot?: number;
          placement_status_snapshot?: Database["public"]["Enums"]["placement_status"];
          profile_id?: string;
          rating_snapshot?: number;
          started_at?: string;
          status?: Database["public"]["Enums"]["waiting_status"];
          updated_at?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "waiting_entries_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "waiting_entries_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      active_match_private_profiles: {
        Row: {
          avatar_url: string | null;
          host_profile_id: string | null;
          match_id: string | null;
          placement_completed_count_snapshot: number | null;
          placement_status_snapshot:
            Database["public"]["Enums"]["placement_status"] | null;
          profile_id: string | null;
          rating_snapshot: number | null;
          sf6_player_name: string | null;
          sf6_user_code: string | null;
          side: Database["public"]["Enums"]["match_side"] | null;
          status: Database["public"]["Enums"]["match_status"] | null;
          username: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "match_participants_match_id_fkey";
            columns: ["match_id"];
            isOneToOne: false;
            referencedRelation: "matches";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_participants_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "match_participants_profile_id_fkey";
            columns: ["profile_id"];
            isOneToOne: false;
            referencedRelation: "public_profiles";
            referencedColumns: ["id"];
          },
        ];
      };
      public_profiles: {
        Row: {
          avatar_url: string | null;
          country_code: string | null;
          created_at: string | null;
          current_rating: number | null;
          id: string | null;
          placement_completed_count: number | null;
          placement_status:
            Database["public"]["Enums"]["placement_status"] | null;
          ranking_eligible: boolean | null;
          rating_reached_at: string | null;
          updated_at: string | null;
          username: string | null;
        };
        Insert: {
          avatar_url?: string | null;
          country_code?: string | null;
          created_at?: string | null;
          current_rating?: number | null;
          id?: string | null;
          placement_completed_count?: number | null;
          placement_status?:
            Database["public"]["Enums"]["placement_status"] | null;
          ranking_eligible?: boolean | null;
          rating_reached_at?: string | null;
          updated_at?: string | null;
          username?: string | null;
        };
        Update: {
          avatar_url?: string | null;
          country_code?: string | null;
          created_at?: string | null;
          current_rating?: number | null;
          id?: string | null;
          placement_completed_count?: number | null;
          placement_status?:
            Database["public"]["Enums"]["placement_status"] | null;
          ranking_eligible?: boolean | null;
          rating_reached_at?: string | null;
          updated_at?: string | null;
          username?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "profiles_country_master_fk";
            columns: ["country_code"];
            isOneToOne: false;
            referencedRelation: "countries";
            referencedColumns: ["code"];
          },
        ];
      };
    };
    Functions: {
      phase1_database_health: { Args: never; Returns: Json };
      phase2_attach_avatar: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_byte_size: number;
          requested_content_sha256: string;
          requested_hash: string;
          requested_height: number;
          requested_idempotency_key: string;
          requested_public_url: string;
          requested_storage_path: string;
          requested_width: number;
        };
        Returns: Json;
      };
      phase2_avatar_cleanup_paths: {
        Args: { requested_actor_auth_user_id: string };
        Returns: string[];
      };
      phase2_complete_onboarding: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_character_code: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_master_rating: number;
          requested_rank: Database["public"]["Enums"]["sf6_rank"];
          requested_rank_tier: number;
        };
        Returns: Json;
      };
      phase2_detach_avatar: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
        };
        Returns: Json;
      };
      phase2_detach_avatars_for_deletion: {
        Args: { requested_actor_auth_user_id: string };
        Returns: string[];
      };
      phase2_mark_auth_deletion_complete: {
        Args: { requested_job_id: string };
        Returns: Json;
      };
      phase2_mark_auth_deletion_failed: {
        Args: { requested_error_code: string; requested_job_id: string };
        Returns: Json;
      };
      phase2_onboarding_state: {
        Args: { requested_actor_auth_user_id: string };
        Returns: Json;
      };
      phase2_prepare_account_anonymization: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_user_code_digest: string;
        };
        Returns: Json;
      };
      phase2_preview_starting_rating: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_character_code: string;
          requested_master_rating: number;
          requested_rank: Database["public"]["Enums"]["sf6_rank"];
          requested_rank_tier: number;
        };
        Returns: Json;
      };
      phase2_request_account_deletion: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
        };
        Returns: Json;
      };
      phase2_retryable_auth_deletion_job: {
        Args: { requested_profile_id: string };
        Returns: Json;
      };
      phase2_save_account_step: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_oauth_avatar_url: string;
          requested_username: string;
          requested_username_normalized: string;
        };
        Returns: Json;
      };
      phase2_save_sf6_info_step: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_broad_region_code: string;
          requested_country_code: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_player_name: string;
          requested_user_code: string;
          requested_user_code_digest: string;
        };
        Returns: Json;
      };
      phase2_update_profile_details: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_broad_region_code: string;
          requested_character_code: string;
          requested_country_code: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_master_rating: number;
          requested_rank: Database["public"]["Enums"]["sf6_rank"];
          requested_rank_tier: number;
        };
        Returns: Json;
      };
      phase2_update_sf6_identity: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_player_name: string;
          requested_user_code: string;
          requested_user_code_digest: string;
        };
        Returns: Json;
      };
      phase2_update_username: {
        Args: {
          requested_actor_auth_user_id: string;
          requested_hash: string;
          requested_idempotency_key: string;
          requested_username: string;
          requested_username_normalized: string;
        };
        Returns: Json;
      };
    };
    Enums: {
      account_status:
        "onboarding" | "active" | "deletion_pending" | "anonymized";
      application_role: "user" | "admin";
      avatar_source_type: "default" | "oauth" | "upload";
      dispute_entry_reason:
        | "result_mismatch"
        | "incident_conflict"
        | "cancellation_conflict"
        | "completed_match_review";
      dispute_resolution_action:
        | "adopt_player_a_report"
        | "adopt_player_b_report"
        | "admin_invalid_no_rating"
        | "mutual_no_rating";
      dispute_status: "open" | "resolved";
      domain_action_status: "in_progress" | "succeeded" | "failed";
      event_visibility: "participants" | "admins";
      incident_status:
        "reported" | "confirmed" | "dismissed" | "responsibility_unknown";
      incident_type:
        | "no_show"
        | "abandonment"
        | "result_nonresponse"
        | "match_completion_failure";
      match_creation_source: "quick_match" | "find_opponent";
      match_event_type:
        | "match_created"
        | "host_assigned"
        | "host_changed"
        | "preset_message"
        | "reporting_started"
        | "match_cancelled"
        | "dispute_opened";
      match_rating_status:
        | "not_applicable"
        | "pending"
        | "applied"
        | "correction_pending"
        | "corrected";
      match_resolution_type:
        | "normal"
        | "forfeit"
        | "admin_result"
        | "mutual_cancel"
        | "nonresponse_no_rating"
        | "mutual_no_rating"
        | "admin_invalid_no_rating"
        | "season_boundary_no_rating";
      match_result_validity: "valid" | "invalidated";
      match_side: "player_a" | "player_b";
      match_status:
        | "matched"
        | "room_setup"
        | "reporting"
        | "disputed"
        | "completed"
        | "cancelled";
      onboarding_status:
        | "not_started"
        | "account_in_progress"
        | "sf6_info_in_progress"
        | "rating_setup_in_progress"
        | "completed";
      placement_status: "not_started" | "preview" | "active" | "completed";
      preset_message_type:
        | "room_created"
        | "joined"
        | "cant_find_room"
        | "please_try_again"
        | "please_wait";
      rating_correction_type: "match_invalidation";
      rating_entry_type:
        | "initial_placement"
        | "match_result"
        | "season_reset"
        | "compensating_correction";
      restriction_status: "warning" | "active" | "expired" | "revoked";
      restriction_type: "matchmaking";
      result_report_status:
        "submitted" | "mismatch_review" | "confirmed" | "superseded";
      result_report_type: "normal" | "forfeit";
      season_record_status: "live" | "finalized";
      season_status: "upcoming" | "active" | "completed";
      sf6_rank:
        | "rookie"
        | "iron"
        | "bronze"
        | "silver"
        | "gold"
        | "platinum"
        | "diamond"
        | "master";
      starting_rating_source: "rank" | "master_rating";
      waiting_mode: "quick_match" | "accepting_challenges";
      waiting_status:
        "active" | "matched" | "cancelled" | "expired" | "restricted";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<
  keyof Database,
  "public"
>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      account_status: [
        "onboarding",
        "active",
        "deletion_pending",
        "anonymized",
      ],
      application_role: ["user", "admin"],
      avatar_source_type: ["default", "oauth", "upload"],
      dispute_entry_reason: [
        "result_mismatch",
        "incident_conflict",
        "cancellation_conflict",
        "completed_match_review",
      ],
      dispute_resolution_action: [
        "adopt_player_a_report",
        "adopt_player_b_report",
        "admin_invalid_no_rating",
        "mutual_no_rating",
      ],
      dispute_status: ["open", "resolved"],
      domain_action_status: ["in_progress", "succeeded", "failed"],
      event_visibility: ["participants", "admins"],
      incident_status: [
        "reported",
        "confirmed",
        "dismissed",
        "responsibility_unknown",
      ],
      incident_type: [
        "no_show",
        "abandonment",
        "result_nonresponse",
        "match_completion_failure",
      ],
      match_creation_source: ["quick_match", "find_opponent"],
      match_event_type: [
        "match_created",
        "host_assigned",
        "host_changed",
        "preset_message",
        "reporting_started",
        "match_cancelled",
        "dispute_opened",
      ],
      match_rating_status: [
        "not_applicable",
        "pending",
        "applied",
        "correction_pending",
        "corrected",
      ],
      match_resolution_type: [
        "normal",
        "forfeit",
        "admin_result",
        "mutual_cancel",
        "nonresponse_no_rating",
        "mutual_no_rating",
        "admin_invalid_no_rating",
        "season_boundary_no_rating",
      ],
      match_result_validity: ["valid", "invalidated"],
      match_side: ["player_a", "player_b"],
      match_status: [
        "matched",
        "room_setup",
        "reporting",
        "disputed",
        "completed",
        "cancelled",
      ],
      onboarding_status: [
        "not_started",
        "account_in_progress",
        "sf6_info_in_progress",
        "rating_setup_in_progress",
        "completed",
      ],
      placement_status: ["not_started", "preview", "active", "completed"],
      preset_message_type: [
        "room_created",
        "joined",
        "cant_find_room",
        "please_try_again",
        "please_wait",
      ],
      rating_correction_type: ["match_invalidation"],
      rating_entry_type: [
        "initial_placement",
        "match_result",
        "season_reset",
        "compensating_correction",
      ],
      restriction_status: ["warning", "active", "expired", "revoked"],
      restriction_type: ["matchmaking"],
      result_report_status: [
        "submitted",
        "mismatch_review",
        "confirmed",
        "superseded",
      ],
      result_report_type: ["normal", "forfeit"],
      season_record_status: ["live", "finalized"],
      season_status: ["upcoming", "active", "completed"],
      sf6_rank: [
        "rookie",
        "iron",
        "bronze",
        "silver",
        "gold",
        "platinum",
        "diamond",
        "master",
      ],
      starting_rating_source: ["rank", "master_rating"],
      waiting_mode: ["quick_match", "accepting_challenges"],
      waiting_status: [
        "active",
        "matched",
        "cancelled",
        "expired",
        "restricted",
      ],
    },
  },
} as const;
