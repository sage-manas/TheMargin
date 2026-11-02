# THE MARGIN — Product Overview

**Tagline:** Escape the drawing.

## What it is

A single-player, browser-playable 2D puzzle-adventure. You play Nib, a tiny ink character who discovers their world is a comic book, and that the comic's rules can be edited:

- Panels are rooms. Rooms connect where their floors line up across the gutter, and the reader can slide panels around the page.
- Things obey what is written on them. Bold words in speech bubbles can be lifted out and stuck onto objects.
- Later chapters add erasing pencil lines, tracing sketches in ink, an unseen artist who corrects your edits, and finally the margins and gutters themselves.

## Who it's for

Players of thoughtful puzzle-adventures who enjoy "aha" moments and environmental storytelling, play on desktop browsers, and want short sessions (one page = one puzzle, 1–5 minutes).

## Product shape

| Layer | Tech | Role |
|---|---|---|
| Game | Godot 4.7 (GDScript), Web export, Compatibility renderer | All gameplay, local saves |
| Website | Next.js + TypeScript | Landing, launcher, accounts, chapters, settings |
| API | NestJS + TypeScript + Prisma | Auth, cloud saves, progression, achievements |
| Data | PostgreSQL | Accounts and compact, versioned save snapshots |
| Delivery | S3 + CDN | Game exports and assets |

## Release strategy

1. **Prototype:** browser-playable Chapter 1, pages 1–2. Proves the panel + word mechanics are fun.
2. **First public build:** complete Chapter 1 with the website, accounts and cloud saves.
3. **Chapters 2–7:** shipped incrementally on the same architecture.

## Success criteria for the first public build

- First-time players finish Chapter 1 without reading instructions. Target: ≥ 70 % completion in playtests.
- Median time to the first "aha" (first panel slide) is under 90 seconds.
- Stable 60 FPS on mid-range desktop hardware in Chrome, Firefox, Edge and Safari 17+.
- Initial download under 15 MB compressed. Time to interactive under 5 s on broadband.
- No lost progress across refreshes, offline play, or devices.
