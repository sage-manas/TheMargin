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

test("every achievement the game unlocks is defined", async () => {
  const { ACHIEVEMENTS } = await import("./achievements.ts");
  const root = join(import.meta.dirname, "../../../apps/game");
  const codes = new Set<string>();
  const walk = (dir: string) => {
    for (const e of readdirSync(dir, { withFileTypes: true })) {
      const p = join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (/\.(json|gd)$/.test(e.name)) for (const m of readFileSync(p, "utf8").matchAll(/"code": *"([A-Z][A-Z0-9_]*)"/g)) codes.add(m[1]);
    }
  };
  // Achievement codes start with a letter; combination-dial codes are digits.
  for (const d of ["data", "scripts", "autoload"]) walk(join(root, d));
  assert.ok(codes.size >= 3);
  for (const c of codes) assert.ok(ACHIEVEMENTS.some((a) => a.code === c), c);
});

test("api: requests normalise and validate", async () => {
  const { RegisterRequestSchema, ErrorEnvelopeSchema } = await import("./api.ts");
  assert.equal(RegisterRequestSchema.parse({ email: " Nib@Example.COM ", password: "0123456789", displayName: "Nib" }).email, "nib@example.com");
  assert.ok(!RegisterRequestSchema.safeParse({ email: "x", password: "short", displayName: "" }).success);
  assert.ok(ErrorEnvelopeSchema.safeParse({ error: { code: "SAVE_CONFLICT", message: "m" } }).success);
});

test("the game's chapter list matches the catalogue", () => {
  const game = JSON.parse(readFileSync(join(import.meta.dirname, "../../../apps/game/data/chapters.json"), "utf8")) as { id: string; number: number; title: string }[];
  assert.deepEqual(game.map((c) => [c.id, c.number, c.title]), CHAPTERS.map((c) => [c.id, c.number, c.title]));
});
