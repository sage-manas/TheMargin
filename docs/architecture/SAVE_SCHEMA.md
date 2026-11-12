# Save Data Schema

> Source of truth: `packages/contracts/src/save.ts` (Zod) for the web/API side, and `apps/game/autoload/save_manager.gd` for the game. A contract test checks that a save produced by the game validates against the Zod schema.

## 1. Principles

- **One save slot per player** (`main`) in the first release; the envelope supports more later.
- Store **decisions, not objects** (including where each scene card sits and how each close-up control is set; what they make appear is derived): panel positions, slot→word assignments and fired story triggers. Never node paths, velocities or animation state. The one exception is where a crate or platform stands: these move themselves after a word is placed, so their positions are the outcome of decisions. It is stored as integer pixels, never as a velocity.
- Every save is **versioned** (`version`) and **revisioned** (`revision`, monotonic per device lineage).
- The local save is authoritative for play; the cloud copy is a mirror.

## 2. Envelope (version 1)

```jsonc
{
  "schema": "the-margin.save",
  "version": 1,                 // schema version, bumped on breaking change
  "revision": 42,               // increments on every write
  "updatedAt": "2026-11-02T10:15:00Z",
  "playtimeSec": 512,
  "progress": {
    "chapter": "ch01",
    "page": "ch01_p01",         // page to resume on
    "completedPages": ["..."],
    "completedChapters": [],
    "abilities": [],            // tools Nib has found: "eraser", "ink"
    "flags": {}                 // global story flags
  },
  "player": {
    "position": [64, 140],      // page coordinates; null means use the page spawn
    "carrying": "OPEN"          // word id or null
  },
  "pages": {
    "ch01_p01": {
      "panels": { "p3": [424, 40] },             // only lifted panels that moved
      "slots":  { "neighbor_bubble:3": null,     // slot id -> word id or null
                  "door1:label": "OPEN" },
      "objects": { "crate1": [40, 112] },        // crate and platform positions, panel-local (optional)
      "sketches": { "wall": false, "f1": "inked" }, // pencil sketch id -> true | false (erased) | "inked" (optional)
      "collected": ["drop"],                     // ink pickups collected (optional); crumbs and ink are derived
      "scenes": { "later": "a" },                // scene card id -> panel holding it (optional, GDD §4.7)
      "controls": { "lever1": true, "safe": "417" }, // close-up controls: lever position or dial digits (optional, GDD §4.8)
      "fired":  ["caption_doubt"]                // once-triggers already fired
    }
  }
}
```

Constraints (enforced by both sides): serialised size ≤ 64 KB; word ids match `^[A-Z]{1,12}$`; page ids match `^ch\d\d_p\d\d$`; positions are integers inside the 640×360 page.

## 3. Settings (separate file, separate API resource)

```json
{ "version": 1, "masterVolume": 0.8, "sfxVolume": 1.0, "musicVolume": 0.6, "reducedMotion": false }
```

Settings live apart from progress because they change independently and should never cause a progress conflict.

## 4. Migrations

- `SaveManager.MIGRATIONS` is an ordered list of functions `vN -> vN+1`. Loading applies them in order until `CURRENT_VERSION`.
- A save with `version > CURRENT_VERSION` (written by a newer build) is **never** overwritten. The game plays in memory and shows "This save was made by a newer version". The API rejects saves above its supported version with `422`.
- Every migration has a fixture test: `tests/fixtures/save_vN.json` → expected vN+1.
- On the web, every save is also mirrored synchronously to `localStorage` (`the-margin.save_main`), because `user://` reaches IndexedDB asynchronously. Loading picks the valid copy with the higher `revision`.
- If a file is corrupt, it is moved to `user://save_main.corrupt-<ts>.json` and a backup (`save_main.bak.json`, rotated on each write) is tried before starting fresh.

## 5. Cloud conflict resolution (deterministic)

When `PUT /v1/saves/main` returns `409` (the server revision ≠ client `baseRevision`):

1. Compute a **progress score** for each candidate: `completedChapters × 1000 + completedPages × 10 + (fired story triggers)`.
2. The higher score wins.
3. On a tie, the later `updatedAt` wins.
4. On a further tie, the higher `revision` wins.
5. **The loser is never discarded**: it is uploaded to `PUT /v1/saves/backup-<timestamp>` (the server keeps the last 5) and kept locally as `save_main.conflict.json`.

The winner is written with `revision = max(local, server) + 1`.
