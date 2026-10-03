import { notFound } from "next/navigation";
import { requestPasswordResetAction } from "@/features/auth/actions";
import { AuthForm } from "@/features/auth/AuthForm";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function ForgotPasswordPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);
  return (
    <section
      className="panel auth-panel"
      aria-labelledby="forgot-password-title"
    >
      <h1 id="forgot-password-title">{messages.forgotPasswordTitle}</h1>
      <AuthForm
        action={requestPasswordResetAction}
        labels={{
          email: messages.emailLabel,
          password: messages.passwordLabel,
          submit: messages.sendReset,
        }}
        locale={locale}
        mode="forgot"
      />
    </section>
  );
}
