import "server-only";

import type { User } from "@supabase/supabase-js";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export class AuthenticationRequiredError extends Error {
  constructor(public readonly code = "authentication_required") {
    super(code);
  }
}

export async function getVerifiedUser(): Promise<User> {
  const supabase = await createClient();
  const claimsResult = await supabase.auth.getClaims();

  if (claimsResult.error || !claimsResult.data?.claims?.sub) {
    throw new AuthenticationRequiredError();
  }

  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) throw new AuthenticationRequiredError();
  if (!data.user.email_confirmed_at) {
    throw new AuthenticationRequiredError("email_verification_required");
  }

  return data.user;
}

export async function requireVerifiedUser(locale: string): Promise<User> {
  try {
    return await getVerifiedUser();
  } catch (error) {
    if (
      error instanceof AuthenticationRequiredError &&
      error.code === "email_verification_required"
    ) {
      redirect(`/${locale}/verify-email`);
    }
    redirect(`/${locale}/sign-in`);
  }
}

export function hasRecentAuthentication(user: User, maximumAgeMinutes = 15) {
  if (!user.last_sign_in_at) return false;
  const signedInAt = Date.parse(user.last_sign_in_at);
  return (
    Number.isFinite(signedInAt) &&
    Date.now() - signedInAt <= maximumAgeMinutes * 60_000
  );
}
