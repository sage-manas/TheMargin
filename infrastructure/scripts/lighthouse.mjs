// Phase 5 exit bar: Lighthouse performance and accessibility >= 90 on the
// landing page. Usage: node infrastructure/scripts/lighthouse.mjs [url] [min]
// Runs Lighthouse (fetched with npx, so it stays out of the lockfile) in
// Playwright's Chromium against a running production build (`pnpm --filter
// @the-margin/web build && pnpm --filter @the-margin/web start`).
import { spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { createRequire } from "node:module";

const url = process.argv[2] ?? "http://localhost:3000/";
const min = Number(process.argv[3] ?? 90);
const require = createRequire(resolve(import.meta.dirname, "../../tests/e2e/package.json"));
const chromePath = process.env.CHROME_PATH ?? require("@playwright/test").chromium.executablePath();
const out = join(mkdtempSync(join(tmpdir(), "lh-")), "report.json");

const r = spawnSync(
  "npx",
  ["--yes", "lighthouse@13.6.0", url, "--only-categories=performance,accessibility,best-practices,seo", "--output=json", `--output-path=${out}`, "--quiet", "--chrome-flags=--headless=new --no-sandbox"],
  { stdio: "inherit", env: { ...process.env, CHROME_PATH: chromePath } },
);
if (r.status !== 0) process.exit(r.status ?? 1);

const report = JSON.parse(readFileSync(out, "utf8"));
let failed = false;
for (const [id, cat] of Object.entries(report.categories)) {
  const score = Math.round(cat.score * 100);
  const gated = id === "performance" || id === "accessibility";
  if (gated && score < min) failed = true;
  console.log(`${cat.title.padEnd(16)} ${score}${gated ? ` (needs ${min})` : ""}`);
}
for (const a of Object.values(report.audits)) {
  if (a.score !== null && a.score < 0.9 && a.scoreDisplayMode !== "informative" && a.scoreDisplayMode !== "notApplicable") console.log(`  - ${a.id}: ${a.title}`);
}
process.exit(failed ? 1 : 0);
