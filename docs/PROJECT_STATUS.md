# Project Status

_Last updated: 2026-11-07: Phase 4 pages 1.3–1.5._

## Current phase

**Phase 2 is done except for the human playtest. Phase 3 is done for Chapter 1's needs, and Phase 4 (Chapter 1) has started: pages 1.3–1.5 are built.** The Phase 2 prototype passes every automated test and has been browser-tested in Chromium, Firefox and WebKit. It has **not** been play-tested by people and is **not** deployed. The roadmap gates Phase 3 on that playtest (Risks R1, R2). The Phase 3 work so far covers word categories, crates, pressure plates, moving platforms, the eraser, ink and music. Chapter 1 pages 1.4 and 1.5 need the first three whatever the playtest finds, so that work is low-regret; the eraser and ink are Chapter 4 and 5 mechanics, built now as sandboxes so the framework's data model covers them.

| Status level | Prototype pages 1.1–1.2 | Phase 3: crates, panel words, plates, platforms, eraser, ink, music | Phase 4: pages 1.3–1.5 |
|---|---|---|---|
| Implemented | ✅ | ✅ (sandbox pages `sb_mechanics`, `sb_weight`, `sb_platforms`, `sb_eraser`, `sb_ink`, `sb_music`) | ✅ (`ch01_p03`–`ch01_p05`, reached from page 1.2) |
| Automated tests (Godot headless) | ✅ | ✅ 42 tests | ✅ 7 tests, including each page solved through real physics (75 total) |
| Browser-tested, Chromium + Firefox (Windows, 2026-11-02) | ✅ 6/6 | Not yet (sandbox pages aren't reachable from the title) | Firefox: on the PR's CI |
| Browser-tested, Chromium + WebKit (macOS, 2026-11-07) | ✅ 8/8 | n/a | Arrival on 1.3 only (the e2e solves page 1 and lets page 2 turn itself) |
| Human playtest | ❌ Required (Risk R1, R2) | ❌ | ❌ |
| Production-deployed | ❌ (Phase 8–9) | ❌ | ❌ |

## Completed milestones

- **Phase 0:** product overview, GDD (with the evaluated chapter plan), state diagrams, TDD (architecture, monorepo, Godot architecture, integration, deployment), database + ER diagram, save schema, API contract, risk register, roadmap and backlog, ADR-0001…0009.
- **Phase 1 (game-first subset, ADR-0008):** pnpm monorepo, Godot 4.7.2 project (Compatibility renderer, 640×360 integer scaling, single-threaded web export), `packages/contracts` (Zod), Godot wrapper and export scripts (Windows and macOS local binaries), a static server, and CI on GitHub Actions.
- **Phase 2:** browser-playable vertical slice. Panels and links, the reader's hand (mouse + keyboard), words and slots, a door that obeys its label, narrative triggers, original font/art/SFX, title/pause/reset/end card, versioned local save with a synchronous `localStorage` mirror, and a web bridge that validates against the contracts.
- **Phase 3 (started 2026-11-03):**
  - Words `LEFT`, `RIGHT`, `HEAVY`, `LIGHT` added; categories `motion`, `halt` and `mass` now have handlers.
  - **Crate** object: moves along its `motion` word until blocked, STOP holds it in mid air, and it falls when unlabelled. It carries Nib, never crushes Nib, and stays inside its panel. Its resting position is saved (`pages.<id>.objects`, an optional field, so older v1 saves still load).
  - **Narrator captions can hold bold words** (shared `Lettering` with speech bubbles). Words in a panel's caption act on the panel: HEAVY or STOP pins a lifted panel (drawn flat, refuses to move). This is the page 1.4 mechanic.
  - **Sandbox page** `sb_mechanics`, opened with `godot --path apps/game -- --page=sb_mechanics`. Sandbox play never writes the save.
- **Phase 3 (2026-11-05): weight.**
  - Crates accept `mass`: as drawn they weigh 1, HEAVY 2, LIGHT 0.5. Mass-labelled crates fall as drawn; LIGHT ones drift down at half speed.
  - **Pressure plates** (`button` objects): pressed while the weight resting on them reaches `needs × label mass`. Nib weighs 1 and adds to a crate Nib stands on. A plate's label accepts `mass` (LIGHT halves what it needs, HEAVY doubles it).
  - Doors can be wired to a plate (`"button": "<id>"`) and stand open while it is held; the door's own label still wins. New story events `button_pressed` / `button_released`.
  - Plate state is derived from positions, so the save format is unchanged; restoring a page settles plates silently.
  - Sandbox page `sb_weight` (`-- --page=sb_weight`) + 6 headless tests; page validation checks plate bounds and door→button references.
- **Phase 3 (2026-11-06): the eraser (GDD §4.3).**
  - **Pencil sketches** (`sketches` in panel data): graphite lines, solid while drawn. Ink is never a sketch, so ink can't be erased. A sketch can start `erased` (a smudge).
  - **The eraser is found, not given:** an `eraser` object Nib walks into. It becomes an ability (`progress.abilities: ["eraser"]`), so it is never drawn again on any page.
  - **X erases** the pencil line in reach, which removes its collision and leaves its crumbs; X on a smudge draws it back for those crumbs. The prompt explains refusals: ERASER FULL, NEEDS N CRUMBS, SOMETHING IS IN THE WAY (never over Nib or a crate). Crumbs show as pips above Nib.
  - **Crumbs are derived, never saved:** each sketch's difference from how it was drawn. The eraser holds `eraser_holds` (default 3), so you can't erase more than you can put back. Saves store `pages.<id>.sketches` (id → drawn, optional, so older v1 saves still load); a save implying an impossible crumb count resets that page's sketches.
  - New story events `eraser_found`, `sketch_erased`, `sketch_restored`; a "rub" SFX; the artist's pink `Palette.ERASER`.
  - Sandbox page `sb_eraser` (`-- --page=sb_eraser`): rub out a pencil wall (which fills the 2-crumb eraser), draw a step back to make room, erase the shelf so its crate drops on a plate and opens the door, and draw the second step to reach it. 6 headless tests; page validation checks sketch bounds, unique ids and crumb costs within capacity; the contracts schema and a contract test cover `sketches`.
- **Phase 3 (2026-11-06): ink (GDD §4.4).** PR #3 (eraser) merged with green CI, including Firefox.
  - **Ink traces existing pencil only.** A sketch with an `ink` cost (dots above it) can be traced with C: it becomes ink, solid and permanent, and the eraser never targets it.
  - **Faint sketches** are layout pencil, drawn but not solid until inked. This reconciles "pencil is solid" (§4.3) with "tracing a sketched bridge makes it real" (§4.4); the GDD records the decision.
  - **Ink drops and inkwells** (`ink` objects with `drops`) are collected by walking in, if the hat (`ink_holds`, default 3) has room for all of it; otherwise the pickup stays and says HAT FULL. The first ink adds `"ink"` to `progress.abilities`.
  - **Ink is derived like crumbs:** drops collected (`pages.<id>.collected`) less the cost of inked sketches. Sketch state in the save is now `true | false | "inked"`; old boolean saves still load. Impossible saves reset the page's sketches.
  - The eraser and ink share a `SketchTool` base (reach, highlight, refusal prompts, pips); their prompts stack when both have a target. New events `ink_collected`, `sketch_inked`; "ink" and "drip" SFX.
  - Sandbox page `sb_ink` (`-- --page=sb_ink`): the hat holds two, so the inkwell won't fit until a faint step is traced; trace two steps over an ink wall, then a third in the next panel to reach the door. 6 headless tests; page validation checks ink costs, drops and that faint sketches are traceable; contracts cover `"inked"` and `collected`.
- **Phase 3 (2026-11-06): music (GDD §10, TDD §3.7a).** Ink branch pushed as PR #4 so CI runs Firefox against it.
  - **Scores are data** (`data/music.json`): tempo, bars and step patterns for four synthesised instruments (`felt`, `pluck`, `pad`, `tap`). `MusicSynth` renders into a circular buffer, so loops are seamless. Everything is original and synthesised at runtime (ADR-0009, `ASSETS.md`).
  - **Chapter 1 has a loop, "Margins"** (A minor, 84 bpm, 23 s). Pages play their chapter's track or name one with `music` (`""` for silence); a page in the same chapter never restarts it; a new track cross-fades.
  - **No threads on the web, so tracks build a slice per frame** (4 ms during play, 12 ms on the title, which warms up the resume page's track). Music renders at 16 kHz. On the web export, `ch01` was ready 2.8 s after boot in Chromium and 1.9 s in WebKit.
  - **Ducking:** −12 dB while the artist letters a caption or shakes a panel. Holds nest, and a caption freed mid-sentence (page reset) lets go, so a duck can't leak.
  - **MUSIC volume** in the title and pause settings (the `musicVolume` setting already existed).
  - Sandbox `sb_music` (`-- --page=sb_music`): drag the lifted panel and the artist complains, ducking the music. 10 headless tests.
  - The test runner now fails a suite that doesn't parse instead of hanging the run.
- **Phase 3 (2026-11-06): moving platforms (GDD §4.2, backlog 22).** PR #4 (ink) merged with green CI; the music branch is PR #5.
  - **Platforms** (`platform` objects) are planks on a drawn `rail` (`{axis, min, max}`). As drawn they shuttle between the rail ends, resting 1 s at each. A `motion` word along the rail sends one to that end and holds it; STOP holds it in place. A lift refuses LEFT/RIGHT and a ferry refuses UP/DOWN (a new per-word `WordSlot.filter`), so a platform only takes words it can obey.
  - Platforms carry Nib and crates (the crate's move is split into `can_step` and `shift` so a platform can check and carry it), never move into Nib, and a shuttling platform that meets Nib turns back.
  - **Fixed a latent bug:** Nib picked up Godot's platform velocity from anything carrying them, so riding sideways moved Nib twice as far (a ferry ride drifted 21 px). Nib now sets `platform_floor_layers = 0`; carriers move Nib explicitly, as the Player docs always said.
  - Restored slot words are now checked against what the slot accepts, so a tampered save can't put LEFT on a lift (or OPEN on a crate).
  - Positions share `pages.<id>.objects` with crates (no schema change) and are restored only if on the rail.
  - Sandbox `sb_platforms` (`-- --page=sb_platforms`) with the three GDD uses: ride a drawn lift to a ledge, take STOP off a ferry to cross a pit, and lift a crate (LEFT on the crate, UP on the lift) until it slides onto a plate that opens the door. 8 headless tests, including the whole page solved with real walking and hopping (onto a moving lift); page validation checks rails stay in their panels and labels run along them.

- **Phase 4 (2026-11-07): Chapter 1 pages 1.3–1.5 (GDD §6).** Platforms (PR #6) had been merged into `phase3/music` after that branch was already merged, so it never reached `main`; this branch carries it.
  - **Page 1.2 turns to 1.3** with a new story action, `turn_page` (the door exit and the story now share `ComicPage.turn()`). The end card now follows page 1.5.
  - **1.3 "Next Door":** a horizontal track and a vertical one in a forced order (fetch Nib with H, raise V empty, ride V down).
  - **1.4 "The Heavy Room":** taking HEAVY from a room's caption frees it to slide; the same word on a box under a low shelf presses the plate that opens the door.
  - **1.5 "The Stairs":** lower a room to the start, ride a crate UP to a ledge, raise the room to the top.
  - **Fixed: a crate's label couldn't be reached while standing on it**, although its comment said it could (the sandbox test called `slot.put` directly). The label is now reachable with Nib's feet anywhere from just above the crate's top to 20 px below its bottom.
  - **Fixed: a crate or platform lifting Nib to a ceiling wedged them.** It stopped with Nib's head touching, overlapping ceiling and carrier by a hair, and Nib could no longer walk. Carriers now leave `Player.HEADROOM` (1 px), and the sandbox test now walks off the risen crate.
  - 7 headless tests in `test_chapter1.gd` (each page solved through real walking and hopping, plus checks that 1.3's order matters, 1.4's box can't be pressed without HEAVY, and 1.5's ledge can't be reached without UP); page validation covers the new pages; the capture tool renders them.

## Test status

| Suite | Command | Result |
|---|---|---|
| Godot unit + integration (incl. real-physics playthroughs of pages 1.1 and 1.3–1.5, crate/panel-word, plate, platform, eraser, ink and music tests) | `pnpm game:test` | 75 passed |
| Contracts (save schema incl. optional `objects`, `sketches` and `collected`, conflict resolution, bridge) | `pnpm --filter @the-margin/contracts test` | 8 passed |
| Browser e2e: boot; solving page 1 and arriving on page 3; immediate-reload persistence; keyboard panel mode | `pnpm e2e` (+ `E2E_WEBKIT=1` on macOS) | Chromium 4/4, WebKit 4/4 on macOS (2026-11-07 with pages 1.3–1.5; earlier re-runs 2026-11-06 with music, and again with platforms, since Nib no longer takes platform velocity from floors. Earlier, after the eraser changes, one WebKit run of the page-1 solve failed once alongside the Firefox launch failures, then passed 4 times in a row, so it's a timing flake to watch). Firefox could not launch inside this session's macOS sandbox (an environment limit, not a game failure); CI covers Firefox on Linux |

## Known issues and limitations

1. The `localStorage` mirror is unavailable when a browser blocks site storage (some private modes). The game still plays, with the old IndexedDB-only behaviour.
2. Placeholder-grade art and synthesised audio. Only Chapter 1 has music; the title screen plays only room tone. The music isn't cached between sessions, so it is rebuilt on every boot (caching the rendered loop in `user://` is a possible optimisation).
3. Only Chapter 1 pages 1–5 are in the story; the end card follows page 5 and says the chapter continues.
4. A crate can't carry another crate (a rising crate stops under one), so stacked crates don't add weight to a plate. LIGHT has no effect on panels yet. Plates have no puzzle on a story page yet.
5. Captions that hold words can't be rewritten by story actions (validated by `test_pages`).
6. The sandbox page can only be opened from the command line or editor, not from the web build.
7. The 38 MB `index.wasm` is the stock engine template (≈9 MB with Brotli). A custom slim template is a Phase 8 optimisation.
8. CI was green on PR #2 and its merge to `main` (2026-11-06: Godot tests, web export, contracts, Chromium + Firefox on Linux). CI was also green on PR #3 (eraser). Firefox has not run against the ink changes yet; it runs on their PR. Headless Firefox on the GPU-less runner has no WebGL2, so CI runs Firefox headed under `xvfb-run` (`E2E_HEADED=1`).
9. The workflow's actions (`checkout`, `setup-node`, `pnpm/action-setup`, `upload/download-artifact`, all v4) still target the deprecated Node 20 runtime; bumping them is a small follow-up.
10. The eraser targets only whole sketches (no partial rubbing), and sketches are axis-aligned rects. Erasing a crate's support while Nib stands underneath leaves the crate hovering above Nib until Nib steps away (crates never crush Nib). The "underdrawing revealed by erasing" (GDD §4.3) isn't built yet.
11. **Only the first bold word in a narrator caption can be reached.** Every word in a caption shares the caption's `reach_at` point, and the nearest-slot pick keeps the first on a tie, so in `sb_mechanics` ("CRATES GO *UP*. UNTIL THEY *STOP*.") STOP can never be targeted. Story pages so far have one word per caption; `sb_platforms` uses two captions. A fix needs a design call (per-word reach points, or cycling targets).
12. Page 1.5 has one recovery that needs a page reset: UP placed on the crate from beside it (not on top) sends it up empty, out of reach. Watch for it in the playtest; a softer recovery would need a design change.

## Architectural decisions

See [ADRs](architecture/decisions/README.md): 0001 engine/renderer/threads, 0002 resolution, 0003 pages as data, 0004 words as data, 0005 in-house test runner, 0006 pnpm without Turborepo, 0007 opaque cookie sessions, 0008 slice before web/API scaffolds, 0009 procedural original assets. The Phase 3 changes follow these ADRs; the crate collision approach is documented in TDD §3.5.

## Next recommended tasks

1. **Playtest pages 1.1–1.5 with 3–5 people** who haven't seen them (`pnpm game:export && pnpm game:serve`). Measure the time to the first slide, whether players discover bold words unaided, and whether 1.4's "the word that freed the room is the key" lands. This still gates the rest of Chapter 1 (R1, R2).
2. Merge this branch (it also carries the platforms work that missed `main`) once CI, including Firefox, is green.
3. Pages 1.6–1.8 (GDD §6). 1.6 needs a speech bubble that lies on the floor and 1.8 needs an artist action that erases a whole panel; both are new story/object work. 1.7 (carry a word through three rearranged panels) can be built from data.
4. Decide how multi-word captions are reached (known issue 11) before a page needs one.
5. Listen to "Margins" in a browser and tune by ear (levels, duck depth).
