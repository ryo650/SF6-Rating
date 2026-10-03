import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

import { getAuthEnv } from "./auth";

afterEach(() => vi.unstubAllEnvs());

describe("Auth environment contract", () => {
  it("does not depend on admin or service-role environment values", () => {
    vi.stubEnv("APP_BASE_URL", "https://sf6-rating.example");
    vi.stubEnv("SUPABASE_SERVICE_ROLE_KEY", "");
    vi.stubEnv("SF6_USER_CODE_RECLAIM_PEPPER", "");

    expect(getAuthEnv().APP_BASE_URL).toBe("https://sf6-rating.example");
  });
});
