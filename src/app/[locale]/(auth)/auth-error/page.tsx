import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function AuthErrorPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);
  return (
    <section className="panel" aria-labelledby="auth-error-title">
      <h1 id="auth-error-title">{messages.authErrorTitle}</h1>
      <p>{messages.authErrorDescription}</p>
      <Link href={`/${locale}/sign-in`}>{messages.signInTitle}</Link>
    </section>
  );
}
