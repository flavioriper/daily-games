# Sudoku

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Sudoku is the fourteenth board, and the second in a row that was added
  rather than swapped in** (2026-09-20, `puzzles/sudoku2d.gd`, spec
  `2026-09-20-sudoku-flat-design.md`, mock
  `docs/brainstorm/concepts.html#sudoku`). It joins Nonogram in seating no
  character at all: its pieces are numerals in ink, and `ui/faces/` gets
  nothing. **The cell is 100, not 104.9.** A 28 inset off the 1000 board
  card leaves 944, and nine cells would fit at 104.9 flush to the edge --
  but the grid is **900**, nine cells of a round 100, because the 6-wide
  heavy rule that marks off the regions is drawn *round* the grid rather
  than inside it, and a grid pushed to the inset's edge has nowhere to put
  that rule. 100 was the second-smallest cell any flat board asked of a
  thumb when it landed, a hair under Queens' and Nonogram's 103 -- Paper
  Planes' 58 and Bridges' hard-band 84 have since put it fourth -- and it
  is bearable for the same
  reason a small cell always is here: a tap on the grid **only ever
  selects**, nothing is typed on it, and the thing tapped next is the pad.
  **The pad's chip is 91 wide** -- `(1000 - 9*10) / 10 = 91` for ten chips
  and nine 10-gaps -- and that is not a new number: it is
  `ui/flat/key_board.gd`'s own `KEY.x`, Hidden Word's keyboard arithmetic,
  so a thumb here has exactly the room it already has on a shipped screen.
  **There is no eraser chip.** The tenth chip is the pencil, a real mode (the
  only one on the screen, lit in `SUN` with a `PAPER` glyph while it is on),
  and the rule that buys its place in the row is Nonogram's: **tapping the
  digit a cell already holds clears it**, one tap instead of two, so nothing
  needs a second chip just to undo the first. **The wave is its signature**,
  Queens' `_settle` with a unit in place of a queen's sight: finishing a row,
  column or region lights every cell of it gold, king-move steps out from the
  cell that closed it, derived off a snapshot diff rather than stored, so an
  undo that reopens a unit leaves no highlight behind to clean up. The
  generator (`puzzles/sudoku_gen.gd`) is seeded, symmetric and graded to a
  uniqueness count under a 300&nbsp;ms budget, past which it gives up and
  hands back `graded: false` rather than block the board opening -- and the
  budget is the one figure on this board that cannot be trusted from this
  Mac, and two different sessions timed it rather than one. **Task 2's own
  calibrated probe** (twelve seeds a band, two full readings) has the worst
  seed in the suite (band 2, seed 9203) at **193-195 ms in GDScript on this
  Mac** -- band 0 ~4 ms mean / 7 ms worst, band 1 ~60 ms mean / 142 ms worst,
  band 2 ~66 ms mean / 193-195 ms worst -- against **9 ms** for the same
  algorithm in JavaScript on the concept page. **Task 5's review round timed
  the same seed again**, ad hoc and from a different throwaway probe, while
  chasing the suite's live-clock flake: five separate readings of **196.5,
  198.4, 198.4, 201.3 and 201.5 ms**. The two sessions never claimed to be
  the same measurement -- one is the spec's calibrated per-band sweep, the
  other is an incident probe reproducing one seed under load -- and the
  honest range this file can stand behind for that seed on this Mac is
  **193-201.5 ms** across both. **A phone is commonly two to three times
  slower than this Mac**, so a worst-case ~200 ms here is plausibly
  400-600 ms on device, which is past the 300 ms budget: a hard day on a
  phone can plausibly fall back to `graded: false` where this Mac never
  does, and hand the player an accidentally gentler grid than the generator
  meant to. Nothing on this Mac can measure that; it is the one thing in
  this board to feel on the phone rather than read off a log.
  Measured with `tests/_shot_anim.gd -- sudoku` at `--resolution 810x1440`,
  2026-09-20: **87** draw calls bare (twice, and again on the phone's
  `--rendering-driver opengl3_angle`, settled frames matching the default
  driver to within 1/255 on edge antialiasing alone), 88 once with a hint's
  ring live, and 110 once on the win screen after a full solve -- all well
  inside the 855 budget.
