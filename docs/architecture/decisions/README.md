# Architecture Decision Records

Each record lists its context, the decision, the alternatives considered, the reasoning, and the consequences.

## ADR-0001: Godot 4.7.2, Compatibility renderer, single-threaded web export
- **Context:** The game must run in desktop browsers. Godot's web export needs the Compatibility renderer. A threaded export needs SharedArrayBuffer, which requires COOP/COEP headers on every page, embed and asset.
- **Decision:** Pin Godot 4.7.2-stable (`.godot-version`), use Compatibility, and export with `thread_support=false`.
- **Alternatives:** threaded export (better audio latency, but cross-origin isolation complicates Next.js, CDN and any third-party embed); Godot 3.x (end of life for new features).
- **Reasoning:** A 2D puzzle game has no CPU-bound workload that needs threads.
- **Consequences:** Audio goes through the AudioWorklet fallback, which is fine for SFX. Hosting stays simple. Revisit only if profiling shows main-thread audio stalls.

## ADR-0002: 640×360 base resolution, viewport stretch, integer scaling
- **Context:** The pixel art must stay crisp, and one comic page must fit on one screen with legible 5×7 lettering.
- **Decision:** Render at 640×360, `stretch_mode=viewport`, `scale_mode=integer`, nearest filtering, pixel snapping, letterboxed on paper colour.
- **Alternatives:** 480×270 (too cramped for lettering); 320×180 (pages become unreadable); `canvas_items` stretch (allows sub-pixel and mixed pixel sizes).
- **Consequences:** At window sizes between integer multiples there is a border. That's acceptable and on-theme (it's the page margin).

## ADR-0003: Pages are JSON data built at runtime
- **Context:** Puzzles must be configurable, testable and extensible, not ad-hoc scripts.
- **Decision:** `data/pages/*.json` describes panels, openings, solids, props, NPCs, bubbles, captions, objects and triggers. `page.gd` builds them; behaviours are reusable scripts.
- **Alternatives:** hand-authored `.tscn` per page (visual editing, but hard to validate and diff, and logic leaks into scenes); a custom editor plugin now (premature).
- **Consequences:** No visual editor yet; positions are authored on an 8 px grid. A small in-editor page preview tool is a Phase 3 nice-to-have.

## ADR-0004: Words are data; objects react by category
- **Context:** The brief forbids hardcoding words.
- **Decision:** `words.json` maps word → category + parameters. Objects implement category handlers. Slots hold word ids.
- **Consequences:** New words cost nothing. New categories cost one handler per object type that accepts them. Saves store only `slot → word`.

## ADR-0005: In-house headless test runner instead of GUT
- **Context:** The game needs automated tests in CI with zero external downloads.
- **Decision:** `tests/run_tests.gd` (about 100 lines) discovers `test_*.gd`, runs `test_*` methods, reports results, and exits with a status code.
- **Alternatives:** GUT or GdUnit4 (feature-rich, but an extra dependency to pin and update with each Godot release).
- **Consequences:** No mocking framework. Systems are designed as pure functions or with node dependencies passed in, which is a design benefit. Revisit if the suite grows beyond about 300 tests.

## ADR-0006: pnpm workspaces without Turborepo or Nx
- **Context:** Three apps and two packages; Godot isn't a JS build.
- **Decision:** Plain pnpm workspaces with `pnpm -r` scripts.
- **Consequences:** Builds aren't cached. Add Turborepo only when CI exceeds about 10 minutes.

## ADR-0007: Opaque server sessions in HttpOnly cookies, not JWT
- **Context:** A browser-only client on the same site.
- **Decision:** 256-bit random session token in a `HttpOnly; Secure; SameSite=Lax` cookie, SHA-256 hashed in `sessions`, 30-day sliding expiry, CSRF double-submit.
- **Alternatives:** JWT access + refresh tokens (revocation complexity for no benefit with a single API).
- **Consequences:** One DB lookup per authenticated request, which is negligible at this scale and can be cached later.

## ADR-0008: Build the gameplay slice before the web and API scaffolds
- **Context:** Section 24 of the brief makes the first milestone a browser-playable vertical slice. Phase 1 also asks for Next.js and NestJS setup.
- **Decision:** Phase 1 delivers the monorepo, the Godot project, contracts, export tooling and CI. The Next.js and NestJS apps are created at the start of Phases 5 and 6.
- **Consequences:** The riskiest assumption (is it fun?) is tested first, and no idle scaffolding drifts out of date. The bridge contract is still defined now, so the game is built against it.

## ADR-0009: Original procedural assets for the prototype
- **Context:** No licensed assets exist yet, and the brief forbids unlicensed fonts, SFX and art.
- **Decision:** Sprites are authored as text grids in code, the 5×7 font is original, and SFX are synthesised at boot.
- **Consequences:** Zero licensing risk and a tiny `.pck`. The art and audio pass in Phase 7 replaces them through the same interfaces (`Sprites`, `Audio.play(name)`).

## ADR-0010: The site is lean Next.js with plain CSS, and the launcher owns the canvas
- **Context:** Phase 5 must hit Lighthouse ≥ 90 for performance and accessibility on the landing page and launch the game reliably in three browsers. React and Next.js alone are about 520 KB of uncompressed JavaScript before any of our code.
- **Decision:** Next.js 16 (App Router, Turbopack) with static pages and one global stylesheet using the game's palette (text colours darkened to pass WCAG AA). No CSS framework, web fonts or images: the hero illustration is inline SVG. Pages that only display progress read the save with small type guards and import `@the-margin/contracts/chapters` and `/keys`, so Zod (about 60 KB) ships only where messages and settings are validated (`/play`, `/settings`). The launcher drives Godot's `Engine` API with resize policy 0 and a fixed in-memory pack path, reading `build.json` beside the export.
- **Alternatives:** Tailwind or a component library (more CSS and JS for a handful of pages); embedding the exported `index.html` in an iframe (simpler, but the bridge, focus, sizing and fullscreen would all cross a frame boundary, and the save's origin would be the build's, not the site's); Godot's full-window resize policy (it would cover the toolbar).
- **Consequences:** Lighthouse measured performance 98–100 and accessibility 100 on the landing page. `/play` must always be reached by a full page load. The game's save stays on the site's origin wherever the build is hosted, so the site can read it. A CDN on another origin needs CORS on the build files (Phase 8).

