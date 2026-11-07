import { Injectable } from "@nestjs/common";
import { ApiError, notFound } from "../common/errors.js";
import { PrismaService } from "../common/prisma.service.js";

type Meta = { chapterId?: string };

@Injectable()
export class AchievementsService {
  constructor(private readonly db: PrismaService) {}

  async list(userId: string | null) {
    const defs = await this.db.achievement.findMany({ orderBy: { code: "asc" } });
    const unlocked = userId ? await this.db.playerAchievement.findMany({ where: { userId } }) : [];
    const at = new Map(unlocked.map((u) => [u.achievementId, u.unlockedAt]));
    return defs.map((d) => ({ code: d.code, title: d.title, description: d.description, unlockedAt: at.get(d.id)?.toISOString() ?? null }));
  }

  /** Idempotent. Chapter achievements are the server's to award. */
  async unlock(userId: string, code: string): Promise<{ code: string; unlockedAt: string }> {
    const def = await this.db.achievement.findUnique({ where: { code } });
    if (!def) throw notFound("That achievement");
    if ((def.metadata as Meta).chapterId) throw new ApiError("FORBIDDEN", "That achievement is awarded for finishing a chapter.");
    return { code, unlockedAt: (await this.grant(userId, def.id)).toISOString() };
  }

  async awardForChapter(userId: string, chapterId: string): Promise<void> {
    const defs = await this.db.achievement.findMany({ where: { metadata: { path: ["chapterId"], equals: chapterId } } });
    for (const d of defs) await this.grant(userId, d.id);
  }

  private async grant(userId: string, achievementId: string): Promise<Date> {
    const row = await this.db.playerAchievement.upsert({
      where: { userId_achievementId: { userId, achievementId } },
      create: { userId, achievementId },
      update: {},
    });
    return row.unlockedAt;
  }
}
