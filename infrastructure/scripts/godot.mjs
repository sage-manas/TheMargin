// Runs the pinned Godot version against apps/game.
// Usage: node infrastructure/scripts/godot.mjs <test|export|import>
// Godot binary: $GODOT, else .tools/godot/ (Windows), else `godot` on PATH.
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const repo = resolve(import.meta.dirname, "../..");
const game = join(repo, "apps/game");
const pinned = readFileSync(join(repo, ".godot-version"), "utf8").trim();
const local = join(repo, ".tools/godot", `Godot_v${pinned}_win64_console.exe`);
const godot = process.env.GODOT ?? (existsSync(local) ? local : "godot");

function run(args) {
  const r = spawnSync(godot, ["--headless", "--path", game, ...args], { stdio: "inherit" });
  if (r.error) throw r.error;
  return r.status ?? 1;
}

const version = spawnSync(godot, ["--version"], { encoding: "utf8" }).stdout?.trim() ?? "";
if (!version.startsWith(pinned.replace("-", "."))) {
  console.error(`Godot ${pinned} required, found "${version}". Set GODOT to the right binary.`);
  process.exit(1);
}

const cmd = process.argv[2];
let status = 0;
if (cmd === "import") {
  status = run(["--import"]);
} else if (cmd === "test") {
  status = run(["--import"]) || run(["--fixed-fps", "60", "res://tests/test_runner.tscn"]);
} else if (cmd === "export") {
  mkdirSync(join(game, "build/web"), { recursive: true });
  status = run(["--import"]) || run(["--export-release", "Web", "build/web/index.html"]);
  if (status === 0) {
    // Required artifacts and size budget (TDD §5.1, §7).
    const required = ["index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js"];
    for (const f of required) {
      const p = join(game, "build/web", f);
      if (!existsSync(p)) {
        console.error(`Missing export artifact: ${f}`);
        process.exit(1);
      }
    }
    const pck = statSync(join(game, "build/web/index.pck")).size;
    console.log(`Export OK. index.pck = ${(pck / 1024).toFixed(0)} KB`);
    if (pck > 8 * 1024 * 1024) {
      console.error("index.pck exceeds the 8 MB budget");
      process.exit(1);
    }
  }
} else {
  console.error("Usage: godot.mjs <test|export|import>");
  status = 2;
}
process.exit(status);
