# Caterpillar, flat: the twenty-first board

Status: built, 2026-09-25, on `feat/caterpillar`. Concept page:
`docs/brainstorm/concepts.html#caterpillar`.

A garden of squares with numbered leaves on some of them and wooden fences
between a few. Press leaf 1 and drag: every square the finger crosses grows
the caterpillar one segment. It eats the leaves in order, never crosses
itself or a fence, and the board is done when its body fills every square
with its head on the last leaf. One walk through the whole garden.

## 1. What it is, and what it is called

The genre is a Hamiltonian path with ordered waypoints. The user's reference
is a screenshot of LinkedIn's version (a 7x7 Hard board: ten numbers, four
wall runs); LinkedIn ships it under its own name, which the concept page
names once in order to forbid it. **It is called Caterpillar and nothing
else**, in code, in a comment or on screen: the newest link in the chain this
repo names rather than numbers -- Code Break, Hidden Word, Word Trail,
Bridges, Quilt, Paper Planes, Pinwheel and Caterpillar.

Decided with the user on 2026-09-25 before a line was written:

- **The dressing: the path is a caterpillar.** The one thing the player draws
  is also the one creature on the screen, and the solve turns it into a
  butterfly. Chosen over a thread, a stream and a kite string.
- **The ladder grows and thins**: 5x5 / 6x6 / 7x7, Insane 8x8, with fewer
  leaves for the area as the garden grows and fences from Medium on.
- **Every board is proved to have exactly one walk.** No guess-free promise
  is made: there is no logic solver behind this board, only a uniqueness
  proof. That is weaker than Bridges' and Fairy Lights' promise and it is
  named here so nobody quotes it as the same thing.

How it differs from its neighbours: One Line walks the *lines* of a figure;
Word Trail drags short words through letters; here the walk fills *squares*,
all of them, and the numbers are waypoints.

## 2. The rules, exactly

1. The walk starts on leaf 1. A press anywhere else on an empty garden says
   "Start on leaf 1." and does nothing.
2. It grows one square at a time, side to side or up and down, never onto
   itself and never across a fence.
3. **Leaves are eaten in order.** Stepping onto a later leaf early is refused.
4. **The last leaf is the last bite.** Stepping onto it while any square is
   still empty is refused.
5. Solved when the body covers every square and the head is on the last leaf.

Rules 2-4 are one gate (`caterpillar_state.gd`'s `why()`), so **nothing wrong
can sit on the garden**: the only way to be wrong is to be stuck. That is why
there is no Check.

Input: press leaf 1 (or anywhere on the body) and drag. Dragging back onto
the body cuts it back to that square, which is how steps are taken back
mid-stroke; pressing on the body does the same between strokes. While a
finger drags, only the middle 80% of a square counts (`DRAG_CORE`), so a fast
drag along one row cannot clip the corner of the next. A stroke that changed
the body is one move and one Undo.

## 3. The chrome

Pinwheel's shape: `"tray": "none"`, `"actions": false`. Undo, Reset and Hint
ride in the top bar (five buttons, so the title block is 370); the board card
takes the rest. `Caterpillar` at the theme's 84 is fitted down by
`flat_top_bar.gd`'s `_fit_title`, and `LEAF BY LEAF, EVERY SQUARE` fits.

**There is no tip card any more, on any board.** It left the flat chrome in
`1a04e0a` (2026-09-21), after most of CLAUDE.md's bottom-slot figures were
written; `tip_line()` is kept, as every board keeps it, but nothing shows it.
So a refusal speaks through motion alone: the refused leaf's badge (or the
fence) flashes toward `Pal.BAD` and shivers, and the head shivers with the
STRAIN face.

## 4. The card

`ui/menu/card_art.gd`'s `_draw_caterpillar`: Pinwheel's 8 by 3 strip of
`BED_GROUND`, the caterpillar part-way through a walk (leaves 1 and 2 eaten
under it, 3 and 4 ahead) and one fence, drawn through `ui/faces/caterpillar.gd`
-- the board's own drawing, so the two cannot drift apart. One mesh plus four
numbers. Plate: the meadow vista (`ui/menu/vistas.gd`). It is the
twenty-first entry and stands on page three at 1080x1920 (entries 17-21).

## 5. The generator (`puzzles/caterpillar_gen.gd`)

1. **Grow the answer.** A boustrophedon stirred by `STIR` (24) backbites a
   cell, from either end: the end steps onto a neighbour already in the path,
   the path is cut there and the loose part reversed. Every backbite keeps a
   Hamiltonian path.
2. **Lay leaves and fences.** Leaf 1 on the first cell, the last leaf on the
   last, `target - 3` spread along the path; fences on random edges the path
   never crosses, up to the band's count.
3. **Prove it.** A depth-first count of walks, capped at two. While it finds
   a second walk, the first place the two disagree is pinned: a fence on the
   stray edge (half the time, while the band allows one), or a leaf on the
   first square where they part.
4. **Thin it.** Leaves are taken away one at a time toward the band's target,
   each only if the proof still holds.

The proof is a bitmask search: up to 64 squares, so a set of squares is one
int, and two prunes per node -- every free square reachable from the head
(a flood by shifts), and no free square with fewer than two open neighbours
unless it is the last leaf.

**Every proof is capped by a node count, never by a clock** (`NODE_CAP`
1000; Insane's row 500), and **a capped proof is never a proof**: the leaf it
was testing stays. That bounds the worst seed and, unlike Sudoku's 300 ms
budget, cannot differ between phones: a day is the same garden everywhere.
The first cut read a capped search that had found one walk as "unique", and
**14 of 60 hard and insane boards had two walks**; `tests/_probe_cat_gen.gd`
re-proves every board against an uncapped 3M-node search, which is what
caught it, and it now finds none.

Measured with that probe on this Mac, 30 seeds a band, GDScript:

| Band | Garden | Leaves (range, mean) | Fences | Mean | Worst |
|---|---|---|---|---|---|
| Easy | 5x5 | 6-8, 7.0 | 0 | 8.0 ms | 13.6 ms |
| Medium | 6x6 | 7-9, 8.2 | 2-4, 4.0 | 18.1 ms | 41.4 ms |
| Hard | 7x7 | 8-11, 9.9 | 3-6, 6.0 | 55.3 ms | 102.2 ms |
| Insane | 8x8 | 9-13 target, 13.8 | 4-8, 7.6 | 85.1 ms | 157.2 ms |

All under the 194 ms gate. Insane's lower cap costs it density: it lands
above its own target on average, because more proofs hit the cap and keep
their leaf. Its row is provisional like every board's
(`2026-09-23-insane-level-design.md`); a mined bank would fix both.

## 6. The state (`puzzles/caterpillar_state.gd`)

`body` (tail first), `history` (one body per stroke), `given` (the squares a
hint grew, washed gold while the body covers them). `why(n)` is the gate;
`grow`, `cut_to`, `commit`, `undo`. **The hint** cuts back to the last square
that agrees with the answer and grows the answer on to the next leaf, four
squares at most (`HINT_REACH`); three hints. Probed headless over 160 boards
(40 a band): the answer always walks through `why()` clean, every fence and
out-of-turn leaf beside a half walk is refused with the right reason, and a
hint from a wrong body leaves a body that wholly agrees with the answer.

## 7. The board (`puzzles/caterpillar2d.gd`, `ui/faces/caterpillar.gd`)

Three meshes and the numbers between them: **still** (the ground, its grid
and a `LINE` rim -- `BED_GROUND` is only a shade off the card's parchment and
had no edge without it), **live** (the hint's wash, the fences, the body, the
badges and the eaten rings) and **top** (the head). The numbers go over
`live` and under `top`: **the head must never sit under a badge**, which is
exactly what the concept page's first frame did to it.

- **Fences, not hedges.** The first cut drew green hedge puffs, and next to a
  green body they read as a second, smaller caterpillar. They are Shikaku's
  fence woods now (`FENCE_DARK`, `FENCE_RAIL`, `FENCE_POST`).
- **Leaves are ink badges** with a leaf on the shoulder: readability first,
  the reference's own choice. An eaten one wears a `SUN` ring.
- **The caterpillar** is a `LEAF_DEEP` tube under a `LEAF` one, a round
  segment on every square alternating `LEAF` and `LEAF_LIGHT`, feet under
  every other one, and a head with the family's face
  (`Face.face_parts`, made static for this board so a face can be baked into
  a mesh) and antennae pointing the way it is going.
- **Only the head breathes.** The first cut breathed every segment and
  rebuilt the whole body mesh every frame: **12.2 ms an idle frame** on Hard.
  At rest only the head's small mesh is rebuilt now (breath and blink):
  **3.3 ms**, twice, against Pinwheel's 2.44 ms read as a control in the same
  session.
- **Motion**: the head slides in from the square it left (`SLIDE_TIME`
  0.11), a new segment takes `Motion.pop_in_scale`, a leaf bumps and rings
  as it is eaten and the head munches (a squash). The solve's hop runs tail
  to head over `SOLVE_SPAN` 0.7 whatever the length, sparkles land on each
  leaf as it passes, and a butterfly (flower and sun wings) rises out of the
  head over `BUTTERFLY_TIME` 1.8; the win waits `WIN_WAIT` 2.8. Reduce motion
  stills all of it, and the butterfly is not drawn.

Measured with `tests/_shot_anim.gd -- caterpillar d=2` at
`--resolution 810x1440`: **58** draw calls half-walked, on every run
(stock, `refuse`, `rm`, and `--rendering-driver opengl3_angle`); 47 on the
Medium win screen (`d=1 full`). Menu page three reads **142**. All far inside
855. `tests/_win.gd`: **PASS** (6x6, one hint, one drag, fit and HUD true).
Suite: 122,583 passed, 0 failed.

## 8. Sounds

`tools/gen_sfx.py`'s `caterpillar` set: place, munch, refuse, undo, hint,
reset, solved, enter. `step` fires on every square and gets no file. Not
generated yet: a missing file is silence.

## 9. Files

- `puzzles/caterpillar_gen.gd`, `puzzles/caterpillar_state.gd`,
  `puzzles/caterpillar2d.gd`
- `ui/faces/caterpillar.gd`; `ui/faces/face.gd` (`face_parts` made static)
- `ui/registry.gd`, `ui/menu/card_art.gd`, `ui/menu/vistas.gd`
- `locale/boards.csv` (`CP_*`, en / pt-BR / es)
- `tests/_shot_anim.gd`, `tests/_win.gd`, `tests/_probe_cat_gen.gd`
- `tools/gen_sfx.py`
- `docs/brainstorm/concepts.html#caterpillar`

## Amendment, 2026-09-26: the polish

Built directly on `feat/caterpillar-polish` after a short design in chat; no
reference image, so it was drawn toward the house style Rings and Fairy
Lights set that same day.

- **The garden** (`_build_still`, built once a layout): a mown lawn over the
  whole card, clipped to its corner, with stripes, dappled shade, tufts and
  daisies off the bed, foliage hanging into the top corners and daisy bushes
  along the foot. The bed is a wooden frame (Fairy Lights' planks) round a
  checker of pale grass tiles in `MEADOW`, a clover or a few blades on some.
  Rings' leaf, daisy and hash statics are shared rather than copied.
  `INSET` 28 to 40 to seat the frame.
- **Leaves** are a real leaf lying on the square *under* the body, with the
  ink badge and number still over it; an eaten leaf carries a bite per chew.
- **Fences** are a rail with a lit top, grain, a shadow and square capped posts.
- **The caterpillar** (`ui/faces/caterpillar.gd`): a soft shadow, a chubbier
  tube, two sun spots on every segment, a stubby leg pair out to either side,
  the last two segments tapering, a two-tone head with swaying antennae. The
  butterfly has real fore- and hindwings, spots and a segmented body.
- **Motion.** A crawl swell leaves the head on every step (`RIPPLE_*`). While
  it walks, each leg pair steps in a wave tail to head, left and right in
  opposition, a swinging leg tucked in and pale-footed, the body wiggling
  across; the gait eases out over `WALK_FADE` 0.4 after the last square.
  **Eating** is `CHEWS` 3 chews of `CHEW` 0.17: each one smooth cosine that
  squashes the head, leans it into the leaf and opens its mouth on a leaf
  scrap that shrinks chew by chew, eyes shut; a bite and a few crumbs a chew,
  then a gulp runs back down the body (`GULP_*`). **A cut back** (press or drag
  onto an earlier segment) no longer jumps: the head runs back along its own
  body, `RETREAT_STEP` 0.05 a square capped at `RETREAT_MAX` 0.6 in all, on a
  smoothstep, folding the body up behind it. Undo, Hint and Reset pop the
  segments they take away (`GHOST_TIME`; Reset tail first). The solve warms
  each segment toward paper white as the hop passes (a shade of gold turned
  the greens khaki), and the butterfly unfolds out of the head, flies a loop
  and leaves over the top.
- **At rest only the head moves**, as before: its breath, blink and antennae
  are its own small mesh. The walk, chew, gulp and run each keep the live mesh
  rebuilding only while they last.

Measured at `--resolution 810x1440`: **58** draw calls half-walked, **57**
under `rm`, **50** after the full solve; reduce motion's pair 1.5 s apart is
pixel-identical; ANGLE agrees on 57 with a max channel delta of 11/255. Idle
~3.0 ms on the bare board, which is the painted garden's cost and the same as
Rings (3.00) and Fairy Lights (2.96) in the same session (1.73 before).
Menu page one still 255, and the menu card has the new bed and body. Suite
122,583 / 0; `tests/_win.gd` 21/21. The harness gained `munch` (stops on
leaf 2 and shoots the chewing) and `cut` (drags back eight squares).
