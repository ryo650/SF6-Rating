import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { localeFromNextPath, safeNextPath } from "@/features/auth/safe-next";
import { getServerEnv } from "@/lib/env/server";
import { createClient } from "@/lib/supabase/server";

const allowedTypes = new Set<EmailOtpType>([
  "email",
  "signup",
  "recovery",
  "email_change",
]);

export const dynamic = "force-dynamic";

function authRedirect(path: string, appOrigin: string) {
  const response = NextResponse.redirect(new URL(path, appOrigin));
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const rawType = requestUrl.searchParams.get("type") as EmailOtpType | null;
  const next = safeNextPath(requestUrl.searchParams.get("next"));
  const locale = localeFromNextPath(next);
  const appOrigin = getServerEnv().APP_BASE_URL;

  if (!tokenHash || !rawType || !allowedTypes.has(rawType)) {
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.verifyOtp({
    token_hash: tokenHash,
    type: rawType,
  });

  if (error) {
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  return authRedirect(next, appOrigin);
}
