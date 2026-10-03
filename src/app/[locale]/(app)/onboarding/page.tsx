import { redirect } from "next/navigation";
import { getOnboardingState } from "@/features/account/queries";
import { requireVerifiedUser } from "@/features/auth/session";
import { isLocale } from "@/i18n/config";

export default async function OnboardingEntry({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale: candidate } = await params;
  const locale = isLocale(candidate) ? candidate : "ja";
  const user = await requireVerifiedUser(locale);
  const state = await getOnboardingState(user.id);

  if (state.account_status === "active")
    redirect(`/${locale}/settings/profile`);
  if (state.current_step >= 3) redirect(`/${locale}/onboarding/rating`);
  if (state.current_step >= 2) redirect(`/${locale}/onboarding/sf6`);
  redirect(`/${locale}/onboarding/account`);
}
