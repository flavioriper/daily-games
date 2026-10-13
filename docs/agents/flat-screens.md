<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

## The flat screens

Eighteen cards open a flat 2D board under flat chrome: **Binairo**
(`puzzles/binairo2d.gd`), **Code Break** (`puzzles/codebreak2d.gd`),
**Balance** (`puzzles/balance2d.gd`), **Shikaku**
(`puzzles/shikaku2d.gd`), **Untangle** (`puzzles/untangle2d.gd`), **Tents**
(`puzzles/tents2d.gd`), **Light Up** (`puzzles/lightup2d.gd`), **One Line**
(`puzzles/oneline2d.gd`), **Nonogram** (`puzzles/nonogram2d.gd`) and, since
2026-09-19, **Queens** (`puzzles/queens2d.gd`) and **Hidden Word**
(`puzzles/hidden_word2d.gd`), and, since 2026-09-20, **Word Trail**
(`puzzles/word_trail2d.gd`), **Mushroom Patch** (`puzzles/mushroom2d.gd`),
**Sudoku** (`puzzles/sudoku2d.gd`), **Bridges** (`puzzles/bridges2d.gd`),
**Quilt** (`puzzles/quilt2d.gd`), **Paper Planes**
(`puzzles/planes2d.gd`) and **Pinwheel** (`puzzles/pinwheel2d.gd`).

Each of the first nine was built on trial beside its island, as a second
card seeded from the same day, so the two could be judged on the phone.
**The trial is over**: on 2026-09-18 the game went 2D, the first screen was
redrawn flat and every island moved to `legacy/`. Those nine islands keep
`seed_as` pointing at their flat twin, so a board opened from More still
hands out the same day's puzzle. The nine since -- Queens and Hidden Word
(2026-09-19), Word Trail, Mushroom Patch, Sudoku, Bridges, Quilt, Paper
Planes and Pinwheel
(2026-09-20) -- were
drawn flat from the start, with no island of their own behind them in More and nothing
pointing `seed_as` at them. Specs:
`docs/superpowers/specs/2026-09-18-binairo-flat-design.md` and its
`...-codebreak-`, `...-balance-`, `...-shikaku-`, `...-untangle-`,
`...-tents-`, `...-lightup-`, `...-oneline-` and
`...-nonogram-flat-design.md` siblings, and
`docs/superpowers/specs/2026-09-19-queens-flat-design.md`,
`...-hidden-word-flat-design.md`,
`docs/superpowers/specs/2026-09-20-word-trail-flat-design.md`,
`...-mushroom-patch-flat-design.md`, `...-sudoku-flat-design.md`,
`...-bridges-flat-design.md`, `...-quilt-flat-design.md`,
`...-paper-planes-flat-design.md` and `...-pinwheel-flat-design.md`; mocks:
`docs/brainstorm/concepts.html#binairo`, `#codebreak`, `#balance`, `#shikaku`,
`#untangle`, `#tents`, `#lightup`, `#oneline`, `#nonogram`, `#queens`,
`#hiddenword`, `#wordtrail`, `#mushroom`, `#sudoku`, `#bridges`, `#quilt`,
`#planes` and `#pinwheel`.

- **Every flat board moves with one hand.** `docs/art/flat-motion.md` is the
  table: the press, the pop in and out, the hop, the nudge, the drop, the
  ring, the entrance and the solve wave are recipes and constants in
  `core/motion.gd` ("the flat boards' vocabulary"), lifted from Binairo on
  2026-09-18 when Code Break was put on them. A new or a ported board calls
  those and keeps only its own signature (Binairo's blush, Code Break's
  flight and lids) as constants of its own; a number that has to differ goes
  through a recipe's parameter, never a copied constant. Rings, puffs and
  sparkles come from `ui/fx2d.gd` alone. Balance joined them the same day
  (its spec's section 10), and brought `ui/flat/scenery.gd`: one mesh of
  clouds and grass tufts under a board card, and the radial disc every
  ground shadow is drawn with. Untangle joined on 2026-09-19 (its spec's
  section 11), and it is the precedent for a board whose motion is
  integrated rather than tweened: the point's motion (the drag, the two
  springs, the scripted walks) stays on the board's clock, and every lantern
  stands in a slot the board owns so the paper can take the recipes;
  `Motion.lift` is the press for a dragged thing, and a board that already
  rebuilds a mesh builds its shadows into it with `Scenery.soft_disc`.
  Shikaku joined on 2026-09-19 too (its spec's section 11), and it is the
  precedent for a board whose pieces are drawn rather than nodes: it reads
  the recipes as curves off `Motion` (`back_out`, `pop_in_scale`,
  `wide_pop_scale`, `pop_out_scale`, `drop_in_lift`, `bump_scale`,
  `flash_level`), handed the seconds since the moment began, so a drawn bed
  and a tweened tile move as one hand and no board copies a number. Tents
  joined the same morning (its spec's section 10), and it is the precedent
  for a board with both media: trees, tents and chips are nodes in slots
  taking the recipes, the cairns and the shade under the sweep are drawn off
  the readers, and a piece with no blushing skin (a tree) blushes through
  its cell (the doc's rule 9). Light Up joined on 2026-09-19 as well (its
  spec's section 11), and it completed the curve readers: every recipe a
  node takes now has its reader on `Motion` (`press_scale`, `hop_lift`,
  `nudge_offset`, `shiver_offset`, `wobble_angle` beside the pops and the
  flash), so a drawn board needs nothing new from `core/motion.gd`; its
  lamps stand in slots and its blocks, chips and stones are drawn off the
  readers, the stone itself sinking under the finger. One Line and Nonogram
  joined that afternoon (each spec's section 11), which put all nine flat
  boards on the vocabulary; neither needed anything new from it. One Line
  is the precedent for a board whose one character rides a clock: the
  walker's seat takes the ride, the facing and the rock every frame, and the
  snail inside takes the recipes (pop, drop, press, hop), while the far post
  keeps its old cap until the snail lands and takes the new one with the
  Count bump. Nonogram is the precedent for drawn text on the vocabulary:
  its clue numbers go through one `draw_set_transform` per line, so they
  pop in, bump and hop off the same readers as the mesh, and
  `ui/faces/mosaic_tile.gd` takes a Vector2 scale, a turn and a blush so a
  drawn tile can squash, wobble, turn out and flash.
- **A long title or motto is lettered smaller, never larger**
  (`ui/flat/flat_top_bar.gd`, 2026-09-20). The title block is whatever the
  buttons leave -- 496 with four, 370 with five -- and `Word Trail` measures
  392 at GameWordmark 84, so it used to run out under Undo and Reset, as
  Balance's and Untangle's mottos had since 2026-09-18. Every title fitted
  the four-button 496 until `Mushroom Patch`'s 635 (2026-09-20). `_fit_title`
  measures the rendered face (`Font.get_string_size`, which carries the
  variation's letter spacing) against the block on every resize and takes a
  `font_size` override when it does not fit, removing the override when it
  does. **`floor(base * wide / want)` is the seed of that override and not
  the answer**: advance widths are not linear in the font size, so the
  linear guess can still overflow -- Balance's motto guesses 22 and the face
  at 22 measures 372 against a 370 block -- and `_fit` steps down from the
  guess (never from `base`, which is up to 60 measurements for a long title)
  until the rendered face actually fits. **Swept across all seventeen
  screens on 2026-09-20** -- first a windowed probe at `--resolution
  810x1440` that opened every registry entry in turn through the real menu
  and read the bar's own labels back (fifteen screens, before Bridges and
  Quilt merged), then re-run over all seventeen at the Bridges/Quilt/Paper
  Planes merge with a headless probe running `_fit`'s own arithmetic against
  the real theme faces; the second reproduced every figure of the first to
  the pixel bar one (Hidden Word's title 482 where the windowed run read
  481), which is why its two new rows are quoted beside them --
  **exactly seven labels are lettered smaller**: Balance's
  motto (399 at 24, down to 21), Untangle's (397, to 22), **Quilt's (`MAKE
  THE BLANKET WHOLE`, 380, to 23)**, Word Trail's title
  (391 at 84, to 79) and motto (406, to 21), Mushroom Patch's title (635, to
  65) and **Paper Planes' title (497, to 62)**. **Bridges is untouched** --
  284 and 236 against the four-button 496, which is what its spec's section
  2 predicted. Every other label is
  untouched to the pixel, Hidden Word's 481-wide title included: its bar
  builds five buttons but `refresh()` hides Undo, so the block it measures
  against is 496 and it stays at 84. **Sudoku is now measured rather than
  expected**: its title is 275 and `EVERY NUMBER HAS ITS PLACE`, the widest
  motto in the game, is **421 against the four-button 496** -- 75 px of
  headroom, so nothing on that screen is fitted, which is what the earlier
  estimate of "roughly 428" guessed and this reading replaces. (Two of the
  older figures read one pixel narrower in this sweep -- Word Trail's title
  391 where 392 was recorded, Hidden Word's 481 where 482 was: rounding
  between the two probes, and it moves no label across the line.)
  **Paper Planes is still the most severely fitted label in the game after
  Bridges and Quilt** -- 62 is
  three points under Mushroom Patch's 65 even though Mushroom Patch's face is
  138 px the wider, because the block is the five-button 370 and not 496, and
  Quilt's motto, the one label those two boards added to the list, gives up
  a single point (24 to 23) against Paper Planes' twenty-two. Its
  own motto is not fitted: `A CLEAR LANE AND AWAY` measures 353 and clears
  the same 370 block that forces the other three mottos down.
  **Pinwheel leaves the count at seven labels over eighteen screens**, and
  it is the first five-button board to letter *neither* of its own down: `Pinwheel`
  measures **338** at 84 and `TURN IT TILL IT FITS` **272** at 24, against
  the same 370 block, so both keep their base size with 32 and 98 px to
  spare -- read on 2026-09-20 by a throwaway probe that opened the real
  screen and measured the rendered face, not by the headless sweep above,
  which predates it. A motto written short on purpose is what bought the
  second half of that; the first half is simply a short title. Two
  by-products of that probe are worth keeping and are *not* in the sweep:
  **Quilt's motto is fitted 24 to 23** (`MAKE THE BLANKET WHOLE`, 380),
  which the sweep did record, and **Word Trail's title measures 391 there
  against 392 here** because the string the label actually renders is
  `Word Traıl` -- `ui/sun_dot.gd` has already swapped the i for Fredoka's
  dotless `ı` by the time the bar measures it, which is the explanation the
  sweep's own "rounding between the two probes" was guessing at.
  **497 and 62
  are the measurements, and they replace 528 and 58**, which the plan's
  ledger recorded off the concept page while the name was still being chosen
  and which nothing on the shipping bar produces; the sweep that took them
  reproduced Mushroom Patch's 635 to 65 and Word Trail's 84 to 79 before it
  was believed about this one.
- **Nothing under `tests/` loaded a board's `*2d.gd` until 2026-09-20**, and
  that was true of all boards, not one -- and since the merge that brought
  Bridges and Quilt in, the guard covers every entry in the registry, which
  is eighteen today. It walks `Registry.PUZZLES` rather than a list of its
  own, so a new board is covered by being added and by nothing else. A parse error in
  `puzzles/planes2d.gd` left the suite reporting `passed=94534 failed=0`; the
  only thing that caught it was `tests/_win.gd`, which needs a display and is
  not in CI. A script with a parse error still `load()`s as a GDScript object
  and only gives itself away at `can_instantiate()`. `tests/test_planes.gd`
  now walks `Registry.PUZZLES` and asserts exactly that for every entry's
  script, naming the board in the message -- the same idiom
  `tests/run_tests.gd` already uses on its own suites, and the same reason.
  It is two assertions a board in the newest suite rather than a file of its
  own, because it belongs to no board in particular.
  `godot --headless --check-only --script puzzles/<board>2d.gd` is still the
  one-second check worth running before a harness.
- **A card that moves inside a container needs a slot.** A container writes
  its children's positions on every sort, so a child that tweens its own
  position (a shiver, a hop) fights it and loses; give the container a plain
  slot and let the card move inside that. Balance's weight cards learned it
  the hard way on 2026-09-18: a refused minus threw the card under the first
  one, and the player saw it vanish.
- **The flat screen breaks the sign rule on purpose.** Its title is a `Label`
  in ink (`Wordmark2D`) with the leaf drawn over it, not the carved sign, and
  it has no How to play card, working-line card or motto footer: a tip card
  with a sprout names the rule a tap just broke and opens the rules sheet.
  Nothing else may drop the sign; this screen is the experiment.
- **The rules live in a scene-free state class** the flat board draws
  (`puzzles/binairo_state.gd`, `puzzles/codebreak_state.gd`), and they are
  the island's move for move, so what was on trial was the screen and not
  the game. The state class is the one truth (the island copies were
  removed with the 3D game).
- **Faces are code, not images** (`ui/faces/`): one Control per character,
  drawn from a few tweened properties (`expression`, `eye_open`, `spin`,
  `rock`) as one cached `ArrayMesh` per layer, because gl_compatibility pays
  per draw command. `radius_ratio` fixes R as a fraction of the rect and
  `plain` drops the face for a silhouette; `ui/faces/friends.gd` is the one
  list of Code Break's seven. Filled polygons get an antialiased feather in
  their own colour; MSAA for the 2D canvas stays off.
- **Code Break's score is a count and never a map.** Nothing on that screen
  may suggest which seat a pip came from -- not the pips' arrangement, not
  their colour, not a face, not the order things animate in. That is why the
  pouch is a loose pile with no socket for a miss, and why a checked row
  wears one expression rather than one per seat.
- **The registry picks the shell**: `Registry.shell(entry)` is "flat", the
  only shell left since the island one was removed on 2026-09-24; it fills
  `ui/puzzle_host.gd`'s `_build_chrome` and `_enter`. The base has no rows
  of its own and errors rather than falling back. It picks the tray too
  (`"tray": "none"`, `"friends"`, `"weights"`, `"tiles"`, `"queens"`,
  `"keys"`, `"patch"`, `"digits"`), because
  the host lays out its rows
  before it has a puzzle to ask how many chips it wants -- and it can drop
  the actions row with `"actions": false`, which Balance does: that board is
  its own continuous check, so it has no Check to put in the row and Reset
  rides up into the top bar instead. It can drop the tip card too
  (`"tip": false`), which **Hidden Word** is the first board to do: the
  keyboard fills the space a tip card would sit in, and the screen has no
  room for both. This also leaves Hidden Word with no route to the rules
  sheet, since the tip card was every other board's only door to it -- see
  above. Hidden Word drops the actions row as well -- there is no Check on a
  board where a commit is the check, and no Undo, because the commit is the
  one irreversible move any flat board has. The flat host therefore measures
  its bottom slot from the rows it actually built, not from a constant; the
  eighteen screens want, **in registry order**, 458, 460, 390, 140, 290,
  290, 290, 290, 460, 460, 340, 140, 460, 480, 290, 140, 140 and 140, with
  Mushroom Patch's 460 the thirteenth, Bridges' 290 the fifteenth, Quilt's
  140 the sixteenth, Paper Planes' 140 the seventeenth and Pinwheel's 140
  the eighteenth, and
  **the fourth and fifth numbers were the wrong way round in this file
  until 2026-09-20** (Untangle's is 140 and Shikaku's is 290, not the
  reverse) -- re-derived from the registry and `ui/flat/flat_host.gd`'s own
  row sums at this merge rather than carried forward. And
  **Sudoku's 480 the fourteenth and the widest bottom slot in the game** --
  twenty more than the 460 its neighbours take, because its digit pad is 170
  where a tray is 150: `170 + 20 + 130 (actions) + 20 + 140 (tip card)`. It
  is the first board since Nonogram to want all three bottom rows at once.
  Of the rest: Untangle drops the tray *and* the actions row, so its slot
  is the tip card alone, Hidden Word's is the keyboard alone (`ui/flat/key_board.gd`'s `HEIGHT`), and
  **Word Trail** is Untangle's shape again: it picks nothing up and there is
  no Check, because only a right word locks, so its slot is the tip card
  alone at 140 and Reset rides up into the top bar. **Quilt is the third of
  that shape**, and for the third distinct reason: its pieces are dragged
  from a rack *inside the board card* rather than picked out of a tray row,
  so it asks for no tray, and nothing wrong can be sitting on the quilt
  because an illegal drop is never taken, so there is no Check either.
  **Paper Planes is the fourth** and gives a fourth reason: nothing to pick
  up, and no Check because a launch only ever empties cells, so it can never
  put a wrong thing on the board. **Pinwheel is the fifth and gives a
  fifth**, and it is the only one of the five that reaches it by *allowing*
  the wrong thing rather than by preventing it: a piece may lie across
  another, and the stain under it draws that the instant it lands, so the
  one question Check could ask is already answered on the screen. **140 is
  therefore the shortest bottom
  slot in the game and five boards now share it** -- Untangle, Word Trail,
  Quilt, Paper Planes and Pinwheel -- so it is no longer a tie of two and
  nobody
  should write it as one. Six
  boards now carry
  five buttons up there (Balance, Untangle, Word Trail, Quilt, Paper
  Planes, Pinwheel); Hidden Word
  builds five and shows four, because its `capabilities()` has no Undo.
  **Count that from the registry's `"actions": false`, never by
  incrementing**: seven entries carry it and Hidden Word is the one of the
  seven that shows four. Mushroom
  Patch takes the ordinary three rows, and its 460 is the same sum as
  Code Break's, Nonogram's and Queens': a 150 tray, a 130 actions row, a
  140 tip card and two 20 gaps between them. Binairo's own tray
  (`SymbolTray.HEIGHT`, a 140 chip plus an 8 lift) is 148, two short of
  150, so its slot is 458 rather than 460.
- **What the flat chrome asks a board for is optional and defaulted**:
  `palette()`, `weights()` (the weight cards' rows), `tip_line()` (the
  sprout's own line, in place of Binairo's cycle of rules), `flat_win()` (the
  characters of the answer, laid across the win screen in place of the sun
  and the moon, optionally each with a label under it), `win_delay()` and
  `card_height(available)` (a board that wants less of the slot than it was
  given: Balance caps its scale bands, and the leftover becomes air *above*
  the weight cards, because a gap under the day card reads as a mistake and a
  gap above the cards reads as room) and `card_centred()` (where that
  leftover goes: Tents, Light Up, One Line, Nonogram, Queens and Mushroom
  Patch halve it,
  because their grid is square -- or, on One Line, wider than it is tall --
  while their space is tall, so the cell is capped by the width and there is slack
  however the card is cut; One Line's medium lattice is 4x3 and leaves 432 of a 1190 slot, the
  widest air of the eight and a call its spec's section 10 records rather than
  hides). A board that offers none gets Binairo's behaviour. Hidden Word
  answers `true` to `card_centred()` and **the answer does nothing on this
  phone**: five tiles across six rows is taller than it is wide, so height
  binds and the slack is zero -- measured at three slot sizes on 2026-09-19,
  `card_height()` hands back every pixel it is given (1140 of 1140, 1190 of
  1190, 900 of 900), so there is nothing to halve at any of them. It says
  `true` because on a squarer screen
  the width would bind instead; nobody should read a centring on the phone
  into it.
- **The flat cast is a shared drawing, and two screens already share one.**
  `ui/faces/friends.gd` is Code Break's seven and `ui/faces/fruit.gd` is
  Balance's five, and the apple in the second *is* the berry in the first --
  one class, one mesh cache, named differently by each screen because the
  mocks drew the same round red fruit twice. Light Up's lamp
  (`ui/faces/court_lantern.gd`) is the third: it is Untangle's paper lantern
  subclassed, with the cord and tassel off it and an iron foot under it, so it
  shares the parent's seat, halo and mesh cache. Check `ui/faces/` before
  drawing a new character -- in eighteen screens two have earned one: One Line's
  walker (`ui/faces/snail_face.gd`), because nothing else in the cast walks
  anywhere and its trail *is* the mechanic, and Queens' bee
  (`ui/faces/bee_face.gd`), because nothing in the cast is a queen and the
  bee is the one thing that board seats. Nonogram went the other way and
  drew **no** character at all: its
  pieces are tiles and its clues are numbers, so the only face on the screen
  is the sprout's, and `ui/faces/mosaic_tile.gd` is builder shapes rather than
  a Control -- eighty-one of them go into one mesh. Hidden Word went the same
  way and added nothing to `ui/faces/`: its thirty tiles are Nonogram's
  mosaic tile, taught to carry a letter and nothing else, and the only face
  it shows is the shared sprout, which comes on stage once, for the reveal.
  Word Trail is the third to add nothing: its letter tiles are that same
  mosaic tile, its scenery band borrows `ui/flat/scenery.gd`'s clouds
  (`Scenery.cloud`) into the board's own builder -- the bushes under them are
  the board's own `_bush` -- and the only face on the screen is the sprout on
  the tip card. Mushroom Patch reused rather than earned too: its mushrooms
  and their pebble are `ui/faces/mushroom_face.gd` and
  `ui/faces/mosaic_tile.gd`, already on stage since Balance and
  Nonogram/Queens, and the only thing it added to either was the
  off-by-default `sprig` a hint's mushroom wears. Sudoku is the fourth to add
  nothing, and the first board that seats no character of any kind: its
  pieces
  are numerals in ink drawn straight on the grid mesh, and the one face on
  the screen is the sprout on the tip card -- the way Nonogram decided and
  Hidden Word confirmed. **Bridges is the fifth to add nothing and seats
  none either**: its islets are a disc, a rim and a number, and the only
  face on that screen is the sprout on the tip card. **Quilt seats none
  either, and is the second board to add a drawing rather than a
  character**: `ui/faces/patch_cloth.gd` is
  builder shapes and not a Control, exactly as `mosaic_tile.gd` is, because
  the board batches up to eight patch silhouettes into one mesh and the menu
  card draws five more into another -- a Control per patch would be a node
  per piece of a thing with no face on it. A patch is **one polygon and not
  a row of squares**: its cells' boundary is traced into a loop and the
  corners rounded (a concave one rounds inward, which is what makes a notch
  read as folded cloth), because tiling a patch out of rounded squares
  would draw the seams the game has not sewn yet -- and those are exactly
  the information the player is looking for.
  Paper Planes was the sixth to add nothing and is the **fourth to seat
  none**: its pieces are folded paper, and since 2026-09-26 they are a
  drawing of their own (`ui/faces/paper_plane.gd`) rather than shapes in the
  board's mesh code, shared with the menu card -- a drawing, not a character.
  **Pinwheel is the fifth to seat none and the third to add a drawing rather
  than a character**, after Nonogram's tile and Quilt's cloth:
  `ui/faces/pin_wheel.gd` is builder shapes and not a Control, for the same
  reason `patch_cloth.gd` is -- the board bakes every piece and every
  pinwheel into three meshes, and a Control per pinwheel would be a node per
  handle of a thing with no face on it. Its cloth is Quilt's, unchanged. Five
  boards in a row now say the same thing, so it is a pattern and not a
  coincidence -- **a board whose pieces are marks rather than creatures does
  not get a mascot bolted onto it**, and its win screen keeps the family's
  sun and moon rather than earning a Control for one screen's sake.
- **A canvas command holds a mesh by RID, not by reference.** A board that
  rebuilds a cached `ArrayMesh` every frame and drops the previous one leaves
  the renderer drawing a freed RID -- "Parameter mesh is null", and an empty
  card -- on any frame rendered without its queued redraw flushed first, which
  is exactly what `RenderingServer.force_draw()` does in a harness.
  `lightup2d.gd`, `oneline2d.gd`, `nonogram2d.gd`, `untangle2d.gd`,
  `shikaku2d.gd` and `tents2d.gd` keep the mesh their last `_draw` handed
  over (`_shown`) until the next one replaces it; `word_trail2d.gd` keeps
  three (the still band, the field and the slots), so its `_shown` is an
  Array, `planes2d.gd` keeps the one mesh its whole field is drawn as, and
  `pinwheel2d.gd` keeps its three the same way.
  A harness shooting one of these boards has to let a frame pass between the
  state change and `force_draw()`: `queue_redraw` is flushed on the next idle
  frame, so a probe that pokes the board and shoots in the same frame
  photographs the state before the poke.
- **A board that rebuilds only while it is moving has to ask about every
  wave.** `oneline2d.gd`'s `_animating()` first asked only its posts'
  entrance, and on a figure of twenty lines the lines' own wave outlasts it:
  the last few froze at four fifths of their fade, two pale lines that never
  arrived. It showed on a rendered frame and in no test.

Per-board entries (Queens through Shikaku) are in `docs/agents/boards/`.

### A board that fills the screen: `bleed` (2026-10-11)

Gumdrop came over from the Arcade tab with its table edge to edge, and the
user's rule of 2026-10-10 is that a game's world fills the screen. A
registry entry says `"bleed": true` (with `"tray": "none"` and
`"actions": false`: its controls lie on its own field) and
`ui/flat/flat_host.gd` then:

- lays the board **full rect under the rows**, in a `BleedSlot` that is the
  host's second child, not in the column's card slot. The column's own row
  stays as the empty gap between the two slots. No backdrop plate
  (`_backdrop` stays null), no board card (`_card` hidden); the paper page
  is still under everything.
- sets the margins and the column to ignore the pointer, so the board takes
  every touch the rows do not. A container left on PASS would hand the
  touch to the host and never to the board beside it.
- tells the board what the rows cover, in the board's own pixels:
  `set_clear(top, bottom, won)` from `_tell_clear()`, at the spawn, on
  `_apply_insets` and once in `_show_win` with the win's slots (`TOP_WIN`
  and the bottom with or without the next-level button).
- never freezes and scales the board for the win's slide (`_freeze_board`,
  `_thaw_board` and `_fit_card` return early): the board moves itself into
  the span it was told.

**Button Box is the second** (2026-10-11, `docs/agents/boards/buttons.md`):
linen edge to edge, the picture and its tin on it, the win's picture slid
to the middle of the span under one transform. It has Undo and the bulb in
the top bar, which a bleed board had not had; they work as on any board.

**Toy Cannons (built as Toy Train, id `train`) is the third** (2026-10-12, `docs/agents/boards/train.md`): the
playroom floor edge to edge, the rug and its loop, the siding and the shed
on it. It is the first flat board whose state moves on a clock (the loop's
ticks), so it has no Undo; the bulb and Reset ride in the top bar.

**Binairo is the fourth, and the first with a tray and an actions row**
(2026-10-13, `docs/agents/boards/binairo.md`, "The sky is the whole
screen"). The host needed nothing new: `_bottom_play` already sums the rows
it built and `_tell_clear` hands them over, and a touch pushed through the
window reached the board between the rows and solved it. It is also the
first bleed board made of nodes rather than one drawing, and the recipe for
the grid boards still in a card: the world is a Control of its own, the
board's first child; `_layout` fits the span `set_clear` gave instead of
`size`; and on `won` the board is not laid out again, it slides and
shrinks under its own transform with the world counter-transformed.

Everything else is the host's as for any board: the bar, the day card, the
tutorial, `_on_solved`, the win stack, Redo, the next level.

### Every board gets a world of its own (2026-10-13)

The user, 2026-10-13: "let's start redesign the ingame to something
completely customized for every game taking full screen, just making sure
to keep the same brand UI layout ... Screens should be elegant, cozy, but
carry the game elements." Binairo is the first; the other card boards
(Code Break to Lattice in the registry) are still to do, one at a time.
What "the same brand layout" was taken to mean, mine and the user's to
call: the top bar, the day card with its painted island, the tray, the
actions row and the win's panels stay where and as they are; what changes
is everything under them. For each board:

- `"bleed": true` in the registry; the paper page, the painted header and
  the parchment card go with it.
- The world is the board's menu card (`ui/menu/cards/<board>.gd`) at the
  size of the screen, drawn as one cached mesh in a file of its own beside
  the board (`puzzles/binairo_sky.gd`).
- **What lies over the world decides its tones.** The wordmark and the
  motto are ink with no scrim under them now, and the win's "Well done!"
  is ink in the top 640: the world is light there. The tray's chips and
  the buttons carry their own paper and stand on anything.
- Place the decoration where the world shows: beside the tray, between
  the buttons, in the air the grid leaves above and below it, and across
  the top on the win. Behind the grid only the gaps show.
- Shoot rest and `solve` with `tests/_shot_anim.gd`; the draw calls should
  not rise (the card and the header plate leave as the world arrives).

### The win screen comes in with the board's wave (2026-10-04)

The host used to wait `win_delay()` (0.8 s by default, 3.3 on Code Break)
before the rows left, the slots resized and the stats and buttons arrived;
the user read the wave, then the resize, then the buttons as a win that took
too long. `_on_solved` now calls `_show_win(hold)` on the next idle frame, so
all of it starts with the wave. `win_delay()` keeps its meaning for the board
(how long its own win animation runs) but the host spends it on one thing
only: the board stays frozen (`_freeze_board`, scaled to follow its card)
until `max(SLOT_TIME, hold)`, so the relayout a thaw causes never lands in
the middle of a wave. Redo or New inside the hold thaws and replaces the
board; the late timer checks it still has the same one. Under `Motion.reduce`
the win screen is set at once. Any older note that times the win screen
"after `win_delay()`" (Binairo's 0.77 s, Code Break's 3.3) now describes the
thaw, not the screen.

### The streak's bubble goes after showing (2026-10-04)

The `xN` bubble twenty boards share (`_draw_combo`, One Line's first) used to
stand over the board until the streak broke, in the way of the next move. It
now shows for `COMBO_HOLD` (1.2 s from `_combo_at`) and deflates on its own
with the same `COMBO_DEFLATE` a broken streak plays; `_streak` runs on, so the
next right move pops it back in with the next number (a move inside the hold
still bumps it). `_draw_combo` starts the deflate itself, and each board's
tick keeps the layer drawing through the hold. Under `Motion.reduce` it
vanishes at the hold's end. Checked on Sudoku with a throwaway probe: four
right numbers, gone 1.45 s after the last, back at x5 on the fifth.

### Only Insane can be lost (2026-10-04)

The user: remove the hearts for Hard, keep only Insane possible to lose.
Every hearts table (`HEARTS`, `HEARTS_BY`, Binairo's `HEART_COUNTS`; 24
boards, Drumbeat among them) reads `[0, 0, 0, n]` now, so Hard plays as
Medium does on a bigger board: no pill, no judging of a move as it lands, no
out-of-hearts card, and Check back where a judged band had lost it (Binairo,
Pixel Garden; Sudoku and Bridges already asked `max_hearts`). The places
that said `band >= 2` instead of asking the table follow it: Rings' and
Pinwheel's `judged`, Quilt's and Bridges' coach, Trestle's and Pixel
Garden's rules, and the tutorial diagrams of Quilt, Hedgehogs, Knight, Pixel
Garden and Marigold. Hard's hint counts are as they were.

**Sunbeam is the exception**: its snails are Hard's own content, so the rule
stays without the price -- the light let go on a snail wakes it and the piece
slides back, no heart (`_misstep`'s `costs`), and `SB_RULES_SNAILS` /
`HTP_SB_SNAILS_BODY` lost their `%d`.

Each board's own notes and the comments over the tables still say "Hard and
Insane"; read them as Insane. Not touched: the Hard bands that end some other
way (Balance's sunset, Untangle's thread, Hidden Word's rows).

The same day, on the user's yes, the Hard bands that ended some other way
went to Insane only as well: Balance's sunset (`Gen.BANDS[2]` lost `sun` and
`hour`), Untangle's thread (`slack` 0 on Hard, `SPOOL_BY_BAND`), Word
Trail's wishes (`WISHES`), and the ink rows of Hidden Word and Code Break
(`keeps_rows` from band 3; Hidden Word's Hard keeps its strict clue rule,
and the ink sentence moved out of `HW_RULES_STRICT` into `HW_RULES_INK`).
Those two still run out of rows on every band, as Easy and Medium always
did: one more row, see the word, or Reset.

### Insane counts moves (2026-10-04)

The user, the same day: a heart was a poor way to make a board hard, because
the judgement that cost it was also the answer (Nonogram turned the wrong
tile into a pebble, Caterpillar refused the wrong step). The bands now read:

- **Hard cannot be lost**; its difficulty is more to handle (size, colours).
- **Insane** keeps its own rule (Leaf Fall, Peckish, Tumble...) and adds a
  limit the player spends by choice: **a move counter**. Nothing is judged
  as it lands, nothing is filled in for the player, and there is no Undo,
  Hint or Check (each would say what is wrong).

The rule, as each board applies it:

- Every hearts table reads `[0, 0, 0, 0]`. The hearts code is left in place
  and dormant (`max_hearts == 0` everywhere), not deleted.
- The state class owns the budget: `MOVES_SLACK := [0, 0, 0, n]` and
  `moves_budget()` (0 on a band that does not count).
  - A board solved by placing pieces: the pieces the answer holds + slack 3.
    A piece put down costs one and a piece taken off costs one; notes
    (crosses, pencil marks, flags) are free. Three is one slip mended with
    one to spare; zero slack was rejected, a mis-tap on a phone must not
    lose the day.
  - A board solved by a sequence of moves: the shortest solve the board can
    know (a bank's `par`, the miner's line) + max(3, a quarter of it).
    Every move costs one.
- The screen holds `max_moves`, `moves_left` and `_spend(cost, land)`; out
  of moves unsolved sets **`out_of_hearts`** (the name the host and the card
  already read) and runs the board's old out-of-hearts ending.
- `ui/flat/moves_pill.gd` draws "N moves left" where the hearts sat (one
  mesh, one string; rose from 3 down). `ui/hud/out_of_hearts.gd` takes a
  third argument, the moves its video buys (`MOVES_BONUS`, 5), and then
  reads Out of moves. `ui/hud/moves_tutorial_diagram.gd` is the shared
  tutorial page (`MovesDiagram.page(self, max_moves)`), in place of each
  board's HEARTS lesson. Shared lines are in `locale/ui.csv`: `RULES_MOVES`,
  `RULES_MOVES_SEQ`, `TIP_MOVES`, `HTP_MOVES`, `OUT_MOVES_*`, `MOVES_LEFT_*`.
- Reset and Try again hand the whole budget back: both are the board from
  the top.
- What a board still shows on Insane is what Medium shows from the rules
  alone (a clue going green, two pieces visibly clashing). What came from
  the answer is gone.

Twenty-three boards are on it. Where one departs from the two formulas:

- **Bridges** has slack 4: a plank only comes off round the 0-1-2-0 cycle,
  so one slip costs three moves to mend.
- **Hedgehogs** counts piles cleared, not taps (a flood takes its size off
  the counter at once): the walks move the noughts, so taps vary 0.7-1.8x
  between clean plays of the same night and piles do not.
- **Paper Planes** has a flat slack of 3: every plane flies once, so the
  spare moves can only be gusts.
- **Marigold**'s counter is its seeds (the proof's shots + 3, one garden
  where there were two tries); a pot or a big shot still gives seeds back,
  and the video buys 3.
- **One Line** takes a line back by stepping onto the post just left, on
  Insane only, for a move; without it the counter could never run out.
- **Sunbeam**'s Shy Dew slide-back stays (the band's rule, read off the
  floor) and costs a move. **Knight**'s caught hop costs a move too.
- **Binairo** charges a tile once for where it ends up, at its `_commit`.
- Sequence and path boards say `TIP_MOVES_SEQ` and pass `seq` to
  `MovesDiagram.page` (or their own body key); the shared placing lines are
  untrue of them.
- **Lattice** (2026-10-09) has slack 5 over a par of 15, the twenty swaps
  of the game it follows, and it keeps the green of a tile at home: that is
  the game's own feedback, as Hidden Word's letters are, and without it
  there is nothing to solve by. Its lines read swaps (`LA_LEFT_*`,
  `LA_OUT_*`), not moves.
- **Trestle keeps its two hearts**: they are spent only on a Go the player
  watches fail, and a count that stands still while members are laid would
  not be a move counter.

Not seen on screen beyond the pill, the card and Try again: no board was
played through by hand on Insane, and the pt/es lines are unreviewed. The
old `_shot_*` and `_probe_*` harnesses still drive hearts on Insane and are
stale. The level labels lost their hearts (`*_LVL_2`) or read "counted
moves" (`*_LVL_3`).

Nonogram is the reference (`git log --grep "move counter"`). Left as they
were, because their limit was never a judgement: Balance's sunset, Untangle's
thread, Word Trail's wishes, the rows of Hidden Word and Code Break, and
Drumbeat's misses. `tests/_probe_moves.gd -- id=<board>` opens any board on
Insane, shoots the pill, spends the budget and shoots the card.

### Insane counts nothing (2026-10-12)

The user, 2026-10-12: "remove any move limit or time limit from insane, all
insane games must be insane for difficulty not because it limit player
movements". Everything above about the counter is history: no board counts
moves on Insane now (Button Box and Pixel Garden lost theirs the same
morning).

- Every `MOVES_SLACK` reads `[0, 0, 0, 0]`, so `moves_budget()` is 0 and
  `max_moves` is 0 on every band. The counter code (`_spend`, the pill, the
  out-of-moves card, `MovesDiagram`, the `RULES_MOVES*` / `MOVES_LEFT_*` /
  `OUT_MOVES_*` keys) is left in place and unreached, as the hearts are.
- Limits that were Insane's alone went with it: **Gumdrop**'s counted serves
  (`set_day(..., false)` on every band), **Untangle**'s thread (`slack` 0;
  the kitten stays) and **Balance**'s sunset (`sun` off Insane's band; the
  springy bales stay). Hard had neither thread nor sunset already; its
  labels (`UT_LVL_2`, `BAL_LVL_2`) said so wrongly and are fixed.
- **Insane keeps its own rule and its seal**: no Undo, Hint or Check, as
  before (the Hint came back on 2026-10-13, below). Fairy Lights and Paper Planes hung that on `max_moves` and now
  read the band. Button Box and Pixel Garden keep the Undo they were given.
- **Paper Planes**: a gust on a closed-in Windy Day was paid with a move;
  with no counter and no hearts it is free (`_gust_left`,
  `PP_TIP_STUCK_FREE`), or the first closed sky would end the day.
- **Marigold**'s Insane is back on the band's own seeds, raised from 8 to
  Hard's 10 (fewer shots a try was a limit of the same kind), and on the
  all-band rule that a garden out of seeds grows back for another try.
- **Lattice**'s Insane seal read "Twenty" for the swaps it counted; it
  reads "Six knots" (`LA_SEAL_INSANE`).
- The `*_LVL_3` labels that read "counted moves" (strokes, serves, 20 swaps)
  name the band's rule or "no hints" instead, in en, pt and es.
- `tests/_probe_moves.gd` is stale: there is no budget for it to spend.

Not touched, because they are the game on every band or a count of
mistakes, not of moves: Pearl Dive's per-prompt clock (Insane's single tank
did go: `docs/agents/boards/pearl-dive.md`), Word Trail's five wishes, the rows of Hidden Word and Code Break, Drumbeat's misses, and
the two hearts of Trestle, How Big? and Golden Acorn.

The suite 249,784, 0 failed; all 37 boards opened headless on Insane with
`max_moves` 0. Nothing seen on a screen and no Insane day played through:
boards that can dead-end with no Undo (Rings, Hedgehogs, Paper Planes) end
in Start over, as they did under the counter.

### Insane has the bulb again (2026-10-13)

The user, 2026-10-13: "add hints back to insane, players are complaining too
much that it's not fun because of the lack of it".

- **Insane holds as many hints as Hard** on every board that has a bulb:
  each `HINTS_BY` / `HINTS_BY_BAND` / `HINTS` table ends in Hard's figure
  (1, 2 or 3; Binairo's flat 3). The count is mine, the user's to call. A
  video's hint follows once they are spent, as on any band
  (`puzzle_host._hint_offer` reads the capability and `hints_left()`).
- **Only the bulb came back.** `capabilities()` on Insane is what it was
  plus `"hint"`: no Undo and no Check where there was none. The boards that
  refused inside the hint itself no longer do (Marigold's and Mini Golf's
  `hint()`, Trestle's and Hedgehogs' `hints_left()`, Hidden Word's
  `no_hints`, which now reads the table).
- **Hedgehogs, Sleepwalkers**: a hint's flag is pinned, and `restart()` kept
  every pin while it sent the hedgehogs home, so a flag the bulb laid on a
  hedgehog that had walked there would pin a bare pile. `restart()` lifts
  those pins (the hint stays spent).
- **Code Break, the Shell Game**: a hinted seat stays shown through a swap
  and shows whoever sits under that lid now (`_fresh_row` reads `code`), so
  it is never wrong; it does tell one more friend than the hint paid for
  when its lid trades. Left as it is, the user's to call.
- The `*_LVL_3` labels and the Insane rules that said "no hints" / "no
  bulb" lost those words in en, pt and es (the unreached `*_MOVES` rules
  are left as they are, with the counter).
- `tests/_probe_insane_hints.gd` (headless): every registry board on band 3
  must offer the bulb with Hard's count, build its lessons and rules, and
  is then played by the bulb alone. `seeds=2`: 76 days, 0 failures. 22
  boards are carried to the end by it (Knight's Brambles, the
  Sleepwalkers, Homesick, Shy Dew, Peckish, Ribbons, Wish Tags and
  Untangle's kitten among them); the others have a bulb that shows and
  does not play (an aim, a plane named, a letter, an option struck, a
  member laid before Go), as on Hard, or a day longer than the probe's 600
  hints (Pixel Garden's 1,024 beads). Rings is not carried on Hard either:
  each hint is the first move of a fresh search and they do not add up to
  a line; it was so before this and is not looked into. Drumbeat and
  Gumdrop have no bulb on any band. Pearl Dive waits on the backend and is
  not judged there.

Not seen on a phone; no Insane day played by hand with the bulb.
