import { test, expect } from "@playwright/test";

test("homepage loads", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Collaborative Todo Lists/);
  await expect(page.getByText("coming soon")).toBeVisible();
});
