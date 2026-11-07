// Post-deploy smoke test: the site, its bundled game build and the API
// behind its /v1 proxy all answer. Usage: node smoke.mjs https://site.example
const base = (process.argv[2] ?? "").replace(/\/$/, "");
if (!/^https?:\/\//.test(base)) {
  console.error("Usage: node infrastructure/scripts/smoke.mjs <site URL>");
  process.exit(2);
}

const checks = [
  ["landing page", "/", async (r) => (await r.text()).includes("Escape the drawing")],
  ["play page", "/play", async (r) => r.ok],
  ["game build manifest", "/game/build.json", async (r) => typeof (await r.json()).fileSizes?.["index.wasm"] === "number"],
  ["engine binary", "/game/index.wasm", async (r) => (r.headers.get("content-type") ?? "").includes("application/wasm")],
  ["API health", "/v1/health", async (r) => (await r.json()).db === "ok"],
  ["API session", "/v1/auth/session", async (r) => typeof (await r.json()).csrfToken === "string"],
];

let failed = 0;
for (const [name, path, ok] of checks) {
  try {
    // HEAD-like for the 38 MB binary: read headers only.
    const r = await fetch(base + path, { redirect: "follow" });
    const pass = r.ok && (await ok(r));
    if (path.endsWith(".wasm")) await r.body?.cancel();
    console.log(`${pass ? "ok  " : "FAIL"} ${name} (${path}, HTTP ${r.status})`);
    if (!pass) failed++;
  } catch (err) {
    console.log(`FAIL ${name} (${path}): ${err.message}`);
    failed++;
  }
}
process.exit(failed ? 1 : 0);
