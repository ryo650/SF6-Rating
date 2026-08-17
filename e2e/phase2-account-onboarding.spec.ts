import AxeBuilder from "@axe-core/playwright";
import { expect, test } from "@playwright/test";

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
