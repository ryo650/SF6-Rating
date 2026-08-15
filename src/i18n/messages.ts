import type { Locale } from "./config";
import en from "./messages/en";
import ja from "./messages/ja";

export type Messages = { [Key in keyof typeof ja]: string };

const messages: Record<Locale, Messages> = { ja, en };

export function getMessages(locale: Locale): Messages {
  return messages[locale];
}
