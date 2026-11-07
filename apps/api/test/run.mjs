// Integration test runner. Needs TEST_DATABASE_URL, a database it may wipe:
// the public schema is dropped, migrated from scratch and seeded, then every
// test/*.test.ts runs against the built API (pnpm build first).
import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { join } from "node:path";
import pg from "pg";

const url = process.env.TEST_DATABASE_URL;
if (!url) {
  console.error("Set TEST_DATABASE_URL to a disposable Postgres database (it will be wiped).");
  process.exit(2);
}
const here = import.meta.dirname;
const env = { ...process.env, DATABASE_URL: url };
const node = [process.execPath, "--experimental-strip-types", "--disable-warning=ExperimentalWarning"];

const client = new pg.Client({ connectionString: url });
await client.connect();
await client.query("DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;");
// A non-UTC server timezone, so a timestamp read in the wrong zone fails here
// even on UTC CI machines (see src/common/db.ts).
await client.query(`ALTER DATABASE "${client.database}" SET timezone = 'Asia/Kolkata'`);
await client.end();

const run = (cmd, args) => {
  const r = spawnSync(cmd, args, { stdio: "inherit", env, cwd: join(here, "..") });
  if (r.status !== 0) process.exit(r.status ?? 1);
};
run("pnpm", ["exec", "prisma", "migrate", "deploy"]);
// Migrations must produce exactly the schema (DATABASE.md).
run("pnpm", ["exec", "prisma", "migrate", "diff", "--from-config-datasource", "--to-schema", "prisma/schema.prisma", "--exit-code"]);
run(node[0], [...node.slice(1), "dist/seed.js"]);
const files = readdirSync(here).filter((f) => f.endsWith(".test.ts")).map((f) => join(here, f));
run(node[0], [...node.slice(1), "--test", "--test-concurrency=1", ...files]);
