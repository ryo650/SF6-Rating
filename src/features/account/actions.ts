"use server";

import { randomUUID } from "node:crypto";
import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import type { DatabaseEnum } from "@/lib/database/types";
import type { ActionState } from "./action-state";
import {
  AccountValidationError,
  normalizeSf6PlayerName,
  normalizeSf6UserCode,
  normalizeUsername,
  safeOauthAvatarUrl,
} from "./normalization";
import { digestSf6UserCode, hashActionPayload } from "./secure-values";
import { getOnboardingState } from "./queries";
import {
  getVerifiedUser,
  hasRecentAuthentication,
} from "@/features/auth/session";
import {
  processAvatar,
  AvatarValidationError,
} from "@/features/avatar/process-avatar";
import { isLocale } from "@/i18n/config";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

type Sf6Rank = DatabaseEnum<"sf6_rank">;
const ranks = new Set<Sf6Rank>([
  "rookie",
  "iron",
  "bronze",
  "silver",
  "gold",
  "platinum",
  "diamond",
  "master",
]);

function localeFromForm(formData: FormData) {
  const candidate = String(formData.get("locale") ?? "");
  return isLocale(candidate) ? candidate : "ja";
}

function idempotencyKey(formData: FormData) {
  const candidate = String(formData.get("idempotencyKey") ?? "");
  return candidate.length >= 8 && candidate.length <= 200
    ? candidate
    : randomUUID();
}

function rpcFailure(
  error: { code?: string; message: string } | null,
): ActionState {
  const message = error?.message ?? "save_failed";
  const known = [
    "username_reserved",
    "username_cooldown",
    "sf6_user_code_reserved",
    "sf6_user_code_cooldown",
    "sf6_identity_locked_by_active_match",
    "rate_limit_exceeded",
    "email_verification_required",
    "deletion_blocked",
    "avatar_cleanup_required",
  ].find((code) => message.includes(code));

  if (known) return { status: "error", message: known };
  if (error?.code === "23505") {
    return { status: "error", message: "value_already_in_use" };
  }
  return { status: "error", message: "save_failed" };
}

function parseRatingSetup(formData: FormData) {
  const characterCode = String(formData.get("characterCode") ?? "");
  const rankCandidate = String(formData.get("rank") ?? "") as Sf6Rank;
  if (!ranks.has(rankCandidate)) {
    throw new AccountValidationError("invalid_rank");
  }

  const rawTier = String(formData.get("rankTier") ?? "");
  const rawMr = String(formData.get("masterRating") ?? "");
  const rankTier = rankCandidate === "master" ? null : Number(rawTier);
  const masterRating = rankCandidate === "master" ? Number(rawMr) : null;

  if (!characterCode) throw new AccountValidationError("invalid_character");
  if (
    (rankCandidate !== "master" &&
      (!Number.isInteger(rankTier) || rankTier! < 1 || rankTier! > 5)) ||
    (rankCandidate === "master" &&
      (!Number.isInteger(masterRating) ||
        masterRating! < 1 ||
        masterRating! > 5000))
  ) {
    throw new AccountValidationError("invalid_rating_setup");
  }

  return { characterCode, rank: rankCandidate, rankTier, masterRating };
}

async function uploadProcessedAvatar(
  authUserId: string,
  file: File,
  actionKey: string,
) {
  const state = await getOnboardingState(authUserId);
  const processed = await processAvatar(await file.arrayBuffer());
  const storagePath = `${state.profile_id}/${randomUUID()}.webp`;
  const supabase = await createClient();
  const upload = await supabase.storage
    .from("avatars")
    .upload(storagePath, processed.buffer, {
      contentType: "image/webp",
      upsert: false,
    });
  if (upload.error) throw new AvatarValidationError("avatar_upload");

  const publicUrl = supabase.storage.from("avatars").getPublicUrl(storagePath)
    .data.publicUrl;
  const payload = {
    storagePath,
    publicUrl,
    byteSize: processed.byteSize,
    width: processed.width,
    height: processed.height,
    sha256: processed.sha256,
  };
  const admin = createAdminClient();
  const attached = await admin.rpc("phase2_attach_avatar", {
    requested_actor_auth_user_id: authUserId,
    requested_storage_path: storagePath,
    requested_public_url: publicUrl,
    requested_byte_size: processed.byteSize,
    requested_width: processed.width,
    requested_height: processed.height,
    requested_content_sha256: processed.sha256,
    requested_idempotency_key: `${actionKey}:avatar`,
    requested_hash: hashActionPayload(payload),
  });

  if (attached.error) {
    await supabase.storage.from("avatars").remove([storagePath]);
    throw new AvatarValidationError("avatar_attach");
  }

  const cleanup = await admin.rpc("phase2_avatar_cleanup_paths", {
    requested_actor_auth_user_id: authUserId,
  });
  const stalePaths = (cleanup.data ?? []).filter(
    (path) => path !== storagePath,
  );
  if (stalePaths.length > 0) {
    await supabase.storage.from("avatars").remove(stalePaths);
  }
}

export async function saveAccountStepAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  try {
    const user = await getVerifiedUser();
    const username = normalizeUsername(String(formData.get("username") ?? ""));
    const actionKey = idempotencyKey(formData);
    const oauthAvatar = safeOauthAvatarUrl(
      user.user_metadata.avatar_url ?? user.user_metadata.picture,
    );
    const payload = { ...username, oauthAvatar };
    const admin = createAdminClient();
    const saved = await admin.rpc("phase2_save_account_step", {
      requested_actor_auth_user_id: user.id,
      requested_username: username.display,
      requested_username_normalized: username.normalized,
      requested_oauth_avatar_url: oauthAvatar as string,
      requested_idempotency_key: actionKey,
      requested_hash: hashActionPayload(payload),
    });
    if (saved.error) return rpcFailure(saved.error);

    const avatar = formData.get("avatar");
    if (avatar instanceof File && avatar.size > 0) {
      await uploadProcessedAvatar(user.id, avatar, actionKey);
    }
  } catch (error) {
    if (
      error instanceof AccountValidationError ||
      error instanceof AvatarValidationError
    ) {
      return { status: "error", message: error.code };
    }
    return { status: "error", message: "save_failed" };
  }
  redirect(`/${locale}/onboarding/sf6`);
}

export async function saveSf6InfoStepAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  try {
    const user = await getVerifiedUser();
    const playerName = normalizeSf6PlayerName(
      String(formData.get("playerName") ?? ""),
    );
    const userCode = normalizeSf6UserCode(
      String(formData.get("userCode") ?? ""),
    );
    const countryCode = String(formData.get("countryCode") ?? "");
    const broadRegionCode = String(formData.get("broadRegionCode") ?? "");
    const payload = { playerName, userCode, countryCode, broadRegionCode };
    const admin = createAdminClient();
    const saved = await admin.rpc("phase2_save_sf6_info_step", {
      requested_actor_auth_user_id: user.id,
      requested_player_name: playerName,
      requested_user_code: userCode,
      requested_user_code_digest: digestSf6UserCode(userCode),
      requested_country_code: countryCode,
      requested_broad_region_code: broadRegionCode,
      requested_idempotency_key: idempotencyKey(formData),
      requested_hash: hashActionPayload(payload),
    });
    if (saved.error) return rpcFailure(saved.error);
  } catch (error) {
    if (error instanceof AccountValidationError) {
      return { status: "error", message: error.code };
    }
    return { status: "error", message: "save_failed" };
  }
  redirect(`/${locale}/onboarding/rating`);
}

export async function completeOnboardingAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  try {
    const user = await getVerifiedUser();
    const setup = parseRatingSetup(formData);
    const admin = createAdminClient();
    if (formData.get("intent") === "preview") {
      const preview = await admin.rpc("phase2_preview_starting_rating", {
        requested_actor_auth_user_id: user.id,
        requested_character_code: setup.characterCode,
        requested_rank: setup.rank,
        requested_rank_tier: setup.rankTier as number,
        requested_master_rating: setup.masterRating as number,
      });
      if (preview.error) return rpcFailure(preview.error);
      const result =
        preview.data &&
        typeof preview.data === "object" &&
        !Array.isArray(preview.data)
          ? {
              starting_rating:
                typeof preview.data.starting_rating === "number"
                  ? preview.data.starting_rating
                  : 0,
              parameter_version:
                typeof preview.data.parameter_version === "string"
                  ? preview.data.parameter_version
                  : "",
            }
          : undefined;
      return { status: "success", message: "rating_preview", result };
    }
    const completed = await admin.rpc("phase2_complete_onboarding", {
      requested_actor_auth_user_id: user.id,
      requested_character_code: setup.characterCode,
      requested_rank: setup.rank,
      requested_rank_tier: setup.rankTier as number,
      requested_master_rating: setup.masterRating as number,
      requested_idempotency_key: idempotencyKey(formData),
      requested_hash: hashActionPayload(setup),
    });
    if (completed.error) return rpcFailure(completed.error);
  } catch (error) {
    if (error instanceof AccountValidationError) {
      return { status: "error", message: error.code };
    }
    return { status: "error", message: "save_failed" };
  }
  redirect(`/${locale}/settings/profile?onboarding=complete`);
}

export async function updateUsernameAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    const user = await getVerifiedUser();
    const username = normalizeUsername(String(formData.get("username") ?? ""));
    const admin = createAdminClient();
    const result = await admin.rpc("phase2_update_username", {
      requested_actor_auth_user_id: user.id,
      requested_username: username.display,
      requested_username_normalized: username.normalized,
      requested_idempotency_key: idempotencyKey(formData),
      requested_hash: hashActionPayload(username),
    });
    if (result.error) return rpcFailure(result.error);
    revalidatePath(`/${localeFromForm(formData)}/settings/profile`);
    return { status: "success", message: "saved" };
  } catch (error) {
    if (error instanceof AccountValidationError) {
      return { status: "error", message: error.code };
    }
    return { status: "error", message: "save_failed" };
  }
}

export async function updateSf6IdentityAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    const user = await getVerifiedUser();
    const playerName = normalizeSf6PlayerName(
      String(formData.get("playerName") ?? ""),
    );
    const userCode = normalizeSf6UserCode(
      String(formData.get("userCode") ?? ""),
    );
    const payload = { playerName, userCode };
    const admin = createAdminClient();
    const result = await admin.rpc("phase2_update_sf6_identity", {
      requested_actor_auth_user_id: user.id,
      requested_player_name: playerName,
      requested_user_code: userCode,
      requested_user_code_digest: digestSf6UserCode(userCode),
      requested_idempotency_key: idempotencyKey(formData),
      requested_hash: hashActionPayload(payload),
    });
    if (result.error) return rpcFailure(result.error);
    revalidatePath(`/${localeFromForm(formData)}/settings/profile`);
    return { status: "success", message: "saved" };
  } catch (error) {
    if (error instanceof AccountValidationError)
      return { status: "error", message: error.code };
    return { status: "error", message: "save_failed" };
  }
}

export async function updateProfileDetailsAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    const user = await getVerifiedUser();
    const setup = parseRatingSetup(formData);
    const countryCode = String(formData.get("countryCode") ?? "");
    const broadRegionCode = String(formData.get("broadRegionCode") ?? "");
    const payload = { ...setup, countryCode, broadRegionCode };
    const admin = createAdminClient();
    const result = await admin.rpc("phase2_update_profile_details", {
      requested_actor_auth_user_id: user.id,
      requested_country_code: countryCode,
      requested_broad_region_code: broadRegionCode,
      requested_character_code: setup.characterCode,
      requested_rank: setup.rank,
      requested_rank_tier: setup.rankTier as number,
      requested_master_rating: setup.masterRating as number,
      requested_idempotency_key: idempotencyKey(formData),
      requested_hash: hashActionPayload(payload),
    });
    if (result.error) return rpcFailure(result.error);
    revalidatePath(`/${localeFromForm(formData)}/settings/profile`);
    return { status: "success", message: "saved_no_rating_recalculation" };
  } catch (error) {
    if (error instanceof AccountValidationError)
      return { status: "error", message: error.code };
    return { status: "error", message: "save_failed" };
  }
}

export async function replaceAvatarAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    const user = await getVerifiedUser();
    const avatar = formData.get("avatar");
    if (!(avatar instanceof File) || avatar.size < 1) {
      return { status: "error", message: "avatar_required" };
    }
    await uploadProcessedAvatar(user.id, avatar, idempotencyKey(formData));
    revalidatePath(`/${localeFromForm(formData)}/settings/profile`);
    return { status: "success", message: "saved" };
  } catch (error) {
    if (error instanceof AvatarValidationError)
      return { status: "error", message: error.code };
    return { status: "error", message: "save_failed" };
  }
}

export async function deleteAvatarAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  try {
    const user = await getVerifiedUser();
    const actionKey = idempotencyKey(formData);
    const admin = createAdminClient();
    const detached = await admin.rpc("phase2_detach_avatar", {
      requested_actor_auth_user_id: user.id,
      requested_idempotency_key: actionKey,
      requested_hash: hashActionPayload({ action: "detach-avatar" }),
    });
    if (detached.error) return rpcFailure(detached.error);
    const path =
      detached.data &&
      typeof detached.data === "object" &&
      !Array.isArray(detached.data)
        ? detached.data.storage_path
        : null;
    if (typeof path === "string") {
      const supabase = await createClient();
      await supabase.storage.from("avatars").remove([path]);
    }
    revalidatePath(`/${localeFromForm(formData)}/settings/profile`);
    return { status: "success", message: "saved" };
  } catch {
    return { status: "error", message: "save_failed" };
  }
}

export async function requestAccountDeletionAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  try {
    if (formData.get("confirmed") !== "on") {
      return { status: "error", message: "deletion_confirmation_required" };
    }
    const user = await getVerifiedUser();
    if (!hasRecentAuthentication(user)) {
      return { status: "error", message: "reauthentication_required" };
    }

    const admin = createAdminClient();
    const actionKey = idempotencyKey(formData);
    const requested = await admin.rpc("phase2_request_account_deletion", {
      requested_actor_auth_user_id: user.id,
      requested_idempotency_key: actionKey,
      requested_hash: hashActionPayload({ action: "request-deletion" }),
    });
    if (requested.error) return rpcFailure(requested.error);

    const response = requested.data;
    const ready =
      response && typeof response === "object" && !Array.isArray(response)
        ? response.ready_to_finalize === true
        : false;
    if (!ready) {
      return { status: "success", message: "deletion_pending_blocked" };
    }

    const state = await getOnboardingState(user.id);
    const pathsResult = await admin.rpc("phase2_detach_avatars_for_deletion", {
      requested_actor_auth_user_id: user.id,
    });
    if (pathsResult.error) return rpcFailure(pathsResult.error);
    if ((pathsResult.data ?? []).length > 0) {
      const supabase = await createClient();
      const removed = await supabase.storage
        .from("avatars")
        .remove(pathsResult.data ?? []);
      if (removed.error)
        return { status: "error", message: "avatar_cleanup_failed" };
    }

    const digest = state.sf6_user_code
      ? digestSf6UserCode(state.sf6_user_code)
      : "";
    const prepared = await admin.rpc("phase2_prepare_account_anonymization", {
      requested_actor_auth_user_id: user.id,
      requested_user_code_digest: digest,
      requested_idempotency_key: `${actionKey}:anonymize`,
      requested_hash: hashActionPayload({ action: "anonymize", digest }),
    });
    if (prepared.error) return rpcFailure(prepared.error);

    const preparedData = prepared.data;
    const jobId =
      preparedData &&
      typeof preparedData === "object" &&
      !Array.isArray(preparedData)
        ? preparedData.job_id
        : null;
    if (typeof jobId !== "string")
      return { status: "error", message: "deletion_retry_required" };

    const deleted = await admin.auth.admin.deleteUser(user.id);
    if (deleted.error) {
      await admin.rpc("phase2_mark_auth_deletion_failed", {
        requested_job_id: jobId,
        requested_error_code: deleted.error.code ?? "auth_delete_failed",
      });
      return { status: "error", message: "deletion_retry_required" };
    }

    await admin.rpc("phase2_mark_auth_deletion_complete", {
      requested_job_id: jobId,
    });
    const supabase = await createClient();
    await supabase.auth.signOut({ scope: "local" });
  } catch {
    return { status: "error", message: "deletion_failed" };
  }
  redirect(`/${locale}?account=deleted`);
}
