import { notFound } from "next/navigation";
import { resendVerificationAction } from "@/features/auth/actions";
import { AuthForm } from "@/features/auth/AuthForm";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function VerifyEmailPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);
  return (
    <section className="panel auth-panel" aria-labelledby="verify-email-title">
      <h1 id="verify-email-title">{messages.verifyEmailTitle}</h1>
      <p>{messages.verifyEmailDescription}</p>
      <AuthForm
        action={resendVerificationAction}
        labels={{
          email: messages.emailLabel,
          password: messages.passwordLabel,
          submit: messages.resendVerification,
        }}
        locale={locale}
        mode="resend"
      />
    </section>
  );
}
