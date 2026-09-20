# The flat boards: one motion, one dressing

Every flat screen moves with the same hand and wears the same cloth. The
flat Binairo (`puzzles/binairo2d.gd`, its spec's section 6) set the hand;
Code Break was the second board to take it, on 2026-09-18, and the vocabulary
was lifted into `core/motion.gd` on that day so a third does not copy it.
Balance followed the same day, Untangle on 2026-09-19, and Shikaku, Tents and
Light Up the same morning; One Line and Nonogram followed that afternoon,
which put all nine flat boards on it. Queens arrived the same evening, built
on the vocabulary from its first line rather than ported, the tenth, and
Hidden Word followed it the same night, the eleventh, and Word Trail on
2026-09-20, the twelfth. Mushroom Patch joined the same day, also built on
the vocabulary from its first line, the thirteenth, and Sudoku the same day,
the fourteenth, also built on the vocabulary rather than ported; Bridges is
the fifteenth and Quilt the sixteenth, both the same day again, and
Pinwheel the seventeenth, the same day once more. (**Word
Trail and Bridges have no row of their own in the table below**; their
motion is recorded in CLAUDE.md and in each spec's own section. Quilt has
one, because its signature needed a shape the table did not already hold.)
This page is the table a new or
a ported board is built against. When a number here and a number in a board
disagree, the board is wrong.

## The rules

1. **Everything goes through `core/motion.gd`.** A decorative recipe returns
   `null` under reduce-motion and lands its final state at once; the state
   change itself (a face swapping, a row scoring) is essential and stays,
   shortened to `Motion.REDUCED_TIME`. A board never checks `Motion.reduce`
   to decide *what* happens, only to skip a delay that paced a decoration
   (Code Break's `_beat`).
2. **A mover owns its place until it lands.** Layout code leaves a node
   alone while its tween runs (`Motion.running`), and the recipe's landing
   callback puts it back where the layout would. Otherwise a relayout mid
   flight teleports the piece. **A piece the board places every frame
   stands in a slot.** A dragged lantern's point is written on every frame
   by the drag and the springs; the paper hangs in a slot the board owns
   (position and swing) and the recipes tween the paper inside it, so the
   two hands never write the same property. Balance's weight cards learned
   the same thing against their container, and One Line's walker rides its
   stroke the same way: the seat takes the ride, the facing and the rock,
   and the snail inside takes the pop, the drop, the press and the hop.
3. **Kill on rebuild.** Every tween a board keeps is stopped in `_stop_all`
   before the nodes it aims at are freed, and a timer is guarded by a
   generation counter (`_after`), so a new board never inherits a hop aimed at
   the last one.
4. **Stagger through `Motion.stagger(i, per, cap)`.** The cap (0.6 by default)
   keeps a big board's wave from outlasting the player's attention.
5. **Particles only through `ui/fx2d.gd`**: `puff` for a placement, `sparkle`
   for a hint or a win, `ring` for the hint's pulse, all in the board's own
   pixels. No board builds its own emitter or its own ring.
6. **One voice.** A number that has to differ for a board goes through a
   recipe's parameter (Code Break's seats nudge 7 where Binairo's tiles nudge
   3) and never through a copied constant. What a board keeps as its own
   constants is what nothing else does: Binairo's blush, Code Break's flight
   and lids.
7. **Square pops from nothing, wide from most of the way.** A tile, a lid or a
   face enters from scale 0.01; a row or a card from `ENTER_WIDE_FROM` (0.86),
   because the back ease's tenth of overshoot on a thousand units of width is
   a wobble, not a spring.
8. **What is drawn reads the same numbers.** A board that draws its pieces
   into a mesh rather than as nodes (Untangle's rings and cords, Shikaku's
   beds and the wash under its finger, Tents' cairns and the shade under its
   sweep, One Line's posts and lines, Nonogram's tiles and pebbles,
   Sudoku's eighty-one cells and every numeral on them) cannot
   call a recipe on them; it reads
   the recipe *as a curve* off `Motion`: `back_out` for the overshoot, and
   `pop_in_scale`, `wide_pop_scale`, `pop_out_scale`, `drop_in_lift`,
   `appear_level`, `bump_scale`, `flash_level`, `press_scale`, `hop_lift`,
   `nudge_offset`, `shiver_offset` and `wobble_angle` for the recipes
   themselves, each handed the seconds since its moment began and landing
   on its final state under reduce-motion exactly as the tween would. The
   set is complete since Light Up (2026-09-19): every recipe a node takes
   has its reader, so a drawn board needs nothing new from `core/motion.gd`
   -- One Line and Nonogram, ported that afternoon, added nothing to it.
   Text drawn with `draw_string` takes the same readers through
   `draw_set_transform` (Nonogram's clue numbers pop in, bump and hop by
   the line; Sudoku's digit and its nine pencil marks take one transform
   between them, so a cell's contents can never drift apart).
   One voice, two media. It never copies the number. **A board with both** (Tents: trees,
   tents and chips as nodes over drawn cairns) stands each node in a slot and
   gives it the recipes, and draws the rest off the readers; the two arrive
   on the same clock because both read the same constants.
9. **A piece with no blushing variant blushes through its cell.** The
   Refused and Wrong-on-Check rows flash the thing that was pressed or
   pointed at; a character drawn in one skin (Tents' conifer, its pegged
   tent) has nothing to flash toward, so its cell takes the wash instead,
   toward `BAD_TILE` at `flash_level`, drawn into the ground mesh. The
   piece still moves (a shiver, a wobble); the cell carries the colour.
   **And the cell carries the movement too**, where the piece is only a
   mark on it. Sudoku's numeral is a `draw_string` inside a cell that is
   nothing but a wash and a rule: shivering the numeral alone shakes a 3
   inside a square that never budges, and a cell the player has just
   emptied has nothing left to shake at all. So the cell's own layers --
   its washes, the wave's gold, its selected edge -- take the shiver and
   the bump with the numeral, and only the paper under them (the chequer)
   and the rules between them stay put, because a rule that shivered with
   one cell would tear the grid.

## The moments

Times in seconds, distances in the game's 1080-wide design units. Each row is
a recipe in `core/motion.gd` unless it names another file.

| Moment | What happens | Recipe, numbers |
|---|---|---|
| Entrance | The pieces wait `ENTER_DELAY` for the chrome to slide in, then pop in along the diagonal from the top left (a grid) or down the column (a list), with the back ease; a resident face lands a beat after its tile with the squash. A board whose pieces *do* something as they land lets them (Balance's fruit tilt the beam). The chrome slides in row by row (`ui/hud/panel.gd`). | `ENTER_DELAY` 0.18; `slide` on scale, `ENTER_POP` 0.25, `ENTER_STAGGER` 0.03; face `pop_in` `ENTER_FACE_LAG` 0.12 later |
| Press | The tile sinks under the finger and springs back on release. Every tappable piece does this, including one that will do nothing when released. A drawn tile (Light Up's stone, its block) sinks through `press_scale`; a board whose cells are tiles sinks the tile itself rather than laying a wash on it, since a 7 percent ink wash on a mid-grey stone is invisible. | `press`: `PRESS_SCALE` 0.94 in `PRESS_TIME` 0.08, back-ease out `RELEASE_TIME` 0.25 |
| Pick up · Drop | The press for a thing that is dragged rather than tapped: it grows a tenth toward the finger and its shadow parts from it (further below, wider, fainter). On release it springs back with the back ease and hops on landing; whatever weight the board gives it (Untangle's cord slack and swing) settles on its own. | `lift`: `LIFT_SCALE` 1.1 in `LIFT_TIME` 0.12, back-ease out `RELEASE_TIME` 0.25; `hop` `HOP` -6 over `HOP_TIME` 0.3 |
| Place | The old piece pops out; the new one pops in with the squash; the tile hops; the side neighbours lean away and back; a puff of five stars in the piece's colour. A gesture that places many at once (Tents' sweep) lays them in a wave along the finger's path at `ENTER_STAGGER`, the shade under each staying until its piece lands, and puffs none of them. | `pop_out` `POP_OUT` 0.12; `pop_in` `POP_IN` 0.22 with `POP_SQUASH` 0.15; `hop` `HOP` -6 over `HOP_TIME` 0.3; `nudge` `NUDGE` 3 over 0.3 after `NUDGE_LAG` 0.04; `fx.puff` |
| Remove | The piece shrinks to nothing with a quarter turn, rising a little if the board wants; whatever it hid pops back under it. | `pop_out`, optional `lift`; `pop_in` 0.18 on what returns |
| Turn | A piece swings a quarter turn clockwise about the one cell it is pinned through. It is **drawn in the orientation it has turned *to*** and the swing starts it back where it came from, so the angle is read off the board's clock and no orientation is ever stored half way between two; it passes the quarter and settles onto it, because a piece that stopped dead on the mark reads as a snap rather than as a spin. The pinwheel that is the handle turns on the same clock with a longer `time` -- a handle that lagged its piece would be a broken one, so the blades carry the overshoot the cloth does not, rather than moving apart from it. Whatever the turn changed under the piece settles in a wave out of the pin, by king-move distance, the pin being the only thing on the board that did not move. | `turn_angle` on `back_out`: `TURN_TIME` 0.26, the hub 1.55 times that; the wave `WAVE_STEP` 0.045 |
| Hint | A ring pulses out of the cell, the piece drops in from above with the back ease while it fades in, sparkles rise, the cell takes the given look. A board whose pieces walk (Untangle, One Line's walker once the stroke has begun) walks the piece to its place instead, and rings and sparkles as it lands. | `fx.ring` `RING_TIME` 0.5; `drop_in` `DROP` 40 over `DROP_TIME` 0.3; `fx.sparkle` |
| Wrong on Check | Each wrong cell wobbles and flashes toward `Pal.BAD_TILE` and back; a drawn bed (Shikaku) flashes toward its own blush, read off `flash_level`. | `wobble2d` 0.45; `flash` (`FLASH_IN` 0.15, `FLASH_OUT` 0.45) |
| Clean Check | The Check pill squashes and says All good for a moment. | `ui/flat/flat_actions.gd` |
| Undo | The reverse of Place. | as Place |
| Reset | Free pieces pop out in a wave from the far corner; givens hop `RESET_HOP`. | `pop_out`, `RESET_STAGGER` 0.02, `RESET_HOP` -4 |
| Solved | Every piece hops in a wave with JOY eyes, sparkles across the board, then the host brings the win screen. | `hop` `SOLVE_HOP` -10 over `SOLVE_TIME` 0.4, `SOLVE_STAGGER` 0.04 after `SOLVE_DELAY` 0.25; win after 0.8 or the board's `win_delay()` |
| Palette | A pressed chip squashes, lifts and takes a border in its symbol's colour. On a brush tray (Binairo) that is a mode and it stays; on a direct-action tray (Code Break) it is a beat of feedback and settles after `CHIP_LIT`. | `squash` 0.1 over 0.18; `CHIP_LIFT` 8 over `CHIP_LIFT_TIME` 0.18; `CHIP_LIT` 0.35 |
| Count | A number that was recounted bumps up and back (not a squash: it was not pressed), the thing it counts hops with a puff in its colour, and every twin of that thing on the board hops too, down the board at the board's own pace. Balance's weight cards; Shikaku's area disc as the drag grows, drawn off `bump_scale`; Tents' line chips when a tent joins or leaves their line; Light Up's numbered blocks when a lamp joins or leaves their side. | `bump` `BUMP` 0.25 over `BUMP_TIME` 0.24; `hop` `HOP` -6 over `HOP_TIME` 0.3; `fx.puff` |
| Refused | A press the rules will not take: the card shivers and blushes toward `BAD` and settles, and the sprout says why. The button still takes the press, or the reason is never given. A piece with no blush of its own (a tree) shivers while its cell blushes (rule 9); a drawn piece that *is* its cell (Light Up's block) flashes toward its own rose, read off `flash_level`; a piece that is only a mark on its cell (Sudoku's numeral) shivers the **cell** -- its wash, its gold edge and the mark together (rule 9). **Where the reason goes is the board's own call.** Hidden Word pops a toast because a keyboard fills the space a tip card would sit in; a board that already carries a tip card whose whole job is one line writes it there instead, and never both (Sudoku's `_speak`, which holds the line `SAY_HOLD` and then lets the rules resume cycling). A refusal is never a silence. | `shiver` (`SHIVER_PX` 2, `SHIVER_TIME` 0.2); `flash` toward `BAD` (`FLASH_IN` 0.15, `FLASH_OUT` 0.45) |
| Reveal | A hint that settles a card rather than a cell: the card takes the given look, the value drops in from above, the tag pops in, a ring pulses out of its character. | `drop_in`; `pop_in` 0.18; `fx.ring` |
| Tip | The line fades in and the sprout hops with its new face. | `ui/flat/tip_card.gd`: `appear` 0.25, `hop` -8 over 0.35 |
| Idle | Faces blink at their own 3 to 7 s; suns turn a revolution in 40 s; a third of the moons rock; Untangle's knots turn gently, a redraw with the mesh the board already has and no rebuild. | `ui/faces/face.gd` |

What is a board's alone stays a board's: Binairo's blush with its two
heartbeats and its focus tint; Code Break's flight from the palette, its dip
under a score, its pips dropping into the pouch, its lids and the code's pop;
Balance's tilt and the shadows that follow its dishes; Untangle's two
springs, its walks (a hint's to the peg, an undo's back, reset's home, one
`SLIDE_TIME` for all three) and the light that runs along its string on the
win, one hop of the graph per `LIGHT_STEP`; Shikaku's crop coming up bed by
bed on the win and the earth thrown at a new bed's four corners; Tents'
cairns clearing away in a scatter on the win, so the last picture is the
camp and not the working-out; Light Up's light travelling out from a lamp
stone by stone (`LIGHT_STEP`, `LIGHT_CAP`, `LIGHT_IN`, `LIGHT_OUT`), its
beam withdrawing with the cooling floor when the lamp is taken up, and its
chips clearing the same way; One Line's walk itself (`LAY_TIME` 0.28, the
plank growing under the snail and the far post keeping its old cap until
the snail lands) and its trail warming back along itself on the win at the
solve stagger, uncapped, each post hopping as the warmth reaches it;
Nonogram's reveal (the pebbles clearing in a scatter, the sockets and guides
fading back to parchment, the grout closing and the numbers going faint). A
new board may add one signature of its own on top of the table, not instead
of it.

**A row is not a cell.** The staggers above are per cell of a grid. A board
whose pieces are rows (Balance's scales, Code Break's lids) paces its waves
by row through `Motion.stagger`'s `per` (Balance's `BAND_STAGGER` 0.08,
Code Break's `ENTER_LID_STAGGER` 0.06), because three things 0.03 apart is
one thing.

## The dressing

- **Cards**: corner 28, a bottom edge of 6 in `Pal.LINE`. The live thing is
  `Pal.SURFACE`; a resting one (a history row) is `Pal.PARCHMENT` warmed 0.45
  toward `SURFACE` with the edge at `LINE` 0.45, and everything on it a blend
  of the same bigness, so a card sliding between the two states is dressed
  continuously rather than flipped.
- **Tiles and sockets**: corner 18 on a Binairo tile, 0.22 of the piece on a
  Code Break socket, a bottom edge of 4 or 5. No paper wash on anything
  smaller than a card: set `material = null` *after* `add_child`, which is
  when `CozyTheme.dress()` puts it on.
- **Dimming the rest**: sockets to 0.72, dotted rings to 0.55, an unscored
  pouch to 0.6. **The record never dims**: a scored pouch, a placed piece.
- **Faces below about 22 px are silhouettes** (`plain`), because a face there
  is a smudge.
- **A tray of things is tinted by the thing**: a chip or a card takes its
  character's `tile` colour (`Friends.tile`, `Fruit.tile`), so the row reads
  as characters and not as forms; a given one is `SURFACE_HI` rimmed in
  `SUN_DEEP` all round. Buttons on a tinted card are `SURFACE` pills. No
  wash on a tinted card: the shared stain reads as paper on cream and as
  dirt on a pastel.
- **Scenery through `ui/flat/scenery.gd`**: a board card that wants a sky
  and a ground hands it cloud and tuft anchors and gets one mesh in one
  draw call under everything. Clouds keep to the corners the pieces never
  reach; tufts stand where something meets the ground.
- **Things stand on a ground, and a ground has shadows**: `Scenery.shadow()`
  is one radial disc drawn scaled to the ellipse wanted, in `TEXT` at 0.06
  to 0.16, widest and darkest for a thing on the ground and narrower and
  fainter as it rises. One draw a shadow, redrawn only when the thing moves.
  A board that already rebuilds a mesh while its things move builds the
  same disc into it with `Scenery.soft_disc` (Untangle's cord mesh, the
  shadows first so they lie under the cords), at no draw call of their own.
  A thing that hangs rather than stands throws its shadow on the wall behind
  it, a little below and to one side; a lifted thing's shadow parts from it
  and a hopping thing leaves its shadow where it was, and that is what makes
  height read on a flat card.
- **Decoration says so**: the sparks beside Code Break's lids, the hearts on
  the menu's day row, Balance's clouds and grass. Nothing decorative may
  read as a count of anything.

## Porting a board

1. Read its inline tweens and match each to a row above. Replace the ones
   that match with the recipe, passing the board's own number only where it
   truly differs. Delete the constants the recipes now own. A board that
   integrates its motion against a clock (a drag) keeps the *point's* motion
   and puts each piece in a slot; the piece then takes the recipes (rule 2),
   and what stays drawn reads the constants (rule 8).
2. Keep `_stop_all` and its generation counter; add any new tween you keep
   to it.
3. Route every ring, puff and sparkle through `fx`. A tray that animates
   its own cards gets its own `Fx2D` (Balance's weight tray), since a
   board's effects are in the board's pixels.
4. Shoot it: `tests/_shot_anim.gd -- <id>` for the strip and the idle cost,
   and a throwaway `SceneTree` probe that plays the moments the table names
   and saves a frame of each. Read the frames; a tween that does nothing
   shows in no test.
5. Measure the fullest board's draw calls against the 855 budget and write
   the number in the board's spec.

## Boards on it

| Board | Status |
|---|---|
| Binairo | the source; its press, pop in, pop out, drop, nudge, ring and waves call the recipes (2026-09-18) |
| Code Break | on it (2026-09-18): entrance pop, seat press, flight landing with squash and puff, lit chip, pop-out on send back, flash on an incomplete Check, solve wave, ring and drop through Fx2D. Measured: fullest board 234 draw calls, 3.8 ms idle at 1080 x 1920 on this Mac |
| Balance | on it (2026-09-18): scales pop in wide and level, fruit land with the squash and swing the beam, a stepped kind hops in every dish with the card's bump and puff, a refused card shivers and blushes, a hint's card reveals under a ring, a level beam rings through Fx2D, the solve wave; plus its ground shadows and scenery. Measured: 146 draw calls, 3.24 ms idle at 1080 x 1920 on this Mac (7.42 before, when every face redrew every frame) |
| Untangle | on it (2026-09-19): rings and cords pop in along the stagger and each lantern pops onto its ring a beat later, the lift on pick-up with the shadow parting, the hop on the drop and on every walk's landing, knots undone and a hint's peg ring through Fx2D, the solve wave's hop as the light reaches each lantern; the springs and the walks stay its own. Shadows in the cord mesh, clouds and tufts through Scenery. Measured: 66 draw calls (75 before), 2.92 ms idle bare at 1080 x 1920 on this Mac (2.94 before); 4.8 ms while a dropped lantern's swing settles |
| Shikaku | on it (2026-09-19): the field pops in wide and each marker pops in with the squash along the diagonal, its shadow on the ground arriving with it and staying put when it hops; the wash and the count disc pop in under the finger and the disc bumps on every recount; a bed pops in wide, its marker hops and the markers around it lean away; a cleared or displaced bed shrinks to nothing; a hint's bed drops in under a ring with a sparkle and the family's bump; Check wobbles a wrong marker and blushes its bed; a refused drag shivers the marker and blushes the pinned bed; Reset pops the beds out in a wave from the far corner while the markers hop; the planting wave stays its own, with the solve hop and a sparkle as each bed comes up. The beds are drawn, so all of it reads the curve readers (rule 8). Measured: 95 draw calls bare (94 before) and 101 with a bed and its fence, 3.4 ms idle at 1080 x 1920 on this Mac (4.0 before) |
| Tents | on it (2026-09-19): the meadow pops in wide on the family's edge and each chip and tree pops in with the squash along the diagonal, the tree's shadow on the ground arriving with it and staying put when it hops; a tree or a tent sinks under the finger and bare ground takes a shade that pops in wide; a tent pops in with a puff, its side neighbours lean away and its line's chips bump; a sweep's shade follows the finger and the cairns arrive in a wave along its path; a tent or cairn taken away shrinks with the quarter turn; a hint's tent drops in under a ring; Check wobbles a wrong tent and blushes its cell; a refused tree or pegged tent shivers and blushes its cell (rule 9); Reset pops everything out in a wave from the far corner while the trees hop; the solve wave hops trees and tents alike to JOY, and the cairns clearing in a scatter stay its own. Nodes in slots and drawn cairns on one clock (rule 8). Measured: 97 draw calls bare (103 before), 3.4 ms idle at 1080 x 1920 on this Mac (3.3 before); 3.6 ms with a swept row |
| Light Up | on it (2026-09-19): the court pops in wide and each block pops in with the squash along the diagonal, its number and its soft shadow arriving with it; a lamp sinks under the finger and so does a block and so does a bare stone, drawn (`press_scale`); a lamp pops in with a puff, leans its neighbours away and bumps every numbered block it touches while the light travels; a sweep sinks the stones under the finger and the chips arrive in a wave along its path; a lamp taken up shrinks with the quarter turn while its beam withdraws with the cooling floor; a hint's lamp drops in under a ring; Check wobbles a wrong lamp and blushes its stone; a refused block shivers and flashes toward its rose, a refused pinned lamp shivers over a blushing stone; Reset pops everything out in a wave from the far corner while the blocks hop and the light cools in the same wave; the solve wave hops lamps and blocks alike to JOY. Lamps in slots over two drawn meshes on one clock (rule 8); it completed the readers. Measured: 63 draw calls bare (62 before) and 65 with a lit lamp, 3.15 to 3.48 ms idle over three readings at 1080 x 1920 on this Mac (3.08 and 3.12 before) |
| One Line | on it (2026-09-19): each stone line pops in wide about its middle in index order and each post pops in with the squash along the diagonal a beat later, its soft shadow arriving with it and staying put when it hops; a post sinks under the finger (and shades toward its deep colour, as Light Up's stones do) and the walker on it sinks too; the walker pops in with the squash and a puff to begin, or drops in under a ring from a hint; on every landing the post hops, its cap takes its new colour with the Count bump and a puff lands in wood (an undo lands without one); a hint after the first step walks the line and rings and sparkles as it lands; Check wobbles a stranded line about its middle and blushes it; a refused post shivers and blushes; Reset shrinks the planks out in a wave from the far corner while the posts hop and the walker pops out where it stood; the solve wave runs the trail, the planks warming and the posts hopping as it passes and the walker grinning and hopping last. Drawn posts and lines off the readers, the walker in a slot (rules 2 and 8). Measured: 63 draw calls bare (63 before) and 66 with a plank and the walker, 2.86 and 2.87 ms idle bare at 1080 x 1920 on this Mac (2.90 before), 2.89 and 2.91 with the walker standing |
| Nonogram | on it (2026-09-19): the floor pops in wide about its centre and each line's numbers pop in with the squash along their band a beat later; a cell sinks under the finger and stays down through a sweep, springing back as its tile lands; a tapped tile or pebble pops in with the squash and a puff, leans the pieces beside it and bumps its row's and column's numbers; a sweep lays its pieces in a wave along the finger's path and puffs none; a leaving piece shrinks with the quarter turn, an undo in the wave it was laid in; a hint's tile drops in under a ring with a sparkle, a pebble there popping out first; Check wobbles a wrong tile and blushes it; a grouted tile shivers and blushes when pressed; Reset shrinks every piece out in a wave from the far corner while the numbers hop; the solve wave hops the tiles along the diagonal, and the reveal stays its own. Everything drawn off the readers, the numbers through one draw transform per line (rule 8); a soft disc under every pebble. Measured: 68 draw calls bare and with a swept row (68 before), 3.01 and 2.97 ms idle bare at 1080 x 1920 on this Mac (3.04 before), 3.27 and 3.23 with a row of tiles |
| Queens | on it (2026-09-19), built on the vocabulary from the first line rather than ported: the court pops in wide about its centre; a cell shades under the finger and the piece on it sinks; a seated bee pops in with the squash under a gold ring and puff and her crosses arrive in a wave by king-move distance at `WAVE_STEP` 0.045, each cell flashing `QUEEN_WASH` as the wave reaches it, read off `flash_level` and `pop_in_scale`; a lifted bee shrinks with the quarter turn and her crosses leave far first; a sweep sinks its cells and lays pebbles along the path at `ENTER_STAGGER`; a hint's bee drops in under a leaf ring with a sparkle, a wrong queen in her way popping out first; Check wobbles a wrong bee and blushes her cell; a refused seat shivers the pebble and blushes the cell, a refused given queen shivers and strains; Reset shrinks everything the player laid in a wave from the far corner while given queens hop; the solve wave hops the bees to JOY along the diagonal and the pebbles clear in a scatter. Bees in slots over two drawn meshes on one clock (rule 8); since the evening of 2026-09-19 the queen is a chibi bee (`ui/faces/bee_face.gd`) whose wings beat at idle as a second layer squashed about her shoulder line, the sun's-rays pattern through `Face._layer_transform`, stilled and open under reduce-motion. Measured: 67 draw calls bare and 69 with a seated queen's crosses, 3.18 and 3.34 ms idle bare at 1080 x 1920 on this Mac, 3.80 and 3.81 with a queen seated; with the bee, 71 with a queen seated (her wings and the chip's) and 3.83 ms |
| Hidden Word | on it (2026-09-19), built on the vocabulary from the first line: the grid pops in wide about its centre while the keyboard's rows slide up under it at `ENTER_STAGGER`; a typed letter and its tile pop in with the squash (`pop_in_scale` at its own `TYPE_POP` 0.18) and the key presses and bumps -- a key is a real `Button`, so it takes `Motion.press` and `Motion.bump`, the *node* recipes, and not the readers the tiles read; an erased letter shrinks out with the quarter turn; a refused guess shivers the row and pops the toast in over the card's top, holds it `TOAST_HOLD` and pops it out; a hint's letter drops in under a leaf ring with a sparkle, ghosted at 0.55, and greens its key with the bump; Reset shrinks every committed tile out in a wave from the last row up at `RESET_STAGGER` while the keys clear their colours together; the solve wave hops the winning row letter by letter with gold sparkles while the rows above dim. Drawn tiles and drawn letters off the readers, keys in slots (rules 8 and 2); it adds nothing to `core/motion.gd`. **The flip is its signature** -- the row's five tiles turn on X in sequence, `FLIP_STEP` 0.16 apart over `FLIP_TIME` 0.42 each, taking their colour edge-on at the halfway point, and the keyboard is repainted only when the last tile lands, so the keys never give the row away. It is also the first board whose one irreversible move is a **commit**: there is no Undo, an Enter is spent, and it is the first board that can end without a solve -- the sixth row spent slides the keyboard out, dims every row and brings the sprout up with the word (`finish_unsolved`, the `ended` signal), an ending no other board has, which is why its six constants stand in the board and not in the vocabulary. Measured at 810x1440, which is 1080 x 1920 of design space on this Mac (see CLAUDE.md, "What the harnesses actually measure"): 109 draw calls bare, 110 with the first row committed and the keys repainted (109 to 111 over fourteen runs), 56 in the reveal with the keyboard gone. Idle with a committed row runs about 5.0 ms, but this harness is not reproducible to better than a factor of two on this Mac just now -- fourteen runs spread 3.06 to 7.30 with a median of 5.00. Queens, run as a control in the same session, swung just as widely -- 4.40, 4.62, 4.45, 2.84, 4.55 and 4.52 against the 3.83 in its own row above, a factor of 1.6 -- and that 2.84 is the reading that matters, because it shows the spread belongs to the machine and not to either board. So no single reading off this harness is worth quoting; only a same-hour comparison is, and it has to carry every reading rather than the convenient end of the range. The reveal, which draws half as much, gave 1.88 and 1.92 |
| Mushroom Patch | on it (2026-09-20), built on the vocabulary from the first line: the field pops in wide about its centre after `ENTER_DELAY` 0.18, the cells fading in on a diagonal wave at `ENTER_STAGGER` 0.03; a cell sinks under the finger (`press_scale`) and whatever stands on it sinks with it; a planted mushroom pops in with the squash under a ring in `SUN_RAY` and a puff, a pulled-up one shrinks with the quarter turn; a laid pebble pops in with the squash and a puff in `SOCKET_PEBBLE`, a rubbed-out one shrinks the same way; a sweep sinks cells as the finger passes and lays pebbles in a wave along the path on release; a hint's mushroom drops in from 40 above under a ring in `LEAF` with a sparkle and wears a leaf sprig from then on, which it never sheds; Check wobbles a wrong mark and blushes its cell; a refused given or pinned mushroom shivers and blushes, the sprout saying why; Reset shrinks everything the player laid in a wave from the far corner while a hint's mushrooms hop and stay; the solve wave hops every mushroom to `JOY` along the diagonal with sparkles, the pebbles clearing in the same wave, every number already green. Mushrooms and pebbles are nodes in slots, the field and its numerals drawn off the curve readers (rules 2 and 8); `core/motion.gd` gains nothing. **It is the precedent for a board whose feedback is derived from public information**: every numbered cell's wash -- green the instant its own eight neighbours hold exactly its number of mushrooms, rose if one too many stands there, and *holding* rather than flashing -- is a running signal no other flat board keeps, and it is legitimate only because it is computed from information the player already holds, the number printed on the cell and the mushrooms they themselves planted, never from the answer; a board can be covered in green and still be wrong, which is what Check is for (the Code Break rule, "a count and never a map", survives intact). `WASH_TIME` 0.35 s, how long a change takes to settle, and `WASH_LEVEL` 0.30, how deep the colour sits on the cell, are its own two constants and are not for any other board to read. Measured at 810x1440 (see CLAUDE.md, "What the harnesses actually measure" -- `--resolution` has to sit before `--script` or the flag is silently dropped): 75 draw calls with the answer's first mushroom planted and its neighbour's wash landed, twice in a row (72 bare and 103 mid-wave with five pebbles and a hint, both through the win harness rather than this one); 2.47 ms idle, twice, against a Queens control read in the same session at 71 draw calls and 2.87-2.90 ms |
| Sudoku | on it (2026-09-20), built on the vocabulary from the first line rather than ported: the grid pops in wide about its centre (`wide_pop_scale`, `ENTER_WIDE_FROM` 0.86 -- the recipe's number, not the spec's 0.88) after `ENTER_DELAY`, and the givens fade in **region by region** at `ENTER_STAGGER` through `stagger(box_of(i))` and `appear_level`, so the board assembles as three by three and not as eighty-one; a placed digit drops in from `DROP` 40 with its fade (`drop_in_lift`, `appear_level`) while the cell bumps (`bump_scale`); a digit tapped out again only bumps the cell -- no pop-out, because a cleared cell is not an event -- and so does a pencil mark, which appears in its third of the cell with no drop, nine of them dropping being a rainstorm; a refused tap shivers the cell (`shiver_offset`) and writes the reason on the tip card; a hint's digit drops in under a leaf ring with a sparkle and bumps; Check shivers every wrong cell in a shallow wave out from the middle row at `RESET_STAGGER` and leaves the rose wash on it until it is written again; Reset bumps every cell the player wrote in a wave from the far corner at `RESET_STAGGER` and carries the digits out with it; the solve wave flashes and bumps the whole grid along the anti-diagonal at `SOLVE_STAGGER` after `SOLVE_DELAY`, with three gold sparkles marching down the main diagonal on the same beats, and the win `WIN_WAIT` later. Everything drawn off the readers, cells and numerals alike (rule 8); it adds nothing to `core/motion.gd`. **Three constants of its own**, and each is something nothing else in the game has: `WAVE_FLASH` 0.5 is the signature's hold, `WIN_WAIT` 1.4 is `win_delay()` because the diagonal wave has to finish before the win screen covers it, and `WASH_FLASH` 0.55 is a colour alpha beside the board's five derived washes rather than a timing. The wave's step, `WAVE_STEP` 0.045, is not this board's own any more: Sudoku was the second board to read it, after Queens, so it moved to `core/motion.gd` on 2026-09-20 rather than being copied a second time. Word Trail, which landed on trunk the same day, keeps a same-named `WAVE_STEP` of its own (0.05, in word_trail2d.gd) rather than reading this one: GDScript resolves the unqualified name to the script-local const, so the two never collide, and the value is deliberately different because Word Trail's step is per-tile along a ribbon, not this king-move ring step, so it was never a candidate to share this constant. **Its signature is the unit coming right**, and that is **the first precedent it adds: a board that answers a finished unit.** The wave is keyed on a *diff of derived state* -- one snapshot of which rows, columns and regions were complete before the move against which are complete after it -- and not on the move that caused it, so `place`, `mark`, `hint`, `undo` and `reset` all light exactly what they finished through one `_settle` and no move can light a unit twice or light one it did not finish. Queens' `_settle` is the shape; the difference is that Queens diffs a queen's *sight*, which belongs to the piece that moved, while a finished unit belongs to no piece at all and only the diff can find it. A digit that closes a row *and* a region runs both at once from the same seat, for free, because the step is read off the seat and never off the unit. **The second precedent is that a refusal writes to the tip card rather than to a toast** (the Refused row above): this board already carries a card whose whole job is one line, so a toast over it would be two voices saying different things, and `_speak` holds the line `SAY_HOLD` 2.2 before the cycling rules resume. One more thing worth copying: the mesh rebuild is gated on `_mesh_moving` -- `_flash`, `_bump` and `_shiver` only -- and is decided once a frame in `_process` rather than again in `_draw`. The entrance is one transform over a finished mesh and a fade that lives in the numerals, so gating it took the entrance from **189 rebuilds of eighty-one cells to one**; deciding it once removes the `oneline2d.gd` hazard of the two asks disagreeing on the frame a moment expires. The solve's last two anti-diagonals share a beat, because 16 x `SOLVE_STAGGER` is 0.64 against `stagger`'s 0.6 cap: three cells of eighty-one at the tail of the wave, left alone on purpose rather than given a wider cap, because the cap is the family's promise and not this board's to raise. Measured at 810x1440, which is 1080 x 1920 of design space on this Mac (see CLAUDE.md, "What the harnesses actually measure"): **87** draw calls bare and 87 with a finished row waving, on the refusal, on a Check and through Reset -- unchanged by any of this task's work, and the same 87 under reduce-motion. Idle bare 2.41 and 2.43 ms over two sequential readings, and 2.59 and 7.79 ms with the wave run -- that spread is this Mac's and not this board's (see Hidden Word's row), so only the pair is worth quoting, not the flattering half of it |
| Quilt | on it (2026-09-20), built on the vocabulary from the first line: the backing pops in wide about its centre (`wide_pop_scale` from `ENTER_WIDE_FROM`) after `ENTER_DELAY` while the rack's patches pop in with the squash on the family's stagger behind it; a patch picked up grows from the rack's cell to the quilt's at `LIFT_SCALE` and rides `HOLD_LIFT` 1.2 cells above the thumb, with the ghost of a legal drop washed on the cells under it; a patch that lands pops in with the squash and **sews its seams**; a refused drop flies home over its own `FLY_TIME` 0.26 with the back ease, shivering (`shiver_offset`) under a **rose halo stroked round its silhouette** on `flash_level` -- **the cloth itself never blushes**, and that is rule 9 read for a piece that is its own shape: the eight cloths run round the wheel, so a `BAD` wash turns the teal grey (saturation 0.34 to 0.07) and the sage khaki (hue 91 to 49), and a greyed patch reads as disabled rather than as refused, so the colour is drawn beside the cloth instead of mixed into it -- and the sprout names the rule; letting a patch go **clear** of the quilt is not a refusal at all but the gesture for taking it off, and gets the count and no blush; a hint's patch drops in under a `LEAF` ring with a sparkle, taking up anything in its way first, and keeps a `SUN` glow for good; Reset sends every patch the player laid home in a wave from the far corner at `RESET_STAGGER`, a hint's staying; the solve hops every patch along the diagonal at `SOLVE_STAGGER` after `SOLVE_DELAY` with a gold sparkle each, and the hem's stitch warms to `SUN_RAY` in the same wave. Everything drawn off the curve readers (rule 8) with no Controls at all, in three meshes -- the quilt, the rack and the hand; `core/motion.gd` gains nothing. **Its signature is the stitch**, and its two constants are that stitch's: `STITCH_STEP` 0.05 a cell of distance and `STITCH_TIME` 0.22 for one seam's dashes to run. Nothing else in the game sews. **It is the third shape of the `_settle` pattern** and the plainest: where Queens diffs a queen's sight and Sudoku diffs which units are finished, this diffs *where every patch is*, before a move against after, and turns the difference into the moments the drawing reads -- so a hint that displaces two patches and the undo that puts them back animate correctly without either of them knowing which patches those were. The seams themselves are derived the same way and never stored: a seam exists because two patches are where they are, it takes the **later** of their two landings as its moment (a seam belongs to a *pair*, which is what a pair costs), and lifting either takes it away with no book to keep. Measured at 810x1440, which is 1080 x 1920 of design space on this Mac: **58-59** draw calls bare and 58-59 with a patch dragged on and its seams sewn (six readings each; the +1 is whether an fx ring or sparkle is still alive on the frame the window samples), **80** on the fullest board with the solve wave running, and 58 under reduce motion -- all against the 855 budget, with Queens (71, 71) and Word Trail (65) reproducing their recorded counts as controls in the same session. Idle 2.54/3.36/3.90 bare, 2.13-2.71 played, 2.09-2.46 full; Queens read 3.45 and 3.49 in that session against the 3.83 of its own spec, so the milliseconds are comparable only within the session and every reading is quoted rather than the flattering one. The reduce-motion pair 1.5 s apart is pixel-identical |
| Pinwheel | on it (2026-09-20), built on the vocabulary from its first line: the frame pops in wide about its centre after `ENTER_DELAY` and the pieces pop in with the squash along the diagonal at `ENTER_STAGGER`, each pinwheel a beat behind the cloth it holds down; a tapped pin turns its piece a quarter clockwise and the stain under it settles in a wave out of the pin at `WAVE_STEP`; a tap anywhere but a pin wobbles every pinwheel that reaches the cell (`wobble_angle`) and the sprout says to turn a piece by its pinwheel; a piece that is pinned fast shivers (`shiver_offset`) under a rose halo stroked round its silhouette on `flash_level`; a hint walks a piece home in one go and rings and sparkles at its pin; Reset turns every piece back in a wave from the far corner at `RESET_STAGGER`; the solve hops every piece along the wave out of the last pin turned, at `SOLVE_STAGGER` after `SOLVE_DELAY`. Everything drawn off the curve readers (rule 8) with no Controls at all. **It is the first rotation in the game**, and the one thing it adds to `core/motion.gd`: every turn before it was an idle (the sun's forty seconds, Untangle's knots) or Hidden Word's flip, which is a scale on one axis and not a rotation at all, so `TURN_TIME` 0.26 and `turn_angle` are the vocabulary's and not this board's -- a quarter turn is a thing the next board may want. **The piece and its pinwheel read the same recipe with different `time`s**: the cloth settles on the mark at `TURN_TIME` and the blades go on turning to `HUB_TIME`, 1.55 times it, so the handle carries the overshoot the cloth does not. That is one recipe and one parameter, not two numbers, which is rule 6 read for a thing made of two parts moving at two speeds. **A refused piece takes rule 9's halo and never a blush**, for Quilt's measured reason: its pieces are coloured by index off `Pal.CLOTH`, which runs right round the wheel, so a `BAD` wash turns the teal grey and the sage khaki and a greyed piece reads as disabled rather than as refused -- the rose is stroked round the silhouette beside the cloth instead of mixed into it. Any board whose pieces are coloured by index should expect this. The pinwheel itself is `ui/faces/pin_wheel.gd`, builder shapes and not a Control, the third board to add a drawing rather than a character after Nonogram's tile and Quilt's cloth; a piece with one orientation wears a plain pin instead, because a pinwheel that does not turn is a lie. Its draw calls and its idle are read with `tests/_shot_anim.gd -- pinwheel` at 810x1440 against a control board run in the same session, and every reading is written into the spec's section 8 rather than here |
