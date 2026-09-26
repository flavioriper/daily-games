# Sunbeam, flat: the twenty-second board

A greenhouse floor at morning. The sun comes in through a gap in the glass as
one golden beam, and a handful of **brass mirrors and copper cups ride wooden
rails** across the floor. **Drag a piece along its rail and the light follows
it live.** Light every dewdrop, then end the beam in the bud, which blooms.

The reference is a screenshot the user supplied of *LIT: Bend the Light*,
which this spec names once in order to forbid it: **it is called Sunbeam and
nothing else**, in code, in a comment or on screen -- the chain this repo
names rather than numbers: Code Break, Hidden Word, Word Trail, Bridges,
Quilt, Paper Planes, Pinwheel, Caterpillar and now Sunbeam. Nothing is taken
from it but the mechanic.

- Mock, playable, and the reference for every measure:
  `docs/brainstorm/concepts.html#sunbeam`.
- Decided with the user on 2026-09-26, before a line was written: pieces
  **slide on rails** (not placed from a tray, not turned in place -- turning
  is Fairy Lights' gesture); the set is **mirrors and U-cups**; the dressing is
  **a sunbeam in a greenhouse**; the floor is **snapped to a grid**, so every
  arrangement can be searched and every day proved to have one answer.

---

## 1. What is built

| File | What it is |
| --- | --- |
| `puzzles/sunbeam_gen.gd` | The day's floor: grow the answer, rails, drops, pots, the opening, and the proof. Scene-free. |
| `puzzles/sunbeam_state.gd` | The rules: pegs, snapping, the traced beam, undo, hint, reset, solved. Scene-free. |
| `puzzles/sunbeam2d.gd` | The board: three meshes, the drag, the light's travel, the bloom. |
| `ui/faces/sunbeam_parts.gd` | The drawing -- mirror, cup, beam, drop, pot, bud, window, sun, rail -- shared by the board and its menu card. |
| `core/palette.gd` | The greenhouse's colours (`GLASSHOUSE` .. `BEAM_CORE`). |
| `ui/registry.gd`, `locale/boards.csv`, `ui/menu/vistas.gd`, `ui/menu/card_art.gd` | The card: entry, strings (en/pt-BR/es), banner vista, picture. |
| `tools/gen_sfx.py` | The sound set's prompts (not yet generated). |
| `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_probe_sunbeam_gen.gd` | The harness hooks and the generator probe. |

## 2. The rules

- **The lamp** is an edge cell, never a corner; the beam leaves it straight
  into the floor.
- **A mirror** is one cell and turns the beam 90 degrees. Both faces reflect.
  Its angle never changes -- only its peg.
- **A cup** is two side-by-side cells with its mouth one way. Light going into
  the mouth comes out of the other cell going back the way it came; light
  that meets its back stops.
- **The beam** may cross itself and runs over the rails. A pot stops it, and
  so does the lamp; off the floor it is gone; a beam that would loop stops.
- **Solved** when every dewdrop is lit and the beam ends in the bud. What is
  judged is the light, never where the pieces stand.
- Reaching the bud with a drop still dry is **not** a solve: the bud glows,
  stays shut, and the tip card says how many drops are left.
- **The one move** is sliding a piece to another peg of its rail -- by drag,
  or by tapping an empty peg. A piece hops a peg another piece stands on
  rather than stopping short of it, so every arrangement is reachable.

Nothing wrong can sit on the floor: the beam is traced after every step of a
drag and *is* the check. So there is **no Check**, no tray and no actions
row; Undo, Reset and Hint ride in the top bar and the tip card stands alone
-- Pinwheel's shape (`"tray": "none"`, `"actions": false`).

## 3. The ladder

| Level | Floor | Pieces | Cups | Rail pegs | Drops | Pots |
| --- | --- | --- | --- | --- | --- | --- |
| Easy | 5x6 | 3 | 0-1 | 3-4 | 2-3 | 0-1 |
| Medium | 6x7 | 4-5 | 1 | 3-5 | 3-4 | 1-2 |
| Hard | 7x8 | 6 | 1-2 | 4-5, shortened to 3 if a rail will not fit | 4-5 | 1-3 |
| Insane | 7x8 | 7 | 1-2 | 4-6, **rails cross** | 4-6 | 1-3 |

Insane is provisional, as every board's is
(`2026-09-23-insane-level-design.md`). The Hard rail shortening was not in
the first design: without it a quarter of Hard seeds found no board in 3000
grows, because six disjoint rails on 7x8 rarely all fit at full length.

## 4. The card

The same 8 by 3 strip Pinwheel and Caterpillar use: the sun in its window, a
mirror turning the light up and another along it into a cup, which sends it
back one lane over, through a dewdrop, into the bud. Every piece home and the
light arriving, so the card is the rule in one picture. Drawn through
`sunbeam_parts.gd`, one mesh. Banner vista: `sky`.

## 5. The generator

Grow the answer first -- the beam walked out of the lamp, a bender dropped at
every turn (a mirror turning left or right, or a cup reversing it one lane
over), the bud at the end. A later run may **cross** the answer's beam so far
but never **lie along** it, and no bender stands on a cell the beam already
crossed. Then drops go on the beam's free cells, one from each of `D` equal
stretches; each bender gets a straight rail through its answer cell; pots go
where the answer's beam never passes and no rail runs; and the opening puts
every piece on a peg other than home, overlapping nothing and not already
solved.

**The proof is exhaustive, never capped.** `count()` follows the beam out of
the lamp and branches only where it reaches a peg -- a piece stands here, or
none does (which rules that peg out for the rest of the branch). A piece the
beam never reaches is counted over every peg left to it. The search is
bounded by the rails, not by a node count, so there is nothing to cut short
and a day is the same floor on every phone. Exactly one arrangement, or the
board is thrown away and grown again.

Measured with `tests/_probe_sunbeam_gen.gd`, forty seeds a band, GDScript on
this Mac, every board re-counted (cap 3) and its answer re-traced to a solve:

| Band | Mean | Worst | Grows, mean / max | Bad |
| --- | --- | --- | --- | --- |
| Easy | 1.1 ms | 3.7 ms | 13 / 47 | 0 |
| Medium | 3.2 ms | 13.7 ms | 33 / 136 | 0 |
| Hard | 22.7 ms | 83.3 ms | 208 / 764 | 0 |
| Insane | 2.5 ms | 7.9 ms | 11 / 52 | 0 |

Hard's cost is grows that do not fit, not proofs: its disjoint rails are the
tightest constraint in the ladder, which is also why Insane -- whose rails may
cross -- is faster. 83 ms is inside the 194 ms gate; a phone two to three
times slower would still be about at it, so Hard is the band to feel on the
phone.

**What the proof does not promise:** that finding the answer takes thought.
Whether the ladder wants more pieces, longer rails or more drops is for the
user to judge by playing.

## 6. The state

`sunbeam_state.gd` holds the floor (`g`), each piece's peg (`pos`) and its
opening (`start`), the history for Undo, the pinned set, and the beam traced
after every change. `snap(p, s)` is the nearest free peg to a float index,
which is what a drag asks for every motion event. `hint()` slides the first
piece along the answer's beam that is not home onto its peg and **pins** it
(a gold mount; a drag on it shivers and says so); whoever stands in the way
steps to the nearest free peg of its own rail. Reset keeps pinned pieces.

## 7. The board

Three meshes (`_still`, `_live`, `_air`):

- **still** -- the glass wall, the frame, the tiles, the rails, the pots and
  the window. Rebuilt only on a relayout.
- **live** -- cups, the beam, drops, mirrors, glints, the bud and a hint's
  ring. Rebuilt only while something moves.
- **air** -- the sun's rays and the motes drifting down the light: the only
  thing that moves at rest, and small, so an idle floor rebuilds that alone
  (Caterpillar's lesson: a whole-mesh idle rebuild cost 12 ms a frame).

**The light travels.** After a move, the stretch the old and new beams share
stays lit; the old remainder fades over `BEAM_FADE` 0.18 s; the light runs
down the new stretch at `BEAM_SPEED` 34 cells a second from the fork. A drop
rings and chimes as the light reaches it, pitch rising with each. The win is
`solved` at the release, but `win_delay()` waits for the light to reach the
bud (`_arrive_in`), then `WIN_WAIT` 2.6 s for the bloom and sparkles.

**The beam is stroked in runs**, cut at every sharp turn: a
`Face.Builder.stroke` joint pinches at a right angle, so each straight is its
own stroke with round caps that meet under the mirror that turned it. The
arc round a cup is one run.

**A cup is hit-tested as the box round both its cells.** The first cut tested
each cell on its own with a strict half-cell bound, and the cup's middle --
the line between its cells, and the very point a thumb aims at -- was in
neither. The animation harness found it: its drag pressed there and nothing
moved.

The board's own motion constants: `BEAM_SPEED`, `BEAM_FADE`, `SNAP_TIME`
0.16, `BEAM_DELAY` 0.55 (the light waits for the pieces' entrance),
`SUN_TURN`, `MOTE_SPEED`, `MOTE_DENSITY`, `BLOOM_TIME` 0.7 and `WIN_WAIT`.
Everything else is a recipe from `core/motion.gd`; it added nothing there.

## 8. Measured

`tests/_shot_anim.gd -- sunbeam` at `--resolution 810x1440`, 2026-09-26, on
a Medium 6x7 floor with five pieces:

- **65** draw calls with one piece dragged home (idle mean 4.01-4.08 ms over
  three runs), **68** on the solved floor with the bud open (`full`, 6.18 ms),
  **65** under reduce motion (3.53 ms) -- against the 855 budget.
- ANGLE (`--rendering-driver opengl3_angle`): the same **65**.
- Menu page three, with Sunbeam's card on it: **152** draw calls.
- `tests/_win.gd`: **22/22** winnable, Sunbeam through one hint and four
  real drags.
- Suite: `passed=122585 failed=0`.

The milliseconds are this Mac's and comparable only within a session.

## 9. Open

- **The sounds are prompts only**: `tools/gen_sfx.py sunbeam` generates them
  with ElevenLabs, and a missing file is silence until then.
- **Is it a puzzle?** Section 5's caveat -- the ladder is to be judged by
  playing.
- pt-BR and es strings are machine-fluent and want a native pass, like every
  other board's.
