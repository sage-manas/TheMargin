// Opaque sessions (ADR-0007): a 256-bit random token in an HttpOnly cookie,
// stored only as its SHA-256. Expiry slides to 30 days, refreshed at most
// once a day so most requests don't write.
import { createHash, randomBytes } from "node:crypto";
import { Injectable, type OnModuleDestroy, type OnModuleInit } from "@nestjs/common";
import { PrismaService } from "../common/prisma.service.js";
import { SESSION_TTL_MS } from "./cookies.js";

const REFRESH_AFTER_MS = 24 * 3600 * 1000;

export type SessionUser = { id: string; email: string; displayName: string; avatar: string | null };
export type ActiveSession = { id: string; user: SessionUser; refreshed: boolean };

export const hashToken = (token: string): Buffer => createHash("sha256").update(token).digest();
export const newToken = (): string => randomBytes(32).toString("base64url");

@Injectable()
export class SessionsService implements OnModuleInit, OnModuleDestroy {
  private sweeper?: NodeJS.Timeout;

  constructor(private readonly db: PrismaService) {}

  onModuleInit(): void {
    this.sweeper = setInterval(() => void this.sweep(), 24 * 3600 * 1000);
    this.sweeper.unref();
  }

  onModuleDestroy(): void {
    clearInterval(this.sweeper);
  }

  async create(userId: string, userAgent?: string): Promise<string> {
    const token = newToken();
    await this.db.session.create({
      data: { userId, tokenHash: hashToken(token), expiresAt: new Date(Date.now() + SESSION_TTL_MS), userAgent: userAgent?.slice(0, 256) },
    });
    return token;
  }

  async resolve(token: string | undefined): Promise<ActiveSession | null> {
    if (!token || token.length > 128) return null;
    const s = await this.db.session.findUnique({ where: { tokenHash: hashToken(token) }, include: { user: { include: { profile: true } } } });
    if (!s || s.expiresAt.getTime() <= Date.now()) return null;
    let refreshed = false;
    if (s.expiresAt.getTime() - Date.now() < SESSION_TTL_MS - REFRESH_AFTER_MS) {
      await this.db.session.update({ where: { id: s.id }, data: { expiresAt: new Date(Date.now() + SESSION_TTL_MS) } });
      refreshed = true;
    }
    const u = s.user;
    return { id: s.id, refreshed, user: { id: u.id, email: u.email, displayName: u.profile?.displayName ?? "", avatar: u.profile?.avatar ?? null } };
  }

  async revoke(token: string | undefined): Promise<void> {
    if (token) await this.db.session.deleteMany({ where: { tokenHash: hashToken(token) } });
  }

  sweep(): Promise<unknown> {
    return this.db.session.deleteMany({ where: { expiresAt: { lte: new Date() } } });
  }
}
