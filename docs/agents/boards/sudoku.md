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
- **The polish pass** (2026-09-30, spec `2026-09-30-sudoku-polish-design.md`)
  made Hard and Insane losable and gave Insane a rule of its own. Hard and
  Insane judge every number as it lands (`State.HEARTS` 3 and 2): a wrong
  one blushes, splits a heart and tumbles off the paper, and that number is
  crossed out of that cell for good (`state.reject`, `state.ruled`, out of
  the history; placing it again is refused free). A right number there is
  kept (`State.KEPT`) and Check is left out (`capabilities()`), since no
  wrong number can stand. Out of hearts is Queens' dusk and
  `out_of_hearts.gd` with `SD_OUT_*`; hints are 3/3/1/0. **Insane is
  Hilltops**: some cells carry a mound with 0 to 4 dots counting the
  orthogonal neighbours holding a smaller number (`Gen.beside`,
  `Gen.hill_count`, `state.hills`), 15-16 givens -- under the seventeen no
  plain grid can reach -- dug by a count that propagates singles and the
  hills' reckoning at every node (`_count_hills`; the plain backtracking
  count took over a minute a grid at that depth), graded by a player-like
  solver with suppositions (`Gen.solve_logic`) and **banked**
  (`content/insane/sudoku.json`, `tools/insane/sudoku_ladder.gd`). The
  miner's threads share Gen's static tables, so the ladder warms them on
  load and `use()` never clears them when the size stands (it crashed with
  `Array::_ref` before). Easy to Hard deal the very grids they dealt before
  (0 of 60 seeds differ). Rewards: the streak with the x3 bubble and
  confetti, three gags (hearts, a twirl, a boing), all of a number home
  hops, a daisy sticker on every finished region, and a party (dance,
  confetti, number wisdom, the seal; the night seal on Insane). The win
  card got its own words (`flat_win`, no mascot). `tests/_shot_sudoku.gd`
  drives every scenario.
- **The board checkup** (2026-10-02, `docs/agents/checkup.md` row 14). The
  grid's mesh is put together by a `ui/flat/run_mesh.gd` (`_rm`, reset on
  every layout) from shapes made at the cell (`_make_shape`): the tray, its
  floor and the panels as one shape in their own colours (`SHAPE_BASE`, and
  `SHAPE_BASE_GLOW` once the win's warmth is full; drawn live only while it
  rises and its glint goes round), each wash, twin coin and wave gold the one
  shape under its cell's shiver and bump (on the tail, `_tail_offsets`), a
  region's daisy open (`SHAPE_DAISY + region`, a run each), the selected
  tile (`SHAPE_SEL`, its face again for the wave's gold) and a hill at rest
  (`_hill_id`, a run each); a landing, a hill's reach and a hill or daisy on
  the move are drawn live. The pad (`ui/flat/digit_pad.gd`) paints its chips
  from one `Paint` control. The tutorial (`ui/hud/sudoku_tutorial_diagram.gd`)
  is the board itself, quietened (`Sheet`), dealt a fixed answer of the
  band's size (Gen holds one size at a time, so the page plays the size the
  board behind it is on), laid out by the page (`left`, `hearts_at`,
  `_hearts_x()`), with the real `DigitPad` scaled beside it and the finger
  firing its chips; the Hilltops page magnifies the grid about its hill.

### Solved by reasoning, no guess (2026-10-04)

The user: "nonogram, sudoku and queens should be exactly like binairo about no
guess, it should be fully solvable from deduction". Before this the dig asked
only for one answer: of 60 nines dug that way 41 fell to singles, 7 to the
pencil's steps and **12 to neither**, and Hard kept the first that singles did
not finish, so most Hard days wanted a guess or a technique nobody here knows.
Insane's bank was graded with suppositions (0 of 200 finished without one).

- **The dig asks a reasoner, not a count.** `Gen.deduce(puz, tier, hills)`:
  `SINGLES` (a cell with one number left, a number with one cell left), and
  `PENCIL` adds `_locked` (a number held to one line of a region, or one
  region of a line), `_naked_pairs` and `_hidden_pairs`, tried only when
  singles stall; the hills' reckoning joins when there are hills. `dig` keeps
  a pair out only while `deduce` still finishes, so a deadline's shallow grid
  is still a fair one and `count_solutions` is left to the tests.
  `Gen.TIER`: Easy `SINGLES`, the rest `PENCIL`. `solve_logic` and its
  suppositions are gone.
- **`graded`** now means within `GIVENS_SLACK` of the target and, on the nine,
  that singles stall. A mini dug by reasoning never wanted the pencil (0 in
  60), so Medium is a mini with fewer givens (10-12 against Easy's 14), as it
  mostly was (24 of 30 fell to singles before).
- **Hard is banked** (`content/insane/sudoku_hard.json`, 300 grids,
  `tools/insane/sudoku_hard_ladder.gd`, `mine_insane.gd -- sudoku_hard`): one
  reasoned nine in eight stalls singles, and drawing until one does cost
  194 ms mean and 313 ms worst on the Mac. Every banked grid wants the pencil
  and none a guess; 25-30 givens. The live deal is the fallback
  (`sudoku_state.setup`), reasoned too, graded when the budget allows.
- **Hilltops** digs and prunes its hills by `deduce` as well, and still
  lands on 15 givens (9-17 hills) -- under the seventeen, so
  `SD_RULES_HILLS` stands. Re-mined, 640 of 640 passed, 200 kept, all
  re-proved through `from_bank` and counted to one answer. A live deal took
  225 ms mean (budget 900).
- `_propagate` settles a cell against its peers once and finds a unit's lone
  numbers with two masks (`once`, `twice`): a nine's dig is ~30 ms.
- `SD_TIP_HILLS_2` told the player to suppose a number; it now says no
  guessing. The hint still picks the cell with fewest numbers left, not a
  cell one step of reasoning fills (Binairo's does).
- Easy to Hard deal different grids than before; a day finished earlier
  restores another.

### Insane counts moves (2026-10-04)

- **Insane counts moves, and no band has hearts** (2026-10-04,
  `docs/agents/flat-screens.md`, "Insane counts moves"). `State.HEARTS` is
  `[0, 0, 0, 0]`, so `judged()` is false everywhere: no number tumbles off,
  none is ruled out of a cell (`RULED`) and a right one is no longer kept
  (`KEPT`); that code stays, unreached. Hilltops plays as Medium does on
  feedback -- a clash turns rose, a finished unit waves, a hill that comes
  true turns gold, all read off the player's own numbers. Budget:
  `State.moves_budget()` = the grid's empty cells + 3 (15 givens is 69). A
  number written costs one (over a blank or over another number), a number
  tapped back out or taken by the cross costs one, pencil marks and rubbing
  them out are free (`move_cost`, `erase_cost`). No Undo, hint or Check on
  Insane, so the tutorial drops its Undo page there and the slip page reads
  `HTP_SD_MISTAKE_BODY_MOVES`; rules end on `SD_RULES_MOVES`.
  `completion_record` keeps `moves` beside `hearts`. **Still wrong and not
  this pass's to fix**: `SD_RULES` ends on a sentence about Check, which
  Insane does not have (it was already untrue on a judged band).
