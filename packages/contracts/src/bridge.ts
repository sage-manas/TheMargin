// Game ↔ web message contract (TDD §4). Every message is JSON
// `{ v: 1, type, payload }`. Mirrors apps/game/autoload/web_bridge.gd.
import { z } from "zod";
import { SaveSchema } from "./save.ts";
import { SettingsPatchSchema, SettingsSchema } from "./settings.ts";

export const BRIDGE_PROTOCOL = 1;

const envelope = <T extends string, P extends z.ZodTypeAny>(type: T, payload: P) =>
  z.object({ v: z.literal(BRIDGE_PROTOCOL), type: z.literal(type), payload });

export const GameToWebSchema = z.discriminatedUnion("type", [
  envelope("GAME_READY", z.object({ version: z.string(), hasSave: z.boolean() })),
  envelope("GAME_STARTED", z.object({ pageId: z.string() })),
  envelope("GAME_PAUSED", z.object({})),
  envelope("GAME_RESUMED", z.object({})),
  envelope("SAVE_UPDATED", z.object({ save: SaveSchema })),
  envelope("PAGE_COMPLETED", z.object({ pageId: z.string() })),
  envelope("CHAPTER_COMPLETED", z.object({ chapterId: z.string() })),
  // Sent once the bridge is up and whenever the settings change in the game.
  envelope("SETTINGS_UPDATED", z.object({ settings: SettingsSchema })),
  envelope("ACHIEVEMENT_UNLOCKED", z.object({ code: z.string().regex(/^[A-Z0-9_]{1,40}$/) })),
  envelope("GAME_EXITED", z.object({})),
  envelope("GAME_ERROR", z.object({ message: z.string() })),
]);

export const WebToGameSchema = z.discriminatedUnion("type", [
  envelope("LOAD_CLOUD_SAVE", z.object({ save: SaveSchema })),
  envelope("SET_SETTINGS", z.object({ settings: SettingsPatchSchema })),
  envelope("PAUSE", z.object({})),
  envelope("RESUME", z.object({})),
  envelope("REQUEST_SAVE", z.object({})),
]);

export type GameToWeb = z.infer<typeof GameToWebSchema>;
export type WebToGame = z.infer<typeof WebToGameSchema>;

export function parseGameMessage(json: string): GameToWeb {
  return GameToWebSchema.parse(JSON.parse(json));
}

export function encodeWebMessage(msg: WebToGame): string {
  return JSON.stringify(WebToGameSchema.parse(msg));
}
