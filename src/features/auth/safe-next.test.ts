import { describe, expect, it } from "vitest";
import { localeFromNextPath, safeNextPath } from "./safe-next";

describe("safeNextPath", () => {
  it("accepts locale-scoped relative application paths", () => {
    expect(safeNextPath("/en/onboarding?step=2")).toBe("/en/onboarding?step=2");
  });

  it.each([
    "https://evil.example/path",
    "//evil.example/path",
    "/unknown/path",
    "javascript:alert(1)",
  ])("rejects unsafe redirect %s", (value) => {
    expect(safeNextPath(value, "/ja/onboarding")).toBe("/ja/onboarding");
  });

  it("preserves a safe locale for callback error routes", () => {
    expect(localeFromNextPath("/en/onboarding")).toBe("en");
    expect(localeFromNextPath("https://evil.example/en")).toBe("ja");
  });
});
