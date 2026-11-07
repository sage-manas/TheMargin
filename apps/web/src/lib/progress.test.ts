import { test } from "node:test";
import assert from "node:assert/strict";
import { CHAPTERS, LOCAL_SAVE_KEY, type Save } from "@the-margin/contracts";
import { chapterProgress, continueLabel, readLocalProgress } from "./progress.ts";
import type { KeyValueStore } from "./storage.ts";

const save = (progress: Partial<Save["progress"]> = {}): Save => ({
  schema: "the-margin.save",
  version: 1,
  revision: 1,
  updatedAt: "",
  playtimeSec: 0,
  progress: { chapter: "ch01", page: "ch01_p01", completedPages: [], completedChapters: [], abilities: [], flags: {}, ...progress },
  player: { position: null, carrying: null },
  pages: {},
});

const store = (items: Record<string, string>): KeyValueStore => ({
  getItem: (k) => items[k] ?? null,
  setItem: () => {},
  removeItem: () => {},
});

const ch1 = CHAPTERS[0];
const prog = (p: Partial<Save["progress"]> = {}) => save(p).progress;

test("reads only valid saves", () => {
  assert.equal(readLocalProgress(null), null);
  assert.equal(readLocalProgress(store({ [LOCAL_SAVE_KEY]: "{bad" })), null);
  assert.equal(readLocalProgress(store({ [LOCAL_SAVE_KEY]: JSON.stringify({ schema: "x" }) })), null);
  assert.equal(readLocalProgress(store({ [LOCAL_SAVE_KEY]: JSON.stringify({ ...save(), progress: { ...save().progress, page: "../x" } }) })), null);
  assert.equal(readLocalProgress(store({ [LOCAL_SAVE_KEY]: JSON.stringify({ ...save(), progress: { ...save().progress, completedPages: [1] } }) })), null);
  assert.equal(readLocalProgress(store({ [LOCAL_SAVE_KEY]: JSON.stringify(save()) }))?.page, "ch01_p01");
  const throwing: KeyValueStore = { getItem: () => { throw new Error("blocked"); }, setItem: () => {}, removeItem: () => {} };
  assert.equal(readLocalProgress(throwing), null);
});

test("chapter status", () => {
  assert.deepEqual(chapterProgress(null, ch1), { status: "not-started" });
  assert.deepEqual(chapterProgress(prog(), ch1), { status: "not-started" });
  assert.deepEqual(chapterProgress(prog({ page: "ch01_p05", completedPages: ["ch01_p01", "ch01_p02", "ch01_p03", "ch01_p04"] }), ch1), { status: "in-progress", pagesDone: 4, currentPage: "ch01_p05" });
  assert.deepEqual(chapterProgress(prog({ completedChapters: ["ch01"] }), ch1), { status: "completed" });
  assert.deepEqual(chapterProgress(prog(), CHAPTERS[1]), { status: "unreleased" });
});

test("continue label", () => {
  assert.equal(continueLabel(null), null);
  assert.equal(continueLabel(prog()), null);
  assert.equal(continueLabel(prog({ page: "ch01_p05", completedPages: ["ch01_p04"] })), "Continue · page 1.5");
  assert.equal(continueLabel(prog({ page: "ch01_p08", completedChapters: ["ch01"] })), null);
});
