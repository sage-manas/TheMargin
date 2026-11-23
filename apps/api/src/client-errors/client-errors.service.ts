// Browser error reports (TDD §6b), grouped by fingerprint and counted, so a
// crash seen by a thousand players is one row. No user identity is stored.
import { createHash } from "node:crypto";
import { Injectable, type OnModuleDestroy, type OnModuleInit } from "@nestjs/common";
import type { ClientErrorReport } from "@the-margin/contracts";
import { PrismaService } from "../common/prisma.service.js";

/** New fingerprints stop being stored past this many rows (counts still rise). */
export const MAX_ROWS = 2000;
const KEEP_DAYS = 30;

/** Same error, same place, same release: numbers in the message don't split it. */
export function fingerprint(r: ClientErrorReport): string {
  const message = r.message.replace(/\d+/g, "#");
  const top = (r.stack ?? "").split("\n").map((l) => l.trim()).find((l) => l.length > 0) ?? "";
  return createHash("sha256").update([r.source, r.release, message, top].join("\u0000")).digest("hex");
}

@Injectable()
export class ClientErrorsService implements OnModuleInit, OnModuleDestroy {
  private sweeper?: NodeJS.Timeout;

  constructor(private readonly db: PrismaService) {}

  onModuleInit(): void {
    this.sweeper = setInterval(() => void this.sweep(), 24 * 3600 * 1000);
    this.sweeper.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }

  async record(reports: ClientErrorReport[], userAgent?: string): Promise<void> {
    for (const r of reports) {
      const fp = fingerprint(r);
      const { count } = await this.db.clientError.updateMany({ where: { fingerprint: fp }, data: { count: { increment: 1 }, lastSeen: new Date() } });
      if (count > 0) continue;
      if ((await this.db.clientError.count()) >= MAX_ROWS) continue;
      await this.db.clientError
        .create({ data: { fingerprint: fp, source: r.source, release: r.release, message: r.message, stack: r.stack ?? null, path: r.path, userAgent: userAgent?.slice(0, 256) ?? null } })
        // Two reports of a new error at once: the other one created it.
        .catch(() => this.db.clientError.updateMany({ where: { fingerprint: fp }, data: { count: { increment: 1 }, lastSeen: new Date() } }));
    }
  }

  sweep(): Promise<unknown> {
    return this.db.clientError.deleteMany({ where: { lastSeen: { lt: new Date(Date.now() - KEEP_DAYS * 24 * 3600 * 1000) } } });
  }
}
