import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import {
  getAccountMasters,
  getOnboardingState,
} from "@/features/account/queries";
import { requireVerifiedUser } from "@/features/auth/session";
import { RatingSetupForm } from "@/features/onboarding/OnboardingForms";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function RatingStepPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const user = await requireVerifiedUser(locale);
  const [state, masters] = await Promise.all([
    getOnboardingState(user.id),
    getAccountMasters(locale),
  ]);
  if (state.current_step < 3) redirect(`/${locale}/onboarding`);
  if (state.account_status === "active")
    redirect(`/${locale}/settings/profile`);
  const messages = getMessages(locale);
  return (
    <section className="panel" aria-labelledby="rating-step-title">
      <p className="step-indicator">3 / 3</p>
      <h1 id="rating-step-title">{messages.ratingStepTitle}</h1>
      <RatingSetupForm
        characters={masters.characters}
        idempotencyKey={randomUUID()}
        labels={messages}
        locale={locale}
        state={state}
      />
    </section>
  );
}
