import { createBrowserClient } from "@supabase/ssr";
import type { Database } from "@/lib/database/types";
import { getSupabasePublicEnv } from "@/lib/env/public";

export function createClient() {
  const env = getSupabasePublicEnv();
  return createBrowserClient<Database>(
    env.NEXT_PUBLIC_SUPABASE_URL,
    env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );
}
