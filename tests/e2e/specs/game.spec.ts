import { test, expect, type Page } from "@playwright/test";
import { GameToWebSchema, type GameToWeb, type Save } from "@the-margin/contracts";

// The game renders a 640×360 page at integer scale; the 1280×720 viewport
// gives exactly ×2, so page coordinates map to screen pixels by doubling.
const S = 2;

type Msg = GameToWeb;

async function boot(page: Page): Promise<void> {
  await page.addInitScript(() => {
    const w = window as unknown as { TheMarginBridge: unknown; __msgs: unknown[] };
    w.__msgs = [];
    w.TheMarginBridge = {
      _inbox: [],
      onGameMessage(json: string) {
        w.__msgs.push(JSON.parse(json));
      },
    };
  });
  // Godot reports missing browser features (e.g. WebGL2) on the console and
  // never starts; surface that immediately instead of timing out.
  let unsupported = "";
  page.on("console", (m) => {
    if (m.type() === "error" && m.text().includes("required to run Godot")) unsupported = m.text();
  });
  await page.goto("/");
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    if (unsupported) throw new Error(`Browser cannot run the game: ${unsupported}`);
    if ((await messages(page)).some((m) => m.type === "GAME_READY")) return;
    await page.waitForTimeout(100);
  }
  throw new Error("Timed out waiting for GAME_READY");
}

async function messages(page: Page): Promise<Msg[]> {
  const raw = (await page.evaluate(() => (window as unknown as { __msgs: unknown[] }).__msgs)) as unknown[];
  // Every message the game sends must satisfy the shared contract.
  return raw.map((m) => GameToWebSchema.parse(m));
}

async function waitFor(page: Page, pred: (m: Msg) => boolean, timeout = 15_000): Promise<Msg> {
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const hit = (await messages(page)).find(pred);
    if (hit) return hit;
    await page.waitForTimeout(100);
  }
  throw new Error("Timed out waiting for a game message");
}

async function lastSave(page: Page): Promise<Save | undefined> {
  const saves = (await messages(page)).filter((m) => m.type === "SAVE_UPDATED");
  const last = saves.at(-1);
  return last && last.type === "SAVE_UPDATED" ? last.payload.save : undefined;
}

async function hold(page: Page, key: string, ms: number): Promise<void> {
  await page.keyboard.down(key);
  await page.waitForTimeout(ms);
  await page.keyboard.up(key);
}

/** Walk right in short steps, pressing E, until `done` holds for the latest save. */
// A key tap moves Nib further than its hold time suggests (input latency +
// frame timing: ~27 px for a 70 ms hold), so taps stay short to never stride
// past a 52 px reach window.
async function walkAndInteract(page: Page, label: string, done: (s: Save) => boolean, shot: string, steps = 120): Promise<void> {
  for (let i = 0; i < steps; i++) {
    const s = await lastSave(page);
    if (s && done(s)) return;
    await hold(page, "d", 25);
    await page.waitForTimeout(120);
    await page.keyboard.press("e");
    await page.waitForTimeout(150);
  }
  await page.screenshot({ path: shot });
  throw new Error(`Interaction never happened: ${label}`);
}

async function drag(page: Page, from: [number, number], to: [number, number]): Promise<void> {
  await page.mouse.move(from[0] * S, from[1] * S);
  await page.mouse.down();
  await page.mouse.move(to[0] * S, to[1] * S, { steps: 12 });
  await page.mouse.up();
  await page.waitForTimeout(250);
}

async function newGame(page: Page): Promise<void> {
  await page.mouse.click(20, 20); // focus the canvas without hitting the menu
  const ready = await waitFor(page, (m) => m.type === "GAME_READY");
  if (ready.type === "GAME_READY" && ready.payload.hasSave) {
    await page.keyboard.press("ArrowDown"); // CONTINUE is first when a save exists
  }
  await page.keyboard.press("Enter");
  await waitFor(page, (m) => m.type === "GAME_STARTED");
  await page.waitForTimeout(400);
}

test.beforeEach(async ({ page }) => {
  page.on("pageerror", (e) => {
    throw e;
  });
});

test("boots to the title screen", async ({ page }, info) => {
  await boot(page);
  await page.waitForTimeout(500);
  await page.screenshot({ path: info.outputPath("title.png") });
  const ready = (await messages(page)).find((m) => m.type === "GAME_READY");
  expect(ready).toBeTruthy();
});

test("page 1 can be solved with keyboard and mouse", async ({ page }, info) => {
  await boot(page);
  await newGame(page);
  await page.screenshot({ path: info.outputPath("page1-start.png") });

  // Walk across the first gutter until the sealed border to P3 stops Nib.
  await hold(page, "d", 5200);

  // The reader's hand: slide P3 (centre 520,76) down 24 px so the floors line up.
  await drag(page, [520, 76], [520, 100]);
  await waitFor(page, (m) => m.type === "ACHIEVEMENT_UNLOCKED" && m.payload.code === "FIRST_SLIDE", 8000);
  await page.screenshot({ path: info.outputPath("page1-linked.png") });

  // Walk to the neighbour and lift OPEN out of the sentence.
  await walkAndInteract(page, "take OPEN", (s) => s.player.carrying === "OPEN", info.outputPath("fail-take.png"));
  await page.screenshot({ path: info.outputPath("page1-carrying.png") });

  // Ride P3 down (centre now 520,100) until its pit meets P5, then walk off into it.
  await drag(page, [520, 100], [520, 132]);
  const afterRide = await lastSave(page);
  expect(afterRide?.pages.ch01_p01.panels.p3).toEqual([416, 72]);

  // Walk off into the pit and drop into P5 before pressing E again; next to
  // the neighbour, E would put OPEN back into the sentence gap.
  await hold(page, "d", 1600);
  await page.waitForTimeout(600);

  // Swap OPEN onto the door.
  await walkAndInteract(page, "swap onto door", (s) => s.pages.ch01_p01?.slots["door1:label"] === "OPEN", info.outputPath("fail-door.png"), 90);
  expect((await lastSave(page))?.player.carrying).toBe("SHUT");
  await page.screenshot({ path: info.outputPath("page1-door-open.png") });

  // Walk through the door; the page turns.
  await page.keyboard.down("d");
  await waitFor(page, (m) => m.type === "PAGE_COMPLETED" && m.payload.pageId === "ch01_p01", 10_000);
  await page.keyboard.up("d");
  await page.waitForTimeout(1200);
  await page.screenshot({ path: info.outputPath("page2-arrival.png") });

  // The artist writes on page 2, then turns the page to page 3 themselves.
  await waitFor(page, (m) => m.type === "PAGE_COMPLETED" && m.payload.pageId === "ch01_p02", 15_000);
  await page.waitForTimeout(1500);
  await page.screenshot({ path: info.outputPath("page3-arrival.png") });
  const save = await lastSave(page);
  expect(save?.progress.completedPages).toEqual(expect.arrayContaining(["ch01_p01", "ch01_p02"]));
  expect(save?.progress.page).toBe("ch01_p03");
  const codes = (await messages(page)).flatMap((m) => (m.type === "ACHIEVEMENT_UNLOCKED" ? [m.payload.code] : []));
  expect(codes).toEqual(expect.arrayContaining(["FIRST_SLIDE", "FIRST_WORD"]));
});

test("progress survives a browser reload", async ({ page }, info) => {
  await boot(page);
  await newGame(page);
  await drag(page, [520, 76], [520, 100]);
  await waitFor(page, (m) => m.type === "SAVE_UPDATED" && m.payload.save.pages.ch01_p01?.panels.p3?.[1] === 40);
  // Reload immediately: user:// reaches IndexedDB asynchronously, so this
  // only passes because saves are also mirrored synchronously to localStorage.
  await page.reload();
  await waitFor(page, (m) => m.type === "GAME_READY", 90_000);
  const ready = (await messages(page)).find((m) => m.type === "GAME_READY");
  expect(ready?.type === "GAME_READY" && ready.payload.hasSave).toBe(true);

  await page.mouse.click(20, 20);
  await page.keyboard.press("Enter"); // CONTINUE
  await waitFor(page, (m) => m.type === "GAME_STARTED");
  await page.waitForTimeout(500);
  await page.screenshot({ path: info.outputPath("restored.png") });
  // Ask the game for a fresh save through the bridge: it must reflect the restored world.
  await page.evaluate(() => {
    const b = (window as unknown as { TheMarginBridge: { deliver: (j: string) => void } }).TheMarginBridge;
    b.deliver(JSON.stringify({ v: 1, type: "REQUEST_SAVE", payload: {} }));
  });
  await page.waitForTimeout(300);
  expect((await lastSave(page))?.pages.ch01_p01.panels.p3).toEqual([416, 40]);
});

test("keyboard panel mode moves a panel without moving Nib", async ({ page }) => {
  await boot(page);
  await newGame(page);
  const requestSave = () =>
    page.evaluate(() => {
      const b = (window as unknown as { TheMarginBridge: { deliver: (j: string) => void } }).TheMarginBridge;
      b.deliver(JSON.stringify({ v: 1, type: "REQUEST_SAVE", payload: {} }));
    });
  await requestSave();
  await page.waitForTimeout(300);
  const before = (await lastSave(page))?.player.position;

  // Q selects P3 (the only lifted panel); S slides it one grid step at a time.
  await page.keyboard.press("q");
  for (let i = 0; i < 3; i++) {
    await page.keyboard.press("s");
    await page.waitForTimeout(100);
  }
  await page.keyboard.press("q"); // put it down
  await waitFor(page, (m) => m.type === "ACHIEVEMENT_UNLOCKED" && m.payload.code === "FIRST_SLIDE", 8000);

  await requestSave();
  await page.waitForTimeout(300);
  const save = await lastSave(page);
  expect(save?.pages.ch01_p01.panels.p3).toEqual([416, 40]);
  // While a panel is selected the direction keys belong to the panel, not to Nib.
  expect(save?.player.position).toEqual(before);
});
