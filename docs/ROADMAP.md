# Roadmap and Backlog

## Phases and completion criteria

| Phase | Goal | Done when |
|---|---|---|
| 0 Discovery | Design and architecture documents | Docs in `docs/` reviewed; prototype scoped ✅ |
| 1 Foundation | Monorepo, Godot project, contracts, CI | `pnpm -r build` passes; Godot tests pass headless; web export builds in CI |
| **2 Prototype** | Browser-playable pages 1.1–1.2 | A first-time player solves 1.1 in the **browser export** without help; save/refresh restores state; all automated tests green |
| 3 Mechanic framework | Panels (resize/swap), words (all categories), eraser, ink, triggers | Each system has unit tests plus one sandbox page |
| 4 Chapter 1 | Pages 1.1–1.8, audio, polish | Playtest: ≥ 70 % unaided completion, median 20–35 min |
| 5 Web platform | Landing, launcher, auth UI, chapters, settings | The game launches reliably from `/play` in 3 browsers; Lighthouse ≥ 90 performance and accessibility on the landing page |
| 6 Backend | Auth, saves, progression, achievements, settings | API integration tests green; offline→online sync and conflict tests green |
| 7 Expansion | Chapters 2+, art and audio pass | Per-chapter playtest bars |
| 8 Production | Perf, security, monitoring, deploy automation | Release checklist complete in staging |
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
3. Art kernel: palette, original 5×7 pixel font (regular + bold), text-grid sprites.
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
21. Panel resize and swap tracks; word categories `motion`, `halt`, `mass`.
22. Crates/platforms reacting to `motion`.
23. Eraser prototype on a sandbox page (pencil layer, crumbs).
24. Ink trace prototype.
25. Music system with per-chapter loops and ducking.

### Later
26. Pages 1.3–1.8 and the chapter finale.
27. Next.js app: landing, `/play` launcher with the bridge adapter.
28. NestJS app: auth, saves, progression, achievements, settings; Prisma schema and migrations.
29. E2E: register → play → save → second session restores from cloud.
30. Infrastructure: S3/CloudFront build upload, staging environment, monitoring.
