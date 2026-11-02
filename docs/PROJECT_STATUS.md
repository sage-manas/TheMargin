# Project Status

_Last updated: 2026-11-02, end of the Phase 0–2 session._

## Current phase

**Phase 2: core gameplay prototype.** It is implemented, passes its automated tests, and has been browser-tested in Chromium. It has **not** been play-tested by people and is **not** deployed.

| Status level | Prototype pages 1.1–1.2 |
|---|---|
| Implemented | ✅ |
| Automated tests (Godot headless) | ✅ 25/25 |
| Browser-tested (real web export, Chromium + Firefox, Windows) | ✅ 6/6 Playwright tests; the immediate-reload test passed 8/8 when repeated |
| Browser-tested (WebKit/Safari) | ❌ Not yet run |
| Human playtest | ❌ Not done. Required before Phase 3 (Risk R1, R2) |
| Production-deployed | ❌ (Phase 8–9) |

## Completed milestones

- **Phase 0:** product overview, GDD (with the evaluated chapter plan), state diagrams, TDD (architecture, monorepo, Godot architecture, integration, deployment), database + ER diagram, save schema, API contract, risk register, roadmap and backlog, ADR-0001…0009.
- **Phase 1 (game-first subset, ADR-0008):** pnpm monorepo, Godot 4.7.2 project (Compatibility renderer, 640×360 integer scaling, single-threaded web export), `packages/contracts` (Zod, five tests), Godot wrapper and export scripts, a static server, and a CI workflow (written, but not yet run on GitHub).
- **Phase 2:** browser-playable vertical slice:
  - Panel system: data-driven panels, a pure link solver, generated border collision with gutter tunnels, lifted panels on tracks, the reader's hand (mouse drag + keyboard panel mode), a refusal when Nib is in a gutter, and carrying Nib along when their own panel moves.
  - Word system: data-driven words and categories, slots in speech bubbles and on object labels, take/place/swap, sentence gaps as mistake recovery.
  - Door that obeys its label; exit door → page turn.
  - Narrative triggers: a caption that rewrites itself when the floors first line up; NPC emotes; the artist's scrawl on page 1.2; achievements emitted to the host.
  - Original 5×7 font, text-grid sprites, halftone and paper shaders, page-turn shader, procedurally synthesised SFX and ambience (no third-party assets).
  - Title screen, pause menu (Esc/P, auto-pause on focus loss), hold-R reset, end card, reduced-motion and volume settings.
  - Versioned local save with validation, backup, quarantine of corrupt files, read-only protection for newer-version saves, and save/restore of the full page state.
  - Web bridge implementing the documented message contract; every message emitted in the browser tests validates against `packages/contracts`.

## Test status

| Suite | Command | Result |
|---|---|---|
| Godot unit + integration (incl. a real-physics solution playthrough) | `pnpm game:test` | 25 passed |
| Contracts (save schema, conflict resolution, bridge) | `pnpm test` | 5 passed |
| Browser e2e: boot; solving page 1 with real keyboard and mouse; immediate-reload persistence | `pnpm e2e` (Chromium + Firefox) | 6 passed |

## Fixed this session (found by browser testing, not visible in the editor)

- The web bridge never initialised in browsers (the `eval` type check failed); it now uses `get_interface`.
- The title screen rendered without its paper background (anchor preset misuse); all full-screen UI now uses explicit anchors and offsets.
- **Progress could be lost on a refresh:** `user://` reaches IndexedDB asynchronously, and reloads up to about 1 s after a save restored the previous save. `SaveManager` now mirrors every save synchronously to `localStorage` and loads whichever copy has the higher revision. An immediate reload now restores 8/8 times.

## Known issues and limitations

1. The `localStorage` mirror is unavailable when a browser blocks site storage (some private modes). The game still plays, with the old IndexedDB-only behaviour.
2. Placeholder-grade art and synthesised audio. The direction is intentional and consistent, but this is not final art. There is no music yet, only room-tone ambience.
3. Only Chapter 1 pages 1–2 exist; the end card says so.
4. The keyboard alternative for panels (Q) exists but has only been unit-checked through the shared movement API, not exercised in a browser test.
5. WebKit/Safari not verified. Tested on Windows only.
6. The 38 MB `index.wasm` is the stock engine template (≈9 MB with Brotli). A custom slim template is a Phase 8 optimisation.
7. CI runs on GitHub Actions and is green on PR #1. All jobs pass on Linux: Godot tests, web export, contracts, and 6/6 browser tests (Chromium + Firefox). Headless Firefox on the GPU-less runner has no WebGL2, so CI runs Firefox headed under `xvfb-run` (`E2E_HEADED=1`). The workflow's actions still target the deprecated Node 20 runtime; bumping them is a small follow-up.

## Architectural decisions (this session)

See [ADRs](architecture/decisions/README.md): 0001 engine/renderer/threads, 0002 resolution, 0003 pages as data, 0004 words as data, 0005 in-house test runner, 0006 pnpm without Turborepo, 0007 opaque cookie sessions, 0008 slice before web/API scaffolds, 0009 procedural original assets.

## Next recommended tasks

1. **Playtest the prototype with 3–5 people** who haven't seen it (`pnpm game:export && pnpm game:serve`). Measure the time to the first slide and whether players discover bold words unaided. This gates Phase 3.
2. Run the e2e suite on WebKit; push to a remote so CI runs.
3. Phase 3: panel resize/swap, the `motion` word category with crates, an eraser sandbox page.
4. Pages 1.3–1.8 (GDD §6) to complete Chapter 1.
