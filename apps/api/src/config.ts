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
};

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  if (!env.DATABASE_URL) throw new Error("DATABASE_URL is required");
  return {
    port: Number(env.PORT ?? 4000),
    databaseUrl: env.DATABASE_URL,
    webOrigins: (env.WEB_ORIGINS ?? "http://localhost:3000").split(",").map((s) => s.trim()).filter(Boolean),
    cookieSecure: env.COOKIE_SECURE !== "false",
    trustProxy: Number(env.TRUST_PROXY ?? 0),
    rateLimits: { default: 120, register: 5, login: 10, windowMs: 60_000 },
    argon2: { memoryCost: 19_456, timeCost: 2 },
  };
}

export const CONFIG = Symbol("CONFIG");
