import { defaultLocale, isLocale } from "@/i18n/config";

export function safeNextPath(value: string | null, fallback?: string): string {
  const safeFallback = fallback ?? `/${defaultLocale}/onboarding`;
  if (!value || !value.startsWith("/") || value.startsWith("//")) {
    return safeFallback;
  }

  try {
    const parsed = new URL(value, "https://local.invalid");
    if (parsed.origin !== "https://local.invalid") return safeFallback;
    const locale = parsed.pathname.split("/")[1];
    return isLocale(locale)
      ? `${parsed.pathname}${parsed.search}`
      : safeFallback;
  } catch {
    return safeFallback;
  }
}

export function localeFromNextPath(value: string | null) {
  const locale = safeNextPath(value).split("/")[1];
  return isLocale(locale) ? locale : defaultLocale;
}
