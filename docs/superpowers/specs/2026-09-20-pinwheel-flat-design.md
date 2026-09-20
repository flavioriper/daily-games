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

### The title, and the reading that settled it

`Pinwheel` is eight characters in Fredoka 700 at GameWordmark's 84 against a
370 block. `Word Trail` measures 391 against the same block and is lettered
down to 79; `Pinwheel` is shorter but carries a `w` and an `h`, so it was an
open question rather than an assumption. **Measured against the real face on
the real screen** (§8): the title comes to **338** and keeps its 84, and the
motto to **272** and keeps its 24. Neither is lettered down, which makes this
the first five-button board whose motto is not — all four before it are
(Balance 399 → 21, Untangle 397 → 22, Word Trail 406 → 21, Quilt 380 → 23),
and a motto written short on purpose is what bought it.

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

**Generation cost, measured in GDScript on this Mac** (retaken 2026-09-20 once
the colouring began rejecting boards — see "Colouring the pieces" below. A
headless probe over 24 seeds a band, `Time.get_ticks_usec()` round the whole of
`generate`, four runs across two sessions and every run quoted):

| band | mean, four runs | median | worst | attempts, median / max | taps, median / range |
|---|---|---|---|---|---|
| 0 | 3.57 / 3.59 / 3.95 / 3.96 ms | 2.44–3.28 | **9.04–9.96** | 2 / 9 | 14 / 9–18 |
| 1 | 3.10 / 3.12 / 3.29 / 3.34 ms | 2.92–3.21 | **4.61–4.90** | 2 / 6 | 18 / 14–24 |
| 2 | 4.92 / 4.99 / 5.21 / 7.39 ms | 4.59–6.08 | **7.67–16.42** | 3 / 9 | 23 / 20–33 |

Four runs rather than two because **the first session was under load and its
numbers are useless on their own**: it timed the *unchanged* band-0 generator
at 4.14 ms in one run and 9.31 ms in the next, a factor of 2.3 on identical
code. The second session is the quiet one, its two runs agree to within two
percent, and every figure below that compares before with after is taken from
inside it. This is the same caution `CLAUDE.md` records for the render
harnesses, and it applies to a headless clock too: a single reading is worth
nothing.

**What the rejections cost, before against after, on the same 24 seeds in the
quiet session:** band 0 3.56/3.55 → 3.59/3.57 ms and band 1 3.06/3.08 →
3.12/3.10 ms, which is inside the noise; band 2 4.54/4.54 → 4.92/4.99 ms,
about **nine percent**. That agrees with the grow counts taken separately over
300 seeds a band (1125 → 1257 grows on band 2, +11.7%), which is two
measurements of the same thing by different routes.

Every one of the 24 seeds in every run came back proved unique, so no band ever
walked the `ATTEMPTS` fallback. The worst board in the quiet session is
**9.08 ms** and the worst seen at all, in the loaded one, is **16.42 ms** —
against the repo's 194 ms gate, two orders inside it either way, and still the
smallest generation cost of any board in the game (Quilt's worst is 51.8 ms and
Sudoku's is about 200). The attempt counts and tap depths reproduce the
prototype's table above to within a board or two, which is a second, cheaper
statement that the port did not change the algorithm.

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
the player sees one shape where there are two.

**The edge is the honest reading of “these two can ever meet”:** the union of
one piece’s orientations’ cells, **dilated by one orthogonal step**, meeting
the union of the other’s. It is symmetric, it covers overlapping as well as
touching, and — the whole point — it holds in *every* state the board can be
in rather than in one of them. The generator greedy-colours that graph in
descending degree.

**A board eight cloths cannot colour is thrown away and another is grown.**
There is no `p % CLOTHS` fallback on the playable path any more: the moment
greedy would want a ninth cloth, `_colour` hands back an empty array and
`generate()`’s loop moves to the next attempt exactly as it does for a failed
proof or a failed scramble. Rejection is affordable here only because
generation is — a board is a few milliseconds — and that is the entire
argument. Measured over 300 seeds a band, it throws away **2, 6 and 31** proved
boards, which costs **3, 17 and 132** extra grows out of 619, 721 and 1125: a
rejected board costs a whole fresh grow-and-prove cycle rather than one grow,
which is why band 2’s bill is twelve percent where its rejection rate is ten.
The one `p % CLOTHS` left is in the total-failure dictionary, the `cols == 0`
one, which has no pieces to mis-colour and nothing playable to spoil.

#### The narrow rule that shipped first, and the lesson it left

**A narrower rule was measured, written down and shipped before this one, and
it was measured against the wrong frame.** It is recorded here rather than
deleted, because the reason it failed travels further than the rule that
replaced it.

Task 1 tried the rule above, found that eight cloths cannot always colour it
— exact colouring, not greedy, of 60 seeds a band needed a ninth on 2 of 60
band-0 boards and 1 of 60 band-1 boards — and concluded that it was “not a
promise the board can make”. So it weakened the promise to the strongest thing
eight cloths could keep without ever rejecting anything: **two pieces never
share a cloth if they can ever overlap, or if they touch *in the answer*.**
That graph wanted at most seven colours on all 180 boards measured, greedy
reached it every time, and a 600-board sweep found zero clashes.

Every one of those measurements was true. The promise was about the wrong
state. **The answer is the frame the player sees last and least**; the opening
is what is on the screen when the board is handed over and for as long as it
takes to solve. Measured over 300 seeds a band, the shipped rule left a
same-cloth pair **orthogonally touching in the opening state** on **149, 219
and 241 boards of 300** — independently re-measured at 145, 214 and 233 on a
different seed block. Two apricot pieces edge to edge read as one shape, which
is exactly what the colouring exists to prevent, and it was happening on most
boards.

**The lesson is not the rule. A legibility rule measured against the solved
frame is measured against the state the player spends the least time looking
at.** Any board that colours, shades or outlines its pieces to keep them apart
should check that rule against the *opening*, and against whatever the player
stares at in between — the solved frame is the cheapest state to reason about
and the least important one to get right.

The fix was not to weaken the rule further but to keep the wide one and
**reject the boards it cannot colour**, which Task 1 never weighed because it
was looking for a colouring that always succeeds rather than a generator that
can afford to be picky. The “within two cells” reading, which an early test
asked for, is still out of reach and has not been retried: exact colouring
needed a ninth colour on 33 of 60 band-1 boards, and rejecting a board in two
would not be picky, it would be a different generator.

Under the widened rule, all 900 boards of the 300-a-band sweep came back with
**zero** same-cloth pairs touching or stacked in the opening state and zero in
the answer. `tests/test_pinwheel_gen.gd` asserts both states over 40 seeds a
band, and also re-derives the conflict graph and checks the colouring is
proper, which is what says the fallback was never walked on a real board. Run
against the *old* colouring, that test fails on 18, 24 and 31 of its 40 boards
a band, so it bites.

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
func cells_of(p: int, orientation := -1) -> Array   # a fresh copy; the caller may keep it
func pin_cell(p: int) -> Vector2i               # cached in setup, because the board asks every frame
func depth(c: int, r: int) -> int               # 0 bare, 1 covered, 2+ stained
func fixed(p: int) -> bool                      # one orientation: pinned fast
func steps_home(p: int) -> int                  # posmod(answer - turned, orientations)
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

**A hint spends itself on the piece furthest from home** (the largest
`steps_home`, strictly greater than zero). A hint that turned the piece already
one quarter from its answer would be worth less than the tap it saved, and a
board with three of them cannot afford a cheap one.

**`ok` is currently always true for any board that exists**, and nothing in the
UI may be built on the assumption that an unproved board will arrive.
`generate()` only returns a board — the chosen one or its fallback — after the
proof has passed, so `unique: false` ships only with the total-failure
dictionary, which also carries `cols == 0`. `hint()` deliberately does not test
`ok` anyway, the way Quilt's does not: the stored answer is a tiling whatever
the proof said, and the check would silently start mattering if the generator
ever grew a fallback that skipped the proof.

**The share glyphs looked one short and are not.** The first count was eight
cloths plus bare plus stained against Unicode's nine squares, which is one too
many, and cloth indices 4 and 7 shipped sharing `🟪`. That count is wrong:
**a share is only ever taken from a solved frame**, where by definition no cell
is bare and none is stained. The nine glyphs are therefore eight cloths with
one to spare, not ten states in nine slots. Each cloth now has its own square
and bare and stained share the leftover `⬛`, which costs nothing because a
share carrying either cannot happen. Worth keeping because the mistake is the
interesting part: **the constraint was counted over every state the board can
be in, when the only state the share is ever taken from is the one that
excludes two of them.**

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

## 8. What was measured

Every figure here was taken on this Mac on 2026-09-20, after the board was
live on the menu, in **one sitting and one windowed run at a time** — the rule
the repo has already paid for twice. The strip harness is
`tests/_shot_anim.gd -- pinwheel` at `--resolution 810x1440`, with the
resolution flag **before** `--script`, and the win harness is `tests/_win.gd`,
run windowed because headless it silently reports 0/0.

### The session, and what it is worth

A single reading off `_shot_anim.gd` is worth nothing — CLAUDE.md records this
Mac's idle swinging by a factor of 1.6 on identical code — so Queens and Word
Trail were run as controls at **both ends** of the session, everything was read
twice, and every reading is quoted below including the ones that disagree.

| run | draw calls | idle mean |
|---|---|---|
| **Queens** (control), opening and closing the session | **71 / 71** | 2.89 / 2.83 ms |
| **Word Trail** (control), opening and closing the session | **65 / 65** | 2.42 / 2.38 ms |
| `pinwheel`, one piece turned and its stain settled | **59 / 59** | 2.65 / 2.62 ms |
| `pinwheel empty`, the bare opening board | **60 / 59** | 2.14 / 2.52 ms |
| `pinwheel rm`, reduce motion | **59 / 59** | 2.53 / 2.55 ms |
| `pinwheel` on `--rendering-driver opengl3_angle` | **59 / 59** | 4.10 / 4.20 ms |

Both controls reproduced their recorded counts exactly, at the start and again
at the end, so the counts in this table can be quoted. **The milliseconds
cannot be quoted outside it**: this was a fast session — Queens read 2.83–2.89
against the 3.83 recorded in its own spec and the 3.45/3.49 of Quilt's
session — so Pinwheel's 2.6 ms means "beside Word Trail's 2.4 and Queens' 2.86
in the same hour" and nothing more. The ANGLE run's 4.1–4.2 ms is that driver
being slower on *this* Mac; no claim about a phone can be read off it.

**59 draw calls against the 855 budget**, which makes Pinwheel the
second-cheapest board the repo has measured, a call behind Quilt's 58 and a
little over half of Hidden Word's 110. Three meshes and no Controls is what
buys that, and it is also why **a turn costs nothing measurable**: a piece
swinging over its neighbours, the stain arriving on the cells it has doubled
up on and eleven pinwheels standing on the frame are all inside the same three
meshes as the bare board, so the played board does not draw more than the
opening one.

The one reading in the table that disagrees with itself is the bare board's
**60 then 59**, against a played board that read 59 twice — a bare board
cannot cost more than a played one, so the ±1 is the frame the window happened
to catch. The likely cause, **inferred and not measured**, is the shared
wordmark's sun-dot: CLAUDE.md records a rayed sun costing the header one draw
call over a still one when it glints, and it glints on its own clock. The
reduce-motion runs are what point at it — with the glint stilled the count is
a flat 59 twice — but nothing here was run with the glint disabled, so this is
an inference from three readings and not a measurement.

### Reduce motion

**Pixel-identical, twice.** The two frames 1.5 s apart (shots 7 and 8 of a
`pinwheel rm` run) differ in **zero** pixels of 810 x 1440, in both runs — not
a small number, an empty difference image, because reduce motion stills the
wordmark's glint along with the board.

The played run says the other half of the same thing: its shots at 2.8 s and
3.8 s differ **only** in a 22 x 22 box at (169, 55)–(191, 77), which is the
sun-dot, worst 153/255 there and nothing anywhere else. The board itself is
still by 2.8 s, so the idle window that produced the numbers above was
measuring an idle board — which is exactly what the extra shots and the later
`_idle_from` of 2.6 s were added for: the swing is over in `TURN_TIME` 0.26,
but the stain fans out of the pin for another `_wave_span` (0.515 s on band 1)
after the piece has landed.

### The phone's driver

ANGLE agrees on **59**, twice. Comparing the settled frames, 110,002 pixels of
1,166,400 differ and **not one of them by more than 1/255** — worst 1 overall
and worst 1 below the header. That is paper-wash and gradient rounding spread
thinly over the whole page, with nothing structural anywhere: no silhouette
moved, no cut staircased, nothing has reintroduced an `instance uniform`. It
is the tightest agreement between the two drivers any board in the repo has
recorded.

### The title and the motto

Measured with a throwaway probe that opened the real screen and read
`Font.get_string_size` off the rendered face, against the block the bar
actually lays out. The block is **370.0** with five buttons, as §3 said it
would be.

| board | title at 84 | motto at 24 | fitted |
|---|---|---|---|
| **Pinwheel** | **338** | **272** | **neither is lettered down** |
| Balance | 306 | 399 | motto 24 → 21 |
| Untangle | 351 | 397 | motto 24 → 22 |
| Word Trail | 391 | 406 | title 84 → 79, motto 24 → 21 |
| Quilt | 190 | 380 | motto 24 → 23 |

So §3's estimate holds, and it is now a reading: `Pinwheel` fits at 84 with 32
px to spare and `TURN IT TILL IT FITS` fits at 24 with 98. **Pinwheel is the
first five-button board whose motto is not lettered down** — all four before it
are, which is what §3's "short on purpose" was aiming at. Two by-products worth
keeping: Quilt's motto is fitted 24 → 23 and that was nowhere on the record,
because CLAUDE.md's `_fit_title` probe of 2026-09-20 predates Quilt; and Word
Trail's title measures 391 here against the 392 on the record, because the
string the label actually renders is `Word Traıl` — `ui/sun_dot.gd` has already
swapped the i for Fredoka's dotless `ı` by the time the bar measures it. The
probe reproduced Word Trail's 79 and Mushroom Patch's 65 exactly, which is what
says it was reading the real Fredoka and not a fallback face.

### The menu

Taken at the card (Task 5), twice, at the same resolution: **page one
unchanged at 335** and **page two 150** with five cards, up from the 140 it
read with four. Pinwheel stands on page two and costs page one nothing, which
is the point of paging rather than reflowing — the third board in three days to
be added without displacing one, and the second to land on a pager that was
already there.

### Generation, and the win path

Generation cost is measured per band in §5 and not repeated here: worst board
**9.08 ms** in the quiet session and **16.42 ms** in the loaded one, against
the repo's 194 ms gate, the smallest generation cost of any board in the game.

`tests/_win.gd` drives the board the way a thumb would — a real hint off the
HUD, then every piece turned home by touching its own pinwheel, with the
pinned-fast pieces skipped because tapping one is the board's refusal rather
than its move. It comes back **17/17 winnable** with Pinwheel reading
`5x7 frame, 11 pieces, 16 taps, hints=1, board fit=true, hud=true`, so the pin
maths, the cell the finger lands on and the win condition are all proved
through the input layer rather than by poking the state.

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
