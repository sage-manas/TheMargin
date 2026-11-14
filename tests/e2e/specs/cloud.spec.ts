import { test, expect, type BrowserContext, type Page } from "@playwright/test";
import { CloudSaveSchema, GameToWebSchema, LOCAL_SAVE_KEY, type GameToWeb, type Save } from "@the-margin/contracts";

// Accounts and cloud saves end to end: the site, the API behind its /v1
// proxy, and the real game (TDD §4.3, backlog 29).
// 764 px tall leaves a 1280×720 stage below the launcher's toolbar: the page at
// exactly ×2, so drags map to whole page units in every engine.
const VIEWPORT = { width: 1280, height: 764 };
test.use({ baseURL: "http://localhost:3000", viewport: VIEWPORT });
test.skip(process.env.E2E_CLOUD === "0", "needs the API and Postgres");

const PASSWORD = "correct horse battery";

/** Records the game's messages, which the launcher re-dispatches on window. */
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

async function signUp(page: Page): Promise<string> {
  const email = `nib-${Date.now()}-${Math.random().toString(36).slice(2, 8)}@example.com`;
  await page.goto("/account");
  await page.getByRole("tab", { name: "Create account" }).click();
  await page.getByLabel("Name").fill("Nib");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Create account" }).click();
  await expect(page.locator("[data-account=signed-in]")).toContainText("Signed in as Nib");
  // The header follows.
  await expect(page.locator("[data-account-name]")).toHaveText("Nib");
  return email;
}

async function signIn(page: Page, email: string): Promise<void> {
  await page.goto("/account");
  await page.getByLabel("Email").fill(email);
  await page.getByLabel("Password").fill(PASSWORD);
  await page.getByRole("button", { name: "Sign in" }).click();
  await expect(page.locator("[data-account=signed-in]")).toBeVisible();
}

/** Opens /play and waits for the game and the cloud connection. */
async function play(page: Page): Promise<void> {
  await page.goto("/play");
  await waitFor(page, (m) => m.type === "GAME_READY");
  await expect(page.locator("[data-cloud]")).toHaveAttribute("data-cloud", "synced", { timeout: 15_000 });
}

async function newGame(page: Page): Promise<void> {
  await page.locator("#game-canvas").click({ position: { x: 20, y: 20 } });
  await page.keyboard.press("Enter");
  await waitFor(page, (m) => m.type === "GAME_STARTED");
  await page.waitForTimeout(400);
}

/** Slides page 1.1's lifted panel P3 down `dy` page units. Godot scales the 640×360 page to fit, centred in the canvas (ADR-0013). */
async function slideP3(page: Page, dy: number): Promise<void> {
  const box = (await page.locator("#game-canvas").boundingBox())!;
  const scale = Math.min(box.width / 640, box.height / 360);
  const at = (x: number, y: number) => [box.x + (box.width - 640 * scale) / 2 + x * scale, box.y + (box.height - 360 * scale) / 2 + y * scale] as const;
  await page.mouse.move(...at(520, 76));
  await page.mouse.down();
  await page.mouse.move(...at(520, 76 + dy), { steps: 12 });
  await page.mouse.up();
}

async function cloudSave(context: BrowserContext): Promise<{ revision: number; save: Save } | null> {
  const r = await context.request.get("http://localhost:3000/v1/saves/main");
  return r.status() === 404 ? null : CloudSaveSchema.parse(await r.json());
}

async function localSave(page: Page): Promise<Save> {
  return JSON.parse((await page.evaluate((k) => localStorage.getItem(k), LOCAL_SAVE_KEY)) ?? "null");
}

test.beforeEach(async ({ page }) => {
  page.on("pageerror", (e) => {
    throw e;
  });
});

test("play saves to the account, and a second browser continues from it", async ({ page, context, browser }) => {
  await record(page);
  const email = await signUp(page);
  await play(page);
  await newGame(page);
  await slideP3(page, 24);
  await expect.poll(async () => (await cloudSave(context))?.save.pages.ch01_p01?.panels.p3, { timeout: 15_000 }).toEqual([416, 40]);
  await expect(page.locator("[data-cloud]")).toHaveText("Saved online");

  // Another browser: nothing saved locally, so it takes the cloud save.
  const other = await browser.newContext({ viewport: VIEWPORT });
  const page2 = await other.newPage();
  await record(page2);
  await signIn(page2, email);
  await play(page2);
  await expect.poll(async () => (await localSave(page2))?.pages?.ch01_p01?.panels?.p3, { timeout: 15_000 }).toEqual([416, 40]);
  // The title now offers CONTINUE, which resumes the moved panel.
  await newGame(page2);
  await page2.evaluate(() => {
    const b = (window as unknown as { TheMarginBridge: { deliver: (j: string) => void } }).TheMarginBridge;
    b.deliver(JSON.stringify({ v: 1, type: "REQUEST_SAVE", payload: {} }));
  });
  await expect
    .poll(async () => {
      const saves = (await messages(page2)).filter((m) => m.type === "SAVE_UPDATED");
      const last = saves.at(-1);
      return last?.type === "SAVE_UPDATED" ? last.payload.save.pages.ch01_p01?.panels.p3 : undefined;
    })
    .toEqual([416, 40]);
  await other.close();
});

test("play offline syncs once the browser is back online", async ({ page, context }) => {
  await record(page);
  await signUp(page);
  await play(page);
  await newGame(page);
  await expect.poll(async () => (await cloudSave(context))?.revision ?? 0, { timeout: 15_000 }).toBeGreaterThan(0);

  await context.setOffline(true);
  await slideP3(page, 24);
  await expect(page.locator("[data-cloud]")).toHaveAttribute("data-cloud", "offline", { timeout: 15_000 });
  await expect(page.locator("[data-cloud]")).toHaveText("Offline: saved here, will sync");
  // Still playing offline: more progress, kept locally.
  await slideP3(page, 32);
  await page.waitForTimeout(500);
  expect((await localSave(page)).pages.ch01_p01.panels.p3).toEqual([416, 72]);

  await context.setOffline(false);
  await expect(page.locator("[data-cloud]")).toHaveAttribute("data-cloud", "synced", { timeout: 20_000 });
  expect((await cloudSave(context))?.save.pages.ch01_p01.panels.p3).toEqual([416, 72]);
});

test("a conflict with more progress elsewhere loads the cloud save into the game", async ({ page, context }) => {
  await record(page);
  await signUp(page);
  await play(page);
  await newGame(page);
  await expect.poll(async () => (await cloudSave(context))?.revision ?? 0, { timeout: 15_000 }).toBeGreaterThan(0);
  // Another device gets further (straight through the API).
  const cloud = (await cloudSave(context))!;
  const elsewhere: Save = {
    ...cloud.save,
    revision: cloud.save.revision + 5,
    progress: { ...cloud.save.progress, page: "ch01_p03", completedPages: ["ch01_p01", "ch01_p02"] },
    pages: {},
  };
  const { csrfToken } = await (await context.request.get("http://localhost:3000/v1/auth/session")).json();
  const put = await context.request.put("http://localhost:3000/v1/saves/main", {
    headers: { "x-csrf-token": csrfToken, origin: "http://localhost:3000" },
    data: { baseRevision: cloud.revision, save: elsewhere },
  });
  expect(put.status()).toBe(200);

  // This browser plays on from its stale base; its next save conflicts and loses.
  await slideP3(page, 24);
  await expect.poll(async () => (await localSave(page)).progress.page, { timeout: 15_000 }).toBe("ch01_p03");
  await expect(page.locator("[data-cloud]")).toHaveAttribute("data-cloud", "synced");
  expect((await localSave(page)).progress.completedPages).toEqual(["ch01_p01", "ch01_p02"]);
  // The game reloaded onto the winning page.
  await waitFor(page, (m) => m.type === "SAVE_UPDATED" && m.payload.save.progress.page === "ch01_p03", 15_000);
});
