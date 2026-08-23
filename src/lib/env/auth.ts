import "server-only";

import { z } from "zod";

const authEnvSchema = z.object({
  APP_BASE_URL: z.url().default("http://127.0.0.1:3000"),
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  VERCEL_ENV: z.enum(["development", "preview", "production"]).optional(),
  VERCEL_URL: z.string().min(1).optional(),
  VERCEL_BRANCH_URL: z.string().min(1).optional(),
});

export type AuthEnv = z.infer<typeof authEnvSchema>;

export function getAuthEnv(): AuthEnv {
  const result = authEnvSchema.safeParse({
    APP_BASE_URL: process.env.APP_BASE_URL,
    NODE_ENV: process.env.NODE_ENV,
    VERCEL_ENV: process.env.VERCEL_ENV,
    VERCEL_URL: process.env.VERCEL_URL,
    VERCEL_BRANCH_URL: process.env.VERCEL_BRANCH_URL,
  });

  if (!result.success) {
    throw new Error(
      `Invalid Auth environment: ${result.error.issues
        .map((issue) => issue.path.join("."))
        .join(", ")}`,
    );
  }

  return result.data;
}
