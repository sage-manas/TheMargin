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

**Chapter 2:** swapping panel positions (§4.9) and stretching borders (§4.10). **Later:** borderless panels open to the gutter, gutters as walkable space (Chapter 7), tilted panels.

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

### 4.7 Scene captions (Chapter 1, from the rework)

Playtest feedback (2026-11-12): every Chapter 1 page was "slide a room, carry a word to a slot, reach a door". Scene captions give the reader's hand a second job that changes a whole room at once.

- A **scene card** is a loose narrator caption that names a time or scene: **LATER.** or **THAT NIGHT.** It sits in a panel's top-right corner, drawn as a caption box with a dog-ear (loose, can be picked up).
- The **reader's hand** carries a card to another panel's corner (mouse drag, or panel mode: Q selects it, arrow keys hop it to the next panel that way). Each panel holds at most one card. A panel with a card *is* that scene; a panel without one is now, by day.
- **What scenes do** is data: features, characters and props carry a condition (`when: "later"`, `"!night"`):
  - LATER: time has passed in that room. A sprout is a vine whose leaves are ledges; ice has melted into a puddle; a candle has burned down.
  - THAT NIGHT: the room is dark (a night wash over its paper; Nib, objects and lettering stay readable). Glow paint shows: writing (clues) and steps you can stand on. Characters go to bed.
- **Moving a card un-happens the scene where it was.** Taking LATER away from a room grows the ice back. Order matters, and that is the puzzle.
- **Refusals:** a card won't land if it would make something solid where Nib or a crate is (the hand buzzes and the panel shakes). A pencil sketch panel takes no card.
- Feedback: the card ticks into its corner; a growing vine and melting ice animate (cut under reduced motion); the panel's night wash fades in.
- Saves store which panel each card is on (`pages.<id>.scenes`); features follow from that.

### 4.8 Close-ups (Chapter 1, from the rework)

- A **close-up** is a round inset panel that magnifies one spot of the page, joined to it by two pencil lines (the zoom). Comics use them to show a detail too small to see; here the detail is something only the reader's hand can work.
- **Controls** are drawn small in a panel, too small for Nib: a **lever** (on or off) or a **combination dial** (one wheel per digit, on while it shows its code). Each control is a **switch**.
- In the close-up the control is drawn big. The reader clicks it: the lever flips; a wheel turns up (top half) or down (bottom half). Keyboard: panel mode selects the close-up, left and right pick a wheel, up and down turn it, E pulls a lever.
- **The close-up looks at the page, not at a thing.** It shows whatever control is under its focus ring. Slide a lifted panel and the close-up sees what is now under the ring, or nothing (it is hatched).
- **Switches drive the page:** features with `when: "<switch>"` (a gate lifts, a bridge appears), doors wired to a switch (`button: "<switch>"`, like a pressure plate), and story triggers (`switch_changed`).
- Saves store each control's position or digits (`pages.<id>.controls`).

### 4.9 Swapping panels (Chapter 2)

- Comics are read in order: what is in the next panel happens next. Some panels are **swappable**: a ⇄ badge sits on their top border. Panels in the same swap group are the same size.
- The reader's hand drags a swappable panel (it lifts and follows the hand) and drops it on another panel of its group: the two **trade places**. Dropped anywhere else, it goes back. Keyboard: Q selects it; an arrow key swaps it with the nearest panel of its group that way.
- Everything inside travels with its panel, Nib included, as when a panel slides. Links re-form at once: a swap can join a corridor to a door, or cut Nib off from one.
- **Refusals:** not while Nib is in a gutter; never with a pinned panel (HEAVY or STOP on its caption pins it, as in Chapter 1).
- Saves store panel positions as they do for sliding; a restored set must be a rearrangement of where the group's panels started.

### 4.10 Stretching borders (Chapter 2)

- Some panels have a **stretchable right border**, drawn with a grip (three short lines across it) and its range dashed on the page like a lane. The reader drags the border to make the room wider or narrower, a grid step at a time.
- What is in the room stays where it is drawn; the floor runs to the border wherever the border is. Openings in the right border move with it.
- Stretching is how a room reaches across a gap too wide for a link, or narrows to make room for a lifted panel to slide past.
- **Refusals:** a border never crosses anything in the room (Nib, a crate, a feature, a character): it stops short. It never comes closer than a gutter to another panel, and not while Nib is in a gutter.
- Saves store panel widths (`pages.<id>.sizes`).

## 5. Chapter structure (evaluated)

I checked the proposed structure against two failure modes: a first chapter with nothing to *do*, and a mid-game where each chapter feels like a separate game.

**Recommended change:** Chapter 1 should not be movement only. A movement-only chapter is a tutorial, and the creative safeguards rule out overusing tutorials. Chapter 1 instead introduces both hands at their lightest, one panel slide and one word, so the player leaves Chapter 1 having had the core realisation. Chapters 2 and 3 then go deep on each.

| # | Title | New rule | Combined with | Story beat |
|---|---|---|---|---|
| 01 | The Page | Panels connect where floors line up; bold words are loose; the reader moves scene captions and works close-ups (§4.7, §4.8) | (none) | The world is a comic. The narrator becomes uncertain. |
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

### Pages 1.3–1.8 (reworked 2026-11-12)

Page 1.2 turns to 1.3 with the story action `turn_page`. The end card follows 1.8.

**Why the rework.** Playtest feedback: the theme and concept land, but the first Chapter 1 had one loop on every page ("slide a room, carry HEAVY, OPEN or UP to a slot, walk through a door") and its pixel props were hard to read. The reworked middle pages each introduce or twist one verb and end in a different goal. Panels and words remain the base (1.1 teaches them; 1.7 brings them back with everything else), and two reader-hand mechanics join them: scene captions (§4.7) and close-ups (§4.8). Crates, plates and platforms stay in the toolbox (sandboxes) for later chapters.

| Page | New verb | Goal |
|---|---|---|
| 1.3 Later | Moving a scene card, in the right order | Climb out through a high door |
| 1.4 Close Up | Sliding a room under a close-up; working its lever | Free the neighbour (the page turns when Nib reaches them) |
| 1.5 That Night | Two cards across three rooms | Get past the neighbour, who sleeps only at night |
| 1.6 The Empty Room | Reading a glow note at night; dialling it in a close-up | Unlock the door the neighbour left |
| 1.7 The Long Night | Everything at once: a word, a slide, a close-up, a card | Reach the last door and give it the right word |
| 1.8 From the Top | (the artist acts) | Go on after the first room is erased |

- **1.3 "Later".** Two tall rooms. In the left one a vine has grown to a door on a high ledge, because the LATER. card sits in its corner. Nib starts in the right room, and between the two is a block of ice: it's still cold there. Moving LATER to Nib's room melts the ice, but the vine shrinks back to a seed. Once Nib is through, moving LATER back grows the vine again (and refreezes the ice behind). Nib climbs leaf to leaf and leaves by the door. *(Learn: a caption card changes a whole room; moving it un-happens it where it was; order matters.)* The narrator follows: IT WAS COLD THAT YEAR becomes AND THEN, IT WASN'T. A margin hint names the hand's new verb.
- **1.4 "Close Up".** The neighbour from 1.1 is locked in next door behind a gate: LET ME OUT! THE LEVER'S UP THERE. The lever is a tiny detail on the wall of a lifted room on the top row. A close-up hangs to the right, its ring over an empty stretch of page, so it shows nothing (hatched). Sliding the lever's room until the lever is under the ring brings the lever into the close-up, where the reader pulls it: the gate lifts, and when Nib reaches the neighbour (THANKS!) the page turns. *(Learn: close-ups magnify a spot of the page, not a thing; the reader works what is too small for Nib.)* The gate stands inside Nib's own room, so Nib is never left in a gutter (where panels refuse to move) while waiting at it.
- **1.5 "That Night".** Three rooms and two cards. Nib starts at the foot of a stairwell whose stairs are gone. THAT NIGHT. is with the neighbour, who sleeps at last; LATER. hangs in a room where the clock struck twelve. LATER in the first stairwell grows a vine up to a landing. THAT NIGHT in the second stairwell lights glow-paint steps up to the neighbour's room, but takes the night away from the neighbour, who wakes and stands guard in front of the door (I NEVER SLEEP. NOT BEFORE NIGHT.). Once Nib is up, THAT NIGHT goes back to the neighbour, who sleeps, and Nib slips past. *(Two cards, three places to be: the first planning puzzle.)* A fall from the steps lands Nib in the stairwell's bottom, which links back to the first, so nothing needs a reset while LATER still grows the vine.
- **1.6 "The Empty Room".** The neighbour's blue room again, on its track and set too high; lowered, it meets Nib's room. Nobody is in it. Their bubble, THIS DOOR WON'T **OPEN**. NOT ONCE. NOT EVER., lies on the floor as a solid thing, the step up to the ledge where the door is. The door has no word tag: it has a combination lock, which a close-up in the corner of the page sees once the room is lowered. THAT NIGHT. starts in Nib's room. Moved to the empty room, it shows what the neighbour left in glow paint: FOR NIB: 3 0 8. The narrator: THEY ALWAYS SAID THE SAME THING becomes BUT THEY LEFT A NOTE. Taking OPEN from the bubble still makes the old joke (NOW THEY SAID NOTHING AT ALL.), but no word opens this door. The pencil panel: the neighbour sketched and crossed out, TOO MANY CHARACTERS.
- **1.7 "The Long Night".** The set-piece. Nib takes **OPEN** from THE DOOR BEHIND WAS LEFT OPEN. The middle room has a pit, a drawbridge raised, and ice that is melted only while LATER. is there. The bridge's lever is in a lifted room below, and a close-up across the page looks at the spot that room must slide to. Lever pulled, bridge down, Nib crosses while it is LATER in the middle room, then moves LATER on to the last room, where a vine grows to the exit door's ledge (refreezing the ice behind). Up the vine, OPEN onto the door labelled **SHUT**. Moving LATER too soon freezes the ice in Nib's way: put it back. The pencil panel asks CUT THIS PAGE?
- **1.8 "From the Top".** The little room from page 1.1, the same layout and the same caption, but the rest of the page is already rubbed out. When Nib steps wholly into the next room, the artist's eraser rubs the little room out, row by row (story action `erase_panel`), and writes FROM THE TOP. The narrator's AND THAT WAS ALL THERE WAS. becomes AND THEN, THERE WASN'T. The erasure is also the way out. Lifted L, below, couldn't rise past the little room before. Now it can rise into the space it left (THERE WAS ROOM AFTER ALL.), meet the next room, and carry Nib down to the exit (AND SO THE STORY WENT ON.). The end card closes Chapter 1. This seeds Chapter 6: the artist's corrections are tools.

## 6b. Chapter 2: "The Border"

Chapter 2 takes the page layout itself apart. Chapter 1's tools stay (sliding, words, caption cards, close-ups) and two hand verbs join them: **swap** (§4.9) and **stretch** (§4.10). Story: someone outside is moving the panels; the artist starts to push back. Palette: newsprint grey with cyan (`news`, `news_cyan`); music: "Gutters" (D Dorian, 96 bpm). Page 1.8 turns to 2.1 through a chapter card (END OF CHAPTER 1, NEXT: CHAPTER 2: THE BORDER, TURN THE PAGE); the end card follows 2.8.

The same rule as Chapter 1's rework: every page has one main verb and one goal, and neighbouring pages never share both.

| Page | Main verb | Goal |
|---|---|---|
| 2.1 Reading Order | Swap (introduced) | Put the door after Nib's room, and walk through |
| 2.2 Stretch | Stretch (introduced) | Reach a room across a gap too wide to link (arriving turns the page) |
| 2.3 Make Room | Narrow one room so another can slide past | Bring the exit room up to Nib |
| 2.4 Someone Outside | Swap against the artist, who swaps back | Get next to the door in a way the artist can't undo |
| 2.5 Room for Later | Stretch a room wide enough to hold a caption card | Climb out |
| 2.6 Close Shave | Swap a close-up's subject under its ring | Lower the bridge |
| 2.7 Page Layout | Slide, a word and a swap together | Give the last door the right word |
| 2.8 The Border | Stretch the box the artist draws round Nib | Break out |

- **2.1 "Reading Order".** Three swappable rooms in a row: THEN, A DOOR. / FIRST, A ROOM. / AND A HALL. The door comes first, so it opens onto nothing. Swapping it to the end puts it right after Nib's room. The pencil panel: PANELS ARE READ LEFT TO RIGHT. Entering the door's room: THEN, AT LAST, A DOOR. (Swapping the hall instead carries Nib if they are in it; any order with Nib's room just before the door works.)
- **2.2 "Stretch".** THE ROOM WAS TOO SMALL. Its right border has a grip, and its reach is dashed across the gap to THE WORLD WAS FURTHER AWAY. Stretched all the way, its floor reaches the gutter and the rooms link. Arriving turns the page (AND THEN, IT WASN'T.).
- **2.3 "Make Room".** Nib's room takes the whole top row, so the lifted exit room below can only rise a little before it meets it. Narrowing the room clears the lane; the exit room rises, and its opening meets the narrowed border exactly a gutter away. (Narrowing further leaves a gap; the risen room then stops the border at the right width.)
- **2.4 "Someone Outside".** Nib's room, a wall, the door: all swappable. Swapping the wall and the door brings the door next to Nib, but the artist puts them back: LEAVE THEM WHERE I PUT THEM. Swapping Nib's own room past the wall works, because the artist won't move a room with Nib in it: ...NOT WHILE THEY'RE IN IT. (Story action `swap_back`; Chapter 1's "move the room you're in" returns as the answer.)
- **2.5 "Room for Later".** A seed room only 48 units wide: too narrow to hold LATER. (a card needs room beside the caption), and too narrow to reach the way out. Stretched to its widest it links to the room with the door and has room for the card; LATER grows the vine to the ledge that runs to the border.
- **2.6 "Close Shave".** The close-up's ring is over the wrong one of two swappable rooms; the lever is in the other (THE LEVER WAS IN THE WRONG ROOM.). Swapping them puts the lever in view; pulling it lowers the bridge across the pit in the room below (THE BRIDGE WAS ALWAYS UP. becomes UNTIL IT WASN'T.).
- **2.7 "Page Layout".** THE LAST DOOR, labelled **SHUT**, comes before Nib's room; a lifted room on the right holds IT WAS **OPEN** ALL ALONG. but sits too far away. Slide it in, take OPEN, come back, swap Nib's room before the door, and give the door OPEN.
- **2.8 "The Border".** The artist draws a box round Nib (STAY IN YOUR BOX., and the box shakes). The box's border stretches: wide enough, it links to THE STORY WENT ON. (...FINE. GO ON, THEN.) The end card: END OF CHAPTER 2.

## 7. Puzzle checklist (every page)

- **Objective:** the goal is visible from the start: an exit (door or linked opening) or a person to reach. Pages vary the goal and the main verb (§6); no two neighbouring pages share both.
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

- **Hand-inked, not pixel art (ADR-0013).** A page is 640×360 units drawn at full screen resolution with antialiased ink strokes, like a printed comic. One page fills one screen, and the camera never scrolls within a page.
- **Read the puzzle first.** Line weight says what matters:
  - *Heavy ink* (1.5–2 units, full colour) for everything Nib can use or that moves: Nib, crates, doors, plates, planks, panel borders, ground.
  - *Thin grey lines and muted colour* for scenery: furniture, windows, frames, plants. Scenery never looks usable.
  - *Red* means "the reader can act here": loose words, an empty word tag (red dashed outline), the panel or tag in reach.
- **Movable panels say so.** A lifted panel casts a shadow and carries chevrons on its edges pointing the way it slides (red under the hand). Its whole lane, everywhere it can go, is dashed faintly on the page. A pinned panel lies flat with no chevrons.
- **Every label is the same tag.** A paper tag with the word in bold, hung on the thing it labels. An empty tag shows a red dashed outline and a blank line: a word goes here.
- **Ink:** near-black blue `#1d1b26`. Borders are 2 units; loose (unlinked) openings are dashed. A linked opening becomes a short inked corridor across the gutter.
- **Paper:** warm cream with fibre noise. Panel interiors use Ben-Day halftone dots for shading.
- **Pencil:** graphite grey, thin. The artist's sketches and notes.
- **Lettering:** `ComicFont`, an original single-stroke hand-lettering font in capitals (comics are lettered in capitals). Bold = emphasis = loose. Key prompts show a keycap and the verb.
- **Characters:** Nib is a round white figure with a pen-nib cap, a face that looks where Nib is going, a red scarf that streams behind, and legs that stride. The neighbour wears a hat and a long blue coat.
- **Palettes:** Ch 1 warm cream with a red accent; Ch 2 newsprint and cyan (panel styles `news`, `news_cyan`); Ch 3 pulp yellow; Ch 4 graphite greys; Ch 5 ink blues; Ch 6 red-pencil corrections; Ch 7 near-white.

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
