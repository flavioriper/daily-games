# Who Ate the Pie?

- **Who Ate the Pie? is a Puzzles card (2026-10-22, unattended)**, the
  roadmap's tenth, a deduction board under Logic. Bakers in a grid on the
  fête's bake-sale table, some of whom ate the pie; mark each "ate pie" or
  "didn't", and each marked baker says one true clue. A mark stands only
  when the clues showing prove it. Spec
  `docs/superpowers/specs/2026-10-22-pie-design.md`. The id is `pie` and the
  locale prefix `PI_`.
- Files: `puzzles/pie2d.gd` (the board, extends `core/puzzle_base.gd`; the
  clue sentences are written here, `clue_text`), `puzzles/pie_state.gd`
  (marks, slips, the bulb's baker, quality), `puzzles/pie_gen.gd` (the
  clue kinds as sums, the solver and the deal), `puzzles/pie_world.gd`,
  `ui/faces/pie_art.gd` (card, halo, tick, slice, pie, hat, bubble,
  buttons, and the twenty faces), `ui/hud/pie_tutorial_diagram.gd`,
  `ui/menu/cards/pie.gd`.
- **One solver for everything**: `Gen.forced` is what the deal checks every
  round with and what `State.mark` judges a mark with (via `proof()`,
  cached until the next mark). A clue kind added must be added to
  `constraint` (the sum it is), `_sayable` (when it is true) and
  `clue_text` (its words), or the board and the deal disagree.
- **`_find` never decides a baker twice**: a baker in `set` (marked, or
  fixed by `forced` to test the other verdict) is stepped over. Without
  the guard the second branch flipped a fixed "didn't" back to "ate" and
  eaters reached only by combining clues were never proven.
- **Clues are three sums**: SUM (so many of a set), MORE (more of one set
  than another), ODD (odd or even of a set), a bit a baker (20 bits at
  most; `popcount` reads them by a 1024 table).
- **The deal is a wavefront** and a stalled round is a retry: 365 days a
  band in `tests/_probe_pie.gd`, none failed, worst 341 ms (Insane) on the
  Mac. The phone deals its own day; a bank (as Picket Sums') is the way out
  if a phone hitches on opening.
- **A marked card is laid differently from an open one** (small face and
  name on top, the clue under them); the swap happens at the middle of the
  card's turn, so it is never seen. The clue size is fit once a layout to
  the longest clue of the day (`_fit_text`, 32 down to 16 at W).
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram picks with `demo_select` and presses with
  `demo_mark`, always on an Easy deal. Lessons MARK, CLUES, PROOF, DISH,
  HINT.
- **Draw calls**: 123-206 on Easy, 156-270 on Insane (the win's report on
  top is most of the high end), 182-189 a tutorial page, 8 on the card.
- Harness: `tests/_win.gd -- pie` (real touches: an unproven mark refused,
  a proven baker marked wrong for a slip, the bulb's button, then every
  proven baker picked and marked); `tests/_shot_pie.gd -- <dir> d=<0..3>
  [tut=<page>|card]` shoots rest, picked, refused, turning, marked, slip,
  hinted, midway, the win and the reopened day, and prints the day's clues.
