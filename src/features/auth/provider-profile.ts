import type { User } from "@supabase/supabase-js";
import { normalizeUsername } from "@/features/account/normalization";

const providerAvatarHosts = new Map([
  ["google", ["googleusercontent.com"]],
  ["discord", ["cdn.discordapp.com", "media.discordapp.net"]],
]);

export type ProviderProfileCandidate = {
  provider: "google" | "discord";
  displayName: string | null;
  username: string | null;
  avatarUrl: string | null;
};

function nonEmptyString(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : null;
}

function allowedHost(hostname: string, suffixes: string[]) {
  return suffixes.some(
    (suffix) => hostname === suffix || hostname.endsWith(`.${suffix}`),
  );
}

export function safeProviderAvatarUrl(
  provider: string,
  input: unknown,
): string | null {
  const suffixes = providerAvatarHosts.get(provider);
  if (!suffixes || typeof input !== "string") return null;

  try {
    const url = new URL(input);
    if (
      url.protocol !== "https:" ||
      url.username ||
      url.password ||
      (url.port && url.port !== "443") ||
      !allowedHost(url.hostname.toLowerCase(), suffixes)
    ) {
      return null;
    }
    return url.toString();
  } catch {
    return null;
  }
}

function usernameCandidate(displayName: string | null) {
  if (!displayName) return null;
  const withoutSpaces = displayName.replace(/\s+/gu, "");
  try {
    return normalizeUsername(withoutSpaces).display;
  } catch {
    return null;
  }
}

export function providerProfileCandidate(
  user: Pick<User, "identities">,
): ProviderProfileCandidate | null {
  for (const identity of user.identities ?? []) {
    if (identity.provider !== "google" && identity.provider !== "discord") {
      continue;
    }

    const data = identity.identity_data ?? {};
    const displayName =
      nonEmptyString(data.name) ??
      nonEmptyString(data.full_name) ??
      nonEmptyString(data.global_name) ??
      nonEmptyString(data.user_name) ??
      nonEmptyString(data.preferred_username);
    const avatarInput = data.avatar_url ?? data.picture;

    return {
      provider: identity.provider,
      displayName,
      username: usernameCandidate(displayName),
      avatarUrl: safeProviderAvatarUrl(identity.provider, avatarInput),
    };
  }

  return null;
}
