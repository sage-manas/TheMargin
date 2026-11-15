# Risk Register

Scores are likelihood × impact on a 1–3 scale each (max 9). Reviewed at the end of every phase.

| # | Risk | L | I | Score | Mitigation | Owner |
|---|---|---|---|---|---|---|
| R1 | The core mechanic isn't fun: panel sliding reads as a "slide puzzle", not a magical realisation | 1 | 3 | 3 | Prototype first (Phase 2) with the "move the room you're in" beat; playtest with 5 people before Phase 3; kill or rework anything that tests below the bar | Game Director |
| R2 | Players don't discover that bold words are takeable | 1 | 3 | 3 | Three redundant cues (bold, bobbing, reach outline + prompt); first word is alone in a short sentence; measured in playtests | Game Director |
| R3 | Godot web export issues: audio unlock, focus, IndexedDB sync timing, Safari quirks | 2 | 2 | 4 | Browser-test from the first prototype; Playwright on Chromium, Firefox, WebKit; single-threaded build avoids SharedArrayBuffer issues | QA |
| R4 | Wasm download size (~9 MB Brotli) hurts first load | 2 | 2 | 4 | CDN + Brotli, immutable caching, a launcher progress bar, and a custom template build without unused modules later (expected about −40 %) | DevOps |
| R5 | Save loss from browser storage eviction, a cleared site, or **a refresh during the IndexedDB sync window** (measured in Phase 2: `user://` writes reach IndexedDB asynchronously; a reload immediately after a save restored the previous save, while a reload 1 s later restored correctly) | 2 | 3 | **6** | Cloud sync for signed-in users; `navigator.storage.persist()` requested by the launcher; rotating local backup; never overwrite newer-version saves. **Done (Phase 2):** the game mirrors every save to `localStorage` synchronously and loads the higher revision; an immediate reload restored 8/8 times in Chromium and Firefox | Backend + Frontend |
| R6 | Panel collision edge cases (player stuck in border, tunnelling when a panel moves) | 2 | 2 | 4 | One shared physics space, generated borders, gutter bridges with walls, refuse moves while in a gutter, solution-playthrough test | Godot Eng |
| R7 | Scope creep: seven chapters with distinct mechanics | 3 | 3 | **9** | Ship Chapter 1 complete before starting Chapter 2; every new mechanic needs a GDD entry with ≥ 3 puzzle uses | Director + Architect |
| R8 | The art is hard to read, or the identity is weak | 2 | 2 | 4 | **Feedback (2026-11-12): pixel props and scenes were often not understandable.** Moved to hand-inked vector art at full resolution with readability rules: heavy ink for usable things, grey scenery, red for where the reader can act, visible lanes for movable panels (ADR-0013, GDD §9). Recheck in the Chapter 1 playtest; a further art pass is budgeted in Phase 7 | Art |
| R9 | Licensing contamination (fonts, SFX, music) | 1 | 3 | 3 | Everything original or synthesised; `docs/ASSETS.md` licence ledger for anything added | Architect |
| R10 | Auth/session vulnerabilities | 1 | 3 | 3 | Opaque hashed sessions, Argon2id, CSRF double-submit, rate limits, security review in Phase 8 | Backend |
| R11 | Tooling drift (Godot version, export templates) between dev machines and CI | 2 | 1 | 2 | Pin 4.7.2 in `.godot-version`; CI downloads that exact version; export script asserts the version | DevOps |
| R12 | Accessibility gaps (mouse-only panel moving) | 2 | 2 | 4 | Keyboard panel mode in the prototype; reduced-motion setting from day one | Frontend + Godot |

Review 2026-11-14: the reworked Chapter 1 met its playtest bar, so R1 and R2 drop to likelihood 1. R7 stays high as Chapter 2 starts: Chapter 2 adds only two verbs (swap, stretch) and reuses Chapter 1's.
