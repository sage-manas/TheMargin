// The chapter catalogue (GDD §5). Page ids must match apps/game/data/pages,
// which a contract test checks. The site lists chapters from this; the API's
// progression rules (a chapter must be released and its predecessor done)
// read it too.
export type Chapter = {
  id: string;
  number: number;
  title: string;
  /** Page ids in play order; empty until the chapter is built. */
  pages: string[];
  released: boolean;
};

export const CHAPTERS: readonly Chapter[] = [
  {
    id: "ch01",
    number: 1,
    title: "The Page",
    pages: ["ch01_p01", "ch01_p02", "ch01_p03", "ch01_p04", "ch01_p05", "ch01_p06", "ch01_p07", "ch01_p08"],
    released: true,
  },
  {
    id: "ch02",
    number: 2,
    title: "The Border",
    pages: ["ch02_p01", "ch02_p02", "ch02_p03", "ch02_p04", "ch02_p05", "ch02_p06", "ch02_p07", "ch02_p08"],
    released: true,
  },
  { id: "ch03", number: 3, title: "The Words", pages: [], released: false },
  { id: "ch04", number: 4, title: "The Eraser", pages: [], released: false },
  { id: "ch05", number: 5, title: "The Ink", pages: [], released: false },
  { id: "ch06", number: 6, title: "The Artist", pages: [], released: false },
  { id: "ch07", number: 7, title: "Beyond the Margin", pages: [], released: false },
];

/** "ch01_p05" → "1.5", the page numbering the game and GDD use. */
export function pageLabel(pageId: string): string {
  const m = /^ch(\d\d)_p(\d\d)$/.exec(pageId);
  return m ? `${Number(m[1])}.${Number(m[2])}` : pageId;
}
