import { test } from "node:test";
import assert from "node:assert/strict";
import { DEFAULT_SETTINGS } from "@the-margin/contracts";
import { readSettings, writeSettings, SETTINGS_KEY } from "./settings.ts";
import type { KeyValueStore } from "./storage.ts";

function memory(): KeyValueStore & { items: Map<string, string> } {
  const items = new Map<string, string>();
  return { items, getItem: (k) => items.get(k) ?? null, setItem: (k, v) => void items.set(k, v), removeItem: (k) => void items.delete(k) };
}

test("settings round-trip and reject invalid values", () => {
  const s = memory();
  assert.equal(readSettings(s), null);
  assert.ok(writeSettings(s, { ...DEFAULT_SETTINGS, musicVolume: 0.25 }));
  assert.equal(readSettings(s)?.musicVolume, 0.25);
  s.items.set(SETTINGS_KEY, JSON.stringify({ ...DEFAULT_SETTINGS, musicVolume: 3 }));
  assert.equal(readSettings(s), null);
  assert.throws(() => writeSettings(s, { ...DEFAULT_SETTINGS, sfxVolume: -1 }));
  assert.equal(writeSettings(null, DEFAULT_SETTINGS), false);
});
