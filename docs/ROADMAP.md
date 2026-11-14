# Roadmap and Backlog

## Phases and completion criteria

| Phase | Goal | Done when |
|---|---|---|
| 0 Discovery | Design and architecture documents | Docs in `docs/` reviewed; prototype scoped ✅ |
| 1 Foundation | Monorepo, Godot project, contracts, CI | `pnpm -r build` passes; Godot tests pass headless; web export builds in CI ✅ |
| 2 Prototype | Browser-playable pages 1.1–1.2 | A first-time player solves 1.1 in the **browser export** without help; save/refresh restores state; all automated tests green (automated ✅, human playtest pending) |
| 3 Mechanic framework (done for Chapter 1; resize/swap deferred to Chapter 2) | Panels (resize/swap), words (all categories), eraser, ink, triggers, music | Each system has unit tests plus one sandbox page |
| 4 Chapter 1 (reworked 2026-11-12 after playtest feedback) | Pages 1.1–1.8, audio, polish | Playtest: ≥ 70 % unaided completion, median 20–35 min ✅ (met 2026-11-14) |
| **5 Web platform** (automated bar met: landing, launcher, auth UI, chapters, settings) | Landing, launcher, auth UI, chapters, settings | The game launches reliably from `/play` in 3 browsers; Lighthouse ≥ 90 performance and accessibility on the landing page |
| **6 Backend** (automated bar met: API integration, offline→online sync and conflict tests) | Auth, saves, progression, achievements, settings | API integration tests green; offline→online sync and conflict tests green |
| **7 Expansion** (started 2026-11-14: Chapter 2 "The Border") | Chapters 2+, art and audio pass | Per-chapter playtest bars |
| **8 Production** (started: staging pipeline) | Perf, security, monitoring, deploy automation | Release checklist complete in staging |
| 9 Release | Production deploy | The deployed game works end to end (E2E suite against production) |

**Ordering note (ADR-0008):** the brief lists Phase 1 before Phase 2, but its first assignment says the first implementation milestone is a browser-playable slice, not a scaffolded website. Phase 1 therefore covers only what the prototype needs: the monorepo root, the Godot project, `packages/contracts`, export scripts and CI. The Next.js and NestJS scaffolds move to the start of Phases 5 and 6, where they get built for real instead of sitting idle as empty shells.

## Prototype definition (smallest test of the central mechanic)

**Hypothesis:** players enjoy realising that (a) the page layout is the level, (b) they can move the room they are standing in, and (c) words are objects that rewrite behaviour.

**Content:** Page 1.1 (5 panels: 1 slide, 1 word, 1 ride-the-panel, 1 door), Page 1.2 (ending), title screen, pause menu, synthesised SFX, local save.

**Out of scope:** website, accounts, achievements, eraser, ink, music beyond an ambient loop.

## Backlog (ordered by dependency, then priority)

### Now (Phase 1 + 2)
1. Repo root: README, `.gitignore`, `.editorconfig`, pnpm workspace, `.godot-version`.
2. Godot project config (renderer, resolution, stretch, input map, autoloads).
3. Art kernel: palette, original 5×7 pixel font (regular + bold), text-grid sprites. *(Replaced by hand-inked vector art, ADR-0013.)*
4. Audio kernel: SFX synthesiser, audio autoload, web audio unlock.
5. `PanelLinks` pure solver + tests.
6. `ComicPanel` (draw, clip, generated border collision, bridges).
7. Page builder from JSON + page validation tests.
8. Player controller (walk, hop, coyote, buffer, animation).
9. Reader's hand: mouse drag + keyboard panel mode; refusal rules.
10. Word library, slots, speech bubbles, labels, interaction verbs + tests.
11. Door object (category `state`) and exit.
12. Captions + story triggers (rewrite, write, wait, shake).
13. Page 1.1 and 1.2 data; solution-playthrough test.
14. Scene router: title → page → page turn → end card; pause menu; reset.
15. Save manager (versioned, backups, migrations) + settings + tests.
16. Web bridge autoload + `packages/contracts` bridge and save schemas.
17. Web export preset, export script, local static server.
18. Playwright smoke + playthrough + reload-persistence test on the real export.
19. CI: Godot tests, export, artifact checks, contracts typecheck.
20. Project status + ADRs updated.

### Next (Phase 3)
21. Word categories `motion`, `halt`, `mass` ✅ (crates; HEAVY/STOP on a panel's caption pins it; sandbox `sb_mechanics`). Panel resize and swap tracks: not started (Chapter 2 mechanic, so it follows Chapter 1 per R7).
22. Crates reacting to `motion`/`halt` ✅. Pressure plates and crate `mass` ✅ (wired doors, plate labels; sandbox `sb_weight`). Moving platforms ✅ (planks on rails that shuttle as drawn and obey `motion`/`halt`, carry Nib and crates; sandbox `sb_platforms`).
23. Eraser prototype on a sandbox page (pencil layer, crumbs) ✅ (`sketches` in panel data, the eraser as a found ability, derived crumbs with a capacity; sandbox `sb_eraser`).
24. Ink trace prototype ✅ (traceable and `faint` sketches, ink drops and inkwells, the hat's capacity, derived ink; both tools share `SketchTool`; sandbox `sb_ink`).
25. Music system with per-chapter loops and ducking ✅ (scores as data in `data/music.json`, synthesised incrementally; chapter 1 "Margins"; ducks while the artist letters or shakes; MUSIC volume in settings; sandbox `sb_music`).

### Now (Phase 7)
31. Chapter 2 mechanics: swapping panels and stretching borders (GDD §4.9, §4.10), with sandboxes and tests ✅.
32. Chapter 2 pages 2.1–2.8 (GDD §6b), each solved through real physics; palette (newsprint and cyan) and music ✅; chapter cards between chapters ✅.
33. Chapter 2 playtest (same bar as Chapter 1). Next.

### Later
26. Pages 1.3–1.8 and the chapter finale ✅. 1.3–1.5 (`ch01_p03`–`ch01_p05`; 1.2 now turns to 1.3) and 1.6–1.8 (`ch01_p06`–`ch01_p08`: fallen bubbles, `erase_panel`, `panel_entered`; the end card follows 1.8), each with a real-physics solution test. Finishing the chapter records `completedChapters` and sends `CHAPTER_COMPLETED`; the browser e2e plays the finale from a seeded save. **Reworked (2026-11-12)** after playtest feedback: hand-inked art (ADR-0013), scene captions and close-ups (GDD §4.7, §4.8), and pages 1.3–1.7 rebuilt with a different verb and goal each. Next: the Chapter 1 playtest (Phase 4 exit bar).
27. Next.js app: landing, `/play` launcher with the bridge adapter ✅ (`apps/web`, ADR-0010; plus chapters and settings pages, shared settings via `SETTINGS_UPDATED`, `build.json`, a Lighthouse gate in CI). The auth UI (`/account`, header) ✅.
28. NestJS app: auth, saves, progression, achievements, settings; Prisma schema and migrations ✅ (`apps/api`, ADR-0011; 28 integration tests on a real Postgres in CI).
29. E2E: register → play → save → second session restores from cloud ✅ (`specs/cloud.spec.ts`, plus offline→online and conflict; the sync client is `apps/web/src/sync/`).
30. Infrastructure: staging environment ✅ pipeline (Vercel + Fly.io + Neon, game bundled into the site; ADR-0012, DEPLOY.md), live once accounts are set up. Next: monitoring, production environment.
