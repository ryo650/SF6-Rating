import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const {
  createClient,
  getAuthEnv,
  redirect,
  signInWithOAuth,
  signUp,
  resend,
  resetPasswordForEmail,
} = vi.hoisted(() => ({
  createClient: vi.fn(),
  getAuthEnv: vi.fn(),
  redirect: vi.fn(),
  signInWithOAuth: vi.fn(),
  signUp: vi.fn(),
  resend: vi.fn(),
  resetPasswordForEmail: vi.fn(),
}));

vi.mock("next/headers", () => ({
  headers: vi.fn(
    async () =>
      new Headers({
        "x-forwarded-host": "deploy-a.vercel.app",
        "x-forwarded-proto": "https",
      }),
  ),
}));
vi.mock("next/navigation", () => ({ redirect }));
vi.mock("@/lib/env/auth", () => ({ getAuthEnv }));
vi.mock("@/lib/supabase/server", () => ({ createClient }));

import {
  requestPasswordResetAction,
  resendVerificationAction,
  signUpAction,
  startOAuthAction,
} from "./actions";

beforeEach(() => {
  vi.clearAllMocks();
  getAuthEnv.mockReturnValue({
    APP_BASE_URL: "https://sf6-rating.example",
    NODE_ENV: "production",
    VERCEL_ENV: "preview",
    VERCEL_URL: "deploy-a.vercel.app",
  });
  signInWithOAuth.mockResolvedValue({
    data: { url: "https://provider.example/authorize" },
    error: null,
  });
  signUp.mockResolvedValue({ error: null });
  resend.mockResolvedValue({ error: null });
  resetPasswordForEmail.mockResolvedValue({ error: null });
  createClient.mockResolvedValue({
    auth: { signInWithOAuth, signUp, resend, resetPasswordForEmail },
  });
});

describe("Auth action callback origins", () => {
  it.each(["google", "discord"] as const)(
    "keeps %s OAuth on the active Preview origin",
    async (provider) => {
      await startOAuthAction("ja", provider);

      expect(signInWithOAuth).toHaveBeenCalledWith({
        provider,
        options: {
          redirectTo:
            "https://deploy-a.vercel.app/auth/callback?next=%2Fja%2Fonboarding",
          skipBrowserRedirect: true,
        },
      });
      expect(redirect).toHaveBeenCalledWith(
        "https://provider.example/authorize",
      );
    },
  );

  it("preserves the Email verification callback", async () => {
    const form = new FormData();
    form.set("locale", "en");
    form.set("email", "player@example.test");
    form.set("password", "password123");

    await signUpAction({ status: "idle" }, form);

    expect(signUp).toHaveBeenCalledWith({
      email: "player@example.test",
      password: "password123",
      options: {
        emailRedirectTo:
          "https://deploy-a.vercel.app/auth/callback?next=%2Fen%2Fonboarding",
      },
    });
  });

  it("preserves resend and password recovery destinations", async () => {
    const form = new FormData();
    form.set("locale", "en");
    form.set("email", "player@example.test");

    await resendVerificationAction({ status: "idle" }, form);
    await requestPasswordResetAction({ status: "idle" }, form);

    expect(resend).toHaveBeenCalledWith({
      type: "signup",
      email: "player@example.test",
      options: {
        emailRedirectTo:
          "https://deploy-a.vercel.app/auth/callback?next=%2Fen%2Fonboarding",
      },
    });
    expect(resetPasswordForEmail).toHaveBeenCalledWith("player@example.test", {
      redirectTo:
        "https://deploy-a.vercel.app/auth/callback?next=%2Fen%2Fupdate-password",
    });
  });
});
