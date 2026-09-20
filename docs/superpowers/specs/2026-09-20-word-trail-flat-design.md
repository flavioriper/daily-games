# Word Trail, flat: the twelfth screen

Status: designed 2026-09-20, after the concept page was built and judged.
Concept page: `docs/brainstorm/concepts.html#wordtrail` -- it plays the real
generator and the real word list, and two of the rules in section 4 were paid
for there rather than guessed here. Reference: the user's mock of 2026-09-20,
`docs/art/concept-word-trail.png`. Sibling specs: the nine
`2026-09-18-*-flat-design.md`, `2026-09-19-queens-flat-design.md` and
`2026-09-19-hidden-word-flat-design.md`.

A field of letters with grey walls through it. Drag from a tile to a
side-adjacent tile -- never diagonally -- and the trail bends around the
walls; let go on a word and it locks in its own colour. **You are never told
the words, only how long each one is.** Every open tile belongs to exactly
one word, so the grid is the scoreboard: the last word locked fills the last
tile.

**The name is not Wend.** That is LinkedIn's product name for this game, and
this repo has made the same move twice already -- Mastermind ships as *Code
Break*, and the New York Times' word game ships as *Hidden Word*. The user
chose **Word Trail** on 2026-09-20. Nothing in the source, the registry or
the UI says the other name.

**The mock is right about the picture and wrong about the game.** Its *How to
play* describes a straight-line word search with diagonals; the real rules,
read off the published ones on 2026-09-20, are orthogonal trails that bend,
and the bending is the whole puzzle. What the mock settles is the field of
big cream letter tiles, the grey slabs, the day card and the tip card. What
it loses is Check (nothing wrong can sit on the board), its two chips (Queens'
tray), the crowned bee (Queens' cast), the hearts (decoration, settled
2026-09-18) and the wooden frame (no flat board wears one). What it is
missing and this screen requires is **the length slots**.

## 1. What is built

| File | New? | Job |
|---|---|---|
| `content/word_trail.json` | done 2026-09-20 | 1,132 common words bucketed by length 3-8. |
| `puzzles/word_trail_state.gd` | new | The rules, scene-free: the generator, the letters, the walls, lock/undo/reset/hint. |
| `puzzles/word_trail2d.gd` | new | The flat board: the field, the ribbons, the slots, the scenery band. |
| `ui/registry.gd` | edit | The twelfth grid entry, in the slot Pipes' `soon` card holds. |
| `ui/menu/card_art.gd` | edit | The menu card's picture. |
| `ui/faces/mosaic_tile.gd` | reuse | The letter tile, as Hidden Word already uses it. |
| `tests/test_word_trail.gd` | new | The state class: generation, coverage, lock, undo, reset, hint. |

Nothing else moves. No new character is drawn (section 8), no new colour is
added to the palette (section 7), and `core/motion.gd` gains nothing
(section 9).

## 2. Where it stands on the first screen

Word Trail takes **the last slot of the last row**, which is Pipes' dimmed
`SOON` card. Pipes keeps its island board under More, exactly as Snake Apple
did for Queens on 2026-09-19 and Horse Pen did for Hidden Word the same day.
The grid stays twelve cards, three across and four down, and the 252 card
height is untouched.

One consequence to record rather than discover: **no dimmed card is left on
the screen.** The `SOON` pill, the 55% ink and the `blocked` signal in
`ui/menu.gd` go unused. They stay in the code -- the rule that dimmed cards
stand together in the last slots is worth keeping for the next board that is
named before it is drawn -- but nothing exercises them, and a test that
asserted "there is exactly one soon card" would now be wrong.

Registry entry:

```gdscript
{
    "id": "wordtrail",
    "kind": "puzzle",
    "title": "Word Trail",
    "blurb": "Trace every hidden word. The lengths are the only clue.",
    "short": "Trace the words,\nfill the field.",
    "motto": "Every letter finds its way",
    "footer": "Trace · Bend · Fill",
    "script": "res://puzzles/word_trail2d.gd",
    "shell": "flat",
    "tray": "none",
    "actions": false,
    "difficulties": [0, 1, 2],
}
```

`"tray": "none"` because the board picks nothing up, and `"actions": false`
because there is no Check: nothing wrong can be sitting on the board to
check. Reset therefore rides up into the top bar beside Undo and Hint, the
way Balance's and Untangle's already do, and the bottom slot is **the tip
card alone: 140**, Untangle's number and Untangle's reason.

## 3. The state is the one truth

`puzzles/word_trail_state.gd`, scene-free, as every flat board's rules are.

```gdscript
var n: int                      # 5, 6 or 7
var words: Array[Dictionary]    # {word: String, path: Array[Vector2i], found: bool}
var letters: Dictionary         # Vector2i -> String, one upper-case letter
var walls: Array[Vector2i]
var order: Array[int]           # the indices of found words, in lock order
var given: Dictionary           # word index -> how many of its tiles a hint has lit
```

Words are sorted **shortest first** once at build time, and that order is the
order of the slot groups, of the colours, and of everything else. A word's
index is its identity.

Four moves and nothing else writes to the state:

- **`trace(path) -> int`** returns the index of the word that locked, or
  `-1`. It locks when `path` is exactly some unfound word's `path`, cell for
  cell and in order. Nothing else changes: there is no error state to record.
- **`undo() -> bool`** lifts the last word in `order`.
- **`reset_board()`** lifts them all. What a hint gave stays given.
- **`hint() -> bool`** lights the next tile of the shortest unfound word's
  path.

Derived, never stored: `is_solved()` is every word found; `free(cell)` is not
a wall and not part of a found word; `slots()` is the lengths, in order, with
the letters of the found ones. The Queens rule -- a thing the state can
compute is never a thing the state keeps.

**Its own cells, not merely its letters.** A trail that spells the word over
other tiles is not that word, and accepting it would break the coverage the
whole puzzle rests on and leave a board that cannot be finished. In practice
the player retraces; there is no state to recover from.

**Only a right word locks, and nothing else is refused.** A release that is
not a word simply unwinds -- no toast, no shiver, no penalty, nothing spent.
The board never says no, because it never had to say yes. This is the user's
decision of 2026-09-20 and it is a deliberate departure from the original,
which lets a plausible-but-wrong word stick and quietly kill the grid. It is
also what makes a dictionary unnecessary: the only words this game knows are
today's four to six.

## 4. Generation, backwards from the walls

**A path's shape puts no constraint on its letters.** Any five-letter word
fits any five-cell path, because each cell just holds one letter. So there is
no packing search, no solver and no uniqueness proof:

1. Off the day's `RandomNumberGenerator`, grow the paths **longest first**: a
   random free start, then a self-avoiding walk through free neighbours,
   restarting that word (up to 120 times) if it paints itself into a corner.
2. Every cell no path covered becomes a **wall**.
3. Pick a word of each length from `content/word_trail.json` and write it
   along its path.

Solvable by construction. A candidate is then **rejected** if any word of
five or more letters has no bend (a straight row is not a trail), if the open
cells are not one connected field (an island of letters reads as a bug), or
if any row or column is wall end to end (that is not carving, it is a smaller
grid with a dead strip drawn on it). What survives is **scored** at ten a
wall block less one a bend, and **the best of sixty candidates** is the day's
board.

Both of those last two rules were paid for on the concept page. Taking the
first layout that passed gave a field speckled with single walls that looked
like damage; scoring only for the fewest wall blocks then gave a board whose
entire top row was wall, because one block is cheapest when the block is a
stripe.

**Uniqueness is not required, and that is a consequence of the lock rule.**
The original's walls guarantee one solution because a wrong-but-real word can
stick; ours cannot stick, so a second valid tiling of the same letters is
unreachable -- a trail that is not one of today's words never locks, whatever
it spells.

### The bands

| Band | Grid | Words | Lengths | Tiles | Walls |
|---|---|---|---|---|---|
| Easy | 5 x 5 | 4 | 3,4,5,6 | 18 of 25 | 7 |
| Medium | 6 x 6 | 6 | 3,4,4,5,6,7 | 29 of 36 | 7 |
| Hard | 7 x 7 | 6 | 4,5,6,7,8,8 | 38 of 49 | 11 |

**The band is chosen by how much of the field it fills, not by how many words
it names.** One word of each length would leave 16 walls on the 7x7 -- a
third of the field, and twice what the user's mock draws. Repeating a length
instead fills 38 of 49 and leaves 11, the mock's number exactly. Six words is
also the most the palette's six chip colours cover, which is why no band asks
for seven. Measured on the concept page over forty seeds a band: every one
built, in one to three wall blocks.

## 5. The words

`content/word_trail.json`: **1,132 words bucketed by length** -- 108 of
three, 160 of four, 199 of five, 222 of six, 272 of seven, 171 of eight.
Common, concrete, and the same camp vocabulary the rest of the game is
written in. The rule the list is written to: **the player is shown the
lengths and nothing else**, so an obscure word is not a hard day, it is an
unfair one. No proper nouns, and no plural made by adding an *s* to a shorter
word in the same bucket.

There is no band structure inside the lists, unlike Hidden Word's: difficulty
here is the grid, not the vocabulary. The picks are independent, so the easy
board's four alone are 108 x 160 x 199 x 222 letterings -- over seven hundred
million before the paths are counted.

`content/*` is already in the export preset's `include_filter` (Hidden Word
put it there), so the file reaches the APK with no preset change.

## 6. The screen, measured

At 1080 x 1920, with 40 of margin and three 20 gaps:

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `WORD TRAIL` in ink with the leaf and `EVERY LETTER FINDS ITS WAY` under, then Undo, Reset, Hint with its count, Settings. Five buttons, which only Balance and Untangle carry. |
| Day card | 120 | The tree, `Day N`, the island name. |
| Board card | 1340 | The field, the slots, the scenery band. |
| Tip card | 140 | The sprout, its line, and the door to the rules sheet. |

Inside the card, with a 28 inset and a 14 gap, **the width binds at every
band**: `cell = min((944 - (n-1)*14)/n, ...)` and the first term wins at 5, 6
and 7 alike -- **178, 146 and 123**, against Queens' and Nonogram's 103 on
their hard boards. The grid is then 944 wide and as tall. Under it 24 of air,
then the slots' 150, and **everything left is the scenery band**: 222, 236
and 250 by band. `card_height()` returns every pixel it is given and
`card_centred()` never comes up -- there is no slack to centre, because the
band takes it.

**The slots are the only thing the player is told.** One group of empty boxes
per word, shortest first, boxes **34 by 52** with 5 between and 22 between
groups, wrapped to as many lines as it takes -- one line on easy, two on the
others. A group fills with its letters, in that word's colour, as the word's
wave reaches each tile. Nothing about a word's *shape* is ever shown.

## 7. Colour

**A locked word takes one of the palette's six chip colours, in order**, and
every part of it agrees: the ribbon over its tiles in the strong colour at
0.5, the tile faces in that colour's pale `*_TILE`, and its slot group
lettered in the deep one. No new colour is added.

| Word | Ribbon | Tile face | Letter |
|---|---|---|---|
| 1st | `Pal.LEAF` | `Pal.LEAF_TILE` | `Pal.LEAF_DEEP` |
| 2nd | `Pal.SUN` | `Pal.SUN_TILE` | `Pal.SUN_DEEP` |
| 3rd | `Pal.MOON_INK` | `Pal.MOON_TILE` | `Pal.MOON_DEEP` |
| 4th | `Pal.BERRY` | `Pal.BERRY_TILE` | `Pal.BERRY_DEEP` |
| 5th | `Pal.ACORN` | `Pal.ACORN_TILE` | `Pal.ACORN_DEEP` |
| 6th | `Pal.FLOWER` | `Pal.FLOWER_TILE` | `Pal.FLOWER_DEEP` |

An untouched tile is `SURFACE` with a rim a sixth of the way to ink and its
letter in `TEXT`. A wall is `STONE_GIVEN` with a leaf at 0.14 ink drawn on
it -- the mock's grey slab, in the family's warm grey rather than its cool
one, because a cool grey goes muddy on cream (Hidden Word's finding). The
live trail under the finger is `SUN_RAY` at 0.6, a torch beam and not a
seventh word.

**The ribbon is drawn over the tiles, not under them.** A tile is opaque; a
trail drawn under one is a trail nobody sees. The board draws the walls, then
the tile faces, then the ribbons, then the letters and the hint glow. This
cost one wrong screenshot on the concept page and is the only ordering that
works.

## 8. The cast

**Nothing new.** The thirty-eight tiles are `ui/faces/mosaic_tile.gd`, which
Hidden Word already taught to carry a letter, and the only face on the screen
is the shared sprout on the tip card and again on the win. Check `ui/faces/`
before drawing a character: in twelve screens two have earned one, and this
board seats nothing, walks nothing and has no creature in it. The mock's
crowned bee is Queens'.

The scenery band is `ui/flat/scenery.gd`'s clouds, turf and bushes, laid the
way Balance's and Hidden Word's are.

## 9. Motion

Everything through the flat boards' vocabulary (`core/motion.gd`,
`docs/art/flat-motion.md`), read as curves off `Motion` the way Nonogram's
and Hidden Word's drawn tiles read them. **It needs nothing new from
`core/motion.gd`**, and its signature is the ribbon, with two numbers of its
own: `WAVE_STEP` 0.05 s a tile and `BEAM_TIME` 0.18 s.

| Moment | What happens |
|---|---|
| Entrance | The field pops in wide about its centre (`wide_pop_scale` from 0.88) while it fades; the slot groups drop in after it, `ENTER_STAGGER` apart. |
| Dragging | The tile under the finger presses (`press_scale` 0.94), the ones behind it in the trail sit at 0.97, and the beam grows to the finger over `BEAM_TIME`. Dragging back over the previous tile retracts it. |
| Locked | **The wave.** The ribbon takes the word's colour from its first tile to its last, `WAVE_STEP` a tile; each tile bumps (`bump_scale`) as the wave reaches it and its letter drops into its slot box (`drop_in_lift`). A ring and sparkles in the word's colour on the last tile. |
| Unwound | The beam shrinks back to its first tile over `BEAM_TIME` and fades. Nothing shivers and nothing is said: a wrong trail is not a wrong move. |
| Hint | A ring in `LEAF` over the tile, which then keeps a `SUN_RAY` glow at 0.45 under a dashed outline until its word is found. |
| Undo | The word's wave runs backwards, last tile first, and its letters leave the slots. |
| Reset | Every locked word unwinds at once, each on its own reversed wave. |
| Solved | The last wave finishes, then every tile hops in one wave from the top-left corner (0.02 a tile) with sparkles in gold. The win after `win_delay()` 1.4 s. |

Reduce motion: the field is up at once, a locked word takes its colour and
its letters in one frame with no wave, the beam has no growth, nothing hops,
rings or sparkles, and the win follows the last lock.

## 10. The hint

**Three**, as the mock's badge says, and each lights **the next tile of the
shortest unfound word's path** -- its first tile, then its second. That is
the one hint this game can give: the words are hidden but the letters are
not, so the only thing a player can be short of is *where a word starts*.
`capabilities()` is `["undo", "hint"]`; `hints_left()` counts down from 3.

## 11. The menu card

`ui/menu/card_art.gd` gains one branch: a small field of letter tiles in the
320 by 118 box with one trail bending through it in `LEAF`, and the sprout
beside it. Drawn with the same `mosaic_tile` shapes the board uses, so the
card costs one branch of `_build` and nothing of `_draw`. It is never an
image and never a `SubViewport`.

## 12. What the board says

The tip card's lines, cycling while nothing is found, the way Binairo's do:

- *Drag from letter to letter. Never diagonally.*
- *Every open tile belongs to one word.*
- *The lengths under the field are the only clue.*
- *A wrong trail costs nothing. Try another.*

And on events: after a lock, *N words left*; after an undo, *Taken back. N
words left*; after a hint, *A word starts on the glowing tile* and then *It
carries on through the glow*. `rules()` is real and reachable, because this
board keeps its tip card and the tip card is the rules sheet's door.

`tip_line()` returns the sprout's own line rather than Binairo's cycle of
broken rules -- there is no rule a tap can break here.

## 13. Analytics

Nothing new. `puzzle_start`, `puzzle_complete` with `solved: true`,
`puzzle_abandon`, `hint_used`, `undo_used`, `board_reset`, `rules_opened` --
all from the host, all already wired. There is no `check_used` because there
is no Check, and this board cannot end unsolved, so the `solved` boolean
Hidden Word added is always true here.

## 14. Calls this screen is for

- **Length slots, and only length slots.** Six lengths and thirty-eight
  letters: a puzzle, or a shrug?
- **Only the right word locks.** Gentler than the original by a long way, and
  it removes the original's best trap.
- **123 at 7x7.** The biggest hard-board cell in the game. Drag accuracy is
  the thing to feel.
- **Three hints**, each worth one tile of thirty-eight.
- **The scenery band**, 222 to 250, because the width binds and the height
  cannot be spent on the grid.
- **Backwards tracing.** Trace *oats* from the S and nothing happens, because
  it spells *stao*. Right, and possibly annoying.
