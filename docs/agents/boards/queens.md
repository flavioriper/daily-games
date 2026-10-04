# Queens

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Queens is the precedent for a board that answers a move** (2026-09-19,
  `puzzles/queens2d.gd`, spec `2026-09-19-queens-flat-design.md`). A seated
  queen crosses out every cell she sees; those crosses are **derived** by the
  state (`seen`, a count per cell rebuilt after every change) and never
  stored, so lifting her takes them with her and undo keeps no book for
  them. A crown on a seen cell is **refused**, so two queens can never
  conflict and the n-th queen is the win. The wave is its signature: every
  move goes through one `_settle` that diffs a snapshot of the court against
  the state and hands each changed cell its moment, with a Callable saying
  when -- a queen's king-move distance times `WAVE_STEP` (reversed for a
  lift, far cells first), a sweep's path, Reset's far corner -- and the
  cells the queen sees flash gold (`QUEEN_WASH` at `WAVE_FLASH`) as it
  reaches them. The queen bee (`ui/faces/bee_face.gd`) is the cast's one new
  species since the snail: a chibi bee in a small crown, who replaced a
  plain crown with a face on the evening of 2026-09-19 from the user's
  second mock (`docs/art/concept-queens-bee.png`). Her wings are a second
  layer that beats through `Face._layer_transform`, a squash about her
  shoulder line, so a beat rebuilds no mesh and costs one draw call a bee
  (71 on the strip with a queen seated and the chip alive, against 69). The
  tile tray takes a **chip set** now (`TileTray.MOSAIC`, `TileTray.QUEENS`;
  `"tray": "queens"`), so Nonogram's tray and Queens' are one class.
- **The polish of 2026-09-30** (spec `2026-09-30-queens-polish-design.md`).
  The players' "too many starting single cells" were one-cell patches: the
  repair pass that drives a grown court to a unique answer could shrink a
  patch to one cell, which is a queen handed out before the first thought.
  `Gen.KEEP` forbids it, and `puzzles/queens_logic.gd` grades every court by
  hand logic (singles; bands and reach, one-line and wide; suppositions).
  **Hard is banked, not generated** (`content/insane/queens_hard.json`, mined
  by `tools/mine_insane.gd -- queens_hard`): grading a live 9x9 until one
  fitted cost 184 ms median and 914 ms worst on the Mac. Insane is **Morning
  Mist** (`Gen.mist`): two pairs of neighbouring patches merged into misty
  patches that take two queens; `state.quota` carries it everywhere (the
  seating search, `legal`, `seen`, the hint, the solver), and a queen crosses
  her misty patch only once its second queen sits (`reach_of`). Hard and
  Insane judge every seat: a wrong queen costs a heart, buzzes off and leaves
  a `shown` cross that nothing takes back (not undo, not a sweep, not a
  seat). The misty patches' crown pips ride the life layer so a queen on the
  patch's first cell cannot hide them. `tests/_shot_queens.gd` plays it
  through the real taps (a bare seat takes a cross first); remember zsh's
  `${=args}` when looping its modes.
- **The checkup (2026-10-02)**: the ground (the sink, the wave's, glint's
  and blush's washes, the flowers, the bees' halos and shadows, the leaving
  and standing Xs) was one Builder mesh rebuilt in script every animating
  frame, 9-13 ms on a full Insane court, and the floor (3 ms) with it. The
  floor is now made once a court (the finger's sink moved into the ground as
  a wash in `Pal.TEXT`), and the ground goes through `ui/flat/run_mesh.gd`:
  four shapes (`SHAPE_SQUARE`, `SHAPE_DISC`, `SHAPE_CROSS`, `SHAPE_FLOWER`,
  the flower in three slots: rim, petal, heart) copied into per-cell runs
  laid in paint order (`PART_SINK`, `PART_WASH`, `PART_FLOWER`, `PART_BEE`,
  `PART_GONE`, `PART_CROSS`), alphas kept in `ALPHA_STEPS`/`WASH_STEPS`.
  Shapes and floor are made at `_ref`/`_floor_cell` and drawn scaled, and a
  finished court's relayout (the win card's slide) keeps them: making them
  again there was a 45-75 ms frame. Ground build ~2 ms; pixel-identical at
  rest. `_solved_at` is `-INF` while unsolved: a restore stamps `now - 10`
  and the clock counts from launch, so the old `>= 0` test showed a day
  reopened in its first ten seconds with its crosses and mist crowns.
- **Tutorial (2026-10-02)**: `ui/hud/queens_tutorial_diagram.gd`, a
  quietened board (`Court.lay()`) on a 5x5 court of five patches: SEAT (a
  tap crosses, a second seats; her wave), TOUCH (her corner refused, the
  next queen where she cannot see), CROSS (a stroke lays crosses, one from a
  cross picks them up), HINT (pinned queen refuses a lift), HEARTS (band 2,
  a wrong queen buzzes off and leaves a rose cross), MIST (the last two
  patches run together; one crown of two, then the rest crossed). Easy and
  Medium 4 pages, Hard 5, Insane 6.

### Solved by reasoning, no supposition (2026-10-04)

The user: "nonogram, sudoku and queens should be exactly like binairo about no
guess, it should be fully solvable from deduction". Easy and Medium already
finished on bands and reach. Hard's `fits` let in courts that needed a
supposition (127 of the 200 banked), and Morning Mist's ladder kept only
courts where bands and reach left over half the court open (0 of 180 finished
without supposing).

- `queens_logic.gd` has two rungs. `SUPPOSE`, `Court.suppose`, `probes` and
  the grade's `solved` / `deep` are gone; `Logic.answer` and `from_bank(...,
  true)` prove with bands and reach. Reach (a seat whose queen would leave a
  row, column or patch without room is crossed) stays: it reads the court as
  it stands and follows nothing.
- `Gen.fits`: every band needs `solved2`; Hard is two wide bands.
  `Gen.graded` only ever returns a court reasoning finishes (`REASONED_TRIES`
  more draws when `GRADED_TRIES` found none; 40 seeds in 40 on each of 7, 8,
  9 did).
- Both banks re-mined: Hard 573 of 4000 fit, 200 kept (rungs 300-520);
  Morning Mist 288 of 1600, 180 kept (at least one wide band, rungs
  170-530). All re-proved through `from_bank(board, true)` and counted to
  one seating.
- `QN_TIP_MIST_2` told the player to seat a queen in her head and follow
  her; it now says no guessing and points at counting rows.

### The queen / cross chips go (2026-10-04)

The user: no choosing between queen and X, a tap always goes X then queen.
The board already played that way (`_tap_cycle`: blank -> cross -> queen ->
blank, a drag lays crosses) and ignored the armed chip, so the tray was a
selector that selected nothing. The registry asks for `"tray": "none"` now
and the board's `brush` / `set_brush` stub is deleted. `TileTray.QUEENS` and
the host's `"queens"` case are left in place, unused. Shot at rest on Easy:
no bottom row, board in the same place, 87 draw calls.
