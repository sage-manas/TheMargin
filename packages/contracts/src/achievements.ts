// Achievement definitions (seeded into the API's `achievements` table). Codes
// the game emits must be listed here, which a contract test checks.
export type AchievementDef = { code: string; title: string; description: string; chapterId?: string };

export const ACHIEVEMENTS: readonly AchievementDef[] = [
  { code: "FIRST_SLIDE", title: "Reader's Hand", description: "Slide a panel for the first time." },
  { code: "FIRST_WORD", title: "Lifted", description: "Take a word out of a sentence." },
  { code: "WONT_SHUT", title: "Won't Shut", description: "Give a shut door a better word." },
  // Awarded by the API when a chapter is completed, not sent by the game.
  { code: "CH01_COMPLETE", title: "The End of the Page", description: "Finish Chapter 1.", chapterId: "ch01" },
];
