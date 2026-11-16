# Chapter 2 "The Border": testing walkthrough

How to play Chapter 2 start to finish, what you should see on each page, and what to try that should be refused. Use it to check a build before a playtest and as the answer key while watching players. The design is in [GDD §6b](../game-design/GDD.md); the automated playthrough is `apps/game/tests/test_chapter2.gd`.

## Setup

- **Full flow (with saves):** `pnpm game:export && pnpm game:serve`, open http://localhost:8060. Start a new game and play Chapter 1 through, or continue a save that is on page 1.8.
- **One page directly (no save):** `godot --path apps/game -- --page=ch02_p05` (any page id `ch02_p01`…`ch02_p08`).
- **Controls:** A/D or ←/→ move · W/Space/↑ hop · E take/place a word · drag panels, cards and borders with the mouse · Q panel mode (arrows swap or slide) · R hold to reset the page · Esc pause.

**Hand verbs new in this chapter**
- **Swap:** panels with a ⇄ badge on the top border. Drag one onto another of the same size and they trade places. Nib travels with their room.
- **Stretch:** a right border with a grip (three short lines) and a dashed reach. Drag it wider or narrower.

## 0. Chapter 1 → 2

Finish page 1.8.
- [ ] A card reads **END OF CHAPTER 1 · NEXT: CHAPTER 2: THE BORDER** with **TURN THE PAGE** and **BACK TO TITLE**.
- [ ] TURN THE PAGE turns to 2.1. The palette changes to newsprint grey and cyan, and the music changes to "Gutters".
- [ ] BACK TO TITLE, then Continue, resumes on 2.1. The title screen shows Chapter 2.

## 2.1 Reading Order (swap is introduced)

Three rooms in a row, from left: THEN, A DOOR / FIRST, A ROOM (Nib) / AND A HALL. A pencil note: PANELS ARE READ LEFT TO RIGHT.

**Solution:** drag the door room onto the hall. Walk right through the door.
- [ ] Before the swap, the door room isn't connected to anything.
- [ ] After the swap, Nib's room opens onto the door: THEN, AT LAST, A DOOR.
- **Also check:**
  - Any order with Nib's room directly before the door works.
  - Swapping the room Nib is in carries Nib along.
  - Dropping a panel on empty page sends it back.

## 2.2 Stretch (stretch is introduced)

THE ROOM WAS TOO SMALL. A dashed reach runs across a gap to THE WORLD WAS FURTHER AWAY.

**Solution:** drag the grip all the way right. Walk across.
- [ ] The floor follows the border as it moves.
- [ ] Fully stretched, the rooms link. Arriving turns the page (AND THEN, IT WASN'T.).
- **Also check:** you can't drag the border narrower than the things drawn in the room or Nib; it stops short.

## 2.3 Make Room

Nib's room fills the top row. A lifted exit room sits below.

**Solution:** drag the exit room up; it stops against Nib's room. Narrow Nib's room with its grip. Then drag the exit room all the way up, and walk out through its door.
- [ ] Before narrowing, the exit room only rises a little.
- [ ] After narrowing, it rises all the way and links.
- **Also check:** narrow too far, and the risen room blocks the border from widening past the right width.

## 2.4 Someone Outside

Three swappable rooms: Nib's room, a wall, the door. There is a desk panel for the artist.

**Wrong move:** swap the wall and the door.
- [ ] About two seconds later, the artist swaps them back. **LEAVE THEM WHERE I PUT THEM.**

**Solution:** swap Nib's own room with the wall, then walk right through the door.
- [ ] The artist leaves this one alone. **...NOT WHILE THEY'RE IN IT.**
- **Watch for:** do players think of moving the room they're standing in? (It's Chapter 1's answer coming back.)

## 2.5 Room for Later

A narrow seed room (48 wide) and a LATER. caption card.

**Wrong move:** drag LATER. onto the seed room.
- [ ] The card is refused and goes back, because there's no room for it beside the caption.

**Solution:** stretch the seed room all the way. Drop LATER. on it, which grows the vine. Climb the vine, then walk along the ledge to the door.
- [ ] Fully stretched, the room links to the room with the door.
- **Watch for:** do players understand why the card was refused?

## 2.6 Close Shave

A close-up's ring sits over an empty room. The lever is in the other swappable room: THE LEVER WAS IN THE WRONG ROOM. Below is a pit with a raised bridge.

**Solution:** swap the lever's room with the empty room. Click the lever in the close-up. Walk across the bridge.
- [ ] The close-up now shows the lever.
- [ ] Pulling it lowers the bridge: THE BRIDGE WAS ALWAYS UP. becomes UNTIL IT WASN'T.
- [ ] No stray chain line is drawn while the bridge is down.

## 2.7 Page Layout

THE LAST DOOR (labelled **SHUT**) comes before Nib's room. A lifted room far right holds IT WAS **OPEN** ALL ALONG.

**Solution:**
1. Slide the far room in next to Nib's room.
2. Walk over, take **OPEN** (E), and walk back into Nib's room.
3. Swap Nib's room with the door room so it comes before the door.
4. Walk to the door and swap SHUT for OPEN (E). Walk out.

- [ ] Nothing links at the start.
- [ ] After step 4 the door opens.

## 2.8 The Border

On arrival the artist draws a box round Nib and shakes it: **STAY IN YOUR BOX.**

**Solution:** stretch the box's border right until it links to THE STORY WENT ON. Walk out.
- [ ] Walking right before stretching gets Nib nowhere.
- [ ] After the stretch: **...FINE. GO ON, THEN.**
- [ ] Leaving shows **END OF CHAPTER 2** ("Chapter 3 is still being drawn").
- [ ] Signed in on the site, the profile shows the "Chapter 2 complete" achievement.

## Every page

- **Reset:** hold R. The page goes back to its start, including swaps, widths and cards.
- **Save:** quit to title, then Continue. Swaps, widths and cards are where you left them.
- **Keyboard:** Q selects a ⇄ panel, and an arrow key swaps it.

## What to note in playtests (same bar as Chapter 1)

For each player, note:
- Did they spot the ⇄ badge and the grip without help?
- How long were they stuck on each page?
- Did 2.4 and 2.5 click?

Any page that needs a hint from you is a design issue, not a player issue.
