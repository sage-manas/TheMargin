// Reference data: the chapter catalogue and achievement definitions, both from
// packages/contracts. Idempotent; run on every deploy (`pnpm seed`).
import { ACHIEVEMENTS, CHAPTERS } from "@the-margin/contracts";
import { PrismaClient } from "./generated/prisma/client.js";
import { pgAdapter } from "./common/db.js";

export async function seed(db: PrismaClient): Promise<void> {
  for (const c of CHAPTERS) {
    const data = { ordinal: c.number, title: c.title, released: c.released };
    await db.chapter.upsert({ where: { id: c.id }, create: { id: c.id, ...data }, update: data });
  }
  for (const a of ACHIEVEMENTS) {
    const data = { title: a.title, description: a.description, metadata: a.chapterId ? { chapterId: a.chapterId } : {} };
    await db.achievement.upsert({ where: { code: a.code }, create: { code: a.code, ...data }, update: data });
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (!process.env.DATABASE_URL) throw new Error("DATABASE_URL is required");
  const db = new PrismaClient({ adapter: pgAdapter(process.env.DATABASE_URL) });
  await seed(db);
  await db.$disconnect();
  console.log(`Seeded ${CHAPTERS.length} chapters and ${ACHIEVEMENTS.length} achievements.`);
}
