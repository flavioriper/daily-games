# Light Up, flat: the seventh screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#lightup`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `...-codebreak-`, `...-balance-`,
`...-shikaku-`, `...-untangle-` and `...-tents-flat-design.md`.

Akari: set lanterns in a walled court so every floor stone is lit, no lantern
lights another, and each numbered block touches exactly its number of
lanterns.

## 1. What flat buys here, honestly

**The floor, and the beam.** Light Up has no marker for its main condition: a
stone no lamp reaches is a cold grey, a lit one is warm, and that is the whole
of "every stone must be lit". So the thing the player reads is a *field of
flat tints* — up to 35 of them on a hard court.

- **The floor is the display, and the floor is what a tilted camera ruins.** On
  the island that field is seen at seven degrees, where the far rows are a few
  pixels tall, foreshortened, and half in the shade of the blocks standing in
  front of them: precisely the information you look at most, rendered worst.
  Square-on, every stone is the same size and the same tint wherever it sits.
- **The island already had to fight for it once.** `core/palette.gd` records
  the first pass: unlit stone at `b4ab97`, one and a half stops off lamplight,
  and the toon ramp ate the whole difference under the island sun. The fix was
  to push the pair nearly three stops apart and cool the dark end. That margin
  was bought to survive a lit 3D ramp; flat, the same two colours are simply
  the two colours.
- **And it buys the beam.** Flat can draw the shaft of light itself down the
  row and the column, cell by cell as it travels, which is the rule made into a
  picture: you see exactly how far a lamp reaches and exactly what stopped it.
  The island casts light onto the floor stones and no further, because a
  visible beam at seven degrees is a smear across the court.
- **What it costs is the court.** The island's version is a real place with
  rough stone standing in it and lamplight pooling on flagstones, and that is
  more atmospheric than tinted tiles on parchment. This screen trades a lit
  room for a legible diagram. Whether that is the right trade for a puzzle
  whose difficulty is entirely in the reading is section 9's first question.

## 2. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/lightup_state.gd` | new | The rules, scene-free: the grid, what is on each stone, how far each lamp reaches, and every gesture that changes it. |
| `puzzles/lightup2d.gd` | new | The flat board: the court, the beams, the blocks, the chips, the gesture and the sprout's lines. |
| `ui/faces/court_lantern.gd` | new | The lamp: Untangle's paper lantern with the cord and tassel off it and an iron foot under it. |
| `core/palette.gd` | edit | The four bottom edges the flat court needs, and its own lit stone (section 3). |
| `ui/registry.gd` | edit | `lightup` goes flat; `lightup_island` keeps the island board, seeded from the same day. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/lightup_gen.gd` — the greedy placement,
the uniqueness search and the clue stripper — is the island's, and both boards
run the same ladder (5×5 at 24% blocks, 6×6 at 22%, 7×7 at 20%), so a day
lights the same court on each.

## 3. The state is the one truth, with two deliberate differences

`lightup_state.gd` is `lightup3d.gd`'s logic ported, except that:

- **A gesture is a move, not a tap.** The flat board sweeps a run of chips in
  one drag, so the history records a *list* of stones rather than a single one.
  Measured: a six-stone sweep is `moves=1`, `history=1`, and one undo clears
  all six. This is Tents' answer carried across unchanged; two of the seven
  screens now rule cells out by the handful, with the same finger movement.
- **A tap is one state, not a cycle.** Whatever is on the stone comes off, and
  a bare stone gets a lamp. The island cycles blank → lamp → chip → blank,
  which costs two taps for every chip.

The win test is the generator's own three conditions rather than a comparison
with the stored answer — clues exact, no two lamps in sight of each other,
every stone lit — exactly as the island tests it. `lit` (how many cells of
beam the nearest lamp is away) lives in the state rather than the board,
because the travelling wave staggers on it and the blocks' counts read from
it: it is a fact about the puzzle, not about the drawing.

**Two colours had to change, and the palette says why.** The flat court cannot
use the island's `LAMPLIGHT` for a lit stone: the beam is drawn *over* the
stone in the lantern's own `LANTERN_LIT`, and the two are within nine values of
each other, so the shaft vanished into the floor — measured on a rendered
frame, the band came out 4/10/22 per channel over the stone it crossed, about
3% in luminance. `LAMPLIT_FLOOR` (`f6d488`, the mock's own) is a shade more
saturated, and the beam went white at 0.45 rather than `LANTERN_LIT` at 0.34;
the band now measures 4/19/51. Those two numbers are the only place this board
does not take the mock's paint literally, and they were changed because
otherwise section 1's third bullet is a claim the screen does not keep.

## 4. The cast is one character

The lamp is `ui/faces/court_lantern.gd`, a subclass of Untangle's
`lantern_face.gd`: same seat, same halo, same mesh cache, with the cord and
tassel removed and an iron cap and foot added. The seventh flat screen adds no
new species.

What changes is what `lit` means. On Untangle the light was the reward at the
very end; here it is the state — a lamp you set down is burning — so a court
lamp is drawn lit from the moment it lands. Two more states ride on the
drawing: `bad` (a lamp that can see another) blushes and strains, and it is
*both* lamps, because neither is more wrong than the other; `pinned` (a lamp a
hint lit) wears green iron and a green arc at its foot, the language every
board uses for a given. Both are in the cache key, so ten lamps still share
one mesh per state.

The blocks are not characters. They are drawn into the court's mesh, plain, and
they carry no face — half of a generated court's stone says nothing at all (the
stripper removes every clue it can while the answer stays unique), and a blank
block is information too: it stops the light.

## 5. What the board says, and what it will not

Two of the three rules are shown where they break. A lamp that can see another
blushes rose and strains. A numbered block goes green the moment it touches
exactly its number and rose the moment it touches too many. The third rule —
every stone lit — needs no marker: the cold stones are the ones still to do,
and their count is the sprout's line.

**Nothing draws which lamp lit which stone.** The beam shows reach, not
ownership, and a stone lit twice looks exactly like a stone lit once. That
matters because the deduction in Light Up is about *which* lamp has to be the
one.

A block with no number never goes green — not while playing and not on the
win. It has nothing to be satisfied about.

## 6. The gesture

- **Tap** sets a lamp down, takes one up, or clears a chip.
- **Drag** sweeps chips. The direction is read off the stone the drag started
  on: begin on a chip and the sweep clears, begin anywhere else and it lays.
  The board also fills in the stones *between* drag events, which the mock does
  not: holes in a swept run would be a phone-only defect.
- **A sweep never disturbs a lamp, a block, or a lamp a hint pinned.** Measured:
  sweeping the length of a lamp's own row leaves the lamp standing and lays
  chips around it.
- A tap on a block or on a pinned lamp is refused with a dip and a line from
  the sprout rather than a move.

## 7. The screen

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `LIGHT UP` with the leaf, `LET THERE BE LIGHT`, then Undo, Hint and Settings. |
| Day card | 120 | The day and its name. |
| Board card | cut to the court | The court on parchment, centred in what is left. |
| Actions | 130 | Reset and Check. |
| Tip card | 140 | The sprout and one line. |

The bottom slot is 290: the tip card, the actions row and the gap between them.
There is no clue band to spend width on — every number is carved into a block
standing *inside* the grid — so the cell is the roomiest of the seven flat
boards. Measured at 1080 design width: **186.4 on easy, 155.3 on medium, 133.1
on hard**, capped by the width every time, which is 48 CSS pixels under a thumb
on hard against the 38 Tents had to settle for.

Because the cell is width-capped at every step, the court is square and the
space is tall, the card is cut to the court and **centred** (`card_centred()`,
which Tents added for the same shape). Measured in a 9:16 window: a 1000-tall
card in a 1190 slot, 95 above and 95 below; a taller phone gives it more.

## 8. Motion

| Moment | What happens |
|---|---|
| Entrance | The flagstones fade in on a diagonal from 0.12 s, then the blocks drop onto the court from 0.2 s. |
| Setting a lamp | The lamp pops in from six tenths, and the light **travels**: each stone waits 0.035 s per cell of beam from the lamp, capped at 0.25 s, then warms over 0.22 s. Taking one up cools over 0.3 s. The island's own `LIGHT_STEP`, `LIGHT_CAP`, `LIGHT_IN` and `LIGHT_OUT`. |
| Breaking a rule | The lamp blushes and strains, and a number turns green or rose, on the frame the count changes. Nothing waits for Check. |
| Check | Every lamp the answer does not put there shakes; the sprout counts them. |
| Solved | The lamps hop in reading order a tenth of a second apart, each grinning and throwing sparks as it lands, and the chips clear away, so the last picture is the lit court rather than the working-out. |

Measured 0.09 s after a lamp lands: its own stone at 0.75 warmth, a stone two
cells out at 0.27, the far end of the beam still at 0. Six tenths of a second
later every stone on the beam is at 1.00 and the board reports itself idle.

Two implementation notes worth keeping:

- **The warmth painted so far is what a retarget starts from.** Ask for a lamp
  and take it away again inside the fade, and a single target would carry the
  stone all the way to lamplight and leave it there — a lit floor with nothing
  lighting it. The board keeps `{from, to, at, dur}` per stone and reads the
  current value before changing the target, which is the island's fix.
- **A canvas command holds a mesh by RID, not by reference.** Rebuilding the
  court every frame and dropping the previous mesh leaves the renderer drawing
  a freed RID ("Parameter mesh is null", and an empty card) on any frame
  rendered without a queued redraw being flushed first — which is what
  `RenderingServer.force_draw()` in a harness does. `lightup2d.gd` keeps the
  mesh the last `_draw` handed over in `_shown` until the next one replaces it.
  `tents2d.gd` and `untangle2d.gd` rebuild meshes the same way and do not hold
  that reference; it has never been seen in the game, where every frame flushes
  its redraws first, but it is the same shape of bug.

## 9. Measured

- Suite `passed=2086 failed=0`; win harness `winnable=20/20`, both `lightup`
  and `lightup_island` through real touch events, board fit and HUD checks
  included.
- Draw calls against the 855 budget: **62** on a fresh court, 65 mid-travel, 69
  working, **83** on a working hard court (7 lamps, 6 chips, beams crossing),
  92 at the busiest frame of the win, 66 on the win screen.
- The ladder, sampled: easy 5×5 with 6–7 blocks, 3–5 numbered, 6–8 lamps over
  18–19 stones; medium 6×6 with 9–10 blocks, 5–7 numbered, 7–9 lamps over 26–27
  stones; hard 7×7 with 14–17 blocks, 5–7 numbered, 10–13 lamps over 32–35
  stones.
- By hand: the sweep both ways, one undo taking back a whole run, a sweep
  refusing to disturb a lamp, a tap refused by a block and by a pinned lamp,
  the hint pinning for good, Check shaking the wrong lamps, the chips clearing
  on the win, the board idling the moment its entrance ends, and reduce motion
  putting the whole court up lit with no wave.

## 10. Calls this screen is still for

- **Is a diagram worth a room?** The sharpest version of the flat question yet:
  the island's court is atmospheric and the rule is legible here. Nobody should
  read seven screens as seven wins.
- **Is the beam right now that it can be seen?** It had to be brightened to
  exist at all (section 3). The tinted floor already answers "is this stone
  lit", so the shaft may be the rule made visible or a second voice saying the
  same thing louder. It is the one thing the island cannot do at all, which is
  exactly why it wants challenging rather than assuming.
- **An untouched court is the screen's dullest picture**, and worse than the
  mock predicted: a hard board sampled here opened with three of its seven
  numbers being `0`, so three blocks sit green and settled before the player
  has done anything. That is honest — a zero is satisfied by an empty court, and
  it teaches what green means for free — but the first frame is cold grey stone,
  dark blocks and three green ones.
- **Does the travelling wave slow the board down?** A quarter of a second of
  stagger per move is honest and teaches the rule, but Light Up is a board you
  tap a great deal. Halving `LIGHT_CAP` is the gentle lever; snapping the light
  on is the blunt one.
- **Ten lamps with faces, all lit, all glowing.** Ten halos on a 7×7 court is a
  lot of warm light in one card, and the faces sit on the brightest things on
  the screen. The blocks stayed plain partly for this reason; the lamps may
  still need their glow pulled down.
- **Should a hint pin a lantern for good?** It is the island's behaviour and the
  answer is unique, so it commits the player to nothing false — but it removes
  a stone from the puzzle permanently.
- **Should the court be centred?** The family's rule everywhere else is to pin
  the board under the day card. This is the second board of the seven to break
  it, and the only one where the air is the same above and below at every
  difficulty.
