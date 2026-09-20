# Pinwheel — the seventeenth flat board

**Date:** 2026-09-20
**Mock:** `docs/brainstorm/concepts.html#pinwheel`
**Card:** page two, the fifth card (after Mushroom Patch, Sudoku, Bridges and Quilt)
**Status:** design, approved in chat before the mock was built

---

## 1. What it is

A rectangular frame of cells, exactly tiled — in the answer — by a handful of
polyomino pieces of coloured cloth. Each piece is pinned through **one** of its
own cells by a small paper pinwheel, and that pin's board cell never moves.
Tap a pinwheel and its piece takes a quarter turn clockwise about the pin.
Turn every piece until no cell is bare and no cell has two pieces on it, and
the frame is full.

The reference the user supplied is a screenshot of a mobile puzzle app's daily,
and the genre ships elsewhere as **Flipart**. It is recorded here **once, in
order to forbid it**: in this repo the board is called **Pinwheel** and nothing
else, in code, in a comment or on screen. That is the sixth rename after Code
Break, Hidden Word, Word Trail, Bridges and Quilt.

### Why it earns a slot

Sixteen boards already stand on the grid and the question a seventeenth has to
answer is what it does that none of them do. Pinwheel's move is **one tap with
a deterministic consequence and no target**: every other board on the grid asks
*where* (Quilt's drag, Shikaku's rectangle, Sudoku's cell-then-digit) or *what*
(Binairo's brush, Hidden Word's letter). Pinwheel asks neither. The only
decision is *which piece*, and *how many times*. That makes it the cheapest
board in the game to play one-handed, and the only one whose entire input
vocabulary is a single tap on a single unambiguous target.

---

## 2. The rules, exactly

1. The frame is `cols x rows`. Every cell is either bare, under exactly one
   piece, or **stained** — under two or more.
2. Each piece is a polyomino of 1 to 5 cells with one **pin** cell. The pin's
   position on the board is fixed for the life of the puzzle.
3. A piece's **orientations** are the rotations of its cell set about its pin
   by 0, 90, 180 and 270 degrees clockwise that lie **wholly inside the frame**.
   Rotations that coincide (a 1x1, a plus) are one orientation. A piece has
   between 1 and 4.
4. **A tap on a pin cell advances that piece to its next in-frame orientation,
   cyclically in clockwise order.** Out-of-frame rotations are skipped, not
   refused.
5. A piece with exactly **one** in-frame orientation is *pinned fast*. Tapping
   it shivers it under a rose halo and the tip card says so. This is the board's
   only refusal.
6. Pieces may overlap freely. Overlap is the working state, not an error.
7. **Solved when every cell is under exactly one piece.** Because the pieces'
   cells sum to the frame's cells, that is the same statement as "no cell is
   bare" and as "no cell is stained"; `is_solved()` tests coverage directly and
   never compares against the stored answer.
8. The solution is **unique**. See §5.

### Why the tap skips rather than refuses

The alternative — refuse a rotation that would leave the frame — was rejected
before the mock was built, because it is not merely worse, it is **broken**.
Rotation is a discrete state change, so a piece cannot pass *through* an
out-of-frame orientation on its way to a legal one. A 1x4 bar pinned at its end
against the frame edge would have its solution orientation two clockwise steps
away with an illegal step between, and no sequence of taps would ever reach it.
The puzzle would generate unsolvable boards and nothing in the generator would
notice, because the generator reasons about orientation *sets* and not about
reachability.

Skipping fixes it by construction: the in-frame orientations form a cycle, a tap
advances one place round that cycle, so every in-frame orientation is reachable
from every other. It also means **a tap is never a no-op** except on a piece
that has nowhere to go at all, which is the one case worth a refusal.

### Why there is no Check

Nothing is hidden. A bare cell is drawn bare and a stained cell is drawn
stained, so the board already answers, continuously, the only question Check
could ask. This is Word Trail's and Quilt's shape reached by a third route, and
it is the third distinct reason for it:

- **Word Trail** has no Check because only a *right* word locks, so nothing
  wrong can be sitting on the board.
- **Quilt** has no Check because an illegal drop is *never taken*, so nothing
  wrong can be sitting on the board.
- **Pinwheel** has no Check because something wrong **can** be sitting on the
  board and is **drawn as wrong the instant it lands**.

That difference is worth keeping straight: Pinwheel is the first flat board
that lets a player hold an illegal position *and shows them it is illegal*,
rather than refusing the move or waiting to be asked.

---

## 3. The chrome

No tray (nothing is picked up), no actions row (no Check), tip card alone.

| row | height |
|---|---|
| tip card | 140 |
| **bottom slot** | **140** |
| **board slot** | **1340** (1800 − 320 top − 140) |

`"actions": false` puts Reset in the top bar, so Pinwheel is the **fifth** board
carrying five buttons up there (after Balance, Untangle, Word Trail and Quilt),
and its title block is therefore **370 wide, not 496**.

`capabilities()` is `["undo", "hint"]`.

### The title, and a thing to measure rather than assume

`Pinwheel` is eight characters in Fredoka 700 at GameWordmark's 84 against a
370 block. `Word Trail` measures 392 against the same block and is lettered
down to 79; `Pinwheel` is shorter but carries a `w` and an `h`. **It is
expected to fit at 84 and that is an estimate, not a reading.** Measure it with
a headless probe against the real face before the spec's amendments claim
otherwise, the way the `_fit_title` round of 2026-09-20 did, and record the
number here. The motto must be measured too — it is the label that has been
forced down on three of the four existing five-button boards.

Motto: `TURN IT TILL IT FITS` (short on purpose, for the 370 block).

### Registry entry

```gdscript
{
    "id": "pinwheel",
    "kind": "puzzle",
    "title": "Pinwheel",
    "blurb": "Turn each pinned piece until the frame is full.",
    "short": "Turn each piece\ntill the frame fills.",
    "motto": "Turn it till it fits",
    "footer": "Turn · Fit · Complete",
    # Nothing is picked up and nothing is hidden, so there is no tray and no
    # Check; Reset rides up into the top bar and the tip card stands alone.
    "script": "res://puzzles/pinwheel2d.gd",
    "shell": "flat",
    "tray": "none",
    "actions": false,
    "difficulties": [0, 1, 2],
}
```

Seventeenth in `Registry.PUZZLES`, so the fifth card of page two. `PER_PAGE` is
twelve and page two holds four today, so **the pager needs no change** and page
one is untouched — which is the whole point of paging rather than reflowing,
and the third time in three days a board has been added without displacing one.

---

## 4. The board card, and the cell

Board slot 1000 x 1340. A 28 inset leaves 944 x 1284.

| band | frame | cell = min(944/cols, 1284/rows) | board |
|---|---|---|---|
| 0 | 5 x 5 | min(188.8, 256.8) = **188** | 940 x 940 |
| 1 | 5 x 7 | min(188.8, 183.4) = **183** | 915 x 1284 |
| 2 | 6 x 8 | min(157.3, 160.5) = **157** | 942 x 1256 |

Band 1 is the shipping band (the menu hardcodes difficulty 1), so the cell on
the phone is **183** — the **largest** cell of any flat board, well above
Sudoku's 100 and Queens' 103. That is not indulgence: the tap target is the pin
cell and nothing else, so the board's whole input surface is `N` cells out of
`cols*rows`, and a generous cell is what stops a mis-tap turning a neighbour.

`card_height(available)` returns `available` and `card_centred()` returns
`true`: band 0 is square in a tall slot and leaves 344 of slack, band 2 leaves
28, and slack above a board reads as room where slack below it reads as a
mistake.

---

## 5. The generator

`puzzles/pinwheel_gen.gd`, seeded, deterministic in the `RandomNumberGenerator`
it is handed. Four stages.

**1. Grow the answer.** Partition the frame into `N` polyominoes of the band's
size multiset. Each piece seeds at the free cell with the **fewest free
orthogonal neighbours** (ties broken at random) and accretes at random. Seeding
into the tightest corner first is what keeps the last piece from being wedged
into a disconnected pair of holes; it is the same instinct as `quilt_gen.gd`'s
`_seeds`, arrived at for the same reason and measured to be worth it (without
it, grows wedge often enough to dominate the attempt count).

**2. Pin each piece.** For each piece, compute the in-frame orientation count
for every candidate pin cell and choose at random among the cells that maximise
it. Maximising is what keeps pieces movable; a pin chosen carelessly leaves a
piece with one orientation and a dead tap.

**3. Prove it unique.** Exact cover over the product of the per-piece
orientation sets, branching on "the first uncovered cell in scan order must be
covered by something", capped at two solutions. Require exactly one.

**4. Scramble, tidily.** Give every piece with more than one orientation a
random **non-solution** start. Score the result by how many taps it needs to
come home (`sum over pieces of (solution index − start index) mod m`) and by how
messy it looks (the count of stained cells, then the deepest stack). Keep the
tidiest scramble that still needs at least the band's `min_turns`, and reject
any whose deepest stack exceeds the band's `max_stack`.

### The bands

| band | frame | pieces | sizes | min turns | max stack |
|---|---|---|---|---|---|
| 0 | 5 x 5 | 9 | 1,2,2,3,3,3,4,4,3 | 8 | 2 |
| 1 | 5 x 7 | 11 | 1,2,2,3,3,3,4,4,4,5,4 | 14 | 3 |
| 2 | 6 x 8 | 13 | 2,2,3,3,3,4,4,4,5,5,5,4,4 | 20 | 3 |

Band 1's 5x7 with eleven pieces is the reference screenshot's own shape,
counted off it.

### Uniqueness is nearly free here, and `quilt_gen.gd` says the opposite

`puzzles/quilt_gen.gd` warns, in its header, that "a rotating patch would make
almost every region tileable a dozen ways and uniqueness would stop being worth
proving". **That warning does not apply to this board, and the reason is worth
writing down so nobody re-derives it.** Quilt's patches are free to *translate*:
a patch that could also rotate would have roughly `4 x cells` placements.
Pinwheel's pieces cannot translate at all — the pin fixes them — so a piece has
**at most four placements in the entire frame**, and usually fewer. Pinwheel is
therefore far *more* constrained than Quilt, not less.

Measured on a prototype of this exact algorithm (80 seeds a band):

| band | attempts to a unique board, median / max | min taps, median / range |
|---|---|---|
| 0 | 1 / 8 | 14 / 8–19 |
| 1 | 2 / 7 | 18 / 14–23 |
| 2 | 3 / 18 | 24 / 20–30 |

and zero seeds in 240 failed to produce a board.

**Generation cost, measured in GDScript on this Mac** (2026-09-20, a headless
probe over 24 seeds a band, `Time.get_ticks_usec()` round the whole of
`generate`, run twice and both runs quoted):

| band | mean (run 1 / run 2) | median | worst | attempts, median / max | taps, median / range |
|---|---|---|---|---|---|
| 0 | 3.10 / 4.07 ms | 2.28 / 4.23 | **6.65 / 6.85** | 2 / 8 | 13 / 10–18 |
| 1 | 3.01 / 3.21 ms | 2.84 / 3.09 | **3.93 / 4.01** | 1 / 4 | 17 / 14–22 |
| 2 | 5.04 / 5.46 ms | 4.60 / 4.93 | **8.66 / 9.12** | 3 / 12 | 23 / 20–29 |

Every one of the 72 seeds in each run came back proved unique, so no band ever
walked the `ATTEMPTS` fallback. The worst board in either run is **9.12 ms**
against the repo's 194 ms gate — two orders inside it, and the smallest
generation cost of any board in the game (Quilt's worst is 51.8 ms and Sudoku's
is about 200). The attempt counts and tap depths reproduce the prototype's
table above to within a board or two, which is a second, cheaper statement that
the port did not change the algorithm.

That comfort is the pin's doing and not the code's: a piece with at most four
placements in the entire frame makes the exact cover collapse almost
immediately, so the proof — the expensive stage on every other board that has
one — is the cheap stage here.

Unlike Sudoku there is **no wall-clock give-up and no `graded: false`**: the
attempt loop is bounded by `ATTEMPTS` and the honest flag, if a seed ever
exhausts it, is Quilt's `unique: false` on a board that is still playable
because the scramble is by construction reachable from a real tiling.

### Colouring the pieces

`Pal.CLOTH` holds eight cloths and band 2 has thirteen pieces, so colours
repeat. Two pieces that repeat a colour must never be able to be confused, or
the player sees one shape where there are two. The generator therefore **greedy
graph-colours** the pieces in descending degree, falling back to index order if
eight colours run out (which it must be *allowed* to do rather than loop
forever — a board with a colour clash is a blemish, a board that never
generates is a crash).

**What the edges are was rewritten during Task 1, because the rule this section
first asked for cannot be kept with eight colours.** That rule was "an edge
whenever one piece's orientations' cells are adjacent to or intersect the
other's", and a piece's reach is everything its four orientations sweep, so on
a 5x7 of eleven pieces nearly every pair reaches nearly every other: degrees of
10 out of 10 and 12 out of 12 were measured. Colouring 60 seeds a band
*exactly*, not greedily, that rule needs a ninth colour on 2 of 60 band-0
boards and 1 of 60 band-1 boards; a wider "within two cells" reading of it
needs one on 33 of 60 band-1 boards. Neither is a promise the board can make.

The rule the generator keeps instead is the strongest one eight cloths can
actually carry, and it was measured before it was written down: **two pieces
never share a cloth if they can ever overlap** (share a cell in any pair of
orientations) **or if they touch in the answer**. Those are the two ways the
colour would really mislead — a same-cloth stack is invisible, and the solved
frame is the picture being built — and that graph wanted at most **seven**
colours on all 180 boards measured. Plain greedy reached it on all of them, and
a 600-board sweep found **zero** clashes and never once walked the index-order
fallback. `tests/test_pinwheel_gen.gd` asserts exactly that pair of promises;
it does not assert the wider one, because the wider one is false.

---

## 6. The state class

`puzzles/pinwheel_state.gd`, scene-free, `extends RefCounted`, the only truth
about the rules. It is the island-free half the flat boards have kept since
Binairo.

```gdscript
var cols: int
var rows: int
var pins  := PackedInt32Array()   # per piece: the pin's cell index. Never changes.
var shapes: Array                 # per piece: Array[Array[Vector2i]], one entry an orientation,
                                  # in clockwise order, absolute board cells
var answer := PackedInt32Array()  # per piece: the orientation index that solves it
var start  := PackedInt32Array()  # per piece: the orientation it opened on
var cloth  := PackedInt32Array()  # per piece: its Pal.CLOTH index
var ok := true                    # whether the tiling was proved unique
var turned := PackedInt32Array()  # per piece: the orientation it is on now
var history: Array                # one entry a tap, newest last
var hints_used := 0
var cover := PackedInt32Array()   # derived: cell -> how many pieces sit on it. Rebuilt, never stored.
```

`cover` is **derived and never stored**, rebuilt by `recompute()` after every
change, exactly as Quilt's `cover` and Queens' `seen` are. That is what makes
undo keep no book for the stain: lifting a piece off a cell takes the stain with
it because the stain was never a fact, only an arithmetic.

Public surface:

```gdscript
func setup(rng: RandomNumberGenerator, difficulty: int) -> void
func idx(c: int, r: int) -> int
func cell_of(i: int) -> Vector2i
func piece_at_pin(c: int, r: int) -> int        # -1 when the cell is not a pin
func pieces_over(c: int, r: int) -> Array       # every piece whose current cells include it
func cells_of(p: int, orientation := -1) -> Array
func depth(c: int, r: int) -> int               # 0 bare, 1 covered, 2+ stained
func fixed(p: int) -> bool                      # one orientation: pinned fast
func turn(p: int) -> bool                       # false when the piece is pinned fast
func is_solved() -> bool
func hints_left() -> int
func hint() -> Dictionary                       # {"piece": int, "from": int, "to": int} or {}
func undo() -> Dictionary                       # {"piece": int, "from": int, "to": int} or {}
func reset() -> Array                           # the pieces that moved
func share_glyphs() -> String
```

**One tap is one history entry, and one undo is one tap.** `turn()` pushes
exactly one entry and a refused tap on a pinned-fast piece pushes none.
`hint()` walks a wrong piece all the way home and pushes **one** entry carrying
the whole journey, so undoing a hint costs one press however many quarter turns
it spent — the same decision Quilt made about a hint that displaces two patches.
`hints_used` is deliberately **not** refunded by undo, for the reason Quilt
records: a hint that has been seen has been spent.

`reset()` clears `history`, because reset is not a gesture and cannot be undone.

---

## 7. The board

`puzzles/pinwheel2d.gd`, `extends "res://core/puzzle_base.gd"`.

Everything is drawn — there is no node per piece. Pieces go into **one cached
`ArrayMesh`** through `ui/faces/patch_cloth.gd`, which is reused unchanged:
`Cloth.loops(cells)` traces a cell set into rounded loops and is entirely
shape-agnostic, so a rotated piece is just a different cell set. **Cache one
loop set per (piece, orientation)** at `build()` time — four entries a piece at
most — rather than tracing on the frame.

`_shown: Array` keeps every mesh the last `_draw` handed over alive until the
next one replaces it, because a canvas command holds a mesh by RID and not by
reference. Three meshes, in draw order:

1. **the frame** — the ground, its cell rules, and the stain;
2. **the still pieces** — every piece not currently swinging;
3. **the swinging piece** — drawn alone, under its own `Transform2D` about the
   pin, so it draws over its neighbours while it turns.

### The swing is the signature, and it is the first rotation in the game

`docs/art/flat-motion.md` has **no rotation row**. Every turn in the repo today
is either an idle (the sun's 40-second revolution, Untangle's knots) or
Hidden Word's flip, which is a scale on one axis and not a rotation at all.
Pinwheel's quarter turn is the first time a drawn piece rotates about a point,
so it needs **one** new thing in `core/motion.gd` and one new row in the doc:

```gdscript
const TURN_TIME := 0.26
## The angle a piece has swung through, `steps` quarter turns clockwise about
## its pin, `elapsed` seconds after the tap. Lands at the full angle at once
## under reduce motion.
static func turn_angle(elapsed: float, steps: int, time := TURN_TIME) -> float
```

It is a curve reader in the sense rule 8 means, reading `back_out` so the piece
overshoots a few degrees and settles — a pinwheel that stopped dead would read
as a snap. Its one number, `TURN_TIME`, goes in `core/motion.gd` and **not** in
the board, because a quarter turn is a thing the next board may want; the two
numbers that are Pinwheel's alone stay in the board.

The pinwheel hub spins with its piece and keeps spinning a moment past it,
reading the same `turn_angle` with a longer `time` — the blades carry the
overshoot the cloth does not.

### The stain settles in a wave

Queens' `_settle` in a fourth shape. Take a snapshot of `cover` before the turn,
call the state's mutator, then diff: every cell whose depth changed takes a
moment `t + king-move distance from the pin * Motion.WAVE_STEP`, and the stain
fades in or out from there. A cell that stops being stained does it from the pin
outwards; a cell that starts being stained does the same. The pin is the only
thing that moved, so it is the only sensible origin for the wave — and because
the moments are derived from a diff and not stored, a hint that walks a piece
through three quarter turns and the undo that walks it back both animate
correctly without either knowing which cells those were.

### Board constants

Only two are the board's own, and both are shape rather than timing:

```gdscript
const STAIN_ALPHA := 0.26   # the wash a second piece lays on a cell, per extra layer
const PIN_R := 0.19         # the pinwheel's radius, in cells
```

Everything else — the entrance, the press, the refusal shiver, the halo, the
solve hop, the stagger — comes from `core/motion.gd` unchanged.

### Refusal

A tap on a pinned-fast piece: `Motion.shiver_offset` on the piece, a
`Pal.BAD` halo stroked round its silhouette at `Motion.flash_level`, and the tip
card says *"That one is pinned fast."* **The cloth is never washed toward
`BAD`** — Quilt measured why, and CLAUDE.md records the general form: any board
whose pieces are coloured by index should expect it. `Pal.CLOTH` runs round the
wheel, so a rose wash turns the teal grey and the sage khaki, and a greyed piece
reads as disabled rather than as refused.

### Win

`flat_win()` returns `{"faces": [], "subtitle": "Every piece turned home."}` —
no cast, because this board seats no character, which puts it with Nonogram,
Sudoku, Bridges and Quilt. It does add one file to `ui/faces/`, and like
Quilt's that file is a **drawing and not a character**: `ui/faces/pin_wheel.gd`
is builder shapes, exactly as `mosaic_tile.gd` and `patch_cloth.gd` are, because
up to thirteen pinwheels batch into one mesh and a Control per pin would be a
node per pin of a thing with no face on it. That makes Pinwheel the **third**
board to earn a drawing rather than a character, after Nonogram's tile and
Quilt's cloth. The only face on the screen is the sprout on the tip card.

`win_delay()` is `Motion.REDUCED_TIME if Motion.reduce else WIN_WAIT`.

---

## 8. What has to be measured, not assumed

Written here so the implementation cannot quietly skip it. Every one of these
is a number this spec does not yet have.

1. **Generation cost in GDScript, per band**, worst seed of a calibrated sweep,
   against the 194 ms gate. The prototype's sub-millisecond JS reading is not a
   substitute.
2. **Draw calls**, with `tests/_shot_anim.gd -- pinwheel` at
   `--resolution 810x1440`, bare and played, against the 855 budget — plus a
   control board (Queens at 71, Word Trail at 65) run **in the same session**,
   because CLAUDE.md records this Mac's idle readings swinging by a factor of
   1.6 and a single reading off that harness being worth nothing.
3. **The phone's driver**: the same counts under
   `--rendering-driver opengl3_angle`, and the settled frames compared, to prove
   nothing has reintroduced an `instance uniform`.
4. **Reduce motion**: two frames 1.5 s apart, pixel-identical.
5. **The title and motto widths** against the 370 block (§3).
6. **The menu**: page one unchanged at 335, page two up from 140 by about one
   card's worth (Bridges and Quilt cost about 20 each).

---

## 9. Files

| file | what |
|---|---|
| `puzzles/pinwheel_gen.gd` | new — the seeded generator and the uniqueness proof |
| `puzzles/pinwheel_state.gd` | new — the scene-free rules |
| `puzzles/pinwheel2d.gd` | new — the drawn board |
| `ui/faces/pin_wheel.gd` | new — the pinwheel hub, builder shapes |
| `core/motion.gd` | `TURN_TIME` and `turn_angle()` |
| `docs/art/flat-motion.md` | a Turn row, and Pinwheel's line |
| `ui/registry.gd` | the seventeenth entry |
| `ui/menu/card_art.gd` | a `pinwheel` branch of `_draw`, and a `_pinwheel_mesh` field |
| `tests/test_pinwheel.gd` | the rules and generator suite |
| `tests/run_tests.gd` | register it |
| `tests/_win.gd` | a `_solve_pinwheel()` case |
| `tests/_shot_anim.gd` | a tap branch |
| `docs/brainstorm/concepts.html` | the playable mock |
| `CLAUDE.md` | the board's paragraph |

No existing board's file changes except the four shared ones above, and none of
those four changes behaviour for an existing board: `turn_angle` is additive,
the registry entry is appended, and the `card_art` branch is a new `match` arm.
