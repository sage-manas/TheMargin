import { test, expect, type Page } from "@playwright/test";
import { DEFAULT_SETTINGS, GameToWebSchema, LOCAL_SAVE_KEY, type GameToWeb, type Save } from "@the-margin/contracts";

// The site, against the real game export behind its /game proxy (TDD §5.3).
test.use({ baseURL: "http://localhost:3000" });

const SETTINGS_KEY = "the-margin.settings";

const save = (progress: Partial<Save["progress"]>): Save => ({
  schema: "the-margin.save",
  version: 1,
  revision: 1,
  updatedAt: "2026-11-07T00:00:00Z",
  playtimeSec: 0,
  progress: { chapter: "ch01", page: "ch01_p01", completedPages: [], completedChapters: [], abilities: [], flags: {}, ...progress },
  player: { position: null, carrying: null },
  pages: {},
});

/** Seeds localStorage before the first page script runs, once per test. */
async function seed(page: Page, items: Record<string, unknown>): Promise<void> {
  await page.addInitScript((entries) => {
    if (sessionStorage.getItem("seeded")) return;
    sessionStorage.setItem("seeded", "1");
    for (const [k, v] of Object.entries(entries)) localStorage.setItem(k, JSON.stringify(v));
  }, items);
}

/** Records every game message the launcher re-dispatches on window. */
async function record(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as unknown as { __msgs: unknown[] };
    w.__msgs = [];
    window.addEventListener("themargin:message", (e) => w.__msgs.push((e as CustomEvent).detail));
  });
}

async function messages(page: Page): Promise<GameToWeb[]> {
  const raw = (await page.evaluate(() => (window as unknown as { __msgs: unknown[] }).__msgs)) as unknown[];
  return raw.map((m) => GameToWebSchema.parse(m));
}

async function waitFor(page: Page, pred: (m: GameToWeb) => boolean, timeout = 90_000): Promise<GameToWeb> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const hit = (await messages(page)).find(pred);
    if (hit) return hit;
    await page.waitForTimeout(100);
  }
  throw new Error("Timed out waiting for a game message");
}

test.beforeEach(async ({ page }) => {
  page.on("pageerror", (e) => {
    // Leaving a page cancels Next.js's route prefetches; WebKit reports the
    // cancelled fetch as an error. Anything else fails the test.
    if (/_rsc=/.test(e.message)) return;
    throw e;
  });
});

test("the landing page leads to /play and offers to continue a save", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toHaveText("The Margin");
  await expect(page.getByRole("link", { name: "Start reading" })).toHaveAttribute("href", "/play");

  await seed(page, { [LOCAL_SAVE_KEY]: save({ page: "ch01_p04", completedPages: ["ch01_p01", "ch01_p02", "ch01_p03"] }) });
  await page.reload();
  await expect(page.getByRole("link", { name: "Continue · page 1.4" })).toBeVisible();
});

test("the chapters page shows this browser's progress", async ({ page }) => {
  await seed(page, { [LOCAL_SAVE_KEY]: save({ page: "ch01_p04", completedPages: ["ch01_p01", "ch01_p02", "ch01_p03"] }) });
  await page.goto("/chapters");
  const ch1 = page.locator('[data-chapter="ch01"]');
  await expect(ch1).toHaveAttribute("data-status", "in-progress");
  await expect(ch1).toContainText("3 of 8 pages. On page 1.4.");
  await expect(ch1.getByRole("progressbar")).toHaveAttribute("aria-valuenow", "3");
  await expect(page.locator('[data-chapter="ch02"]')).toContainText("8 pages. Not started.");
  await expect(page.locator('[data-chapter="ch03"]')).toContainText("Still being drawn.");
});

test("/play launches the game, which takes the site's settings", async ({ page }, info) => {
  await record(page);
  await page.goto("/settings");
  await page.getByLabel("Music").fill("25");
  await expect(page.locator("#settings-status")).toContainText("Saved");

  const errors: string[] = [];
  page.on("console", (m) => m.type() === "error" && errors.push(m.text()));
  await page.goto("/play");
  await expect(page.getByRole("progressbar", { name: "Loading the game" })).toBeVisible();
  await waitFor(page, (m) => m.type === "GAME_READY");
  await expect(page.locator(".launcher")).toHaveAttribute("data-state", "ready");
  // The game applied the site's settings and echoed them back.
  const echo = await waitFor(page, (m) => m.type === "SETTINGS_UPDATED" && m.payload.settings.musicVolume === 0.25, 10_000);
  expect(echo.type === "SETTINGS_UPDATED" && echo.payload.settings.masterVolume).toBe(DEFAULT_SETTINGS.masterVolume);

  // The canvas has focus, so the title menu answers the keyboard at once.
  await page.locator("#game-canvas").click({ position: { x: 20, y: 20 } });
  await page.keyboard.press("Enter");
  const started = await waitFor(page, (m) => m.type === "GAME_STARTED", 15_000);
  expect(started.type === "GAME_STARTED" && started.payload.pageId).toBe("ch01_p01");

  await page.getByRole("button", { name: "Mute" }).click();
  await expect(page.getByRole("button", { name: "Unmute" })).toHaveAttribute("aria-pressed", "true");
  await page.waitForTimeout(500);
  await page.screenshot({ path: info.outputPath("play.png") });
  expect(errors).toEqual([]);

  // The game's settings echo kept the site's mirror current.
  const mirror = await page.evaluate((k) => JSON.parse(localStorage.getItem(k) ?? "null"), SETTINGS_KEY);
  expect(mirror.musicVolume).toBe(0.25);
});

test("/play explains a missing game build", async ({ page }) => {
  await page.route("**/game/build.json", (r) => r.fulfill({ status: 404, body: "" }));
  page.on("console", () => {}); // the launcher logs the failure
  await page.goto("/play");
  await expect(page.locator(".launcher")).toHaveAttribute("data-state", "error");
  await expect(page.locator(".launcher-overlay[role=alert]")).toContainText("could not be found (HTTP 404)");
  await expect(page.getByRole("button", { name: "Try again" })).toBeVisible();
});
