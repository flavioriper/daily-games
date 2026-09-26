# Nonogram, flat: the ninth screen on trial

Status: built, 2026-09-18. Concept page:
`docs/brainstorm/concepts.html#nonogram`. Sibling specs:
`2026-09-18-binairo-flat-design.md`, `...-codebreak-`, `...-balance-`,
`...-shikaku-`, `...-untangle-`, `...-tents-`, `...-lightup-` and
`...-oneline-flat-design.md`.

Picross: the numbers beside each line count its runs of filled cells, in
order, and the finished grid is a picture. This is the last of the twelve
boards to be drawn flat, and the ninth and last of the screens on trial.

## 1. What flat buys here, honestly

This is the largest margin of the nine, and it comes down to one thing.

- **In a nonogram the clues are the puzzle**, and the island puts them on
  marker stones. A stone carries one numeral and needs a whole cell of
  platform to stand on, so the clue margin is as wide as the longest clue is
  long -- and it caps the grid at nine, because a run of "10" has no stone
  face. Flat, a clue is text in a band: it costs 0.55 of a cell, it can say
  any number, and it can change colour legibly.
- **You read a clue constantly and a cell once.** A hard board has 18 lines
  and about 47 numbers, consulted on every deduction, and on a board pitched
  at seven degrees the far band is the smallest, most foreshortened thing on
  the screen. This is Tents' argument again, only stronger: Tents had 16
  counts, this has 47, and they are the entire input to the puzzle.
- **And it buys the five-cell guides.** Every nonogram in the world rules a
  heavier line every fifth cell, because counting to seven along a row of nine
  is where mistakes come from. The island has nowhere to put one -- a grout
  line between flagstones is not something you can thicken -- and flat draws
  it in one stroke.
- **What it costs is the relief.** The island's finished grid is a mosaic
  floor in real relief, lit and shadowed, and that is a better *reward* than
  tiles on parchment: the whole point of a nonogram is the picture at the end,
  and the island's picture is an object. This screen answers with the reveal
  in section 8 rather than with the surface, and that is the trade the verdict
  has to weigh.

## 2. What was built

| File | New? | Job |
|---|---|---|
| `puzzles/nonogram_state.gd` | new | The rules, scene-free: the picture, the clues, what the player has put on each cell, and every move that changes it. |
| `puzzles/nonogram2d.gd` | new | The flat board: the floor, the clue bands, the guides, the stroke and the sprout's lines. |
| `ui/faces/mosaic_tile.gd` | new | The socket, the tile and the pebble, as builder shapes both the board and the tray batch (section 5). |
| `ui/flat/tile_tray.gd` | new | The two chips. `symbol_tray.gd`'s sibling; the registry asks for it with `"tray": "tiles"`. |
| `ui/flat/flat_host.gd` | edit | The `"tiles"` case in the tray match, and the row's height in the bottom slot's sum. |
| `core/palette.gd` | edit | A tile's bottom edge and highlight, the teal of a grouted one, the pebble on a ruled-out socket, and the clue numbers' two states. |
| `ui/theme.gd` | edit | `ChipLabel`: the word beside each chip's picture. |
| `ui/registry.gd` | edit | `nonogram` goes flat; `nonogram_island` keeps the island board, seeded from the same day. |
| `tests/_win.gd` | edit | One driver solves both boards. |

The generator is untouched. `puzzles/nonogram_gen.gd` -- the smoothed noise,
the clue extraction and the line-solver that proves every board is fair -- is
the island's, and both boards run the same ladder, so a day lays the same
picture on each.

## 3. The state is the one truth

`puzzles/nonogram_state.gd` holds the picture, the clues, `marks` (a cell is
absent, `FILL` or `MARK`), `locked`, and the history. It is
`puzzles/nonogram3d.gd`'s logic with one deliberate difference.

**A stroke is a move, not a tap.** The island cycles a cell blank -> tile ->
cross -> blank on repeated taps, which is three taps to correct a cross and
one tap per cell besides; a hard board is 81 cells of which about 43 are tiles
and 38 crosses. Here the tray says which of the two a stroke lays, a stroke
that begins on your own paint rubs it out, and the history records a *list* of
cells -- so a painted run of six comes back on one Undo rather than six. This
is the one place the flat board's history differs from the island's, and it
follows from the gesture rather than being a decoration.

Two things the state is careful about:

- **The win test is the picture and never the clues.** A grid can have every
  line reading exactly as its numbers say and still be wrong, because the
  clues describe runs and not positions. `is_solved` compares cell for cell
  with the bitmap, and the sprout says so in those words (section 7) rather
  than pretending the board is finished.
- **A cross is a note, not a claim.** `row_line`/`col_line` read a cross as an
  empty cell, `wrong_tiles` never returns one, and Check never looks at one.
  Crosses are never marked wrong, never counted against the player and never
  checked.

The island script keeps its own copy of the rules until the verdict; whichever
board survives, the state is the one truth to keep.

## 4. The cast is nobody

**This is the first flat screen with no character on the board at all.** Its
pieces are tiles and its clues are numbers, and the only face anywhere on it
is the sprout's on the tip card. Every other flat screen has something alive
on the board -- Binairo's suns and moons, Code Break's friends, Balance's
fruit, Shikaku's markers, Tents' conifers, Light Up's lanterns, One Line's
snail -- and drawing one here would mean putting a face on a square for the
sake of it.

That may be the honest answer for a puzzle made of arithmetic, or it may be
the one screen that reads as a different game from the other eight. It is
call 10.2 and the page does not pretend to have settled it. What it does
instead is make the *floor* an object rather than a painted grid: a tile has
a grout line, a bottom edge and a sliver of light on its crown, and a
ruled-out cell takes a real pebble.

## 5. How it is drawn

**One mesh for the whole floor.** Every socket, guide line, tile and pebble
goes into a single `Face.Builder` mesh, rebuilt only when something moves --
81 cells and about 120 shapes in one `draw_mesh`. None of them has a face on
it, so none of them needs a Control: a Control per cell would be 81 nodes for
a field of squares, and gl_compatibility pays per draw command
(`ui/faces/face.gd`'s measurement, and the `canvas-primitives-are-objects`
note). `ui/faces/mosaic_tile.gd` is the three shapes, static, so the tray
draws the same tile and the same pebble the board does -- what the tray offers
is literally what the finger leaves behind.

**The clue numbers are drawn over it with one `draw_string` each**, as
`puzzles/lightup2d.gd` draws its numerals: a digit in a mesh cache key would
multiply every state by ten, and a hard board carries about 47 of them.

**The mesh the last `_draw` handed over is kept** (`_shown`). A canvas command
holds a mesh by RID and not by reference, so a board that rebuilds its cache
every frame and drops the previous one leaves the renderer drawing a freed RID
-- "Parameter mesh is null", and an empty card -- on any frame rendered
without its queued redraw flushed first. `lightup2d.gd` and `oneline2d.gd`
learned this; this board was written with it.

**A board left alone costs nothing.** `_animating` is true while a stroke is
running, through the entrance, through any cell's pop, dip or Check shake, and
through the win's whole 2.2 s; otherwise the board never asks for a frame.
Unlike every sibling it has no character to sway or blink, so idle really is
idle.

## 6. The tray and the gesture

**Two chips, and a drag paints the one you picked.** `ui/flat/tile_tray.gd`
is a tile chip and a cross chip, each wide enough to carry its word, the
armed one lifted with the sun border exactly as Binairo's chips take it. The
tray only asks; the board owns `brush` and the tray reads it back, so a board
that drops the brush is shown here too.

- **A drag that starts on your own paint rubs it out.** The stroke's job is
  read off the cell it began on, exactly as Tents' and Light Up's sweeps are,
  so there is no eraser chip to arm and no mode to get stuck in.
- **A stroke locks to a row or a column** the moment it leaves the first cell,
  by whichever direction is larger, and every cell between the last one
  painted and this one is filled in, so a fast finger leaves no holes. A
  nonogram is played in lines, and a finger dragged across a phone wanders;
  without the lock, painting a run of six in the middle of a 9x9 reliably
  catches a cell in the row above. The lock is not breakable: lift and
  re-press to paint a new line.
- **A cell is painted once per stroke.** Crossing back over your own stroke is
  how a finger wanders, not a second decision.
- **A tile a hint grouted in refuses the finger** with a dip and a word, and a
  stroke passing over it leaves it alone.

## 7. What the board says, and what it will not

Feedback is **per line and never per cell**, which is the help a nonogram
player actually wants. A line's numbers turn green the moment its filled runs
read exactly as the clue says, and rose the moment the line holds more filled
cells than the clue can account for. Nothing on the board ever points at one
cell -- the lines do the talking, and that is the island's decision kept
unchanged.

A ruled-out cell reads twice, as it does on the island: the socket goes a
shade darker *and* takes a pebble. On a hard board 38 of the 81 cells end up
like that, so the difference between "ruled out" and "nobody has looked at
this yet" has to survive being half the grid.

The sprout's line, in order of precedence:

| When | What it says |
|---|---|
| idle, floor bare | the three tips, cycling every 10 s |
| any line over-filled | "N lines hold more filled cells than their numbers allow." |
| every line reading right, still wrong | "Every line reads as it should. Something is still in the wrong place." |
| otherwise | "N tiles still to lay." |
| all the tiles down, lines disagree | "All the tiles are down. N lines still disagree." |
| after Check | "N tiles are in the wrong place." / "Every tile you have laid belongs to the picture." |
| after a hint | "That tile belongs to the picture, and it is grouted in for good." |
| on a grouted tile | "That tile is grouted in. A hint laid it." |
| solved | "There it is. The picture you were counting towards." |

## 8. The screen, and the reveal

| Row | Height | What is in it |
|---|---|---|
| Top bar | 180 | Back, `NONOGRAM` in ink with the leaf, `NUMBERS MAKE A PICTURE` under, then Undo, Hint with its count and Settings. |
| Day card | 120 | A tree, the day, the island's name. |
| Board card | cut to fit | The floor on parchment, with the clue bands above and to the left. |
| Tray | 150 | The tile chip and the cross chip. |
| Actions | 130 | Reset and Check. `capabilities()` is undo, hint and check. |
| Tip card | 140 | The sprout and one line. |

The bottom slot is therefore 460, the same as Binairo's and Code Break's.

**The board card is cut to the floor and centred**, `card_height` and
`card_centred` both -- the fourth board of the nine to want both (Tents, Light
Up and One Line are the others), and for the same reason: the grid is square
while the space is tall, so the cell is capped by the width and there is slack
however the card is cut. Air above and below reads as centring where all of it
below reads as a board that fell over.

The band is measured from the puzzle in hand -- as the island measures its
margin of bare platform -- so a gentle picture gets a tight board. A number
costs **0.55 of a cell** rather than the whole cell a marker stone needs,
which is most of why a 9x9 fits at all.

Motion:

| Moment | What happens |
|---|---|
| Entrance | The clue numbers fade along their bands, the sockets arrive on a diagonal, the guides last. |
| Painting | A tile pops in with its grout line; a cross's pebble arrives with the same overshoot. Cells under a running stroke carry a faint shade, so the gesture is visible while it happens. |
| A line settling | Its numbers go green on the frame the count changes, and rose the moment it is over-filled. Nothing waits for Check. |
| A grouted tile | Teal rather than a darker slate -- two neighbouring darks are the one thing that will not read -- and it refuses the finger with a dip. |
| Check | Every tile the picture does not want shakes. Crosses are left alone. |
| Solved | The crosses clear in a scatter, the empty sockets fade back to parchment, **the grout lines close up**, the clue numbers go faint, and the tiles hop in reading order 0.02 s apart. |

**The reveal is the win.** The board *is* the reward here, more than on any
other screen, so `flat_win` shows no cast at all: everything that was
working-out leaves and what stays on the card is the picture as a single
shape. Closing the gap is not enough on its own -- four rounded corners
meeting leave a star-shaped hole of parchment -- so the corner radius comes
down with the inset, and the tiles' highlights go with the grout, because
eighty of them on a finished picture read as noise across it rather than as
relief. The clue numbers fade to 15% rather than to nothing: a picture with
the numbers that made it still faintly beside it reads as an answer, where a
bare picture reads as a screensaver.

## 9. Measured

The ladder, over 120 generated boards a step (the concept page's measurement):
every board line-solves, the picture fills 51-53% of the grid, and the longest
clue runs to 1.6 numbers on easy, 2.1 on medium and 2.6 on hard (worst seen:
3, 4 and 5). Generation is effectively free -- under a millisecond, 1.4
attempts on hard -- and on all 360 boards the line-solver's fixpoint came back
*equal to the stored picture*, which is what makes the answer unique and the
board guess-free.

Cells land at 154 on easy, 116 on medium and 88 on hard; 80 when a clue runs
to five numbers.

On this Mac, a hard board half laid: **68 draw calls and 203 render objects**,
against the 855-call budget in `docs/art/blender-contract.md`. The whole floor
is one of those calls and the clue numbers are most of the rest -- the fewest
calls of any flat board measured, against Tents' 111 and Binairo's 162 on
their own hard boards, because a field of squares with no faces on it batches
where a board of characters cannot. Idle, the three are indistinguishable
(11.9, 11.9 and 11.9 ms in a windowed harness with the menu still behind the
host, two readings each): the number is the harness's floor and not the
board's, and a board left alone asks for no frames at all.

`tests/_win.gd` drives both boards from one driver and both win:
22/22 winnable, board fit and HUD checks green. A throwaway probe drove the
stroke through `_gui_input` and confirmed the axis lock holds a wandering
finger to its row, that one stroke is one history entry and one move, that a
stroke beginning on your own paint rubs it out, that the cross chip paints
crosses and a tile goes straight over one, and that a grouted tile survives a
tap on it.

## 10. Calls this screen is still for

1. **88 is a small cell, and 80 is smaller.** That is 32 and 29 CSS pixels
   against the 44 you want under a thumb -- the tightest board of the nine.
   The gesture is a drag rather than a tap, which forgives a great deal, and
   the axis lock forgives more; whether that is enough on a 9x9 is a thumb
   question, and only the phone answers it. The levers, in order: shrink the
   clue band's 0.55, drop hard to 8x8, or accept the drag.
2. **No character on the board at all** (section 4).
3. **Is the picture worth anything when it is a blob?** The generator smooths
   noise into shapes, so what you reveal is pleasing but abstract -- never a
   cat. The reveal is the strongest thing this screen does, and it is showing
   off something nobody authored. A hand-drawn set of pictures per day is the
   obvious answer and a content pipeline nobody has asked for.
4. **Two chips, or one chip and a long press?** The tray costs a 150-tall row
   on the tightest screen in the set. Dropping it would give the board about
   13% more cell.
5. **Whether the axis lock should be breakable** -- lift and re-press to paint
   a new line, as it is here, or allow a stroke to turn a corner the way some
   picross apps do.
6. **Whether Check should say anything about crosses.** It refuses to on
   purpose (a cross is a note), but a player who has crossed out a cell the
   picture wants is heading for a contradiction they will not find for another
   twenty strokes.
7. **The ladder stays 5 / 7 / 9.** The nine-wide cap is the island's
   constraint, not this screen's -- the flat board could go wider, since a
   clue is text and a "10" is as cheap as a "1". The series' rule is that the
   game is identical and only the screen is on trial, so widening it is a
   decision for after the verdict.

## 11. Amendment: the polish of 2026-09-19

The user asked for One Line and Nonogram to be polished with proper
animations on Binairo's pattern, smoother and more elegant, and for the
pattern to be kept so the other boards take it. Built straight in Godot, as
the seven ports before it were, with this amendment and
`docs/art/flat-motion.md` as the record. The layout is kept; sections 2 to 7
stand. Section 8's motion table is superseded by what follows; its reveal
paragraph stands.

**Everything drawn, off the readers.** The floor stays one mesh, rebuilt
while an `_anim_until` clock runs that every moment extends through
`_busy_for`, and every piece reads the recipes as curves off `Motion` (rule 8
of the motion doc); the board's own `_back_out`, `_dip_at`, `_flash_at` and
`_at` are gone, and so is the 7 percent shade under a running stroke. Every
move -- a tap, a sweep, an undo, a hint, a reset -- goes through one
`_transition` that diffs a snapshot of the marks against the state, Light
Up's shape. `ui/faces/mosaic_tile.gd` takes its scale as a Vector2 and a turn
and a blush, so a drawn tile can squash, wobble, turn out and flash. The clue
numbers are `draw_string` still, but through one `draw_set_transform` per
line, so a line's numbers pop in, bump and hop together. The pattern grew
nothing here.

**What changed, moment by moment:**

| Moment | Now |
|---|---|
| Entrance | the whole floor -- sockets and guides -- pops in wide about its centre (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 over `ENTER_POP` 0.25) while it fades in, as one draw transform over the mesh, after `ENTER_DELAY`; each line's numbers pop in with the squash (`pop_in_scale`) along their band at `ENTER_STAGGER` 0.03, `ENTER_FACE_LAG` after the floor, rows from the top and columns from the left together. The sockets' diagonal fade and the numbers' 0.35 s fade are gone |
| Press | the cell under the finger sinks to `PRESS_SCALE` 0.94 (`press_scale`) and shades a third of the way toward `LINE` (`Mosaic.SINK_SHADE` 0.35, since 0.94 alone is invisible on pale stone), a tile or a pebble there sinking with it; on release it springs back. Nothing pressed before |
| Place (a tap) | the tile or pebble pops in with the squash (`pop_in_scale`, `POP_IN` 0.22) in place of a bare back ease; a puff in the piece's colour (`MOSAIC` or `SOCKET_PEBBLE`); the pieces on its four sides lean away 0.03 of a cell and back (`nudge_offset`); the row's and the column's numbers bump (`bump_scale`, the Count moment) when a tile joins or leaves the line |
| Sweep | every cell the finger can change sinks as it passes and stays down; on release the pieces arrive in a wave along the finger's path at `ENTER_STAGGER`, each cell springing back as its piece lands. No puffs, no nudges. A rub-out runs the same wave with the pop out |
| Remove, undo | a leaving piece shrinks to nothing with the quarter turn (`pop_out_scale`, `POP_OUT` 0.12), drawn from a leaving list after the state has forgotten it; an undo takes a stroke back in the wave it was laid in |
| Hint | a ring in `MOSAIC_LOCK` through `Fx2D.ring` at 0.62 of a cell, the tile drops in from `DROP` 40 above with the fade (`drop_in_lift`, `appear_level`), a sparkle in the same teal; a pebble under it pops out first |
| Wrong on Check | each wrong tile wobbles about its centre (`wobble_angle`) and blushes seven tenths of the way toward `BAD_TILE` and back (`flash_level`; slate to full pale rose is a flashbulb). The 0.6 s shake is gone |
| Refused | a grouted tile shivers (`shiver_offset`, 0.03 of a cell) and blushes the same way; the sprout says why. The dip is gone |
| Reset | every tile and pebble shrinks out in a wave from the far corner at `RESET_STAGGER` 0.02, a grouted tile in its teal; every line's numbers hop `RESET_HOP` -4 as the wave reaches their band and bump for each tile that leaves their line. Everything vanished on one frame before |
| Solved | the tiles hop `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4 along the diagonal from `SOLVE_DELAY` 0.25 at `SOLVE_STAGGER` 0.04 (they hopped in reading order 0.02 apart before); the reveal -- the pebbles clearing in a scatter (`CLEAR_*`), the sockets and guides fading back to parchment and the grout closing (`GONE_*`), the numbers going faint (`CLUE_GONE`) -- stays this board's own. `WIN_WAIT` 1.6, from 2.2 |

**The dressing:** a soft disc (`Scenery.soft_disc`, 0.2 peak in `TEXT`, a
little below and wider than the pebble) under every pebble, so it lies on the
floor rather than floating on it; the tray's chip shows the same. The tiles
sit flush in their sockets and cast nothing. No clouds or tufts: the floor
fills the card. The tile tray's squash and lift times come from
`Motion.CHIP_LIFT_TIME` now; only its 10 px lift stays its own, for a taller
chip.

**Measured** on this Mac at 1080 x 1920 through `tests/_shot_anim.gd`, whose
Nonogram run now sweeps the top row with the tile chip (`empty` skips it), two
readings each:

| | Draw calls | Idle |
|---|---|---|
| Medium board at rest, bare, before | 68 | 3.04 ms |
| Medium board at rest, bare, now | 68 | 3.01, 2.97 ms |
| Now, with the top row swept | 68 | 3.27, 3.23 ms |

Suite 2086/0. `tests/_win.gd` windowed 9/9, Nonogram solved through the real
hint button, Check and taps. A throwaway probe shot the entrance in three
frames, a tapped tile popping and landed with its column's number bumped, a
sweep with the row sunk under the finger, the wave arriving and the row
laid, an undo mid-wave and done, a pebble popping and landed on its shadow,
a hint's drop under its ring, a refused grouted tile, Check's wobble on a
wrong tile, Reset mid-wave and done, the solve wave, the reveal and the win
screen, each with and without reduce-motion (under which the floor and the
numbers are up at once, a piece is there or gone in one frame, a sweep lays
its row at once, nothing sinks, blushes, wobbles or rings, and the win screen
follows the last tap).

Open, still, from section 10: the 88 px cell, the empty cast, the abstract
picture, the two chips, the breakable lock, Check's silence on crosses and
the ladder. Nothing here answers them; it only makes the flat board move with
the same hand as the other eight.

## 12. Amendment: the second polish, 2026-09-25

The user asked for the design and the animation to be polished. Built
directly, like the second passes of Code Break, Balance, Untangle, Shikaku,
Tents, Light Up and One Line the same evening, and this amendment is the
record. The rules, the layout, the gesture, the two chips and every motion in
section 11 are unchanged.

**A tile is glazed ink blue, not slate.** On parchment with nothing else as
dark, `SLATE` read as a black square, against the shading direction;
`Pal.MOSAIC` is `4a5672` now, with `MOSAIC_DEEP` and `MOSAIC_HI` to match, so
the picture is still the darkest thing on the card. The menu card and the
tray's chip take it through the same constants. **A tile has a bevel**
(`Mosaic.BEVEL`, `RIM_LIGHT`): the crown sits a little down and in from a rim
lit toward `MOSAIC_HI`, so it is lit from above along its top and sides. That
replaced the single highlight dash, which on a 9x9 read as eighty small marks
rather than eighty raised tiles. The bevel closes with the grout on the win,
as the dash did. Each tile carries a `tone` off its cell's hash, within
`TONE` 5% lighter or darker, so the floor reads as laid by hand and a tile
keeps its shade from one day to the next.

**Every line's numbers sit on a paper tab** (`TAB_*`), which says which line
a number belongs to rather than leaving it floating in the band. A tab washes
toward its line's verdict over `WASH_TIME` as the tile that decided it lands:
a third of the way to `GOOD` when the line reads right, most of the way to
`BAD_TILE` when it holds too much. The numbers keep their green and rose
ink. The tabs leave with the rest of the scaffolding on the win.

**The row and the column under the finger light up** toward the sun, sockets
`FOCUS` and tabs `FOCUS_TAB` of the way, so the clues a stroke is checked
against are lit while it is drawn. They follow the finger along a locked
stroke and fade out over `FOCUS_OUT` on the release.

**A dragged stroke shows its length**: an ink pill with the count in paper
from two cells on, popping in and bumping as the run grows or shrinks. It
stands `BADGE_OFF` cells off the finger, above a row stroke and left of a
column stroke, or below and right on the first row and column. The first
draft put it above the finger always, which on the top row covered the very
column clue the run was being counted against. It costs two draw commands
and only while a finger is dragging.

**A line that comes out right glints.** Its numbers hop and a light runs out
of its clue along its tiles at `Motion.WAVE_STEP` a cell (`GLINT_*`),
starting as the tile that decided it lands. It does not glint on the move
that finishes the picture, whose own wave says it louder. **On the win a
light crosses the finished picture** along the diagonal (`WIN_GLINT_*`) once
the grout has closed. The shine goes toward `Mosaic.GLAZE_LIT`, a lighter
blue. Paper and then `SUN_TILE` were tried first and both turned the picture
grey, because warm light over a cool glaze mixes to a dull midtone.

Under reduce motion none of it moves: the washes land at once, nothing
glints, and the finger's line is lit or not with no fade.

**Measured** on this Mac at `--resolution 810x1440` with
`tests/_shot_anim.gd -- nonogram`, before and after in the same session.
Draw calls are unchanged at **65**, played and bare. Bare idle reads 1.99 and
1.97 ms against 2.10 before. Played idle reads 2.48 and 2.49 against 2.12
and 2.27, and that is the harness's window, not a settled board. The swept
row completes two columns, so their glints run on to 0.76 s after the
release, about half a second into the window. An instrumented run showed no
rebuild after that. The reduce-motion pair 1 s apart is pixel-identical, and
under reduce motion ANGLE matches the default driver to a max channel delta
of 1/255 on the same 65 calls. The menu reads 258. Suite 122583/0;
`tests/_win.gd` windowed 21/21. A throwaway probe shot a stroke mid-drag
with its count, a line's glint, the settled row and the win's hop and glint.
