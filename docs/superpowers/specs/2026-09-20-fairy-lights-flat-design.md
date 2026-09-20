# Fairy Lights, flat: the fifteenth screen

A garden strung with wire. A lantern post stands in the middle cell and every
other cell of the grid holds one length of garden wire -- a straight, an
elbow, a tee, a cross, or a paper lantern on a stub. **One tap turns a piece a
quarter turn clockwise**, and that is the only gesture on the screen. Wire
joined all the way back to the post runs warm and gold; everything else is
pale and cool, and the light washes outward one step at a time whenever a turn
changes what is reachable. Done when every stub meets a stub and every lantern
is lit.

The game is **Netwalk**, a rotate-the-pipes puzzle that has been in general
circulation for decades -- Simon Tatham's Portable Puzzle Collection ships it
as *Net* -- with no company owning it the way the New York Times owns Wordle
or LinkedIn owns Queens. This repo has renamed a game it did not invent three
times for that reason (Code Break, Hidden Word, Word Trail) and this is **not**
a fourth such case: the rename here is a dressing, not a precaution. The
user's reference is a screenshot of another phone app's version of it, saved
as `docs/art/concept-fairy-lights-ref.png`; nothing is taken from it but the
mechanic.

- Mock, playable and the reference for every number here:
  `docs/brainstorm/concepts.html#fairylights`.
- Reference screenshot: `docs/art/concept-fairy-lights-ref.png`.
- Decided with the user on 2026-09-20 before a line was written: the garden
  dressing over the bare wires-and-plug of the reference; the ladder 5x5 /
  6x6 / 7x7; and the strongest generator promise, **no guess is ever needed**.

Everything in this spec was ported from the mock, which runs the real
generator and the real solver. Where a figure was measured, it says over how
many samples and on what.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/fairy_lights_gen.gd` | The day's garden: a spanning tree, the propagate-only solver, the scramble. Scene-free. |
| `puzzles/fairy_lights_state.gd` | The rules: masks, turning, live, solved, undo, hint, reset. Scene-free. |
| `puzzles/fairy_lights2d.gd` | The board: one mesh, the lanterns, the gestures, the wash. |
| `tests/test_fairy_lights.gd` | The generator's promise and the state's moves. |
| `ui/registry.gd` | One entry, the fifteenth card. |
| `ui/menu/card_art.gd` | One `_build` branch and one `_draw` branch. |
| `tests/run_tests.gd`, `tests/_win.gd`, `tests/_shot_anim.gd` | Suite entry, win-harness solver, animation strip. |
| `docs/art/flat-motion.md`, `CLAUDE.md` | The record. |

Nothing is added to `ui/faces/` and nothing is added to `core/palette.gd` --
see sections 5 and 6. `core/motion.gd` gains nothing.

**Every file in the right-hand half of that table is also being edited on
`feat/bridges`**, which is running in parallel in another worktree. Merge main
into this branch and reconcile by hand before merging out; the recorded
failure mode is two board branches merging *clean* and still landing broken.

---

## 2. The screen, measured

| Row | Height | What is in it |
| --- | --- | --- |
| Top bar | 180 | Back, `Fairy Lights` in ink with the leaf, `WAKE EVERY LANTERN` under it, then Undo, Reset, Hint with its count, Settings. |
| Day card | 120 | The family's, unchanged. |
| Board slot | 1340 | The card is cut to the grid; the rest is air, halved above and below. |
| Tip card | 140 | The sprout, its line, and the door to the rules sheet. |

40 of margin, three 20 gaps and those four rows are 1920 exactly, which is
where 1340 comes from -- the same sum Word Trail's board card gets, because
the two screens ask the host for the same rows.

**The title is lettered smaller, and it is the title and not the motto.**
`Fairy Lights` measures **452** at GameWordmark 84 against the five-button
block of **370**, so `ui/flat/flat_top_bar.gd`'s `_fit_title` steps it to
**68** (rendered face 366). `WAKE EVERY LANTERN` measures **309** at FlatMotto
24 and is untouched, which makes this **the first five-button board whose
motto fits** -- Balance's 399, Untangle's and Word Trail's 406 all come down.
Measured headless on this Mac on 2026-09-20 with the real Fredoka; the same
probe reproduced Word Trail's 392, Hidden Word's 482 and Mushroom Patch's 635
to the pixel. A probe run without `godot --headless --path . --import` first
falls back to the engine font and gives wrong widths -- it read `Word Trail`
at 420 -- so import before measuring.

### 2.1 Inside the board card: the cells abut

**There is no gap between cells, and this is the one flat board where that is
not a style choice.** A wire has to cross the cell boundary and meet the wire
on the other side; the 14-pixel alley Word Trail and Nonogram draw between
tiles would put a break in the middle of every join and the board would read
as broken everywhere. So the cell is a round `(1000 - 2*28) / n = 944 / n`
with nothing subtracted, floored.

| Band | Grid | Cell | Card height | Air, halved | Lanterns, typically |
| --- | --- | --- | --- | --- | --- |
| Easy | 5x5 | 188 | 996 | 172 each | 9 of 25 (37.9% mean) |
| Medium | 6x6 | 157 | 998 | 171 each | 13 of 36 (36.0%) |
| Hard | 7x7 | 134 | 994 | 173 each | 17 of 49 (35.2%) |

188 is the largest cell any flat board has asked for, and 134 is comfortably
the largest hard cell -- Word Trail's 123 held that, and Queens, Nonogram and
Sudoku are at 103, 103 and 100. The reason is Word Trail's: seven columns is
fewer than nine and the width binds long before the height does.
`card_height()` returns the grid plus its two 28 insets, `card_centred()`
answers `true`, and the 344 the card does not want is halved into air above
and below -- Tents' and Queens' arrangement, not a new one.

**The alternative, named so it is not lost:** spend that 344 on a scenery band
at the card's foot, the way Word Trail spends 222-250. It is not drawn,
because a strung grid of wire is a single object and a band under it reads as
a second one -- but it is the first thing to change if the screen reads bare
on the phone.

---

## 3. The rules

1. **Every cell holds a piece, and the pieces are a tree.** The wiring is a
   spanning tree over the whole grid rooted at the post, so there is no empty
   cell, no wall and no loop, and a cell's piece is nothing but its degree in
   that tree: 1 is a paper lantern on a stub, 2 is a straight or an elbow, 3
   is a tee, 4 is a cross. The post cell draws the post and carries whatever
   arms its degree gives it.
2. **One tap, one quarter turn, clockwise.** No counter-clockwise tap, no long
   press, no lock, no drag. Four taps bring a piece back where it started.
3. **A cross refuses.** It is already every way round, so tapping it shivers
   the cell and the sprout says so rather than pretending to turn. Hidden
   Word's rule: a refusal is a toast and never a silence.
4. **Live is derived and never stored** -- a breadth-first walk from the post
   over edges where both sides carry a stub, recomputed after every turn.
   Queens' rule, and it is what makes Undo free: there is no highlight to put
   back.
5. **A loose end looks loose.** A stub that meets a stub runs to the cell's
   edge and joins; a stub that meets a wall or a closed neighbour stops short
   with a rounded end. Every unfinished join is therefore visible without
   counting.
6. **Solved is the rule, not the answer**: every stub meets a stub *and* every
   cell is live. Nothing anywhere compares the board against the stored
   solution to decide whether it is finished.
7. **Nothing can be lost and nothing can be wrong.** There is no Check,
   because a board is unfinished or it is done.

On a board that passed section 4 the second half of rule 6 is already implied
by the first, and it is worth knowing why rather than discovering it later:
"every stub meets a stub" is exactly the constraint the propagate-only solver
works in, and that solver came back with one candidate per cell, so there is
only one fully-matched arrangement of the whole grid and it is the
generator's. The "and every cell is live" clause is kept anyway for two
reasons -- it is what the player is actually looking at, and it still holds on
the fallback board of section 4.4, where uniqueness was never proved.

### 3.1 The representation

A cell is **a four-bit mask of open sides**, N=1, E=2, S=4, W=8. A clockwise
quarter turn is `((m << 1) | (m >> 3)) & 15`, which is the whole of the turn.
Distinct rotations follow from the mask alone: a stub `0001` has four, an
elbow `0011` four, a tee `0111` four, a straight `0101` **two**, a cross
`1111` **one**. Two `PackedInt32Array`s -- what is on the board and what the
generator meant -- plus the dealt masks for Reset, and that is the state.

---

## 4. The generator, and the promise

The user chose the strongest promise available: **no guess is ever needed**.
That is not a property of the scramble -- a scramble hides the answer, it
cannot make the board harder to deduce -- it is a property of **the tree's
shape**, so it is tested before anything is scrambled and a tree that fails is
thrown away whole.

1. **Grow a spanning tree over every cell**, rooted at the post, with
   randomised Prim off the day's seed. (On an even-sided grid the post is one
   of the four middle cells, from the same seed.)
2. **Run the propagate-only solver.** Each cell starts with the distinct
   rotations of its own shape as candidates. An edge to off-grid is closed, so
   any candidate pointing into the wall is struck out. Whenever every
   remaining candidate of a cell agrees about an edge, that edge is proven
   open or closed and the neighbour's candidates are filtered to match.
   Iterate to a fixpoint.
3. **One candidate per cell means guess-free**, and that candidate is the
   answer, because the answer was in the set to begin with and filtering only
   removes what cannot be. Any cell still holding two: re-roll the tree.
4. **Then scramble**, and only then. Every non-cross piece takes a random
   rotation. Two conditions on the deal, each re-rolled rather than shipped:
   at least **60%** of the turnable pieces out of place, and **no more than
   25% of cells live**. The second is new in this spec and the mock predates
   it -- see 4.5.

### 4.1 The solver is deliberately weaker than a good player

It never reasons "that would make a loop" or "that would strand a corner",
which a human does constantly. Weaker is the point: a board this solver can
finish is a board nobody has to guess on, with room to spare.

### 4.2 How the tree is grown is the whole cost of the promise

Measured over **20,000 trees a band**, the fraction the solver could not
finish:

| Tree | 5x5 | 6x6 | 7x7 | Lanterns |
| --- | --- | --- | --- | --- |
| Randomised DFS | 0.00% | 0.35% | 0.74% | 13.6-17.1% of cells |
| Randomised Prim | 18.64% | 23.95% | 30.95% | 35.2-37.9% |

A depth-first tree is almost always guess-free first try -- it grows long
corridors, a corridor is straights, and a straight has only two rotations to
begin with. It is also a snake of wire with a dozen lights on it, which is not
a garden of fairy lights. Prim branches, which is where the lanterns, the tees
and the crosses come from, and it costs a re-roll about a quarter of the time.
**Prim, and pay the re-rolls, is the call.**

### 4.3 What the re-rolls cost, read twice

With the full acceptance test -- guess-free, at least 22% of cells as
lanterns, and a post with at least two arms -- over **2,000 seeds a band**:

| Band | Mean | Median | p90 | p99 | Worst | Gave up |
| --- | --- | --- | --- | --- | --- | --- |
| Easy 5x5 | 1.27 | 1 | 2 | 4 | 6 | none |
| Medium 6x6 | 1.36 | 1 | 2 | 4 | 6 | none |
| Hard 7x7 | 1.48 | 1 | 3 | 5 | 8 | none |

A second, independent reading off the shipped mock's own caption over 400
seeds a band came back at **1.28 / 1.31 / 1.44** mean, median 1, worst 5 at
every band. Two probes, the same answer; neither is to be quoted without the
other.

**Guess-free trees are not rare at 7x7**, which was the open risk when this
board was started, and it is recorded here plainly because it did not
materialise. The whole build including re-rolls costs **0.053 / 0.059 /
0.093 ms in JavaScript** on this Mac, against Sudoku's 9 ms for its generator
in the same place.

**What stood here before this table was an estimate and never a
measurement**: the GDScript cost was scaled off the JavaScript figure above
by a guessed factor of about seven, because no port existed yet to time. It
is gone, and the reading below replaces it.

**The GDScript reading is now real, and it is the third reading of this
generator.** `tests/_probe_fairy_gen.gd` over **200 seeds a band**, run twice
on 2026-09-20, both readings quoted because one off this Mac is worth
nothing:

| Band | Attempts mean | Attempts worst | `build()` mean | `build()` worst | Proved |
| --- | --- | --- | --- | --- | --- |
| Easy 5x5 | 1.170 | 3 | 0.411 / 0.411 ms | 1.051 / 1.054 ms | 200/200 |
| Medium 6x6 | 1.320 | 5 | 0.680 / 0.711 ms | 2.792 / 2.888 ms | 200/200 |
| Hard 7x7 | 1.445 | 4 | 1.117 / 1.120 ms | 3.416 / 3.489 ms | 200/200 |

The attempt counts are identical between the two runs, because the seeds are
the seeds; only the clock moved, and it moved by under 5%. **The worst whole
build measured in GDScript is 3.5 ms at 7x7**, which is roughly twelve times
the JavaScript mean rather than the seven the estimate scaled by -- so the
estimate's *band* (single-digit milliseconds, worst case included) was right
and its ratio was optimistic. Nothing here needs the 300 ms escape hatch
Sudoku had to build; even three times slower on a phone this is under 11 ms,
one frame. The attempt means are a fourth independent agreement with the 1.27
/ 1.36 / 1.48 and 1.28 / 1.31 / 1.44 above, off a different RNG.

### 4.4 The fallback

The re-roll budget is **400 attempts**. It was never approached in 6,000
measured boards and exists only so a pathological seed cannot hang the board
opening: past it the board plays the last tree it grew rather than blocking,
exactly as Sudoku hands back `graded: false`. On such a board the second half
of rule 6 is doing real work.

### 4.5 The deal's live cap is new, and the mock must catch up

The mock deals a scramble with no ceiling on how much of the board starts
live, and it shows: one 6x6 seed opened with a third of the garden already
gold, another opened with nothing lit but the post. The opening frame is the
one that has to say *this is a dark garden and the post is where the power
is*, so the board caps the deal at **25% of cells live** and re-scrambles
otherwise. The implementation adds this to the generator **and to the mock in
the same commit**, so the page stays the reference rather than drifting from
it.

---

## 5. Colour: nothing new

Every value on the screen is already in `core/palette.gd`, and two of them are
being used a second time for the reason they were written down the first time.

| Thing | Colour | Why that one |
| --- | --- | --- |
| Dead wire | `FLAGSTONE` over `FLAGSTONE_DEEP` | Light Up's unlit stone, whose own comment is the argument: the one cool colour, so against warm lamplight the difference is a change of temperature as well as of value. That is precisely this board's one job. |
| Live wire | `SUN` over `SUN_DEEP`, halo in `SUN_RAY`, highlight in `LANTERN_LIT` | The family's gold. The halo is drawn under every live run **before** any wire, so a live branch reads as light before it reads as cable. |
| Lantern, unlit | its `LANTERN_PAPER` pair, 55% toward `STONE` | Untangle's five papers by index, muted, and with **no face**: `ui/faces/face.gd`'s `plain` is what an unlit lantern is. |
| Lantern, lit | its paper 40% toward `LANTERN_LIT`, deep edge toward `SUN`, halo | The documented meaning of `LANTERN_LIT`. Untangle's win does this once; here it is the mechanic. |
| The post | `LANTERN` iron, glass in `SUN` over `SUN_DEEP` | Light Up's lantern iron. The one thing on the board that is never paper and never dark. |
| The ground | `SURFACE` half-way to `PARCHMENT`, rules in `LINE` at 34% | The cells must be visible, because a tap turns one cell -- but only just. The wire is the drawing. |
| The fence round the grid | `GRID_RULE`, 6 wide | Sudoku's heavy rule, drawn round the grid for Sudoku's reason: the cells run to the inset's edge and the rule has nowhere to go inside. |
| A pinned cell | `SUN_RAY` at 40% under a dotted `SUN_DEEP` ring | Word Trail's hint mark, unchanged. |

---

## 6. The cast: no new character, for the sixth screen running

The lantern is `ui/faces/lantern_face.gd` **exactly as Untangle ships it** --
five papers by index, a `lit` from 0 to 1 snapped to five levels for the mesh
cache, and its own halo -- so a board of seventeen lanterns costs at most five
meshes a paper. Nonogram decided this rule, and Hidden Word, Word Trail,
Mushroom Patch and Sudoku each confirmed it; this is the sixth.

**How it is drawn.** The wire, the halos, the ground and the fence go into a
single `ArrayMesh` rebuilt on change, the way Word Trail and Nonogram build
theirs; the lanterns and the post are `lantern_face.gd` Controls **in slots
the board owns**, because they have faces and a face is a Control here. That
is Untangle's arrangement, and Untangle is the precedent for a board whose
pieces move inside slots it owns.

**Keep the mesh the last `_draw` handed over.** A canvas command holds a mesh
by RID: a board that rebuilds its cached `ArrayMesh` and drops the previous
one leaves the renderer drawing a freed RID on any frame rendered without the
queued redraw flushed first, which is exactly what a harness's
`force_draw()` does. `word_trail2d.gd` keeps three meshes in a `_shown` array
for this; this board keeps one.

---

## 7. Motion

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`), read off the curve readers the way Nonogram's and
Light Up's drawn pieces are. It needs **nothing new** from `core/motion.gd`
and carries two constants of its own: `TURN_TIME` 0.26 s and `WAVE_STEP`
0.05 s a depth.

| Moment | What happens |
| --- | --- |
| Entrance | The grid pops in wide about its centre (`wide_pop_scale` from 0.88) while it fades; the lanterns pop in after it (`pop_in_scale`). The first wash then runs out from the post, so the screen opens by showing where the power is. |
| A turn | The piece spins a quarter turn with `back_out`'s overshoot over `TURN_TIME`, pulling its arms in about 11% at the middle of the spin so it does not reach into its neighbours on the way round. **The paper stays level**: a lantern's body counter-rotates, because a hanging thing does not cartwheel. |
| **The wash** (the signature) | Queens' `_settle` with the tree's own depth in place of a queen's sight. Every turn diffs a snapshot of what is live: a cell just reached lights at `depth * WAVE_STEP` after the spin; a cell just cut off goes dark on the same wave **reversed, far end first**, which reads as the light being pulled back rather than switched off. Derived off the diff, never stored. |
| A lantern waking | `bump_scale` as the wash arrives, and the face appears with it. Seventeen of them wake in a ripple rather than together, because each is on its own depth. |
| A refusal | A cross shivers (`shiver_offset`) and the sprout says why. Nothing else on this board can refuse. |
| Hint | The piece turns however many quarters it needs in one spin, a ring in `LEAF` over it, and the cell keeps the pinned wash from then on. |
| Undo | The same spin anticlockwise, and the wash runs backwards behind it. |
| Reset | Every piece that has moved turns back at once, on a corner-out stagger of 0.02 a cell. Pinned pieces stay. |
| Solved | The last wash finishes, every lantern is awake, and the win comes up `WIN_WAIT` 1.4 s later. |

**Reduce motion:** no spin -- a piece is simply round the other way -- no
wash, so the whole live set changes in one frame; no lantern bump, no halo
pulse, no rings, no sparkles, and the win follows the last turn. Two frames
1.5 s apart must come out pixel-identical, as on every other board.

---

## 8. Undo, Hint, Reset -- and no Check

- **Undo** turns the last piece back a quarter turn, in tap order. One log,
  one integer an entry.
- **Hint** takes the first unsolved cell in reading order, turns it to its
  proven orientation and **pins** it so it cannot be turned again. Reading
  order rather than anything cleverer, for Word Trail's reason: it is
  predictable, it needs no state, and a hint that guesses what the player
  wanted can guess wrong. **Three** of them, and a hint clears the undo log
  (Shikaku's rule).
- **Reset** puts every unpinned piece back to the scramble it was dealt. A
  pinned piece stays, because a hint is a given.
- **No Check.** The third screen to drop it: Balance because it is its own
  continuous check, Word Trail because nothing wrong can sit on the board,
  this one because nothing wrong can exist.

**The hint is worth more here than anywhere else in the game, and that is a
risk.** On Word Trail a hint lights one tile of thirty-three; here it settles
one cell of forty-nine permanently, and because the solver is a propagation, a
pinned cell often unlocks a run of its neighbours by hand straight afterwards.
Three may be too many. The knob is one constant and the phone is where to feel
it.

---

## 9. What the chrome is asked for

One registry line and nothing new on the host: `"shell": "flat"`,
`"tray": "none"`, `"actions": false`, tip card kept. `capabilities()` is
`["undo", "hint"]`. The bottom slot the host measures from the rows it built
is therefore **140** -- the tip card alone, which only Untangle and Word Trail
share -- against the fifteen screens' 458, 460, 390, 290, 140, 290, 290, 290,
460, 460, 340, 140, 460, 480 and this one's 140.

Of the optional things a flat board may answer it uses exactly two:
`card_height()`, which returns the grid plus its insets, and `card_centred()`,
which is `true`. It does not want `palette()`, `weights()` or `win_delay()`.
It does want **`flat_win()`**: five lit paper lanterns laid across the win
screen. `ui/flat/well_done.gd` lays a cast of faces and draws no cord, so the
**cord the mock draws between them is not shipped** -- five lanterns in a row,
and nobody touches `well_done.gd` for it.

**Where it stands on the first screen:** the fifteenth entry, so it lands on
**page two** beside Mushroom Patch and Sudoku. `PER_PAGE` is twelve and page
one is full; nothing about the pager changes, and page one's draw-call count
is untouched, which is the whole point of paging rather than reflowing. The
card's picture is one `_build` branch in `ui/menu/card_art.gd`: a lantern post
with a short run of lit wire and two paper lanterns on it, all reuse.

---

## 10. Analytics

The family's events with nothing added: `puzzle_start`, `puzzle_complete`
(`solved: true` -- this board cannot end unsolved), `puzzle_abandon`,
`hint_used`, `undo_used`, `board_reset`, `rules_opened`. No `check_used`,
there being no Check. Moves are turns.

---

## 11. Measured

Everything below was read on this Mac on 2026-09-20, on the build this
section was written against, with **one windowed harness running at a time**
(three other agents were live on this machine; every run waited for any other
Godot to leave, because GPU contention inflates every millisecond). Every
reading is quoted, including the flattering one -- a single reading off this
harness is worth nothing.

The flag is `--resolution 810x1440`, **before `--script`**, which is the true
1080x1920 of design space. Written after the `--` it is handed to the script
as a user argument, the engine never sees it, and the run falls back to a
1237-wide canvas without saying so.

```
godot --path . --resolution 810x1440 --script tests/_shot_anim.gd -- fairylights [empty|wash|rm]
```

`tests/_shot_anim.gd` learned this board in Task 5. Its tap is the point of
the strip: `_tap_fairylights()` looks one turn ahead at every unpinned,
non-cross cell -- turning it clockwise in the grid, asking `depths()` how
much of the garden that lights, and putting the grid straight back -- and
touches the cell that lights the most, through the board's own `_gui_input`.
On the day this was measured that is cell 20 (row 3, column 2) of a 6x6
garden, and it lights five cells and wakes a lantern. The `empty` word
measures the bare board, `wash` puts the measuring window **over** the wash
instead of after it, and `rm` adds the reduce-motion pair.

### 11.1 Draw calls, against the 855 budget

| State | Word | Default driver | ANGLE |
| --- | --- | --- | --- |
| Bare | `empty` | **81**, 81 | 81 |
| One turn played, settled | -- | **82**, 82, 84, 84 | 82, 84 |
| With the wash in flight | `wash` | **82**, 82, 82, 82 | not run |
| Reduce motion | `rm` | 82 | not run |

**A tenth of the budget at every state**, and no state is more than two
calls from any other. Two things are worth saying about that spread rather
than hiding it:

- **The wash costs no draw call.** The peak while the light walks out along
  the wire is the same 82 as the settled board, because the halos, the sheen
  and the lit cable all go into the **one** `ArrayMesh` the board already
  rebuilds. What a wash costs is that rebuild, and the rebuild is
  milliseconds, not calls -- see 11.2.
- **The 82/84 pair is the chrome and not the board.** It comes and goes on an
  unchanged build, on both drivers, off a deterministic tap, and the window
  reports a maximum; the wordmark's rayed sun glints on its own clock and the
  repo already records it costing the header a call. That attribution is
  **inferred from where the two values fall and not measured**; what is
  measured is that the board's own state does not move it.

### 11.2 Milliseconds

This harness **disables vsync** (`VSYNC_DISABLED`, `Engine.max_fps = 0`), so
nothing here is the 120 Hz ceiling that `tests/_shot_menu.gd`'s ~8.3 ms is.

| Window | Readings |
| --- | --- |
| Settled, 2.8-4.8 s (719-775 frames) | 2.78, 2.58, 2.72, 2.72 ms; 2.72 under `rm` |
| Moving, 1.65-2.05 s, `wash` (24-25 frames) | **16.30, 16.70, 16.67, 16.81 ms** |
| Settled on ANGLE | 5.40, 5.86, 5.36 ms |

**The control, run in the same hour**: Word Trail came back at **65, 65**
draw calls with one word locked against its recorded 65/62/65, **60** bare
against its recorded 60/61, and idles of **2.44, 2.49** ms played and 2.40
bare against its recorded 2.51/2.49/2.51. It reproduced its record, so this
session's figures are worth quoting.

**A moving frame costs six times a settled one, and that is the one number on
this board to think about.** While anything moves the board rebuilds its
whole mesh every frame (the board's own header says so), and
`tests/_probe_fairy_frame.gd` times that rebuild directly rather than
inferring it, one board a band off seed 12345, sixty calls each, four runs:

| Band | `_build` | `_dress` |
| --- | --- | --- |
| Easy 5x5 (cell 188) | 7.23, 7.30, 7.26, 7.29 ms | 0.03 ms |
| Medium 6x6 (cell 157) | 9.03, 9.10, 9.03, 9.16 ms | 0.03-0.04 ms |
| Hard 7x7 (cell 134) | 10.68, 10.78, 10.67, 10.91 ms | 0.05-0.06 ms |

So between a half and three quarters of the 16.5 ms moving frame is the
rebuild in GDScript, and the rest is the fresh mesh going to the canvas
beside the lanterns and the effects. The day's own 6x6 board read **11.81 ms** for the
same `_build` on an earlier run of the probe, which is the same figure with
more of the garden live: a live run draws two halo passes and a sheen a dark
one does not. **Run that probe windowed and at 810x1440**: `_build` tessellates
its arcs off the cell, and the first reading of it, headless on a 297 cell,
came back at 21 ms.

**What that means and what it does not.** A settled board is 2.7 ms and idles
inside anything. A board with the wash running sits at about 16.5 ms a frame
on this Mac, which is one 60 Hz frame and not one 120 Hz frame, and the wash
runs for a few tenths of a second a tap. **A phone is commonly two to three
times slower than this Mac**, which would put a moving frame past a 60 Hz
frame there; nothing on this Mac can measure that, so it is one more thing to
feel on the phone rather than read off a log. If it does need fixing, the
levers in order are: rebuild only while a *moment* is actually live rather
than for the whole
of `_anim_until`, cache the still half of the mesh (the ground, the fence and
the rules never change inside a deal), and only then cut geometry.

**Two earlier readings of a moving window are not quoted above and must not
be**: 8.46 and 8.83 ms, off a first draft of `wash` whose window was wider
(1.75-2.45 s, so it ran on past the wash) **and had three of the strip's
shots inside it**. `save_png` of the viewport costs tens of milliseconds,
which is nothing spread over the seven hundred frames of a settled window and
is most of a twenty-five frame one: a second draft with four shots in a
tight window read 33.60 ms. The harness now takes no shot between
`_idle_from` and `_idle_to` in `wash` mode, and says why in a comment.

### 11.3 The phone's driver

```
godot --path . --resolution 810x1440 --rendering-driver opengl3_angle --script tests/_shot_anim.gd -- fairylights
```

Same counts (82 and 84 played, 81 bare), and the settled frame matches the
default driver's to **2/255, on three pixels of the whole frame**; 141,781
pixels differ by a single level, which is two drivers rounding the same
gradients differently. Two runs of the *default* driver, compared with each
other as the reference for that, agree to 1/255. **Nothing has reintroduced an
`instance uniform`**, whose real cap is sixteen instances in the frame and
which this desktop driver would hide.

The reduce-motion pair 1.5 s apart is **pixel-identical** (max difference 0,
zero pixels differing): nothing on a settled board moves when motion is off.

### 11.4 The generator

Measured and written into **section 4.3**, which is where it belongs: the
estimate that stood there was scaled off the JavaScript mock and has been
replaced by `tests/_probe_fairy_gen.gd`'s own reading, 200 seeds a band, run
twice. `build()` means **0.411 / 0.680 / 1.117 ms** and worsts **1.05 / 2.89
/ 3.49 ms** across the three bands, attempts means 1.170 / 1.320 / 1.445,
`proved` 600/600. **The port came out about twelve times the JavaScript mean
rather than the seven the estimate scaled by** -- the estimate's band was
right and its ratio was optimistic. Nothing here needs Sudoku's 300 ms escape
hatch.

### 11.5 The suite and the win harness

The suite is **29650 / 0** (`godot --headless --path . --script
tests/run_tests.gd`), unchanged by Task 5's one code fix.

`tests/_win.gd`, **run windowed** -- it reports 0/0 headless -- comes back
**winnable=17/17**, and 17 is `Registry.PUZZLES.size()` (checked; a board that
fails to parse drops out of that count silently rather than failing it). This
board's line:

```
PASS  fairylights  solved=true done=true overlay=true  6x6 garden, 11 lanterns, 44 turns, board fit=true, hud=true
```

That is the **day's** board and so one band, not three: `_win.gd` opens what
the day deals, which was the medium 6x6. The other two bands are covered by
`tests/test_fairy_lights.gd` in the suite rather than end to end by this
harness.

### 11.6 Not measured

Said plainly so nobody reads a number into a gap: the win screen's own draw
call (there is no `solve` word in this board's branch of the harness), the
count at 5x5 and 7x7 on the strip (the harness opens the day's band), and
anything at all on the phone.

---

## 12. Calls this board is for judging on the phone

1. **Whether the live wash gives the game away.** It is the friendliest
   possible feedback and may be too friendly -- on an easy board you can chase
   the gold outward and barely think. The alternatives are lighting only the
   post's immediate run, or lighting nothing until the board is done.
2. **Clockwise only.** Four taps to undo one is the classic Netwalk bargain,
   and on a 134 cell it is four taps in the same place. It is also why Undo is
   in the bar.
3. **Whether 7x7 is long.** Forty-nine cells, about thirty out of place at the
   deal, roughly a tap and a half each. Nothing else in the game asks for that
   many discrete taps.
4. **The air.** 172 above and below the card at every band. Section 2.1's
   scenery band is the alternative.
5. **The loose-end rule.** It makes the board much easier to read, and it may
   make it too easy to read: it hands over the whole "every stub meets a stub"
   half of the win condition at a glance.
6. **Whether the post should turn.** It does, being an ordinary piece that
   happens to draw a post. Fixing it would be a free given on every board.
7. **Three hints.** See section 8.
