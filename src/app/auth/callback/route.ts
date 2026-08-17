import { NextResponse, type NextRequest } from "next/server";
import { localeFromNextPath, safeNextPath } from "@/features/auth/safe-next";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
  const next = safeNextPath(requestUrl.searchParams.get("next"));
  const locale = localeFromNextPath(next);

  if (!code) {
    return NextResponse.redirect(
      new URL(`/${locale}/auth-error`, requestUrl.origin),
    );
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.exchangeCodeForSession(code);
  if (error) {
    return NextResponse.redirect(
      new URL(`/${locale}/auth-error`, requestUrl.origin),
    );
  }

  const response = NextResponse.redirect(new URL(next, requestUrl.origin));
  response.headers.set("Cache-Control", "no-store");
  return response;
}
