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

## 15. Amendments from the build, 2026-09-20

The board was built in four tasks and measured in a fifth, all on
2026-09-20. This section is what the build found, what it changed and what
it measured -- the spec above is left as it was written, so the two can be
compared.

### 15.1 The numbers

Every reading below was taken on this Mac with the windowed harnesses at
`--resolution 810x1440`, which is the true 1080x1920 of design space, one
run at a time with nothing else on the GPU. **A single reading off this
harness is worth nothing** -- this machine's spread on frame time is a
factor of 1.6 -- so everything is quoted twice or more, including the
flattering reading, and two already-measured boards were run as controls in
the same session.

`tests/_shot_anim.gd -- wordtrail` puts the board on day 7, medium: a 6x6
field, seven walls, the words DEW POOL BIRD BRUSH TENNIS STRETCH, with the
harness dragging DEW's own three cells and the idle window opening at 2.6 s,
after the wave.

| Run | Draw calls | Idle mean, ms |
|---|---|---|
| `wordtrail`, one word locked | 65, 62, 65 | 2.51, 2.49, 2.51 |
| `wordtrail empty`, the bare field | 60, 61 | 2.40, 2.39 |
| `wordtrail rm`, reduce motion | 61, 61 | 2.40, 2.37 |
| `wordtrail` on `--rendering-driver opengl3_angle` | 65, 65 | 4.49, 4.87 |
| Queens, control, same session | 71, 71 | 2.92, 2.95 |
| Hidden Word, control, same session | 110, 110 | 3.27, 3.26 |
| `tests/_shot_menu.gd`, the first screen | 322, 322 | 8.32, 8.33 |

All of it is far inside the 855 draw-call budget: the whole board costs less
than a tenth of it, and the fullest reading on this screen is 65.

Read it this way:

- **The controls are the point.** Queens read 71 and Hidden Word 110 in this
  session, which are exactly the figures already on the record for them
  (`CLAUDE.md`, 2026-09-19). That is what says the session itself is sound
  and that the Word Trail figures beside them can be trusted; it is not a
  new measurement of those two boards.
- **The 62 is the outlier of three readings, not a second truth.** The
  settled board with one word locked draws 65 in two runs of three. The lock
  fires a ring and sparkles at about 2.26 s and the idle window opens at
  2.6 s, so whether the emitters are still alive when the window opens turns
  on a frame or two of timing -- that is the likely cause, and it is an
  inference from the timings rather than something measured directly. The
  bare and the reduce-motion boards, which have no effects in them at all,
  read 60/61 and 61/61.
- **A locked word costs about five calls** over the bare field: the ribbon,
  the ring and the sparkle emitter. The scenery band costs nothing in calls,
  because it is one mesh.
- **The menu's idle mean is the vsync cap, not a measurement.**
  `tests/_shot_menu.gd` never disables vsync and 8.33 ms is exactly 120 Hz.
  The 8.32/8.33 pair says only that the screen is inside the cap.
- **The board's ~2.4-2.5 ms idle is a real figure** (`_shot_anim.gd` runs
  with vsync off) but it is one machine on one afternoon; quote it only
  against a board measured the same hour, which is what the Queens and
  Hidden Word rows are for.

**The first screen went from 311 to 322** (2026-09-20, two runs, against the
311 recorded on 2026-09-19). The eleven cards of the old grid were unchanged
in that time; what moved is that Pipes' dimmed `soon` card left the twelfth
slot and Word Trail's live card took it, so the +11 is that swap and not a
card added to a full grid. The Queens card cost +12 when it joined, so the
price is the usual one for a card with a face and furniture in it.

**On the phone's driver.** `--rendering-driver opengl3_angle` gives the same
**65** twice, and the settled frame at 3.80 s matches the default driver's
to **5/255**, with only four pixels of 1,166,400 differing by more than
3/255 -- edge antialiasing, as Hidden Word's own check found. Nothing here
has reintroduced an `instance uniform`. The mid-animation frames do *not*
match (up to 208/255 at 0.36 s): the two drivers run the harness at
different frame rates, and a shot is taken on the first frame at or after
its time, so the wave is caught at a different sub-step. That is timing, not
rendering, and the settled frames are the comparison that means anything.

**Reduce motion stands still.** The `rm` pair 1.5 s apart (3.80 s and
5.30 s) is pixel-identical again this session:
`ImageChops.difference(...).getbbox()` is `None` and the extrema are
`(0, 0)` on all three channels. Task 3 had checked the same pair twice.

### 15.2 The top bar, and the two screens that were never photographed

Task 3 taught the shared `ui/flat/flat_top_bar.gd` to letter a title or
motto smaller when it is wider than the block the buttons leave
(`4e3d5c2`), because `Word Trail` at GameWordmark 84 measures 391 against
the 370 a five-button bar leaves. It never letters anything larger. Only
Binairo and Balance were photographed at the time, so the other ten screens
rested on an argument. A throwaway headless probe (not committed) built the
real bar for every entry in `Registry.PUZZLES` at 1080 of design width, with
each board's buttons hidden the way the host's `refresh()` hides them, and
measured every label with its own rendered face:

| Board | Buttons | Block | Label | Text | Base | Wanted | Lettered at | Width then |
|---|---|---|---|---|---|---|---|---|
| Binairo | 4 | 496 | title | `BINAıRO` | 84 | 318 | 84 | 318 |
| Binairo | 4 | 496 | motto | `Balance brings harmony` | 24 | 265 | 24 | 265 |
| Code Break | 4 | 496 | title | `Code Break` | 84 | 430 | 84 | 430 |
| Code Break | 4 | 496 | motto | `CRACK THE HIDDEN CODE` | 24 | 351 | 24 | 351 |
| Balance | 5 | 370 | title | `Balance` | 84 | 306 | 84 | 306 |
| **Balance** | 5 | 370 | **motto** | `FIND THE WEIGHT OF THINGS` | 24 | 399 | **21** | 356 |
| Untangle | 5 | 370 | title | `Untangle` | 84 | 351 | 84 | 351 |
| **Untangle** | 5 | 370 | **motto** | `EVERY KNOT COMES UNDONE` | 24 | 397 | **22** | 367 |
| Shikaku | 4 | 496 | title | `Shıkaku` | 84 | 288 | 84 | 288 |
| Shikaku | 4 | 496 | motto | `EVERY PLOT HAS ITS NUMBER` | 24 | 403 | 24 | 403 |
| Tents | 4 | 496 | title | `Tents` | 84 | 210 | 84 | 210 |
| Tents | 4 | 496 | motto | `A CAMP FOR EVERY TREE` | 24 | 340 | 24 | 340 |
| Light Up | 4 | 496 | title | `Lıght Up` | 84 | 319 | 84 | 319 |
| Light Up | 4 | 496 | motto | `LET THERE BE LIGHT` | 24 | 277 | 24 | 277 |
| One Line | 4 | 496 | title | `One Lıne` | 84 | 333 | 84 | 333 |
| One Line | 4 | 496 | motto | `ONE STROKE, NO LIFTING` | 24 | 342 | 24 | 342 |
| Nonogram | 4 | 496 | title | `Nonogram` | 84 | 390 | 84 | 390 |
| Nonogram | 4 | 496 | motto | `NUMBERS MAKE A PICTURE` | 24 | 368 | 24 | 368 |
| Queens | 4 | 496 | title | `Queens` | 84 | 287 | 84 | 287 |
| Queens | 4 | 496 | motto | `EVERY QUEEN HAS HER SEAT` | 24 | 394 | 24 | 394 |
| Hidden Word | 4 | 496 | title | `Hıdden Word` | 84 | 481 | 84 | 481 |
| Hidden Word | 4 | 496 | motto | `FIND THE HIDDEN WORD` | 24 | 335 | 24 | 335 |
| **Word Trail** | 5 | 370 | **title** | `Word Traıl` | 84 | 391 | **79** | 368 |
| **Word Trail** | 5 | 370 | **motto** | `EVERY LETTER FINDS ITS WAY` | 24 | 406 | **21** | 360 |

(The dotless `ı` is `ui/sun_dot.gd`'s doing -- it sets the lowercase i in
Fredoka's dotless glyph and seats a sun where the dot was -- so the widths
above are the widths actually drawn.)

Four labels on three boards are lettered smaller; **every other label on
every other screen is untouched to the pixel**, which is what the probe was
for. Two things it settled that the argument had not:

- **Untangle's motto was overflowing too**, by 27 at base 24, and nobody had
  said so. It is now lettered at 22 and fits. Task 3's report named Balance
  as "the only other title that overflowed"; that was two thirds right.
- **Hidden Word's title is untouched.** Its bar is built with five buttons
  because it has no actions row, but the board's `capabilities()` is
  `["hint"]` alone, so `refresh()` hides Undo, the block goes back to 496
  and the 481-wide title fits at 84. A first pass of the probe that skipped
  `refresh()` "found" it lettered at 64; that was the probe's mistake and it
  is recorded here so nobody re-finds it. Section 6's line that five buttons
  are carried by "only Balance and Untangle" should be read as **Balance,
  Untangle and Word Trail carry five; Hidden Word builds five and shows
  four**.

**The defect this probe found, and the fix.** The first fit was
`floor(base * wide / want)` and stopped there, which for
`FIND THE WEIGHT OF THINGS` is `floor(24 * 370 / 399)` = 22 -- and the face
at 22 measures **372** against a 370 block, because the font's advance
widths are not linear in the size, so one step down is not always enough.
It was reported here and left alone at the time (that task changed no game
code) and fixed in the branch's review wave: `_fit` now treats the linear
guess as a **seed** and steps down from it, one size at a time, until the
rendered face actually fits. It steps from the guess and never from `base`,
which would be up to 60 measurements for a long title. Re-measured with the
same probe after the fix: Balance's motto letters at **21** and draws 356,
Untangle's stays at 22, Word Trail's title stays at 79 and its motto at 21,
**no label overflows**, and the twenty labels that already fitted are still
untouched to the pixel.

### 15.3 Where the build departed from the spec

**The state (`puzzles/word_trail_state.gd`).**

1. `String.reverse()` does not exist in GDScript 4.7, so the backwards-trace
   guard in the generator's quality rules uses a manual `_reverse_str`
   helper. Same intent, one helper.

**The board (`puzzles/word_trail2d.gd`).**

2. **The entrance pops from 0.86, not the 0.88 in section 9.**
   `Motion.wide_pop_scale` has no `from` parameter and `ENTER_WIDE_FROM` is
   the family's constant; using 0.88 would have meant either a literal in
   this board or a change to `core/motion.gd`, and the vocabulary's rule is
   that a board keeps no number the family already owns. Hidden Word's grid
   pops from the same 0.86. Two hundredths of a scale, and the spec's figure
   was never measured off anything.
3. **The solve wave's 0.02 a tile goes through
   `Motion.stagger(index, Motion.SOLVE_STAGGER * 0.5)`.** The family's
   `SOLVE_STAGGER` is 0.04 and there is no named 0.02; halving the recipe's
   own constant through `stagger`'s parameter is rule 6 of
   `docs/art/flat-motion.md` and adds no constant. The reason is real: this
   field's diagonal runs to twelve on a 7x7, where every other board's runs
   to six or eight.
4. **A slot letter drops `SLOT_H * 0.25`, not the family's `DROP` of 40**,
   through `drop_in_lift`'s own `height` parameter: 40 is most of a 52-tall
   slot box, so the letter would arrive from the line above.
5. **The slot *groups* drop in `ENTER_STAGGER` apart, not the boxes** --
   six groups at 0.03 is a wave the eye can follow where thirty-odd boxes
   would not be. (The mock staggers per box.)
6. **The beam grows only its last segment**: `reach = (len - 2) +
   clamp(u)`. The mock pre-charges the whole trail to `clamp(u + 0.7)` of
   its length, which on a seven-cell trail leaves the head two cells behind
   the finger at the moment a cell is added. Growing the last segment is
   exactly section 9's "the beam grows to the finger over `BEAM_TIME`" and
   it needs no extra number.
7. **The field mesh became three** -- the still band, the field, the slots --
   so the entrance's pop and fade can transform the field without moving the
   band, and each slot group's drop can be baked into its vertices. `_shown`
   holds all three until the next `_draw` replaces them, so the freed-RID
   rule (a canvas command holds a mesh by RID) still holds.
8. **Ribbon corners are filleted into the centreline** before the stroke.
   `Face.Builder.stroke` has no round join, so a ninety-degree bend pinches;
   stroking each segment separately would darken where two round caps
   overlap at alpha 0.5. Cutting the corner back by the half-width and
   bridging with a quadratic gives the mock's round join in one stroke.
9. **The hint's dashed outline is this board's own walker** (`_dashes`),
   because `Face.Builder` has no dash support.
10. **`rules()` is one string, not three paragraphs.**
    `ui/hud/rules_sheet.gd` splits on `". "` into bullets and ignores
    newlines. Not a word of the text changed.
11. **The scenery band carries about eighteen geometry constants of its
    own** (the turf's edges, two cloud anchors, the blades' band, three
    bushes, five washes), and its colours are the family's
    `LEAF`/`LEAF_LIGHT`/`LEAF_DEEP` washed toward the card's `PARCHMENT` at
    Hidden Word's own wash levels, not the mock's `moss` and `cloud`. The
    "exactly two constants" rule in section 9 is a *motion* rule; the two
    are still `WAVE_STEP` and `BEAM_TIME`, and nothing was added to
    `core/motion.gd`.
12. **The whole band is drawn a second time here, not just `_bush`**, rather
    than lifted into `ui/flat/scenery.gd`. This disclosure understated
    itself when it first named only the bush, so it is written out in full:
    `_build_band`'s body, the blade loop, `_span`, `_hash` and `_bush` are
    all near-verbatim copies of `puzzles/hidden_word2d.gd`'s band, plus
    thirteen geometry constants carrying the same names (`TURF_TOP`,
    `TURF_RADIUS`, `CROWN_H`, `CROWN_RADIUS`, `CLOUD_LEFT`, `CLOUD_RIGHT`,
    `BLADES`, `BLADE_EDGE`, `BLADE_W`, `BLADE_ROOT`, `BLADE_MIN`,
    `BLADE_SPREAD`, `BLADE_LEAN`) and the same five wash levels
    (`TURF_WASH`, `CROWN_WASH`, `BLADE_WASH`, `BUSH_DEEP_WASH`,
    `BUSH_LIT_WASH`). What differs is the vertical anchoring -- Word Trail
    hangs its band off `_slots_top() + SLOTS_H` and off its own `BAND_FOOT`
    where Hidden Word hangs its off the keyboard -- the bushes' bookkeeping
    (one `BUSHES` list against Hidden Word's three named seats), and the
    flowers, which Word Trail drops. **This is the third band and the lift is now due**: the
    next board that wants one should take `ui/flat/scenery.gd` a `band()`
    and delete both copies, rather than making a fourth.
13. Pixel measures section 6 did not give (the tile, wall and slot bottom
    edges, the slot corner and letter size, the wall leaf's seat and lean,
    the hint glow's insets and dash runs, the beam's width and the ghost's
    alpha) were taken off the mock rather than invented, in the same
    1080-wide design space as the rest.

**The correction.** Task 2's report said `ui/fx2d.gd` "does not check
`Motion.reduce` itself, so Task 3 should gate them". **That was wrong**, and
it is corrected here so it is not repeated: `fx2d`'s `puff`, `sparkle` and
`ring` each return early under `Motion.reduce` already. What the board does
instead is make `_fx_at` a no-op under reduce motion, which spares it the
frames it would otherwise spend waiting on effects that will never draw --
the same net effect with no dead guard.

**The card (`ui/menu/card_art.gd`).**

14. The branch builds a plain `Control` for the field and binds its own
    `draw` signal, so nothing was added to `card_art.gd`'s `_draw` match --
    section 11's "one branch of `_build` and nothing of `_draw`", taken
    literally. Its tile slabs are `draw_style_box` roundrects in the board's
    own three colours rather than `MosaicTile.tile()`, which hardcodes
    Nonogram's; what it borrows from `mosaic_tile.gd` is `letter()`, the
    same glyph helper the board itself uses.

### 15.4 Two bugs the build found, both in the input handling

Both were in the board as Task 2 shipped it and both were fixed in Task 3.

1. **A drag off a trail of one emptied it.** The retraction branch read
   `at == _trail.size() - 2`, and on a trail of one that is `-1` -- which is
   also what `find()` returns for a cell that is *not* on the trail. So
   dragging from a single tile to a non-adjacent free cell resized the trail
   to nothing and left the finger holding a beam that did not exist. It
   shipped silently and only became visible when a later change turned it
   into an out-of-bounds. Guarded with `at >= 0`.
2. **A slot letter had no moment to sit still on while its word was
   lifted.** `_slot_wave` returned the current time for a word that is not
   found, so `drop_in_lift(0)` put every letter of an unwinding word at full
   lift and `appear_level(0)` at zero alpha: on undo the letters vanished in
   one frame instead of leaving tile by tile with the wave. Fixed to a past
   moment. Caught on a rendered frame, not by a test.

### 15.5 What is still open

- **The slot layout walk is written twice.** `_build_slots` and
  `_draw_slot_letters` each compute `tall`, the group's `y`, the per-line
  `x`, the per-item timings and the advance, in the same order and with the
  same arithmetic -- one builds the boxes, the other letters them. A future
  edit to the wrap rule in one of them slides every letter off its box, and
  no test would catch it, because no test covers the board (below). A shared
  `_slot_boxes()` handing back the boxes and their moments would collapse
  both. **Deliberately deferred**: it came out of the whole-branch review,
  and changing the draw path after the board had been photographed and
  measured would have invalidated the figures in 15.1 for a refactor that
  fixes no defect.
- **The band is a third copy.** Section 15.3, item 12: the lift into
  `ui/flat/scenery.gd` is now due.
- **The solve wave has never been in the strip.** `tests/_shot_anim.gd`
  locks one word of six, so it cannot reach a solve; the solve, the hint,
  the undo and the reset were all seen on a throwaway probe instead. A
  `solve` mode in the harness, as Hidden Word has, would be the honest fix.
- **The band's upper half is fairly empty** at the band a medium board
  leaves it (section 6's 236, not re-measured here; Task 3's build reported
  233). Two clouds is what Hidden Word puts in a 120-tall band. It
  reads as air rather than as a mistake, and the mock has the same shape.
- **No test covers the board**, only the state class
  (`tests/test_word_trail.gd`), which is where every other flat board
  stands.

Amendment (2026-09-25): tracing is heard and spelt. Every tile taken or
given back ticks (`select`, a short kalimba pluck) at a pitch that climbs
with the trail's length, Shikaku's count tick. And the trail being traced is
spelt into the slots as it grows: into the smallest unfound word it still
fits (the first of those in the slots' order), its boxes leaning to the
beam's sun with the letters in ink and the rest of that word's boxes rimmed
in it, stepping to the next size up as the trail outgrows each. It tells no
more than the lengths already do: a wrong trail is spelt the same way, and
the preview goes when the finger lifts.
