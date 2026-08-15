import { describe, expect, it } from "vitest";
import { getMessages } from "./messages";
import { defaultLocale, isLocale } from "./config";

describe("locale foundation", () => {
  it("supports Japanese and English with matching messages", () => {
    expect(getMessages("ja").foundationTitle).toBe("プロジェクト基盤");
    expect(getMessages("en").foundationTitle).toBe("Project foundation");
  });

  it("rejects unsupported locales and defaults to Japanese", () => {
    expect(isLocale("ja")).toBe(true);
    expect(isLocale("en")).toBe(true);
    expect(isLocale("fr")).toBe(false);
    expect(defaultLocale).toBe("ja");
  });
});
