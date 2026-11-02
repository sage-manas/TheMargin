# Project Status

_Last updated: 2026-11-03: WebKit verification and the first Phase 3 slice._

## Current phase

**Phase 2 is done except for the human playtest. Phase 3 (mechanic framework) has started.** The Phase 2 prototype passes every automated test and has been browser-tested in Chromium, Firefox and WebKit. It has **not** been play-tested by people and is **not** deployed. The roadmap gates Phase 3 on that playtest (Risks R1, R2). The Phase 3 work so far is limited to word categories and crates. Chapter 1 pages 1.4 and 1.5 need them whatever the playtest finds, so this work is low-regret.

| Status level | Prototype pages 1.1–1.2 | Phase 3: crates, panel words |
|---|---|---|
| Implemented | ✅ | ✅ (sandbox page `sb_mechanics`) |
| Automated tests (Godot headless) | ✅ | ✅ 6 new tests (31 total) |
| Browser-tested, Chromium + Firefox (Windows, 2026-11-02) | ✅ 6/6 | Not yet (sandbox pages aren't reachable from the title) |
| Browser-tested, Chromium + WebKit (macOS, 2026-11-03) | ✅ 8/8, including the new keyboard panel-mode test | n/a |
| Human playtest | ❌ Required before Phase 3 proper (Risk R1, R2) | ❌ |
| Production-deployed | ❌ (Phase 8–9) | ❌ |

## Completed milestones

- **Phase 0:** product overview, GDD (with the evaluated chapter plan), state diagrams, TDD (architecture, monorepo, Godot architecture, integration, deployment), database + ER diagram, save schema, API contract, risk register, roadmap and backlog, ADR-0001…0009.
- **Phase 1 (game-first subset, ADR-0008):** pnpm monorepo, Godot 4.7.2 project (Compatibility renderer, 640×360 integer scaling, single-threaded web export), `packages/contracts` (Zod), Godot wrapper and export scripts (Windows and macOS local binaries), a static server, and CI on GitHub Actions.
- **Phase 2:** browser-playable vertical slice. Panels and links, the reader's hand (mouse + keyboard), words and slots, a door that obeys its label, narrative triggers, original font/art/SFX, title/pause/reset/end card, versioned local save with a synchronous `localStorage` mirror, and a web bridge that validates against the contracts.
- **Phase 3 (started 2026-11-03):**
  - Words `LEFT`, `RIGHT`, `HEAVY`, `LIGHT` added; categories `motion`, `halt` and `mass` now have handlers.
  - **Crate** object: moves along its `motion` word until blocked, STOP holds it in mid air, and it falls when unlabelled. It carries Nib, never crushes Nib, and stays inside its panel. Its resting position is saved (`pages.<id>.objects`, an optional field, so older v1 saves still load).
  - **Narrator captions can hold bold words** (shared `Lettering` with speech bubbles). Words in a panel's caption act on the panel: HEAVY or STOP pins a lifted panel (drawn flat, refuses to move). This is the page 1.4 mechanic.
  - **Sandbox page** `sb_mechanics`, opened with `godot --path apps/game -- --page=sb_mechanics`. Sandbox play never writes the save.

## Test status

| Suite | Command | Result |
|---|---|---|
| Godot unit + integration (incl. real-physics playthrough and crate/panel-word tests) | `pnpm game:test` | 31 passed |
| Contracts (save schema incl. optional `objects`, conflict resolution, bridge) | `pnpm --filter @the-margin/contracts test` | 6 passed |
| Browser e2e: boot; solving page 1; immediate-reload persistence; keyboard panel mode | `pnpm e2e` (+ `E2E_WEBKIT=1` on macOS) | Chromium 4/4, WebKit 4/4 on macOS. Firefox could not launch inside this session's macOS sandbox (an environment limit, not a game failure); CI covers Firefox on Linux |

## Known issues and limitations

1. The `localStorage` mirror is unavailable when a browser blocks site storage (some private modes). The game still plays, with the old IndexedDB-only behaviour.
2. Placeholder-grade art and synthesised audio. No music yet, only room-tone ambience.
3. Only Chapter 1 pages 1–2 are in the story; the end card says so.
4. Crates don't respond to `mass` yet, and a crate can't carry another crate (a rising crate stops under one). LIGHT has no effect anywhere yet.
5. Captions that hold words can't be rewritten by story actions (validated by `test_pages`).
6. The sandbox page can only be opened from the command line or editor, not from the web build.
7. The 38 MB `index.wasm` is the stock engine template (≈9 MB with Brotli). A custom slim template is a Phase 8 optimisation.
8. Firefox e2e has not been re-run since the Phase 3 changes. It runs on the next CI push.

## Architectural decisions

See [ADRs](architecture/decisions/README.md): 0001 engine/renderer/threads, 0002 resolution, 0003 pages as data, 0004 words as data, 0005 in-house test runner, 0006 pnpm without Turborepo, 0007 opaque cookie sessions, 0008 slice before web/API scaffolds, 0009 procedural original assets. The Phase 3 changes follow these ADRs; the crate collision approach is documented in TDD §3.5.

## Next recommended tasks

1. **Playtest the prototype with 3–5 people** who haven't seen it (`pnpm game:export && pnpm game:serve`). Measure the time to the first slide and whether players discover bold words unaided. This still gates the rest of Phase 3.
2. Push so CI runs Firefox and Chromium against the Phase 3 build.
3. Phase 3 remainder: buttons (pressure plates) and crate `mass`; the eraser sandbox; the ink trace prototype; the music system. Panel resize/swap is a Chapter 2 mechanic and follows Chapter 1 (R7).
4. Phase 4: pages 1.3–1.8 (GDD §6). Pages 1.4 (HEAVY caption) and 1.5 (UP crate staircase) can now be built from data alone.
