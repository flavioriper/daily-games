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

### The blue cloth is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/nonogram_world.gd` is the card's
glaze-blue cloth with a faint weave and a window light; two spare tiles, a
pebble and a daisy in the gap of the tools row; and in the foot's corners,
either side of the tray, a small finished heart of tiles on a parchment
tray, a saucer of pebbles and a stitched hem; four glints breathe.

- Registry: `bleed`, `level_card`, no actions row, and **the tile tray
  stays** (`"tray": "tiles"`): a cross cannot be marked without it.
  **Check is gone**: the floor solves itself.
- `opengl3_angle`, 810x1440: 81 draw calls at rest; `tests/_win.gd --
  nonogram` passes.
- Decided for the user, unconfirmed: the tray kept, no Check, an Easy cell
  of 160 uncapped, plain cloth between a wide picture and the tray. Owed:
  a phone, the level slide.

### X's on their own, and a big straight Insane (2026-10-16)

The user: "autofill x but based on current board, not based on the right
answer, just to help user to not need to fill everything all the time. Also,
on insane level instead of having shuffled numbers, keep the same behavior of
others levels but make it way harder and bigger".

- **Auto X on every band**: `_auto_pebbles` lost its `judged()` gate. A line
  a stroke brings to read right (the player's runs equal its clue, `_ok_lines`
  before against after) lays an X in each blank cell, rippling from the
  stroke. It reads the board, not the picture: a wrong row that reads right
  gets its X's too. They ride the stroke's history entry (`apply_more`), so
  one Undo takes both back; a hint's X's are their own entry.
  **Fixed the same day** (the user, with a screenshot of an Easy day whose
  `0` row stayed bare: "not working"): it waited for lines the move *brought*
  to read right and *touched*, so an empty line, right from the deal, never
  got its X's. Now every line reading right fills after every move, rippling
  from the move's last cell when the move did not touch it; an X rubbed out
  of a finished line comes straight back.
  **And again** (the user, a column reading `1 1` with its top tile laid
  and the cell under it bare: "if there is 1 on the column, it can't be the
  following place, should be blocked"): a line's X's are now every blank
  no placement of its runs over the player's tiles can fill
  (`State.shut_in`, `Gen.refine` with the tiles known and everything else
  open). Crosses are not read, so X's never cascade from line to line; a
  line its tiles cannot answer gets none. About 3 ms a move on a 15x15 on
  the Mac.
  **The board's X's go again** (the user: "when user remove a move board
  helper should also remove the blocked that is available now"):
  `State.auto` holds the X's the board laid, each history entry remembers
  whether a cell's old mark was the board's, and after every move an auto
  X no line shuts out any more is lifted in the same entry. The player's
  own X's are never lifted. Undo restores both.
- **Insane is no longer Leaf Fall**: `State.setup` deals band 3 from
  `Gen.hardest` instead of the bank (`content/insane/nonogram.json` and
  `tools/insane/nonogram_ladder.gd` are left, unread). Shapes 15x15, 13x16,
  15x13 (`Gen.SHAPES[3]`); pictures with `INSANE_GRAIN` 0.15 of raw noise;
  of `INSANE_POOL` 12 that line logic fills, the slowest by `Lines.sweeps()`
  (sweeps of every line, then cells open after the first). Over 30 seeds:
  6-16 sweeps with 103-201 cells open after the first, against Hard's 3-4
  and 5-49. 47-124 ms on the Mac to deal. Fallback 12x12 by `Gen.generate`.
  Hints 3, Undo and the tray as on the other bands; the leaf code stays and
  is never reached (`tumbled` all false). `day_dict` says `generator`.
- `opengl3_angle`, 810x1440, `_shot_nonogram.gd -- d=3 right`: 43 px cells,
  peak 92 draw calls. A four-number row clue's first digit sits under its
  daisy at the tab's outer end.
- A day finished on Insane before this restores a different picture.
- Unseen by the user, no phone.

### Every size, and the size printed (2026-10-16)

The user, with a 20 x 20 from the web: "nonogram daily challenges should
have all sort of sizes, grids, numbers ... based on difficulty", and "show
the grid sizing so user can easily know how many rows and columns in total
are".

- `Gen.SHAPES` is six shapes a band: Easy 5-7 a side, Medium 6-10, Hard
  10-15 (12 x 15 the biggest), Insane 13-20 (15 x 13 up to 15 x 20 and
  14 x 20). `State.SIZES` fallbacks 5, 7, 10, 15. The numbers come with the
  size: Hard reaches 12-13, Insane 14 and six numbers a row.
- **Insane grows tall, not wide** (decided for the user): the cell is capped
  by the width, and 20 columns plus the row clues' band is a 30 px cell at
  810 wide. 15 x 20 is a 36 px cell, height-capped. A real 20 x 20 wants a
  zoom first.
- `Gen.hardest`'s pool shrinks with the picture (`INSANE_POOL` 12 at
  `INSANE_CELLS` 225, by the square, never under 4): Insane deals 61-235 ms
  on the Mac over 12 seeds a shape (15 x 20 with the full pool was 350,
  20 x 20 900). Hard deals 2-19 ms.
- `NG_SIZE` ("15 × 20", columns by rows) is drawn under the floor's bottom
  right edge (`_draw_size`, one draw_string); the layout keeps `SIZE_ROW`
  for it; it fades with the scaffolding on the win. `NG_LVL_*` say the
  band's range ("10 to 15 a side"); `NG_LVL_3` said leaf fall till now.
- `opengl3_angle`, 810x1440, `d=3 right` with SHAPES[3] forced to 15 x 20:
  a two-digit row clue (10 3) fits its slots, the label clears the tray.
- A day finished before this restores a different picture (the shape draw
  moved). Unseen by the user, no phone.

### Harder, and every number speaks (2026-10-28)

The user: "players are complaining it's too easy, maybe we should fill X
only when row or column is filled, also for multiple row or column numbers,
we should show them as filled individually as well, right now user is
confused when there is like 1 2 2 1 2 rows or columns, and it only show
filled after filling everything". Built unattended, pushed.

- **The board crosses out a finished line, nothing else**: `State.shut_in`
  returns a line's blanks (and its own X's) only once its tiles read right
  (`Gen.reads`), on every band. The 2026-10-16 rule (every blank no
  placement over the player's tiles can fill, `Gen.refine`) did the line
  logic for the player and is gone; that is what "too easy" was. The
  lifting is unchanged: a line that stops reading right takes its board
  X's back on the same move, and Undo restores both. The generators are
  untouched.
- **A number dims when its own run is surely done** (`Gen.pinned_runs`,
  `State.runs_done`): read off the player's tiles *and* crosses, never the
  picture. A run is done when every way of laying the clue over the board
  (tile = filled, cross = empty, blank = open) puts that run on the same
  cells and they are all tiles: pinned by the edge, by crosses, or by the
  runs beside it. `1 2 2 1 2` with `#.##` laid at the left edge dims the
  1 and the first 2; a 2 boxed by crosses mid-line dims nothing when it
  could be either 2 (Nintendo's Picross rule is "sealed by an X"; ours
  also takes the edge and the neighbours, and refuses an ambiguous seal).
  A line no placement fits dims nothing. Tumbled lines: all or none.
  DP over (run, cell), O(runs x cells) a line, every line after each move
  (`_verdicts`), cached in `_pinned`, never computed in `_draw`.
- Drawn per number: `DONE_A` 0.32 of the ink over `DONE_TIME`, with a
  `Motion.bump_scale` pop as it turns. Green (reads right) and rose
  (over-filled) still win over the dim. No sound: it is not an action.
- Tips `NG_TIP_DONE` and `NG_TIP_X` (en/pt/es) join the cycle.
- Suite 303252/0, `_win.gd -- nonogram` passes, `_shot_nonogram.gd -- d=2
  right` (opengl3_angle, 810x1440) peaks 94 draw calls.
- Owed: a phone, the user's verdict on the dim rule and on whether the
  ambiguous seal should dim "a 2".
