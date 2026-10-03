import { NextResponse, type NextRequest } from "next/server";
import { AuthOriginError, resolveAuthOrigin } from "@/features/auth/origin";
import { localeFromNextPath, safeNextPath } from "@/features/auth/safe-next";
import { getAuthEnv } from "@/lib/env/auth";
import { createClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";

function authRedirect(path: string, appOrigin: string) {
  const response = NextResponse.redirect(new URL(path, appOrigin));
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}

function safeFailureResponse() {
  return new NextResponse(
    "Authentication could not be completed safely. Return to the sign-in page and try again.",
    {
      status: 400,
      headers: {
        "Cache-Control": "private, no-store",
        "Content-Type": "text/plain; charset=utf-8",
      },
    },
  );
}

function logCallbackFailure(stage: string, error: unknown) {
  const rawCode =
    error && typeof error === "object" && "code" in error
      ? String(error.code)
      : "";
  console.error("[auth/callback] authentication failed", {
    stage,
    errorName: error instanceof Error ? error.constructor.name : "UnknownError",
    errorCode: /^[a-z0-9_-]{1,64}$/i.test(rawCode) ? rawCode : undefined,
    status:
      error &&
      typeof error === "object" &&
      "status" in error &&
      typeof error.status === "number"
        ? error.status
        : undefined,
    reason: error instanceof AuthOriginError ? error.reason : undefined,
  });
}

export async function GET(request: NextRequest) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get("code");
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
    logCallbackFailure("origin", error);
    return safeFailureResponse();
  }

  if (!code) {
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  try {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (error) {
      logCallbackFailure("exchange", error);
      return authRedirect(`/${locale}/auth-error`, appOrigin);
    }
  } catch (error) {
    logCallbackFailure("unexpected", error);
    return authRedirect(`/${locale}/auth-error`, appOrigin);
  }

  return authRedirect(next, appOrigin);
}
