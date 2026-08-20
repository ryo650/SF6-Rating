import "server-only";

import { createHash, createHmac, timingSafeEqual } from "node:crypto";
import { getServerEnv } from "@/lib/env/server";

function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(",")}]`;

  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value)
      .sort(([left], [right]) => left.localeCompare(right))
      .map(([key, entry]) => `${JSON.stringify(key)}:${stableJson(entry)}`)
      .join(",")}}`;
  }

  return JSON.stringify(value);
}

export function hashActionPayload(value: unknown): string {
  return createHash("sha256").update(stableJson(value)).digest("hex");
}

export function digestSf6UserCode(userCode: string): string {
  return createHmac("sha256", getServerEnv().SF6_USER_CODE_RECLAIM_PEPPER)
    .update(userCode)
    .digest("hex");
}

export function ratingPreviewToken(value: unknown): string {
  return createHmac("sha256", getServerEnv().SF6_USER_CODE_RECLAIM_PEPPER)
    .update("rating-preview-v1:")
    .update(stableJson(value))
    .digest("hex");
}

export function verifyRatingPreviewToken(value: unknown, token: string) {
  if (!/^[0-9a-f]{64}$/.test(token)) return false;
  const expected = Buffer.from(ratingPreviewToken(value), "hex");
  const actual = Buffer.from(token, "hex");
  return timingSafeEqual(expected, actual);
}
