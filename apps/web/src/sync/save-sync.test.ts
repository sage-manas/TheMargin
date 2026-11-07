import { test } from "node:test";
import assert from "node:assert/strict";
import type { CloudSave, Save } from "@the-margin/contracts";
import { ApiError, NetworkError } from "../lib/api.ts";
import { RETRY_MAX_MS, RETRY_MIN_MS, SaveSync, type SyncState, type Transport } from "./save-sync.ts";

/** An in-memory cloud with the API's rules: compare-and-swap writes, 409 with the server copy. */
class FakeCloud implements Transport {
  main: CloudSave | null = null;
  backups: Save[] = [];
  offline = false;
  status: number | null = null;
  puts = 0;

  private check(): void {
    if (this.offline) throw new NetworkError("Failed to fetch");
    if (this.status) throw new ApiError(this.status, this.status === 401 ? "UNAUTHENTICATED" : "INTERNAL", "nope");
  }
  async getSave() {
    this.check();
    return this.main && structuredClone(this.main);
  }
  async putSave(base: number | null, save: Save) {
    this.check();
    this.puts++;
    const current = this.main?.revision ?? null;
    if (base !== current) throw new ApiError(409, "SAVE_CONFLICT", "conflict", { server: structuredClone(this.main) });
    this.main = { revision: (current ?? 0) + 1, save: structuredClone(save), updatedAt: "2026-11-07T12:00:00.000Z" };
    return { revision: this.main.revision };
  }
  async putBackup(_ts: number, save: Save) {
    this.check();
    this.backups.push(structuredClone(save));
    return {};
  }
}

/** A device: its own sync state, timers and game. */
function device(cloud: FakeCloud, stored: SyncState | null = null, userId = "u1") {
  let state = stored;
  const loaded: Save[] = [];
  const timers: { fn: () => void; ms: number }[] = [];
  const statuses: string[] = [];
  const sync = new SaveSync({
    userId,
    transport: cloud,
    store: { read: () => state, write: (s) => (state = s) },
    loadIntoGame: (s) => loaded.push(s),
    onStatus: (s) => statuses.push(s),
    now: () => 1_700_000_000_000,
    setTimer: (fn, ms) => {
      const t = { fn, ms };
      timers.push(t);
      return t;
    },
    clearTimer: (t) => timers.splice(timers.indexOf(t as never), 1),
  });
  return {
    sync,
    loaded,
    timers,
    statuses,
    state: () => state,
    /** Fires the next retry timer and waits for it to finish. */
    async tick() {
      const t = timers.shift();
      assert.ok(t, "a retry is scheduled");
      t.fn();
      await settle();
      return t.ms;
    },
  };
}

const settle = () => new Promise((r) => setTimeout(r, 5));

function save(pages: string[] = [], extra: Partial<Save> = {}): Save {
  return {
    schema: "the-margin.save",
    version: 1,
    revision: pages.length + 1,
    updatedAt: `2026-11-07T10:0${pages.length}:00Z`,
    playtimeSec: 10 * pages.length,
    progress: { chapter: "ch01", page: `ch01_p0${pages.length + 1}`, completedPages: pages, completedChapters: [], abilities: [], flags: {} },
    player: { position: null, carrying: null },
    pages: {},
    ...extra,
  };
}

test("first sync uploads this browser's save", async () => {
  const cloud = new FakeCloud();
  const d = device(cloud);
  await d.sync.start(save(["ch01_p01"]));
  assert.equal(cloud.main?.revision, 1);
  assert.deepEqual(cloud.main?.save.progress.completedPages, ["ch01_p01"]);
  assert.deepEqual(d.state(), { userId: "u1", cloudRevision: 1, pending: false });
  assert.equal(d.sync.status, "synced");
});

test("a new device continues from the cloud", async () => {
  const cloud = new FakeCloud();
  await device(cloud).sync.start(save(["ch01_p01", "ch01_p02"]));
  const fresh = device(cloud);
  await fresh.sync.start(null);
  assert.equal(fresh.loaded.length, 1);
  assert.equal(fresh.loaded[0].progress.page, "ch01_p03");
  assert.equal(fresh.state()?.cloudRevision, 1);
  assert.equal(cloud.puts, 1, "nothing written back");
});

test("each local save is pushed on the revision it was based on", async () => {
  const cloud = new FakeCloud();
  const d = device(cloud);
  await d.sync.start(null);
  d.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  d.sync.saveUpdated(save(["ch01_p01", "ch01_p02"]));
  await settle();
  assert.equal(cloud.main?.revision, 2);
  assert.equal(d.state()?.pending, false);
  assert.equal(cloud.backups.length, 0);
});

test("offline: retries back off from 2 s to 5 min, then online sends only the latest save", async () => {
  const cloud = new FakeCloud();
  const d = device(cloud);
  await d.sync.start(save());
  cloud.offline = true;
  d.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  assert.equal(d.sync.status, "offline");
  assert.equal(d.state()?.pending, true);
  // More play while offline: absorbed by the scheduled retry, not raced.
  d.sync.saveUpdated(save(["ch01_p01", "ch01_p02"]));
  d.sync.saveUpdated(save(["ch01_p01", "ch01_p02", "ch01_p03"]));
  await settle();
  assert.equal(d.timers.length, 1);
  const delays: number[] = [];
  for (let i = 0; i < 10; i++) delays.push(await d.tick());
  assert.deepEqual(delays, [2, 4, 8, 16, 32, 64, 128, 256, 300, 300].map((s) => s * 1000));
  assert.equal(RETRY_MIN_MS, 2000);
  assert.equal(RETRY_MAX_MS, 300_000);
  assert.equal(cloud.puts, 1, "only the first upload reached the cloud");

  cloud.offline = false;
  d.sync.online();
  await settle();
  assert.equal(d.sync.status, "synced");
  assert.equal(cloud.puts, 2, "one push for all the offline play");
  assert.deepEqual(cloud.main?.save.progress.completedPages, ["ch01_p01", "ch01_p02", "ch01_p03"]);
  assert.deepEqual(d.state(), { userId: "u1", cloudRevision: 2, pending: false });
  assert.equal(d.timers.length, 0);
});

test("offline at start: the pending save survives a reload and syncs on the next visit", async () => {
  const cloud = new FakeCloud();
  const first = device(cloud);
  await first.sync.start(save());
  cloud.offline = true;
  first.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  first.sync.stop(); // the tab closes
  cloud.offline = false;
  const next = device(cloud, first.state());
  await next.sync.start(save(["ch01_p01"]));
  assert.equal(cloud.main?.revision, 2);
  assert.equal(next.loaded.length, 0);
  assert.equal(cloud.backups.length, 0);
});

test("conflict: the cloud has more progress, so it wins and the local save is backed up", async () => {
  const cloud = new FakeCloud();
  const a = device(cloud);
  const b = device(cloud);
  await a.sync.start(save());
  await b.sync.start(save());
  // A plays on; B, offline, plays less.
  a.sync.saveUpdated(save(["ch01_p01", "ch01_p02", "ch01_p03"]));
  await settle();
  b.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  assert.equal(b.loaded.length, 1);
  assert.deepEqual(b.loaded[0].progress.completedPages, ["ch01_p01", "ch01_p02", "ch01_p03"]);
  assert.equal(b.loaded[0].revision, 5, "max(local, server) + 1");
  assert.deepEqual(cloud.backups.map((s) => s.progress.completedPages), [["ch01_p01"]]);
  assert.deepEqual(b.state(), { userId: "u1", cloudRevision: 2, pending: false });
  assert.equal(cloud.main?.revision, 2, "the cloud copy is untouched");
});

test("conflict: the local save has more progress, so it wins and the cloud copy is backed up", async () => {
  const cloud = new FakeCloud();
  const a = device(cloud);
  const b = device(cloud);
  await a.sync.start(save());
  await b.sync.start(save());
  a.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  b.sync.saveUpdated(save(["ch01_p01", "ch01_p02", "ch01_p03", "ch01_p04"]));
  await settle();
  assert.equal(b.loaded.length, 0, "B keeps playing its own save");
  assert.deepEqual(cloud.main?.save.progress.completedPages, ["ch01_p01", "ch01_p02", "ch01_p03", "ch01_p04"]);
  assert.equal(cloud.main?.revision, 3);
  assert.deepEqual(cloud.backups.map((s) => s.progress.completedPages), [["ch01_p01"]]);
  assert.deepEqual(b.state(), { userId: "u1", cloudRevision: 3, pending: false });
});

test("a device that synced long ago reconciles on start rather than overwriting", async () => {
  const cloud = new FakeCloud();
  const old = device(cloud);
  await old.sync.start(save());
  const stale = old.state();
  const other = device(cloud);
  await other.sync.start(null);
  other.sync.saveUpdated(save(["ch01_p01", "ch01_p02"]));
  await settle();
  // The old device returns with its revision-1 view and a different save.
  const back = device(cloud, stale);
  await back.sync.start(save(["ch01_p01"], { updatedAt: "2026-11-07T11:00:00Z" }));
  assert.deepEqual(back.loaded[0].progress.completedPages, ["ch01_p01", "ch01_p02"]);
  assert.equal(cloud.backups.length, 1);
});

test("an identical save in the cloud (keys in another order) is not a conflict", async () => {
  const cloud = new FakeCloud();
  const s = save(["ch01_p01"]);
  const reordered = JSON.parse(JSON.stringify({ pages: s.pages, player: s.player, progress: s.progress, playtimeSec: s.playtimeSec, updatedAt: s.updatedAt, revision: s.revision, version: s.version, schema: s.schema }));
  cloud.main = { revision: 4, save: reordered, updatedAt: "2026-11-07T12:00:00.000Z" };
  const d = device(cloud);
  await d.sync.start(s);
  assert.deepEqual([cloud.puts, cloud.backups.length, d.loaded.length], [0, 0, 0]);
  assert.equal(d.state()?.cloudRevision, 4);
});

test("another account on this browser starts from scratch", async () => {
  const cloud = new FakeCloud();
  const d = device(cloud, { userId: "someone-else", cloudRevision: 7, pending: false }, "u1");
  await d.sync.start(save());
  assert.deepEqual(d.state(), { userId: "u1", cloudRevision: 1, pending: false });
});

test("signed out (401) stops syncing; server errors retry; bad saves don't", async () => {
  const cloud = new FakeCloud();
  const d = device(cloud);
  await d.sync.start(save());
  cloud.status = 503;
  d.sync.saveUpdated(save(["ch01_p01"]));
  await settle();
  assert.equal(d.sync.status, "offline");
  cloud.status = 401;
  await d.tick();
  assert.equal(d.sync.status, "signed-out");
  assert.equal(d.timers.length, 0);
  d.sync.saveUpdated(save(["ch01_p01", "ch01_p02"]));
  await settle();
  assert.equal(cloud.puts, 1, "nothing more is sent");

  const e = device(new FakeCloud());
  const bad = new FakeCloud();
  bad.putSave = async () => {
    throw new ApiError(422, "UNSUPPORTED_SAVE_VERSION", "newer");
  };
  const f = device(bad);
  await f.sync.start(save());
  assert.equal(f.sync.status, "error");
  assert.equal(f.timers.length, 0);
  assert.equal(e.timers.length, 0);
});
