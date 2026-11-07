# THE MARGIN

*Escape the drawing.*

A browser-playable 2D puzzle-adventure. You play a tiny ink character who discovers their world is a comic book, and that its rules are editable because it is a drawing. Panels connect where their floors line up, the reader's hand can slide panels around the page (even the one you're standing in), and things obey what is written on them.

## Repository

```text
apps/game/          Godot 4.7 project (GDScript). The game.
apps/web/           Next.js site: landing, the /play launcher, chapters, settings
apps/api/           NestJS + Prisma API: auth, cloud saves, progression, achievements, settings
packages/contracts/ Zod schemas: bridge messages, save envelope (source of truth)
tests/e2e/          Playwright tests against the real web export
infrastructure/     Godot wrapper (test/export), static server for the export
docs/               Product, game design, architecture, ADRs, status
```

See [ADR-0008](docs/architecture/decisions/README.md) for why the game came first.

## Requirements

- **Godot 4.7.2-stable** with Web export templates. The version is pinned in `.godot-version`. Set `GODOT` to the binary, or place it in `.tools/godot/` (Windows console exe or macOS `Godot.app`).
- Node ^22.12 or ≥ 24 (`.nvmrc`; Prisma 7 needs it) and pnpm 9.
- PostgreSQL for the API: `pnpm db:up` starts one in Docker (`infrastructure/docker/compose.yml`), or use any Postgres 14+.

## Common tasks

```sh
pnpm install
pnpm game:test        # Godot headless test suite (unit + real-physics playthrough)
pnpm game:export      # Web export to apps/game/build/web + artifact checks
pnpm game:serve       # http://localhost:8060 — play the export in a browser
pnpm test             # contract tests
pnpm e2e              # Playwright: the game export, and the site launching it
pnpm web:dev          # http://localhost:3000 — the site (run game:serve too for /play)
pnpm web:lighthouse   # Lighthouse gate on a running site build (web:build && web:start)
pnpm api:test         # API integration tests (TEST_DATABASE_URL: a database it may wipe)
pnpm api:dev          # http://localhost:4000/v1 (DATABASE_URL; migrate and seed first)
```

API setup: copy the variables from `apps/api/.env.example` into your environment, then run `pnpm --filter @the-margin/api migrate:deploy` and `pnpm --filter @the-margin/api build && pnpm --filter @the-margin/api seed`.

The site loads the game from `NEXT_PUBLIC_GAME_BUILD_URL` (a folder holding a web export and its `build.json`). Locally it defaults to `/game`, which Next.js proxies to `pnpm game:serve`. See `apps/web/.env.example`.

To play in the editor, open `apps/game/project.godot` in Godot 4.7.2 and press F5. To open a mechanic sandbox page directly (it never touches the save), run `godot --path apps/game -- --page=sb_mechanics` (crates and panel words), `--page=sb_weight` (pressure plates), `--page=sb_platforms` (moving platforms), `--page=sb_eraser`, `--page=sb_ink`, or `--page=sb_music` (chapter music and ducking).

`pnpm e2e` runs Chromium and Firefox. On macOS, add WebKit with `E2E_WEBKIT=1 pnpm e2e`.

## Controls

A/D walk · Space hop · E take/place words · X erase · C trace in ink · drag lifted panels with the mouse (or Q for keyboard panel mode) · hold R to reset the page · Esc pause.

## Documentation

- [Product overview](docs/PRODUCT_OVERVIEW.md)
- [Game design](docs/game-design/GDD.md) · [state diagrams](docs/game-design/STATE_DIAGRAMS.md)
- [Technical design](docs/architecture/TDD.md) · [database](docs/architecture/DATABASE.md) · [save schema](docs/architecture/SAVE_SCHEMA.md) · [API contract](docs/api/API_CONTRACT.md)
- [Roadmap and backlog](docs/ROADMAP.md) · [risks](docs/RISKS.md) · [decisions](docs/architecture/decisions/README.md)
- [Project status](docs/PROJECT_STATUS.md) · [asset licences](docs/ASSETS.md)
