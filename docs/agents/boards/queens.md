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
