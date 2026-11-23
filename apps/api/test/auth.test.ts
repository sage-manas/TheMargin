import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { ErrorEnvelopeSchema, SessionResponseSchema } from "@the-margin/contracts";
import { Client, startApi, type Api } from "./helpers.ts";

let api: Api;
before(async () => (api = await startApi()));
after(() => api.close());
beforeEach(() => api.reset());

describe("sessions and accounts", () => {
  test("an anonymous session has no user but a CSRF token, set as an HttpOnly cookie", async () => {
    const c = new Client(api);
    const r = await c.session();
    assert.equal(r.status, 200);
    const body = SessionResponseSchema.parse(r.body);
    assert.equal(body.user, null);
    assert.equal(c.cookies.get("tm_csrf"), body.csrfToken);
    const cookie = r.headers.getSetCookie().find((s) => s.startsWith("tm_csrf="))!;
    assert.match(cookie, /HttpOnly/);
    assert.match(cookie, /SameSite=Lax/);
    // The token is stable for the browser.
    assert.equal((await c.session()).body.csrfToken, body.csrfToken);
  });

  test("register signs in, and the session is stored only as a hash", async () => {
    const c = new Client(api);
    const r = await c.register("Nib@Example.com");
    assert.equal(r.status, 201);
    assert.equal(r.body.user.email, "nib@example.com");
    assert.equal(r.body.user.displayName, "Nib");
    const token = c.cookies.get("tm_session")!;
    assert.ok(token.length >= 43);
    assert.match(r.headers.getSetCookie().find((s) => s.startsWith("tm_session="))!, /HttpOnly; SameSite=Lax/);
    const { rows } = await api.db.query("SELECT token_hash FROM sessions");
    assert.equal(rows.length, 1);
    assert.deepEqual(rows[0].token_hash, createHash("sha256").update(token).digest());
    const { rows: users } = await api.db.query("SELECT password_hash FROM users");
    assert.match(users[0].password_hash, /^\$argon2id\$/);
    assert.equal((await c.req("GET", "/me")).body.email, "nib@example.com");
  });

  test("emails are unique regardless of case", async () => {
    await new Client(api).register("nib@example.com");
    const r = await new Client(api).register("NIB@example.com");
    assert.equal(r.status, 409);
    assert.equal(r.body.error.code, "EMAIL_TAKEN");
  });

  test("invalid input gets the error envelope with issues", async () => {
    const c = new Client(api);
    await c.session();
    const r = await c.req("POST", "/auth/register", { email: "not-an-email", password: "short", displayName: "" });
    assert.equal(r.status, 400);
    const e = ErrorEnvelopeSchema.parse(r.body);
    assert.equal(e.error.code, "VALIDATION_FAILED");
    assert.deepEqual((e.error.details.issues as { path: string }[]).map((i) => i.path).sort(), ["displayName", "email", "password"]);
    const bad = await c.req("POST", "/auth/register", undefined, { raw: "{not json" });
    assert.equal(bad.status, 400);
    assert.equal(bad.body.error.code, "VALIDATION_FAILED");
  });

  test("login: a wrong password and an unknown email fail the same way", async () => {
    await new Client(api).register("nib@example.com", "correct horse battery");
    const c = new Client(api);
    await c.session();
    const wrong = await c.req("POST", "/auth/login", { email: "nib@example.com", password: "wrong horse battery" });
    const unknown = await c.req("POST", "/auth/login", { email: "nobody@example.com", password: "wrong horse battery" });
    assert.equal(wrong.status, 401);
    assert.deepEqual(wrong.body, unknown.body);
    assert.ok(!c.cookies.has("tm_session"));
    const ok = await c.req("POST", "/auth/login", { email: "NIB@example.com", password: "correct horse battery" });
    assert.equal(ok.status, 200);
    assert.equal(ok.body.user.email, "nib@example.com");
  });

  test("logout revokes the session server-side", async () => {
    const c = new Client(api);
    await c.register();
    const stolen = c.cookies.get("tm_session")!;
    assert.equal((await c.req("POST", "/auth/logout")).status, 204);
    assert.ok(!c.cookies.has("tm_session"));
    assert.equal((await c.session()).body.user, null);
    const replay = new Client(api);
    replay.cookies.set("tm_session", stolen);
    assert.equal((await replay.req("GET", "/me")).status, 401);
  });

  test("expired sessions are refused, and old ones slide forward", async () => {
    const c = new Client(api);
    await c.register();
    await api.db.query("UPDATE sessions SET expires_at = now() + interval '10 days'");
    assert.equal((await c.req("GET", "/me")).status, 200);
    const { rows } = await api.db.query("SELECT expires_at FROM sessions");
    assert.ok(rows[0].expires_at.getTime() > Date.now() + 29 * 24 * 3600 * 1000, "extended to 30 days");
    await api.db.query("UPDATE sessions SET expires_at = now() - interval '1 second'");
    const r = await c.req("GET", "/me");
    assert.equal(r.status, 401);
    assert.equal(r.body.error.code, "UNAUTHENTICATED");
  });

  test("display name and avatar can be changed", async () => {
    const c = new Client(api);
    await c.register();
    const r = await c.req("PATCH", "/me/profile", { displayName: "  Inky  ", avatar: "nib-red" });
    assert.equal(r.status, 200);
    assert.equal(r.body.displayName, "Inky");
    assert.equal((await c.session()).body.user.avatar, "nib-red");
    assert.equal((await c.req("PATCH", "/me/profile", {})).status, 400);
  });
});

describe("CSRF and origin", () => {
  test("state-changing requests need the header to match the cookie", async () => {
    const c = new Client(api);
    await c.register();
    assert.equal((await c.req("PUT", "/settings", {}, { csrf: null })).body.error.code, "FORBIDDEN");
    assert.equal((await c.req("POST", "/auth/logout", undefined, { csrf: "x".repeat(43) })).status, 403);
    // Without the cookie, a forged header is no good either.
    const noCookie = new Client(api);
    noCookie.cookies.set("tm_session", c.cookies.get("tm_session")!);
    assert.equal((await noCookie.req("POST", "/auth/logout", undefined, { csrf: c.csrf })).status, 403);
    // GETs need neither.
    assert.equal((await c.req("GET", "/me", undefined, { csrf: null })).status, 200);
  });

  test("a foreign Origin is refused even with a valid token", async () => {
    const c = new Client(api);
    await c.session();
    c.origin = "https://evil.example";
    const r = await c.req("POST", "/auth/register", { email: "a@example.com", password: "correct horse battery", displayName: "A" });
    assert.equal(r.status, 403);
    assert.equal(r.body.error.message, "Requests must come from the site.");
  });

  test("CORS allows the site with credentials and nobody else", async () => {
    const pre = (origin: string) => fetch(`${api.url}/saves/main`, { method: "OPTIONS", headers: { origin, "access-control-request-method": "PUT", "access-control-request-headers": "content-type,x-csrf-token" } });
    const ok = await pre("http://localhost:3000");
    assert.equal(ok.headers.get("access-control-allow-origin"), "http://localhost:3000");
    assert.equal(ok.headers.get("access-control-allow-credentials"), "true");
    assert.equal((await pre("https://evil.example")).headers.get("access-control-allow-origin"), null);
  });
});

describe("hardening", () => {
  test("unknown routes and internal errors use the envelope", async () => {
    const r = await new Client(api).req("GET", "/nope");
    assert.equal(r.status, 404);
    assert.equal(r.body.error.code, "NOT_FOUND");
  });

  test("security headers are set", async () => {
    const r = await fetch(`${api.url}/health`);
    assert.deepEqual(await r.json(), { status: "ok", db: "ok" });
    assert.equal(r.headers.get("x-content-type-options"), "nosniff");
    assert.ok(r.headers.get("content-security-policy"));
    assert.equal(r.headers.get("x-powered-by"), null);
  });
});

describe("rate limits (the real ones)", () => {
  let strict: Api;
  before(async () => (strict = await startApi((c) => ({ ...c, rateLimits: { default: 120, register: 5, login: 10, reports: 30, windowMs: 60_000 } }))));
  after(() => strict.close());

  test("register allows 5 a minute per IP, login 10", async () => {
    const c = new Client(strict);
    await c.session();
    const codes: number[] = [];
    for (let i = 0; i < 6; i++) codes.push((await c.req("POST", "/auth/register", { email: `r${i}@example.com`, password: "correct horse battery", displayName: "R" })).status);
    assert.deepEqual(codes, [201, 201, 201, 201, 201, 429]);
    const limited = await c.req("POST", "/auth/register", { email: "r9@example.com", password: "correct horse battery", displayName: "R" });
    assert.equal(limited.body.error.code, "RATE_LIMITED");
    const logins: number[] = [];
    for (let i = 0; i < 11; i++) logins.push((await c.req("POST", "/auth/login", { email: "r0@example.com", password: "wrong horse battery" })).status);
    assert.equal(logins.filter((s) => s === 401).length, 10);
    assert.equal(logins.at(-1), 429);
    // Other routes have their own, larger budget.
    assert.equal((await c.req("GET", "/me")).status, 200);
  });
});

describe("only through the site's proxy (PROXY_SECRET)", () => {
  const SECRET = "s".repeat(40);
  let proxied: Api;
  before(async () => (proxied = await startApi((c) => ({ ...c, proxySecret: SECRET, rateLimits: { default: 120, register: 5, login: 3, reports: 30, windowMs: 60_000 } }))));
  after(() => proxied.close());
  beforeEach(() => proxied.reset());

  const via = (ip: string) => {
    const c = new Client(proxied);
    c.headers = { "x-margin-proxy": SECRET, "x-margin-client-ip": ip };
    return c;
  };

  test("a direct caller is refused; the health check is not", async () => {
    const direct = new Client(proxied);
    const r = await direct.req("GET", "/auth/session");
    assert.equal(r.status, 403);
    assert.equal(r.body.error.code, "FORBIDDEN");
    direct.headers = { "x-margin-proxy": "x".repeat(40) };
    assert.equal((await direct.req("GET", "/auth/session")).status, 403);
    assert.equal((await fetch(proxied.url + "/health")).status, 200);
    assert.equal((await via("203.0.113.1").session()).status, 200);
  });

  test("rate limits follow the proxy's client IP, not X-Forwarded-For", async () => {
    const a = via("203.0.113.1");
    await a.session();
    const codes: number[] = [];
    for (let i = 0; i < 4; i++) {
      a.headers["x-forwarded-for"] = `198.51.100.${i}`;
      codes.push((await a.req("POST", "/auth/login", { email: "x@example.com", password: "wrong horse battery" })).status);
    }
    assert.deepEqual(codes, [401, 401, 401, 429]);
    const b = via("203.0.113.2");
    await b.session();
    assert.equal((await b.req("POST", "/auth/login", { email: "x@example.com", password: "wrong horse battery" })).status, 401);
  });
});

describe("failed sign-ins per account", () => {
  let locked: Api;
  before(async () => (locked = await startApi((c) => ({ ...c, loginFailures: { limit: 3, windowMs: 60_000 } }))));
  after(() => locked.close());
  beforeEach(() => locked.reset());

  test("after the limit, even the right password is refused until the window passes; other accounts are untouched", async () => {
    await new Client(locked).register("nib@example.com");
    await new Client(locked).register("ink@example.com");
    const c = new Client(locked);
    await c.session();
    for (let i = 0; i < 3; i++) assert.equal((await c.req("POST", "/auth/login", { email: "nib@example.com", password: "wrong horse battery" })).status, 401);
    const r = await c.req("POST", "/auth/login", { email: "nib@example.com", password: "correct horse battery" });
    assert.equal(r.status, 429);
    assert.equal(r.body.error.code, "RATE_LIMITED");
    assert.equal((await c.req("POST", "/auth/login", { email: "ink@example.com", password: "correct horse battery" })).status, 200);
  });

  test("a successful sign-in clears the count", async () => {
    await new Client(locked).register("pen@example.com");
    const c = new Client(locked);
    await c.session();
    for (let i = 0; i < 2; i++) await c.req("POST", "/auth/login", { email: "pen@example.com", password: "wrong horse battery" });
    assert.equal((await c.req("POST", "/auth/login", { email: "pen@example.com", password: "correct horse battery" })).status, 200);
    for (let i = 0; i < 2; i++) assert.equal((await c.req("POST", "/auth/login", { email: "pen@example.com", password: "wrong horse battery" })).status, 401);
  });
});

describe("sessions per user", () => {
  test("signing in again keeps only the newest 10 sessions", async () => {
    const first = new Client(api);
    await first.register("nib@example.com");
    for (let i = 0; i < 10; i++) {
      const c = new Client(api);
      await c.session();
      assert.equal((await c.req("POST", "/auth/login", { email: "nib@example.com", password: "correct horse battery" })).status, 200);
    }
    const { rows } = await api.db.query("SELECT count(*)::int AS n FROM sessions");
    assert.equal(rows[0].n, 10);
    assert.equal((await first.req("GET", "/me")).status, 401);
  });
});
