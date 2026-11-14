# Asset Licence Ledger

Every font, image, sound and piece of music in the game must appear here with its origin and licence. Nothing ships without an entry (Risk R9).

| Asset | Location | Origin | Licence |
|---|---|---|---|
| Hand-lettering font (`ComicFont`, regular + bold) | `apps/game/scripts/art/comic_font.gd` | Original single-stroke glyphs, authored for THE MARGIN (ADR-0013) | Project-owned |
| Nib and the neighbour (`Figures`) | `apps/game/scripts/art/figures.gd` | Original vector drawings in code | Project-owned |
| Props, objects, panels, page, halftone, paper texture | `scripts/art/ink.gd`, `scripts/objects/*.gd`, `shaders/*.gdshader` | Original, procedural vector drawing | Project-owned |
| All sound effects and ambience | `apps/game/scripts/audio/sfx_synth.gd` | Synthesised at runtime from code | Project-owned |
| Chapter music ("Margins", Ch 1) | scores in `apps/game/data/music.json`, synthesised by `scripts/audio/music_synth.gd` | Original composition, synthesised at runtime | Project-owned |
| Godot Engine runtime (`index.wasm`, `index.js`) | export output | Godot Engine 4.7.2 | MIT. Credit required in the about/legal page |
