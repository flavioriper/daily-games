# Sudoku, flat: the thirteenth screen

Status: designed 2026-09-20. Concept page:
`docs/brainstorm/concepts.html#sudoku`, which plays the real generated
puzzle and is where every measured number below was taken. Reference:
`docs/art/concept-sudoku.png`, the user's mock, which this spec ports where
the family's chrome allows and departs from where it says so. Sibling specs:
the nine `2026-09-18-*-flat-design.md`, plus `2026-09-19-queens-flat-design.md`
and `...-hidden-word-flat-design.md`. Nonogram's is the closest, because the
screen has the same rows.

Nine by nine, cut into nine three-by-three regions. Every row, every column
and every region holds 1 to 9 exactly once. Nobody needs the rules explained,
which is what makes this board unusual to design: **the whole of the work is
in what a 100-pixel cell can be made to say**, not in what the game is.

Two things follow from that, and they are this screen's contribution:

- **The board answers the selection.** Touch a cell and its peers wash pale,
  its twins wash stronger, and any clash washes warm. All three are derived
  and none is stored.
- **The board answers a finished unit.** The instant a row, a column or a
  region comes right it lights up in a wave from the cell that finished it.
  That is Sudoku's signature, the way the flip is Hidden Word's.

**It is also the first card that does not fit on the first screen.** Twelve
cards is not a taste; it is what four rows of 252 buy. Section 9 grows the
grid a second page, and pays nothing for it.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `puzzles/sudoku_gen.gd` | new | A seeded solution, the symmetric dig, the uniqueness count and the singles grader. |
| `puzzles/sudoku_state.gd` | new | The rules, scene-free: givens, grid, pencil marks, the move log, and everything derived. |
| `puzzles/sudoku2d.gd` | new | The flat board: the cells, the rules, the digits, the marks, the washes and the wave. |
| `ui/flat/digit_pad.gd` | new | The tray: ten chips, 1&ndash;9 and the pencil. |
| `ui/flat/flat_host.gd` | edit | One `match` arm: `"tray": "digits"` builds the digit pad. |
| `core/palette.gd` | edit | Two colours: `GRID_RULE` and the region tint. |
| `ui/registry.gd` | edit | `sudoku` joins the grid as the thirteenth card. |
| `ui/menu.gd` | edit | The grid pages twelve at a time; the entrance staggers within a page. |
| `ui/menu/day_row.gd` | edit | The pager: prev, two dots, next, in the cluster the dead chevron already sits in. |
| `ui/menu/card_art.gd` | edit | One branch: a 3&times;3 fragment with three numerals. |
| `tests/test_sudoku.gd`, `tests/run_tests.gd` | new, edit | The generator's guarantees and the move log's. |
| `tests/_win.gd`, `tests/_shot_anim.gd` | edit | A solve branch and a tap branch. |
| `docs/art/flat-motion.md`, `CLAUDE.md` | edit | The Sudoku row; thirteen cards on two pages. |

**What is not built.** No new character: `ui/faces/` gets nothing. Sudoku's
pieces are numbers, and the only face on the screen is the shared sprout on
the tip card and the win. Nonogram decided this and Hidden Word confirmed it;
this is the third board to add nothing to the cast, and the rule in
`CLAUDE.md` is to check `ui/faces/` before drawing anything, which this does.

## 2. What the mock gives and what it does not

`docs/art/concept-sudoku.png`, the user's mock of 2026-09-20.

**Taken from it:** the 9&times;9 with its heavy region rules and its
alternating region tint; the single gold selected cell; the givens in ink;
the row of number keys under the board; the day card; the tip card with the
sprout; the four top-bar buttons; the hint's badge of three.

**Not built, and why:**

- **The three hearts on the day card.** There are no lives. That was settled
  on 2026-09-18 and it holds: a wrong digit is just a wrong digit, Check is
  what finds it, and nothing on this game counts anything. `flat_day_card.gd`
  has no hearts and gains none.
- **The crown and cross buttons in the actions row.** That row is Reset and
  Check on every flat screen. The mock has borrowed Queens' tray chips into
  it; Undo and Hint live in the top bar here as they do on eleven other
  boards.
- **The wooden frame, the vines and the signpost.** A flat board stands on
  paper, not on furniture. The frame becomes the heavy rule drawn round the
  grid, which is what it was doing anyway.
- **The eraser key.** Section 5 replaces it with the pencil and gives the
  reason.

## 3. Where it stands on the first screen

Sudoku is the **thirteenth** card, and it displaces nothing. This branch is
cut from `main`, where `Registry.PUZZLES` is eleven live cards and Pipes'
dimmed `SOON` &mdash; twelve, a full grid. Word Trail is claiming that `SOON`
slot on a parallel branch, so after both land the grid is twelve live cards
and Sudoku is still the thirteenth entry either way. **Nothing here depends
on which of the two merges first**, and the only shared files are
`ui/registry.gd`, `ui/menu/card_art.gd`, `docs/brainstorm/concepts.html` and
`CLAUDE.md`, all of which take an added block rather than a changed one.

Section 9 is how the thirteenth card gets a seat.

Registry entry, in `Registry.PUZZLES`, last:

```gdscript
{
    "id": "sudoku",
    "kind": "puzzle",
    "title": "Sudoku",
    "blurb": "Every number once in every row, column and region.",
    "short": "Every number once,\nevery way you look.",
    "motto": "Every number has its place",
    "footer": "Scan · Place · Complete",
    # Ten chips -- 1 to 9 and the pencil -- so it asks for the digit pad.
    # Everything else is the default: it keeps the actions row and the tip
    # card, which makes it the plainest board in the registry to wire.
    "script": "res://puzzles/sudoku2d.gd",
    "shell": "flat",
    "tray": "digits",
    "difficulties": [0, 1, 2],
}
```

`short` is 17 and 18 characters a line, which is the card's budget at 320
wide. There is no `legacy` and no island twin: Sudoku has never been on the
3D stage and never will be.

## 4. The screen, measured

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `SUDOKU` in ink with the leaf, `EVERY NUMBER ONCE` under, then Undo, Hint with its count, Settings. |
| Day card | 120 | A tree, `Day N`, the island name. The mock's, without its hearts. |
| Board card | **1000** | The grid, and nothing else. Section 5. |
| Digit pad | 170 | Ten chips. Section 6. |
| Actions | 130 | Reset in paper at the left, Check in sun at the right. |
| Tip card | 140 | The sprout, its line, and the door to the rules sheet. |

With 40 of margin and 20 between rows that is **1920 exactly**, and the 1000
is not a choice &mdash; it is what `ui/flat/flat_host.gd` hands back. The host
measures its bottom slot from the rows it actually built:
`170 + 20 + 130 + 20 + 140 = 480`, and `1840 − 320 − 40 − 480 = 1000`.

**480 is the widest bottom slot in the game**, twenty more than Binairo's and
Nonogram's 460, and Sudoku is the first board since Nonogram to want all
three bottom rows.

`capabilities()` is `["undo", "hint", "check"]`, so the top bar is the
ordinary four buttons and `with_reset` stays false. `card_height(available)`
returns everything it is given and `card_centred()` never comes up: the grid
is square and so is the space, so the slack is zero in both directions. **This
board asks the chrome for nothing new** &mdash; no `"actions": false`, no
`"tip": false`, no new optional on `PuzzleBase`. One registry line and one
tray class is the whole of the wiring.

## 5. The grid

Inside the board card a 28 inset leaves **944**. Nine cells would fit at
104.9. The grid is **900 &mdash; nine cells of 100** &mdash; and the 22 of hem
either side is what the heavy rule stands in: it is drawn *round* the grid,
6 wide, and a grid pushed to the inset's edge has nowhere to put it. A round
100 is also what makes a pencil mark legible, because each of the nine sits
in a third of a cell and 33 is the smallest square a 26 px numeral reads in.

**100 is the second-smallest cell any flat board asks of a thumb**, a hair
under Queens' and Nonogram's 103 and well under Hidden Word's 149. It is the
price of nine columns and it is bearable because **a tap on the grid only
ever selects**: nothing is typed there, and the thing tapped next is a
91&times;130 chip. Section 12 lists it as a call to judge on the phone.

Colour:

| Name | Hex | Where |
|---|---|---|
| `Pal.SURFACE` | `#fffdf8` | A cell in a pale region. |
| `Pal.GRID_TINT` | `#f9f3e7` | A cell in a shaded region: `SURFACE` 55% of the way to `PARCHMENT`. New. The mock's own chequer, and what makes nine columns read as three. |
| `Pal.GRID_RULE` | `#a3855f` | The heavy rule between regions and round the grid, 6 wide. New: `BARK` is too dark on cream at that width and `LINE` too faint to read as a region edge, so this is `BARK` 38% of the way to `PARCHMENT`. |
| `Pal.LINE` at 0.8 | `#b8a892` | The thin rule between cells, 2 wide. |
| `Pal.TEXT` | `#3b3028` | A given. It never changes and it never washes. |
| `Pal.LEAF_DEEP` | `#4f8a31` | **A digit the player put there.** One colour is all it takes to tell a guess from a given, and green is this game's own word for something that grew. |
| `Pal.TEXT_DIM` | `#8a7b6b` | A pencil mark, 26 px in a third of a cell. |

A hint's digit is the player's colour, not a third one: it is in the grid
because the player asked for it, and the hint count in the top bar is where
that is recorded.

## 6. The digit pad

`ui/flat/digit_pad.gd`, `HEIGHT` 170: one row of ten chips 130 tall, a 10
lift over them and 30 of air under &mdash; `130 + 10 + 30`. A chip is
**`(1000 − 9×10)/10 = 91` wide**, and that is not a new number: it is
`ui/flat/key_board.gd`'s `KEY` width exactly, so a thumb here has the room it
already has on a shipped screen, and ten chips with nine 10-gaps close on the
1000 column.

A chip is a **direct action, not a brush** &mdash; Code Break's friend chips
and Hidden Word's keys are the precedent, not Nonogram's tray. Tapping `5`
writes a 5 into the selected cell and nothing stays armed. The one exception
is the pencil, which *is* a mode, and it is the only mode on the screen, so
it is drawn lit in `SUN` with a `PAPER` glyph while it is on.

**The tenth chip is the pencil, not an eraser.** The mock draws an eraser and
this drops it, for Nonogram's stated reason &mdash; *"no eraser chip here and
no mode to get stuck in"*. **Tapping the digit a cell already holds takes it
out again**, which is one tap rather than two and is what every phone sudoku
already does. That buys the row back for the pencil, which a 9&times;9 at 30
givens genuinely needs and which has nowhere else to go: eleven chips would
be 82 wide, under the keyboard's own floor, and a pencil in the top bar is
four hundred pixels from the numbers it modifies.

**A digit already placed nine times goes pale and stops answering.** It costs
one count and closes off a whole class of wasted tap: the pad is the only
place on the screen that can say *there are no more of these*.

Each chip stands in its own slot, a plain `Control` the `Button` sits inside.
That is the lesson Balance's weight cards paid for on 2026-09-18: a container
rewrites its children's positions on every sort, and a chip that presses
writes its own.

The pad is driven by the host like every other tray: `refresh(puzzle)` reads
the counts and the pencil's state back off the board, so the board owns both.

## 7. The state is the one truth

`puzzles/sudoku_state.gd`, scene-free and with no `Node` in it.

```
given   PackedByteArray(81)   the puzzle's own digits, 0 where empty
grid    PackedByteArray(81)   what is on the board now, givens included
notes   PackedInt32Array(81)  a nine-bit mask a cell
sol     PackedByteArray(81)   the answer
log     Array[Dictionary]     the move log
```

Three moves write to it and nothing else does:

- **`place(i, d)`.** Refused at a given &mdash; the cell shivers and the tip
  card says so. If `grid[i] == d` the cell is cleared. Otherwise `d` goes in,
  the cell's own marks are dropped, and **`d` is struck off every peer's
  pencil marks**, each strike recorded.
- **`mark(i, d)`.** Refused at a given or at a filled cell. Toggles the bit.
- **`undo()`.** Pops the log, puts the digit and the cell's own marks back,
  and **re-adds the struck bit to every peer it was taken from**. That last
  clause is the fiddly half of this class and the part a test earns its keep
  on.

Everything the screen draws beyond the digits is **derived on every read and
never stored**:

- `peers(i)` &mdash; the twenty cells that share a row, a column or a region.
- `twins(i)` &mdash; every other cell holding `grid[i]`.
- `clashes()` &mdash; every cell whose digit is repeated in one of its units.
- `unit_done(u)` &mdash; a unit holding all nine.
- `remaining(d)` &mdash; nine minus how many of `d` are placed.

That is Queens' rule (`2026-09-19-queens-flat-design.md`, section 3), and it
is the reason undo cannot leave a stale highlight behind: there is no
highlight to leave.

**A wrong digit is allowed to stand.** Nothing refuses a move that clashes.
Spotting your own mistake is the game, so a clash is washed faintly while it
stands and `check()` is what names it. That is the opposite of the Queens
decision, deliberately: Queens refuses a conflicting crown because the
crossing-out has already told the player the cell is barred, and Sudoku tells
the player nothing they did not work out.

**There is no way to end this board without solving it.** It is not Hidden
Word and it cannot run out, so `finish_unsolved()` is never called and
`puzzle_complete` only ever carries `solved: true`.

`check()` marks every non-given cell whose digit differs from `sol` and
returns the count, which is the contract `PuzzleBase` already documents.
`hint()` fills one cell from `sol`, and there are **three**, the mock's
number.

## 8. The generator

`puzzles/sudoku_gen.gd`, seeded from the day so a board is the same on every
phone.

1. **A full solution** by randomised backtracking over nine-bit row, column
   and region masks.
2. **The dig.** Take cells out in a shuffled order, in **180-degree pairs**,
   so the givens read as a pattern and not as spilled salt. Keep a cell out
   only while a counting solver capped at two still finds exactly one
   solution.
3. **The grade.** Solve the dug puzzle with naked singles and hidden singles
   alone &mdash; the two moves a player makes without writing anything down.
   Easy must fall to that pair; medium and hard must not.
4. **Ten tries**, then whatever the tenth gave. A band is a tendency, and a
   hung generator is worse than a medium day labelled hard.

| Band | Target givens | Measured givens | Falls to singles | Generate (JS) |
|---|---|---|---|---|
| Easy | 36 | 35&ndash;36 (mean 35.1) | 12 / 12, as intended | 1 ms mean, 5 ms worst |
| Medium | 30 | 29&ndash;30 (mean 29.4) | 2 / 12 slip through | 2 ms mean, 3 ms worst |
| Hard | 26 | 25&ndash;28 (mean 26.7) | 0 / 12 | 3 ms mean, 9 ms worst |

Measured on the concept page over twelve seeds a band, 2026-09-20. All 36
puzzles were checked to have **exactly one solution** and every given to
agree with it. Two mediums in twelve falling to singles is recorded rather
than hidden: the middle band is allowed to be gentle, and ten tries is where
the cost stops being free.

### The one real risk in this board

Nine ms in JavaScript is nothing. **The same nest of loops in GDScript is
commonly thirty to eighty times slower**, which puts the worst case somewhere
between a quarter of a second and three quarters of one &mdash; at board
open, on a phone, inside `build()`. Nothing else in this repo does that much
work to start a board.

What the implementation must do, and these are requirements and not advice:

- Write the solver over `PackedInt32Array` with the same bitmasks and no
  allocation inside the recursion.
- Cap the attempt budget and **fall back to a shallower dig rather than
  hang**. A board that opens with 32 givens on a hard day is a disappointment;
  a board that does not open is a crash.
- **Measure it with a throwaway probe before the board is called done**, over
  the same twelve seeds a band, and record the real number in `CLAUDE.md`
  next to the JS one.

If it cannot be made to fit, the fallback is a pack of pre-generated grids in
`content/sudoku.json`, which is exactly how Hidden Word ships its words
&mdash; and `content/*` is already in the export preset's `include_filter`
because of it.

## 9. The first screen grows a second page

Twelve is what 80 of margin, 60 of gaps, a 380 header, a 180 day row and a
150 bar leave for four rows of 252. A thirteenth card has to come from
somewhere, and the three candidates cost:

- **A pager row under the grid**, the campsite's own pattern, costs 60 out of
  the pictures: the card drops 252 to 237 and the picture 92 to 77, which
  re-opens the 320&times;118 card-art budget on all twelve existing cards.
- **A shorter header**, 380 to 320, keeps the cards whole and takes a sixth
  off the screen's signature.
- **The day row**, which is 180 tall and already carries a chevron that does
  nothing. **This is the one taken**, with the user on 2026-09-20.

`ui/menu/day_row.gd` gains a pager in its right-hand cluster: a prev chevron,
two dots and a next chevron, with the dead chevron becoming next. It **costs
no height at all**. Cards stay 252 with their 92 pictures, and every measured
figure in `CLAUDE.md` &mdash; the 311 draw calls, the 252 card, the
320&times;118 art box, the seventeen characters a line of `short` &mdash;
survives untouched. The row spends about 620 of its 1000 today and the pager
wants about 180 of the rest, so the hearts stay where they are and stay
decoration.

**The split is 12 + 1**, not 7 + 6. Page one stays exactly the twelve cards
in exactly the order they are in; page two holds Sudoku alone until a
fourteenth board lands. It looks sparse and it is honest: rebalancing would
change the shape of the first screen for twelve boards to flatter one.

Three consequences to build rather than discover:

- **The entrance stagger is per page.** `ui/menu.gd` currently staggers on
  `Motion.stagger(i, CARD_STEP, CARD_CAP)` with `i` an index into
  `Registry.PUZZLES` entire. With pages, `i` has to be the index *within the
  page*, or page two's single card waits out twelve cards' worth of stagger
  before it appears.
- **A page change is not an entrance.** Turning the page fades the outgoing
  cards and plays the incoming ones' entrance with the same per-page stagger.
  It does not rebuild the header, the day row or the bar.
- **The page resets to one on every return from a board**, in `_show_list`.
  Coming back from Sudoku onto a page whose only card is Sudoku is a dead
  end.

## 10. What the board says when you touch it

This is the whole of the design, because the rules are not in question and
the readability is. Tapping a cell selects it; tapping it again clears the
selection. Four washes come off that one fact, all derived:

| Wash | Colour | What it means |
|---|---|---|
| Selected | `SUN` at 0.34, gold edge 5 | The cell the pad will write into. |
| Twins | `SUN` at 0.20 | Every other cell holding the selected cell's digit. **The most useful scan in sudoku**, and the reason the selection survives the tap. |
| Peers | `SUN` at 0.08 | The selected cell's row, column and region: the twenty it cannot repeat. |
| Clash | `BAD` at 0.10 | Two of the same digit seeing each other. Faint on purpose: a note, not an accusation. |
| Checked wrong | `BAD` at 0.22, digit in `BAD` | What the last Check found. Cleared for a cell the moment it is touched again. |

**A clash and a mistake are two different things, and the board says both
differently.** A clash is visible with no solution in hand &mdash; two 7s in
a row is wrong on its face, so drawing it costs the player nothing they could
not see. A wrong digit that clashes with nothing needs the answer to find,
which is what Check is for and what it spends a count on. Drawing the first
faintly and the second only on request is the line this board draws between
helping and playing for you.

**A refusal is a line on the tip card, never a silence.** There is no toast
pill here: the board already has a card whose whole job is one line of text,
so a refused tap writes into it for 2.2 s and the cycling rules resume after.
Two lines: *That one came with the puzzle* and *Pencil marks go in an empty
cell*.

The mechanism is worth naming, because a refusal is the one event the chrome
does not already hear about. `ui/flat/tip_card.gd`'s `refresh(puzzle)` reads
`tip_line()` off the board, and `ui/puzzle_host.gd` calls `_refresh` on
`moved` and on **`focus_changed`**. A refused tap is not a move, so the board
**emits `focus_changed`** to push the line out, holds it for 2.2 s on its own
timer, and emits `focus_changed` again to let the rules resume. No new signal
and no new host wiring.

## 11. Motion

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`), read as curves the way Nonogram's drawn tiles and
clue numbers already read them. **This board adds nothing to the vocabulary**
and takes only three constants of its own: `WAVE_STEP` 0.045, `WAVE_FLASH`
0.5 and `WIN_WAIT` 1.4.

**Its signature is the unit coming right.** The instant a row, a column or a
region is complete and correct it lights up in `SUN_RAY` from the cell that
finished it outwards, a king-move step apart, each cell holding its gold for
`WAVE_FLASH`. A digit that closes a row *and* a region runs both at once from
the same seat.

It is Queens' `_settle` shape and it is diffed in exactly one place: one
snapshot of which units were finished before the move against which are
finished after it. `place`, `mark`, `hint`, `undo` and `reset` all go through
that same door, so no move can light a unit twice and none can light one it
did not finish.

| Moment | What happens |
|---|---|
| Entrance | The grid pops in wide about its centre (`wide_pop_scale`, from 0.88) after `ENTER_DELAY` 0.18; the givens fade in region by region, `ENTER_STAGGER` 0.03 apart, so the board assembles as three by three and not as eighty-one. |
| Place | The cell bumps (`bump_scale`) and the digit drops in from 40 above with the fade (`drop_in_lift`). |
| Take out | The same digit tapped again: the cell bumps and the numeral is gone. No pop-out &mdash; a cleared cell is not an event. |
| Pencil | The cell bumps; the mark appears at its third of the cell with no drop, because nine of them dropping is a rainstorm. |
| Refused | The cell shivers (`shiver_offset`, 2 px, 0.2 s) and the tip card says what happened. |
| Unit complete | **The wave.** Above. |
| Hint | A ring in `LEAF` over the cell, the digit drops in, sparkles in leaf, and the wave runs if it finished anything. |
| Check | Every wrong cell shivers, in a shallow wave out from the middle row, and takes the `BAD` wash until it is touched. |
| Reset | Every cell the player wrote bumps in a wave from the far corner, `RESET_STAGGER` 0.03 apart, and empties. |
| Solved | The whole grid waves on the diagonal, `SOLVE_STAGGER` 0.04 a step, with sparkles in gold; the win after `WIN_WAIT` 1.4 s. |

Reduce motion: the grid is up at once, a digit appears where it is put,
nothing bumps, shivers, rings or sparkles, no unit flashes, and the win
follows the last digit.

**Drawn, not nodes.** Eighty-one cells, their washes, their rules, their
digits and up to nine marks each is far too much to make Controls out of;
`gl_compatibility` pays per draw command and the lesson is already in
`CLAUDE.md`. The board is one `ArrayMesh` for the cells and the rules,
rebuilt when the state changes, plus `draw_set_transform` per digit and per
mark &mdash; Nonogram's precedent for drawn text on the vocabulary. **It must
keep the mesh its last `_draw` handed over** (`_shown`) until the next one
replaces it, or a harness's `force_draw()` finds a freed RID; six boards have
already paid for that one.

## 12. The menu card

`ui/menu/card_art.gd` gains one branch: a 3&times;3 fragment of the board in
the 320&times;118 box &mdash; nine cream cells with the region rule round
them and three numerals in ink, drawn with `ui/faces/mosaic_tile.gd`, the
class Nonogram and Hidden Word already share. One branch of `_build` and
nothing of `_draw`. It is never an image and never a `SubViewport`.

## 13. Calls this screen is for

- **The 100 cell.** Nine columns is the tightest grid this game has drawn.
  Tapping only ever selects and the thing tapped next is a 91&times;130 chip,
  but that is an argument and the phone is the test.
- **The pencil instead of the eraser.** Tap-the-same-digit-to-clear is
  undiscoverable until someone says it, and the tip card is the only place
  that does.
- **The clash wash.** Faint `BAD` on two digits that see each other is help
  the mock does not offer. Turning it off makes a harder, purer board and
  makes Check matter more.
- **The player's digit in green.** One extra colour on a board that is
  otherwise ink on cream. The alternative is ink for both and no way to tell
  what you put there, which makes Reset frightening.
- **A hard 9&times;9 is a fifteen-minute sit**, and every other board here is
  three to five. Sudoku is the first card that is not a coffee break.
- **Three hints on 81 cells.** Hidden Word gives two on five letters. Three
  may be too few to rescue a stuck hard day and too many to matter on an easy
  one.
- **The lonely second page**, for as long as it takes to build a fourteenth
  board.

## 14. Tests

`tests/test_sudoku.gd`, pure logic, in the style of `tests/test_queens.gd`.
Written despite the standing "no new tests for now" note and with the user's
agreement on 2026-09-20, for one reason: **a generator can silently emit a
non-unique puzzle, and that is unfalsifiable by playing it.** It is the one
bug class in this board that would reach a phone.

Over twelve seeds a band:

- Every puzzle has **exactly one solution**, counted with a cap of three.
- Every given **agrees with the solution**, and the given count is within one
  of its band's target.
- **Easy falls to singles** and hard does not.
- The givens are **180-degree symmetric**.

And over the state, which needs no seeds:

- `place` at a given is refused and changes nothing.
- `place` of the digit already there clears the cell.
- Placing a digit **strikes it off every peer's marks**, and `undo` **puts
  every one of them back** &mdash; the assertion this file exists for.
- `undo` to an empty log is false and changes nothing.
- `clashes`, `twins` and `peers` are recomputed, not cached: mutate the grid
  behind them and the next read is right.
- A solved grid reports solved; a full grid with a wrong digit does not.

No tests for the board's drawing.
