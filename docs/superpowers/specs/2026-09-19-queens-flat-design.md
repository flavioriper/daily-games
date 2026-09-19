# Queens, flat: the tenth screen

Status: designed 2026-09-19, built the same day. Concept page:
`docs/brainstorm/concepts.html#queens`. Reference: `docs/art/concept-queens.png`,
the user's mock, which this spec ports where the family's chrome allows and
departs from where it says so. Sibling specs: the nine
`2026-09-18-*-flat-design.md`, Nonogram's closest, because the screen has the
same rows.

Queens is a square board cut into as many coloured regions as it has rows.
Seat one queen in every row, every column and every region, and never let two
queens touch, not even at a corner. That is the no-touch rule of the game most
players know from LinkedIn, chosen over chess diagonals on 2026-09-19: the
regions carry the deductions, and a 9x9 with a unique answer generates in a
blink.

**This is the first board that answers a move for you.** The user asked for
it (2026-09-19): when a queen is seated, every cell she can see is crossed
out, in a wave that runs out from her. Section 3 says what that does to the
rules and section 9 what it looks like.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `puzzles/queens_gen.gd` | new | Queens first, regions grown from them, the answer proved unique. |
| `puzzles/queens_state.gd` | new | The rules, scene-free: regions, queens, the player's crosses, the derived crosses, every move. |
| `puzzles/queens2d.gd` | new | The flat board: the court, its two meshes, the crowns in slots, the wave, the sprout's lines. |
| `ui/faces/crown_face.gd` | new | The queen: a gold crown with a face. The tenth screen's one new species. |
| `ui/flat/tile_tray.gd` | edit | Takes a chip set; Nonogram's pair stays the default, Queens' pair is the second. |
| `ui/flat/flat_host.gd` | edit | `"tray": "crowns"` builds the tile tray with the crown set. |
| `core/palette.gd` | edit | Nine region pastels, and the gold wash the wave leaves behind. |
| `ui/registry.gd` | edit | `queens` joins the grid as the tenth live card; Snake Apple's `soon` card leaves it. |
| `ui/menu/card_art.gd` | edit | A crown on a patch of coloured cells. |
| `tests/test_queens.gd`, `tests/run_tests.gd` | new, edit | Five seeds: generated, unique, legal. |
| `tests/_win.gd`, `tests/_shot_anim.gd` | edit | A solve branch and a tap branch. |
| `docs/art/flat-motion.md`, `CLAUDE.md` | edit | The Queens row; ten flat boards and two `soon`. |

## 2. Where it stands on the first screen

Twelve cards fit the 3x4 grid and the heights are a budget
(`2026-09-18-flat-menu-design.md`). Queens is the tenth live card, in the
first slot of the last row, and **Snake Apple's `SOON` card leaves the grid**
(the user's call, 2026-09-19): it is the one of the three being redesigned
outright as Apple Worm, and its island board stays reachable under More with
`seed_as` still `snake`, so nothing it hands out moves. Pipes and Horse Pen
stay dimmed together at the end of the row, which keeps the rule that dimmed
cards stand together.

## 3. The state is the one truth

`queens_state.gd` is `RefCounted`, no scene. The board draws it and nothing
else.

- `SIZES := [7, 8, 9]`: easy, medium, hard. The menu opens medium.
- `region[r][c]` is a region index, `solution[r]` the answer's column in row
  `r`, both from the generator.
- `queens` is the set of seated queens, `crosses` the set of crosses **the
  player laid**, `locked` the queens a hint gave.
- **A cell is crossed while any queen sees it.** `seen[cell]` is a count,
  rebuilt by `recompute()` after every change: the queen's row, her column,
  her region and her eight neighbours. It is derived and never stored, so
  removing a queen takes her crosses with her and undo needs no bookkeeping
  for them. `mark_at(cell)` therefore answers one of four: `QUEEN`, `CROSS`
  (the player's), `AUTO` (seen and not the player's) or `BLANK`.
- **A crown on a seen cell is refused.** The cell is provably unavailable
  given the queens on the board, so the board says so rather than seating a
  queen that must be wrong. The consequence is a strong one: **two queens can
  never conflict**, the crowns never need a conflict face, and the n-th queen
  seated is the win. A crown on the player's own cross replaces it; the cross
  was a guess and the finger has changed its mind.
- **A cross never replaces a queen**, and a sweep passes over queens and seen
  cells alike. Crossing a cell already crossed by a queen does nothing but the
  press.
- Moves: `seat(cell) -> Dictionary` (`ok`, or `why` in `SEEN`, `PINNED`),
  `lift(cell)`, `cross(cell)` and `uncross(cell)`, `sweep(cells, on)`. Each
  pushes one history entry of `[{cell, prev}]`, so one gesture is one undo
  however many cells it swept. `undo()` returns the cells that changed.
- `hint() -> Vector2i`: the first row in reading order whose answer cell holds
  no queen. If a seated queen sees that cell she is wrong, and the hint lifts
  her first (she pops out) before seating the given queen, pinned. A hint
  clears the history, Shikaku's rule: what came before no longer describes a
  board that can be gone back to.
- `wrong_queens()`: seated queens not in the answer. Check counts them.
- `is_solved()`: n queens seated and the rules hold, checked against the rules
  and not the stored answer. With the answer proved unique the two agree; the
  honest claim is the rules.
- `share_glyphs()`: one emoji row per board row, a crown for a queen and a
  coloured square for every other cell, the square cycling nine colours by
  region, so a shared board carries its regions.

## 4. The generator

`queens_gen.gd::generate(rng, n) -> {region, solution, n, ok}`, seeded only
by the `rng` the host hands in, so a day is the same board on every phone.

1. **Queens first.** A permutation of `n` columns, one per row, chosen row by
   row in a shuffled order and backtracking when a column repeats or the new
   queen touches the one above (`|dc| <= 1`). Every legal answer is reachable.
2. **Regions grown from the queens.** Region `i` starts on queen `i`'s cell.
   Until every cell is claimed, pick a region at random and give it a random
   unclaimed cell that touches it orthogonally. Regions are connected by
   construction and each holds exactly one queen of the answer.
3. **The answer proved unique.** `solve_count(region, n, 2)` is the same
   row-by-row search with a column set, a region set and the no-touch check
   against the previous row, stopping at two. A board is kept only when it
   answers one.
4. Up to 200 attempts; the last is returned with `ok = false` if none was
   unique, which still plays (any full legal seating wins) but is not a
   puzzle. `tests/test_queens.gd` asserts five seeds succeed.

Difficulty is size alone. Region shape is the other lever the game has and
this spec does not pull it; section 12 keeps the call. Generation has to be
felt as nothing at open: the target is under a tenth of a second for a 9x9 on
this Mac, measured in the plan with a throwaway probe, and the two levers if
it is not are a compact growth (which raises the uniqueness rate) and fewer
attempts.

## 5. The cast: one crown, drawn crosses, coloured ground

**The crown is a new species**, `ui/faces/crown_face.gd`. The bar for one is
the snail's: nothing in the cast does what this needs. Nothing in it is a
queen, and the crown is the one thing this board seats, so it earns the
exception. A gold crown (`SUN` over `SUN_DEEP`) with three points and a face
on its band, drawn from the mock: `HAPPY` at rest, `JOY` on the win, `STRAIN`
for a beat when the finger is refused on her. A hint's crown wears a leaf
gem on its middle point, the given look. One layer, one cached mesh per state,
shared by every crown on the board.

**The cross is drawn**, not a character: Nonogram's pebble
(`ui/faces/mosaic_tile.gd::pebble`) on a soft disc, laid into the ground
mesh, so forty crossed cells cost the renderer nothing more than one. A
cross the player laid is drawn at full ink; a cross a queen laid is the same
pebble at `AUTO_ALPHA` 0.75, so the eye can tell a guess from a fact without
a second shape. Section 12 keeps the call on whether the difference earns its
keep.

**The regions are the ground.** Every cell is filled in its region's pastel,
the grid between cells a faint line, and a region's border a thick warm ink
(`TEXT`), as the mock draws it. The ten chip tints in the palette are too
pale to hold nine regions apart, so `core/palette.gd` gains `REGION`, nine
pastels spread round the wheel so no two neighbours share a family, taken by
region index: tan, lavender, sky, mint, apricot, silver, lemon, coral, rose,
the mock's own. The seam does the separating; colour is the region's name.
Beside them, `QUEEN_WASH`, the gold the wave leaves on a cell for a moment.

## 6. The tray and the gesture

**Two chips, as the mock draws them** (the user's call, 2026-09-19, over the
tap cycle): a crown chip and a cross chip, in Nonogram's tile tray. The tray
today is two constants; it now takes a **chip set** of values, labels and
glyph kinds, Nonogram's pair the default and Queens' pair (`Queen`, `Cross`)
the second, and `"tray": "crowns"` in the registry picks it. One tray class,
two sets, no copy. The tray only asks; the board owns `brush` and the tray
reads it back.

- **Crown chip, tap**: a blank cell seats a queen; a seated queen is lifted
  (the mock's "tap once to place, tap again to remove"); a seen cell is
  refused; the player's own cross is replaced. A drag with the crown chip is
  a tap where it ends.
- **Cross chip, tap**: a blank cell takes a cross, the player's cross is
  taken away; a queen or a seen cell takes only the press.
- **Cross chip, drag**: a sweep lays crosses on every blank cell the finger
  passes, or rubs the player's crosses out if it began on one (Nonogram's
  rule: the stroke's job is read off its first cell). The cells between the
  last one painted and this one are filled in, so a fast finger leaves no
  holes; a cell is painted once per stroke. No line lock: a Queens sweep is
  a region's odd corners as often as a row.
- **Undo** is one gesture back. **Reset** clears queens and crosses but keeps
  a hint's queens, so what was given stays given.

## 7. What the board says, and the win

`tip_line()` is the board's own, refreshed on `focus_changed`:

| When | The sprout says | Face |
|---|---|---|
| Bare board, cycling | One queen in every row, every column and every colour. / A queen crosses out every seat she can see. / Two queens never touch, not even at a corner. | HAPPY |
| Queens seated | Three queens seated, five to go. | HAPPY |
| Crown refused on a seen cell | A queen already sees that seat. | WORRIED |
| Crown refused on a given queen | That queen was given. She stays. | WORRIED |
| After Check, wrong | Two queens are in the wrong seat. | WORRIED |
| Solved | Every queen has her seat. | JOY |

Check counts `wrong_queens()` and shakes them; it never seats anything. A
clean Check with queens still to seat says All good through the actions row,
as every submitting board does.

`flat_win()` is one crown in `JOY` with "Every queen has her seat." The
board stays on the card as it slides down, every queen on her colour, the
crosses gone (section 9).

## 8. The screen

Nonogram's rows exactly, because it has the same rows:

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `QUEENS` in ink with the leaf, `EVERY QUEEN HAS HER SEAT` under, then Undo, Hint with its count and Settings. |
| Day card | 120 | A tree, the day, the island's name. |
| Board card | cut to fit | The court on parchment. |
| Tray | 150 | The crown chip and the cross chip. |
| Actions | 130 | Reset and Check. `capabilities()` is undo, hint and check. |
| Tip card | 140 | The sprout and one line. |

The bottom slot is 460. The board is square in a tall slot, so the cell is
capped by the width and the card is cut to the court and centred
(`card_height`, `card_centred`), the fifth board to want both.

Cell: `(1000 - 2 * PAD) / n` with `PAD` 34, so 133 on easy, 116 on medium and
103 on hard. The mock's 9x9 is the hard board; 103 is the cell Nonogram's
hard board already asks of a thumb.

**Not built from the mock**, and why: the hearts on the day card (there are
no lives, the user's decision of 2026-09-18); the How to play card (the tip
card carries the rule, the flat screens' own rule); the two roadside signs
and the peeking sprout beside the board (the sprout has its card, and the
rule on the sign is its first line). Under the card, the family's clouds and
tufts through `ui/flat/scenery.gd`.

## 9. Motion

Everything through `core/motion.gd` and `docs/art/flat-motion.md`; the crowns
are nodes in slots taking the recipes, the ground is drawn off the readers
(rule 8). The board's own signature is the wave, and its numbers are its own
constants: `WAVE_STEP` 0.045 s per ring, `WAVE_FLASH` the gold wash's peak
alpha 0.35, `AUTO_ALPHA` 0.75.

| Moment | What happens |
|---|---|
| Entrance | The court pops in wide about its centre (`wide_pop_scale`) while it fades, after `ENTER_DELAY`; nothing stands on it yet. |
| Press | The cell under the finger sinks (`press_scale`) and shades toward its region's deeper tone; a crown or a pebble there sinks with it. |
| Seat | The crown pops in with the squash on her cell, a ring in gold pulses out of her (`fx.ring`), and **the wave** runs: every cell she can see, ordered by its king-move distance from her, `WAVE_STEP` apart, flashes toward `QUEEN_WASH` (`flash_level`) as the wave reaches it and its pebble pops in behind the flash (`pop_in_scale`). A puff of five in gold on her cell. Cells already crossed by another queen or by the player flash and keep their pebble. |
| Lift | The crown shrinks with the quarter turn (`pop_out`), and the wave runs backward: the cells only she saw lose their pebble far first, near last, each with the quarter turn (`pop_out_scale`), so her reach draws back into where she stood. |
| Cross, uncross | The pebble pops in with the squash and a puff in `SOCKET_PEBBLE`; taken away, it shrinks with the quarter turn. |
| Sweep | Cells sink as the finger passes and stay down; on release the pebbles arrive in a wave along the finger's path at `ENTER_STAGGER`, each cell springing back as its pebble lands. No puffs. |
| Hint | A wrong queen in the way pops out first. A ring in `LEAF` at the given cell, the crown drops in from `DROP` above with the fade (`drop_in`), sparkles in leaf, then her wave. |
| Wrong on Check | Each wrong crown wobbles (`wobble2d`) and her cell flashes toward `BAD_TILE` (rule 9: a crown has no blush of her own; her cell blushes). |
| Refused | On a seen cell the pebble shivers (`shiver_offset`) and the cell flashes toward `BAD_TILE`; on a given queen the crown shivers with `STRAIN` and her cell flashes. The sprout says why. |
| Undo | The reverse of the gesture, in its own wave. |
| Reset | Every crown and pebble the player laid shrinks out in a wave from the far corner at `RESET_STAGGER`; given queens hop `RESET_HOP` and keep their crosses. |
| Solved | The crowns hop `SOLVE_HOP` in a wave along the diagonal with `JOY`, sparkles in gold, and the pebbles clear in a scatter as Nonogram's do, leaving the queens on their colours. `win_delay()` 1.6. |

Reduce-motion: the court is up at once, a queen and every cross she brings
are there or gone in one frame, nothing sinks, flashes, rings or wobbles, and
the win follows the last tap.

## 10. The menu card

`card_art.gd`: a crown seated on a patch of six region-tinted cells with one
thick seam through them, drawn under her. `Registry.PUZZLES` gains, before
the two `soon` cards:

| Key | Value |
|---|---|
| `id` | `queens` |
| `title` | Queens |
| `blurb` | Seat one queen in every row, column and colour. |
| `short` | One queen per row,\ncolumn and colour. |
| `motto` | Every queen has her seat |
| `footer` | Seat · Cross · Reign |
| `shell` / `tray` | `flat` / `crowns` |

## 11. Measured

Filled in by the build: draw calls bare and with a seated queen's crosses
against the 855 budget, idle ms at 1080x1920 through `tests/_shot_anim.gd`,
the menu's draw calls through `tests/_shot_menu.gd` against 291, the
generator's time for a 9x9, the suite count and the win harness count.

## 12. Calls this screen is still for

- **Region shape as difficulty.** Size alone is the ladder here; the game most
  players know varies the regions' shapes instead. A compact growth on easy
  and a snaking one on hard is one afternoon if wanted.
- **The refusal.** A crown on a seen cell is turned down. The game most
  players know seats her and shows the conflict. Refusing keeps the board
  always consistent and makes the n-th queen the win; it also means a player
  cannot park a queen to test a hypothesis. Judge on the phone.
- **Two inks for the cross.** A player's cross at full ink and a queen's at
  0.75. If nobody notices, one ink.
- **The ink seam.** The shading direction wants no harsh black lines; the mock
  draws the region borders in ink and nothing else would hold nine pastels
  apart. `TEXT` rather than black, and thick, is the compromise.
- **103 on hard.** Nonogram's cell, and the same question.
- **One crown on the win.** The nine on the board are already the reward.
