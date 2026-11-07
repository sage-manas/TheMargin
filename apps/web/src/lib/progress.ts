// Reads where the player is from the game's local save mirror. Read-only:
// only the game writes saves (cloud sync arrives with the API in Phase 6).
// This is for display, so it checks just the fields it shows rather than
// pulling the full Zod save schema into every page.
import type { Save } from "@the-margin/contracts";
import { CHAPTERS, pageLabel, type Chapter } from "@the-margin/contracts/chapters";
import { LOCAL_SAVE_KEY } from "@the-margin/contracts/keys";
import { readItem, type KeyValueStore } from "./storage.ts";

export type SaveProgress = Pick<Save["progress"], "page" | "completedPages" | "completedChapters">;

const PAGE_ID = /^ch\d\d_p\d\d$/;
const CHAPTER_ID = /^ch\d\d$/;
const ids = (v: unknown, re: RegExp): v is string[] => Array.isArray(v) && v.every((x) => typeof x === "string" && re.test(x));

export function readLocalProgress(store: KeyValueStore | null): SaveProgress | null {
  const text = readItem(store, LOCAL_SAVE_KEY);
  if (!text) return null;
  try {
    const save = JSON.parse(text);
    const p = save?.progress;
    if (save?.schema !== "the-margin.save" || save.version !== 1 || typeof p?.page !== "string" || !PAGE_ID.test(p.page)) return null;
    if (!ids(p.completedPages, PAGE_ID) || !ids(p.completedChapters, CHAPTER_ID)) return null;
    return { page: p.page, completedPages: p.completedPages, completedChapters: p.completedChapters };
  } catch {
    return null;
  }
}

export type ChapterProgress =
  | { status: "unreleased" }
  | { status: "not-started" }
  | { status: "in-progress"; pagesDone: number; currentPage: string }
  | { status: "completed" };

export function chapterProgress(progress: SaveProgress | null, chapter: Chapter): ChapterProgress {
  if (!chapter.released) return { status: "unreleased" };
  if (!progress) return { status: "not-started" };
  if (progress.completedChapters.includes(chapter.id)) return { status: "completed" };
  const pagesDone = chapter.pages.filter((p) => progress.completedPages.includes(p)).length;
  const current = progress.page;
  if (pagesDone === 0 && !(chapter.pages.includes(current) && current !== chapter.pages[0])) {
    return { status: "not-started" };
  }
  return { status: "in-progress", pagesDone, currentPage: chapter.pages.includes(current) ? current : chapter.pages[0] };
}

/** "Continue · page 1.5", or null when there is nothing to continue. */
export function continueLabel(progress: SaveProgress | null): string | null {
  if (!progress) return null;
  const chapter = CHAPTERS.find((c) => c.pages.includes(progress.page));
  if (chapter && progress.completedChapters.includes(chapter.id)) return null;
  if (progress.completedPages.length === 0 && progress.page === CHAPTERS[0].pages[0]) return null;
  return `Continue · page ${pageLabel(progress.page)}`;
}
