import { notFound } from "next/navigation";
import Link from "next/link";
import { isLocale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export default async function FoundationPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  const messages = getMessages(locale);

  return (
    <section className="panel" aria-labelledby="foundation-title">
      <h1 id="foundation-title">{messages.foundationTitle}</h1>
      <p>{messages.foundationDescription}</p>
      <div className="form-actions">
        <Link className="button button-link" href={`/${locale}/sign-up`}>
          {messages.createAccount}
        </Link>
        <Link
          className="button button-secondary button-link"
          href={`/${locale}/sign-in`}
        >
          {messages.signInTitle}
        </Link>
      </div>
    </section>
  );
}
