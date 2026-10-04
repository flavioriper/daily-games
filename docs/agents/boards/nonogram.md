# Nonogram

Board notes (the flat spec `2026-09-18-nonogram-flat-design.md`, its
amendments 11 and 12, and the polish spec `2026-09-30-nonogram-polish-design.md`
hold the rest).

- **The polish pass (2026-09-30)**, unattended, One Line's pattern. Shapes
  are drawn per band from `Gen.SHAPES` (squares, tall and wide) with the
  day's rng before the picture, so a completed day restores the same shape.
  Hard 3 hearts, Insane 1: every tile is judged as it lands, a stroke stops
  at the first wrong one, which blushes and after `EJECT_AFTER` turns out to
  a **locked pebble** (`state.reveal`, dropped from the history like a
  hint's tile). Finished lines lay their pebbles on Hard and Insane in the
  same history entry (`state.apply_more`). Check there looks at pebbles.
- **Leaf Fall (Insane)**: tumbled lines (`state.tumbled`, rows then columns;
  `Gen.reads` compares the multiset). Numbers drawn largest first on leaves;
  leaves live in the floor mesh, numbers are draw_string through the same
  `_line_xf * Transform2D(rot, at)` (`_numbers`). The bank is
  `content/insane/nonogram.json` (`w`, `h`, `bits` row-major, `leaf` rows
  then columns); `Gen.Deep` is the proof and must stay one instance a thread
  (the old static `_line_cache` is not safe in the miner's threads).
  Re-proved 160/160; with the order put back Hard's solver finishes 150 of
  them, so the rule is the difficulty.
- **Life** is three full-rect layers (`Hearts`, `Life`, `Combo`) as on One
  Line; the mushroom and the queen bee (`ui/faces/bee_face.gd`) are nodes.
  The frame, daisies and leaves are in the floor mesh. Peaks 90 at rest on
  Insane, 117 at the party, 50 under reduce motion (ANGLE).
- `tests/_shot_nonogram.gd -- d=<n> rest|right|wrong|solve|restore|perf [rm]`;
  in zsh pass the args through `${=args}` or they arrive as one word.
- **Review findings (2026-09-30), fixed**: auto-pebbles fire only for lines
  the move *brought* to read right (`_ok_lines()` before the move) -- an
  empty line reads right from the start, and re-pebbling it undid a rub-out
  and left two entries for one cell, which `undo()` (now newest first,
  deduplicated) replayed wrong; a hint's pebbles are their own history entry
  (the hint leaves none, so `apply_more` rode on the last stroke); a stroke
  overshooting by one still pebbles the line it finished, skipping the wrong
  cell; the Insane seal no longer says Flawless on the live fallback.
- **Known, not fixed**: a day finished before this pass restores a different
  picture (the shape draw moved the rng; Insane reads the bank), as every
  polish pass that touched a generator has done.
- **The same cold-launch trap elsewhere**: a restore that stamps `now - 10`
  where the clock counts from launch reads as unsolved in the first ten
  seconds when the board tests `_solved_at >= 0`. Pinwheel, Paper Planes,
  Quilt, Queens and Untangle carry that test; not checked here. (Queens and
  Untangle fixed at Queens' checkup, 2026-10-02, with a `-INF` sentinel.)
- **The checkup (2026-10-02)**: the floor was one Builder mesh rebuilt in
  script every animating frame (14 ms full Insane, 33k vertices; a 5-10 ms
  hitch on every stroke event). Now `_build_floor` copies cached shapes
  (`_shape`: socket, row/column tab, leaf, daisy, X, guides, tile at each of
  `GROUT_STEPS`) into fixed runs per piece (`_runs`, laid out in paint order:
  tabs, leaves, daisies, sockets, guides, leaving pieces, pieces; bad tiles
  and the frame go on the tail), colours by fills (`_ink`, cached by
  colours), indices offset once per (shape, base) (`_offsets`). `_prune`
  drops played-out moments so `_resting` pieces skip `_grow`/`_offset`/
  `_shine`. A fading X's alpha is kept in `ALPHA_STEPS`. Pixel-identical at
  rest against the old floor. Probe: `x=ng_count` times one floor build.
- **Tutorial (2026-10-02)**: `ui/hud/nonogram_tutorial_diagram.gd`, a
  quietened board (`Floor.lay()`) dealt a 5x5 house whose door makes two
  rows read 1 3: RUNS, ORDER (over-fill rose, tap to rub out), CROSS, HINT,
  HEARTS (band 2 judged, wrong tile -> X, finished line fills with X's),
  LEAVES (rows 3-4 tumbled). Easy/Medium 4 pages, Hard 5, Insane 5-6.

### Solved by reading lines, no supposition (2026-10-04)

The user: "nonogram, sudoku and queens should be exactly like binairo about no
guess, it should be fully solvable from deduction". Easy to Hard already were
(`Gen.generate` ships a picture only when `solve`'s line logic fills it). Leaf
Fall was not: its bank was proved by `Gen.Deep.deep_solve`, line logic plus
one-cell suppositions, and kept the boards where line logic left over a third
of the grid open (0 of the 160 finished on line logic).

- `Gen.Deep` is `Gen.Lines`; `deep_solve`, `line_open` and `probes` are gone.
  `line_solve()` is line logic to its fixpoint, a tumbled line read in every
  order its numbers allow, and it is the whole proof.
- The ladder (`tools/insane/nonogram_ladder.gd`) puts back one line's order
  while `line_solve` does not fill the picture. The rung is the lines left
  tumbled (`LEAVES_MIN` 8 is the gate); re-mined, 1625 of 3000 candidates
  passed, the 160 kept carry 16 to 19 leaves, all 160 re-proved through
  `from_bank`.
- `NG_TIP_LEAF_2` told the player to suppose a cell; it now says no guessing.
- A banked day finished before this restores a different picture.
- **Insane counts moves (2026-10-04)**, the reference for
  `docs/agents/flat-screens.md`'s rule. `HEARTS` is all zero, so `judged()`
  is false on every band: no wrong tile is turned out, no finished line lays
  its pebbles, and the HEARTS tutorial lesson is unreachable. Leaf Fall
  hands out `target + 3` moves (`State.moves_budget`, `move_cost`): a tile
  laid or rubbed out is one, a cross is free, and a stroke stops where the
  budget does (`_release`). No Undo, Hint (`HINTS_BY_BAND[3]` is 0) or Check.
  Clues still go green and rose as on Medium.
