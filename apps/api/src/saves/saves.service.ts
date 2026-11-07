// Cloud saves (TDD §4.3, SAVE_SCHEMA §5). The server never merges: a write
// lands only if it was based on the current cloud revision (compare and
// swap), otherwise the client gets the server's copy and resolves the
// conflict itself, deterministically.
import { Injectable } from "@nestjs/common";
import { BACKUPS_KEPT, MAX_SAVE_BYTES, SAVE_VERSION, type CloudSave, type Save } from "@the-margin/contracts";
import { ApiError, notFound } from "../common/errors.js";
import { PrismaService } from "../common/prisma.service.js";
import { Prisma, type GameSave } from "../generated/prisma/client.js";

const MAIN = "main";

const toCloud = (row: GameSave): CloudSave => ({ revision: row.revision, save: row.payload as Save, updatedAt: row.updatedAt.toISOString() });

/** 422 for a save written by a newer game (checked before full validation, whose shape may differ). */
export function assertSupportedVersion(body: unknown): void {
  const v = (body as { save?: { version?: unknown } } | null)?.save?.version;
  if (typeof v === "number" && v > SAVE_VERSION) {
    throw new ApiError("UNSUPPORTED_SAVE_VERSION", `This save was made by a newer version of the game (v${v}).`, { supported: SAVE_VERSION });
  }
}

export function assertSize(save: Save): void {
  if (Buffer.byteLength(JSON.stringify(save)) > MAX_SAVE_BYTES) throw new ApiError("VALIDATION_FAILED", "The save is larger than 64 KB.");
}

@Injectable()
export class SavesService {
  constructor(private readonly db: PrismaService) {}

  async get(userId: string): Promise<CloudSave> {
    const row = await this.db.gameSave.findUnique({ where: { userId_slot: { userId, slot: MAIN } } });
    if (!row) throw notFound("A cloud save");
    return toCloud(row);
  }

  async put(userId: string, baseRevision: number | null, save: Save): Promise<number> {
    assertSize(save);
    const data = { saveVersion: save.version, payload: save as unknown as Prisma.InputJsonValue, clientUpdatedAt: parseDate(save.updatedAt) };
    if (baseRevision === null) {
      try {
        await this.db.gameSave.create({ data: { ...data, userId, slot: MAIN, revision: 1 } });
        return 1;
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") throw await this.conflict(userId);
        throw err;
      }
    }
    const { count } = await this.db.gameSave.updateMany({
      where: { userId, slot: MAIN, revision: baseRevision },
      data: { ...data, revision: baseRevision + 1 },
    });
    if (count === 0) throw await this.conflict(userId);
    return baseRevision + 1;
  }

  /** Keeps a conflict loser; only the newest BACKUPS_KEPT survive. */
  async backup(userId: string, ts: string, save: Save): Promise<string> {
    assertSize(save);
    const slot = `backup-${ts}`;
    const data = { saveVersion: save.version, payload: save as unknown as Prisma.InputJsonValue, clientUpdatedAt: parseDate(save.updatedAt), revision: 1 };
    await this.db.$transaction(async (tx) => {
      await tx.gameSave.upsert({ where: { userId_slot: { userId, slot } }, create: { ...data, userId, slot }, update: data });
      const backups = await tx.gameSave.findMany({ where: { userId, slot: { startsWith: "backup-" } }, orderBy: { createdAt: "desc" }, select: { id: true } });
      const stale = backups.slice(BACKUPS_KEPT).map((b) => b.id);
      if (stale.length) await tx.gameSave.deleteMany({ where: { id: { in: stale } } });
    });
    return slot;
  }

  private async conflict(userId: string): Promise<ApiError> {
    const row = await this.db.gameSave.findUniqueOrThrow({ where: { userId_slot: { userId, slot: MAIN } } });
    return new ApiError("SAVE_CONFLICT", "The cloud save changed since this one was based on it.", { server: toCloud(row) });
  }
}

function parseDate(s: string): Date | null {
  const d = new Date(s);
  return Number.isNaN(d.getTime()) ? null : d;
}
