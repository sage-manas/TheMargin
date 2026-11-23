import { after, before, beforeEach, describe, test } from "node:test";
import assert from "node:assert/strict";
import { Client, ORIGIN, startApi, type Api } from "./helpers.ts";

let api: Api;
before(async () => (api = await startApi()));
after(() => api.close());
beforeEach(() => api.db.query("TRUNCATE client_errors"));

const report = (over: Record<string, unknown> = {}) => ({ source: "site", message: "TypeError: x is undefined", stack: "at f (app.js:1:2)\nat g (app.js:3:4)", path: "/play", release: "abc1234", ...over });

/** As the site sends it: keepalive, no cookies, no CSRF token. */
const send = (body: unknown, headers: Record<string, string> = {}) =>
  fetch(api.url + "/client-errors", { method: "POST", headers: { "content-type": "application/json", origin: ORIGIN, ...headers }, body: JSON.stringify(body) });

describe("client error reports", () => {
  test("are accepted without a session or CSRF token, and grouped by fingerprint", async () => {
    assert.equal((await send({ reports: [report(), report({ message: "TypeError: x is undefined" })] })).status, 204);
    // Numbers in the message don't make a new group.
    assert.equal((await send({ reports: [report({ message: "TypeError: x is undefined" }), report({ message: "Failed at 12" }), report({ message: "Failed at 345" })] })).status, 204);
    const { rows } = await api.db.query("SELECT message, count, source, path, release, user_agent FROM client_errors ORDER BY message");
    assert.deepEqual(rows.map((r) => [r.message, r.count]), [["Failed at 12", 2], ["TypeError: x is undefined", 3]]);
    assert.equal(rows[0].release, "abc1234");
    assert.ok(rows[0].user_agent);
  });

  test("a different release or source is a different group", async () => {
    await send({ reports: [report(), report({ release: "def5678" }), report({ source: "game" })] });
    assert.equal((await api.db.query("SELECT count(*)::int AS n FROM client_errors")).rows[0].n, 3);
  });

  test("bad reports are refused: wrong origin, query strings, too many, too long", async () => {
    assert.equal((await send({ reports: [report()] }, { origin: "https://evil.example" })).status, 403);
    assert.equal((await send({ reports: [report({ path: "/play?token=secret" })] })).status, 400);
    assert.equal((await send({ reports: Array.from({ length: 11 }, () => report()) })).status, 400);
    assert.equal((await send({ reports: [report({ message: "x".repeat(501) })] })).status, 400);
    assert.equal((await send({ reports: [report({ source: "server" })] })).status, 400);
    assert.equal((await api.db.query("SELECT count(*)::int AS n FROM client_errors")).rows[0].n, 0);
  });

  test("no user identity is stored, even when a signed-in browser reports", async () => {
    const c = new Client(api);
    await c.register();
    const r = await c.req("POST", "/client-errors", { reports: [report()] });
    assert.equal(r.status, 204);
    const { rows } = await api.db.query("SELECT * FROM client_errors");
    assert.deepEqual(Object.keys(rows[0]).sort(), ["count", "fingerprint", "first_seen", "id", "last_seen", "message", "path", "release", "source", "stack", "user_agent"]);
  });

  test("every response carries a request id", async () => {
    const r = await fetch(api.url + "/health");
    assert.match(r.headers.get("x-request-id") ?? "", /^[\w-]{8,}$/);
  });
});

describe("client error report rate limit", () => {
  let strict: Api;
  before(async () => (strict = await startApi((c) => ({ ...c, rateLimits: { ...c.rateLimits, reports: 3 } }))));
  after(() => strict.close());

  test("30 a minute per IP in production; past the limit they are dropped with 429", async () => {
    const codes: number[] = [];
    for (let i = 0; i < 4; i++) {
      const r = await fetch(strict.url + "/client-errors", { method: "POST", headers: { "content-type": "application/json", origin: ORIGIN }, body: JSON.stringify({ reports: [report()] }) });
      codes.push(r.status);
    }
    assert.deepEqual(codes, [204, 204, 204, 429]);
  });
});
