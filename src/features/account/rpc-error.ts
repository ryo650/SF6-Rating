import type { ActionState } from "./action-state";

type RpcError = {
  code?: unknown;
  message?: unknown;
};

const knownDomainErrors = [
  "username_reserved",
  "username_cooldown",
  "sf6_user_code_reserved",
  "sf6_user_code_cooldown",
  "sf6_identity_locked_by_active_match",
  "rate_limit_exceeded",
  "email_verification_required",
  "deletion_blocked",
  "avatar_cleanup_required",
  "active_season_required",
] as const;

export function classifyRpcFailure(error: RpcError | null) {
  const message = typeof error?.message === "string" ? error.message : "";
  const known = knownDomainErrors.find((code) => message.includes(code));

  if (known) return known;
  if (error?.code === "23505") return "value_already_in_use";
  return "save_failed";
}

export function rpcFailure(error: RpcError | null): ActionState {
  return { status: "error", message: classifyRpcFailure(error) };
}

export function logSanitizedRpcFailure(
  action: "phase2_complete_onboarding",
  error: RpcError,
) {
  const classified = classifyRpcFailure(error);
  const sqlstate =
    typeof error.code === "string" && /^[A-Z0-9]{5}$/.test(error.code)
      ? error.code
      : undefined;

  console.error("[account/action] RPC failed", {
    action,
    domainError: classified === "save_failed" ? "unclassified" : classified,
    sqlstate,
  });
}
