import "server-only";

import { createHash, createHmac } from "node:crypto";
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
