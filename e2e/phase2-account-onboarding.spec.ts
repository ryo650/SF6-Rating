import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

async function waitForAuthEmail(email: string) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    const mailbox = await fetch("http://127.0.0.1:54324/api/v1/messages").then(
      (response) => response.json(),
    );
    const message = mailbox.messages?.find(
      (candidate: { To?: { Address?: string }[] }) =>
        candidate.To?.some(
          (recipient) => recipient.Address?.toLowerCase() === email,
        ),
    );
    if (message) {
      const detail = await fetch(
        `http://127.0.0.1:54324/api/v1/message/${message.ID}`,
      ).then((response) => response.json());
      const body = `${detail.HTML ?? ""}\n${detail.Text ?? ""}`.replaceAll(
        "&amp;",
        "&",
      );
      const link = (body.match(/https?:\/\/[^\s"'<>]+/g) ?? []).find(
        (candidate: string) => candidate.includes("/auth/v1/verify"),
      );
      if (link) return link.replace(/[).,]+$/, "");
    }
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("Local verification email was not delivered");
}

for (const locale of ["ja", "en"] as const) {
  test(`${locale} Auth entry is localized, responsive, and accessible`, async ({
    page,
  }) => {
    await page.goto(`/${locale}/sign-in`);
    await expect(page.locator("html")).toHaveAttribute("lang", locale);
    await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
    await expect(page.getByLabel(/Email|メールアドレス/)).toBeVisible();
    await expect(page.getByLabel(/Password|パスワード/)).toBeVisible();
    await expect(page.getByRole("button", { name: /Google/ })).toBeVisible();
    await expect(page.getByRole("button", { name: /Discord/ })).toBeVisible();

    await page.keyboard.press("Tab");
    await expect(page.locator(".skip-link")).toBeFocused();
    await expect(page.locator(".skip-link")).toBeVisible();

    const overflow = await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);

    const accessibility = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
      .analyze();
    expect(accessibility.violations).toEqual([]);
  });
}

test("Auth callback failures preserve a safe locale", async ({ page }) => {
  await page.goto("/auth/callback?next=%2Fen%2Fonboarding");
  await expect(page).toHaveURL(/\/en\/auth-error$/);
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();
});

test("protected onboarding returns an unauthenticated user to sign in", async ({
  page,
}) => {
  await page.goto("/ja/onboarding");
  await expect(page).toHaveURL(/\/ja\/sign-in$/);
});

test("verified Email user completes, resumes, and deletes the full onboarding slice", async ({
  page,
}, testInfo) => {
  test.skip(testInfo.project.name !== "desktop-chromium");
  test.setTimeout(60_000);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const email = `phase2-e2e-${suffix}@example.test`;
  const password = `P2-e2e-${suffix}!`;

  await page.goto("/en/sign-up");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel(/Password/).fill(password);
  await page.getByRole("button", { name: "Sign up with email" }).click();
  await expect(page).toHaveURL(/\/en\/verify-email\?sent=1$/);

  const confirmationLink = await waitForAuthEmail(email);
  await page.goto(confirmationLink);
  await expect(page).toHaveURL(/\/en\/onboarding\/account$/);

  await page.getByLabel("Username").fill(`e2e${suffix}`.slice(0, 20));
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page).toHaveURL(/\/en\/onboarding\/sf6$/);

  await page.getByLabel("SF6 Player Name").fill("E2E Player");
  await page
    .getByLabel("SF6 User Code")
    .fill(suffix.slice(-10).padStart(10, "0"));
  await page.getByLabel("Country").selectOption("JP");
  await page.getByLabel("Broad Region").selectOption("JP-KANTO");
  await page.getByRole("button", { name: "Next", exact: true }).click();
  await expect(page).toHaveURL(/\/en\/onboarding\/rating$/);
  await page.reload();
  await expect(page).toHaveURL(/\/en\/onboarding\/rating$/);

  await page.getByLabel("Main Character").selectOption("ryu");
  await page.getByLabel("SF6 Rank").selectOption("gold");
  await page.getByLabel("Rank Tier").selectOption("3");
  await page.getByRole("button", { name: "Preview Starting Rating" }).click();
  await expect(page.locator("output.rating-preview")).toContainText(
    "Starting Rating",
  );
  await expect(page.getByLabel("SF6 Rank")).toHaveValue("gold");
  await expect(page.locator('input[name="previewToken"]')).toHaveValue(
    /^[0-9a-f]{64}$/,
  );
  await page.getByLabel("Rank Tier").selectOption("4");
  await expect(
    page.getByRole("button", { name: "Complete setup" }),
  ).toBeDisabled();
  await page.getByLabel("Rank Tier").selectOption("3");
  await page.getByRole("button", { name: "Preview Starting Rating" }).click();
  await expect(page.getByLabel("SF6 Rank")).toHaveValue("gold");
  const completeButton = page.getByRole("button", { name: "Complete setup" });
  await expect(completeButton).toBeEnabled();
  await completeButton.click();
  await expect(page).toHaveURL(/\/en\/settings\/profile\?onboarding=complete$/);
  await expect(
    page.getByRole("heading", { name: "Profile settings" }),
  ).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Account setup complete" }),
  ).toBeVisible();
  await expect(page.getByRole("status")).toContainText("Starting Rating:");

  await page.reload();
  await expect(page.getByLabel("SF6 Player Name")).toHaveValue("E2E Player");

  await page.getByLabel("I understand this action is irreversible.").check();
  await page.getByRole("button", { name: "Request deletion" }).click();
  await expect(page).toHaveURL(/\/en\?account=deleted$/);
  await page.goto("/en/settings/profile");
  await expect(page).toHaveURL(/\/en\/sign-in$/);
});
