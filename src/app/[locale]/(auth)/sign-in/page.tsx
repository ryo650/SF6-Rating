import Link from "next/link";
import { notFound } from "next/navigation";
import { signInAction, startOAuthAction } from "@/features/auth/actions";
import { AuthForm } from "@/features/auth/AuthForm";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function SignInPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);

  return (
    <section className="panel auth-panel" aria-labelledby="sign-in-title">
      <h1 id="sign-in-title">{messages.signInTitle}</h1>
      <div className="oauth-actions">
        <form action={startOAuthAction.bind(null, locale, "google")}>
          <button className="button button-secondary" type="submit">
            {messages.googleSignIn}
          </button>
        </form>
        <form action={startOAuthAction.bind(null, locale, "discord")}>
          <button className="button button-secondary" type="submit">
            {messages.discordSignIn}
          </button>
        </form>
      </div>
      <AuthForm
        action={signInAction}
        labels={{
          email: messages.emailLabel,
          password: messages.passwordLabel,
          submit: messages.signInSubmit,
        }}
        locale={locale}
        mode="sign-in"
      />
      <nav className="inline-links" aria-label="Account links">
        <Link href={`/${locale}/forgot-password`}>
          {messages.forgotPassword}
        </Link>
        <Link href={`/${locale}/sign-up`}>{messages.createAccount}</Link>
      </nav>
    </section>
  );
}
