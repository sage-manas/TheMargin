import type { CookieOptions, Response } from "express";
import type { Config } from "../config.js";

export const SESSION_COOKIE = "tm_session";
export const CSRF_COOKIE = "tm_csrf";
export const CSRF_HEADER = "x-csrf-token";
export const SESSION_TTL_MS = 30 * 24 * 3600 * 1000;

const base = (config: Config): CookieOptions => ({ httpOnly: true, secure: config.cookieSecure, sameSite: "lax", path: "/" });

export function setSessionCookie(res: Response, config: Config, token: string): void {
  res.cookie(SESSION_COOKIE, token, { ...base(config), maxAge: SESSION_TTL_MS });
}

// The CSRF token is read from GET /auth/session, never from the cookie, so the
// cookie can be HttpOnly too (double submit: header must equal cookie).
export function setCsrfCookie(res: Response, config: Config, token: string): void {
  res.cookie(CSRF_COOKIE, token, { ...base(config), maxAge: SESSION_TTL_MS });
}

export function clearSessionCookie(res: Response, config: Config): void {
  res.clearCookie(SESSION_COOKIE, base(config));
}
