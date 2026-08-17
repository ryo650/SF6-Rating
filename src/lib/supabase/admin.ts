import "server-only";

import { createClient as createSupabaseClient } from "@supabase/supabase-js";
import type { Database } from "@/lib/database/types";
import { getSupabasePublicEnv } from "@/lib/env/public";
import { getServerEnv } from "@/lib/env/server";

export function createAdminClient() {
  const publicEnv = getSupabasePublicEnv();
  const serverEnv = getServerEnv();

  return createSupabaseClient<Database>(
    publicEnv.NEXT_PUBLIC_SUPABASE_URL,
    serverEnv.SUPABASE_SERVICE_ROLE_KEY,
    {
      auth: { autoRefreshToken: false, persistSession: false },
    },
  );
}
