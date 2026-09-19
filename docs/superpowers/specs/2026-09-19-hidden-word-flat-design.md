# Hidden Word, flat: the eleventh screen

Status: designed 2026-09-19. Concept page: `docs/brainstorm/concepts.html#hiddenword`.
Reference: the user's mock of 2026-09-19, `docs/art/concept-hidden-word.png`, which
this spec ports where the family's chrome allows and departs from where it says
so. Sibling specs: the nine `2026-09-18-*-flat-design.md` and
`2026-09-19-queens-flat-design.md`.

Five letters, six rows, one word a day. Type a guess, commit it, and every
tile answers: green in the right place, amber in the word but elsewhere, grey
not in it at all. The game everybody already knows.

**The name is not Wordle.** The New York Times owns that trademark, and this
repo has made the same move once already -- Mastermind ships here as *Code
Break*. The user chose **Hidden Word** on 2026-09-19, off the mock's own
subtitle, *Guess the hidden word*. Nothing in the source, the registry or the
UI says the other name.

**This is the first board that ships words.** Every other screen generates its
puzzle out of a seed; this one needs English in the APK, and section 4 is
where the real work of it is.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `content/hidden_word.json` | new | 968 answers in three commonality bands. |
| `content/hidden_word_accept.txt` | new | 15,921 words a guess may be. |
| `puzzles/hidden_word_state.gd` | new | The rules, scene-free: the answer, the rows, the marks, the derived keyboard. |
| `puzzles/hidden_word2d.gd` | new | The flat board: the grid, the flip, the toast, the reveal. |
| `ui/flat/key_board.gd` | new | The keyboard tray: 10/9/9 keys, ⌫ and Enter, repainted from the state. |
| `ui/faces/mosaic_tile.gd` | edit | Takes a letter and draws it. Nothing else about it moves. |
| `core/puzzle_base.gd` | edit | `finish_unsolved()` and the `ended` signal, for the one board that can run out. |
| `core/palette.gd` | edit | `WORD_NEAR`, `WORD_MISS`, `KEY_FACE`. |
| `ui/flat/flat_host.gd` | edit | `"tray": "keys"` builds the keyboard; `"tip": false` drops the tip card. |
| `ui/registry.gd` | edit | `hiddenword` joins the grid as the eleventh live card; Horse Pen's `soon` card leaves it. |
| `ui/menu/card_art.gd` | edit | Three letter tiles on a scenery band. |
| `export_presets.cfg` | edit | `content/*` in `include_filter`. |
| `tests/test_hidden_word.gd`, `tests/run_tests.gd` | new, edit | The marking rule, the lists, the bands. |
| `tests/_win.gd`, `tests/_shot_anim.gd` | edit | A solve branch and a type branch. |
| `docs/art/flat-motion.md`, `CLAUDE.md` | edit | The Hidden Word row; eleven flat boards and one `soon`. |

## 2. Where it stands on the first screen

Twelve cards fit the 3x4 grid and the heights are a budget
(`2026-09-18-flat-menu-design.md`). Hidden Word is the eleventh live card, in
the second slot of the last row, and **Horse Pen's `SOON` card leaves the
grid** (the user's call, 2026-09-19), exactly as Snake Apple's did for Queens
the day before: the island board stays reachable under More with `seed_as`
still `horse`, so nothing it hands out moves. Pipes is then the only dimmed
card, and it keeps the last slot of the last row -- the rule that dimmed cards
stand together survives a set of one.

## 3. The state is the one truth

`puzzles/hidden_word_state.gd` is scene-free and holds everything:

```
answer   String, five lower-case letters
rows     Array[String], the committed guesses, in order
marks    Array[Array], one Array[int] of five per committed row
typed    String, the row being typed, 0 to 5 letters
given    Array[int], the positions a hint has revealed
```

`HIT`, `NEAR`, `MISS` are 0, 1, 2. Three moves and one refusal code:

- `type(letter)` appends while `typed` is under five and the board is not done.
- `erase()` drops the last letter of `typed`.
- `commit() -> int` returns `OK`, `SHORT` (fewer than five letters),
  `UNKNOWN` (not in the accept list) or `REPEAT` (a row already guessed --
  section 8's toast has a line for it). On `OK` it marks the row, appends it,
  clears `typed`, and the board is solved if every mark is `HIT` or over if
  that was the sixth row.

**The marking rule is two passes, and it is the one thing implementations get
wrong.** First pass: every position whose letter equals the answer's is `HIT`,
and that answer letter is struck off a tally. Second pass, left to right: a
remaining position is `NEAR` if its letter is still in the tally, and that
copy is struck off too; otherwise `MISS`. The case that carries the lesson
whole: against `MOSSY`, the guess `SWISS` marks S-W-I-S-S as
`NEAR MISS MISS HIT MISS` -- the first S is amber, the fourth is green, and
**the fifth is grey**, because `MOSSY`'s two S's are spent by then, one on the
green and one on the amber. A one-pass implementation paints the fifth amber
and lies. (This example was corrected on 2026-09-19: the spec first used
`SASSY`, which shares a third letter with `MOSSY` and so marks
`MISS MISS HIT HIT HIT` -- true, but it never exercises the exhausted tally.
The concept tab caught it before any GDScript was written, which is what the
tab is for.)

`key_mark(letter) -> int` is **derived** from `rows` and `marks` on every
call, never stored -- the Queens rule. Best mark wins: `HIT` beats `NEAR`
beats `MISS`, so a letter that was amber on row one and green on row three
stays green. A letter never guessed answers `-1`.

`is_solved()` is `marks` ending in five `HIT`s. `is_over()` is
`rows.size() == 6` and not solved. `share_glyphs()` is the row-per-line block
of 🟩🟨⬜, which is the one thing every player already knows how to do with
this game.

The board keeps **no history**. `capabilities()` is `["hint"]` alone: there is
no Check, because every Enter *is* the check, and no Undo, because taking back
a committed guess is not this game. The top bar already hides a button that is
not in `capabilities()`, so the four buttons the mock draws -- back, Reset,
Hint with its badge, Settings -- come out of `"actions": false` and nothing
else. Reset replays the same day from the first row.

## 4. The words

Two files, because they have opposite jobs.

**`content/hidden_word.json`** -- `answers`, 968 words, **hand-written for this
game** and ordered easiest first, with `bands` `[217, 467, 968]` saying where
each difficulty stops reading. Easy draws from the first 217, medium the first
467, hard from all of them. Common, warm, no proper nouns, and **no plain `-S`
plurals**: a plural makes the last column a coin flip and the sixth row a
formality. The day's word is `answers[rng.randi() % bands[difficulty]]`, drawn from the
`RandomNumberGenerator` the host already seeds with
`DailySeed.seed_for("hiddenword", difficulty)` -- the way every other board on
this screen picks its puzzle, rather than How Big?'s own `fnv1a`. So the word
is the same on every phone, and a given day is reproducible.

**`content/hidden_word_accept.txt`** -- 15,921 five-letter words, one a line,
filtered out of `dwyl/english-words`' `words_alpha.txt`, which is released into
the public domain under the Unlicense. It is **deliberately far larger than it
needs to be**, and permissive on purpose: being told that a real word is not a
word is the worst thing this board can do to a player, and it is worse than
letting an obscure one through. It is loaded into a `Dictionary` once per
board (16k keys, a few ms) and asked one question.

macOS's own `/usr/share/dict/web2` was the first candidate and was **rejected
after measurement**: Webster's 1913 has no `PROUD`, no `ASKED`, no `MOVED`, no
`WALKS` and no `LIKED`, because it lists headwords and not inflections. A
player types inflections constantly. Every answer in the list above is in the
accept list; a test asserts it.

**Nothing under `content/` was reaching the APK.** The preset's
`export_filter` is `all_resources`, which packs resources plus whatever
matches `include_filter`, and `.json` under `content/` imports as no resource
-- there is no `.import` beside `how_big.json` and no entry for it in
`.godot/imported`. `content/*` joins `include_filter`, which ships these two
files and, as a side effect, How Big?'s bundled table.

## 5. The screen, measured

At 1080x1920, with the host's 40 margins and 20 gaps, the rows add up:

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `HIDDEN WORD` in ink with the leaf sprouting from it and `FIND THE HIDDEN WORD` under, then Reset, Hint with its count and Settings. |
| Day card | 120 | A tree, "Day 5", "Moss Harbour" -- the mock's, without its hearts. |
| Board card | 1140 | Six rows of five tiles on a scenery band. |
| Keys | 340 | The keyboard. |

The board card reserves a **120 scenery band** at its foot and the grid takes
what is left: `tile = min((inner_w - 4*GAP)/5, (inner_h - BAND - 5*GAP)/6)`
with `GAP` 14, `BAND` 120 and a 28 inset, which at 1140 of slot is **149**,
five across using 801 of the 944 available, leaving 143 of side air.

This was measured on the concept tab on 2026-09-19 and it corrected the
spec's first arithmetic. Without the band the tile is 169 and the grid fills
the card's inner height **exactly** -- 6x169 + 5x14 = 1084, which is the whole
1084 -- so there is no room left for a cloud, and the mock's scenery reduces
to a hem round the edge. 149 is still the second-largest cell any flat board
draws, against Nonogram's and Queens' 103 on hard.

Height binds in a 9:16 slot either way, so `card_centred()`'s slack is **zero
at 1080x1920 and the call is a no-op there**. It stays `true` because on a
squarer screen the width binds instead and the block then wants centring;
what must not be claimed is that it does anything on the phone this game is
built for. `card_height()` is the block plus the band plus the inset.

**Where the mock and the phone disagree.** The mock is 2:3; the phone is 9:16,
much taller and relatively narrower. The clouds, the bushes, the wooden sign
and the sprout stand *outside* the board card there, and at 40 px margins on a
real phone there is no outside. So that furniture moves **inside** the card, as
a low scenery band behind the grid (`ui/flat/scenery.gd`, the way Balance lays
its clouds and tufts), and the sprout comes on stage only for the reveal in
section 8. The mock's hearts are the first screen's decoration, settled on
2026-09-18 as counting nothing; the six rows are this board's lives and they
are drawn as rows.

## 6. The keyboard

`ui/flat/key_board.gd`, `HEIGHT` 340: three rows of keys 100 tall with a
`ROW_GAP` of 14 between rows, a `GAP` of 10 between keys in a row and a 12
`LIFT`, `QWERTYUIOP` / `ASDFGHJKL` / `⌫ZXCVBNM` + `Enter`. **The two gaps are
different numbers and the spec named them both `GAP` until 2026-09-19**; a key
is `(1000 - 9*GAP)/10` wide with the *key* gap -- **91** -- with the middle row
centred on its own 899 and the last row spending what the seven letters leave
on a 126 ⌫ and a 157 Enter, the wider of the two, in `GOOD` with `PAPER`
lettering, because it is the one key that commits.

It emits `key(letter)`, `erase` and `enter`, and takes `set_marks(Dictionary)`
to repaint. **Every key stands in a slot**, not directly in the container: a
key that presses or bumps writes its own position, and a container rewrites
its children's positions on every sort, which is the lesson Balance's weight
cards paid for on 2026-09-18.

## 7. Colour

| Name | Hex | Where |
|---|---|---|
| `Pal.GOOD` | `#7cb06b` | A `HIT` tile and key; the Enter key. |
| `WORD_NEAR` | `#e9ba55` | A `NEAR` tile and key. New: `SUN_RAY` is a brighter lemon than the mock's amber and reads as the sun rather than a mark. |
| `WORD_MISS` | `#8a8078` | A `MISS` tile and key. New, and warm: the mock's grey is cooler than anything in the palette, and a cool grey goes muddy on cream. |
| `Pal.SURFACE_HI` | `#f1e6d2` | An empty tile. |
| `KEY_FACE` | `#fffaf0` | An untouched key. New, a shade above `SURFACE`, so the keyboard reads as a slab and not as six more cards. |

A marked tile letters in `PAPER`; an empty tile's typed letter is `TEXT`.

## 8. What the board says

**The toast.** Refusals do not get a card. A small pill in `TEXT` at 0.92 with
`PAPER` lettering pops in over the top of the grid, holds 1.2 s and pops out:
*Not a word*, *Five letters*, *You guessed that already*. `Motion.pop_in_scale`
and `pop_out_scale` off the readers -- no new constants. The row shivers at the
same moment (`Motion.shiver_offset`, 2 px, 0.2 s).

**There is no tip card.** The user's call, 2026-09-19: the sprout's card is
going away across the game, and this board is the first built without one. The
registry says `"tip": false` and the flat host skips the row the same way
`"actions": false` already skips the actions row, measuring the bottom slot
from the rows it actually built -- which it already does. The rules stay in the
rules sheet behind the gear.

**Running out is not a failure.** Six wrong rows and the keyboard slides out,
the sprout rises over the grid with *The word was MOSSY*, and Reset replays the
day while the gear's New puzzle gives a fresh one. No red, no "you lost". The
board calls `finish_unsolved()`, new on `core/puzzle_base.gd`: it stops the
clock and the chrome greys exactly as a solve does, but `solved` never fires,
so the host shows no win screen. The host connects the new `ended` signal to
its `_refresh`, which is all it needs to know.

## 9. Motion

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`). The tiles are drawn off the curve readers, as
Nonogram's are; the keys are nodes in slots taking the recipes, as Queens'
bees are. This board is the hybrid precedent's eleventh user and needs nothing
new from `core/motion.gd`.

**Its signature is the flip**, and its numbers are its own three constants:
`FLIP_STEP` 0.16 s per tile, `FLIP_TIME` 0.42 s a tile, `TOAST_HOLD` 1.2 s.

| Moment | What happens |
|---|---|
| Entrance | The grid pops in wide about its centre (`wide_pop_scale`, from 0.88) while it fades, after 0.18; the keyboard's rows slide up under it, 0.03 apart. |
| Type | The tile takes the letter with a pop (`pop_in_scale`, 0.18) and a faint bump of its border; the key presses (`press_scale` 0.94). |
| Erase | The letter shrinks out with the quarter turn (0.12) and the tile's border settles. |
| Commit | **The flip.** The row's five tiles turn on their X axis in sequence, `FLIP_STEP` apart, each a `scale.y` squash to zero and back over `FLIP_TIME`; a tile takes its colour at the halfway point, edge-on, so the answer arrives with the turn and never before it. `ui/faces/mosaic_tile.gd` already takes a Vector2 scale, so this costs no new mesh and no new class. |
| Keys repaint | When the last tile of the row lands, every key the row touched bumps (`bump_scale`) and takes its new colour. Not before: the keyboard must not give the row away. |
| Refused | The row shivers, the toast pops in, nothing commits. |
| Hint | A ring in `LEAF` over the chosen column, the letter drops into the typed row's slot from 40 above with the fade (0.3 s) ghosted at 0.55, sparkles in leaf, and that key greens with a bump. It is a given, not a guess: the player still types it, and it never spends a row. |
| Reset | Every committed row's tiles shrink out in a wave from the last row up, 0.03 a tile; the keys clear their colours together. |
| Solved | The winning row's tiles hop 10 letter by letter (0.04 apart after 0.25) with sparkles in gold, and the rows above fade to 0.3 so the answer is the only thing lit. The win after `WIN_WAIT` 1.6 s: no cast, five green tiles spelling the word, "Found it." |
| Over | The keyboard slides out (0.25), the rows dim to 0.4, and the sprout rises from the bottom of the card over 0.35 with the word on a small card beside it. |

Under reduce motion: the grid is up at once, a committed row colours in one
frame with no flip, the toast appears and goes without a scale, nothing hops,
rings, shivers or sparkles, and the win follows the last Enter.

## 10. The hint

Two, not the mock's three. Three of five letters revealed leaves a two-letter
guess, which on most days is the answer handed over; two rescues a stuck day
without ending it. A hint picks the leftmost position the player has not
greened yet, records it in `given`, and shows that letter ghosted in the typed
row at its own column with the key greened. It never commits a row and never
counts as a move; it clears nothing, because the board keeps no history.

## 11. The menu card

`ui/menu/card_art.gd` gets one `_build` branch: three letter tiles in a row --
one `GOOD`, one `WORD_NEAR`, one `WORD_MISS`, lettered `H`, `I`, `D` -- seated
on the shared scenery band in the 320 by 118 box. Drawn, not a `SubViewport`
and not an image. `short` is `"Five letters,\nsix tries."`, which is fifteen
and eleven against the card's seventeen a line.

## 12. Calls this screen is for

- **A permissive accept list.** 15,921 words means `AALII` and `ZYMIN` are
  legal guesses. The alternative is refusing real words, which is worse. Judge
  on the phone: if being able to type junk feels wrong, the list can be cut to
  a curated 9k in an afternoon, and nothing else moves.
- **Two hints, not three.** The mock says three.
- **No Undo.** Committing a guess you did not mean is the one irreversible tap
  on any board in this game. The original has the same rule and nobody argues
  with it, but this game is gentler than the original everywhere else.
- **The word revealed on the sixth row.** Section 8's call. The alternative is
  telling the player to come back tomorrow, which is truer to the original and
  crueller than this game has ever been.
- **968 answers.** About two and a half years of days before one repeats on
  hard, eight months on easy. If that is short, the list grows and nothing
  else changes.
- **149 tiles, and the 120 band that bought them.** Five across is the fewest
  any flat board asks for, so the cell could be 169 -- but at 169 the grid
  fills the card's inner height exactly and the mock's clouds and bushes have
  nowhere to stand (measured on the concept tab, 2026-09-19). 149 with a band
  is the call; 169 with the scenery reduced to a hem is the alternative, and
  it is one constant either way. Judge it on the phone: does the band earn its
  room, and does the cell feel generous rather than empty?
