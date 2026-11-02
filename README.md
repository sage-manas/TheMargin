# THE MARGIN

*Escape the drawing.*

A browser-playable 2D puzzle-adventure. You play a tiny ink character who discovers their world is a comic book, and that its rules are editable because it is a drawing. Panels connect where their floors line up, the reader's hand can slide panels around the page (even the one you're standing in), and things obey what is written on them.

## Repository

```text
apps/game/          Godot 4.7 project (GDScript). The game.
packages/contracts/ Zod schemas: bridge messages, save envelope (source of truth)
tests/e2e/          Playwright tests against the real web export
infrastructure/     Godot wrapper (test/export), static server for the export
docs/               Product, game design, architecture, ADRs, status
```

`apps/web` (Next.js) and `apps/api` (NestJS) arrive in Phases 5–6. See [ADR-0008](docs/architecture/decisions/README.md).

## Requirements

- **Godot 4.7.2-stable** with Web export templates. The version is pinned in `.godot-version`. Set `GODOT` to the binary, or place it in `.tools/godot/` on Windows.
- Node ≥ 22.6 and pnpm 9.

## Common tasks

```sh
pnpm install
pnpm game:test        # Godot headless test suite (unit + real-physics playthrough)
pnpm game:export      # Web export to apps/game/build/web + artifact checks
pnpm game:serve       # http://localhost:8060 — play the export in a browser
pnpm test             # contract tests
pnpm e2e              # Playwright: boot, full solution, reload persistence
```

To play in the editor, open `apps/game/project.godot` in Godot 4.7.2 and press F5.

## Controls

A/D walk · Space hop · E take/place words · drag lifted panels with the mouse (or Q for keyboard panel mode) · hold R to reset the page · Esc pause.

## Documentation

- [Product overview](docs/PRODUCT_OVERVIEW.md)
- [Game design](docs/game-design/GDD.md) · [state diagrams](docs/game-design/STATE_DIAGRAMS.md)
- [Technical design](docs/architecture/TDD.md) · [database](docs/architecture/DATABASE.md) · [save schema](docs/architecture/SAVE_SCHEMA.md) · [API contract](docs/api/API_CONTRACT.md)
- [Roadmap and backlog](docs/ROADMAP.md) · [risks](docs/RISKS.md) · [decisions](docs/architecture/decisions/README.md)
- [Project status](docs/PROJECT_STATUS.md) · [asset licences](docs/ASSETS.md)
