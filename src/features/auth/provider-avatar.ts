import "server-only";

import type { User } from "@supabase/supabase-js";
import {
  MAX_AVATAR_BYTES,
  processAvatar,
} from "@/features/avatar/process-avatar";
import { providerProfileCandidate } from "./provider-profile";

export async function fetchProcessedProviderAvatar(user: User) {
  const candidate = providerProfileCandidate(user);
  if (!candidate?.avatarUrl) return null;

  const response = await fetch(candidate.avatarUrl, {
    cache: "no-store",
    redirect: "manual",
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok || response.type === "opaqueredirect") return null;

  const declaredLength = Number(response.headers.get("content-length") ?? 0);
  if (declaredLength > MAX_AVATAR_BYTES) return null;

  if (!response.body) return null;
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let byteLength = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    byteLength += value.byteLength;
    if (byteLength > MAX_AVATAR_BYTES) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }

  const input = new Uint8Array(byteLength);
  let offset = 0;
  for (const chunk of chunks) {
    input.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return processAvatar(input.buffer);
}
