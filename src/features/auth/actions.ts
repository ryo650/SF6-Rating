"use server";

import { redirect } from "next/navigation";
import { headers } from "next/headers";
import type { Provider } from "@supabase/supabase-js";
import type { ActionState } from "@/features/account/action-state";
import { AuthOriginError, buildAuthCallbackUrl } from "@/features/auth/origin";
import { isLocale } from "@/i18n/config";
import { getAuthEnv } from "@/lib/env/auth";
import { createClient } from "@/lib/supabase/server";

function localeFromForm(formData: FormData) {
  const candidate = String(formData.get("locale") ?? "");
  return isLocale(candidate) ? candidate : "ja";
}

function authError(): ActionState {
  return { status: "error", message: "auth_failed" };
}

async function callbackUrl(next: string) {
  return buildAuthCallbackUrl(
    { env: getAuthEnv(), headers: await headers() },
    next,
  );
}

function logOriginFailure(stage: string, error: unknown) {
  console.error("[auth] origin resolution failed", {
    stage,
    errorName: error instanceof Error ? error.constructor.name : "UnknownError",
    reason: error instanceof AuthOriginError ? error.reason : undefined,
  });
}

export async function signUpAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!email.includes("@") || password.length < 8) {
    return { status: "error", message: "auth_invalid_input" };
  }

  let callback: string;
  try {
    callback = await callbackUrl(`/${locale}/onboarding`);
  } catch (error) {
    logOriginFailure("email-sign-up", error);
    return authError();
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: { emailRedirectTo: callback },
  });

  if (error) return authError();
  redirect(`/${locale}/verify-email?sent=1`);
}

export async function signInAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!email || !password) {
    return { status: "error", message: "auth_invalid_input" };
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (error || !data.user?.email_confirmed_at) return authError();
  redirect(`/${locale}/onboarding`);
}

export async function resendVerificationAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  const email = String(formData.get("email") ?? "").trim();
  if (!email.includes("@")) {
    return { status: "error", message: "auth_invalid_input" };
  }

  let callback: string;
  try {
    callback = await callbackUrl(`/${locale}/onboarding`);
  } catch (error) {
    logOriginFailure("email-resend", error);
    return authError();
  }

  const supabase = await createClient();
  await supabase.auth.resend({
    type: "signup",
    email,
    options: { emailRedirectTo: callback },
  });

  return { status: "success", message: "verification_sent" };
}

export async function requestPasswordResetAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  const email = String(formData.get("email") ?? "").trim();
  if (!email.includes("@")) {
    return { status: "error", message: "auth_invalid_input" };
  }

  let callback: string;
  try {
    callback = await callbackUrl(`/${locale}/update-password`);
  } catch (error) {
    logOriginFailure("password-reset", error);
    return authError();
  }

  const supabase = await createClient();
  await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: callback,
  });

  return { status: "success", message: "password_reset_sent" };
}

export async function updatePasswordAction(
  _previous: ActionState,
  formData: FormData,
): Promise<ActionState> {
  const locale = localeFromForm(formData);
  const password = String(formData.get("password") ?? "");
  if (password.length < 8) {
    return { status: "error", message: "password_too_short" };
  }

  const supabase = await createClient();
  const { error } = await supabase.auth.updateUser({ password });
  if (error) return authError();
  redirect(`/${locale}/onboarding`);
}

export async function startOAuthAction(
  localeCandidate: string,
  provider: Extract<Provider, "google" | "discord">,
): Promise<void> {
  const locale = isLocale(localeCandidate) ? localeCandidate : "ja";
  let callback: string;
  try {
    callback = await callbackUrl(`/${locale}/onboarding`);
  } catch (error) {
    logOriginFailure(`oauth-${provider}`, error);
    redirect(`/${locale}/auth-error`);
  }

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider,
    options: { redirectTo: callback, skipBrowserRedirect: true },
  });

  if (error || !data.url) redirect(`/${locale}/auth-error`);
  redirect(data.url);
}

export async function signOutAction(localeCandidate: string) {
  const locale = isLocale(localeCandidate) ? localeCandidate : "ja";
  const supabase = await createClient();
  await supabase.auth.signOut({ scope: "local" });
  redirect(`/${locale}/sign-in`);
}
