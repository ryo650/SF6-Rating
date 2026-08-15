import { describe, expect, it } from "vitest";
import { parseSupabasePublicEnv } from "./public";

describe("public environment contract", () => {
  it("accepts a Supabase URL and publishable key", () => {
    expect(
      parseSupabasePublicEnv({
        NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_example",
      }),
    ).toEqual({
      NEXT_PUBLIC_SUPABASE_URL: "https://example.supabase.co",
      NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: "sb_publishable_example",
    });
  });

  it("fails with an actionable message when values are absent", () => {
    expect(() => parseSupabasePublicEnv({})).toThrow(
      /NEXT_PUBLIC_SUPABASE_URL/,
    );
  });
});
