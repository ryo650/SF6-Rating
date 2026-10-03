import { notFound } from "next/navigation";
import { updatePasswordAction } from "@/features/auth/actions";
import { AuthForm } from "@/features/auth/AuthForm";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function UpdatePasswordPage({
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
      aria-labelledby="update-password-title"
    >
      <h1 id="update-password-title">{messages.updatePasswordTitle}</h1>
      <AuthForm
        action={updatePasswordAction}
        labels={{
          email: messages.emailLabel,
          password: messages.passwordLabel,
          submit: messages.updatePassword,
        }}
        locale={locale}
        mode="update"
      />
    </section>
  );
}
