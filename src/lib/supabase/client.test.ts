import { beforeEach, describe, expect, it, vi } from "vitest";

const { createBrowserClient } = vi.hoisted(() => ({
  createBrowserClient: vi.fn(() => ({ kind: "browser-client" })),
}));

vi.mock("@supabase/ssr", () => ({ createBrowserClient }));

describe("Supabase browser client", () => {
  beforeEach(() => {
    vi.resetModules();
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", "https://example.supabase.co");
    vi.stubEnv(
      "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
      "sb_publishable_example",
    );
  });

  it("initializes the SDK with public configuration only", async () => {
    const { createClient } = await import("./client");
    expect(createClient()).toEqual({ kind: "browser-client" });
    expect(createBrowserClient).toHaveBeenCalledWith(
      "https://example.supabase.co",
      "sb_publishable_example",
    );
  });
});
