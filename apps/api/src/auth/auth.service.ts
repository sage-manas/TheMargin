import { hash, verify } from "@node-rs/argon2";
import { Inject, Injectable, type OnModuleInit } from "@nestjs/common";
import type { z } from "zod";
import type { LoginRequestSchema, RegisterRequestSchema } from "@the-margin/contracts";
import { CONFIG, type Config } from "../config.js";
import { ApiError } from "../common/errors.js";
import { PrismaService } from "../common/prisma.service.js";
import { Prisma } from "../generated/prisma/client.js";
import { SessionsService, type SessionUser } from "./sessions.service.js";

@Injectable()
export class AuthService implements OnModuleInit {
  /** Verified against when the email is unknown, so failures take the same time. */
  private dummyHash = "";

  constructor(
    private readonly db: PrismaService,
    private readonly sessions: SessionsService,
    @Inject(CONFIG) private readonly config: Config,
  ) {}

  async onModuleInit(): Promise<void> {
    this.dummyHash = await this.hash("not-a-real-password-at-all");
  }

  private hash(password: string): Promise<string> {
    // @node-rs/argon2 defaults to Argon2id.
    return hash(password, { ...this.config.argon2, parallelism: 1 });
  }

  async register(input: z.infer<typeof RegisterRequestSchema>, userAgent?: string): Promise<{ user: SessionUser; token: string }> {
    const passwordHash = await this.hash(input.password);
    try {
      const u = await this.db.user.create({
        data: { email: input.email, passwordHash, profile: { create: { displayName: input.displayName } } },
      });
      const token = await this.sessions.create(u.id, userAgent);
      return { user: { id: u.id, email: u.email, displayName: input.displayName, avatar: null }, token };
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
        throw new ApiError("EMAIL_TAKEN", "An account with that email already exists.");
      }
      throw err;
    }
  }

  async login(input: z.infer<typeof LoginRequestSchema>, userAgent?: string): Promise<{ user: SessionUser; token: string }> {
    const u = await this.db.user.findUnique({ where: { email: input.email }, include: { profile: true } });
    const ok = await verify(u?.passwordHash ?? this.dummyHash, input.password).catch(() => false);
    if (!u || !ok) throw new ApiError("UNAUTHENTICATED", "That email and password don't match an account.");
    const token = await this.sessions.create(u.id, userAgent);
    return { user: { id: u.id, email: u.email, displayName: u.profile?.displayName ?? "", avatar: u.profile?.avatar ?? null }, token };
  }
}
