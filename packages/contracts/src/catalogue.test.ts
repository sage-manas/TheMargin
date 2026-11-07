import { test } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { CHAPTERS, pageLabel } from "./chapters.ts";
import { DEFAULT_SETTINGS, SettingsPatchSchema, SettingsSchema } from "./settings.ts";
import { encodeWebMessage, parseGameMessage } from "./bridge.ts";
import { LOCAL_SAVE_KEY } from "./save.ts";

const pagesDir = join(import.meta.dirname, "../../../apps/game/data/pages");

test("released chapters list exactly the game's story pages, in order", () => {
  const files = readdirSync(pagesDir).filter((f) => /^ch\d\d_p\d\d\.json$/.test(f));
  for (const ch of CHAPTERS.filter((c) => c.released)) {
    const ids = files.map((f) => f.replace(".json", "")).filter((id) => id.startsWith(`${ch.id}_`)).sort();
    assert.deepEqual(ch.pages, ids, ch.id);
    // Each page turns to the next; the last one ends the chapter.
    ch.pages.forEach((id, i) => {
      const def = JSON.parse(readFileSync(join(pagesDir, `${id}.json`), "utf8"));
      assert.equal(def.chapter, ch.id, `${id} chapter`);
      assert.equal(def.number, i + 1, `${id} number`);
    });
  }
});

test("page labels", () => {
  assert.equal(pageLabel("ch01_p05"), "1.5");
  assert.equal(pageLabel("ch12_p10"), "12.10");
});

test("settings: defaults match the game and patches are validated", () => {
  const gd = readFileSync(join(import.meta.dirname, "../../../apps/game/autoload/settings.gd"), "utf8");
  const declared = (name: string) => Number(new RegExp(`var ${name} := ([0-9.]+)`).exec(gd)?.[1]);
  assert.equal(DEFAULT_SETTINGS.masterVolume, declared("master_volume"));
  assert.equal(DEFAULT_SETTINGS.sfxVolume, declared("sfx_volume"));
  assert.equal(DEFAULT_SETTINGS.musicVolume, declared("music_volume"));
  assert.ok(SettingsSchema.safeParse(DEFAULT_SETTINGS).success);
  assert.ok(SettingsPatchSchema.safeParse({ muted: true }).success);
  assert.ok(!SettingsPatchSchema.safeParse({ musicVolume: 2 }).success);
});

test("bridge: settings messages round-trip", () => {
  const msg = parseGameMessage(JSON.stringify({ v: 1, type: "SETTINGS_UPDATED", payload: { settings: DEFAULT_SETTINGS } }));
  assert.equal(msg.type, "SETTINGS_UPDATED");
  assert.throws(() => encodeWebMessage({ v: 1, type: "SET_SETTINGS", payload: { settings: { masterVolume: -1 } } }));
});

test("the local save key matches the game's localStorage mirror", () => {
  const gd = readFileSync(join(import.meta.dirname, "../../../apps/game/autoload/save_manager.gd"), "utf8");
  assert.equal(/const WEB_KEY := "([^"]+)"/.exec(gd)?.[1], LOCAL_SAVE_KEY);
});
