import Link from "next/link";
import { notFound } from "next/navigation";
import { signUpAction } from "@/features/auth/actions";
import { AuthForm } from "@/features/auth/AuthForm";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function SignUpPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);
  return (
    <section className="panel auth-panel" aria-labelledby="sign-up-title">
      <h1 id="sign-up-title">{messages.signUpTitle}</h1>
      <AuthForm
        action={signUpAction}
        labels={{
          email: messages.emailLabel,
          password: messages.passwordLabel,
          submit: messages.signUpSubmit,
        }}
        locale={locale}
        mode="sign-up"
      />
      <Link href={`/${locale}/sign-in`}>{messages.existingAccount}</Link>
    </section>
  );
}
