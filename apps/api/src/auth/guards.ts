import { timingSafeEqual } from "node:crypto";
import { createParamDecorator, Inject, Injectable, SetMetadata, type CanActivate, type ExecutionContext } from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import type { Request, Response } from "express";
import { CONFIG, type Config } from "../config.js";
import { ApiError, unauthenticated } from "../common/errors.js";
import { CSRF_COOKIE, CSRF_HEADER, SESSION_COOKIE, setSessionCookie } from "./cookies.js";
import { SessionsService, type ActiveSession } from "./sessions.service.js";

export type AuthedRequest = Request & { session?: ActiveSession | null };

/** `@Auth("required")` (401 without a session) or `@Auth("optional")`. Routes without it never look. */
export const Auth = (mode: "required" | "optional") => SetMetadata("auth", mode);

export const CurrentSession = createParamDecorator((_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest<AuthedRequest>().session ?? null);

@Injectable()
export class SessionGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly sessions: SessionsService,
    @Inject(CONFIG) private readonly config: Config,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const mode = this.reflector.getAllAndOverride<"required" | "optional" | undefined>("auth", [ctx.getHandler(), ctx.getClass()]);
    if (!mode) return true;
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const token: string | undefined = req.cookies?.[SESSION_COOKIE];
    req.session = await this.sessions.resolve(token);
    if (req.session?.refreshed && token) setSessionCookie(ctx.switchToHttp().getResponse<Response>(), this.config, token);
    if (mode === "required" && !req.session) throw unauthenticated();
    return true;
  }
}

const SAFE = new Set(["GET", "HEAD", "OPTIONS"]);

/**
 * CSRF for every state-changing request (TDD §6): the x-csrf-token header must
 * equal the tm_csrf cookie, and a browser's Origin must be one of the site's.
 * Login and register are covered too (login CSRF).
 */
@Injectable()
export class CsrfGuard implements CanActivate {
  constructor(@Inject(CONFIG) private readonly config: Config) {}

  canActivate(ctx: ExecutionContext): boolean {
    const req = ctx.switchToHttp().getRequest<Request>();
    if (SAFE.has(req.method)) return true;
    const origin = req.headers.origin;
    if (origin && !this.config.webOrigins.includes(origin)) throw new ApiError("FORBIDDEN", "Requests must come from the site.");
    const cookie: unknown = req.cookies?.[CSRF_COOKIE];
    const header = req.headers[CSRF_HEADER];
    if (typeof cookie !== "string" || typeof header !== "string" || !cookie || cookie.length !== header.length || !timingSafeEqual(Buffer.from(cookie), Buffer.from(header))) {
      throw new ApiError("FORBIDDEN", "Missing or stale CSRF token. Fetch /v1/auth/session and retry.");
    }
    return true;
  }
}
