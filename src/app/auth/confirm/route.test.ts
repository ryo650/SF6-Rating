import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

vi.mock("server-only", () => ({}));

const { createClient, getAuthEnv, verifyOtp } = vi.hoisted(() => ({
  createClient: vi.fn(),
  getAuthEnv: vi.fn(),
  verifyOtp: vi.fn(),
}));

vi.mock("@/lib/env/auth", () => ({ getAuthEnv }));
vi.mock("@/lib/supabase/server", () => ({ createClient }));

import { GET } from "./route";

beforeEach(() => {
  vi.restoreAllMocks();
  vi.clearAllMocks();
  getAuthEnv.mockReturnValue({
    APP_BASE_URL: "https://sf6-rating.example",
    NODE_ENV: "production",
    VERCEL_ENV: "preview",
    VERCEL_URL: "deploy-a.vercel.app",
  });
  verifyOtp.mockResolvedValue({ error: null });
  createClient.mockResolvedValue({ auth: { verifyOtp } });
});

describe("GET /auth/confirm", () => {
  it("keeps Email OTP verification and its redirect on the Preview origin", async () => {
    const response = await GET(
      new NextRequest(
        "https://deploy-a.vercel.app/auth/confirm?token_hash=secret-token&type=signup&next=%2Fen%2Fonboarding",
        {
          headers: {
            "x-forwarded-host": "deploy-a.vercel.app",
            "x-forwarded-proto": "https",
          },
        },
      ),
    );

    expect(verifyOtp).toHaveBeenCalledWith({
      token_hash: "secret-token",
      type: "signup",
    });
    expect(response.headers.get("location")).toBe(
      "https://deploy-a.vercel.app/en/onboarding",
    );
    expect(response.headers.get("cache-control")).toBe("private, no-store");
  });

  it("does not verify a token when the request origin is not allowed", async () => {
    const log = vi.spyOn(console, "error").mockImplementation(() => undefined);
    const response = await GET(
      new NextRequest(
        "https://attacker.example/auth/confirm?token_hash=secret-token&type=signup&next=%2Fen%2Fonboarding",
        {
          headers: {
            "x-forwarded-host": "attacker.example",
            "x-forwarded-proto": "https",
          },
        },
      ),
    );

    expect(response.status).toBe(400);
    expect(verifyOtp).not.toHaveBeenCalled();
    expect(JSON.stringify(log.mock.calls)).not.toContain("secret-token");
  });
});
