import { notFound } from "next/navigation";
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
    </section>
  );
}
