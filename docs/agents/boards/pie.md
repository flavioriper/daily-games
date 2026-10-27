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
  `ui/faces/pie_art.gd` (card, halo, tick, slice, pie, crumbs, bubble,
  buttons), `peeplet/peeplet_personas.gd` (the fifty bakers),
  `ui/hud/pie_tutorial_diagram.gd`, `ui/menu/cards/pie.gd`.
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
  band in `tests/_probe_pie.gd`, none failed, worst 240 ms (Hard) on the
  Mac since 2026-10-26 (341 ms Insane before).
- **Several bakers open at once (2026-10-26, made fun)**: the user, "make
  who ate the pie experience way better to play, and game itself way
  funnier to play, right now nobody likes it". Measured first
  (`tests/_probe_pie_fun.gd`, 100 days a band, a player marking a random
  proven baker): 48/55/46/42% of steps had exactly one baker proven, 1.6-2.0
  on average, and a random tapper was refused 2.2-5.4 times a step, free,
  so tapping round beat reading. The deal's speakers were chosen to prove
  nothing ("quiet") but the last of a round. Now every speaker's clue
  proves 1..`want` bakers beyond what was already proven (`_choose`, the
  fewest past one when ten tries miss); `want` 3/2/1/1. After: one-baker
  steps 24/17/12/11%, 2.4/2.7/3.2/3.4 open, refusals a step 1.2/1.7/2.1/2.6,
  the new clue speaks of a proven baker 76-80% of steps (69-75 before).
- **The bulb is two presses, a bulb each** (the no-guess dailies' two-step
  hint): the first rings the fewest clues that prove somebody
  (`Gen.reasons` drops speakers one at a time while the baker stays proven;
  `State.nudge` takes the proven baker with the fewest, the picked one on a
  tie) and says "The glowing clues prove somebody. Who?"; the rings breathe
  until that baker is marked. A second press while they stand marks the
  baker. A baker marked while the rings stand counts as the bulb's (yellow
  in the share). Bulbs 4/3/2/2 (were 3/2/1/1, one press a mark). When
  the dish alone proves the baker (every eater found, or every other baker
  cleared) there is no card to light and the first press marks them.
- **An open baker picked rings every marked clue that speaks of them**
  (`State.leads`) and the bubble counts them under the question ("2 ringed
  clues speak of Jo"); the last clue's fading rings are cleared then, or
  they read as clues about the picked baker. **A marked baker tapped while
  picked dims their clue** (the player's note that it is spent; not
  saved). **A caught baker owns up** in the bubble over their clue for
  `QUIP_TIME` (PI_QUIP_0..7, by place) and wears crumbs on their chin
  (`Art.crumbs`). The bubble is 252 at W (was 214) for the count line.
- Calls the user has not made: refusals stay free (as the genre's), the
  dim is unsaved, the quips' voice, the band wants. The phone deals its own day; a bank (as Picket Sums') is the way out
  if a phone hitches on opening.
- **A marked card is laid differently from an open one** (small face and
  name on top, the clue under them); the swap happens at the middle of the
  card's turn, so it is never seen. The clue size is fit once a layout to
  the longest clue of the day (`_fit_text`, 32 down to 16 at W).
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram picks with `demo_select` and presses with
  `demo_mark`, always on an Easy deal. Lessons MARK, CLUES, PROOF, DISH,
  HINT.
- **Draw calls**: 151-251 on Hard and 168-276 on Insane since 2026-10-26; before, 123-206 on Easy, 156-270 on Insane (the win's report on
  top is most of the high end), 182-189 a tutorial page, 8 on the card.
- Harness: `tests/_win.gd -- pie` (real touches: an unproven mark refused,
  a proven baker marked wrong for a slip, the bulb's button, then every
  proven baker picked and marked); `tests/_shot_pie.gd -- <dir> d=<0..3>
  [tut=<page>|card]` shoots rest, picked, refused, turning, marked, slip,
  nudged, hinted, leads, quip, dimmed, midway, the win and the reopened day, and prints the day's clues.
- **Caught is crust, not berry (2026-10-27)**: the user, "the red color
  when someone ate the pie is making users confused, look like it's wrong".
  Berry is the house's wrong, so the "ate" card paper, its badge plate, the
  "Ate pie" button and the caught ring moved to baked crust (`Art.ATE*`);
  berry stays only on slips and the "says otherwise" line, and 🟥 in the
  share is still a slip.
- **The bakers are Peeplets (2026-10-27)**: the user, "switch the fruits
  with peeplets char personas". Fifty personas in
  `peeplet/peeplet_personas.gd` (name, coat, hat, eyewear, two traits, a
  line; no two share coat and hat; append only, a day keeps them by
  index). The deal shuffles the fifty after the clues (the clue rng is
  untouched) and sorts the day's n by name. Each baker is a live
  `ui/peeplet_view.gd` in `_cast`, seated by `_draw_card` under the card's
  own transform (drop, shiver, hop, flip, dim) and shown only when seated;
  crumbs go on `_over` above them. The views hold their frame
  (`idle_fps` 0): the picked baker breathes at 12, a marked baker laughs
  (walker `laugh_time`, silent, the board has its sounds), the win laughs
  along its wave. The first game screen that loads a model, on the user's
  word. Draw calls on Insane 143-252 (were 168-276); the menu card 10.
  The persona page: https://claude.ai/artifact/LaPmKwPhMwxqDJzhQPZ6X2
  (renders by `tests/_shot_peeplet_personas.gd`). Owed: a phone run (20
  SubViewports on Insane, MSAA 4x each), the traits and lines are not in
  the game (they need locale rows first).
