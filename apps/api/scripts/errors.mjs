// Lists the browser errors players hit, most frequent first (TDD §6b).
//   DATABASE_URL=… pnpm api:errors [--days 7] [--source game] [--release abc1234] [--stack]
// For staging, DATABASE_URL is the Neon direct connection string (DEPLOY.md).
import pg from "pg";

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : fallback;
};
const days = Number(opt("days", "7"));
const source = opt("source", null);
const release = opt("release", null);
const withStack = args.includes("--stack");

if (!process.env.DATABASE_URL) {
  console.error("Set DATABASE_URL (the API's database).");
  process.exit(2);
}
const db = new pg.Client({ connectionString: process.env.DATABASE_URL, options: "-c timezone=UTC" });
await db.connect();
const { rows } = await db.query(
  `SELECT source, release, message, stack, path, count, first_seen, last_seen
     FROM client_errors
    WHERE last_seen > now() - make_interval(days => $1)
      AND ($2::text IS NULL OR source = $2) AND ($3::text IS NULL OR release = $3)
    ORDER BY count DESC, last_seen DESC LIMIT 50`,
  [days, source, release],
);
await db.end();

if (rows.length === 0) console.log(`No errors in the last ${days} days.`);
for (const r of rows) {
  console.log(`${String(r.count).padStart(6)}×  [${r.source} ${r.release}] ${r.message}`);
  console.log(`         ${r.path} · first ${r.first_seen.toISOString().slice(0, 16)} · last ${r.last_seen.toISOString().slice(0, 16)}`);
  if (withStack && r.stack) console.log(r.stack.split("\n").map((l) => `           ${l}`).join("\n"));
}
