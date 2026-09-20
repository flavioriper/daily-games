# Rings — the sixteenth flat screen

**Date:** 2026-09-20
**Concept tab:** `docs/brainstorm/concepts.html#rings` (playable, plays a real generated deal)
**Reference:** `docs/art/concept-rings-ref.png` — the user's screenshot of a ring-sort game
**Status:** design approved in chat 2026-09-20; measurements in sections 4 and 8 are
real readings taken while the concept tab was built, and are marked where they are not.

---

## 0. What this is, and what it is called

Eight pegs stand in two rows. Twenty-four rings in six colours are dealt over them,
three to a peg. Lift the top ring off a peg and put it down on another — **only onto
an empty peg, or onto a ring of its own colour, and only if that peg has room**. The
board is done when every colour stands alone.

It is called **Rings**, in code, in a comment and on screen. The reference the user
supplied is a Portuguese build of a widely cloned genre (its own title is *Anéis*);
the genre is generic — hoops on pegs, water into bottles, balls into tubes — so there
is no name to avoid here the way there was with Wordle, Mastermind and LinkedIn's word
game. `Rings` is chosen because it is what the pieces are. The registry id is `rings`.

**What was read off the reference, pixel by pixel** (2026-09-20, sampling
`docs/art/concept-rings-ref.png` directly rather than judging by eye): six colours —
coral `#f06d65`, amber `#f5bc48`, cornflower `#7fa0e5`, tan `#d8b4a4`, pink `#ffacce`,
teal `#aee0e9` — **four rings of each**, over **eight pegs of three**. That is the
whole shape of the game: 24 rings in 32 slots, so every peg is exactly one slot short
of full and the two pegs' worth of slack is spread around instead of sitting in two
empty tubes. The count was verified colour by colour; all six come to exactly four.

Not taken from the reference: its white page and salmon header (this game is ink on
cream), its ad rail, its timer, and its exact hues — ours are the palette's own and
land within a few points of them anyway.

---

## 1. The screen, measured

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `RINGS` in ink with the leaf sprouting from it and `EVERY RING FINDS ITS PEG` under, then Undo, **Reset**, Hint with its count, Settings. Five buttons. |
| Day card | 120 | The shared row, unchanged. |
| Board card | **1340** | Two rows of pegs and the scenery band their height leaves. Section 5. |
| Tip card | 140 | The sprout, its line, the door to the rules sheet. |

40 of margin, 20 between rows: **1920 exactly**. The 1340 is not chosen — it is what
`ui/flat/flat_host.gd` hands back once the bottom slot is the tip card alone
(`140`), which is Word Trail's and Untangle's shape.

**Registry entry** (`ui/registry.gd`, appended to `PUZZLES`):

```gdscript
{
    "id": "rings",
    "kind": "puzzle",
    "title": "Rings",
    "blurb": "Gather every colour onto a peg of its own.",
    "short": "Sort the rings,\na colour a peg.",
    "motto": "Every ring finds its peg",
    "footer": "Lift · Drop · Sort",
    # It picks nothing up, so no tray; and it has no Check -- a solved board is
    # solved in plain sight and there is no wrong ring to find -- so no actions
    # row either, and Reset rides up into the top bar.
    "script": "res://puzzles/rings2d.gd",
    "shell": "flat",
    "tray": "none",
    "actions": false,
    "difficulties": [0, 1, 2],
},
```

`short`'s two lines are 15 characters each, inside the seventeen a 320-wide card fits.
`Rings` at GameWordmark 84 is far inside the five-button title block of 370, so
`_fit_title` never takes an override here; the motto `EVERY RING FINDS ITS PEG` is 24
characters and may be lettered down a point or two the way Balance's and Untangle's
are — that is the bar's own business and costs this board nothing.

**This board asks the host for nothing new.** No new optional on `PuzzleBase`, no new
tray class, no new chrome. `capabilities()` is `["undo", "hint"]`. `card_height()`
returns everything it is given and `card_centred()` is `false`, honestly so.

---

## 2. The rules, scene-free

`puzzles/rings_state.gd`, a `RefCounted`, is the one truth. The board is a view of it
and writes nothing of its own.

```gdscript
const CAP := 4

var colours := 6          # 4, 5 or 6 by band
var peg_count := 8        # colours + 2, always
var pegs: Array = []      # Array[Array[int]], bottom ring first
var deal: Array = []      # the dealt position, for reset_board()
var log: Array[Vector2i] = []   # completed moves, (from, to)
var held := -1            # the colour in hand, or -1
var held_from := -1       # the peg it came off, or -1
```

- **One move, two halves.** `lift(i)` takes the top ring off peg `i` into `held`;
  `drop(j)` puts it down. `put_back()` returns it to `held_from` and is not a move.
  A lift and its drop are **one entry in `log`**, so Undo is one tap for one move.
- **`can_lift(i)`** is false for an empty peg and false for a **locked** one (below).
- **`can_drop(j)`** is `pegs[j].size() < CAP and (pegs[j].is_empty() or pegs[j].back() == held)`.
  That single restriction is the whole puzzle; without it every deal solves itself.
- **A finished peg locks.** `locked(i)` is `pegs[i].size() == CAP` and all one colour.
  Nothing comes off a locked peg. This is safe to forbid rather than merely pointless:
  a full monochrome peg is already where that colour belongs and it has no free slot,
  so no solution can need to take rings off it. It also means a careless tap cannot
  undo work already done.
- **A refused drop costs nothing.** No move is spent, the ring stays in hand, and the
  tip card names which of the two rules it broke ("A ring only lands on its own
  colour." / "That peg is full.").
- **`is_solved()`** is every peg empty or full of one colour. There is no other
  ending: this board cannot run out the way Hidden Word can, and there is nothing to
  check.
- **`is_stuck()`** is "no legal move exists": two loops over the pegs, no solver.
  Section 7.
- **Everything the screen washes is derived** — which pegs are locked, which colours
  are home, whether anything can move — recomputed from `pegs` on every read. Queens'
  rule: an undo cannot leave a stale gold peg behind because there is no stored gold.

`undo()` pops `log`, moves the ring back the way it came (it was legal then, so no
check is needed), and clears `held` first if a ring is in hand. `reset_board()`
restores `deal` and empties `log`.

**Bands** (`build(rng, difficulty)`):

| Band | Colours | Pegs | Rings | Deal |
|---|---|---|---|---|
| 0 Easy | 4 | 6 | 16 | four pegs of 3, two of 2 |
| 1 Medium | 5 | 7 | 20 | six pegs of 3, one of 2 |
| 2 Hard | 6 | 8 | 24 | **eight pegs of 3** — the reference exactly |

Pegs are always `colours + 2`, so the slack is always eight slots. The deal is as even
as the arithmetic allows; only the hard band divides. Which pegs get the short stacks
is shuffled off the same seed.

---

## 3. The generator, and the proof

`puzzles/rings_gen.gd`, static, seeded from the day like every other board.

1. Fill a bag with `colours × CAP` ring colours, shuffle it with the day's `rng`.
2. Cut it into `peg_count` stacks of the sizes above, shuffled.
3. Reject a deal that is already solved.
4. **Prove it solvable** with the solver below. If it is not, advance the seed and
   deal again, up to `ATTEMPTS` 40 times.

### The solver

Depth-first over **canonical** positions. The pegs are interchangeable, so sorting
them before hashing collapses the entire symmetry group, and that is what makes this
tractable at all.

- **The key.** Encode a peg as `sum (colour + 1) << (3 * k)` over its rings — under
  4096, so it fits one character — sort the `peg_count` codes, and build a `String`
  of `char(code)`. Cheap to build, cheap to hash, and correct: two positions with the
  same key differ only by which peg is which.
- **The moves,** tried in this order, which is where the speed comes from:
  1. a move that **finishes** a peg (lands on a matching stack that becomes full),
  2. any other move onto a **matching colour**,
  3. a move onto an **empty** peg.
- **Three prunings:** a locked peg is never a source; a whole uniform peg is never
  moved onto an empty peg (that is the same position with the pegs renamed); and a
  position already in the visited set is not re-entered.
- **A node budget** (`NODE_BUDGET` 20000) rather than trust: past it the solver gives
  up and the deal is rejected, so a pathological day cannot hang `build()`.

`solve(pegs) -> Array[Vector2i]` returns **a** solution, not the shortest. That is
enough for both of its jobs: proving a deal, and answering `hint()`.

### Measured (JavaScript, this Mac, 2026-09-20)

200 seeds a band, through the concept tab's own copy of the algorithm:

| Band | Deals rejected | Worst search | Greedy solves it | Solution length |
|---|---|---|---|---|
| 0 — 4 colours, 6 pegs | **0 of 200** | 82 nodes, 0.4 ms | 6 of 200 (3%) | mean 22, 10–39 |
| 1 — 5 colours, 7 pegs | **0 of 200** | 126 nodes, 0.3 ms | 0 of 200 | mean 30, 15–49 |
| 2 — 6 colours, 8 pegs | **0 of 200** | 267 nodes, 0.6 ms | 0 of 200 | mean 38, 19–58 |

Two of those columns are the whole story. **Not one deal in six hundred was
unsolvable**, and a verdict cost under three hundred nodes — so the proof the
generator is built around is nearly free, and the risk this design was written to
flag is not there at two pegs' worth of slack. And **greedy solves it** is what says
the board is not trivial: a player who always takes the obvious move and never once
backtracks solves 3% of easy boards and none at all above that. The search is cheap
because it backtracks well, not because the game plays itself.

**The same probe at one peg less** — six colours on seven, half the slack — for the
record, because it is the obvious lever if the board ever feels too kind: rejection
goes to **85%** (still about a millisecond a deal, so the loop stays affordable) and a
careless player starts running out of moves entirely, 22% of the time. Not what ships.

### What the implementation still owes

The figures above are JavaScript. **GDScript is commonly thirty to eighty times
slower**, which puts the worst deal around 20–50 ms — inside a **300 ms** budget with
two orders of magnitude of headroom that Sudoku's generator never had. It is still
measured, not assumed: the implementation keeps the node budget, and a probe times
`build()` over a dozen seeds a band before the board is called done.

---

## 4. The board's own arithmetic

Inside the 1000-wide board card a **28 inset** leaves **944 by 1284**.

| Constant | Value | Why |
|---|---|---|
| `STATION_W` | 236 | four across close 944 exactly |
| `RING_W`, `RING_H` | 200 × 92 | the reference's own proportion to within a point |
| `RING_GAP` | 6 | the hairline between two stacked rings |
| `POST_W` | 30 | the pale post |
| `POST_UP` | 48 | how far the post stands proud of a **full** stack |
| `BASE_W`, `BASE_H` | 182 × 30 | the dish the post stands in |
| `STATION_H` | **464** | `BASE_H + (CAP × 98 − 6) + POST_UP` |
| `TOP_AIR` | 96 | **measured, not chosen** — see below |
| `MID_GAP` | 96 | between the two rows |
| band | 164 | `1284 − 96 − 464 − 96 − 464`, the scenery |

**`TOP_AIR` is the lift's, not a taste.** A lifted ring hovers `LIFT_H` above the top
of its post, so the top row needs `LIFT_H + RING_H/2` of air over it or a held ring
hangs out of the card. At 96 it clears the inset by ten pixels. This was found by
shooting the mock with a ring in hand, not by reading the code.

**Rows.** Four stations at the hard band, four and three at the medium one, three and
three at the easy one; a short row is centred, so a station is 236 wide and a ring is
200 whatever the band. The peg's slot `k` has its centre at
`ground − BASE_H − RING_H/2 − k × (RING_H + RING_GAP)`.

**The post is drawn only from above down to the top ring's centre**, so the hairline
between two rings shows the card and not the stick — which is what the reference does.
An empty peg's post runs all the way down to its dish.

**The thing a thumb aims at is the station, not the ring**: the whole 236 × 464 column
answers a tap, plus the lift's headroom above it. That makes it the largest touch
target in the game by a wide margin (Sudoku's cell is 100), and it has to be: a tap
here is not a placement, it is "this peg".

### The ring, drawn

A pill `RING_W × RING_H` with radius `RING_H/2` and a bottom rim in its own colour
mixed 22% toward ink; a white highlight at 26% off the upper-left shoulder; a flat
pale ellipse at the top centre where the post passes through, so a pill reads as a
ring; and the **pips**.

### The colours, and the pips

| Colour | Palette | Pips | The reference's |
|---|---|---|---|
| coral | `Pal.BERRY` `#e2645c` | 1 | `#f06d65` |
| amber | `Pal.SUN` `#f5a623` | 2 | `#f5bc48` |
| cornflower | `Pal.MOON_INK` `#7d8fd9` | 3 | `#7fa0e5` |
| tan | `Pal.ACORN` `#c99a63` | 4 | `#d8b4a4` |
| pink | `Pal.FLOWER` `#e58fb5` | 5 | `#ffacce` |
| teal | `Pal.ACCENT` `#4c9a94` | 6 | `#aee0e9` |

Bands take them in that order, so easy is coral, amber, cornflower, tan.

**Two new palette constants**: `ACCENT_DEEP` `#3a7a75` and `ACCENT_TILE` `#dfeceb`, the
two shades every other chip colour already has. Nothing else is added. The post is
`CHEEK` mixed 62% into `SURFACE`, its shade `CHEEK` 18% toward ink; the dish is
`SURFACE_HI` with a `LINE` rim.

**The pips are not decoration.** `core/palette.gd` says it in as many words about Code
Break's pegs — *"every peg also carries a pip mark, so colour never stands alone"* —
and a game whose whole mechanic is matching colour is the game that rule was written
for. One to six pips, embossed in the ring's own colour 30% toward ink at 70% alpha,
low on the face where the post's dimple is not.

---

## 5. The motion

**The signature is the arc and the settle.** A ring you lift rises off its post and
waits there breathing; a ring you put down *flies* across and the peg takes it with a
squash; and the instant a peg comes right, gold washes **down** its stack from the top
ring to the bottom.

| Moment | What happens |
|---|---|
| Entrance | The card pops in wide about its centre (`wide_pop_scale`, from 0.88) after `ENTER_DELAY`; the pegs drop in from `Motion.DROP` above, `Motion.ENTER_STAGGER` apart, so the board deals itself out peg by peg. |
| Lift | `back_out` to `LIFT_H` over the post top, then `BOB` 5 px on a `BOB_CYCLE` of 1.9 s, with a soft shadow under it. `Motion.lift` is the recipe; the bob is this board's. |
| Drop | `ARC_TIME` 0.34: x on a sine ease, y held near the lift height early and falling late (`lerp(hover, slot, u²)`) with a small `ARC_LIFT` 26 arch over the top, clamped so the ring never leaves the card. It lands with `Motion.squash`. |
| Put back | The ring settles back onto its own post. No flight, no log entry, no move counted. |
| Refused | The peg shivers (`shiver_offset`, 3 px, 0.2 s) and the tip card says which rule it was. The ring stays in hand. |
| **Peg comes home** | The wash: each ring of the stack flashes toward `SUN_RAY` in turn, `Motion.WAVE_STEP` apart from the top down, one `Fx2D.ring` and a handful of sparkles at the post. |
| Hint | A ring in `LEAF` over the peg it means, then it **plays the move** — lift, flight, landing, sparkles in leaf. |
| Undo | The last ring flies back the way it came, on the same arc. |
| Reset | The pegs drop back in as dealt, 0.03 apart, left to right. |
| Solved | Every peg hops in a wave on `Motion.SOLVE_HOP`/`SOLVE_TIME`/`SOLVE_STAGGER`/`SOLVE_DELAY`, then the win after `WIN_WAIT` 1.4 s. |

**Reduce motion:** the pegs are up at once, a lifted ring hangs still, a dropped ring
is simply on its new peg, nothing squashes, shivers, washes or sparkles, and the win
follows the last move (`win_delay()` returns `Motion.REDUCED_TIME`).

**Six constants are this board's own** — `LIFT_H` 40, `BOB` 5, `BOB_CYCLE` 1.9,
`ARC_TIME` 0.34, `ARC_LIFT` 26, `TOAST_HOLD` 2.6, plus the customary `WIN_WAIT` 1.4 —
and every other number above is a recipe or a curve reader off `core/motion.gd`. The
wash uses `Motion.WAVE_STEP`, which Queens wrote and Sudoku moved into the vocabulary;
the entrance, the reset and the solve use `Motion`'s own stagger, hop and delay.
**Nothing is added to the vocabulary.**
The board is drawn rather than built of nodes, so it reads `press_scale`,
`hop_lift`, `shiver_offset`, `bump_scale`, `drop_in_lift`, `wide_pop_scale` and
`flash_level` as curves, the way Light Up and Nonogram already do.

**One mesh, kept.** The pegs, dishes, rings at rest and the scenery band go into one
`ArrayMesh` rebuilt in `_draw` while anything is moving; the ring in hand and the ring
in flight are drawn over it. The board keeps the mesh its last `_draw` handed over
(`_shown`) until the next one replaces it — a canvas command holds a mesh by RID, and
a harness that calls `force_draw()` without that will photograph a freed one
(`CLAUDE.md`, the flat screens). `_animating()` must ask about **every** wave: the
entrance, the flight, the wash, the reset and the solve.

---

## 6. The win

`flat_win()` returns the day's colours as rings — `{"faces": [...], "subtitle": "Every
colour on a peg of its own."}` — drawn by a small inner class in `rings2d.gd` that
draws one ring with its pips. **Nothing is added to `ui/faces/`**: Rings joins
Nonogram, Hidden Word, Word Trail and Sudoku in adding no character at all, and the
only face on the screen is the shared sprout on the tip card and the win.

`share_glyphs()` is one row of coloured squares, one per colour gathered, in the order
they came home.

---

## 7. The one sentence this board needs and no other does

A ring sort is the first game on this grid you can play into a position with **no
legal move at all**. It is not a loss — Undo and Reset are one tap away — but a screen
that says nothing at that moment is a screen that looks broken. So: **a toast over the
board**, ink's dark pill, `TOAST_HOLD` 2.6 s, saying *"Nothing can move. Undo, or start
again."* Hidden Word's rule — a refusal is a toast and never a silence — spent on the
one thing worth it.

**Measured, and it changes what this is worth.** In **450 careless games** (a player
picking uniformly at random among the legal moves, 150 a band) the board ran out of
legal moves **not once**. At this slack there is nearly always something that can
move; a stuck position is constructible but you have to work at it. What that careless
player *did* hit is the other thing: a position still legal and already lost — **4% of
the time on easy, 9% on medium, 11% on hard**, usually inside the first ten moves.

**So the toast is a cheap guard for a rare case, and the thing that actually ends a
board is the thing this screen deliberately says nothing about.** That was the call:
the user was offered silence, a toast, and a solver that refuses any move which dooms
the board, and chose the toast. Refusing doomed moves was rejected with its reason —
every accepted move would then be a safe move, and tapping more or less at random
would solve the board. A position that is legal and lost stays the player's problem,
which is the puzzle.

---

## 8. What is measured, and what must be

**Already measured** (JavaScript, this Mac, 2026-09-20, in building the concept tab):
the rejection rate (0 of 600), the search cost (≤ 267 nodes, ≤ 0.6 ms), the greedy
solve rate (0–3%), the careless-doom rate (4/9/11%), the careless-stuck rate (0 of
450), and solution lengths (mean 22/30/38).

**Owed by the implementation, before the board is called done:**

1. `build()` timed in GDScript over a dozen seeds a band, against a **300 ms** gate.
2. Draw calls with `tests/_shot_anim.gd -- rings` at **`--resolution 810x1440`** — the
   flag goes **before** `--script`, never after (`CLAUDE.md`). Against the 855 budget;
   this board draws 24 rings, 8 posts and a band, so it should sit low.
3. Two sequential idle readings, never one: a single reading off that harness is worth
   nothing, and a control board measured in the same hour is what makes a number
   quotable.
4. A frame on the phone's driver (`--rendering-driver opengl3_angle`) compared to the
   default, to show nothing has reintroduced an `instance uniform`.
5. `tests/_win.gd` drives it to a win ten times out of ten.

---

## 9. The files

| File | What |
|---|---|
| `puzzles/rings_state.gd` | new — the rules, scene-free |
| `puzzles/rings_gen.gd` | new — the deal and the solver |
| `puzzles/rings2d.gd` | new — the board |
| `tests/test_rings.gd` | new — the state and the generator |
| `ui/registry.gd` | one entry appended to `PUZZLES` |
| `ui/menu/card_art.gd` | one `_build` branch: three little pegs in the 320×118 box, one full, two part-sorted, drawn with the board's own ring builder scaled down. No furniture branch in `_draw`. |
| `core/palette.gd` | `ACCENT_DEEP`, `ACCENT_TILE` |
| `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/run_tests.gd` | the three harness lists |
| `CLAUDE.md` | the record, once it is measured |

**It is the sixteenth card**, so it stands on page two of the pager with Mushroom
Patch, Sudoku and whatever else lands first. Page one is untouched and its 335 draw
calls are unaffected — which is the whole point of paging rather than reflowing.

**Another board is being built in parallel** (`.claude/worktrees/bridges`, and a
`fairy-lights` worktree beside it), and all three touch the same five files: the
registry, `card_art.gd`, and the three harness lists. The record says these branches
merge clean but broken. So: merge `main` in before finishing, and reconcile the
registry order, the card-art branches, the harness lists and `CLAUDE.md`'s card count
by hand rather than trusting a clean `git merge`.

---

## 10. Open questions, for the phone

- **Tap-tap, not drag.** Lift with one tap, drop with another — steadier on a phone
  than dragging a ring between pegs, and what the reference does too. Watch whether a
  hand expects to drag.
- **The locked peg.** Kind and safe, and it also removes a move you might want to make
  for the fun of it.
- **Six colours at once** is the most colour this game has put on one screen. The pips
  make them countable; the easy band's four is the control.
- **Three hints, where a hint plays a whole move.** A much bigger gift than a hint is
  on Sudoku. Two may be right.
- **An 11% chance a careless hard board is already lost**, with nothing saying so.
  The levers, in order, are a peg less at the hard band (section 3's second probe), a
  solver-vetted refusal (already rejected), or leaving it alone because Undo is
  unlimited and a lost board costs only the taps to walk back out of it.
