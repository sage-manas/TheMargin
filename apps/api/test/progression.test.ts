import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { AchievementListSchema, DEFAULT_SETTINGS, ProgressionSchema } from "@the-margin/contracts";
import { Client, makeSave, startApi, type Api } from "./helpers.ts";

let api: Api;
before(async () => (api = await startApi()));
after(() => api.close());
beforeEach(() => api.reset());

async function player(): Promise<Client> {
  const c = new Client(api);
  await c.register();
  return c;
}

describe("progression", () => {
  test("chapter 1 is open, the rest locked until released and reached", async () => {
    const c = await player();
    const list = ProgressionSchema.parse((await c.req("GET", "/progression")).body);
    assert.equal(list.length, 7);
    assert.deepEqual(list.map((p) => p.status), ["available", "locked", "locked", "locked", "locked", "locked", "locked"]);
    assert.equal(list[0].title, "The Page");
  });

  test("a cloud save in chapter 1 shows it in progress", async () => {
    const c = await player();
    await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave({ page: "ch01_p03" }) });
    assert.equal((await c.req("GET", "/progression")).body[0].status, "in_progress");
  });

  test("completing is validated, idempotent, and awards the chapter achievement", async () => {
    const c = await player();
    const early = await c.req("POST", "/progression/ch02/complete");
    assert.equal(early.status, 403);
    assert.equal(early.body.error.code, "FORBIDDEN");
    assert.equal((await c.req("POST", "/progression/ch99/complete")).status, 404);
    const done = await c.req("POST", "/progression/ch01/complete");
    assert.equal(done.status, 200);
    assert.equal(done.body.status, "completed");
    const again = await c.req("POST", "/progression/ch01/complete");
    assert.equal(again.body.completedAt, done.body.completedAt);
    const list = (await c.req("GET", "/progression")).body;
    assert.equal(list[0].status, "completed");
    // Chapter 2 now follows a completed chapter, but isn't released yet.
    assert.equal(list[1].status, "locked");
    assert.equal((await c.req("POST", "/progression/ch02/complete")).status, 403);
    const ach = AchievementListSchema.parse((await c.req("GET", "/achievements")).body);
    assert.ok(ach.find((a) => a.code === "CH01_COMPLETE")?.unlockedAt);
  });
});

describe("achievements", () => {
  test("anyone can list the definitions; unlocks are per player and idempotent", async () => {
    const anon = new Client(api);
    const defs = AchievementListSchema.parse((await anon.req("GET", "/achievements")).body);
    assert.deepEqual(defs.map((d) => d.code).sort(), ["CH01_COMPLETE", "FIRST_SLIDE", "FIRST_WORD", "WONT_SHUT"]);
    assert.ok(defs.every((d) => d.unlockedAt === null));

    const c = await player();
    const first = await c.req("POST", "/achievements/FIRST_SLIDE/unlock");
    assert.equal(first.status, 200);
    const second = await c.req("POST", "/achievements/FIRST_SLIDE/unlock");
    assert.equal(second.body.unlockedAt, first.body.unlockedAt);
    assert.equal((await c.req("POST", "/achievements/NOPE/unlock")).status, 404);
    // Chapter achievements are the server's to award.
    assert.equal((await c.req("POST", "/achievements/CH01_COMPLETE/unlock")).status, 403);
    const mine = (await c.req("GET", "/achievements")).body as { code: string; unlockedAt: string | null }[];
    assert.deepEqual(mine.filter((a) => a.unlockedAt).map((a) => a.code), ["FIRST_SLIDE"]);
    // Another player's list is unaffected.
    const other = await player();
    assert.ok(((await other.req("GET", "/achievements")).body as { unlockedAt: null }[]).every((a) => a.unlockedAt === null));
  });
});

describe("settings", () => {
  test("default until set; replaced whole; validated", async () => {
    const c = await player();
    assert.deepEqual((await c.req("GET", "/settings")).body, DEFAULT_SETTINGS);
    const mine = { ...DEFAULT_SETTINGS, musicVolume: 0.25, reducedMotion: true };
    assert.deepEqual((await c.req("PUT", "/settings", mine)).body, mine);
    assert.deepEqual((await c.req("GET", "/settings")).body, mine);
    assert.equal((await c.req("PUT", "/settings", { ...mine, sfxVolume: 3 })).status, 400);
    assert.equal((await c.req("PUT", "/settings", { musicVolume: 0.5 })).status, 400);
  });
});
