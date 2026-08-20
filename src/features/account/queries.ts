import "server-only";

import { z } from "zod";
import type { Locale } from "@/i18n/config";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const onboardingStateSchema = z.object({
  profile_id: z.uuid(),
  account_status: z.enum([
    "onboarding",
    "active",
    "deletion_pending",
    "anonymized",
  ]),
  onboarding_status: z.enum([
    "not_started",
    "account_in_progress",
    "sf6_info_in_progress",
    "rating_setup_in_progress",
    "completed",
  ]),
  current_step: z.number().int().min(1).max(3),
  username: z.string().nullable(),
  avatar_url: z.string().nullable(),
  avatar_source: z.enum(["default", "oauth", "upload"]),
  country_code: z.string().nullable(),
  sf6_player_name: z.string().nullable(),
  sf6_user_code: z.string().nullable(),
  broad_region_code: z.string().nullable(),
  main_character_code: z.string().nullable(),
  sf6_rank: z
    .enum([
      "rookie",
      "iron",
      "bronze",
      "silver",
      "gold",
      "platinum",
      "diamond",
      "master",
    ])
    .nullable(),
  sf6_rank_tier: z.number().int().nullable(),
  master_rating: z.number().int().nullable(),
  current_rating: z.number().int().nullable(),
  placement_status: z.enum(["not_started", "preview", "active", "completed"]),
  username_changed_at: z.string().nullable(),
  sf6_user_code_changed_at: z.string().nullable(),
  deletion_requested_at: z.string().nullable(),
  deletion_blocking_reasons: z.array(
    z.enum(["active_match", "unresolved_result", "open_dispute"]),
  ),
});

export type OnboardingState = z.infer<typeof onboardingStateSchema>;

export async function getOnboardingState(authUserId: string) {
  const admin = createAdminClient();
  const { data, error } = await admin.rpc("phase2_onboarding_state", {
    requested_actor_auth_user_id: authUserId,
  });
  if (error) throw new Error("Unable to load account state");
  return onboardingStateSchema.parse(data);
}

export async function getAccountMasters(locale: Locale) {
  const supabase = await createClient();
  const [countries, regions, characters] = await Promise.all([
    supabase.from("countries").select("code").order("code"),
    supabase
      .from("broad_regions")
      .select("code,country_code,name_ja,name_en,sort_order")
      .order("country_code")
      .order("sort_order"),
    supabase
      .from("sf6_characters")
      .select("code,name,sort_order")
      .order("sort_order"),
  ]);

  if (countries.error || regions.error || characters.error) {
    throw new Error("Unable to load account masters");
  }

  const countryNames = new Intl.DisplayNames([locale], { type: "region" });

  return {
    countries: countries.data.map(({ code }) => ({
      code,
      label: countryNames.of(code) ?? code,
    })),
    regions: regions.data,
    characters: characters.data,
  };
}
