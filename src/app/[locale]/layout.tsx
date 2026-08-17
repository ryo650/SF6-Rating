import Link from "next/link";
import { notFound } from "next/navigation";
import { isLocale, locales, type Locale } from "@/i18n/config";
import { getMessages } from "@/i18n/messages";

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: Readonly<{
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}>) {
  const { locale: candidate } = await params;
  if (!isLocale(candidate)) notFound();
  const locale: Locale = candidate;
  const messages = getMessages(locale);
  const otherLocale: Locale = locale === "ja" ? "en" : "ja";

  return (
    <html lang={locale}>
      <body>
        <a className="skip-link" href="#main-content">
          {messages.skipToContent}
        </a>
        <header className="site-header">
          <div className="header-inner">
            <Link className="brand" href={`/${locale}`}>
              {messages.appName}
            </Link>
            <Link
              className="locale-link"
              href={`/${otherLocale}`}
              hrefLang={otherLocale}
            >
              {messages.switchLocale}
            </Link>
            <Link className="locale-link" href={`/${locale}/sign-in`}>
              {messages.signInTitle}
            </Link>
          </div>
        </header>
        <main className="main-content" id="main-content">
          {children}
        </main>
      </body>
    </html>
  );
}
