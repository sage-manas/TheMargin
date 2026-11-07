# Project Status

_Last updated: 2026-11-07: Phase 5 started: the site (`apps/web`) with the landing page, the `/play` launcher, chapters and settings._

## Current phase

**Phase 2 is done except for the human playtest. Phase 3 is done for Chapter 1's needs, and Phase 4 (Chapter 1) is content-complete: all eight pages are built and the end card follows the finale.** Phase 4 isn't done until its playtest bar is met (≥ 70 % unaided completion, median 20–35 min). The Phase 2 prototype passes every automated test and has been browser-tested in Chromium, Firefox and WebKit. It has **not** been play-tested by people and is **not** deployed. The roadmap gates Phase 3 on that playtest (Risks R1, R2). The Phase 3 work so far covers word categories, crates, pressure plates, moving platforms, the eraser, ink and music. Chapter 1 pages 1.4 and 1.5 need the first three whatever the playtest finds, so that work is low-regret; the eraser and ink are Chapter 4 and 5 mechanics, built now as sandboxes so the framework's data model covers them.

**Phase 5 (web platform) has started alongside the playtest**, since it doesn't depend on Chapter 2. The site has its landing page, `/play` launcher, chapters and settings pages; the auth UI is next. Of the exit bar, Lighthouse is met (landing page: performance 98–100, accessibility 100) and `/play` launches in Chromium and WebKit; Firefox runs on CI.

| Status level | Prototype pages 1.1–1.2 | Phase 3: crates, panel words, plates, platforms, eraser, ink, music | Phase 4: pages 1.3–1.5 | Phase 4: pages 1.6–1.8 |
|---|---|---|---|---|
| Implemented | ✅ | ✅ (sandbox pages `sb_mechanics`, `sb_weight`, `sb_platforms`, `sb_eraser`, `sb_ink`, `sb_music`) | ✅ (`ch01_p03`–`ch01_p05`, reached from page 1.2) | ✅ (`ch01_p06`–`ch01_p08`; the end card follows 1.8) |
| Automated tests (Godot headless) | ✅ | ✅ 42 tests | ✅ 7 tests, including each page solved through real physics (75 total) | ✅ 8 tests, including each page solved through real physics (83 total) |
| Browser-tested, Chromium + Firefox (Windows, 2026-11-02) | ✅ 6/6 | Not yet (sandbox pages aren't reachable from the title) | Firefox: on CI (PR #7 green) | Firefox: on the PR's CI |
| Browser-tested, Chromium + WebKit (macOS, 2026-11-07) | ✅ 10/10 | n/a | Arrival on 1.3 only (the e2e solves page 1 and lets page 2 turn itself) | 1.8 only, from a seeded save: erasure, L's ride and the end card ✅ |
| Human playtest | ❌ Required (Risk R1, R2) | ❌ | ❌ | ❌ |
| Production-deployed | ❌ (Phase 8–9) | ❌ | ❌ | ❌ |

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

- **Phase 4 (2026-11-07): Chapter 1 pages 1.6–1.8 (GDD §6), completing the chapter.** Page 1.5 now turns to 1.6, and the end card after 1.8 reads END OF CHAPTER 1.
  - **1.6 "The Empty Room":** the neighbour's room, empty. Their bubble lies on the floor as a solid thing; Nib climbs onto it to reach a ledge and takes OPEN from it for the door.
  - **1.7 "The Long Way":** carry OPEN through three lifted panels. R is pinned by STOP, so Nib lends OPEN to its caption to free it, and V has to be slid out from under R's shaft to become the bridge.
  - **1.8 "From the Top":** the artist rubs out the little room from 1.1 as soon as Nib is next door, and the space it leaves is what lets L rise and carry Nib to the exit.
  - **Fallen bubbles** (`bubbles` in panel data): a speech bubble with no speaker, solid and fixed at the widest its words can make it, with its words reached from on top.
  - **`erase_panel {panel, respawn}`** story action and **`panel_entered`** event. An erased panel has no collision, no links and takes up no space; the action waits for Nib to be wholly in another panel, nudges Nib clear of the closed border, and ducks the music while the eraser rubs the panel out row by row. Panels can also start `erased` in data.
  - **Fixed: saved panel positions were checked one at a time,** so a panel saved where another one *started* (1.7's R over V, 1.8's L in the erased room) was refused on reload and Nib was sent back to the spawn. Lasting erasures and their respawn now apply first, then all saved positions together; if any clash, all start over.
  - 8 headless tests: the chapter runs 1.1→1.8; each new page solved with real walking and hopping; 1.6's ledge needs the bubble and its word is only reachable from on top; 1.7 and 1.8 restore their saved positions; the erasure waits for Nib and is re-applied instantly on load. Page validation covers fallen bubbles, erased panels and erase targets (fixed, holding nothing the page needs, with a respawn in a room that stays). The capture tool renders the new pages and the erasure mid-rub.

- **Phase 4 (2026-11-07): the finale in a real browser.** PR #8 (pages 1.6–1.8) merged with green CI, including Firefox.
  - **Fixed: finishing Chapter 1 was never recorded.** The end card showed, but `progress.completedChapters` stayed empty and `CHAPTER_COMPLETED` (in the bridge contract since Phase 1) was never sent. Cloud conflict resolution scores a finished chapter at 1000 against 10 per page (SAVE_SCHEMA §5), so this had to be in place before Phase 6. The end now records the page's chapter (`GameState.complete_chapter`, idempotent) and sends `CHAPTER_COMPLETED {chapterId}` before the save is committed. Sandbox pages (chapter `sandbox`) never do.
  - **New e2e: "the finale erases the first room and ends the chapter".** It seeds a save at 1.8 through the `localStorage` mirror, then in the browser walks next door, waits for the erasure, drags L up into the space, walks in, rides L down and leaves through the door. It checks L's saved positions, `PAGE_COMPLETED`, `CHAPTER_COMPLETED` and `completedChapters: ["ch01"]`. The e2e's `requestSave` helper is now shared.
  - 1 new headless test (a chapter is recorded once and the save still validates).

- **Phase 5 (2026-11-07): the site (`apps/web`, backlog 27; ADR-0010).** PR #9 (finale e2e) merged.
  - **Next.js 16** (App Router, static pages, one stylesheet in the game's palette with AA-contrast text colours, no web fonts or images; the hero art is inline SVG). Pages: `/` (pitch, how it plays, controls; the play button becomes "Continue · page 1.x" when this browser has a save), `/chapters` (the catalogue with this browser's progress), `/settings`, `/play`, and a 404.
  - **The `/play` launcher drives Godot's `Engine` API** (TDD §5.3): bridge first, then `build.json`, the engine script, a missing-features check, and the engine on the launcher's own canvas (resize policy 0, sized in device pixels below a toolbar). Loading bar, error and unsupported-browser states, mute, fullscreen, and back to the site. It asks for persistent storage (R5). Every link to `/play` is a full page load because an engine starts once per document.
  - **Builds are loaded by URL** (`NEXT_PUBLIC_GAME_BUILD_URL`, default `/game`, proxied to `pnpm game:serve` locally). The export script now writes `build.json` (executable, game and Godot versions, file sizes) and checks for both audio worklets.
  - **Settings are shared with the game.** New contract message `SETTINGS_UPDATED {settings}`: the game sends it once the bridge is up and on every change, so the site's mirror follows the pause menu. `SET_SETTINGS` is now validated (`SettingsPatchSchema`: any subset plus `muted`). `muted` is new in the game: transient, never saved, so the launcher's mute can't leave the game silent next time.
  - **Contracts:** `SettingsSchema` (+ defaults checked against `settings.gd`), the chapter catalogue `CHAPTERS` (checked against `apps/game/data/pages`), `BuildManifestSchema`, `LOCAL_SAVE_KEY` (checked against `save_manager.gd`). The package is side-effect free and exposes `/chapters` and `/keys` subpaths, so pages that only display progress don't ship Zod.
  - Tests: 7 site unit tests (bridge queueing and validation, progress and continue labels, settings mirror), 5 new contract tests, 1 new headless test (mute is never saved), and 4 site e2e tests (landing and continue, chapters progress, `/play` boot taking the site's settings and echoing them back with no console errors, and the missing-build error). CI runs the site's unit tests, the site e2e and a Lighthouse gate (`infrastructure/scripts/lighthouse.mjs`, ≥ 90 for performance and accessibility).

## Test status

| Suite | Command | Result |
|---|---|---|
| Godot unit + integration (incl. real-physics playthroughs of pages 1.1 and 1.3–1.8, crate/panel-word, plate, platform, eraser, ink and music tests) | `pnpm game:test` | 85 passed |
| Contracts (save schema incl. optional `objects`, `sketches` and `collected`, conflict resolution, bridge, settings, chapter catalogue vs the game's pages, storage key vs the game) | `pnpm --filter @the-margin/contracts test` | 13 passed |
| Site unit tests (bridge, progress, settings mirror) | `pnpm --filter @the-margin/web test` | 7 passed |
| Lighthouse, landing page (production build) | `pnpm web:lighthouse` | Performance 98 and 100 (two runs), accessibility 100, best practices 100, SEO 100 |
| Browser e2e: boot; solving page 1 and arriving on page 3; immediate-reload persistence; keyboard panel mode; the 1.8 finale and end card from a seeded save; the site (landing, chapters, `/play` launch with settings, missing build) | `pnpm e2e` (+ `E2E_WEBKIT=1` on macOS) | Chromium 9/9, WebKit 9/9 on macOS (2026-11-07 with the site specs). Earlier: Chromium 5/5, WebKit 5/5 (2026-11-07 with the finale test; in the first full run WebKit's boot test failed once and then passed alone and in a full re-run, another timing flake to watch. Earlier 4/4 with pages 1.6–1.8, and earlier the same day with pages 1.3–1.5; earlier re-runs 2026-11-06 with music, and again with platforms, since Nib no longer takes platform velocity from floors. Earlier, after the eraser changes, one WebKit run of the page-1 solve failed once alongside the Firefox launch failures, then passed 4 times in a row, so it's a timing flake to watch). Firefox could not launch inside this session's macOS sandbox (an environment limit, not a game failure); CI covers Firefox on Linux |

## Known issues and limitations

1. The `localStorage` mirror is unavailable when a browser blocks site storage (some private modes). The game still plays, with the old IndexedDB-only behaviour.
2. Placeholder-grade art and synthesised audio. Only Chapter 1 has music; the title screen plays only room tone. The music isn't cached between sessions, so it is rebuilt on every boot (caching the rendered loop in `user://` is a possible optimisation).
3. Only Chapter 1 is in the story; the end card follows page 1.8. The browser e2e plays pages 1.1–1.2 and 1.8 (from a seeded save); 1.3–1.7 are covered by headless real-physics solutions only.
4. A crate can't carry another crate (a rising crate stops under one), so stacked crates don't add weight to a plate. LIGHT has no effect on panels yet. Plates have no puzzle on a story page yet.
5. Captions that hold words can't be rewritten by story actions (validated by `test_pages`).
6. The sandbox page can only be opened from the command line or editor, not from the web build.
7. The 38 MB `index.wasm` is the stock engine template (≈9 MB with Brotli). A custom slim template is a Phase 8 optimisation.
8. CI was green on PR #2 and its merge to `main` (2026-11-06: Godot tests, web export, contracts, Chromium + Firefox on Linux). CI was also green on PR #3 (eraser). Firefox has not run against the ink changes yet; it runs on their PR. Headless Firefox on the GPU-less runner has no WebGL2, so CI runs Firefox headed under `xvfb-run` (`E2E_HEADED=1`).
9. The workflow's actions (`checkout`, `setup-node`, `pnpm/action-setup`, `upload/download-artifact`, all v4) still target the deprecated Node 20 runtime; bumping them is a small follow-up.
10. The eraser targets only whole sketches (no partial rubbing), and sketches are axis-aligned rects. Erasing a crate's support while Nib stands underneath leaves the crate hovering above Nib until Nib steps away (crates never crush Nib). The "underdrawing revealed by erasing" (GDD §4.3) isn't built yet.
11. **Only the first bold word in a narrator caption can be reached.** Every word in a caption shares the caption's `reach_at` point, and the nearest-slot pick keeps the first on a tie, so in `sb_mechanics` ("CRATES GO *UP*. UNTIL THEY *STOP*.") STOP can never be targeted. Story pages so far have one word per caption; `sb_platforms` uses two captions. A fix needs a design call (per-word reach points, or cycling targets).
12. Page 1.5 has one recovery that needs a page reset: UP placed on the crate from beside it (not on top) sends it up empty, out of reach. Watch for it in the playtest; a softer recovery would need a design change.
13. Page 1.7's "lend a word" step relies on players reading SWAP OPEN as an offer rather than a loss. Watch whether players stall in R with OPEN in hand. A narrator nudge on the first swap is a cheap fix if they do.
14. The 1.8 erasure takes about 2 s and doesn't lock Nib; walking back into the sealed border during it is harmless. An erased panel can't be restored (no story action undoes it).
15. The site has no accounts yet: the auth UI is the next Phase 5 step, and it needs the Phase 6 API to do anything. Progress shown on the site is this browser's only.
16. `/play` and `/settings` ship Zod (about 60 KB) to validate bridge messages and settings; the landing and chapters pages don't.
17. A game build on a different origin from the site (the CDN) needs CORS headers on its files. Only same-origin `/game` has been tested.
18. `GAME_ERROR` messages are logged by the launcher but not shown to the player.

## Architectural decisions

See [ADRs](architecture/decisions/README.md): 0001 engine/renderer/threads, 0002 resolution, 0003 pages as data, 0004 words as data, 0005 in-house test runner, 0006 pnpm without Turborepo, 0007 opaque cookie sessions, 0008 slice before web/API scaffolds, 0009 procedural original assets. The Phase 3 changes follow these ADRs; the crate collision approach is documented in TDD §3.5.

## Next recommended tasks

1. **Playtest the whole of Chapter 1 (pages 1.1–1.8) with 3–5 people** who haven't seen it (`pnpm game:export && pnpm game:serve`). This is now the Phase 4 exit bar: ≥ 70 % unaided completion, median 20–35 min. Also measure the time to the first slide, whether players discover bold words unaided, whether 1.4's "the word that freed the room is the key" lands, whether 1.7's lend-a-word step is found (known issue 13), and whether 1.8's erasure reads as both loss and opening. This still gates Chapter 2 (R1, R2).
2. Merge the Phase 5 branch once CI, including Firefox and the Lighthouse gate, is green. That covers the third browser for the Phase 5 bar.
3. **Phase 5, next: the auth UI** (register, sign in, sign out, session state in the header) against the API contract, with the API mocked in e2e until Phase 6 builds it. Then Phase 6 can start: `apps/api` (NestJS + Prisma), whose progression rules can use `CHAPTERS` and whose `/settings` can use `SettingsSchema`.
4. Decide how multi-word captions are reached (known issue 11) before a page needs one.
5. Listen to "Margins" in a browser and tune by ear (levels, duck depth), including the duck during the 1.8 erasure.
