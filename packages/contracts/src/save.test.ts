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
