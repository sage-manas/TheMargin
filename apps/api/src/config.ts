// Runtime configuration from the environment. Everything has a safe default
// except DATABASE_URL.
export type Config = {
  port: number;
  databaseUrl: string;
  /** Site origins allowed for CORS and for the CSRF Origin check. */
  webOrigins: string[];
  /** Secure cookies; off only for plain-http local development and tests. */
  cookieSecure: boolean;
  /** Hops of reverse proxy to trust for the client IP (rate limits). */
  trustProxy: number;
  rateLimits: { default: number; register: number; login: number; windowMs: number };
  /** Argon2id cost (OWASP minimum by default: 19 MiB, 2 passes). */
  argon2: { memoryCost: number; timeCost: number };
  /**
   * Shared with the site's proxy (apps/web/src/proxy.ts). When set, every
   * request but the health check must carry it, and the client IP for rate
   * limits comes from the proxy, not from X-Forwarded-For (TDD §6).
   */
  proxySecret: string | null;
  /** Failed sign-ins allowed per account per window, from any number of IPs. */
  loginFailures: { limit: number; windowMs: number };
  /** Sessions kept per user; signing in again drops the oldest. */
  sessionsPerUser: number;
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  if (!env.DATABASE_URL) throw new Error("DATABASE_URL is required");
  return {
    port: Number(env.PORT ?? 4000),
    databaseUrl: env.DATABASE_URL,
    webOrigins: (env.WEB_ORIGINS ?? "http://localhost:3000").split(",").map((s) => s.trim()).filter(Boolean),
    cookieSecure: env.COOKIE_SECURE !== "false",
    trustProxy: Number(env.TRUST_PROXY ?? 0),
    // Per IP per minute. Overridable for test environments that share one IP.
    rateLimits: {
      default: Number(env.RATE_LIMIT_DEFAULT ?? 120),
      register: Number(env.RATE_LIMIT_REGISTER ?? 5),
      login: Number(env.RATE_LIMIT_LOGIN ?? 10),
      windowMs: 60_000,
    },
    argon2: { memoryCost: 19_456, timeCost: 2 },
    proxySecret: proxySecret(env.PROXY_SECRET),
    loginFailures: { limit: Number(env.LOGIN_FAILURE_LIMIT ?? 20), windowMs: 15 * 60_000 },
    sessionsPerUser: 10,
  };
}

export const CONFIG = Symbol("CONFIG");

function proxySecret(v: string | undefined): string | null {
  if (!v) return null;
  if (v.length < 32) throw new Error("PROXY_SECRET must be at least 32 characters");
  return v;
}
