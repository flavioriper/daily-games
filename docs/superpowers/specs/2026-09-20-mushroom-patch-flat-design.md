# Mushroom Patch, flat: the thirteenth screen

Status: designed 2026-09-20, after the concept page was built, measured and
judged. Concept page: `docs/brainstorm/concepts.html#mushroom` -- it plays the
real generator and the real solver, and three of the numbers in section 4 were
measured there rather than guessed here. Reference: the user's screenshot of
another app's *Campo Minado*, `docs/art/concept-mushroom-ref.png`. Sibling
specs: the nine `2026-09-18-*-flat-design.md`,
`2026-09-19-queens-flat-design.md` and `2026-09-19-hidden-word-flat-design.md`.

A meadow of covered cells with mushrooms hidden under it. Some cells are
turned over and carry a number: how many mushrooms grow in the eight cells
touching that one. Plant a mushroom where you have proved one is, lay a pebble
where you have proved one is not, and the patch is done the moment the last
mushroom is planted.

**It is not Minesweeper, and the differences are the design.** A tap never
reveals anything and the board can never be lost; every board is solvable by
logic alone, and that guarantee is the generator's carving rule rather than a
test it passes afterwards; and what is buried is a mushroom, because the cast
on every other flat screen is a sprout, a snail, a bee and five camp fruit,
and a buried explosive is the one subject that would not belong. The genre's
name is nobody's property -- unlike Wordle or Mastermind, this is a choice of
tone and not of law -- but the repo has renamed a game three times already and
the cast decides it.

**What the reference settles** is the field of numbered cells over covered
ones, and two chips under the board: one that marks and one that rules out.
**What it loses** is the dig, the flag, the mine, the modal *how to play*
sheet (every flat board's rule lives on the sprout's tip card) and the green
chrome.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `puzzles/mushroom_gen.gd` | new | Scatter, count, carve. Hands back a field and a set of givens proved solvable. |
| `puzzles/mushroom_state.gd` | new | The rules, scene-free: the marks, plant/pebble/undo/reset/hint/check. |
| `puzzles/mushroom2d.gd` | new | The flat board: the field, the numerals, the wash, the tally strip. |
| `ui/flat/tile_tray.gd` | edit | A third chip set, `PATCH`, beside `MOSAIC` and `QUEENS`. |
| `ui/flat/flat_top_bar.gd` | edit | Fit the wordmark to the block it is given (section 5). |
| `ui/registry.gd` | edit | The thirteenth grid entry. |
| `ui/menu.gd` | edit | The pager (section 2), in its own commit. |
| `ui/menu/card_art.gd` | edit | The menu card's picture. |
| `ui/faces/mushroom_face.gd` | reuse | The mushroom, as Balance already draws it. |
| `ui/faces/mosaic_tile.gd` | reuse | The pebble on its socket, as Nonogram and Queens already draw it. |

Nothing else moves. **No new character** is drawn (section 7), **no new colour**
is added to `core/palette.gd` (section 6), and **`core/motion.gd` gains
nothing** (section 9).

## 2. Where it stands on the first screen, and the pager

The grid is full: twelve cards, three across and four down, and the last slot
is Pipes' dimmed `SOON` card, which Word Trail's spec of the same morning is
already spending. Sudoku is in flight beside this. So the first screen **gets
its pager back**: twelve cards a page, a next and a prev under the grid with a
dot each, the way `legacy/ui/camp_menu.gd` turned its pages of nine before the
flat screen dropped it on 2026-09-18.

The card stays **252** tall and the 92 px picture the card-art budget is
written against is untouched. The alternative -- letting the `GridContainer`,
which is `SIZE_EXPAND_FILL`, simply run to five rows -- takes a card to about
**210**, and every one of those 42 pixels comes out of the picture, which is
the one thing CLAUDE.md says a new row may not do.

**The pager is not this board's work.** It belongs to whichever of the three
boards in flight lands first, and it is specified here because this is the tab
that hit the wall. It is its own commit and it touches `ui/menu.gd` alone.

One consequence to record: with three boards landing, **no dimmed card is left
on the grid**. The `SOON` pill, the 55% ink and the `blocked` signal stay in
the code for the next board that is named before it is drawn, but nothing
exercises them.

Registry entry:

```gdscript
{
    "id": "mushroom",
    "kind": "puzzle",
    "title": "Mushroom Patch",
    "blurb": "Every number counts the mushrooms around it. Find them all.",
    "short": "The numbers count\nwhat is hidden.",
    "motto": "Every patch has its count",
    "footer": "Count · Prove · Plant",
    "script": "res://puzzles/mushroom2d.gd",
    "shell": "flat",
    "tray": "patch",
    "difficulties": [0, 1, 2],
}
```

Full actions row -- `capabilities()` is undo, hint and check -- so the bottom
slot is **460**: Nonogram's and Queens' number, and the flat host measures it
from the rows it actually built.

## 3. The state is the one truth

`puzzles/mushroom_state.gd`, scene-free, as all twelve are.

```gdscript
const BLANK := 0
const FOUND := 1     # the player says: a mushroom is here
const CLEAR := 2     # the player says: nothing is here

var n: int                      # 6, 7 or 8; the field is square
var mushrooms: Dictionary       # Vector2i -> true, the answer
var given: Dictionary           # Vector2i -> int, the turned-over numbers
var marks: Dictionary           # Vector2i -> FOUND | CLEAR
var pinned: Dictionary          # Vector2i -> true, what a hint gave
var order: Array                # the moves, for undo
```

Four moves and nothing else writes:

- **`place(cell, v) -> bool`** plants or pebbles. It returns false and changes
  nothing when the cell is a given (there is nothing there to decide) or when
  a pebble is aimed at a planted mushroom.
- **`undo() -> bool`** takes back one gesture, however many cells a sweep
  painted.
- **`reset_board()`** lifts everything the player laid. What a hint gave stays.
- **`hint() -> bool`** plants the next unfound mushroom in reading order and
  pins it. A hint clears the history -- Shikaku's rule.

Derived, and never stored, which is the Queens rule: `count(cell)` is how many
mushrooms neighbour it in the answer; `around(cell)` is how many the *player*
has planted around a given; `standing(cell)` is short, settled or over, and is
what the wash reads (section 8); `left()` is `mushrooms.size()` minus the
FOUND marks; `is_solved()` is the FOUND set equalling `mushrooms` exactly.

**`is_solved()` is an exact set match, not a count.** Planting the right number
of mushrooms in the wrong places does not win, and the board says nothing about
it until Check is pressed.

## 4. Generation, backwards from a full field

`puzzles/mushroom_gen.gd`, the way every board splits its generator from its
rules.

1. Scatter *k* mushrooms on an *n×n* field from the day's seeded RNG.
2. Count every bare cell's eight neighbours.
3. **Turn every bare cell over**, then walk them in a shuffled order and try to
   cover each one back up, keeping the cover only while the solver still
   proves the whole field.
4. Hand a share of the carved-away numbers back at random (section 4.2).

The guarantee falls out of step 3 rather than being tested for: **carving can
only ever remove information from a board that started fully solved**, so a
board with a guess in it is never produced in the first place. The generator
still asserts the final board is solvable, because an assertion that can never
fire is cheap and a generator that silently changes is not.

### 4.1 The solver never branches

Two rule families, run to a fixpoint:

- a number whose mushrooms are all accounted for **clears** its remaining
  unknown neighbours;
- a number whose unknown neighbours equal its shortfall **plants** them all.

Plus the global constraint, *k* mushrooms in the whole field -- which is why
the tally strip is on the screen at all: **it is a clue, not decoration**, and
a board carved with it and played without it would be unfair.

On hard only, the solver may also **subtract subsets**: where one number's
unknown cells sit inside another's, the cells outside carry the difference of
their counts, and if that difference is nought or the whole remainder, they all
resolve. This is the 1-2-1 pattern every player of this game knows by feel.

It never guesses and never backtracks. A field it cannot finish would be
rejected.

### 4.2 The ladder, measured

A minimal board is the hardest board, so easy and medium hand a share of the
carved-away numbers back, chosen at random so the givens stay scattered.

| | Field | Mushrooms | Subsets | Handed back | Givens, minimal | Givens, shipped |
|---|---|---|---|---|---|---|
| Easy | 6×6 | 6 | no | 45% | 9.9 | **18.9** of 30 bare |
| Medium | 7×7 | 9 | no | 20% | 13.6 | **18.9** of 40 bare |
| Hard | 8×8 | 12 | yes | none | 18.4 | **18.4** of 52 bare |

Measured in the concept page's own generator over 120 seeds a difficulty on
2026-09-20: **0 of 360 boards unproved**, mean 0.5, 0.5 and 1.3 ms a board,
worst 7 ms. GDScript will be slower than a browser by some multiple; a tenth
of a second on the 8×8 is the number to measure against, and if it is missed
the carve is the loop to cheapen, not the solver.

**The ladder is real and not just size.** Of 200 hard boards, **168 cannot be
solved without the subset rule**; of 200 medium boards, **0** need it. The
three difficulties therefore differ in the size of the field, in how much
scaffolding is left standing, and in what kind of thinking the last few cells
demand.

### 4.3 A zero is drawn blank

A given of nought carries no numeral: it is turned over and bare, which is the
whole of what it has to say, and the reference draws it as an empty white cell
for the same reason. It takes no green wash either -- it is settled from the
moment the board is built, and a field of green nothings would drown the wash
that matters. It *does* blush if a mushroom is planted beside it, because that
is news.

## 5. The screen, measured

Nonogram's rows exactly, with one strip of this board's own above the field.

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `Mushroom Patch` in ink with the leaf, `EVERY PATCH HAS ITS COUNT` under, then Undo, Hint with its count, Settings. |
| Day card | 120 | The family's, unchanged. It carries **no count** -- the tally strip does that, and two of them on one screen is one too many. |
| Board card | cut to fit | A 72 tally strip over the field on parchment. |
| Tray | 150 | Two chips: the mushroom and the pebble. |
| Actions | 130 | Reset and Check. |
| Tip card | 140 | The sprout and one line. |

**The cell is capped by the width at every difficulty**: `(1000 − 2 × 34) / n`
is 155.3, 133.1 and 116.5, against a height bound of 158.9, 136.3 and 119.2.
So `card_centred()` is `true` and it does something, unlike Hidden Word's --
though only just: the field spends 932 of the card's width however it is cut,
so the leftover is **21.9 px at all three difficulties** and the centring moves
the card by eleven. Nobody should read more into it than that; it is said here
so the next person does not measure it again.

### 5.1 The wordmark does not fit, and this is the first title that does not

`ui/flat/flat_top_bar.gd` lays the title in an `HBoxContainer` block between
the back button and the three icons. That block is
`1000 − 110 − 3 × 110 − 4 × 16` = **496** wide.

Measured in Fredoka 700 at the `GameWordmark` size of 84 on 2026-09-20:

| Title | Width |
|---|---|
| Binairo | 268 |
| Queens | 287 |
| Nonogram | 390 |
| Code Break | 430 |
| Hidden Word | 482 |
| **Mushroom Patch** | **635** |

Hidden Word at 482 is the longest that fits, and it fits by fourteen pixels.
So the bar gains a fit: when the title is wider than the block, it overrides
the font size to `84 × 496 / width`, floored at 56. Mushroom Patch lands at
**65**; every existing board measures under 496 and is untouched, so nothing
that ships today changes by a pixel. `ui/sun_dot.gd` needs nothing -- it takes
its seat from `Label.get_character_bounds` at any size, and in any case there
is no lowercase i in this title.

## 6. Colour: nothing new

Every colour on this field is already in `core/palette.gd`, which is unusual
enough to be worth saying.

| What | Colour |
|---|---|
| A covered cell | `TURF_REACH` `#dde08a`, the pale meadow Horse Pen owns |
| A turned-over cell | `SURFACE`, its numeral `TEXT` |
| A settled number | its cell washed toward `LEAF`, its numeral `LEAF_DEEP` |
| An over-planted number | its cell washed toward `BAD`, its numeral `BAD` |
| A pebbled cell | `SOCKET_OUT`, the pebble `SOCKET_PEBBLE` |
| A planted cell | `MUSHROOM_TILE`, the cap `MUSHROOM`, the stem `MUSHROOM_STEM` |
| The card, the page | `PARCHMENT` on `PAPER`, as every flat board's |

## 7. The cast: no new character, and no flag

**You mark a mushroom by planting the mushroom.** `ui/faces/mushroom_face.gd`
already exists -- it is Balance's fifth camp fruit -- so the reference's flag
is not redrawn, it is not needed. The pebble is the socket
`ui/faces/mosaic_tile.gd` already draws for Nonogram's and Queens' cross chip;
a third glyph for the third board ruling a cell out would be a new word for an
idea the game has.

In thirteen screens two boards have earned a new face -- One Line's snail and
Queens' bee -- and this one does not clear the bar and does not need to. The
only other face on the screen is the shared sprout on the tip card.

`ui/flat/tile_tray.gd` gains a third chip set:

```gdscript
const PATCH := {
    "values": [MushroomState.FOUND, MushroomState.CLEAR],
    "labels": ["Mushroom", "Pebble"],
    "names": ["MushroomChip", "PebbleChip"],
    "glyphs": ["mushroom", "pebble"],
}
```

One tray, three sets, no copy.

## 8. The count wash -- the board's signature

Queens' signature is the wave and Hidden Word's is the flip. This one is **the
count wash**: a number is written in ink while its neighbourhood is short of
mushrooms, **turns green the moment exactly that many stand around it**, and
turns rose if one too many is planted. The wash *holds* -- it is a state, not
a flash that fades -- and the numeral bumps as it changes, off
`Motion.bump_scale`. On a solved board every number on the field is green,
which is what makes the last plant feel like a lid closing.

**This does not break the Code Break rule** ("a count and never a map"). The
wash is computed from information the player already holds -- the number
printed on the cell, and the mushrooms they themselves planted -- and never
from the answer. A green number means *you have put three here*, not *your
three are right*. A board can be covered in green numbers and still be wrong,
and finding that out is what Check is for.

Two constants of its own, and they are the only two the board adds:
`WASH_TIME` 0.35 s, how long a change takes to settle, and `WASH_LEVEL` 0.30,
how deep the colour sits on the cell. A rose wash sits at 0.34 because `BAD`
is darker than `LEAF` and reads lighter on the meadow.

## 9. The tray and the gesture

- **Mushroom chip, tap**: a covered cell takes a mushroom; a planted one is
  pulled up; your own pebble is replaced; a given is refused. A drag with the
  mushroom chip is a tap where it ends.
- **Pebble chip, tap**: a covered cell takes a pebble, your pebble is taken
  away; **a pebble never lifts a mushroom** -- Queens' rule, and it keeps a fat
  finger from undoing a deduction; a given is refused.
- **Pebble chip, drag**: a sweep lays pebbles on every covered cell the finger
  passes, or rubs yours out if it began on one -- Nonogram's rule, the stroke's
  job read off its first cell. Cells between two samples are filled in, and a
  cell is painted once per stroke. **No line lock**: this field's deductions
  run round a number as often as along a row.
- **Undo** is one gesture back. **Reset** clears what the player laid and keeps
  what a hint gave.

**A wrong mark is never refused.** The board knows the answer and could turn a
wrong mushroom down, the way Queens turns down a seen cell -- and it must not,
because then tapping every cell in turn would read the answer off what stuck.
The only refusal is the given, which is refused for the opposite reason: there
is nothing there to be right or wrong about.

## 10. Motion

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`): the mushrooms are nodes in slots taking the
recipes, the field and the pebbles are drawn off the curve readers, and the
numerals ride one `draw_set_transform` a cell the way Nonogram's clues do.
`core/motion.gd` gains nothing.

| Moment | What happens |
|---|---|
| Entrance | The field pops in wide about its centre (`wide_pop_scale`, from 0.86) after `ENTER_DELAY` 0.18, the cells fading in in a diagonal wave at `ENTER_STAGGER` 0.03. |
| Press | The cell under the finger sinks (`press_scale` 0.94); whatever stands on it sinks with it. |
| Plant | The mushroom pops in with the squash (0.22, squash 0.15), a ring in `SUN_RAY` pulses out, a puff of five in leaf -- and every number whose standing just changed bumps and takes its wash. |
| Pull up | The mushroom shrinks with the quarter turn (0.12); the numbers around it go back to ink. |
| Pebble, rub out | The pebble pops in with the squash and a puff in `SOCKET_PEBBLE`; rubbed out, it shrinks with the quarter turn. |
| Sweep | Cells sink as the finger passes and stay down; on release the pebbles arrive in a wave along the path at 0.03, each cell springing back as its pebble lands. |
| Hint | A ring in `LEAF`, the mushroom drops in from 40 above with the fade (0.3 s), sparkles in leaf, and wears a leaf sprig from then on. |
| Wrong on Check | Each wrong mark wobbles (0.45 s) and its cell blushes. |
| Refused | The cell shivers (2 px, 0.2 s) and blushes; the sprout says why. A pinned mushroom pulls a face with it. |
| Reset | Everything the player laid shrinks out in a wave from the far corner at 0.02 s a cell; a hint's mushrooms hop 4 and stay. |
| Solved | The mushrooms hop 10 along the diagonal (0.04 s a cell after 0.25) with `JOY` and sparkles in gold, the pebbles clear in the same wave, and every number is already green. The win after 1.6 s. |

Reduce motion: the field is up at once, a mushroom or a pebble is there or gone
in one frame, nothing sinks, rings, shivers or wobbles, the washes change
without bumping, and the win follows the last tap.

## 11. What the board says, and the win

- **The tally strip**, inside the board card over the field: a small mushroom
  and *four mushrooms still hidden*. At nought it reads *every mushroom is
  planted*; past nought, *two too many planted* in rose.
- **`tip_line()`** is the sprout's: the rule while nothing is planted, then
  *three mushrooms found, six to go*, then the refusal when a given is tapped.
- **Check** shakes every mark that contradicts the patch -- a mushroom on bare
  ground **and** a pebble on a mushroom -- and plants nothing. A clean Check
  says *All good* through the Check pill, as every submitting board does. The
  pebble counts for nothing towards the win, but it is still a claim, and
  Check answers claims.
- **`flat_win()`** is one mushroom in `JOY` over *Every patch has its count.*
- **`rules()`** is real and reached the usual way, through the tip card.

## 12. Analytics

Nothing new in `core/analytics.gd`. `puzzle_id` is `mushroom`, and the board
sends the events every other board sends: `puzzle_start`, `puzzle_complete`
with `solved: true` (this board cannot end unsolved -- only Hidden Word can),
`puzzle_abandon`, `hint_used`, `undo_used`, `check_used`, `board_reset`,
`rules_opened`.

## 13. Calls this screen is for

- **The auto-pebble.** A settled number could lay pebbles on its remaining
  neighbours for you, the way a seated queen crosses out what she sees. It
  would feel wonderful and it would play the easiest stretch of the game on
  your behalf, so it is off. One method either way; judge it on the phone.
- **The wash as a crutch.** Section 8 argues it is honest. It is still a
  running signal no other flat board gives, and if it turns the hard board
  into colour-matching it should move to Check only.
- **116 on hard.** Nonogram's cell and Queens' cell, and the same question
  about a thumb.
- **Two chips or one.** A tap cycle would free the tray's 150 and give the
  field a bigger cell -- except the cell is width-bound at every difficulty
  (section 5), so it would buy air and nothing else. Nonogram already answered
  this the other way, and three taps to correct a pebble is why.
- **Whether easy is too easy.** Handing 45% of the carved numbers back makes a
  6×6 close to a reading exercise. The knob is one constant.
- **The fitted wordmark.** Section 5.1 shrinks one title to 65. The other
  answer is a shorter name -- *Mushrooms* measures 434 and fits at full size.
