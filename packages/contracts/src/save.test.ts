import { test } from "node:test";
import assert from "node:assert/strict";
import { parseSave, progressScore, resolveConflict, type Save } from "./save.ts";
import { parseGameMessage } from "./bridge.ts";

const base = (): Save =>
  parseSave({
    schema: "the-margin.save",
    version: 1,
    revision: 3,
    updatedAt: "2026-11-02T10:00:00Z",
    playtimeSec: 60,
    progress: { chapter: "ch01", page: "ch01_p01", completedPages: [], completedChapters: [], abilities: [], flags: {} },
    player: { position: null, carrying: null },
    pages: {},
  });

test("rejects malformed saves", () => {
  assert.throws(() => parseSave({ ...base(), version: 2 }));
  assert.throws(() => parseSave({ ...base(), player: { position: null, carrying: "<b>" } }));
  assert.throws(() => parseSave({ ...base(), progress: { ...base().progress, page: "../x" } }));
});

test("progress score orders by chapters, pages, story beats", () => {
  const more = base();
  more.progress.completedPages = ["ch01_p01"];
  assert.ok(progressScore(more) > progressScore(base()));
});

test("conflict: more progress wins regardless of time; loser is returned", () => {
  const local = base();
  const remote = base();
  remote.progress.completedPages = ["ch01_p01"];
  local.updatedAt = "2026-11-02T12:00:00Z";
  const r = resolveConflict(local, remote);
  assert.equal(r.winnerSource, "remote");
  assert.equal(r.loser, local);
  assert.equal(r.winner.revision, 4);
});

test("conflict: ties broken by time, then revision — deterministic both ways", () => {
  const a = base();
  const b = base();
  b.updatedAt = "2026-11-02T11:00:00Z";
  assert.equal(resolveConflict(a, b).winnerSource, "remote");
  assert.equal(resolveConflict(b, a).winnerSource, "local");
  const c = { ...base(), revision: 9 };
  assert.equal(resolveConflict(c, base()).winnerSource, "local");
});

test("bridge messages are validated", () => {
  const ok = parseGameMessage(JSON.stringify({ v: 1, type: "GAME_READY", payload: { version: "0.2.0", hasSave: false } }));
  assert.equal(ok.type, "GAME_READY");
  assert.throws(() => parseGameMessage(JSON.stringify({ v: 2, type: "GAME_READY", payload: {} })));
  assert.throws(() => parseGameMessage(JSON.stringify({ v: 1, type: "HACK", payload: {} })));
});

test("crate positions are optional, so saves written before crates still parse", () => {
  const old = base();
  old.pages = { ch01_p01: { panels: {}, slots: {}, fired: [] } as never };
  assert.deepEqual(parseSave(old).pages.ch01_p01.objects, {});
  const withCrate = { ...base(), pages: { ch01_p01: { panels: {}, slots: {}, objects: { crate1: [40, 112] }, fired: [] } } };
  assert.deepEqual(parseSave(withCrate).pages.ch01_p01.objects, { crate1: [40, 112] });
  assert.throws(() => parseSave({ ...base(), pages: { ch01_p01: { objects: { crate1: [40.5, 112] } } } }));
});

test("pencil sketches are optional booleans; the eraser is an ability", () => {
  const old = base();
  old.pages = { ch01_p01: { panels: {}, slots: {}, fired: [] } as never };
  assert.deepEqual(parseSave(old).pages.ch01_p01.sketches, {});
  const erased = base();
  erased.progress.abilities = ["eraser"];
  erased.pages = { ch01_p01: { panels: {}, slots: {}, objects: {}, sketches: { wall: false, step1: true }, fired: [] } };
  const parsed = parseSave(erased);
  assert.deepEqual(parsed.pages.ch01_p01.sketches, { wall: false, step1: true });
  assert.deepEqual(parsed.progress.abilities, ["eraser"]);
  assert.throws(() => parseSave({ ...base(), pages: { ch01_p01: { sketches: { wall: "erased" } } } }));
});
