# Bridges, flat: a screen for a grid that has run out of slots

Hashiwokakero, themed as islets in a river joined by plank bridges. Twelve
flat boards stand on the first screen and every slot is taken, so section 2
is about where this one goes rather than which cell it takes; it was designed
on 2026-09-20 alongside two other boards with the same problem.

**It is called Bridges and nothing else**, in code, in a comment or on
screen. Hashiwokakero is Nikoli's name for it and the reference the design
came from ships it as "Metrô"; neither belongs in this repo. This is the
fourth time the repo has renamed a game it did not invent (Code Break,
Hidden Word, Word Trail), and the rule those three set holds here: the
original name is recorded once, in this paragraph, in order to forbid it.

The playable mock is `docs/brainstorm/concepts.html#bridges`, built before
this spec as the house order requires. **Every measurement below is ported
from that mock**, which is the reference for the build; where a figure came
from the mock's JavaScript rather than from Godot, this document says so,
because a JS timing is not a GDScript timing.

## 1. What is built

A lattice of water cells with islets standing on some of them, each islet
showing a number. A **run** is the 0 to 3 planks laid in the straight lane
between two islets that face each other orthogonally across open water.

The rules, and there are only four:

- A run is orthogonal only, and at most three planks join the same pair.
- Runs may not cross. A lane ends at the first islet it meets, so a run can
  never pass over an islet.
- Every islet must end with exactly its number of plank-ends.
- Every islet must end in **one single network**.

The fourth rule is the puzzle. Without it most boards have several legal
fillings and no generator can promise one answer; with it, the position the
player spends the last third of the board in -- every number met, the islets
in two separate rings -- is the thing being solved. The reference's own rules
card does not state it. This one does, in `rules()` and on the tip card.

## 2. Where it stands on the first screen

The grid is twelve cards, three across and four down, and all twelve are
live. On the day this was designed two other boards were in flight on their
own branches, each adding a thirteenth card and **each having independently
built a pager in `ui/menu.gd`** to make room for it. This board is the third
in that queue and does not touch `ui/menu.gd` at all: it adds a registry
entry and a card picture, and whichever pager merges first carries it.

That is a deliberate narrowing, and it has a sharper cost than this spec
first claimed. The original wording here said the card simply would not
appear on a full grid. **That was wrong, and the build proved it wrong.**
`ui/menu.gd:139` loops `for i in Registry.PUZZLES.size()` into a 3-column
grid with no cap of any kind, so a thirteenth entry *does* get a card, the
grid becomes five rows, and **the bottom bar is pushed off the bottom of the
screen**. The menu shot drops from 322 draw calls to 313, and the nine
missing calls are the bar leaving, not a saving.

So the constraint is not "the card is invisible until a pager lands", it is
**this branch cannot merge to `main` before a pager does**. That is a merge
ordering requirement, not a defect in this board: nothing here is wrong, and
the moment a pager is in front of it the card takes its slot. It is written
down in this paragraph because the symptom -- a first screen with no bottom
bar -- looks nothing like its cause, and the next person to see it will not
guess that a registry entry three files away did it.

The card picture is drawn and verified on its own (section 11); its
draw-call contribution to a full page is not, and cannot be until a pager
lands.

`ui/registry.gd` gains one `PUZZLES` entry:

```
"id": "bridges", "kind": "puzzle", "title": "Bridges",
"blurb": "Plank every islet to its number, and join them all.",
"short": "Plank every islet\nto its number.",
"motto": "Join every islet",
"footer": "Link · Count · Cross",
"script": "res://puzzles/bridges2d.gd",
"shell": "flat", "tray": "none", "difficulties": [0, 1, 2],
```

No `seed_as`: this board shadows no island. It picks nothing up, so it asks
for no tray; it has a real Check, so unlike Balance and Untangle it keeps the
actions row. `Bridges` at GameWordmark 84 is far inside the four-button 496
block, so `_fit_title` leaves both the title and the 16-character motto
alone -- this is not one of the four labels that get lettered smaller.

## 3. The state is the one truth

`puzzles/bridges_state.gd`, a scene-free `RefCounted`, as every flat board's
rules are. It holds the lattice size, the islets and their numbers, the
answer's runs, the player's runs, and the history. The board
(`puzzles/bridges2d.gd`) only draws it.

What it exposes, and nothing more -- this is the surface as built, and the
board is written against it: `build(rng, difficulty)`; `lane_at(a, b)` and
`facing(cell, dir)` for finding the lane a gesture means; `blocked_by(key)`;
`cycle(key)`, which advances a run 0→1→2→3→0 and is the only way a plank is
laid; `clear_run(key)`; `undo()`; `reset_board()`; `hint()`; `wrong_runs()`;
`degree(cell)`; `groups()`; `is_solved()`; and `share_glyphs()`. Runs are
keyed by lane, `"x,y|x,y"` with the two cells sorted, so the end a gesture
starts from never matters.

**A run is wrong when it carries *more* planks than the answer lays there**,
including a run on a lane the answer never names. An under-laid run is
unfinished, not wrong. The distinction is not pedantry: marking every
under-laid lane would print the answer, which is exactly what section 10
says this screen does not do. It also matches the house convention that
`nonogram_state.wrong_tiles` and `lightup_state.wrong_lamps` already set.

Two things are **derived and never stored**, which is Queens' rule and the
reason undo needs no bookkeeping for them: an islet's current degree, summed
from its runs, and the network's connected groups, flooded from the runs on
demand. Storing either would mean a second truth to keep in step, and undo
would have to unwind it.

`is_solved()` is every rule at once and never a subset of them: every islet's
degree equals its number, **no two laid runs cross**, and one flood from any
islet reaches them all. The crossing clause is a backstop and not the rule's
enforcement -- `cycle()` refuses a crossed lane, so ordinary play cannot reach
a crossed position -- but a win predicate that covers only two of the three
rules it states is a bug waiting for the next way in, and there *was* one: see
section 10 on the hint that lifted a single blocker.

## 4. Generation: grow the answer, then prove it unique

`puzzles/bridges_gen.gd`. The generator does not search for a puzzle; it
grows an answer and then proves the clues admit only that answer.

1. **Grow.** Place one islet at random. Repeatedly pick an existing islet, a
   free direction, a distance up to the band's max span, and a run of one to
   three planks; refuse anything that crosses a laid run, lands on or passes
   over a taken cell, or pushes either degree past 6. Stop at the band's
   islet count. The network is connected by construction, so rule four is
   satisfied by the answer before anything is checked.
2. **Close some loops.** The grow step lays exactly one run per new islet, so
   on its own it can only ever build a **tree** -- and on a tree the
   connectivity rule never bites and no lane is ever a decoy. A second pass
   joins a few pairs that already face each other. It is bounded by the
   degree cap rather than by the number asked for: past a point, asking for
   more loops changes nothing.
3. **Centre and reach.** The walk wanders, so a raw board sits in a corner
   with two empty rows. The islets are slid so their bounding box is centred,
   which changes no lane, no crossing and no answer, and the board is
   rejected unless that box comes within one row *and* one column of the
   lattice edge.
4. **Clues.** Each islet's degree is its number. The cap is **6**, not the 8
   the original game allows. Six keeps growth tractable and every number
   inside one glyph; the cost, stated because it is real, is that an 8 --
   all four lanes nearly full, the best free opening clue a Hashi board has
   -- never appears on this screen.
5. **Prove it.** A solver runs range propagation over every lane (each pair's
   `lo..hi` narrowed by each islet's remaining need, its still-open
   directions, and the lanes a laid run now blocks), plus **the group rule**,
   which has two halves and needs both. Flood the islets over the lanes that
   must carry at least one plank; if that leaves more than one group, then a
   group with **no** way out still open is a contradiction, and a group with
   **exactly one** way out must take it. The first half is the connectivity
   rule as most people state it; **the second half is what pins lanes without
   a guess**, and dropping it moves the guess-free rates off 100/81/69 by a
   wide margin. Then a DFS counts answers and **stops at two**. A board with a
   second answer is thrown away and the grow restarts.
6. **Grade.** The generator records how far pure propagation gets before the
   first guess. **Band 0 must need no guess at all**; the other two may.

### The bands

| Band | Lattice | Islets | Max span | Loop pass | Guess-free |
|---|---|---|---|---|---|
| 0 | 7x7 | 11 | 5 | 4 | required |
| 1 | 9x9 | 16 | 5 | 6 | not required |
| 2 | 11x11 | 24 | 5 | 10 | not required |

Eleven islets on the 7x7 and not ten: at ten, a board averaged 0.7 decoy
lanes and 0.6 crossing pairs, so **the no-crossing rule effectively never
appeared on the easy band**; eleven gives 1.0 and 1.0 for a tenth of an
attempt more. Even at eleven the crossing rule shows up about once a board,
which is thin -- see section 15.

Max span stays at 5. Shortening it to 3 to pack the board tighter was
measured and is the wrong lever: it made boards no denser in decoys (1.3
against 1.1) and cost the hard band 70 attempts and 41 ms against 7.3 and
5.9. The lever that works on density is the islet count.

### What the mock measured

500 seeds a band, in the mock's JavaScript, on this Mac:

| Band | Attempts | Rejected for a 2nd answer | No guess needed | Lanes pinned by propagation | Generate |
|---|---|---|---|---|---|
| 7x7 | 3.0 mean, 13 worst | 54% | 100% (required) | 100% | 0.41 ms mean, 5.3 ms worst |
| 9x9 | 3.9 mean, 19 worst | 70% | 82% | 94% | 0.33 ms mean, 2.1 ms worst |
| 11x11 | 6.8 mean, 47 worst | 82% | 71% | 87% | 0.93 ms mean, 7.0 ms worst |

**The port then reproduced them**, which is the reason this table is left
standing rather than replaced. 200 boards a band in GDScript, two sequential
readings: attempts 3.26 / 4.14 / 6.71 mean and 19 / 20 / 53 worst against the
mock's 3.0 / 3.9 / 6.8 and 13 / 19 / 47; second answers rejected on 53% / 72%
/ 84% against 54% / 70% / 82%; guess-free on 100% / 81% / 68.5% against 100%
/ 82% / 71%. Every figure within two points of a different language's
implementation of the same rules, which is a stronger statement about the
solver than either run alone. **Worst case 14.4 / 13.9 / 56.7 ms against the
194 ms gate** -- 3.4x of headroom on the hard band. The port's solver was
also cross-checked the way the mock's was, against an independent counter
with no propagation and no group rule, on 102 boards: 0 mismatches.

The uniqueness claim is **cross-checked rather than asserted**: on 380 boards
an independent counter -- a plain DFS over every lane with no propagation and
no connectivity pruning -- agreed with the solver's count every time, 0
mismatches, and the grown answer verified legal on all 380.

**These are JavaScript figures and the port's budget is a GDScript one.** The
honest reading is that there is roughly twenty times headroom against the
~194 ms the Sudoku generator was gated at, and that **the number to watch in
the port is attempts, not milliseconds**: the worst case is 47 attempts on
the hard band, and it is the retry loop, not the solver, that will decide
whether this fits. The port's own timing is measured in section 14 and this
paragraph is not a substitute for it.

## 5. The finger

Press an islet and drag toward a neighbour. The drag takes its dominant axis
and lights the lane to the first islet that way, so the player sees what they
are about to join before they let go. Release on it and the run cycles
**0→1→2→3→0**. A tap on the water of an existing run wipes that run to 0 in
one go.

Two gestures are refused, and a refusal flashes the lane and puts the broken
rule on the tip card, which is the tip card's established job on these
screens:

- a drag with no islet facing it that way ("Nothing faces it across the
  water.");
- a drag whose lane is already crossed by another run ("Another run crosses
  that lane.").

An islet pushed **over** its number is not refused. It is drawn wrong -- a
`BAD` ring, its turf washed out, one shiver -- and the player fixes it. That
is the house rule that feedback beats a mode: nothing on these boards stops a
finger from making a mistake it can see.

Three things about the refusals that the build settled and this spec did not:

- **The lines are shorter than the mock's**, on purpose. The mock says "Runs
  may not cross. Clear the one in the way first." and "Nothing faces that
  islet across the water."; the board says the two above. The porting rule on
  this board is about measurements, not about copy.
- **The refusal band is drawn under the runs, not over them.** That order is
  what makes the blocker highlight read as a glow beneath the run in the way
  rather than paint laid on top of it: water, then the aim and refusal bands,
  then the runs, then the islets, then the numbers.
- **What moves on a refusal is the pressed islet**, leaning along the drag.
  The mock appears to shiver the refused lane, but that is a dead branch --
  a refused lane carries zero planks at that moment, so the mock's own draw
  returns before the shiver applies, and the mock has no visible nudge at
  all. The islet under the finger is the one piece guaranteed to exist for
  both refusals, so it is the piece that answers.

And one consequence nobody chose but everybody should know: **under reduce
motion a refusal has no visual at all.** The flash is motion and the lean is
motion, so the tip card's line is the whole of the feedback. That is correct
house behaviour and matches every other board, but on this board the refusal
is *entirely* motion, which is not true of the others.

The cycle wrapping at 3 means clearing a full run takes three drags, with
tap-to-wipe as the shortcut. **Nothing on screen teaches the tap**, and that
is carried as an open call in section 15 rather than solved here.

## 6. The screen, measured

At 1080x1920 design space, top to bottom: 40 margin, a 180 top bar, 20, the
120 day card, 20, the **1190 board card**, 20, the 130 actions row, 20, the
140 tip card, 40. That is 1920 exactly, and a **290 bottom slot** -- the same
shape as Shikaku, Tents, Light Up and One Line, so `ui/flat/flat_host.gd`
needs no change at all.

Inside the card, a sea pool inset 28 from the paper (`INSET`), with the
lattice inset a further 12 inside the pool (`FIELD_PAD`). Those two are the
only constants: the lattice is measured off the pool the card hands over, so
its width is a consequence and not a setting. At 1080 wide that is a 1000
card, a 944 pool and a lattice **920 wide at every band**, so the width binds
and a cell is **131 / 102 / 84** on the three bands. That leaves 214 of pool height over, and because the lattice is
square in a tall slot, `card_centred()` is `true` and the slack is
**halved: 107 above and 107 below**.

One detail the build settled and this section had not: `card_height()` hands
back **every pixel it is given**, so the host has nothing left to halve, and
the centring `card_centred()` promises is done by the board itself inside the
pool (`_origin()`). `FIELD_PAD` only ever caps the cell -- it does not inset
the lattice's seat -- which is why the leftover is 214 and not 190.

An islet is a turf disc on a sand rim with its number in ink. A plank is
**0.115 of a cell thick with 0.095 between two of them** (`PLANK`,
`PLANK_GAP`), so a full run of three spans 0.59 of a cell -- wide enough to
read as three at 84 px and narrow enough to leave water either side.

Everything else the board is made of was ported from the mock number for
number, and all of it now stands as named constants in
`puzzles/bridges2d.gd`. **Three different units are in play**, and mixing
them up is how this board goes wrong, so each table below says which it is.

### The pool, in design-space pixels

These are the mock's own numbers and they do **not** scale with the band. The
pool is the card less `INSET` on every side and the lattice is 920 at every
band, so both are the same size on a 7x7 as on an 11x11; the only thing a
band changes is the cell.

| What | Constant | Value |
|---|---|---|
| Pool corner | `POOL_RADIUS` | 34 |
| The rim the pool stands on | `POOL_EDGE` | 9 |
| Shallows, inset from the pool | `SHALLOW_INSET` | 9 |
| Shallows, band thickness | `SHALLOW_W` | 26 |
| Shallows, corner | `SHALLOW_RADIUS` | 26 |
| Shallows, alpha | `SHALLOW_ALPHA` | 0.85 |

The pool is two rounded rects, not a rect with a border: the deep edge colour
fills the whole box and the sea fills the same box `POOL_EDGE` shorter, so
the rim shows along the bottom only, the way a lip catches light.

### The ripples, also in pixels

Nine of them (`RIPPLES`), each a quadratic bezier bowed up by `RIPPLE_BOW`
and stroked `RIPPLE_W` wide in `WATER` at `RIPPLE_ALPHA`.

| What | Constant | Value |
|---|---|---|
| How many | `RIPPLES` | 9 |
| Stroke width | `RIPPLE_W` | 8 |
| Alpha | `RIPPLE_ALPHA` | 0.24 |
| Sown from, in from the pool's corner | `RIPPLE_AT` | (60, 70) |
| Kept clear of the far edges | `RIPPLE_SPAN` | (190, 140) |
| Length, base plus spread | `RIPPLE_LEN` | (40, 60) |
| Bow | `RIPPLE_BOW` | 8 |

**`RIPPLE_SPAN` is the one number on this board that is deliberately not the
mock's.** The mock sows its ripples over (160, 140) and then clips the whole
sea to the pool's rounded rect, so a ripple that runs off the edge is simply
cut. **A mesh cannot clip**, and this board is one `ArrayMesh`, so a ripple
that ran past the rim would stand on the paper outside the pool. The width
was raised from 160 to 190 so the ripples are sown clear of the rim instead
of cut at it, and the arithmetic is exact: a ripple starts at `RIPPLE_AT`
plus up to `pool - RIPPLE_SPAN`, and runs up to 100 long, so on the 944-wide
pool the furthest one ends at 914 -- 30 px clear of the edge. At the mock's
160 that last ripple would end at 944, on the rim itself, which is precisely
where the mock's clip cuts it. The height stays the mock's 140, because a
ripple's vertical extent is the 8 of `RIPPLE_BOW` and nothing reaches.
Everything else in these tables is the mock's figure verbatim.

### An islet, in fractions

`ISLET_R` is a fraction of the **cell**; everything under it is a fraction of
**that radius**, so an islet keeps its proportions at 131, 102 and 84 alike.

| What | Constant | Value |
|---|---|---|
| Turf disc radius, of the cell | `ISLET_R` | 0.40 |
| Coloured shadow, offset down | `SHADOW_AT` | 0.30 |
| Shadow radii | `SHADOW_RX` / `SHADOW_RY` | 1.02 / 0.40 |
| Shadow alpha | `SHADOW_ALPHA` | 0.30 |
| Wet sand, offset down | `SAND_DROP` | 0.07 |
| Turf, of the sand rim | `TURF_R` | 0.80 |
| Turf lip, offset down | `TURF_DROP` | 0.04 |
| Sun cap, seat and radii | `CAP_AT` / `CAP_R` | (-0.22, -0.34) / (0.30, 0.17) |
| Sun cap alpha | `CAP_ALPHA` | 0.55 |
| Number size, of the islet | `NUMBER_SIZE` | 0.95 |
| Number seat | `NUMBER_AT` | -0.04 |
| A met number, let down toward the paper | `NUMBER_MET` | 0.38 |
| How wide a press still takes the islet | `GRAB` | 1.25 |

`GRAB` is 1.25 and not 1.0 because an islet is round and the corners of its
cell are water: a finger that lands on the corner meant the islet.

### Two rings, two floors

**There are two rings on this screen and they are not the same ring**, which
section 9 discusses only half of. The satisfied ring is the standing
`GOOD`/`BAD` band a met or over-filled islet wears; the aim ring is the gold
band a live drag throws round the islet it is about to join. They have
different radii, different thicknesses and **different pixel floors**.

| Ring | Radius | Width | Floor | Alpha |
|---|---|---|---|---|
| Satisfied (`RING_*`) | 1.13 | 0.13 | 4 px | 0.95 |
| Aim (`BEAM_RING*`) | 1.22 | 0.14 | 5 px | 0.90 |

Both radii and widths are in islet radii. The floors are what keep either
ring from becoming a hair on the 11x11, and section 9's arithmetic -- 4.7 px
from the ratio against a 5 px floor -- is about the aim ring alone.

### The lit lane and a refusal, in fractions of a cell

| What | Constant | Value |
|---|---|---|
| Beam width | `BEAM_W` | 0.62 |
| Beam corner | `BEAM_RADIUS` | 0.4 |
| Let in under the islets it joins, in islet radii | `BEAM_TUCK` | 0.4 |
| Beam alpha | `BEAM_ALPHA` | 0.72 |
| Refusal band alpha | `REFUSE_ALPHA` | 0.88 |
| Blocker highlight alpha | `BLOCKER_ALPHA` | 0.95 |

`BEAM_W` is 0.62 against a full run's 0.59, so a lit lane is wider than three
planks by a hair and never reads as a run that is already there.

### A plank

Thickness and gap are the 0.115 and 0.095 above. The rest:

| What | Constant | Value | Unit |
|---|---|---|---|
| Corner, of its own thickness | `PLANK_RADIUS` | 0.34 | fraction |
| The lip the deck stands on | `PLANK_EDGE` | 4 | px |
| Shadow offset | `PLANK_SHADOW` | (3, 7) | px |
| Shadow alpha | `PLANK_SHADOW_ALPHA` | 0.22 | — |
| Slat spacing | `SLAT_STEP` | 0.30 | of a cell |
| Slat width | `SLAT_W` | 0.022 | of a cell |
| Slat floor | `SLAT_MIN` | 2 | px |
| Slat alpha | `SLAT_ALPHA` | 0.28 | — |

The lip is the same 4 px trick as the pool's: the deep colour fills the
plank's box and the deck fills it `PLANK_EDGE` shorter on the axis the run
does not run along, which is why a plank is a plank and not a bar.

### The hint's glow pad

| What | Constant | Value |
|---|---|---|
| Pad off the run's own box, of a cell | `GLOW_PAD` | 0.13 |
| Corner, of the pad | `GLOW_RADIUS` | 1.6 |
| Alpha | `GLOW_ALPHA` | 0.85 |
| Dash on / off, of a cell | `DASH_ON` / `DASH_OFF` | 0.13 / 0.1 |
| Dash width, of a cell, with a floor | `DASH_W` / `DASH_MIN` | 0.05 / 3 px |

## 7. Colour

This is the first flat board whose field is not paper, and the sea was
re-pitched once before this spec was written: the first cut used `WATER`
straight and read as the loudest surface in the game. Every value below is a
**mix of exactly two `core/palette.gd` entries**; nothing here is invented
and nothing was added to the palette.

| Surface | Value | Mix |
|---|---|---|
| Open water | `#a4cde6` | `mix(WATER_HI, PAPER, 0.46)` |
| Shallows | `#cfdfe4` | `mix(WATER_HI, PAPER, 0.74)` |
| Pool edge | `#5896c2` | `mix(WATER_HI, TEXT, 0.20)` |
| Islet shadow | `#336e99` at 0.30 | `mix(WATER, TEXT, 0.35)` |
| Ripples | at 0.24 | `WATER` straight |

Letting `WATER_HI` down into **`PAPER`** rather than into `SKY_TOP` or
`SURFACE` is what carries the warmth: the paper's red comes up as the blue
comes down, so the result is a warm pale blue rather than a cool sky one,
which is what `docs/art/shading-direction.md` asks for.

Two things invert on a pale ground, and both are counter-intuitive enough to
be worth writing down: **the ripples are darker than the water they lie on**
(`WATER_HI` strokes vanished, so the old sea's blue became the new sea's
mark), and **the shallow band is paler than the open water**, not deeper.

The islets: turf is `BANK`, and the beach around it is **`ACORN`** with
`mix(ACORN, TEXT, 0.22)` offset down 0.07R for the wet sand at the
waterline. The beach was `STONE` in the first cut and **the islets stopped
reading entirely** -- `STONE` is value 237 against a 230 sea, seven points
apart, so the rim disappeared. `ACORN` sits 29 of value below the water and
warm against a cool ground. It is far enough from `DECK` that a beach and a
plank never read as the same material.

### Warm ink on the sea

The first cut needed a special case -- `BAD` at any alpha over deep `WATER`
came back mauve, so the refusal band had to be drawn opaque and dissolved by
mixing toward the water. **The pale sea deletes that special case**: the
refusal band is now plain `BAD` at a fading alpha, and so is the blocker
highlight.

The rest of the warm ink moved the other way, because the problem flipped
from "too weak against dark" to "too pale against light":

| Ink | Was | Is |
|---|---|---|
| Refusal band | opaque `BAD`, dissolved by a mix | `BAD` at a fading alpha to 0.88 |
| Drag beam | `SUN_RAY` at 0.78 | `SUN` at 0.72 |
| Hint glow | `SUN_RAY` at 0.70 | `SUN_RAY` at 0.85 |
| Answer dashes (`?peek`) | white at 0.30 | `TEXT` at 0.34 |
| Turf sun cap | `mix(BANK, #ffffff, 0.26)` | `mix(BANK, SURFACE, 0.26)` |

The solve wave's gold (`mix(DECK, SUN_RAY, 0.72)`) and the `GOOD` satisfied
ring are **unchanged**: both read better against the pale sea than they did
against the dark one.

**The rule this screen owns, and the reason the table above records both
columns: a warm-ink alpha tuned against a dark ground is not portable to a
light one, in either direction.** Three of the five re-tunes above were
reversals rather than adjustments. Any alpha fixed as a constant on this
board must say which ground it was measured on.


### The check's mark, and the tint it holds

Check flashes the runs that differ from the answer and then **keeps them
tinted** until the player's next move (section 10). The flash is
`Motion.flash_level` at `BAD_MIX` 0.85 on the deck and `BAD_DEEP_MIX` 0.6 on
the lip; what stays behind is `BAD_HELD = 0.50` **of that peak**, so the held
mark is `mix(DECK, BAD, 0.425)` = `#c4745a` on the deck and
`mix(WOOD_DEEP, BAD, 0.30)` = `#ae6d53` on the lip.

**0.50 was measured, not picked, and the reason it has to be that high is
that `DECK` and `BAD` are both warm**: the mix moves far less than the number
suggests. At 0.35 the marked deck came back `#c0785a` -- eleven units of red
off an unmarked plank -- and on a rendered frame beside a right run it was
there only if you already knew where to look; call that invisible. At 0.65 (`#c96f5a`) it
goes salmon and reads as a second alarm rather than as a mark. Both ends of
the band table were shot with a marked run standing next to an unmarked one,
the 7x7 at a 131 px cell and the 11x11 at 84, because a tint tuned at one
cell size is not portable to the other.

This is the same rule as the rest of this section, arrived at from the other
direction: an alpha or a mix is only valid against the ground it was measured
on -- there against a pale sea rather than a dark one, here against a warm
deck rather than a neutral tile.

## 8. The cast: nobody new

**This board adds nothing to `ui/faces/`**, which makes it the fourth in a
row to add nothing (Nonogram, Hidden Word, Word Trail). Its islets are drawn
shapes rather than characters -- a disc, a rim, a number -- and the only face
on the screen is the shared sprout on the tip card. Check `ui/faces/` before
drawing a character was the rule; here nothing on the board is a character in
the first place, so there is nothing to check for.

The drawing follows Word Trail's arrangement exactly: **one `ArrayMesh`** for
the sea, the ripples, the islets, the runs and the hint glow, with the
numbers as `draw_string` commands over the top, because a glyph in a mesh
cache key multiplies every state by ten. And with it comes Word Trail's
hard-won rule -- **a canvas command holds a mesh by RID, not by reference** --
so the board keeps the mesh its last `_draw` handed over in `_shown` until
the next one replaces it, or a harness's `force_draw()` will photograph a
freed RID.

## 9. Motion

Everything comes from `core/motion.gd`'s vocabulary and
`docs/art/flat-motion.md`; the board's own constants are only the two the
wave needs. A plank drops in; an islet that has just met its number bumps and
takes its ring; a refusal flashes the lane; entrance and reset are the
recipes' own.

**The signature is the network wave.** When the board is solved, light runs
outward along the planks from the islet the player finished at, in breadth
-first order over the network, one step per run: the front crosses a run in
`WAVE_EDGE`, planks behind it wear a lit deck, and each islet flares, bumps
and sparkles as the front arrives. The network the player built is the wave's
own graph, which is why this board could not borrow another's solve -- the
shape of the animation is the shape of the answer.

Reduce motion stills it as it stills every other board: the lit state is
applied at once and no front travels. On this board that also silences the
refusals entirely -- see the end of section 5.

**There are two rings on this screen and they are not the same ring**: the
aim ring that marks the islet a drag is pointing at, and the `GOOD` ring an
islet wears once its number is met. They have different floors, and the
paragraph below is about the first one only.

**The lit lane holds at every band, but not by the same means.** The beam is
0.62 of a cell, so it scales: 81 px at the 7x7's 131, 63 at 102, 52 at the
11x11's 84, still four times a single plank's width on the hardest band. The
ring on the target islet does **not** survive the same way -- at 84 the ratio
gives 4.7 px, under the 5 px floor, so on the hard band that ring is drawn at
the floor rather than at its ratio, and the floor is what keeps it from
becoming a hair.

## 10. The hint, the check, and the silence

Three hints. A hint lays **one plank the answer has and the board lacks** --
never an overshoot, so a hint can never be the thing that pushes an islet
over. It walks the answer's lanes in sorted order, so the hint a board gives
is stable however that board's answer happened to be grown. One edge case is
worth knowing: when every remaining under-laid lane is crossed by a run the
player laid wrong, the hint lifts the blockers first, which is always safe
because the answer's own runs never cross each other. Each lift is its own
history entry, so in that case a hint costs **one undo per blocker plus one**
rather than one.

**It has to be every blocker and not the first, and this was a real bug.**
A lane with *k* water cells can be crossed by *k* different lanes, and two
lanes that cross the same lane are perpendicular to it and therefore parallel
to each other -- so `cycle()` permits both, and a player can have both laid.
Lifting only the first and then writing the hint through the private `_lay`
bypassed the `blocked_by` guard and left **two runs crossing**: a position
this section's own rules call impossible, with both lanes frozen (each is now
`blocked_by` the other, so neither can be cycled), a hint spent, a glow lit
round an illegal run and the tip card saying a plank the answer wants is in.
Reproduced on band 0 at `rng.seed = 259`, where the lane `1,2|1,6` is crossed
by both `0,3|2,3` and `0,5|2,5`; a regression test in `tests/test_bridges.gd`
builds that position and asserts nothing crosses after the hint. Aimless
random play never reached it (0 in 360 tries) while realistic near-end play
hit it in 1-3.3%, which is why the suite had not caught it. `is_solved()`
grew its crossing clause in the same pass -- see section 3.
Verified over 120 boards hinted to completion: 0 overshoots, and every board
finished. Check marks the runs that differ from the answer, costs a check, and is
the board's only door to the one thing it will not tell you.

**Its marks flash and then hold.** The flash is the beat that says where to
look -- on an 11x11 with 24 islets something has to -- but when it decays the
marked runs keep a quiet tint until the player's next move clears them, on
the same clearing as every other transient state. This is a deliberate
departure from Nonogram and Light Up, whose marks fade away entirely, and the
reason is that on those boards a check is decoration over a board that
already shows its own state, while here **a check is the only door to the
near-miss and it is paid for**. A player who spends a check keeps what they
bought until they act on it. The departure also fixes something nobody chose:
with a fading mark, a reduce-motion player -- who is drawn no flash at all --
paid a check and was shown nothing whatsoever.

**The near-miss is unsignposted, deliberately.** When every number is met but
the islets are in two rings, the board says nothing: no group count, no tint,
no line. Seeing the split network is the puzzle, and Check is the door at the
price of a check. This is the same rule Code Break's screen is built on --
the screen never hands over the deduction the player is there to make -- and
it was taken as a decision rather than an oversight.

## 11. The menu card

One branch of `ui/menu/card_art.gd`'s `_build` and one of `_draw`: three
turf islets with their numbers on a small sea panel, two joined by a double
run and one waiting. Drawn furniture, no character, no image, no
`SubViewport` -- the card and the board are the same drawing, as every other
card is.

## 12. What the board says

`rules()` is a one-line preamble -- "Join the islets with plank bridges." --
and then the four rules of section 1, **connectivity last** and stated
plainly. It is not section 1's order: the number rule comes ahead of the
crossing rule, because a player reads the number on an islet before they have
laid anything to cross. The order that is load-bearing is the last one, and
that is the one the code keeps. The tip card's resting line is "Press an islet and drag
at the one facing it."; its two refusal lines are in section 5.

`flat_win()` returns `{"faces": [], "subtitle": ...}` -- the no-cast form
Light Up uses. The joined network stays on the card under the win screen,
because the board is the answer and there is nothing better to show.

`share_glyphs()` takes Shikaku's one-line form rather than Light Up's grid:
an 11x11 emoji lattice would be mostly blank water. One line with the
lattice, the islet count and the planks laid.

## 13. Analytics

Nothing new. `puzzle_start`, `puzzle_complete` with `solved: true`,
`puzzle_abandon`, `hint_used`, `check_used`, `undo_used`, `board_reset`,
`rules_opened` -- all from the host, all carrying this board's `puzzle_id`.
This board cannot end without a solve, so it never sends `solved: false`.

## 14. Calls this screen is for

Measured on this Mac on 2026-09-20 with
`godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- bridges`
-- the resolution flag before `--script`, windowed, and **one harness at a
time**. The harness disables vsync, so the idle mean is a measurement rather
than the 120 Hz ceiling `tests/_shot_menu.gd` reports.

### Draw calls

**64 to 65**, against the 855 budget. Every reading of the session, in the
order taken:

| Run | Draw calls | Idle mean | Idle frames |
|---|---|---|---|
| Bridges 1 | 65 | 4.11 ms | 487 |
| Bridges 2 | 65 | 4.22 ms | 474 |
| Bridges 3 | 64 | 3.75 ms | 532 |
| Word Trail (control) | 65 | 2.94 ms | 681 |
| Word Trail (control) | 65 | 3.38 ms | 594 |
| Queens (control) | 71 | 4.28 ms | 468 |
| Queens (control) | 71 | 3.93 ms | 508 |
| Bridges 4 | 64 | 4.08 ms | 490 |
| Bridges 5 (`empty`, bare board) | 64 | 4.04 ms | 495 |
| Bridges 6 (`rm`, reduce motion) | 64 | 4.27 ms | 633 |
| Bridges 7 | 65 | 4.05 ms | 493 |
| Bridges 8 | 65 | 3.11 ms | 642 |
| Bridges 9 (`opengl3_angle`) | 65 | 5.98 ms | 334 |
| Bridges 10 (`empty`) | 64 | 3.61 ms | 554 |
| Bridges 11 (`empty`) | 64 | 4.54 ms | 440 |

The controls are quoted because a single reading off this harness is worth
nothing. **The draw calls came back exactly on record** -- Word Trail 65 and
65 against its recorded 65/62/65, Queens 71 and 71 against its recorded 71 --
which is what makes this session's counts worth writing down.

The board's own spread is **64 or 65 and nothing else**, and the two are not
two states:

- **Bare (`empty`): 64, 64, 64.** Three readings, no variation.
- **Reduce motion (`rm`), which plays the same two runs: 64.**
- **The strip's state** -- two runs laid at one islet, its number met, its
  ring up -- **65, 65, 64, 64, 65, 65.** Same code, same board, same frame
  budget, six runs.

So the played board costs the bare board **either nothing or one call**, and
which of the two a run reports is not determined by anything on screen. **It
cannot be the ring**: the ring is built into the same `ArrayMesh` as the rest
of the board, and a mesh is one draw call however many fans go into it. The
likely cause -- and this is an inference from the timings, not a measurement
-- is `ui/fx2d.gd`: the ring and sparkles the satisfied islet throws are
their own canvas items, the idle window opens at 3.2 s, and the last plank
lands not long before it, so whether one effect node is still alive when the
counter first samples is a matter of a frame or two. That is exactly Word
Trail's 62 outlier in the other direction -- its spec reaches the same
inference from the same shape of evidence, with its own effect-free bare and
reduce-motion boards reading a stable number while the played one wobbles. **It was not checked by stubbing the effects
out**, and until someone does, the honest statement is that this board costs
64 with an occasional 65 and both are 790 calls inside the budget.

### Idle, and the caveat that matters more than the number

**4.05, 4.08, 4.11, 4.22, 3.75 and 3.11 ms** on the strip's state; **4.04,
3.61 and 4.54** bare; **4.27** under reduce motion; **5.98** on ANGLE. Quote
all of them or none.

**This machine's idle figure is not stable and this board has already proved
it.** On unchanged Bridges code, in a single day, the same harness has
returned figures from **2.50 to 7.62 ms** with the draw calls flat at 64
throughout. The session above is tighter than that -- 3.11 to 4.54 over ten
default-driver runs -- but the spread is still a third of the mean.

The controls say the same thing from the other side, and they do not all
agree:

- **Queens came back where it is recorded** (4.28 and 3.93 against ~3.83-4.5).
- **Word Trail came back high** (2.94 and 3.38 against its recorded
  2.40-2.51), 20 to 40 percent above its own figures.

So the honest reading is: the *counts* from this session are trustworthy and
the *milliseconds* are comparable **only within it**. Within it, Bridges
(3.11-4.22) sits above Word Trail (2.94, 3.38) and at or just under Queens
(3.93, 4.28) -- which is where a board with a full-card mesh, nine ripples
and a shallow band should sit, but the gap to Word Trail is about one
millisecond and this session's own noise is larger than that. **Nobody should
read a ranking off it.** Against the 8 ms the polish spec asks for, every
reading is inside, with the worst of them at about half.

One thing genuinely is cheap and it is not visible in these numbers: a
settled Bridges card **redraws nothing at all** -- `_anim_until` has passed,
so the idle window is measuring the chrome around a still mesh. What the
readings above bound is the cost of *having* this board on screen, not the
cost of playing it. The playing frames are inside the strip and were not
timed separately.

### Reduce motion

The `rm` pair 1.5 s apart is **pixel-identical**: the difference image's
bounding box is empty and the maximum channel difference is 0 over the whole
810x1440 frame. Nothing on a settled Bridges board moves when motion is off.

### The phone's driver

`--rendering-driver opengl3_angle`: **the same 65 draw calls**, and the
settled frame compared against the default driver's pixel for pixel.

Outside one 33 by 35 box the two drivers agree to **4 of 255**, and 167,582
of the 168,213 differing pixels differ by exactly **1** -- the pale sea's
gradient rounding, across the sea and nowhere structural. That is the
expected edge-antialiasing-and-rounding class and **not** the
`instance uniform` class of bug; nothing this board touches declares one.

The one box that differs by more (132 of 255) is the **wordmark's sun-dot**
in the top bar, and it is not a driver difference at all: two runs on the
*default* driver, compared with each other, differ by 82 of 255 in the same
box and nowhere else. `ui/sun_dot.gd`'s rayed sun turns and glints on its own
clock, so the phase it is caught at is not reproducible between runs of the
harness. That is shared chrome on every flat screen, it is not this board,
and it is written down here because the next person to run this comparison
will see a three-figure difference and reach for the wrong explanation.

### Generation, in GDScript

Re-measured with a throwaway probe, 200 boards a band, run from `_process`
(headless `_ready` is deferred), twice; the probe was then deleted. Both runs
agreed to two decimal places on attempts and to a tenth of a millisecond on
the means, so only the second is quoted where they differ:

| Band | Attempts mean | Attempts worst | ms mean | **ms worst** | Guess-free |
|---|---|---|---|---|---|
| 0 (7x7) | 3.26 | 19 | 1.85 | **14.7** | 100.0% |
| 1 (9x9) | 3.83 | 19 | 2.34 | **13.3** | 82.5% |
| 2 (11x11) | 6.26 | 38 | 6.89 | **47.2** | 73.5% |

**Against the ~194 ms gate the worst case is 47.2 ms, which is 4.1x of
headroom on the hard band** -- and the gate is what the Sudoku generator was
held to, so it is a real bar and not a round number.

**Task 1's figures reproduce.** They were 14.4 / 13.9 / 56.7 ms worst and
3.26 / 4.14 / 6.71 mean attempts; this run gives 14.7 / 13.3 / 47.2 and 3.26
/ 3.83 / 6.26. Band 0's mean attempts land on the same 3.26 to the hundredth;
bands 1 and 2 come in a little under. **That is not a speed-up and must not
be read as one** -- Task 1's probe was deleted, so its seed set is unknown
and this one's is `s * 7919 + difficulty`. Two different 200-board samples of
the same generator is all the agreement claims. The hard band's worst case
moved 56.7 to 47.2 for the same reason: the worst of 200 boards is the
longest tail this sample happened to draw, and nothing in the generator
changed between the two.

The guess-free rates -- 100 / 82.5 / 73.5 percent -- hold section 4's
requirement that **band 0 needs no guess**, over 200 boards, and sit beside
the mock's JavaScript (100 / 82 / 71) and Task 1's port figures
(100 / 81 / 68.5). Bands 0 and 1 land within a point and a half of both; the
hard band's 73.5 is 2.5 points over the mock and **5 points over Task 1's own
port figure**, which is the largest disagreement anywhere in this section. It
is a different 200-board sample of the same code, so sampling is the obvious
explanation and no other was looked for.

### The suite

`godot --headless --path . --import` then
`godot --headless --path . --script res://tests/run_tests.gd`:
**passed=19962 failed=0**, on the baseline this branch started from.

## 15. Open calls carried from the concept build

Five, none of them blocking, all measured or argued rather than guessed:

1. **An easy board is mostly open water.** Eleven islets on a 7x7 with a
   reach test still leaves a hollow middle. It is what this puzzle looks
   like, but it may read as under-filled on a phone, and the only lever that
   moves it is the islet count.
2. **The crossing rule barely appears on the easy band** -- about one
   crossing pair a board. That band may never teach its own hardest rule.
3. **Closed, and recorded rather than dropped.** The first cut's sea forced
   warm ink to be drawn opaque over water -- `BAD` came back a bruise, the
   drag beam olive. The colour pass removed the cause, and no warm ink on
   this board is drawn opaque any more. What survives the fix is the rule at
   the end of section 7, which is the general lesson and not this board's
   accident.
4. **Nothing teaches tap-to-wipe** (section 5).
5. **No user mock exists for this board.** The layout is a proposal read off
   the other flat screens' chrome, not a reading of anyone's drawing. Every
   other flat board was ported from a mock the user had seen; this one
   inverts that order, and section 6's numbers should be treated as a first
   pitch rather than a settled composition.

## 16. The polish, 2026-09-26

The user asked for the design and the animation to be polished: the board read
as too simple beside the flat boards' second passes (a flat blue slab, flat
green discs, thin sticks). Built directly, like those passes, and this is the
record. The rules, the layout, the gesture, both refusals, Check's held mark and
the solve wave's clock are unchanged.

- **The sea is sunk into the card.** Its wall shows `BASIN_WALL` along the top,
  the open water `WALL_DEEP` toward ink -- the family's bed, where the first cut
  drew a lip along the bottom and read as a slab laid on the paper. The water
  pales from the open blue to `SEA_PALE` at the wall over `SHORE_W` (one band
  stitched point for point, no step in it), and the shallows over each islet's
  sandbar pale it again (`SANDBAR`). Ripples are a dark arc over a lit one and
  keep clear of every islet. All of it is a **still mesh**, rebuilt only on a
  resize or a new board, so the board's own mesh no longer carries the sea.
- **An islet is a small island.** A soft shadow on the water, a wet-sand foot
  under a beach lit along its top, a turf crown toned off the islet's hash
  with its own lit rim, and a tuft on about half of them.
- **The number stands on a paper coin**, as every other board's clues stand on
  paper, lifted over its own edge. **The coin replaces the standing ring**: it
  washes `LEAF_TILE` carried `COIN_MET` toward `GOOD` (numeral `LEAF_DEEP`)
  when the islet is met, `BAD_TILE` (numeral `BAD`) when it is over, and gold
  when the solve's wave reaches it. A 4 px ring was a hair on the 11x11; a wash
  on the thing carrying the number reads at a glance. The ring `fx` throws off
  a met islet stays, and a met coin glints.
- **Planks are decking**: a lit upper edge, the lip under it, each plank toned
  a hair off its neighbours, a softer shadow in the sea's shade, and a pair of
  pilings at each end of a run, out in the water off the beach.
- **The next state shows before the finger lets go.** Under the lit lane the
  plank the drag would lay stands at `PREVIEW_ALPHA`, or the whole run fades
  to it when the drag would lift it.
- **A plank is laid across from the islet the finger left** -- the pass's
  signature. It rolls out along the lane over `LAY_TIME`, lifted as it
  travels, the near pilings driven first; at `LAND_AT` the far pilings go in,
  the far islet bumps (`LAND_BUMP`), the water splashes there, and an islet the
  move met takes its ring, its note and its glint only then, so the count
  comes right as the wood touches. A run lifted to nothing by a drag draws back
  into that islet (`PULL_TIME`); a wipe, an undo or Reset still closes it in
  place. A hint's or an undo's plank rolls out from its middle.
- **The sea is alive at rest, for one extra draw call.** Every `LAP_EVERY`
  seconds or so one islet laps: two foam rings spread off its beach and fade.
  They are their own small mesh between the sea and the board, so the board is
  not rebuilt for them; nothing laps while anything else moves, and nothing
  laps under reduce motion.
- **The win**: the wave sets off when the last plank lands (`win_delay()`
  waits for that and for the last islet's hop), every islet hops as the front
  reaches it and its coin turns gold, and once the wave has crossed, a light
  runs over the network along the diagonal, glinting every coin and deck.

`tests/_shot_anim.gd -- bridges solve` lays the answer through the state but
one plank and drags that one, so the strip shows the roll-out, the wave, the
hops and the light.

Measured at `--resolution 810x1440`: **63-64** draw calls played (62 before:
+1 for the still sea, +1 while a lap is spreading), **62** under reduce motion,
**63** on the 11x11. Idle 2.85-3.09 ms against 2.42 before in the same
session; the laps redraw the card while they spread. Reduce motion is
pixel-identical across its 1.5 s pair, and ANGLE agrees on 62 and matches the
default driver within 1/255 on the board. Suite 122583/0, win harness 21/21.
