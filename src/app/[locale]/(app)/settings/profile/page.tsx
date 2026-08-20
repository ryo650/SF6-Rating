import { randomUUID } from "node:crypto";
import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import {
  AvatarSettings,
  DeleteAccountSettings,
  DetailsSettings,
  IdentitySettings,
  UsernameSettings,
} from "@/features/account/ProfileForms";
import {
  getAccountMasters,
  getOnboardingState,
} from "@/features/account/queries";
import { feedbackMessage } from "@/features/account/feedback";
import { signOutAction } from "@/features/auth/actions";
import { requireVerifiedUser } from "@/features/auth/session";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function ProfileSettingsPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ onboarding?: string }>;
}) {
  const { locale } = await params;
  const query = await searchParams;
  if (!isLocale(locale)) notFound();
  const user = await requireVerifiedUser(locale);
  const [state, masters] = await Promise.all([
    getOnboardingState(user.id),
    getAccountMasters(locale),
  ]);
  if (state.account_status === "onboarding") redirect(`/${locale}/onboarding`);
  const messages = getMessages(locale);
  const key = randomUUID();
  return (
    <section className="settings-page" aria-labelledby="profile-settings-title">
      <header className="settings-heading">
        <div>
          <h1 id="profile-settings-title">{messages.profileSettingsTitle}</h1>
          <Link href={`/${locale}/profile/${state.profile_id}`}>
            {messages.publicProfileTitle}
          </Link>
        </div>
        <form action={signOutAction.bind(null, locale)}>
          <button className="button button-secondary" type="submit">
            {messages.signOut}
          </button>
        </form>
      </header>
      {query.onboarding === "complete" ? (
        <section className="settings-card" role="status">
          <h2>{messages.onboardingCompleteTitle}</h2>
          <p>
            {messages.startingRating}: {state.current_rating}
          </p>
          <p>{messages.placementExplanation}</p>
        </section>
      ) : null}
      {state.account_status === "deletion_pending" ? (
        <section className="settings-card">
          <h2>{messages.deleteAccountTitle}</h2>
          <p role="status">{messages.deletionPendingStatus}</p>
          {state.deletion_blocking_reasons.length > 0 ? (
            <ul>
              {state.deletion_blocking_reasons.map((reason) => (
                <li key={reason}>{feedbackMessage(locale, reason)}</li>
              ))}
            </ul>
          ) : null}
          <DeleteAccountSettings
            idempotencyKey={`${key}:delete-retry`}
            labels={messages}
            locale={locale}
            state={state}
          />
        </section>
      ) : (
        <>
          <section className="settings-card">
            <h2>{messages.usernameLabel}</h2>
            <UsernameSettings
              idempotencyKey={`${key}:username`}
              labels={messages}
              locale={locale}
              state={state}
            />
          </section>
          <section className="settings-card">
            <h2>{messages.avatarLabel}</h2>
            <AvatarSettings
              idempotencyKey={`${key}:avatar`}
              labels={messages}
              locale={locale}
              state={state}
            />
          </section>
          <section className="settings-card">
            <h2>{messages.sf6IdentityTitle}</h2>
            <IdentitySettings
              idempotencyKey={`${key}:identity`}
              labels={messages}
              locale={locale}
              state={state}
            />
          </section>
          <section className="settings-card">
            <h2>{messages.ratingStepTitle}</h2>
            <DetailsSettings
              characters={masters.characters}
              countries={masters.countries}
              idempotencyKey={`${key}:details`}
              labels={messages}
              locale={locale}
              regions={masters.regions}
              state={state}
            />
          </section>
          <section className="settings-card">
            <h2>{messages.deleteAccountTitle}</h2>
            <DeleteAccountSettings
              idempotencyKey={`${key}:delete`}
              labels={messages}
              locale={locale}
              state={state}
            />
          </section>
        </>
      )}
    </section>
  );
}
