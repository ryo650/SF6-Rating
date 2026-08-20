import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import {
  getAccountMasters,
  getOnboardingState,
} from "@/features/account/queries";
import { requireVerifiedUser } from "@/features/auth/session";
import { Sf6InfoStepForm } from "@/features/onboarding/OnboardingForms";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function Sf6StepPage({
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
  if (state.current_step < 2) redirect(`/${locale}/onboarding/account`);
  const messages = getMessages(locale);
  return (
    <section className="panel" aria-labelledby="sf6-step-title">
      <p className="step-indicator">2 / 3</p>
      <h1 id="sf6-step-title">{messages.sf6StepTitle}</h1>
      <Sf6InfoStepForm
        countries={masters.countries}
        idempotencyKey={randomUUID()}
        labels={messages}
        locale={locale}
        regions={masters.regions}
        state={state}
      />
    </section>
  );
}
