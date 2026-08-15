import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import FoundationPage from "./page";

vi.mock("next/navigation", () => ({ notFound: vi.fn() }));

describe("foundation page", () => {
  it("renders the localized base state", async () => {
    render(await FoundationPage({ params: Promise.resolve({ locale: "en" }) }));
    expect(
      screen.getByRole("heading", { name: "Project foundation" }),
    ).toBeInTheDocument();
    expect(
      screen.getByText("The application foundation is ready."),
    ).toBeInTheDocument();
  });
});
