import { randomUUID } from "node:crypto";
import { notFound } from "next/navigation";
import { getOnboardingState } from "@/features/account/queries";
import { requireVerifiedUser } from "@/features/auth/session";
import { providerProfileCandidate } from "@/features/auth/provider-profile";
import { AccountStepForm } from "@/features/onboarding/OnboardingForms";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function AccountStepPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const user = await requireVerifiedUser(locale);
  const state = await getOnboardingState(user.id);
  const providerCandidate = providerProfileCandidate(user);
  const messages = getMessages(locale);
  return (
    <section className="panel" aria-labelledby="account-step-title">
      <p className="step-indicator">1 / 3</p>
      <h1 id="account-step-title">{messages.accountStepTitle}</h1>
      <AccountStepForm
        idempotencyKey={randomUUID()}
        labels={messages}
        locale={locale}
        providerAvatarAvailable={Boolean(providerCandidate?.avatarUrl)}
        providerUsernameCandidate={providerCandidate?.username ?? null}
        state={state}
      />
    </section>
  );
}
