import { test, expect } from "@playwright/test";

// Error reports reach the API (TDD §6b). Its own file: the cloud specs treat
// every page error as a failure, and this one throws on purpose.
test.use({ baseURL: "http://localhost:3000" });
test.skip(process.env.E2E_CLOUD === "0", "needs the API and Postgres");

// TDD §6b: an uncaught error on a page is reported to the API, once.
test("an uncaught error on the site is reported to the API", async ({ page }) => {
  await page.goto("/chapters");
  const sent = page.waitForResponse((r) => r.url().endsWith("/v1/client-errors") && r.request().method() === "POST");
  await page.evaluate(() => {
    setTimeout(() => {
      throw new Error("e2e: a deliberate error");
    });
  });
  const res = await sent;
  expect(res.status()).toBe(204);
  const body = res.request().postDataJSON() as { reports: { source: string; message: string; path: string }[] };
  expect(body.reports).toEqual([expect.objectContaining({ source: "site", message: "Error: e2e: a deliberate error", path: "/chapters" })]);
});
