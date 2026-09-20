# Quilt, flat: the rack goes inside the card

A polyomino exact-cover board, themed as a blanket being sewn: a shaped
backing of pale cloth, and a rack of coloured patches that have to be fitted
onto it with not a gap and not an overlap.

**It is called Quilt and nothing else**, in code, in a comment or on screen.
The reference the design came from ships it as "Blocos", and the genre
travels as "Block Fit"; neither belongs in this repo. This is the fifth time
the repo has renamed a game it did not invent — Code Break, Hidden Word,
Word Trail, Bridges — and the rule those four set holds here: the original
name is recorded once, in this paragraph, in order to forbid it. (Uwe
Rosenberg's *Patchwork* is the quilt-themed polyomino board game; it is a
different game and its name is not used either. The pieces here are
**patches** in prose and `patch` in code, and Mushroom Patch keeps the word
*Patch* as a title.)

The playable mock is `docs/brainstorm/concepts.html#quilt`, built before this
spec as the house order requires. **Every measurement below is ported from
that mock**; where a figure came from the mock's JavaScript rather than from
Godot, this document says so, because a JS timing is not a GDScript timing.

## 1. What is built

A **backing** — a connected, hole-free region of cells on the board card —
and a **rack** of five to eight patches under it, inside the same card. A
patch is a polyomino of four to six cells, drawn as one silhouette of
coloured cloth.

The rules, and there are only three:

- A patch must lie **wholly on the backing**. No corner may hang off.
- A patch may **not overlap** a patch already sewn on.
- **Patches never turn.** Each is placed in the orientation it is drawn in,
  on the rack and on the quilt alike.

And one consequence, which is the whole design:

- The patches' cells sum to **exactly** the backing's cells. So when the last
  patch goes on, the quilt is exactly covered and the board is solved. **A
  wrong answer cannot be sitting on this board**, only an unfinished one.

### What that consequence buys, and what it costs

It buys the screen's shape. There is nothing to check, so there is **no
Check**, so there is no actions row: `capabilities()` is `["undo", "hint"]`,
the registry says `"actions": false`, Reset rides up into the top bar as a
fifth button, and the bottom slot is the tip card alone at 140. That is Word
Trail's shape exactly (spec `2026-09-20-word-trail-flat-design.md`), for the
same reason stated differently: there, only a right word locks; here, only a
legal placement is taken.

It costs the player a dead end. Five patches can be sewn on legally and the
sixth fit nowhere, and the board will not say so — that *is* the puzzle, and
saying so would be solving it. The board says how many patches are left and
nothing more. **A dead end is undone, never lost**: there is no cost to
lifting a patch, no move limit and no timer on the screen.

## 2. Where it stands on the first screen

The sixteenth registry entry and the **fourth card on page two**, behind
Mushroom Patch, Sudoku and Bridges. Nothing on page one moves, so the first
screen's 335 draw calls are untouched by this board existing; page two grows
by one card. The pager that makes page two possible landed on 2026-09-20 with
Mushroom Patch (`ui/menu.gd`, `PER_PAGE` twelve) — see that spec's section 2
and the note in `ui/registry.gd`. This board inherits it and argues nothing
about it.

Registry line, in full, because three of its fields are unusual together:

```gdscript
{
    "id": "quilt",
    "title": "Quilt",
    "short": "Fit every patch.\nLeave no gap.",
    "motto": "Make the blanket whole",
    "footer": "Fit · Sew · Finish",
    "script": "res://puzzles/quilt2d.gd",
    "shell": "flat",
    "tray": "none",
    "actions": false,
    "difficulties": [0, 1, 2],
}
```

`"tray": "none"` is the unusual one and deserves its own paragraph.

### Why the rack is not a tray

Every other board that hands the player pieces puts them in a **tray row**
under the board card: Binairo's brush chips, Code Break's friends, Nonogram's
two tiles, Sudoku's digit pad, Hidden Word's keyboard. A tray is a row of
`Button`s that *arms* something; the board then acts when a cell is tapped.

That does not work here, for two reasons, and both were decided before a line
was written:

1. **A patch is dragged, not armed.** The gesture is one continuous motion
   from the rack to the cell, and the patch has to be drawn following the
   finger the whole way, at the quilt's own cell size by the time it lands.
   A tray row is a sibling Control of the board: a drag that crosses between
   them crosses a node boundary, and the thing being dragged has to be
   re-parented or drawn twice.
2. **Where a patch sits on the rack is information.** A rack is not a palette
   of modes; it is the set of pieces still to place, and it shrinks as the
   board fills. The empty bay left behind is worth seeing.

So the rack lives **inside the board card**, drawn in the same
`ArrayMesh` pass and the same coordinate space as the quilt, and the card
takes the whole 1340 the chrome leaves it. This is the first board to put its
pieces inside the card, and it is the reason `card_height()` hands every
pixel back (section 6).

## 3. The state is the one truth

`puzzles/quilt_state.gd`, scene-free, `RefCounted`. The board draws it and
nothing else.

| Field | What it is |
|---|---|
| `cols`, `rows` | the backing's bounding box |
| `region` | `PackedByteArray`, `cols*rows`, 1 where the backing is |
| `shapes` | per patch, its cells normalised so the bounding box starts at (0, 0) |
| `answer` | per patch, the origin cell the generator placed it at |
| `at` | per patch, where it is now: −1 on the rack, else an origin cell |
| `locked` | per patch, 1 if a hint sewed it |
| `ok` | the generator proved the tiling the only one |
| `history` | one entry a gesture, newest last |

**One gesture is one undo.** A patch picked up off the quilt and put down
again is a single entry, which is why the state has `take()` (lift with no
history) and `drop(p, origin, from)` (put down, and push exactly one entry
saying where it came from and where it went). `place()` and `lift()` are the
thin wrappers over those two, so the history invariant lives in one place.
Two cases push nothing at all: rack to rack, and a patch put back exactly
where it was lifted from. Neither is an event and neither costs a move.

`is_solved()` is the rule and never the stored answer: **every cell of the
region covered**. On this board that is equivalent to "every patch placed",
because the cells sum, and the state says so in a comment rather than relying
on the reader to notice.

## 4. Generation: grow the answer, then prove it unique

The house pattern, third outing (Mushroom Patch carves backwards, Bridges
grows and proves; this grows and proves).

1. **Grow.** Seed a random cell in the band's box and grow a polyomino of a
   drawn size from it by random accretion. Then repeatedly pick a random
   empty cell orthogonally adjacent to what has been grown and grow the next
   patch from there. The backing is therefore **connected by construction**,
   and so is the order the patches were cut in.
2. **Reject a shape** whose bounding box is wider or taller than four cells:
   the rack's bays have to hold every patch at a legible size, and one long
   patch would shrink all of them (section 6).
3. **Reject a backing** that encloses a hole, and one whose bounding box does
   not fill the band's box in at least one dimension, so a 7×7 board never
   comes back 4×4. Re-normalise to the bounding box.
4. **Prove it unique.** Exact cover: take the first uncovered cell in scan
   order and try every translation of every *distinct remaining shape* that
   covers it. **Identical shapes are interchangeable** — the multiset is
   grouped by shape, or two copies of the same tetromino swapping places
   would count as a second answer when it is plainly the same quilt. Count to
   a cap of two and stop.
5. **Reject** a board with a second answer and grow the next, up to 200
   attempts.
6. **Grade on search nodes.** The count-to-two search reports how many nodes
   it explored, which is a cheap proxy for how much casting about a person
   has to do. Band 0 rejects a board above an easy threshold; band 2 rejects
   one below a hard threshold. Both thresholds are calibrated from a measured
   sweep and recorded in `quilt_gen.gd`, not guessed.
7. **Never block the board opening.** If the budget runs out, the best board
   grown is handed back with `unique: false` — Sudoku's `graded: false`
   bargain. It is playable; it is not a puzzle.

### The bands

| Band | Box | Patches | Patch sizes | Backing cells |
|---|---|---|---|---|
| Easy | 5 × 5 | 5 | 4–5 | ~22 |
| Medium | 6 × 6 | 6 | 4–6 | ~30 |
| Hard | 7 × 7 | 8 | 4–6 | ~40 |

### Measured, 500 seeds a band

GDScript, through `generate()`, on this Mac, 2026-09-20. Two full readings:
the counts are identical (the generator is deterministic in its `rng`), the
milliseconds are the pair.

| Band | Built | Not unique | Attempts mean / p90 / **worst** | Nodes mean / p90 / worst | Cells mean / worst | ms mean / **worst** |
|---|---|---|---|---|---|---|
| Easy 5×5 | 500/500 | 0 | 5.4 / 12 / **32** | 13.3 / 18 / 20 | 22.2 / 25 | 0.83, 0.77 / **3.93, 3.49** |
| Medium 6×6 | 500/500 | 0 | 5.7 / 12 / **33** | 23.1 / 39 / 109 | 29.3 / 35 | 1.28, 1.20 / **4.95, 4.89** |
| Hard 7×7 | 500/500 | 0 | 25.9 / 61 / **179** | 114.2 / 191 / 608 | 39.2 / 47 | 8.07, 7.36 / **51.8, 51.5** |

Worst case **51.8 ms** against the repo's 194 ms gate, which is comfortable
even at the two-to-three times a phone is commonly slower. All 1,500 seeds
came back unique and inside their band's node window, so none of the three
fallbacks was walked.

### Three things the sweep proved wrong, and they are worth knowing

**1. Uniqueness is not the binding constraint**, and step 5 above reads as
though it is. Over 3,000 raw grows a band, only **2.5% / 4.1% / 4.7%** of
*grown* boards carry a second tiling. Because patches never rotate, a grown
region is almost always rigid. What the attempts are actually spent on is
**grows that wedge** — 77% / 81% / 92% of them run out of room before all
the patches are grown — and, on the hard band, on the node grading. Nobody
should read the attempt counts as "the proof rejected them"; the proof still
has to run, and it is what makes `unique` honest, but it is not the cost.

**2. The node thresholds are an order of magnitude below the first guess.**
`EASY_NODES` 20 and `HARD_NODES` 60, read off the measured distribution of
uniquely-tileable grown boards (3,000 grows a band): band 0 sits at mean
15.9, p75 19; band 1 at mean 23.9; band 2 at mean 80.3, p50 58. 20 is band
0's own p75 and 60 is band 2's own p50. **Band 1 is ungraded on purpose** —
its whole distribution already sits between the two. What the grading buys,
measured through `generate` itself: band 0 hands out 13.3 nodes mean against
the 15.9 it grows, band 2 hands out 114.2 against 80.3.

**3. The hard band's attempt budget is genuinely tight, and it is left
tight.** The worst of 500 seeds spent **179 of the 200** attempts.
Per-attempt success on band 2 is about 4% (8.5% grow × 95% unique × ~50%
node window), so 200 attempts miss roughly **one day in 3,800**. A miss is
not a failure: it falls back to a unique board the node window would have
refused — a real puzzle graded a little soft, the Sudoku `graded: false`
bargain. Two levers would close it (`ATTEMPTS` 300, which takes the worst
case to about 85 ms, or `HARD_NODES` 45, which costs nothing but weakens the
grading) and **neither was pulled**: doubling the worst-case generation time,
or softening the hard band outright, is a poor trade for a cosmetic event
once per ten years of dailies. It is written down here so the next person
does not rediscover it as a bug.

## 5. Colour: the one proposal that lost on a rendered frame

This board was designed to add **nothing** to `core/palette.gd` — a patch
would be `Pal.REGION[i]`, Queens' nine court pastels, and the backing
`Pal.SURFACE_HI`. **Both were wrong, and the first rendered frame said so.**
The section is written the way it went rather than the way it was planned,
because the reason is reusable.

- `REGION` is a **ground**, not a surface. Its nine are pale by design —
  they are what a bee stands *on* — and two of them, the tan `#cfc3ac` and
  the silver `#dcdcdf`, sit within a few points of `PARCHMENT` and
  `SURFACE_HI`. A patch in either read as a hole in the card. Cloth is the
  thing the player picks up and moves; it has to be the **strongest surface
  on the screen**, not the palest.
- `SURFACE_HI` `#f1e6d2` against the card's `PARCHMENT` `#f3e9d2` is **four
  points of value**. The backing simply was not there — the quilt's whole
  shape, which is the puzzle, showed only as a faint lip. This is the
  Bridges lesson repeated in the other direction (a `STONE` beach at 237
  against a 230 sea stopped being an islet), and it cost one frame to find
  both times.

| Thing | Colour | Note |
|---|---|---|
| A patch | `Pal.CLOTH[i]` | **New**: eight cloths, taken by patch index. Mid-light and warm-leaning, pitched between `REGION`'s pastels and `PEGS`' full colours, and spread round the wheel *by index* — butter, sky, coral, sage, lilac, apricot, teal, rose — so two patches with consecutive indices never land beside each other in the same family. Eight is the most any band asks for, so a colour never repeats on one board. |
| Its bottom edge | `CLOTH[i]` 22% toward `Pal.TEXT` | The lip every piece on these screens wears: a fill over a slightly deeper copy of itself. |
| Its stitch | `CLOTH[i]` 35% toward `Pal.TEXT` | Dark enough to read on its own cloth, light enough not to be ink. |
| The backing | `Pal.QUILT_BACK` over `Pal.LINE` | **Reused, not invented**: `QUILT_BACK` is Shikaku's `BED_GROUND` `#e6d8b8`, the one colour in the palette already chosen to read as bare ground *on parchment*, which is exactly this problem. Drawn as **one more patch of cloth** — same silhouette, same corner, same lip — so the quilt reads as the pale piece underneath rather than as a hole in the card. |
| Its cell rules | `Pal.QUILT_RULE` (Shikaku's `BED_LINE`) at 0.55 | A hint of the grid a patch snaps to, and nothing more. |
| A patch that has gone | its own cloth at 0.16, in its empty bay | Section 6. |
| A refused patch | toward `Pal.BAD` on `flash_level` | The family's rose, on the patch itself: a patch *is* its own shape, so it has something to blush (`flat-motion.md`'s rule 9 does not bite here). |
| A patch held where it will not go | toward `Pal.BAD` at 0.30, while it is held | Section 6. |
| A hint's patch | `Pal.SUN` at 0.32, round its silhouette | The given's language every board speaks. |
| The ghost under the finger | the patch's own cloth at 0.30 | Where a legal drop would land. |
| The solve | the stitch warmed toward `Pal.SUN_RAY` | Section 9. |

The patch, its lip, its stitch and those two mixes live in
`ui/faces/patch_cloth.gd`, not in the board: the menu card draws the same
patch (section 11), and neither should own the other's drawing. That is
`ui/faces/mosaic_tile.gd`'s bargain and it is taken here for the same reason.

## 6. The screen, measured

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `QUILT` in ink with the leaf sprouting from it and `MAKE THE BLANKET WHOLE` under, then Undo, Reset, Hint with its count and Settings. **Five buttons**, the wide case, because there is no actions row for Reset to live in. |
| Day card | 120 | A tree, "Day N", the day's name. |
| Board card | 1340 | The quilt and the rack. Below. |
| Tip card | 140 | The sprout and its line, and the door to the rules sheet. |

40 of margin, three 20 gaps and the four rows are 1920 exactly, which is
where the card's 1340 comes from — the tallest board card in the game, 150
more than Bridges' 1190, because this one carries its own rack.

`Quilt` is five letters and measures well inside the five-button block of
370, so `_fit_title` (`ui/flat/flat_top_bar.gd`) leaves it at 84. The motto
`MAKE THE BLANKET WHOLE` is the one to watch: Balance's and Untangle's mottos
are lettered down from 24 to 21 and 22 against that same 370 block. Whatever
this one measures, the bar handles it; it is recorded in the amendments
rather than asserted here.

### Inside the board card

Inset 28 all round, so the content is **944 × 1284**, split:

| Part | Height | |
|---|---|---|
| Field | 800 | the backing, centred both ways in its box |
| Air | 28 | |
| Rack | 456 | two rows of bays |

The split is held as a **share** (`FIELD_SHARE`, 800/1284) rather than as
three constants, so a card of another height splits in the same proportion
instead of spending every extra pixel on the rack.

**The height binds at every band**, which is the opposite of most boards
here: the backing's box is square-ish and its slot is wider than it is tall.
`cell = min(944 / cols, 800 / rows)`, capped at **150** — without the cap a
five-patch board on a 5-row box comes out at 160 a cell and reads as a toy.

| Band | Box | Cell |
|---|---|---|
| Easy | 5 × 5 | 150 (capped from 160) |
| Medium | 6 × 6 | 133 |
| Hard | 7 × 7 | 114 |

Against Sudoku's 100 and Queens' and Nonogram's 103, this is the roomiest
grid on the shelf, and it should be: a patch is dragged onto it, not tapped.

### The rack: two shelves, packed to the cloth

**A grid of equal bays was the proposal and it lost to a measurement.** Two
rows of three or four bays, each sized for the tallest patch on the board,
gave a rack cell of **46.7 on all three bands** — because a bay is
228 tall and any single four-cell-tall patch forces `0.82 × 228 / 4`, which
then shrinks all eight. Against a field cell of 114 to 150, the rack read as
a row of crumbs. And a four-tall patch is common: over 60 seeds a band,
**25, 39 and 54 boards out of 60** carry one.

So the rack is two **shelves** and a shelf takes only the height its own
patches need. The patches are sorted tallest first and cut in half, which
puts the tall ones together on one shelf instead of one on each; each shelf
gets the share of the rack its own height asks for; and one cell serves
every patch, because a rack of two sizes reads as two kinds of thing:

```
rack_cell = min( over shelves: 0.86 · rack_w / shelf_width_cells,
                 0.86 · rack_h / (shelf_heights summed),
                 0.62 · cell )
```

with 0.6 of a cell of air between two patches on a shelf.

Measured over 60 seeds a band:

| Band | Field cell | Rack cell mean / **worst** / best | Ratio mean / worst |
|---|---|---|---|
| Easy | 150 | 71.2 / **56.0** / 78.4 | 0.47 / 0.37 |
| Medium | 133 | 62.8 / **49.0** / 78.4 | 0.47 / 0.37 |
| Hard | 114 | 57.0 / **48.3** / 65.4 | 0.50 / 0.42 |

**The 0.62 cap never binds** — the shelves' own geometry is always the
tighter of the three — so it is a guard and not a design number, and nobody
should read 0.62 as the ratio the screen shows. The ratio the screen
actually shows is about **half**, and half is enough: a waiting patch is
visibly smaller than a sewn one, which is what says it is not on yet.

### The empty bays

**A patch that has gone leaves its shape behind**, in its own cloth at 0.16
with no lip. Without it the rack empties as the quilt fills and the bottom
four hundred pixels of the card go blank — measured on a rendered frame of a
nearly finished board, where the last patch is dragged across a void. The
cut shape keeps the rack's composition, says which patch came from where,
and is honest about the one thing the player can still do with it: drag it
back. No lip, because a lip is what says a thing is sitting on top of
something.

### The finger

- **Press** finds what is under it: a patch sewn on the quilt first, then one
  waiting on the rack. It is taken hold of **by the cell it was pressed on**,
  so a patch dragged by its corner stays held by that corner.
- A patch lifted off the quilt comes off immediately — `take()`, no history.
  The quilt under it is bare while it is in the hand, and the ghost shows
  where it would go back.
- **While held, the patch is drawn at the quilt's cell**, grown from the
  rack's, at `LIFT_SCALE` 1.1, and **held 1.2 cells above the finger** so the
  thumb never covers the shape being placed. That offset is the one number on
  this screen that exists purely because a phone has a thumb on it.
- The **ghost** is the cells a release would take, washed in the patch's own
  cloth at 0.30 — **only when it fits**. A rose ghost for a refusal was the
  proposal and it is pointless: the held patch is drawn at 1.1 of the same
  cell over the same place and covers it almost exactly. What the ghost is
  actually for is the **snap** — it sits on whole cells while the patch
  above it follows the finger, so its edges peek out and show where the
  release will put things.
- **The cloth in the hand says no.** The board reads three states, not two:
  `CLEAR` when no cell of the held patch is over the quilt at all, `FITS`,
  and `SNAG` — over the quilt, and it will not go. On `SNAG` the held cloth
  washes 0.30 toward `Pal.BAD` for as long as it is held there. The three
  states matter: a patch on its way up from the rack spends most of the
  journey not fitting anywhere, and blushing the whole way would be a board
  shouting at a player who has not done anything yet. A drag is a question,
  and this is the only moment the board can answer it before the answer
  costs anything.
- **Release** sews it on if it fits. Otherwise it flies home to its bay over
  `FLY_TIME` 0.26 with the back ease, shivering and blushing, and the sprout
  names the rule it broke. A patch dropped back exactly where it came from
  simply goes back: no move, no line, no history.

## 7. The cast: nobody new

`ui/faces/` gains no character. This is the fourth board to seat none at all
— Nonogram decided it, Hidden Word confirmed it, Sudoku and Bridges repeated
it — and for this one the reason is plainest: the pieces *are* the drawing.
A face on a patch would be a face on a rectangle of cloth.

What it does add to `ui/faces/` is `patch_cloth.gd`, which is **builder
shapes and not a Control**, exactly as `mosaic_tile.gd` is: the board batches
up to nine silhouettes into one mesh and the menu card draws five more into
another, and a Control per patch would be a node per piece of a thing with no
face on it. The only face on the screen is the shared sprout on the tip card.

## 8. How it is drawn

Three meshes and no Controls:

| Mesh | What is in it |
|---|---|
| `_quilt` | the backing and its rules, the ghost, every patch sewn on, a hint's glow, and the seams over the lot |
| `_rack` | every patch still waiting, and any flying home |
| `_hand` | the one patch being dragged, alone, so it draws over everything |

**A patch is one polygon and not a row of squares.** Its cells' boundary is
traced into a loop, the straight runs are collapsed, the corners are rounded
(concave ones round inward, which is what makes a notch read as folded
cloth), and the shape is filled over a copy of itself `EDGE` lower. Tiling a
patch out of rounded squares would draw the seams the game has not sewn yet,
which is precisely the information the player is looking for.

The loop walk handles a **pinch** — two cells of one shape meeting at a
corner only — by taking the sharpest right turn on offer, so the two lobes
stay one loop. No patch of six cells can pinch (it takes eight), and the
generator throws away a backing with a hole in it, so the case is defensive;
it is in there because the walk is shared with the menu card, where the
shapes are hand-written.

The order is the only one that works: backing, ghost, patches, seams. A seam
drawn under a patch is a seam nobody sees.

## 9. Motion, and the stitch

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`), drawn off the curve readers the way Light Up's
and Nonogram's drawn pieces are (rule 8). **It adds nothing to
`core/motion.gd`** and keeps **two** constants of its own, both of them for
the signature: `STITCH_STEP` 0.05 s per cell of distance and `STITCH_TIME`
0.22 s for one seam's dashes to run. Nothing else in the game sews.

| Moment | What happens |
|---|---|
| Entrance | The backing pops in wide about its centre (`wide_pop_scale` from `ENTER_WIDE_FROM` 0.86) while it fades, after `ENTER_DELAY`; the rack's patches pop in with the squash on the family's stagger behind it. |
| Pick up | The patch grows to `LIFT_SCALE` 1.1 at the quilt's cell and rises to the hold above the thumb. The bay it left stays empty. |
| Drop, taken | It pops in with the squash (`pop_in_scale`) where it landed, and **the seam wave runs** — below. |
| Drop, refused | It flies home over `FLY_TIME` with the back ease, shivering (`shiver_offset`) and flashing toward `Pal.BAD` (`flash_level`), and the sprout says which rule. |
| Take off | The patch comes off under the finger; the seams it held go with it, because they were never stored. |
| Hint | A ring in `Pal.LEAF` pulses out of the patch's middle with a sparkle, anything in its way flies home first, and the patch keeps its sun glow from then on. |
| Undo | The reverse: whatever changed pops in or pops out, read off the same two clocks. |
| Reset | Every patch the player laid comes home in a wave from the far corner. A hint's patches stay. |
| **Solved** | **The hem.** Every patch hops along the diagonal at `SOLVE_STAGGER` after `SOLVE_DELAY`, with a gold sparkle on each, and the stitch round the quilt's outer edge warms to `Pal.SUN_RAY` in the same wave — the one moment the quilt is spoken of as a whole thing rather than as pieces. The win follows `WIN_WAIT` 1.6 s later. |

### The signature: the seam stitches

When a patch lands, a running stitch sews itself along **every seam it now
shares** — with each neighbouring patch already on, and with the quilt's hem
where it reaches the edge — dash by dash, in a wave outward from the patch
that landed: a seam's dashes start `distance × STITCH_STEP` after the landing
and take `STITCH_TIME` to cross their own edge.

**The seams are derived and never stored.** They are recomputed from the
placement every frame, and each one's moment is the *later* of its two
patches' landings, so the wave runs out of the patch that was just sewn on
and not out of its neighbour. Lifting a patch takes its seams with it and
undo keeps no book for them. That is Queens' `_settle` and Sudoku's in a
third shape, and the useful difference is that a seam belongs to a *pair* of
pieces rather than to one: the "later of the two" rule is what a pair costs.

It also does real work for the player. A stitched edge is contact, and
contact is what the puzzle is made of: the stitch is feedback derived from
information the player already holds (where they put the patches), never from
the answer — the Mushroom Patch rule, and the Code Break rule under it.

### Reduce motion

The backing and the rack are up at once; a patch appears where it is dropped
rather than popping; a refusal is a colour and a line with no shiver; rings
and sparkles are off (`ui/fx2d.gd` already draws neither); the seam wave's
step is zero and its dashes land in `Motion.REDUCED_TIME`, so a seam is
simply there the moment its two patches are; the solve lights the hem in one
frame and the win follows immediately (`win_delay()` returns
`Motion.REDUCED_TIME`).

## 10. The hint

**Three**, as every flat board gives. A hint sews one patch of the answer
where the board has not got it, **taking up everything in its way first** —
Queens' precedent, where a wrong queen in the hint's cell pops out before the
right one drops in. It prefers the patch with the fewest legal placements
left, so the hint is the most useful one on the board rather than the first
in the list.

The patch it sews is a **given** from then on: it keeps the sun glow and it
will not be dragged off. Pressing it is refused with a line, not a silence.
A hint is an ordinary move — Undo takes it back, along with everything it
displaced, and does not give the hint back.

A hint can finish the quilt, so `hint()` calls `check_solved()`: a board that
ends on a hint still ends.

## 11. The menu card

A backing part covered, five patches sewn onto it with the stitch showing
along every seam between two of them, and one patch still waiting beside it
at the rack's smaller cell — the whole game in one picture. One mesh, one
draw call, no cast, no `_build` branch.

It is **the board's own drawing and not a second one**: `patch_cloth.gd`
traces the silhouette, rounds it and lays the lip under it on the card
exactly as it does on the board, so a card and its board cannot drift apart.
The hem is left unsewn on the card — at 320 × 118 every edge dashed is a
hatch, and the seams *between* patches are the ones that say what the game
is.

## 12. What the board says

The sprout's own line, not Binairo's cycle of broken rules. Idle it cycles
four tips; after a move it is a count ("3 patches left"); after a refusal it
is the rule that was broken, in one sentence. **A refusal is never a
silence**, and it goes to the tip card rather than to a toast, because this
board carries a card whose whole job is one line (Sudoku's precedent).

`flat_win()` returns no cast and the subtitle "Not a gap left."
`share_glyphs()` is the finished quilt as an emoji mosaic: one line per row,
a coloured square per patch and `⬛` for a cell off the quilt — the shape of
the day, which gives nothing away, because the shape is what everyone got.

## 13. Analytics

Nothing new. `puzzle_start`, `puzzle_complete` (always `solved: true` — this
board cannot end unsolved), `puzzle_abandon`, `hint_used`, `undo_used`,
`board_reset`, `rules_opened`, `new_puzzle`. No `check_used`, because there
is no Check.

## 14. Calls this screen is for

All through `tests/_shot_anim.gd -- quilt` at `--resolution 810x1440`, which
is the true 1080 × 1920 of design space on this Mac (CLAUDE.md, "What the
harnesses actually measure" — and `--resolution` has to sit **before**
`--script` or the flag is silently dropped). The harness learned three
things for this board: a `_drag_quilt` that takes the answer's first patch
off the rack through the board's own input path, a later idle window because
the seam wave runs on past the drop, and a **`full` mode** that sews every
patch but the last and drags that one, so the fullest board is reached by
playing rather than by writing to the board's arrays.

### Draw calls

| State | Draw calls |
|---|---|
| Bare | **58** (three readings, all 58) |
| One patch dragged on, seams sewn | **59** (three readings) |
| **Fullest board**, every patch on and the solve wave running | **80** (three readings) |
| Reduce motion | **58** |

Against the **855** budget, so this is one of the cheapest screens in the
game. **The controls reproduce exactly**, which is what makes the numbers
worth quoting: Queens came back **71** twice and Word Trail **65** in the
same session, both exactly their recorded figures.

One `full` run returned `max_draw_calls=0` over a short 285-frame window.
That is **discarded, not averaged**: zero draw calls for a whole window
means the window never rendered (another window over it), not a board that
drew nothing. It is recorded here rather than dropped silently, because the
next person to see a 0 should know it has happened before and what it was.

### Idle

Bare **2.54, 3.36, 3.90 ms**; played **2.13, 2.48, 2.69, 2.71**; fullest
**2.09, 2.40, 2.43, 2.46**. Queens, run as a control in the same session,
gave **3.45 and 3.49** against the 3.83 in its own spec and the 2.87–2.90 of
the Mushroom Patch session — a spread of its own, which is the machine and
not either board (see Hidden Word's row in `docs/art/flat-motion.md`). So:
**every reading is quoted above, including the unflattering ones**, the
board sits in the same neighbourhood as its neighbours, and no single
reading off this harness is worth anything on its own.

### Reduce motion

**58** draw calls, one fewer than played — there is no ring and no sparkle
to count. Two frames **1.5 s apart are pixel-identical** (`bbox None`, max
channel difference 0), so nothing on this screen moves when it is told not
to.

### The phone's driver

`--rendering-driver opengl3_angle`: **80** on the fullest board, matching
the default driver exactly, and 58 played against the default's 59 — one
call, an fx ring or sparkle alive at one sampling and not the other.

The settled frames match **to 1/255 across the whole board card** — pure
rounding, so nothing here has reintroduced an `instance uniform`. The only
differences above 8/255 in the whole frame are **408 pixels in two bands**:
rows 53–77, the wordmark's sun-dot glint, and rows 1355–1361, the tip card's
sprout blinking. Both are shared chrome on their own clocks and differ that
much between two runs of the *same* driver, which is exactly what Bridges
recorded.

### The suite, and the win

`godot --headless --path . --script tests/run_tests.gd` → **28,528 passed,
0 failed**, with `tests/test_quilt.gd`'s sixteen functions in it.

`tests/_win.gd` → **16/16 winnable**, Quilt included, driven end to end
through real touch events: `board fit=true, hud=true`, one hint taken
through the HUD and the given it sewed correctly refusing to be picked up
again. Adding it needed one `_solve_quilt`, which has to aim the finger
`HOLD_LIFT` cells *below* each target — aiming at the cell itself places
every patch a row and a bit too high and the board refuses the lot, which is
the harness agreeing with the rule rather than working around it.

A throwaway `SceneTree` probe drove the board through grab, drag and release
for all three bands, plus a refusal, the full answer, an undo, a hint, a
given's refusal and a reset, drawing a frame after each: **0 failures**.

## 15. Amendments

Recorded as the build measured them. Five of the proposals above did not
survive contact, and each is written into the section it belongs to rather
than only here:

1. **`Pal.REGION` was rejected for cloth** and `Pal.CLOTH` added — section 5.
   The claim "every colour is already in the palette" was wrong, and the
   render is what said so.
2. **`Pal.SURFACE_HI` was rejected for the backing**, four points off the
   card it sits on; `QUILT_BACK` reuses Shikaku's `BED_GROUND` — section 5.
3. **The rack's grid of equal bays was rejected**, measured at 46.7 a cell
   on every band, and replaced with two content-packed shelves — section 6.
4. **The empty bays are drawn**, which the design did not call for and a
   nearly finished board demanded — section 6.
5. **The rose ghost was dropped** and the held cloth blushes instead, with
   `CLEAR`/`FITS`/`SNAG` in place of `fits()`'s two answers — section 6.

And one that came out of the build rather than the design:

6. **`quilt_state.gd` grew `take()` and `drop()`** so that one gesture is
   one undo — section 3. `place()` and `lift()` are wrappers over them.

Two things are left open and named rather than fixed:

- **The hard band's 200-attempt budget misses about one day in 3,800**, and
  the fallback is a real puzzle graded slightly soft. Section 4 has the
  reasoning and the two levers.
- **`hint()` differs from Queens' when `ok` is false.** Queens refuses a
  hint on a board it could not prove; Quilt gives one, because the stored
  answer is a valid tiling whatever the proof said and the hint lifts
  everything in its way, so the board it leaves is always legal and
  finishable. No seed in 1,500 has produced an unproved board, so this path
  is reasoned rather than observed.
