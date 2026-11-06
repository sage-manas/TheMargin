# THE MARGIN — Game Design Document

> Living document. Owner: Game Director. Last major revision: Phase 0.

## 1. The one-sentence game

A tiny ink character discovers that the rules of their world are editable **because the world is an illustration**, and edits their way out of it.

## 2. Design pillars → concrete rules

Every mechanic must be explainable as a *rule of comics*, not a rule of physics. When a player asks "why did that work?", the answer is always "because that's how comics work".

| Pillar | Rule the player learns | System |
|---|---|---|
| The world is a drawing | Panel borders are ink lines. Ink lines are solid. | Panel system |
| Comic-book physics | Two panels connect where their floors line up across the gutter. | Panel link solver |
| Comic-book physics | **Things obey what is written on them.** | Word system |
| Experimentation | Bold words are loose. Loose words can be lifted, carried and put somewhere else. | Word slots |
| Narrative through mechanics | Captions are the narrator. When you break the rules, the narrator notices. | Story triggers |
| Progressive mastery | Each chapter adds one rule, then combines it with the previous ones. | Chapter plan |

### The two hands

There are two ways of touching the world. The split between them is the narrative spine of the game.

- **The character (keyboard)** lives *inside* the drawing. They walk, hop, and handle things that exist in the drawing: words and objects.
- **The reader (mouse, or keyboard panel mode)** lives *outside* the drawing. The reader's hand can slide panels around the page, which nobody inside the comic can do.

The character slowly realises someone outside is helping. The artist slowly realises someone is interfering with their composition. The game ends with the character reaching the reader's side of the page.

## 3. Player character

- **Working name:** Nib. A small ink figure in a pen-nib hat with a red scarf. Red is the only saturated colour on Nib, which gives a strong silhouette on paper.
- **Size:** 10×14 px on a 640×360 page. Nib is deliberately tiny: the page is their whole universe, and the player must be able to read the entire composition at once.
- **Movement model:** side-view walking plus a short hop (about 1.5 tiles). There is **no precision platforming and no death**. Gravity exists because panels are side-view drawings, and because words like UP and DOWN need something to act against. It is not there to test reflexes.
  - Coyote time (0.1 s) and jump buffering (0.12 s), so the hop never feels unfair.
  - A fall of any height is safe. Falling into a sealed pit is recoverable: hop out, or reset the page with R.

## 4. Core mechanics (full game)

### 4.1 Panels (Chapters 1–2, the foundation)

1. A panel is a self-contained space bounded by an ink border. Borders are solid.
2. Borders can have **loose segments**, drawn as a dashed ink line. A loose segment is a *potential* passage.
3. When two panels sit exactly one gutter apart, and their loose segments face each other **with matching floor lines** (side by side) or **overlapping openings** (stacked), the border opens and a strip of paper bridges the gutter. This is a **link**.
4. Some panels are **lifted**: they have a drop shadow and float slightly. The reader can slide a lifted panel along its track. Fixed panels lie flat on the page.
5. A panel's contents move with it, including the character if they are inside.
6. A panel cannot move while the character is standing in a gutter. You can't pull the floor out from under someone mid-step; the panel shakes and refuses.

**Why this isn't a gimmick:** the level geometry *is* the panel layout. The puzzle is the composition of the page.

**Later (Ch 2):** resizing panels (squash a room until its ceiling meets a ledge), swapping panel positions, borderless panels that are open to the gutter, gutters as walkable space, tilted panels.

### 4.2 Words (Chapters 1 and 3)

1. Comic lettering marks emphasis in **bold**. Bold words in the world are **loose**.
2. The character can carry one loose word at a time. A carried word floats above their head.
3. Words go into **slots**: a gap in a speech bubble, or the label on an object.
4. **Things obey what is written on them.** An object's label decides its behaviour. Remove the label and the object goes back to how it was drawn.
5. Taking a word out of a sentence leaves a gap, and gaps accept any word. The player can always put a word back, so mistake recovery is part of the rules rather than a menu option.

**Data-driven behaviour.** Words are never special-cased. Each word belongs to a *category* with parameters, and each object declares which categories it responds to.

| Category | Example words | Parameter | Responds |
|---|---|---|---|
| `state` | OPEN, SHUT | `open: bool` | doors, hatches, gates, chests |
| `motion` | UP, DOWN, LEFT, RIGHT | `dir: Vector2` | crates, platforms, panels (Ch 3) |
| `halt` | STOP | none | anything moving |
| `mass` | HEAVY, LIGHT | `mass` | crates, buttons, panels |
| `scale` | BIG, SMALL | `scale` | props, the character (late Ch 3) |

Adding a word means adding a data row. Adding a category means writing one handler for each object type that accepts it.

**Implemented responses (Phase 3).**

- **Crates** accept `motion`, `halt` and `mass`. UP, DOWN, LEFT and RIGHT move a crate that way until something stops it. STOP holds it where it is, even in mid air. With no label a crate is as drawn: it falls. A `mass` word leaves it falling but changes its weight: as drawn it weighs 1, HEAVY 2, LIGHT 0.5. A LIGHT crate drifts down at half speed. A crate never leaves its panel and never moves into Nib. Nib can ride a crate: a rising crate stops when Nib's head meets the ceiling.
- **Panels** obey words written in their captions ("THIS ROOM IS **HEAVY**."). HEAVY (`mass` > 1) or STOP pins a lifted panel: it lies flat, loses its track arrows and refuses to slide. LIGHT does nothing yet. Taking the word out frees the panel, which is the page 1.4 beat.
- **Pressure plates** (buttons) sit in the floor and are pressed while the weight resting on them reaches what they need (`needs`, default 1). Nib weighs 1; a crate weighs what its label says; Nib standing on a crate adds to it. A plate's own label accepts `mass` and scales what it needs: a LIGHT plate needs half, a HEAVY plate double. A door wired to a plate stands open while the plate is held, unless the door's own label says otherwise (the label always wins).
- **Platforms** are planks on a drawn rail (a dotted pencil guide with a stop at each end) and accept `motion` and `halt`. As drawn, a platform shuttles from one end of its rail to the other and rests a second at each end. A `motion` word along the rail sends it to that end and holds it there; STOP holds it where it is. A platform only takes words it can obey, so a lift refuses LEFT and RIGHT. It carries Nib and any crate resting on it, never moves into Nib, and a shuttling platform that meets Nib turns back. No timing is ever required: a word always parks a platform for good.
- Platform puzzle uses (R7 needs ≥ 3; all three are built in sandbox `sb_platforms`): (1) a drawn lift shuttles up to a ledge too high to hop, so Nib rides it; (2) a ferry labelled STOP waits across a pit, and taking STOP lets it carry Nib over (and gives Nib the word); (3) a crate rides a lift: LEFT on the crate holds it against the shaft wall until UP on the lift brings it level with a ledge, where it slides off onto a plate that opens the door.
- Proposed plate puzzle uses (R7 needs ≥ 3; (1) and (2) are built in sandbox `sb_weight`): (1) a plate needing 2 under a plain crate, solved by putting HEAVY on the crate *or* by standing on the crate; (2) a LIGHT crate that is too light for a plain plate, solved by taking LIGHT off it *or* writing LIGHT on the plate; (3) a stiff HEAVY plate that only a HEAVY crate with Nib on top can press, where the only HEAVY in reach first has to be taken off a panel caption, which frees that panel (page 1.4 combined with weight).

**Later (Ch 3):** putting words into NPC dialogue changes what the NPC does ("YOU MAY NOT PASS" becomes "YOU MAY ___ PASS"). Words stuck on panels (UP makes a panel rise). Sentences as switches. Lettered sound effects as physical events: a "CRASH" placed on a wall breaks it.

### 4.3 Eraser and restoration (Chapter 4)

- The eraser is found, not given: an artist's eraser left on the page.
- **Rule:** you can only erase *pencil* (thin grey lines), never ink. Ink is permanent. That gives an instantly readable language for what can be erased.
- Every erasure leaves **eraser crumbs**, and crumbs are the restoration resource: brushing them back over an erased spot restores it. Erasing is *borrowing*, not destroying; you can't erase more than you can put back.
- Erasing a pencil platform removes its collision. Erasing a pencil wall opens a path. Erasing a sketched ceiling reveals the artist's underdrawing.
- *Implemented (Phase 3 sandbox `sb_eraser`):* "can't erase more than you can put back" is a capacity. The eraser holds a page-set number of crumbs (`eraser_holds`), and a full eraser refuses to erase until crumbs are spent on a smudge. Nib carries crumbs as pips above the head. Erasing is never blocked; drawing back over Nib or a crate is.

### 4.4 Ink (Chapter 5)

- Ink is collected as **drops** from leaking inkwells and spilled pens, and carried in Nib's hat. (Nib *is* a pen nib; Chapter 1 foreshadows this.)
- **Rule:** ink can only *trace existing pencil sketches*. Nib can't draw freehand. Tracing a sketched bridge makes it real; tracing a sketched character wakes them. Drawing stays expressive but bounded, and every level remains fully authorable.
- Each sketch has a fixed ink cost, shown as dots on the sketch, so resource puzzles are readable.
- *Implemented (Phase 3 sandbox `sb_ink`):* §4.3 makes pencil solid while §4.4 says tracing a sketched bridge "makes it real". Both hold because there are two kinds of pencil: ordinary pencil (solid, erasable) and **faint** layout pencil (drawn but not solid). Ink makes either solid and permanent, so the eraser can't touch it. Nib's hat holds a page-set number of drops (`ink_holds`); a drop or inkwell that won't fit stays where it is and says HAT FULL. Ink pips sit above the crumb pips over Nib's head.

### 4.5 The artist (Chapter 6, seeded from Chapter 1)

- Never shown. The artist is present through captions that rewrite themselves, pencil notes in the margins ("LATER.", "FIX THIS"), panels redrawn between visits, an eraser sweeping across a panel, and the shadow of a giant hand.
- In Chapter 6 the artist reacts: re-inking borders you opened, sliding panels back. Puzzles become *negotiations*, where the artist's predictable corrections are tools.

### 4.6 The blank page (Chapter 7)

- Margins, gutters and the page edge become places. Gutters are corridors. The margin is a wide white void where only words and ink exist. The page edge is a cliff above the reader's desk.
- Final act: Nib leaves the page and reaches the reader.

## 5. Chapter structure (evaluated)

I checked the proposed structure against two failure modes: a first chapter with nothing to *do*, and a mid-game where each chapter feels like a separate game.

**Recommended change:** Chapter 1 should not be movement only. A movement-only chapter is a tutorial, and the creative safeguards rule out overusing tutorials. Chapter 1 instead introduces both hands at their lightest, one panel slide and one word, so the player leaves Chapter 1 having had the core realisation. Chapters 2 and 3 then go deep on each.

| # | Title | New rule | Combined with | Story beat |
|---|---|---|---|---|
| 01 | The Page | Panels connect where floors line up; bold words are loose | (none) | The world is a comic. The narrator becomes uncertain. |
| 02 | The Border | Resizing and swapping panels; gutters as space | Words on panels | Someone outside is moving the panels. |
| 03 | The Words | Words change NPC dialogue and object behaviour | Words reshape panels; sentences as logic | Characters are trapped by their lines. |
| 04 | The Eraser | Erase pencil, restore with crumbs | Erasing borders; erasing words | There's an older drawing underneath. |
| 05 | The Ink | Trace pencil sketches with ink | Inking new panels and words | Nib was drawn to be a pen. |
| 06 | The Artist | The artist corrects you | Every mechanic against a rule-following opponent | The artist is tired and erasing the story. |
| 07 | Beyond the Margin | Margins, gutters and the page edge are places | Everything | Escape the drawing. |

**Difficulty curve:** each chapter has 1 teaching page (one rule, no distractions), 2–3 practice pages (the rule plus one twist), 1–2 combination pages, and a set-piece. Target 20–35 minutes per chapter.

## 6. Chapter 1: "The Page" (initial release scope)

Chapter 1 is the release target for the first public build. The **prototype** (Phase 2) is its first two pages.

### Page 1.1: "The Little Room" (prototype)

Layout: a 640×360 page with 16 px margins and 8 px gutters.

```
+--------------------------------------------------------------------+
| [P1 fixed]          [P2 fixed]          [P3 LIFTED, slides up/down]|
|  ONCE, THERE WAS     AND THAT WAS        neighbour + bubble:       |
|  A LITTLE ROOM.      ALL THERE WAS.      THIS DOOR WON'T *OPEN*.   |
|  Nib  ---linked--->  floor - - -         floor (too high)  [pit]   |
|                                                                    |
| [P4 pencil sketch, never inked: "LATER."]  [P5 fixed, lower]       |
|                                             door labelled *SHUT*   |
+--------------------------------------------------------------------+
```

Beat sheet:

1. **Wake.** Nib stands in P1 under the caption ONCE, THERE WAS A LITTLE ROOM. P1's right border has a loose segment that is already linked to P2, so the player crosses a gutter on the first try without knowing it was special. *(Learn: panels are rooms, and borders can open.)*
2. **The misaligned floor.** P2's right border has a loose segment. Across the gutter, P3's loose segment hangs higher, so the floors don't line up. P3 is visibly lifted (shadow) and gently bobs, and the cursor turns into a hand over it. *(Observe.)*
3. **First slide.** The reader drags P3 down; it clicks along an 8 px track. When the floors line up, the border splits open with an ink "thwip". *(Aha 1: the page can be rearranged.)* The narrator notices: P2's caption strikes itself out and is rewritten as AND THAT WAS ALL THERE WAS... WASN'T IT?
4. **The neighbour.** P3 holds a neighbour who says THIS DOOR WON'T **OPEN**. NOT ONCE. NOT EVER. There is no door in P3. The bold word bobs, and standing next to the neighbour shows the interact prompt.
5. **Take the word.** Nib lifts OPEN out of the sentence. The bubble now reads THIS DOOR WON'T ____. and the neighbour gains a confused "...?" *(Aha 2: words are things.)*
6. **The pit.** P3's floor has a pit whose bottom border is loose. Far down the page, below P3, is P5. With Nib still inside P3, the reader slides P3 all the way down until the pit lines up with an opening in P5's top border. *(Aha 3: you can move the room you are standing in.)* Nib drops through the gutter into P5.
7. **The door.** P5 has a door labelled **SHUT**. Nib swaps OPEN onto the door and is now carrying SHUT. The door opens. *(Things obey what is written on them.)* Optional joke: put SHUT into the neighbour's bubble to get THIS DOOR WON'T SHUT.
8. **Turn the page.** Walking through the open door turns the page.

P4 is a pencil sketch that is never inked and can never be entered: a staircase climbing UP out of the panel, a ghostly sketch of Nib, and a pencil note reading LATER. It foreshadows the UP word, pencil (the eraser chapter), and the artist.

Recovery: every state is reversible without a reset. Words can always go back, panels can always slide back, and pits can always be hopped out of. R resets the page anyway.

### Page 1.2: "Someone" (prototype ending)

A single large panel on an otherwise blank page. Nib lands, and a caption writes itself in a different, scratchier hand: WHO MOVED MY PANELS? A beat later the panel border trembles. End card: CHAPTER 1 CONTINUES.

### Pages 1.3–1.8 (Phase 4, completing the chapter)

- 1.3 Two lifted panels, one on a horizontal track and one vertical, must be arranged in sequence.
- 1.4 A panel can only be lowered after a word is removed from it (HEAVY on the panel's caption). The first light combination of words and panels.
- 1.5 A three-panel staircase: floor alignments form a path upward, using UP on a crate.
- 1.6 A narrative page: the neighbour's panel is empty, and their bubble lies on the floor.
- 1.7 Combination set-piece: carry a word through three rearranged panels.
- 1.8 Chapter finale: the artist erases P1, the little room where Nib woke up, while Nib watches from the next panel.

## 7. Puzzle checklist (every page)

- **Objective:** an exit (door, page corner, or linked opening) is visible from the start.
- **Starting state:** fully visible; the whole page fits on one screen.
- **Clues:** loose (dashed) border segments, lifted panels (shadow), bold words, labels on objects.
- **Consistent solution:** only the published rules are needed.
- **Feedback:** every action has a sound and a visual (snap tick, link thwip, word peel, stamp, door creak, deny buzz with shake).
- **Completion:** page turn.
- **Recovery:** reversible actions plus page reset.

## 8. Narrative design

- **Told through** captions (the narrator), speech bubbles (characters), pencil notes (the artist) and changes to the page itself. No walls of cutscene dialogue. No exposition about "the artist" before Chapter 6.
- **Mystery ladder:** (1) The world is a comic. (2) Someone outside can move it. (3) Characters are trapped by their lines. (4) There's an older drawing underneath. (5) Nib was drawn to be a pen: a tool, not a character. (6) The artist is erasing the story because they've given up on it. (7) The reader can keep it alive.
- **Emotional core:** an unfinished story asking to be finished, with the reader as its last friend.

## 9. Visual direction (summary; technical rules are in the TDD)

- **Base resolution 640×360**, integer-scaled. One page fills one screen, and the camera never scrolls within a page.
- **Ink:** near-black blue `#1d1b26`. Borders are 2 px; loose segments are 4 px on, 3 px off.
- **Paper:** warm cream with fibre noise. Panel interiors use Ben-Day halftone dots for shading.
- **Pencil:** graphite grey, 1 px.
- **Lettering:** an original 5×7 uppercase pixel font (comics are lettered in capitals). Bold = emphasis = loose.
- **Palettes:** Ch 1 warm cream with a red accent; Ch 2 newsprint and cyan; Ch 3 pulp yellow; Ch 4 graphite greys; Ch 5 ink blues; Ch 6 red-pencil corrections; Ch 7 near-white.

## 10. Audio direction (summary)

- All audio is original. Phase 2 sound effects are synthesised in-engine: license-clean and a tiny download. Later phases replace them with recorded stationery foley (paper, pencil, nib scratches) and composed music.
- The sound palette is stationery: paper slides and taps for panels, peels for words, rubber stamps for placing words, nib scratches for captions, page turns for transitions.
- Music: a soft, hand-made-feeling loop per chapter, which ducks when the artist intervenes (while the artist letters a caption or shakes a panel). Chapter 1's loop, "Margins", is in A minor and ends each pass on E major, a question that never quite resolves, like the narrator's "WASN'T IT?". Sandbox pages are quiet unless they name a track.

## 11. Controls (desktop)

| Action | Keys |
|---|---|
| Move | A/D or ←/→ |
| Hop | W, Space or ↑ |
| Interact (take, place or swap a word) | E |
| Erase pencil / draw it back with crumbs (once the eraser is found) | X |
| Trace pencil in ink (once Nib has collected ink) | C |
| Move a panel | Drag a lifted panel with the mouse |
| Panel mode (keyboard alternative) | Q selects the next lifted panel; arrows/WASD slide it; Q or Esc exits |
| Reset page | R |
| Pause | Esc or P |

## 12. Accessibility

- Bold words also bob and get an outline when in reach; colour is never the only cue.
- Reduced motion turns off bobbing and panel float, and replaces the page-turn curl with a fade.
- Fully playable by keyboard (panel mode); the mouse is never required.
- No timing challenges, and nothing can kill you.
