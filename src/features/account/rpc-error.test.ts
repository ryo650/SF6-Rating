import { describe, expect, it, vi } from "vitest";
import {
  classifyRpcFailure,
  logSanitizedRpcFailure,
  rpcFailure,
} from "./rpc-error";

describe("account RPC failures", () => {
  it("maps only the explicit active Season domain error", () => {
    expect(
      rpcFailure({ code: "55000", message: "active_season_required" }),
    ).toEqual({ status: "error", message: "active_season_required" });
    expect(
      rpcFailure({ code: "P0002", message: "query returned no rows" }),
    ).toEqual({ status: "error", message: "save_failed" });
  });

  it("logs only the action, classified domain error, and valid SQLSTATE", () => {
    const error = {
      code: "55000",
      message: "active_season_required user@example.test secret-token",
      details: "raw payload",
      hint: "sensitive hint",
    };
    const spy = vi.spyOn(console, "error").mockImplementation(() => undefined);

    logSanitizedRpcFailure("phase2_complete_onboarding", error);

    expect(spy).toHaveBeenCalledWith("[account/action] RPC failed", {
      action: "phase2_complete_onboarding",
      domainError: "active_season_required",
      sqlstate: "55000",
    });
    expect(JSON.stringify(spy.mock.calls)).not.toContain("user@example.test");
    expect(JSON.stringify(spy.mock.calls)).not.toContain("secret-token");
    expect(JSON.stringify(spy.mock.calls)).not.toContain("raw payload");
    spy.mockRestore();
  });

  it("does not expose unknown database messages or malformed error codes", () => {
    expect(
      classifyRpcFailure({ code: "P0002", message: "internal row missing" }),
    ).toBe("save_failed");
    const spy = vi.spyOn(console, "error").mockImplementation(() => undefined);

    logSanitizedRpcFailure("phase2_complete_onboarding", {
      code: "not-a-sqlstate",
      message: "internal row missing",
    });

    expect(spy).toHaveBeenCalledWith("[account/action] RPC failed", {
      action: "phase2_complete_onboarding",
      domainError: "unclassified",
      sqlstate: undefined,
    });
    expect(JSON.stringify(spy.mock.calls)).not.toContain(
      "internal row missing",
    );
    spy.mockRestore();
  });
});
