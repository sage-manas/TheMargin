import { randomBytes } from "node:crypto";
import { Body, Controller, Get, HttpCode, Inject, Post, Req, Res, SetMetadata } from "@nestjs/common";
import type { Request, Response } from "express";
import { LoginRequestSchema, RegisterRequestSchema, type SessionResponse } from "@the-margin/contracts";
import { CONFIG, type Config } from "../config.js";
import { parse } from "../common/zod.js";
import { AuthService } from "./auth.service.js";
import { clearSessionCookie, CSRF_COOKIE, SESSION_COOKIE, setCsrfCookie, setSessionCookie } from "./cookies.js";
import { Auth, CurrentSession } from "./guards.js";
import { SessionsService, type ActiveSession } from "./sessions.service.js";

/** Marks a route for its own rate limit (see app.module.ts). */
export const RateLimit = (name: "register" | "login") => SetMetadata("rateLimit", name);

@Controller("auth")
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly sessions: SessionsService,
    @Inject(CONFIG) private readonly config: Config,
  ) {}

  /** The current user (or null) and the CSRF token for state-changing requests. */
  @Get("session")
  @Auth("optional")
  session(@CurrentSession() s: ActiveSession | null, @Req() req: Request, @Res({ passthrough: true }) res: Response): SessionResponse {
    return { user: s?.user ?? null, csrfToken: this.csrf(req, res) };
  }

  @Post("register")
  @RateLimit("register")
  async register(@Body() body: unknown, @Req() req: Request, @Res({ passthrough: true }) res: Response): Promise<SessionResponse> {
    const { user, token } = await this.auth.register(parse(RegisterRequestSchema, body), req.headers["user-agent"]);
    setSessionCookie(res, this.config, token);
    return { user, csrfToken: this.csrf(req, res) };
  }

  @Post("login")
  @HttpCode(200)
  @RateLimit("login")
  async login(@Body() body: unknown, @Req() req: Request, @Res({ passthrough: true }) res: Response): Promise<SessionResponse> {
    const { user, token } = await this.auth.login(parse(LoginRequestSchema, body), req.headers["user-agent"]);
    // A new session never reuses one the browser already had. A failed login
    // leaves the old one alone.
    await this.sessions.revoke(req.cookies?.[SESSION_COOKIE]);
    setSessionCookie(res, this.config, token);
    return { user, csrfToken: this.csrf(req, res) };
  }

  @Post("logout")
  @HttpCode(204)
  async logout(@Req() req: Request, @Res({ passthrough: true }) res: Response): Promise<void> {
    await this.sessions.revoke(req.cookies?.[SESSION_COOKIE]);
    clearSessionCookie(res, this.config);
  }

  private csrf(req: Request, res: Response): string {
    const existing: unknown = req.cookies?.[CSRF_COOKIE];
    if (typeof existing === "string" && /^[\w-]{43}$/.test(existing)) return existing;
    const token = randomBytes(32).toString("base64url");
    setCsrfCookie(res, this.config, token);
    return token;
  }
}
