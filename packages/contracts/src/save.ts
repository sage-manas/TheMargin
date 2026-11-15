// Save envelope v1 — mirrors apps/game/autoload/save_manager.gd and
// docs/architecture/SAVE_SCHEMA.md. The e2e suite validates real saves
// emitted by the browser build against this schema.
import { z } from "zod";

export const SAVE_SCHEMA_TAG = "the-margin.save";
export const SAVE_VERSION = 1;
export const MAX_SAVE_BYTES = 65536;
export { LOCAL_SAVE_KEY } from "./keys.ts";

const pageId = z.string().regex(/^ch\d\d_p\d\d$/);
const wordId = z.string().regex(/^[A-Z]{1,12}$/);
const pagePoint = z.tuple([z.number().int().min(0).max(640), z.number().int().min(0).max(360)]);

export const PageStateSchema = z.object({
  panels: z.record(z.string(), pagePoint).default({}),
  slots: z.record(z.string(), wordId.nullable()).default({}),
  // Positions of self-moving objects (crates, platforms), panel-local. Optional
  // and defaulted, so version-1 saves written before crates still parse.
  objects: z.record(z.string(), pagePoint).default({}),
  // Pencil sketches: id -> drawn (false once rubbed out, "inked" once traced).
  // Crumbs and ink are derived from these and `collected`, never stored.
  // Optional, like `objects`.
  sketches: z.record(z.string(), z.union([z.boolean(), z.literal("inked")])).default({}),
  // Ink pickups already collected on the page.
  collected: z.array(z.string()).default([]),
  // Scene cards (GDD §4.7): card id -> the panel whose corner holds it.
  scenes: z.record(z.string(), z.string()).default({}),
  // Stretchable panels' sizes (GDD §4.10): panel id -> [width, height].
  sizes: z.record(z.string(), pagePoint).default({}),
  // Close-up controls (GDD §4.8): a lever's position, or a dial's digits.
  controls: z.record(z.string(), z.union([z.boolean(), z.string().regex(/^\d{1,8}$/)])).default({}),
  fired: z.array(z.string()).default([]),
});

export const SaveSchema = z.object({
  schema: z.literal(SAVE_SCHEMA_TAG),
  version: z.literal(SAVE_VERSION),
  revision: z.number().int().nonnegative(),
  updatedAt: z.string(),
  playtimeSec: z.number().int().nonnegative(),
  progress: z.object({
    chapter: z.string().regex(/^ch\d\d$/),
    page: pageId,
    completedPages: z.array(pageId),
    completedChapters: z.array(z.string().regex(/^ch\d\d$/)),
    abilities: z.array(z.string()),
    flags: z.record(z.string(), z.unknown()),
  }),
  player: z.object({
    position: pagePoint.nullable(),
    carrying: wordId.nullable(),
  }),
  pages: z.record(pageId, PageStateSchema),
});

export type Save = z.infer<typeof SaveSchema>;

export function parseSave(input: unknown): Save {
  if (JSON.stringify(input).length > MAX_SAVE_BYTES) {
    throw new Error("Save exceeds maximum size");
  }
  return SaveSchema.parse(input);
}

/** SAVE_SCHEMA §5: higher means more story progress. */
export function progressScore(save: Save): number {
  const fired = Object.values(save.pages).reduce((n, p) => n + p.fired.length, 0);
  return save.progress.completedChapters.length * 1000 + save.progress.completedPages.length * 10 + fired;
}

/**
 * Deterministic conflict resolution (SAVE_SCHEMA §5). Returns the winner and
 * the loser; callers must keep the loser as a backup, never discard it.
 */
export function resolveConflict(local: Save, remote: Save): { winner: Save; loser: Save; winnerSource: "local" | "remote" } {
  const byScore = progressScore(local) - progressScore(remote);
  const byTime = Date.parse(local.updatedAt) - Date.parse(remote.updatedAt);
  const byRevision = local.revision - remote.revision;
  const localWins = byScore !== 0 ? byScore > 0 : byTime !== 0 ? byTime > 0 : byRevision >= 0;
  const winner = localWins ? local : remote;
  const loser = localWins ? remote : local;
  return {
    winner: { ...winner, revision: Math.max(local.revision, remote.revision) + 1 },
    loser,
    winnerSource: localWins ? "local" : "remote",
  };
}
