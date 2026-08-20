import { describe, expect, it } from "vitest";
import {
  AccountValidationError,
  countGraphemes,
  normalizeSf6PlayerName,
  normalizeSf6UserCode,
  normalizeUsername,
} from "./normalization";

describe("account normalization", () => {
  it("normalizes compatibility and full Unicode case folding", () => {
    expect(normalizeUsername(" Ｓｔｒａßｅ ")).toEqual({
      display: "Straße",
      normalized: "strasse",
    });
    expect(normalizeUsername("プレイヤー１").normalized).toBe("プレイヤー1");
  });

  it("re-normalizes characters expanded by full case folding", () => {
    expect(normalizeUsername("İUser").normalized).toBe(
      "i̇user".normalize("NFKC"),
    );
  });

  it("counts grapheme clusters rather than UTF-16 code units", () => {
    expect(countGraphemes("か\u3099きく")).toBe(3);
  });

  it.each(["ab", "a b c", "abc!", "🔥fighter"])(
    "rejects invalid username %s",
    (value) => {
      expect(() => normalizeUsername(value)).toThrow(AccountValidationError);
    },
  );

  it("normalizes full-width SF6 User Code digits and allowed separators", () => {
    expect(normalizeSf6UserCode("１２３４-５６７ ８９０")).toBe("1234567890");
  });

  it.each(["123456789", "12345678901", "1234/567890", "12345A7890"])(
    "rejects invalid SF6 User Code %s",
    (value) => {
      expect(() => normalizeSf6UserCode(value)).toThrow(
        expect.objectContaining({ code: "sf6_user_code_format" }),
      );
    },
  );

  it("allows duplicate-friendly player names but rejects format controls", () => {
    expect(normalizeSf6PlayerName("  プレイヤー  ")).toBe("プレイヤー");
    expect(() => normalizeSf6PlayerName("bad\u200Bname")).toThrow(
      expect.objectContaining({ code: "player_name_characters" }),
    );
  });
});
