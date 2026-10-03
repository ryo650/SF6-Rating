import { caseFold } from "unicode-case-folding";

const usernameCharacters = /^[\p{L}\p{M}\p{Nd}_-]+$/u;
const playerNameForbidden = /[\p{Cc}\p{Cf}]/u;
const userCodeSeparators = /[\p{Zs}\t\u002D\u2010-\u2015\u2212]/gu;

export class AccountValidationError extends Error {
  constructor(
    public readonly code: string,
    message = code,
  ) {
    super(message);
    this.name = "AccountValidationError";
  }
}

export function countGraphemes(value: string): number {
  const segmenter = new Intl.Segmenter("und", { granularity: "grapheme" });
  return Array.from(segmenter.segment(value)).length;
}

export function normalizeUsername(input: string): {
  display: string;
  normalized: string;
} {
  const display = input.trim().normalize("NFKC");
  // The lockfile pins the case-fold data source. Re-normalizing after full
  // case folding implements the NFKC_Casefold-style comparison contract.
  const normalized = caseFold(display).normalize("NFKC");
  const graphemeLength = countGraphemes(display);

  if (graphemeLength < 3 || graphemeLength > 20) {
    throw new AccountValidationError("username_length");
  }

  if (!usernameCharacters.test(display)) {
    throw new AccountValidationError("username_characters");
  }

  if (Array.from(display).length > 80 || Array.from(normalized).length > 160) {
    throw new AccountValidationError("username_too_complex");
  }

  return { display, normalized };
}

export function normalizeSf6PlayerName(input: string): string {
  const display = input.trim().normalize("NFC");
  const graphemeLength = countGraphemes(display);

  if (graphemeLength < 1 || graphemeLength > 32) {
    throw new AccountValidationError("player_name_length");
  }

  if (playerNameForbidden.test(display)) {
    throw new AccountValidationError("player_name_characters");
  }

  return display;
}

export function normalizeSf6UserCode(input: string): string {
  const normalized = input.normalize("NFKC").replace(userCodeSeparators, "");

  if (!/^\d{10}$/.test(normalized)) {
    throw new AccountValidationError("sf6_user_code_format");
  }

  return normalized;
}
