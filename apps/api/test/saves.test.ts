import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { CloudSaveSchema, SaveConflictDetailsSchema } from "@the-margin/contracts";
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

describe("cloud saves", () => {
  test("need a session", async () => {
    const c = new Client(api);
    await c.session();
    assert.equal((await c.req("GET", "/saves/main")).status, 401);
    assert.equal((await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() })).status, 401);
  });

  test("first upload, read back, then compare-and-swap writes", async () => {
    const c = await player();
    assert.equal((await c.req("GET", "/saves/main")).body.error.code, "NOT_FOUND");
    const first = await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() });
    assert.deepEqual([first.status, first.body], [200, { revision: 1 }]);
    const got = CloudSaveSchema.parse((await c.req("GET", "/saves/main")).body);
    assert.equal(got.revision, 1);
    assert.deepEqual(got.save, makeSave());
    const next = await c.req("PUT", "/saves/main", { baseRevision: 1, save: makeSave({ page: "ch01_p02", completedPages: ["ch01_p01"] }, 2) });
    assert.deepEqual(next.body, { revision: 2 });
    assert.equal((await c.req("GET", "/saves/main")).body.save.progress.page, "ch01_p02");
  });

  test("a stale write gets 409 with the server's copy, and changes nothing", async () => {
    const c = await player();
    await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() });
    await c.req("PUT", "/saves/main", { baseRevision: 1, save: makeSave({ completedPages: ["ch01_p01"] }) });
    const stale = await c.req("PUT", "/saves/main", { baseRevision: 1, save: makeSave({ page: "ch01_p05" }) });
    assert.equal(stale.status, 409);
    assert.equal(stale.body.error.code, "SAVE_CONFLICT");
    const { server } = SaveConflictDetailsSchema.parse(stale.body.error.details);
    assert.equal(server.revision, 2);
    assert.deepEqual(server.save.progress.completedPages, ["ch01_p01"]);
    // A device that never synced can't blindly overwrite either.
    assert.equal((await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() })).status, 409);
    assert.equal((await c.req("GET", "/saves/main")).body.revision, 2);
  });

  test("two devices racing from the same base: exactly one wins", async () => {
    const c = await player();
    await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() });
    const results = await Promise.all(
      Array.from({ length: 6 }, (_, i) => c.req("PUT", "/saves/main", { baseRevision: 1, save: makeSave({ page: `ch01_p0${i + 2}` }) })),
    );
    assert.equal(results.filter((r) => r.status === 200).length, 1);
    assert.equal(results.filter((r) => r.status === 409).length, 5);
    assert.equal((await c.req("GET", "/saves/main")).body.revision, 2);
  });

  test("first uploads racing: exactly one creates the save", async () => {
    const c = await player();
    const results = await Promise.all(Array.from({ length: 4 }, () => c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() })));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 409, 409, 409]);
  });

  test("saves from a newer game are refused with 422; invalid or oversized ones with 400", async () => {
    const c = await player();
    const newer = await c.req("PUT", "/saves/main", { baseRevision: null, save: { ...makeSave(), version: 2, whatever: true } });
    assert.equal(newer.status, 422);
    assert.equal(newer.body.error.code, "UNSUPPORTED_SAVE_VERSION");
    const bad = await c.req("PUT", "/saves/main", { baseRevision: null, save: { ...makeSave(), player: { position: null, carrying: "<script>" } } });
    assert.equal(bad.status, 400);
    // Just under the body limit but over 64 KB of save: refused by the size check.
    const big = makeSave({ flags: { pad: "x".repeat(66_000) } });
    const tooBig = await c.req("PUT", "/saves/main", { baseRevision: null, save: big });
    assert.ok(tooBig.status === 400 || tooBig.status === 413, String(tooBig.status));
    assert.equal(tooBig.body.error.code, "VALIDATION_FAILED");
    const huge = await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave({ flags: { pad: "x".repeat(200_000) } }) });
    assert.equal(huge.status, 413);
    assert.equal((await c.req("GET", "/saves/main")).status, 404);
  });

  test("players can't see each other's saves", async () => {
    const a = await player();
    const b = await player();
    await a.req("PUT", "/saves/main", { baseRevision: null, save: makeSave({ page: "ch01_p07" }) });
    assert.equal((await b.req("GET", "/saves/main")).status, 404);
    assert.deepEqual((await b.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() })).body, { revision: 1 });
    assert.equal((await a.req("GET", "/saves/main")).body.save.progress.page, "ch01_p07");
  });

  test("conflict losers are kept as backups, newest 5 only", async () => {
    const c = await player();
    for (let i = 1; i <= 7; i++) {
      const r = await c.req("PUT", `/saves/backup-${1_700_000_000_000 + i}`, { save: makeSave({ playtimeSec: i } as never) });
      assert.equal(r.status, 200);
    }
    const { rows } = await api.db.query("SELECT slot FROM game_saves WHERE slot LIKE 'backup-%' ORDER BY slot");
    assert.deepEqual(rows.map((r) => r.slot), [3, 4, 5, 6, 7].map((i) => `backup-${1_700_000_000_000 + i}`));
    assert.equal((await c.req("PUT", "/saves/backup-abc", { save: makeSave() })).status, 400);
    // Backups never touch the main slot.
    assert.equal((await c.req("GET", "/saves/main")).status, 404);
  });

  test("deleting an account erases everything it owns", async () => {
    const c = await player();
    await c.req("PUT", "/saves/main", { baseRevision: null, save: makeSave() });
    await c.req("POST", "/achievements/FIRST_SLIDE/unlock");
    await api.db.query("DELETE FROM users");
    for (const t of ["sessions", "player_profiles", "game_saves", "player_achievements"]) {
      assert.equal((await api.db.query(`SELECT count(*)::int AS n FROM ${t}`)).rows[0].n, 0, t);
    }
  });
});
