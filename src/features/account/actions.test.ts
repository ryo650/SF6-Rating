import { beforeEach, describe, expect, it, vi } from "vitest";

const { createAdminClient, getVerifiedUser, redirect, rpc } = vi.hoisted(
  () => ({
    createAdminClient: vi.fn(),
    getVerifiedUser: vi.fn(),
    redirect: vi.fn(),
    rpc: vi.fn(),
  }),
);

vi.mock("next/navigation", () => ({ redirect }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
vi.mock("@/features/auth/session", () => ({
  getVerifiedUser,
  hasRecentAuthentication: vi.fn(),
}));
vi.mock("@/features/auth/provider-avatar", () => ({
  fetchProcessedProviderAvatar: vi.fn(),
}));
vi.mock("@/features/avatar/process-avatar", () => ({
  processAvatar: vi.fn(),
  AvatarValidationError: class AvatarValidationError extends Error {
    code: string;

    constructor(code: string) {
      super(code);
      this.code = code;
    }
  },
}));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient }));
vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));
vi.mock("./queries", () => ({ getOnboardingState: vi.fn() }));
vi.mock("./secure-values", () => ({
  digestSf6UserCode: vi.fn(),
  hashActionPayload: vi.fn(() => "request-hash"),
  ratingPreviewToken: vi.fn(() => "preview-token"),
  verifyRatingPreviewToken: vi.fn(() => true),
}));

import { completeOnboardingAction } from "./actions";

function ratingSetupForm() {
  const form = new FormData();
  form.set("locale", "en");
  form.set("characterCode", "ryu");
  form.set("rank", "master");
  form.set("masterRating", "1500");
  form.set("intent", "complete");
  form.set("previewToken", "preview-token");
  form.set("idempotencyKey", "complete-onboarding-test");
  return form;
}

beforeEach(() => {
  vi.clearAllMocks();
  getVerifiedUser.mockResolvedValue({ id: "auth-user-id" });
  createAdminClient.mockReturnValue({ rpc });
});

describe("completeOnboardingAction", () => {
  it("preserves successful completion and the onboarding redirect", async () => {
    rpc
      .mockResolvedValueOnce({
        data: {
          starting_rating: 1850,
          parameter_version: "starting-rating-v2",
        },
        error: null,
      })
      .mockResolvedValueOnce({ data: { completed: true }, error: null });

    await completeOnboardingAction({ status: "idle" }, ratingSetupForm());

    expect(rpc).toHaveBeenNthCalledWith(
      2,
      "phase2_complete_onboarding",
      expect.objectContaining({ requested_actor_auth_user_id: "auth-user-id" }),
    );
    expect(redirect).toHaveBeenCalledWith(
      "/en/settings/profile?onboarding=complete",
    );
  });

  it("returns the localized domain code and emits only sanitized metadata", async () => {
    rpc
      .mockResolvedValueOnce({
        data: {
          starting_rating: 1850,
          parameter_version: "starting-rating-v2",
        },
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: {
          code: "55000",
          message: "active_season_required player@example.test",
          details: "raw payload",
          hint: "secret-token",
        },
      });
    const spy = vi.spyOn(console, "error").mockImplementation(() => undefined);

    const result = await completeOnboardingAction(
      { status: "idle" },
      ratingSetupForm(),
    );

    expect(result).toEqual({
      status: "error",
      message: "active_season_required",
    });
    expect(spy).toHaveBeenCalledWith("[account/action] RPC failed", {
      action: "phase2_complete_onboarding",
      domainError: "active_season_required",
      sqlstate: "55000",
    });
    expect(JSON.stringify(spy.mock.calls)).not.toMatch(
      /player@example\.test|raw payload|secret-token/,
    );
    spy.mockRestore();
  });

  it("does not misclassify an unrelated P0002", async () => {
    rpc
      .mockResolvedValueOnce({
        data: {
          starting_rating: 1850,
          parameter_version: "starting-rating-v2",
        },
        error: null,
      })
      .mockResolvedValueOnce({
        data: null,
        error: { code: "P0002", message: "query returned no rows" },
      });
    const spy = vi.spyOn(console, "error").mockImplementation(() => undefined);

    const result = await completeOnboardingAction(
      { status: "idle" },
      ratingSetupForm(),
    );

    expect(result).toEqual({ status: "error", message: "save_failed" });
    expect(spy).toHaveBeenCalledWith("[account/action] RPC failed", {
      action: "phase2_complete_onboarding",
      domainError: "unclassified",
      sqlstate: "P0002",
    });
    spy.mockRestore();
  });
});
