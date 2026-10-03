import { describe, expect, it } from "vitest";
import {
  providerProfileCandidate,
  safeProviderAvatarUrl,
} from "./provider-profile";

describe("providerProfileCandidate", () => {
  it("uses provider-owned Google identity data for initial candidates", () => {
    const candidate = providerProfileCandidate({
      identities: [
        {
          id: "provider-id",
          user_id: "user-id",
          identity_id: "identity-id",
          provider: "google",
          identity_data: {
            full_name: "ＳＦ プレイヤー",
            picture: "https://lh3.googleusercontent.com/a/avatar",
          },
          created_at: "2026-08-17T00:00:00Z",
          updated_at: "2026-08-17T00:00:00Z",
          last_sign_in_at: "2026-08-17T00:00:00Z",
        },
      ],
    });

    expect(candidate).toEqual({
      provider: "google",
      displayName: "ＳＦ プレイヤー",
      username: "SFプレイヤー",
      avatarUrl: "https://lh3.googleusercontent.com/a/avatar",
    });
  });

  it("accepts only HTTPS URLs on the selected provider allowlist", () => {
    expect(
      safeProviderAvatarUrl(
        "discord",
        "https://cdn.discordapp.com/avatars/1/image.png",
      ),
    ).toBe("https://cdn.discordapp.com/avatars/1/image.png");
    expect(
      safeProviderAvatarUrl(
        "discord",
        "https://cdn.discordapp.com.evil.test/avatar.png",
      ),
    ).toBeNull();
    expect(
      safeProviderAvatarUrl("google", "https://cdn.discordapp.com/avatar.png"),
    ).toBeNull();
    expect(
      safeProviderAvatarUrl(
        "google",
        "http://lh3.googleusercontent.com/avatar.png",
      ),
    ).toBeNull();
  });

  it("does not inspect mutable user_metadata", () => {
    expect(providerProfileCandidate({ identities: [] })).toBeNull();
  });
});
