import { describe, expect, it } from "vitest";
import type { AuthEnv } from "@/lib/env/auth";
import { buildAuthCallbackUrl, resolveAuthOrigin } from "./origin";

const baseEnv: AuthEnv = {
  APP_BASE_URL: "https://sf6-rating.example",
  NODE_ENV: "production",
};

function requestHeaders(host: string, protocol = "https") {
  return new Headers({
    "x-forwarded-host": host,
    "x-forwarded-proto": protocol,
  });
}

describe("resolveAuthOrigin", () => {
  it("uses only APP_BASE_URL for a matching production request", () => {
    expect(
      resolveAuthOrigin({
        env: baseEnv,
        headers: requestHeaders("sf6-rating.example"),
        requestUrl: "https://internal.invalid/auth/callback",
      }),
    ).toBe("https://sf6-rating.example");
  });

  it("fails closed when a production request host is not canonical", () => {
    expect(() =>
      resolveAuthOrigin({
        env: baseEnv,
        headers: requestHeaders("attacker.example"),
      }),
    ).toThrow("production_origin_mismatch");
  });

  it.each(["deploy-a.vercel.app", "phase-2-account-onboarding.vercel.app"])(
    "accepts an explicitly configured Preview host: %s",
    (host) => {
      expect(
        resolveAuthOrigin({
          env: {
            ...baseEnv,
            VERCEL_ENV: "preview",
            VERCEL_URL: "deploy-a.vercel.app",
            VERCEL_BRANCH_URL: "phase-2-account-onboarding.vercel.app",
          },
          headers: requestHeaders(host),
        }),
      ).toBe(`https://${host}`);
    },
  );

  it("supports a changed deployment URL when VERCEL_URL changes", () => {
    expect(
      resolveAuthOrigin({
        env: {
          ...baseEnv,
          VERCEL_ENV: "preview",
          VERCEL_URL: "deploy-b.vercel.app",
        },
        headers: requestHeaders("deploy-b.vercel.app"),
      }),
    ).toBe("https://deploy-b.vercel.app");
  });

  it.each([
    ["arbitrary Vercel host", requestHeaders("not-allowed.vercel.app")],
    ["non-HTTPS Preview", requestHeaders("deploy-a.vercel.app", "http")],
    [
      "multiple forwarded hosts",
      requestHeaders("deploy-a.vercel.app, attacker.example"),
    ],
    ["userinfo", requestHeaders("user@deploy-a.vercel.app")],
    ["unexpected port", requestHeaders("deploy-a.vercel.app:444")],
  ])("rejects %s", (_label, headers) => {
    expect(() =>
      resolveAuthOrigin({
        env: {
          ...baseEnv,
          VERCEL_ENV: "preview",
          VERCEL_URL: "deploy-a.vercel.app",
        },
        headers,
        requestUrl: "https://deploy-a.vercel.app/auth/callback",
      }),
    ).toThrow();
  });

  it("does not trust the request URL when forwarded host is forged", () => {
    expect(() =>
      resolveAuthOrigin({
        env: {
          ...baseEnv,
          VERCEL_ENV: "preview",
          VERCEL_URL: "deploy-a.vercel.app",
        },
        headers: requestHeaders("attacker.example"),
        requestUrl: "https://deploy-a.vercel.app/auth/callback",
      }),
    ).toThrow("preview_origin_not_allowed");
  });

  it.each(["localhost:3000", "127.0.0.1:3000"])(
    "allows a loopback Development origin: %s",
    (host) => {
      expect(
        resolveAuthOrigin({
          env: { ...baseEnv, NODE_ENV: "development" },
          headers: new Headers({ host }),
        }),
      ).toBe(`http://${host}`);
    },
  );

  it("rejects an external Development host", () => {
    expect(() =>
      resolveAuthOrigin({
        env: { ...baseEnv, NODE_ENV: "development" },
        headers: new Headers({ host: "external.example" }),
      }),
    ).toThrow("development_origin_not_loopback");
  });
});

describe("buildAuthCallbackUrl", () => {
  it("keeps the PKCE callback and next path on the same Preview host", () => {
    expect(
      buildAuthCallbackUrl(
        {
          env: {
            ...baseEnv,
            VERCEL_ENV: "preview",
            VERCEL_URL: "deploy-a.vercel.app",
          },
          headers: requestHeaders("deploy-a.vercel.app"),
        },
        "/ja/onboarding",
      ),
    ).toBe("https://deploy-a.vercel.app/auth/callback?next=%2Fja%2Fonboarding");
  });
});
