import { test } from "node:test";
import assert from "node:assert/strict";
import type { ClientErrorReport } from "@the-margin/contracts";
import { ClientErrorsRequestSchema } from "@the-margin/contracts";
import { GameErrorLines, isNoise, Reporter } from "./report.ts";

const collect = () => {
  const batches: ClientErrorReport[][] = [];
  const r = new Reporter((b) => batches.push(b), () => "/play", 10);
  return { r, batches };
};

test("each distinct error is sent once per page, batched, in the API's shape", async () => {
  const { r, batches } = collect();
  r.report("site", "TypeError: boom", "at a (x.js:1:1)");
  r.report("site", "TypeError: boom", "at a (x.js:1:1)");
  r.report("engine", "TypeError: boom");
  await new Promise((res) => setTimeout(res, 30));
  assert.equal(batches.length, 1);
  assert.deepEqual(batches[0].map((b) => b.source), ["site", "engine"]);
  assert.ok(ClientErrorsRequestSchema.safeParse({ reports: batches[0] }).success);
  assert.equal(batches[0][0].path, "/play");
});

test("ten fill a batch at once; a page sends at most twenty", () => {
  const { r, batches } = collect();
  for (let i = 0; i < 25; i++) r.report("site", `error ${i}`);
  r.flush();
  assert.deepEqual(batches.map((b) => b.length), [10, 10]);
});

test("extension errors and ResizeObserver warnings are not ours", () => {
  assert.ok(isNoise("ResizeObserver loop completed with undelivered notifications."));
  assert.ok(isNoise("x", "at f (chrome-extension://abc/content.js:1:1)"));
  assert.ok(!isNoise("TypeError: x", "at f (https://site/_next/x.js:1:1)"));
  const { r, batches } = collect();
  r.report("site", "ResizeObserver loop limit exceeded");
  r.flush();
  assert.equal(batches.length, 0);
});

test("the game's stderr becomes one report per error, with its at: lines; warnings are skipped", async () => {
  const out: [string, string][] = [];
  const lines = new GameErrorLines((m, s) => out.push([m, s]));
  lines.line("WARNING: something minor");
  lines.line("   at: warn (res://a.gd:1)");
  lines.line("SCRIPT ERROR: Invalid call. Nonexistent function 'foo'.");
  lines.line("   at: _ready (res://scripts/page.gd:12)");
  lines.line("ERROR: Condition failed.");
  lines.line("   at: thing (core/x.cpp:5)");
  await Promise.resolve();
  assert.deepEqual(out, [
    ["SCRIPT ERROR: Invalid call. Nonexistent function 'foo'.", "at: _ready (res://scripts/page.gd:12)"],
    ["ERROR: Condition failed.", "at: thing (core/x.cpp:5)"],
  ]);
});
