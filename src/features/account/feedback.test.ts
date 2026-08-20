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
});
