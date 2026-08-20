import "server-only";

import { z } from "zod";

const serverEnvSchema = z.object({
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  SF6_USER_CODE_RECLAIM_PEPPER: z.string().min(16),
  APP_BASE_URL: z.url().default("http://127.0.0.1:3000"),
});

export type ServerEnv = z.infer<typeof serverEnvSchema>;

export function getServerEnv(): ServerEnv {
  const result = serverEnvSchema.safeParse({
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
    SF6_USER_CODE_RECLAIM_PEPPER: process.env.SF6_USER_CODE_RECLAIM_PEPPER,
    APP_BASE_URL: process.env.APP_BASE_URL,
  });

  if (!result.success) {
    throw new Error(
      `Invalid server environment: ${result.error.issues
        .map((issue) => issue.path.join("."))
        .join(", ")}`,
    );
  }

  return result.data;
}
