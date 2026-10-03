import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

vi.mock("server-only", () => ({}));

const { createClient, exchangeCodeForSession, getAuthEnv } = vi.hoisted(() => ({
  createClient: vi.fn(),
  exchangeCodeForSession: vi.fn(),
  getAuthEnv: vi.fn(),
}));

vi.mock("@/lib/env/auth", () => ({ getAuthEnv }));
vi.mock("@/lib/supabase/server", () => ({ createClient }));

import { GET } from "./route";

function callbackRequest(path: string) {
  return new NextRequest(`http://127.0.0.1:3000${path}`, {
    headers: {
      "x-forwarded-host": "127.0.0.1:3000",
      "x-forwarded-proto": "http",
    },
  });
}

beforeEach(() => {
  vi.restoreAllMocks();
  vi.clearAllMocks();
  getAuthEnv.mockReturnValue({
    APP_BASE_URL: "http://127.0.0.1:3000",
    NODE_ENV: "development",
  });
  exchangeCodeForSession.mockResolvedValue({ error: null });
  createClient.mockResolvedValue({ auth: { exchangeCodeForSession } });
});

describe("GET /auth/callback", () => {
  it("exchanges the PKCE code and redirects on the same origin", async () => {
    const response = await GET(
      callbackRequest(
        "/auth/callback?code=secret-code&next=%2Fja%2Fonboarding",
      ),
    );

    expect(exchangeCodeForSession).toHaveBeenCalledWith("secret-code");
    expect(response.headers.get("location")).toBe(
      "http://127.0.0.1:3000/ja/onboarding",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
  });

  it("redirects to the localized error page for an exchange error", async () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    exchangeCodeForSession.mockResolvedValue({
      error: {
        name: "AuthApiError",
        code: "bad_code",
        status: 400,
        reason: "secret-code",
      },
    });

    const response = await GET(
      callbackRequest(
        "/auth/callback?code=secret-code&next=%2Fen%2Fonboarding",
      ),
    );

    expect(response.headers.get("location")).toBe(
      "http://127.0.0.1:3000/en/auth-error",
    );
    expect(JSON.stringify(log.mock.calls)).not.toContain("secret-code");
  });

  it("redirects instead of returning a white-screen 500 when the SDK throws", async () => {
    vi.spyOn(console, "error").mockImplementation(() => undefined);
    exchangeCodeForSession.mockRejectedValue(new Error("network unavailable"));

    const response = await GET(
      callbackRequest(
        "/auth/callback?code=secret-code&next=%2Fja%2Fonboarding",
      ),
    );

    expect(response.headers.get("location")).toBe(
      "http://127.0.0.1:3000/ja/auth-error",
    );
  });

  it("returns a no-store fallback when no safe redirect origin exists", async () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    getAuthEnv.mockReturnValue({
      APP_BASE_URL: "https://sf6-rating.example",
      NODE_ENV: "production",
      VERCEL_ENV: "preview",
      VERCEL_URL: "allowed.vercel.app",
    });

    const response = await GET(
      new NextRequest(
        "https://attacker.example/auth/callback?code=secret-code&next=%2Fja%2Fonboarding",
        {
          headers: {
            "x-forwarded-host": "attacker.example",
            "x-forwarded-proto": "https",
          },
        },
      ),
    );

    expect(response.status).toBe(400);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    expect(await response.text()).toContain("could not be completed safely");
    expect(JSON.stringify(log.mock.calls)).not.toContain("secret-code");
    expect(exchangeCodeForSession).not.toHaveBeenCalled();
  });
});
