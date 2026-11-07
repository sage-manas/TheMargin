// The site's mirror of the game's settings. The game sends SETTINGS_UPDATED
// whenever they change (including from its own pause menu); the settings page
// edits the mirror, and the launcher sends it to the game at start.
import { SettingsSchema, type Settings } from "@the-margin/contracts";
import { readItem, writeItem, type KeyValueStore } from "./storage.ts";

export const SETTINGS_KEY = "the-margin.settings";

export function readSettings(store: KeyValueStore | null): Settings | null {
  const text = readItem(store, SETTINGS_KEY);
  if (!text) return null;
  try {
    const r = SettingsSchema.safeParse(JSON.parse(text));
    return r.success ? r.data : null;
  } catch {
    return null;
  }
}

export function writeSettings(store: KeyValueStore | null, settings: Settings): boolean {
  return writeItem(store, SETTINGS_KEY, JSON.stringify(SettingsSchema.parse(settings)));
}
