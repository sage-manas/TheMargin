import pg from "pg";
import type { Save } from "@the-margin/contracts";
import type { Config } from "../src/config.ts";

type AppModule = typeof import("../src/app.ts");
type ConfigModule = typeof import("../src/config.ts");

export const ORIGIN = "http://localhost:3000";

export type Api = { url: string; db: pg.Pool; close(): Promise<void>; reset(): Promise<void> };

/** Starts the built API on a free port. Rate limits are raised unless a test needs the real ones. */
export async function startApi(overrides: (c: Config) => Config = (c) => c): Promise<Api> {
  const { createApp } = (await import(new URL("../dist/app.js", import.meta.url).href)) as AppModule;
  const { loadConfig } = (await import(new URL("../dist/config.js", import.meta.url).href)) as ConfigModule;
  const base = loadConfig({ DATABASE_URL: process.env.DATABASE_URL, WEB_ORIGINS: ORIGIN, COOKIE_SECURE: "false" });
  const config = overrides({ ...base, rateLimits: { ...base.rateLimits, default: 10_000, register: 10_000, login: 10_000 }, argon2: { memoryCost: 1024, timeCost: 1 } });
  const app = await createApp(config, { logger: false });
  await app.listen(0, "127.0.0.1");
  const url = `${await app.getUrl()}/v1`.replace("[::1]", "127.0.0.1");
  const db = new pg.Pool({ connectionString: process.env.DATABASE_URL });
  return {
    url,
    db,
    async close() {
      await app.close();
      await db.end();
    },
    async reset() {
      // Everything user-owned cascades from users; chapters and achievements stay seeded.
      await db.query("TRUNCATE users CASCADE");
    },
  };
}

/** A browser-like client: keeps cookies and sends the CSRF header and Origin. */
export class Client {
  cookies = new Map<string, string>();
  csrf = "";
  origin: string | null = ORIGIN;

  readonly api: Api;

  constructor(api: Api) {
    this.api = api;
  }

  async req(method: string, path: string, body?: unknown, opts: { csrf?: string | null; raw?: string } = {}): Promise<{ status: number; body: any; headers: Headers }> {
    const headers: Record<string, string> = {};
    if (this.cookies.size) headers.cookie = [...this.cookies].map(([k, v]) => `${k}=${v}`).join("; ");
    if (this.origin) headers.origin = this.origin;
    const csrf = opts.csrf === undefined ? this.csrf : opts.csrf;
    if (csrf) headers["x-csrf-token"] = csrf;
    if (body !== undefined || opts.raw !== undefined) headers["content-type"] = "application/json";
    const res = await fetch(this.api.url + path, { method, headers, body: opts.raw ?? (body === undefined ? undefined : JSON.stringify(body)) });
    for (const c of res.headers.getSetCookie()) {
      const [pair, ...attrs] = c.split(";");
      const [k, v] = pair.split("=");
      const expired = attrs.some((a) => /expires=thu, 01 jan 1970/i.test(a.trim())) || v === "";
      if (expired) this.cookies.delete(k.trim());
      else this.cookies.set(k.trim(), v);
    }
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null, headers: res.headers };
  }

  /** GET /auth/session, keeping the CSRF token as a browser app would. */
  async session() {
    const r = await this.req("GET", "/auth/session");
    this.csrf = r.body.csrfToken;
    return r;
  }

  async register(email = `nib${Math.random().toString(36).slice(2)}@example.com`, password = "correct horse battery", displayName = "Nib") {
    await this.session();
    return this.req("POST", "/auth/register", { email, password, displayName });
  }
}

export function makeSave(progress: Partial<Save["progress"]> = {}, revision = 1): Save {
  return {
    schema: "the-margin.save",
    version: 1,
    revision,
    updatedAt: "2026-11-07T10:00:00Z",
    playtimeSec: 30,
    progress: { chapter: "ch01", page: "ch01_p01", completedPages: [], completedChapters: [], abilities: [], flags: {}, ...progress },
    player: { position: null, carrying: null },
    pages: {},
  };
}
