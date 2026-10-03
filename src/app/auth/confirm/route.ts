import type { EmailOtpType } from "@supabase/supabase-js";
import { NextResponse, type NextRequest } from "next/server";
import { AuthOriginError, resolveAuthOrigin } from "@/features/auth/origin";
import { localeFromNextPath, safeNextPath } from "@/features/auth/safe-next";
import { getAuthEnv } from "@/lib/env/auth";
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

function safeFailureResponse() {
  return new NextResponse(
    "Email confirmation could not be completed safely. Return to the sign-in page and try again.",
    {
      status: 400,
      headers: {
        "Cache-Control": "private, no-store",
        "Content-Type": "text/plain; charset=utf-8",
      },
    },
  );
}

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const tokenHash = requestUrl.searchParams.get("token_hash");
  const rawType = requestUrl.searchParams.get("type") as EmailOtpType | null;
  const next = safeNextPath(requestUrl.searchParams.get("next"));
  const locale = localeFromNextPath(next);
  let appOrigin: string;

  try {
    appOrigin = resolveAuthOrigin({
      env: getAuthEnv(),
      headers: request.headers,
      requestUrl,
    });
  } catch (error) {
    console.error("[auth/confirm] origin resolution failed", {
      errorName:
        error instanceof Error ? error.constructor.name : "UnknownError",
      reason: error instanceof AuthOriginError ? error.reason : undefined,
    });
    return safeFailureResponse();
  }

  if (!tokenHash || !rawType || !allowedTypes.has(rawType)) {
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.verifyOtp({
      token_hash: tokenHash,
      type: rawType,
    });

    if (error) {
      return authRedirect(`/${locale}/auth-error`, appOrigin);
    }
  } catch (error) {
    const rawCode =
      error && typeof error === "object" && "code" in error
        ? String(error.code)
        : "";
    console.error("[auth/confirm] verification failed", {
      errorName:
        error instanceof Error ? error.constructor.name : "UnknownError",
      errorCode: /^[a-z0-9_-]{1,64}$/i.test(rawCode) ? rawCode : undefined,
    });
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  return authRedirect(next, appOrigin);
}
