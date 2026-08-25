import { describe, expect, it } from "vitest";
import { feedbackMessage } from "./feedback";

describe("feedbackMessage", () => {
  it("localizes stable action codes without exposing internal identifiers", () => {
    expect(feedbackMessage("ja", "sf6_user_code_cooldown")).toContain("30日");
    expect(feedbackMessage("en", "sf6_user_code_cooldown")).toContain(
      "30 days",
    );
  });

  it("uses a safe generic message for unknown server errors", () => {
    expect(feedbackMessage("en", "raw_database_detail")).toBe(
      "Could not save. Try again.",
    );
  });

  it("explains the active Season prerequisite in Japanese and English", () => {
    expect(feedbackMessage("ja", "active_season_required")).toContain(
      "現在シーズンを準備中",
    );
    expect(feedbackMessage("en", "active_season_required")).toContain(
      "current season is being prepared",
    );
  });
});
