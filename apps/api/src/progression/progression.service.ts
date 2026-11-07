// Chapter progression. The server enforces order (a chapter must be released
// and its predecessor completed) but doesn't check gameplay (TDD §6).
import { Injectable } from "@nestjs/common";
import type { Progression, Save } from "@the-margin/contracts";
import { ApiError, notFound } from "../common/errors.js";
import { PrismaService } from "../common/prisma.service.js";
import { AchievementsService } from "../achievements/achievements.service.js";

@Injectable()
export class ProgressionService {
  constructor(
    private readonly db: PrismaService,
    private readonly achievements: AchievementsService,
  ) {}

  async list(userId: string): Promise<Progression> {
    const [chapters, rows, main] = await Promise.all([
      this.db.chapter.findMany({ orderBy: { ordinal: "asc" } }),
      this.db.chapterProgress.findMany({ where: { userId } }),
      this.db.gameSave.findUnique({ where: { userId_slot: { userId, slot: "main" } }, select: { payload: true } }),
    ]);
    const byChapter = new Map(rows.map((r) => [r.chapterId, r]));
    // The chapter the cloud save is in counts as in progress.
    const playing = (main?.payload as Save | undefined)?.progress?.chapter;
    let previousDone = true;
    return chapters.map((c) => {
      const row = byChapter.get(c.id);
      const done = row?.status === "completed";
      const status = done ? "completed" : !c.released || !previousDone ? "locked" : row?.status === "in_progress" || playing === c.id ? "in_progress" : "available";
      previousDone = done;
      return { chapterId: c.id, title: c.title, status, completedAt: row?.completedAt?.toISOString() ?? null };
    });
  }

  async complete(userId: string, chapterId: string): Promise<Progression[number]> {
    const chapter = await this.db.chapter.findUnique({ where: { id: chapterId } });
    if (!chapter) throw notFound("That chapter");
    if (!chapter.released) throw new ApiError("FORBIDDEN", "That chapter hasn't been released.");
    const previous = await this.db.chapter.findUnique({ where: { ordinal: chapter.ordinal - 1 } });
    if (previous) {
      const p = await this.db.chapterProgress.findUnique({ where: { userId_chapterId: { userId, chapterId: previous.id } } });
      if (p?.status !== "completed") throw new ApiError("FORBIDDEN", "Finish the chapter before it first.");
    }
    const existing = await this.db.chapterProgress.findUnique({ where: { userId_chapterId: { userId, chapterId } } });
    // Idempotent: completing again keeps the first completion time.
    const completedAt = existing?.completedAt ?? new Date();
    await this.db.chapterProgress.upsert({
      where: { userId_chapterId: { userId, chapterId } },
      create: { userId, chapterId, status: "completed", completedAt },
      update: { status: "completed", completedAt },
    });
    await this.achievements.awardForChapter(userId, chapterId);
    return { chapterId, title: chapter.title, status: "completed", completedAt: completedAt.toISOString() };
  }
}
