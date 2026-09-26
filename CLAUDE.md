# Agent guidelines

## The game is 2D only

**The 3D game was removed on 2026-09-24** (`feat/remove-3d`): `legacy/` (the
thirteen island boards, the campsite, How Big?, the stage, the toon and model
pipeline, the island HUD), `assets/models/`, the 3D shaders, every `art/*.blend`
and the Blender export tools, and the More tab that reached them. Git history
has all of it. Nothing in the game loads a model or a `World3D` now, and a new
board is drawn in 2D like the other twenty. The Blender rules that used to open
this file went with it; if a model ever comes back, recover them from history
(`docs/art/blender-contract.md` is still in the tree).

## What the harnesses actually measure

**Run a render harness at `--resolution 810x1440`, never `1080x1920`**
(measured 2026-09-19). This Mac's display cannot show 1920 rows, so the
window clamps to 1080x1676, and `stretch/aspect="expand"` then keeps the
height and *widens* the canvas: `get_visible_rect()` comes back
**1237x1920**, 15% wider than the phone the game is drawn for. `810x1440`
and `720x1280` both come back exactly **1080x1920**, which is the design
space every layout in this file is written against.

Be precise about what that spoils and what it does not, because most of the
figures here were taken with the old flag:

- **Width-sensitive layout is wrong at the old flag, and measurably so.**
  The first screen's card measures **320** wide at 810x1440 and **372** at
  1080x1920 -- and 320 is the number the card-art budget, the 320 by 118
  picture box and the "about seventeen characters a line" of `short` are all
  written against. A frame shot at the old flag showed cards 16% wider than
  the phone will, with the air between them wrong to match.
- **Height-bound cells are the same either way.** Hidden Word's tile is 149
  at both, because six rows of five in a 9:16 slot are bound by the height;
  so is its 801 by 964 block. What differs is the card *around* it: 1000
  wide against 1157.
- **Draw calls did not move.** The first screen reads 311 at both flags on
  the same build (2026-09-19), so the counts recorded in this file are not
  invalidated by the width -- and the 855 budget is unaffected. Frame times
  were not compared across the two and no claim is made about them.
- **`--resolution` is a Godot *engine* flag: it has to come before
  `--script`, never after** (Mushroom Patch's spec, 2026-09-20). Written
  after the `--` it is handed to the script as a user argument instead --
  `OS.get_cmdline_user_args()` sees it and the engine never does -- and the
  run silently falls back to the default, unflagged window (1080x1676 on
  this Mac) rather than erroring. The tell was in the numbers it produced: a
  first-screen card measured 372-373 wide, the 1237-wide canvas's figure,
  not 320's. A whole round of a spec's layout numbers was retaken and
  corrected once this was found; treat any card measuring near 372 as proof
  the flag landed on the wrong side of `--script`.

What has *not* been rechecked is every older recorded layout number taken
from a frame at the old flag. Treat a pixel measurement in this file that
predates 2026-09-19 as taken on a 1237-wide canvas until it is re-shot; a
draw-call count, a budget figure or a design-space constant is fine.

## The first screen

**The first screen is a page of cards** (`ui/menu.gd`, 2026-09-18): the
wordmark in ink with its golden sun-dot and the sun and moon beside it, a day
row, a page of puzzle cards two across and four down, a pager under the
grid once a second page is needed, and a bottom bar. Twenty cards, so three
pages at 1080x1920: eight, eight and four. There is no
stage on it, no `World3D`, and no model anywhere -- `world/main.tscn` does
not even carry a Stage node any more. It replaced the campsite, which was
removed with the rest of the 3D game on 2026-09-24.
Spec: `docs/superpowers/specs/2026-09-18-flat-menu-design.md`.
Mock: `docs/art/concept-menu-flat.png`, playable at
`docs/brainstorm/concepts.html#menu`.

- **Insane is a fourth level on every sheet**, not a twentieth card
  (2026-09-23, difficulty 3, locale key `DIFF_INSANE`), drawn as the sheet's
  one night row: ink fill, paper lettering, a sun-coloured crescent. Band 3
  is a provisional generator row on every board -- the same generator, one
  step harder -- until that board's batch is mined into a bank
  (`core/insane_bank.gd`, `tools/mine_insane.gd`, `content/insane/`); a
  board then reads its bank and falls back to the row without one. Spec: `docs/superpowers/specs/2026-09-23-insane-level-design.md`.
  Two provisional rows miss the 194 ms gate and are accepted by ruling
  rather than weakened: Binairo's Insane is its Hard row again, and Sudoku's
  22-given Insane shares Hard's own 300 ms budget. `tools/` never reaches
  the APK (`export_presets.cfg`'s `exclude_filter`).
- **The heights are a budget, not a taste.** At 1080x1920 since 2026-09-24:
  80 of margin (`ui/menu.gd`'s `MARGIN` 40, top and bottom), 60 of gaps
  (`GAP` 20 between the header, the day card, the grid and the bar), a 380
  header, a 200 day card and a 120 bar leave 1080 -- restated in the final
  fix wave (2026-09-24) to count the pager seam it left out: `PAGER_SEAM`
  20 plus one more `GAP` 20 take 40 more, leaving 1040 for four rows of
  `CARD_H` 246 at an 18 gap (`MIN_ROW_GAP`, below `_fit_grid`'s own comment
  in `ui/menu.gd`), not the 20 the 1080 figure alone would allow -- spent
  as a 10 `INSET`, a 100 banner, the name and blurb in a column
  beside an 80 `GO` button, and 10 back out to the edge
  (`ui/menu/puzzle_card_2d.gd`). The banner was first built at 108, the
  brief's own figure, on the naive assumption that a 44 name plus two 26
  blurb lines summed to 96 with a little to spare; a properly-settled probe
  (task 2, fix round 1, 2026-09-24) measured the name and blurb's real font
  metrics at 122, not 96, so 108 ran the card 8 over its 246 budget and
  `ART_H` was lowered to 100, the floor the brief allows. Before 2026-09-24
  the budget was a 180 day row and a 150 bar leaving 1070 for four rows
  across three columns, so a card was 252 and spent it on a 92 picture, a
  34 name, two 23 blurb lines and a 16 inset. The card carries its own
  paper stylebox rather than `CozyTheme.paper_card()` for that inset: the
  HUD's usual 24 and the mock's 118 picture came to 277 a card and pushed
  the bar off the screen. Anything added to the header, the day card or the
  bar still comes out of the pictures.
- **The page is fitted to the screen since 2026-09-23** (`ui/menu.gd`,
  `_fit_grid`). The canvas is 1080 wide and never shorter than 1920
  (`stretch/aspect="expand"`), so a taller phone gets height and a wider
  screen gets width, and a fixed grid left a tall phone (9:20, the user's)
  an empty band under the last row. The grid takes as many
  columns of `MIN_CARD_W` and rows of `CARD_H` as the room holds;
  the spare height grows every picture up to `ART_GROW` 26 (plate 92 to
  118, the mock's) and then opens the row gaps. `PER_PAGE` is only the
  default before the first fit. **The figures below predate the painted
  menu and are stale since 2026-09-24** (found in the final fix wave's docs
  review): `MIN_CARD_W` is 490 now, not 320, `CARD_H` is 246, not 252, and
  `PER_PAGE` is 8, not 12 -- see "The heights are a budget" above. Every
  reading below this sentence was retaken at the final fix wave rather than
  carried forward: `810x1440` is **2x4**, not 3x4 (255 draw calls on page
  one -- see "Measured again on 2026-09-24" further down for the same
  figure), `660x1500` (9:20) is **2x6** with **twelve** cards on page one
  and **334** calls, not eighteen at 426, and `1080x1440` (3:4), never
  measured before, is **2x4** at **255** as well -- the same layout as
  810x1440, because a third column now needs 1510 design px of room
  (`3*490 + 2*20`), wider than any of these three, so nothing here reaches
  three columns any more. Row gaps may close to `MIN_ROW_GAP` 16: at
  1080x1920 the pager seam now makes the slack negative (see `ui/menu.gd`'s
  own `MIN_ROW_GAP` comment), so the reference screen's gap already closes
  to 18, not 20.
  **A swipe across the grid turns the page** (finger left
  is next), read in `_input` from both touch and mouse because the project
  does not emulate one from the other; the card a swipe started on does not
  open. **Since 2026-09-25 the page slides rather than fades**: past 16 px
  sideways it follows the finger with the neighbour page a margin beside it
  (a second grid, `_peek`, in a plain `_grid_slot` so no container resets
  the offsets), and on let-go it lands past a quarter of the width or a
  700 px/s flick, else slides back; the ends rubber-band. The chevrons play
  the same slide. Draw calls at rest are unchanged (253 / 222). A turn sounds
  a paper slide (`assets/sfx/ui/page.ogg`, `UiSound.page`), never the click:
  the pager buttons carry the `silent` meta. Which cards stand on page one is therefore a property of the phone
  as well as of the card count -- the "eight on the first" figures in this
  file (twelve, before 2026-09-24) are the 1080x1920 page. **They are also
  the no-banner page** (2026-09-25): with a 180 banner up, `_fit_grid` only
  fits 3 rows (6 cards) on page one, not 4, so the same 21 cards take four
  pages instead of three. See "Ads and the purchase" below.
- **The pager came back on 2026-09-20**, once a thirteenth card needed a
  second page (`ui/menu.gd`, `ui/menu/puzzle_card_2d.gd`; the campsite's own
  pager of nine had left with it on 2026-09-18). A five-row grid was
  rejected first: `GridContainer` is `SIZE_EXPAND_FILL`, so simply letting it
  run to five rows takes a card from 252 to about 210, and every one of
  those 42 pixels comes out of the 92 picture -- the one thing this file
  says a new row may not spend. Pagination alone does not hold the budget
  either: a `GridContainer` sizes each row to its own content and never
  redistributes leftover height, so it is `puzzle_card_2d.gd`'s own
  `CARD_H` floor (252 then, **246 since the painted menu of 2026-09-24**)
  that keeps a card at that floor regardless of how many rows
  share the page -- the pager is what makes a second page possible, not what
  keeps a card's height. The strip itself costs the grid nothing: it is laid
  over the seam between the grid and the bottom bar as its own paper pill,
  an overlay on `_list_root` the way `_toast` already is, never a row of the
  column, so a card stays at its `CARD_H` floor (252 then, 246 now) whether
  or not a second page exists.
  **The seam grew a real gap of its own on 2026-09-24** (`ui/menu.gd`'s
  `PAGER_SEAM`, 20): before the painted menu the pill simply floated on the
  bare 20px column gap between the grid and the bar, and at 490x246 cards
  that put it about 18px over the last row's blurb. `PAGER_SEAM` opens a
  second, dedicated 20px gap after the grid (a spacer control, shown only on
  the home tab) so the pill has its own seam to sit in rather than one it
  shares with a card's text; `_fit_grid` subtracts it, plus one more `GAP`,
  from the room a page's rows are fitted into (see "The heights are a
  budget" above). A short
  last row -- one whose cards do not fill `COLS` -- needs invisible
  `SIZE_EXPAND_FILL` filler `Control`s padded out to the column count, or
  `GridContainer` hands the real cells the empty column's leftover width and
  a lone card comes out 334 wide instead of 320. **Whether it runs is a
  property of today's card count and never of the pager**, which is the one
  thing to carry away from it: at fifteen page two held three over three
  columns, a full row, and nothing was built; at seventeen it held five,
  `5 % COLS` was two, and one filler was; at **eighteen** it holds six, two
  full rows, and nothing is built again. It has now been off, on and off
  within three days, so nobody may delete the path because a page happens to
  come out square, and no sentence in this repo may state the answer without
  naming the count it was true at.
  **Sudoku merged into this on 2026-09-20 and its own pager was discarded.**
  Its branch (spec `2026-09-20-sudoku-flat-design.md`, section 9) had built
  a pager into the day row, growing that row's dead chevron into a working
  `next`, on the argument that the row is 180 tall and the only place on the
  screen with a pixel to spare. The user overturned it on main for a reason
  that branch never weighed: a pager beside **Day N** reads as a way to
  change the *day*. `ui/menu/day_row.gd` is back to what it was, chevron,
  hearts and all, and the pager never came back to it. Since 2026-09-24
  (Stats and Streak) its hearts count today's boards and its chevron opens
  the Streak tab -- still not a way to change the day.
- **The sun-dot is the i's dot, not a sticker over it** (`ui/sun_dot.gd`,
  2026-09-19). It sets the label's lowercase i in Fredoka's dotless `ı`
  and seats a small sun where the font's dot was, measured off the
  rendered face: a circle 0.64 em above the baseline, 0.09 em in radius,
  centred on the glyph's advance box, at 140, 84 and 32 alike. The seat
  comes from `Label.get_character_bounds`, so alignment and margins need
  no arithmetic. A rayed sun (84 and up) floats 0.03 em higher so its
  bottom rays clear the stem; the 32 px card names get a plain disc,
  because a ray a pixel wide is a smudge. The wordmark's sprig does **not**
  grow out of the sun: the user moved it off the i on 2026-09-19, and it
  stands on the a instead, the letter before the sun, where the Binairo
  lockup roots its own sprout (the A of BINAiRO). It is drawn from that
  letter's character bounds, at Fredoka 700's x-height (0.507 em) with its
  foot sunk three pixels into the ink. A rayed sun idles like the header's
  sun: rays turning once in 40 s, and a glint every few seconds (rays flare,
  a shine mesh rises and fades on the boards' flash timings); a plain disc
  never moves. It costs the header one draw call over a still sun.
- **The menu paints its own page.** The campsite used to fill the frame, so
  the old menu never drew a background and the viewport's clear colour --
  the stage's sky -- showed through. With nothing behind this screen,
  `_build_list` lays a `Pal.PAPER` rect under everything.
- **The header stands in the treehouse at dusk, full-bleed** (`ui/menu.gd`'s
  `_backdrop`, `Vistas.header_plate()`, 2026-09-24). The plate is laid under
  the margins so no row of the column moves, anchored top-wide from the
  screen's own top edge and run down to `MARGIN + insets.x +
  MenuHeader.HEIGHT + BACKDROP_BLEED` -- `BACKDROP_BLEED` 140, how far the
  painting runs behind the day card before it has faded to paper
  (`Vistas.HEADER_FADE`). The sun and the moon sit seated on the deck at
  `menu_header.gd`'s `SUN_SEAT` 250 and `MOON_SEAT` 220, `PAIR_TOP` 95:
  measured against the dusk vista's own floor line on the 810x1440 frame so
  the sun's seat rests 10px above the deck's wood post/table edge and the
  moon clears the hanging lantern. **The crop is inset-independent since
  the final fix wave (2026-09-24, F1)**: growing the plate by a top
  safe-area inset (a punch-hole phone) used to rescale and slide the whole
  painting, because `Vistas.crop()` covers the plate off its own height --
  walking the pair off the deck on any inset above zero. `Vistas.set_top_pad
  (plate, px)` now tells the crop to cover the plate at its pre-pad height
  and extends the UV rect upward by the pad's own share of that crop, so
  the picture below the pad is pixel-identical to the pad-0 case, shifted
  down by the pad; `ui/menu.gd` calls it with `insets.x` right after sizing
  the plate. Verified with a forced inset of 100 at 810x1440 (this Mac
  reports 0, so the probe forced `SafeArea.insets()`'s return value):
  cross-correlation against the inset-0 shot found the best alignment at
  exactly 75px down (100 * the harness's 0.75 design scale), mean grayscale
  diff 2.9/255 at that offset (reduce-motion, so the sun and moon's own
  idle animation could not jitter the two shots out of phase) -- the small
  remainder is antialiasing rounding, not drift.
- **A card's picture is a painted plate under the board's own cast**
  (`ui/menu/vistas.gd`, `shaders/painted_plate_2d.gdshader`, 2026-09-24).
  Six vistas the user supplied (`assets/art/menu/vista_<name>.png`: sky,
  meadow, night, autumn, beach, dusk) are cropped as fractions of the
  picture, never pixels, so a full-size original can replace a file with no
  change to the crop table, and each is drawn as one `ColorRect` through the
  shader -- one draw call apiece for the header, the day card and every one
  of the twenty card banners. A vista that is not on disk, or an id the
  table does not name, draws a sky-over-ground colour gradient instead,
  never an error, the way `Fx2D.cue()` plays silence for a missing sound.
  Confirmed 2026-09-24 by moving `vista_night.png` and its import cache
  aside and reshooting page one: Untangle's and Light Up's banners drew as
  gradients, with no error or warning in the run's log. The plate sits
  *under* `ui/menu/card_art.gd`'s own drawing, unchanged by this task --
  **characters are still never images** -- so a card's picture is now a
  plate plus a cast, not one replacing the other.
  Before 2026-09-24 the plate under the cast was a plain `Pal.PAPER` rect
  and the cast was the whole picture: `ui/faces/` characters seated in a
  320 by 118 box and scaled to the card, plus whatever furniture they stand
  on drawn under them. Twelve of the eighteen were almost entirely reuse;
  the six that borrowed nothing were Nonogram, Sudoku, Bridges, Quilt, Paper
  Planes and Pinwheel, none of which has a character to borrow, and none of
  which has a branch of `_build` at all.
  **Quilt's is the board's own drawing rather than a second one**: the card
  and the board both lay their patches through `ui/faces/patch_cloth.gd`, so
  they cannot drift apart. **Pinwheel's is the second of those**, through
  both `patch_cloth.gd` and `ui/faces/pin_wheel.gd`. It is never an
  image and never a `SubViewport`. A new card costs one branch of `_build`
  and, if it needs furniture, one of `_draw`. **A picture drawn with `_draw`
  bakes into one mesh like everything else** (2026-09-20): Paper Planes' arm
  first drew its 5x9 dot lattice as 27 `draw_circle` calls and the card cost
  **48** draw calls on its own; built into one `Face.Builder` mesh and issued
  as a single `draw_mesh` -- the technique Hidden Word's band already used in
  this file -- **the same picture costs 1**. gl_compatibility pays per
  `draw_*` command, and a card's picture is not exempt -- the painted plate
  under it is one more `draw_mesh` a card, not a reason to relax that.
- **Eighteen cards, all eighteen live, and no `soon` card left** (as of
  2026-09-20; **the registry grew to twenty since**, with Fairy Lights and
  Rings -- see "The flat screens" section below for each -- and
  `Registry.PUZZLES.size()` reads 20 today, not eighteen; neither was
  swapped in over a `soon` card or bumped anything off the grid, the same
  as the six before them). Three left
  the grid in a week, each being redesigned outright and each keeping its
  island board under More: Snake Apple's on 2026-09-19 to make room for
  Queens (`seed_as` still `snake`), Horse Pen's the same day for Hidden Word
  (`seed_as` still `horse`), and Pipes' on 2026-09-20 for Word Trail, the
  twelfth live card (`seed_as` still `pipes`). Mushroom Patch is the
  thirteenth, and it is the one that was *added* rather than swapped in,
  which is what took the grid over a page -- see the pager above. Sudoku is
  the fourteenth, added 2026-09-20 without displacing anything either,
  Bridges the fifteenth, Quilt the sixteenth, Paper Planes the seventeenth
  and Pinwheel the eighteenth, all four the same day again and none of them
  displacing anything; all six stand on page two, which is what page two is
  for.
  `PER_PAGE` was twelve at the time, so page one kept exactly the same
  twelve cards in the same order and the fifteenth through the eighteenth
  cost it nothing at all -- which is what paging buys over reflowing.
  **Restated 2026-09-24 (final fix wave)**: the painted menu's `PER_PAGE`
  is 8, not twelve (see "The heights are a budget" above), so page one now
  keeps its own same eight cards while everything from the ninth entry on
  -- Fairy Lights and Rings included -- lands on page two or three without
  moving page one at all; it is the same promise, collected on again at a
  different `PER_PAGE`. **The
  dimmed-card machinery is now unexercised**: the registry's `soon` flag,
  the 55% ink, the pale `SOON` pill and `ui/menu.gd`'s `blocked` signal
  (which answered with a line saying the island version is under More) are
  all still in the code and nothing on the screen reaches them. They stay
  there for the next board that is named before it is drawn -- and with them
  the two rules they were built with, learned the hard way and not to be
  re-derived: a dimmed card holds the last slot of the last row, because
  dimmed cards scattered through the grid read as a bug rather than as a
  plan; and the pill hangs off the card, **not** off `_inner`, which is a
  PanelContainer where a second child is stretched over everything.
- **The hearts, the calendar badge and Stats and Streak are real since
  2026-09-24** (spec `2026-09-24-stats-streak-design.md`). The hearts count
  today's distinct boards solved, up to three, and three keep the streak;
  the badge is the current streak, hidden at zero; the day row's chevron and
  the header's calendar badge both open Streak. Stats and Streak are real
  tabs whose bodies replace the day row and the grid in that same room while
  the header and the bar stay put (`ui/menu.gd`'s `_show_tab`). Every figure
  on both screens is derived from `Progress.solve_log()`, never stored.
  Measured with `tests/_shot_menu.gd -- streak` and `-- stats` at
  `--resolution 810x1440` (second reading of two, the first including this
  session's shader compile): **330** draw calls on Home (the control, twice),
  **142** on Streak and **148** on Stats, both well inside the 855 budget.
  **Redrawn to the user's mocks on 2026-09-25**: Stats' totals carry icon
  plaques and a second line (solves this week, the last seven days as dots,
  and a best-streak tile that opens Streak), its chips carry icons, and each
  board's cell stands under its home card's banner with a done seal; Streak
  is a flame and a best/days/solved/rest-days list with a painted picture
  set into the card, today's hearts with a three-part bar, and a calendar of
  paper tiles with the neighbouring months greyed in. The rest-days row is
  not in the mock and was kept by the user's decision. Measured the same way:
  **Stats 484** (all twenty banners stand at once -- the heaviest screen in
  the game) and **Streak 257**. The 855 figure is inherited from the 3D
  island (755 plus 100 for the HUD, 2026-09-14), not a phone measurement.
  The Streak cards and the Stats chips opt out of `CozyTheme.dress()`'s wash
  with a plain material, because the mocks' paper is clean. The two Streak
  pictures are crops of existing vistas with the mock's props drawn over
  them in code (a heart signpost on a rock, the sprout on a rock): the
  vistas are the user's paintings, and nothing new is painted into them.
- **The registry is two lists.** `Registry.PUZZLES` is the grid (twenty
  flat boards since Fairy Lights and Rings, no `soon`; eighteen before
  2026-09-24); `Registry.LEGACY` is the old game. A grid entry
  carries `short`, the card's own two-line blurb. **Restated for the 490
  card** (final fix wave, 2026-09-24): the text column beside the go button
  is 470 (card minus the panel's 20 of `INSET`) less an 18+8 `TEXT_INSET`
  margin less the 80 `GO` button and its 12 separation -- 352 px, up from
  320 -- and `CardBlurb`'s own font (Nunito 600 at 26, measured with a
  throwaway probe) averages 11.9 px a character on the registry's real
  `short` strings, so 352 has room for about thirty, not the seventeen the
  320-wide card was said to fit. Nobody has rewritten `short` for the extra
  room, so today's lines still run 12-18 characters -- the seventeen figure
  was always closer to how long the authored strings are than to a hard
  fit limit, and remains true of the text itself, if not of the column.
  `blurb`'s label carries `line_spacing` -6 and
  `TextServer.OVERRUN_NO_TRIMMING`, not the ordinary
  `OVERRUN_TRIM_ELLIPSIS` (`ui/menu/puzzle_card_2d.gd`, task 2, 2026-09-24):
  once the label sits inside a `VBoxContainer` ("words") inside an
  `HBoxContainer` ("row") beside the go button, `OVERRUN_TRIM_ELLIPSIS`
  rendered only the first of its two lines and ellipsised the rest, even
  though the label's own reported size and line count were both already
  correct -- a Godot 4.7 quirk of that particular nesting, confirmed by a
  throwaway probe at the time. `OVERRUN_NO_TRIMMING` shows both lines
  correctly in the same nesting and simply drops a third line with no dots,
  which nothing in the registry's `short` strings ever reaches.
- **Measured on this Mac** (`tests/_shot_menu.gd` at `--resolution 810x1440`,
  which is the true 1080x1920 of design space -- see "What the harnesses
  actually measure" above): **335** draw calls on **page one** against the
  campsite's 338 and the 855 budget, and a mean idle of 8.31-8.42 ms -- this
  merge's own four readings (8.31, 8.33, 8.38, 8.33) plus 8.42 from main's
  earlier session, before Sudoku arrived; the range spans both sessions
  rather than one, named here so it is not read as four readings taken in a
  row --
  which is the 120 Hz vsync cap, and this harness never disables vsync, so
  it is a ceiling and not a measurement. What can be said honestly is that
  the campsite sat at ~13 ms, above the cap, and this screen is inside it.
  **335 is the figure after Sudoku merged**, re-measured on 2026-09-20 at
  the merge and read four times in a row -- twice on its own and twice more
  as the first shot of the `page2` runs below -- against the same 335 main
  recorded before Sudoku arrived. **Sudoku costs page one nothing, because
  it stands on page two**, which is the whole point of paging rather than
  reflowing.
  **335 again after Bridges, Quilt and Paper Planes**, re-read on 2026-09-20
  at that merge -- three readings in a row, 335 every time (mean idle 8.59,
  8.45 and 8.32 ms) -- for the same reason: all three of those cards stand
  on page two. **335 again after Pinwheel**, twice more at that merge on the
  same day, for the same reason again.
  **Page two reads 159** with its six cards -- Mushroom Patch, Sudoku,
  Bridges, Quilt, Paper Planes and Pinwheel -- no filler (six over three
  columns is two full rows), the pager pill, and the header, day row and
  bar already standing; two readings in a row, 159 both times, mean idle
  8.31 and 8.33 ms. That is a committed reading, not a
  probe:
  `tests/_shot_menu.gd -- page2` turns the page instead of opening More, so
  anyone can retake it. It read about 100 when Mushroom Patch stood there
  alone, **119 with two cards and an invisible filler** (twice in a row,
  mean idle 8.31 and 8.33 ms), **140 with four** and **149 with five**, so a
  card on a bare
  page costs about 20 at first and then settles to about nine or ten once
  the pill
  and the filler are already standing: 119 to 140 for Bridges and Quilt
  together, 140 to 149 for Paper Planes on its own and **149 to 159 for
  Pinwheel on its own**. Pinwheel's +10 is the firmest of those, because it
  was measured twice against two *different* pages of five -- 140 to 150 on
  its own branch before Paper Planes merged, and 149 to 159 after -- which
  is a better statement about a card's cost than either reading alone. **Eight of that nine
  is the card and one is its picture**: on the branch that built it, page
  two read 127 with the card standing and its picture box empty -- both
  before the arm was written and again with the arm stubbed back to a no-op
  -- against 128 with it drawing. It is one because
  the whole picture is one baked mesh -- unbaked it was 48, and that page
  read 175. (Those three figures were taken when page two held three cards
  and are quoted for the +1, not for the page total, which 149 replaces.)
  **It read 322 on the same twelve cards before the pager landed**, so the
  strip itself -- its paper pill, the prev and next buttons and the two dots
  -- is the +13, and Mushroom Patch's own card costs page one nothing
  because it stands on page two. **322 in turn read 311 on 2026-09-19**, and
  that +11 was
  one card swapped, not one added: Pipes' dimmed `soon` card left the
  twelfth slot and Word Trail's live card -- the sprout and a 4x3 field of
  letter tiles with a trail bending through it -- took it. The count read
  311 at the old `1080x1920` flag too (2026-09-19), so what the wider canvas
  moved was the layout and not the calls. Before that it was 291 before
  Queens and 319 with Queens beside Horse Pen's `soon` card; swapping that
  card for Hidden Word's live one took it to 311, and Hidden Word's own
  picture is 7 of that 311 -- checked on the same build with its `_draw`
  branch stubbed out, at 304, twice. Of the older rise, the Queens card
  alone cost 12 and the rest predates it: the header's turning, glinting sun
  and later changes since 291 was first measured. **All of the above is
  before 2026-09-24**, the three-column grid this file measured up to
  Pinwheel and Rings.
- **Measured again on 2026-09-24, the painted two-column screen**
  (`tests/_shot_menu.gd` at `--resolution 810x1440`, two readings taken
  one after another and the second quoted): **255** draw calls on **page
  one**, well below the pre-painting 334 even though eight cards now stand
  where twelve did, and a mean idle of 8.33 ms both times -- the same
  120 Hz vsync ceiling this file has read since the flat menu shipped, so
  still not a frame-time measurement. **Page two reads 224** (`-- page2`,
  8.39 then 8.33 ms), **Streak 112** and **Stats 149** (`-- streak` and
  `-- stats`, 8.33 and 8.33 ms, then 8.33 and 8.34 ms), all comfortably
  inside the 855 budget. A card measured 364-365 px wide on
  `/tmp/shot_menu_1.png` at two rows clear of any art or text (the shadow
  the lifted stylebox casts softens the true edge by a few pixels either
  side), against the 367-368 `MIN_CARD_W` 490 times the 810x1440 harness's
  0.75 scale predicts -- close enough to confirm `--resolution` landed
  before `--script` and not after, where a card would read nearer 430.
  Run again under `--rendering-driver opengl3_angle`: the same 255 draw
  calls and a painted plate on every card; compared against the default
  driver's page-one shot with Pillow, only 695 of 1,166,400 pixels differ
  by more than 30 levels, and every one of them sits inside the header's
  sun-and-moon box (x497-773, y105-284) -- the sun-dot's glint, on its own
  clock, differing between two runs of the same build, the way this file
  has recorded for every other board's ANGLE check.

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
- **Queens is the precedent for a board that answers a move** (2026-09-19,
  `puzzles/queens2d.gd`, spec `2026-09-19-queens-flat-design.md`). A seated
  queen crosses out every cell she sees; those crosses are **derived** by the
  state (`seen`, a count per cell rebuilt after every change) and never
  stored, so lifting her takes them with her and undo keeps no book for
  them. A crown on a seen cell is **refused**, so two queens can never
  conflict and the n-th queen is the win. The wave is its signature: every
  move goes through one `_settle` that diffs a snapshot of the court against
  the state and hands each changed cell its moment, with a Callable saying
  when -- a queen's king-move distance times `WAVE_STEP` (reversed for a
  lift, far cells first), a sweep's path, Reset's far corner -- and the
  cells the queen sees flash gold (`QUEEN_WASH` at `WAVE_FLASH`) as it
  reaches them. The queen bee (`ui/faces/bee_face.gd`) is the cast's one new
  species since the snail: a chibi bee in a small crown, who replaced a
  plain crown with a face on the evening of 2026-09-19 from the user's
  second mock (`docs/art/concept-queens-bee.png`). Her wings are a second
  layer that beats through `Face._layer_transform`, a squash about her
  shoulder line, so a beat rebuilds no mesh and costs one draw call a bee
  (71 on the strip with a queen seated and the chip alive, against 69). The
  tile tray takes a **chip set** now (`TileTray.MOSAIC`, `TileTray.QUEENS`;
  `"tray": "queens"`), so Nonogram's tray and Queens' are one class.
- **Hidden Word is the first board that can end without a solve** (2026-09-19,
  `puzzles/hidden_word2d.gd`, spec `2026-09-19-hidden-word-flat-design.md`).
  Five letters, six rows: type a guess, commit it, and the row turns over a
  tile at a time -- green in the right place, amber in the word elsewhere,
  grey not in it. **The commit is the one irreversible move on any flat
  board**: there is no Undo and no Check, an Enter spends a row, and when the
  sixth is spent the board calls `PuzzleBase.finish_unsolved()`, which sets
  `_done` and emits **`ended`** rather than `solved`. The host connects it
  on every board (the `has_signal` guard for the frozen island contract went
  with the 3D game on 2026-09-24). The keyboard is
  its tray (`ui/flat/key_board.gd`, `"tray": "keys"`), and it is the first
  board with **no tip card** (`"tip": false`) and no actions row. Its
  `rules()` string is real and the rules sheet is built and refreshed for it
  like any other board, but **there is currently no way to open it**: every
  other board's tip card is the sheet's only door
  (`tip_card.open` to `_open_rules` in `ui/flat/flat_host.gd`), and Hidden
  Word has no tip card. This is an open question for whenever the tip card
  is retired across the other ten boards, tracked in the spec's amendments;
  it is not a claim that the keyboard explains the rule, which it does not.
  **The flip is its signature** and its
  numbers are its own three (`FLIP_STEP`, `FLIP_TIME`, `TOAST_HOLD`), with
  six more for the ending -- the keyboard's exit, two dim levels, the dim's
  time and the sprout's rise -- which stand in the board because nothing else
  in the game can run out, so `core/motion.gd` would never read them. A
  refusal is a toast over the card and never a silence. It ships words:
  `content/hidden_word.json` (968 answers in three bands) and
  `content/hidden_word_accept.txt` (15,921 a guess may be), and `content/*`
  had to join the export preset's `include_filter` to reach the APK at all --
  which was also quietly true of How Big?'s table. **Never call it Wordle**,
  in code, in a comment or on screen; the New York Times owns that, and this
  repo already ships Mastermind as Code Break for the same reason.
  Measured on this Mac with `tests/_shot_anim.gd -- hiddenword` at
  `--resolution 810x1440`: **110** draw calls with the first row committed and
  the keys repainted (109 bare, 109 to 111 over fourteen runs), and **56** in
  the losing reveal, where the keyboard has gone and the grid is dimmed --
  all well inside the 855 budget. Its idle reads about **5.0 ms**, and that
  figure deserves a caveat: fourteen runs spread 3.06 to 7.30 (median 5.00).
  Queens, run as a control in the same session, swung as widely -- 4.40,
  4.62, 4.45, 2.84, 4.55 and 4.52, a factor of 1.6 against the 3.83 recorded
  in its own spec -- which is what shows the spread is this machine's and not
  this board's, and why **a single reading off this harness is worth
  nothing**. Compare a board only against another board measured the same
  hour, and quote every reading, including the flattering one. The reveal,
  which draws half as much, read 1.88 and 1.92. Checked on the phone's driver
  (`--rendering-driver opengl3_angle`): same 110 and 56, and the settled
  frames match the default driver to 21/255 on edge antialiasing alone, so
  nothing has reintroduced an `instance uniform`.
- **Word Trail is the twelfth board, and the first whose signature is a
  drawn path** (2026-09-20, `puzzles/word_trail2d.gd`, spec
  `2026-09-20-word-trail-flat-design.md`, mock
  `docs/brainstorm/concepts.html#wordtrail`). Drag orthogonally through a
  field of letters; every open tile belongs to exactly one hidden word and
  the lengths under the field are the only clue. Only a **right** word
  locks, so nothing wrong can sit on the board and there is no Check --
  which, with no tray, leaves the tip card alone in its bottom slot at 140
  and Reset up in the top bar. **It is called Word Trail and nothing else**,
  in code, in a comment or on screen: LinkedIn ships this game under its own
  name, which the design docs record once each, in order to forbid it, and
  which nothing else may repeat. This is
  the third time the repo has renamed a game it did not invent (Code Break,
  Hidden Word). The wave is its
  motion, and it needed nothing new from `core/motion.gd`: the ribbon takes
  the word's colour from its first tile to its last at `WAVE_STEP` a tile,
  `_front(i, t)` is the one truth four things read (which tile wears the
  colour, how far the ribbon is drawn, which slot box is lit, which letter
  has arrived), and Undo and Reset run the same wave backwards. Its only two
  motion constants are `WAVE_STEP` and `BEAM_TIME`. Since 2026-09-25 a trace ticks (`select`,
  pitch climbing with length) and is spelt into the smallest unfound slot it
  fits (`_preview_slot`), stepping up a size as it grows. Its band is Hidden
  Word's, appended to the board's own builder rather than mounted as a
  `Scenery` node, so it is one draw call. Measured on this Mac with
  `tests/_shot_anim.gd -- wordtrail` at `--resolution 810x1440`, 2026-09-20:
  **65, 62, 65** draw calls over three runs with one word locked (the 62 is
  the outlier of the three; the likely cause, inferred from the timings and
  not measured, is the lock's ring and sparkles dying just as the idle
  window opens), **60/61** bare, **61/61** under reduce motion, and idles of
  2.51/2.49/2.51, 2.40/2.39 and 2.40/2.37 ms. Queens (71, 71) and Hidden
  Word (110, 110) were run as controls in the same session and came back
  exactly as recorded above, which is what makes those figures worth
  quoting. On the phone's driver (`--rendering-driver opengl3_angle`): the
  same **65** twice, and the settled frame matches the default driver to
  5/255 on four pixels -- edge antialiasing, no `instance uniform`. The
  reduce-motion pair 1.5 s apart is pixel-identical again.
- **Bridges is the first board whose field is not paper** (2026-09-20,
  `puzzles/bridges2d.gd`, spec `2026-09-20-bridges-flat-design.md`, mock
  `docs/brainstorm/concepts.html#bridges`). Islets with numbers, 0 to 3
  planks between facing pairs, no two runs crossing, and **every islet in one
  single network** at the end. **It is called Bridges and nothing else**, in
  code, in a comment or on screen: it is Hashiwokakero, and the reference it
  was designed from ships it under a third name; the spec records both once
  in order to forbid them. That is the fourth rename after Code Break, Hidden
  Word and Word Trail.
  **The sea taught the set something.** It was first drawn in `Pal.WATER` and
  was the loudest surface in the game; it is now
  `mix(WATER_HI, PAPER, 0.46)`, and letting the blue down into *paper* rather
  than into a sky colour is what keeps it warm. Two things invert on a pale
  ground -- the ripples are darker than the water and the shallow band is
  paler than the open water -- and the beach had to move from `STONE` (value
  237 against a 230 sea, so the islets stopped reading at all) to `ACORN`.
  **A warm-ink alpha tuned against a dark ground is not portable to a light
  one, in either direction**: three of five re-tunes were reversals, and the
  pale sea *deleted* the special case where `BAD` over deep water came back
  mauve and had to be drawn opaque.
  **The generator grows the answer and then proves it.** Range propagation
  plus a group rule with **two** halves, and the second is load-bearing: a
  group with no still-open lane out is a contradiction, and a group with
  exactly one **must take it**. Drop the forcing half and the guess-free
  rates collapse. The GDScript solver and the mock's JavaScript one agree to
  within two points on attempts, second-answer rejection and guess-free rate
  across all three bands, and both were cross-checked against brute-force
  counters -- which is a better statement about the proof than either alone.
  Worst case 47 ms against the 194 ms gate.
  **`is_solved()` is every rule at once and never a subset** -- every number
  met, no two runs crossing, and one single network. The crossing clause is a
  backstop (`cycle()` refuses a crossed lane) and it was added on 2026-09-20
  with the bug that made it reachable: `hint()` lifted only the **first** lane
  blocking the plank it wanted, and a lane can be blocked by several, so a
  hint could leave two runs crossing with both frozen. A hint now lifts every
  blocker, and costs one undo per blocker plus one. The near-miss
  -- every number met, the islets in two rings -- is **unsignposted by
  decision**. Check is the only door and it costs a check, which is why
  **Check's marks flash and then hold until the next move** rather than
  fading as Nonogram's do: a paid-for answer is kept, and a reduce-motion
  player, who is drawn no flash at all, is shown something.
  Measured with `tests/_shot_anim.gd -- bridges` at `--resolution 810x1440`:
  **64 bare, 64-65 played**, against the 855 budget, with Word Trail (65, 65)
  and Queens (71, 71) both reproducing their recorded counts as controls in
  the same session. Idle read 3.11 to 4.22 ms over eight runs -- but Word
  Trail's idle came back 20-40% above *its* record in that same session, so
  **the counts from it are trustworthy and the milliseconds are comparable
  only within it**. ANGLE agrees on 65 and matches to 4/255 on the sea's
  gradient rounding; the one three-figure difference is the shared wordmark's
  sun-dot, whose glint is on its own clock and differs that much between two
  runs of the *same* driver.
  **It was designed against a grid that had no pager, and merged into one
  that had.** While this board was being built, `ui/menu.gd` still looped the
  whole registry with no cap, so its own registry entry made a fifth card row
  and pushed the bottom bar off the screen -- the menu read 313 draw calls
  against 322 because the bar had left, which is a symptom that looks nothing
  like its cause. Mushroom Patch and Sudoku landed the pager before this
  merged, so Bridges is simply **the fifteenth entry and the third card on
  page two**, and none of that bites. It is written down because the next
  board added without a pager in front of it will see exactly the same thing.
- **Quilt is the sixteenth board, and the first to put its pieces inside the
  board card** (2026-09-20, `puzzles/quilt2d.gd`, spec
  `2026-09-20-quilt-flat-design.md`, mock
  `docs/brainstorm/concepts.html#quilt`). A shaped backing of pale cloth and
  a rack of coloured patches under it; drag each patch on, wholly onto the
  backing and never over another, and the quilt is done when the last one
  goes on. The genre ships elsewhere as "Blocos" and as "Block Fit";
  **it is called Quilt and nothing else**, which is the fifth rename after
  Code Break, Hidden Word, Word Trail and Bridges. **Patches never turn** --
  one decision a drag, where, and not two.
  **Nothing wrong can be sitting on this quilt**: the patches' cells sum to
  the backing's and an illegal drop is never taken, so the last patch sewn
  on *is* the solve and there is no Check. That makes it Word Trail's shape
  -- no tray, no actions row, Reset up in the top bar, the tip card alone at
  140 -- reached by a third route, and it is why **the rack is not a tray**:
  a drag from a tray row to the board crosses a node boundary, and the whole
  gesture has to live in one coordinate space, so the card takes all 1340
  and holds both. **Its signature is the stitch**: a patch that lands sews a
  running stitch along every seam it now shares, dash by dash, in a wave out
  of the patch that landed. The seams are **derived and never stored** --
  each takes the *later* of its two patches' landings, because a seam
  belongs to a pair -- and the board's `_settle` is the plainest form of
  Queens' and Sudoku's: it diffs where every patch *is*, before against
  after, so a hint that displaces two patches and the undo that puts them
  back both animate correctly without either knowing which patches those
  were.
  **Three proposals died on the first rendered frame and one on a
  measurement**, all recorded in the spec's section 15 because the reasons
  travel: Queens' `REGION` pastels are a *ground* and two of the nine read
  as holes in the card, so `Pal.CLOTH` was added (a patch is the thing the
  player moves and has to be the strongest surface on the screen, not the
  palest); `SURFACE_HI` is four points of value off `PARCHMENT`, so the
  backing is Shikaku's `BED_GROUND`, the one palette entry already chosen to
  read as bare ground *on parchment*; a rack of equal bays measured **46.7 a
  cell on every band** because any single four-tall patch sizes them all, so
  it is two content-packed shelves with the tall patches grouped; and the
  empty bays are drawn, because without them the rack empties as the quilt
  fills and the last patch is dragged across four hundred pixels of nothing.
  **And a fifth, which is the one that travels: a patch cannot blush.** Every
  other board flashes a refused piece toward `Pal.BAD`; `Pal.CLOTH` runs
  right round the wheel, so at 0.30 the teal goes from 0.34 saturation to
  **0.07** (dead grey), the sage swings hue 91 to 49 (khaki) and the sky 212
  to 265 (mauve) -- only the four warm cloths blush at all, and a greyed
  patch reads as *disabled* rather than as refused. So the refusal is a rose
  **halo stroked round the silhouette** with the shiver, and the cloth is
  left alone: `docs/art/flat-motion.md`'s rule 9 read for a piece that is
  its own shape. **Any board whose pieces are coloured by index should
  expect this.** Two bugs on the drag were also found in review and are
  locked by `tests/test_quilt_board.gd`: an origin packed as
  `row * cols + column` wrapped a hold one cell off the left edge onto the
  far right (2,386 of those came back legal across 120 boards), and a second
  press stranded the held patch with no undo entry, because `take()` pushes
  no history and the matching `drop()` never ran.
  Measured with `tests/_shot_anim.gd -- quilt` at `--resolution 810x1440`:
  **58** bare, 58-59 played over six readings, **80 on the fullest board** and 58 under reduce
  motion, against the 855 budget, with Queens (71, 71) and Word Trail (65)
  reproducing their recorded counts as controls in the same session. Idle
  2.09-3.90 ms across every state, against a Queens control at 3.45/3.49 in
  that session and 3.83 in its own spec, so the milliseconds are comparable
  only within the session. ANGLE agrees on 80 and matches the board card to
  1/255; the reduce-motion pair 1.5 s apart is pixel-identical. Generation
  worst case **51.8 ms** against the 194 ms gate, and the one thing to know
  about it is that **uniqueness is not what the attempts are spent on** --
  only 2.5 to 4.7 percent of grown boards have a second tiling, because a
  region tiled by pieces that never rotate is almost always rigid; what
  costs attempts is grows that wedge (77 to 92 percent of them).
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
- **Mushroom Patch is the thirteenth board, and the first that was added
  rather than swapped in** (2026-09-20, `puzzles/mushroom2d.gd`, spec
  `2026-09-20-mushroom-patch-flat-design.md`, mock
  `docs/brainstorm/concepts.html#mushroom`). Every number counts the
  mushrooms in the eight cells touching it; plant a mushroom where you have
  proved one is, lay a pebble where you have proved one is not, and the
  patch is done when the last mushroom is planted. **Nothing is revealed by
  a tap and nothing can be lost**, and no board needs a guess: the generator
  carves each one backwards out of a full field and its solver proves it by
  logic alone before it is handed over. Queens, Hidden Word and Word Trail
  each took a `soon` card's slot; this one took no slot, which is what put
  the first screen back on a pager -- see "The first screen" above. Its
  signature is the **count wash**, a running feedback no other flat board
  gives: a number turns the moment its count is satisfied, so the board
  answers a move without being asked to check, and `docs/art/flat-motion.md`
  is where that is recorded. It needed nothing new from `core/motion.gd`.
  **Its title is the widest in the game**: `Mushroom Patch` measures 635 in
  Fredoka 700 at GameWordmark's 84 against a four-button block of 496, where
  Hidden Word's 482 was the widest that had ever fitted, so it is the first
  *title* on a four-button bar to be lettered smaller. It lands at 65,
  through the bar's own fit (the bullet below) and at no cost to the board.
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
- **Paper Planes is the seventeenth board, and still the cheapest board in
  the game after Bridges and Quilt**
  (2026-09-20, `puzzles/planes2d.gd`, `puzzles/planes_state.gd`, spec
  `2026-09-20-paper-planes-flat-design.md`, mock
  `docs/brainstorm/concepts.html#planes`). A field of bent ink trails, each
  with a folded paper dart at its head, on a lattice of faint dots. **Tap a
  plane and it launches** -- it slides forward along its own body and out
  over the edge, head first, the tail pulled through every bend the way a
  ribbon is pulled through a hole -- but only if its **lane**, every cell
  straight ahead of the dart out to the edge, is empty. Clear the sky and the
  board is done. **It is called Paper Planes and nothing else**, in code, in
  a comment or on screen: the app the reference screenshot came from ships
  this genre under its own name, which appears in the spec (four times) and
  the concept page (twice) in order to forbid it, and is nowhere in code, in
  a comment, in a commit message or on screen -- the rule the earlier
  "records it once" phrasing overstated is fully honoured; only the count of
  where it is written down was wrong. It joins a chain this file is careful
  to **name rather than number**, because two branches numbered it two
  different ways on the same day: Code Break, Hidden Word, Word Trail,
  Bridges, Quilt and now Paper Planes, with Mushroom Patch (Minesweeper's
  gentler cousin) counted in it by some bullets and not by others. The
  re-theme came free with the name: an arrowhead folded once is a paper dart,
  and a dart that needs a clear lane before it takes off *is* the rule, said
  in a picture.
  **One fact shapes the whole screen: a launch can never block another
  plane**, because launching only empties cells and a lane is blocked only by
  occupied ones. So there is no wrong move and therefore **no Check**, the
  player cannot dead-end a board that was generated solvable, and the solver
  is greedy and complete -- launch anything whose lane is clear, repeat.
  The generator carves backwards out of an empty sky in reverse play order
  (planes placed later are launched earlier), so a solution exists before the
  first pixel is drawn; measured in GDScript on this Mac over forty seeds a
  band, **1.3 / 2.2 / 7.0 ms** a board for 21-31, 30-45 and 45-62 planes at
  0.70-0.91 coverage, which is two orders off Sudoku's budget problem, so
  **this board has no fallback path and nothing to grade against a clock**.
  **The hard band is the loosest, not the tightest**, and that was accepted
  rather than overlooked: steps with two or fewer legal launches measured
  **22.0% / 16.6% / 12.6%** easy / medium / hard, so a bigger board leaves
  *more* free at once. Difficulty here is how long you sit, not how hard you
  look -- the genre is scanning, not deduction, and dressing it as deduction
  would be a lie the generator cannot back.
  **The launch and the wake are its signature.** The plane runs a track --
  its own body polyline, extended down the lane and one body-length past the
  edge -- eased off `Motion.pop_out_scale` read backwards, with a puff where
  the head crosses the edge and each cell taking its dot back as the tail
  passes over it; then every plane the departure **newly freed** beats its
  wings once, staggered by king-move distance from the departing head. That
  is Queens' `_settle` with a departure in place of a queen's sight, derived
  off a snapshot diff and never stored, so an undo leaves nothing to clean
  up. A refusal is a picture of the rule and not a scolding: the lane flashes
  `BAD_TILE` from the dart to the blocker, the blocker shivers, the tapped
  plane nudges, and the tip card says why -- no toast, because this refusal
  is frequent by design. It needed **nothing new from `core/motion.gd`** and
  carries three constants of its own (`LAUNCH_SPEED`, `WAKE_STEP`,
  `BLOCK_FLASH`) plus `WIN_WAIT`, which at **2.7 s is the longest win wait of
  any flat board** and is arithmetic rather than taste: the longest flight
  this game can generate is **1.364 s**, not the 1.41 s first recorded --
  that bullet described a ten-cell plane with its head on row 0 of the hard
  band, which cannot exist (`add_plane` derives a direction from the cell
  before the head, and row 0 pointing off that edge would need a cell at row
  -1); the true ceiling is a head on row 1, and the solve wave after it is
  1.25. Shikaku's 2.2 was the longest constant before it, and Hidden Word's is the
  only one that is computed rather than set -- its flip plus 1.6, which comes
  to about 2.66, so 2.7 wins by a hair rather than by a length.
  **The cells are 91, 71 and 58**, and **58 is the smallest cell of any
  playing grid in the game** -- under Bridges' hard-band 84, Sudoku's 100,
  Queens' and Nonogram's 103 and Quilt's 114. It is bearable for a reason
  none of those could use: **you do not tap a cell here, you tap a
  plane**, the smallest of which covers two cells and carries a dart across
  most of one. **One thing on a flat screen is drawn smaller**, and it is
  named here so the superlative is not read wider than it is: Quilt's *rack*
  cell measures 57.0 mean and 48.3 worst on its hard band (its spec's
  section 6). That is a waiting patch's display size in the rack and not a
  grid anything is placed on -- a rack patch spans several of them and is
  dragged, not tapped -- so the two numbers are not the same kind of thing,
  but "the smallest cell in the game" full stop is no longer a sentence this
  file can stand behind. Its bottom slot is the tip card alone at **140**,
  **the shortest in the game and now shared four ways** -- Untangle, Word
  Trail, Quilt and Paper Planes -- and Reset rides up into the top bar
  with it. **It is the one flat board that clips** (`clip_contents = true`):
  a launch runs up to a body-length past the grid and would otherwise draw
  over the day card and the top bar, so the cut lands on the board card's own
  hem. It adds **no character and no entry to the palette** -- the fourth
  board to seat none at all, after Sudoku, Bridges and Quilt. **Since the
  polish of 2026-09-26** (toward the user's reference) a plane is a drawing
  in `ui/faces/paper_plane.gd`, shared with its menu card: a pressed paper
  groove with a stitched centre and rounded bends, and a two-tone origami
  dart in one of three papers (identity, never state). The field is **two
  meshes**, a still one (the paper panel, the hint's glow, every plane at
  rest), rebuilt only when the set of moving planes changes, and a live one
  (dots, leaves, the refusal's band, contrails, moving planes), each kept in
  `_still_shown`/`_shown` until the next replaces it. A launch lifts the
  dart (its shadow falls away), leaves a fading dashed contrail, turns the
  leaves beside the lane, and flies on until the tail clears the card's
  margin. **53** draw calls at rest after the polish (2026-09-26, twice),
  reduce motion pixel-identical, ANGLE agreeing on 53. The figures below are
  the pre-polish board's.
  Measured with `tests/_shot_anim.gd -- planes` at `--resolution 810x1440`,
  2026-09-20: **55** draw calls on every run anyone has taken of it -- three
  in the session that first measured it (idle means 2.13, 2.07 and 1.98 ms),
  two more under and without reduce motion (1.97 and 2.02, both at 55, so the
  solve wave costs nothing because the field was already one mesh), and two
  again when this file was written (6.52 and 2.05). Word Trail, the control,
  read **65 / 2.30 ms** in the first session, **62 / 2.42 ms** in a
  reviewer's separate one and **65 / 2.69 ms** in the last, so the gap holds
  across three sittings and is what the comparison actually rests on -- a
  single reading off this harness is worth nothing (Hidden Word's spec). One
  caveat, named rather than dropped: that **6.52 ms** was the first windowed
  run of its session, on the same 55 calls, which is this Mac's first-run
  shader compile and is why a pair is taken and the second is the one to
  quote. **Re-measured at the Bridges/Quilt merge on 2026-09-20**: 55 twice
  more (2.00 and 2.01 ms), with Quilt read as a control in the same session
  at **59** (2.08 ms, its recorded 58-59) and Bridges at **65** (2.56 ms,
  its recorded 64-65) -- both exactly on their own record, which is what
  makes the comparison worth quoting and what keeps "the cheapest board in
  the game" true at seventeen. **Still true at eighteen**: Pinwheel came in
  at 59 (see its bullet below), four calls above this one. On the phone's driver
  (`--rendering-driver opengl3_angle`): the same **55**, with the settled
  frame differing from the default driver's over 91,782 pixels at a **max
  channel delta of 1** -- edge antialiasing between backends, not a garbage
  `instance uniform`. Reduce motion stills it completely: two frames 1.5 s
  apart are pixel-identical, 0 of 1,166,400, against non-zero controls.
- **Pinwheel is the eighteenth board, and the first piece in the game that
  turns** (2026-09-20, `puzzles/pinwheel2d.gd`, `puzzles/pinwheel_state.gd`,
  `puzzles/pinwheel_gen.gd`, spec `2026-09-20-pinwheel-flat-design.md`, mock
  `docs/brainstorm/concepts.html#pinwheel`). A rectangular frame of cells and
  a handful of cloth polyominoes lying on it, each pinned through **one of
  its own cells** by a paper pinwheel whose board cell never moves. Tap the
  pinwheel and the piece takes a quarter turn clockwise about the pin. A cell
  two pieces are on goes dark; a cell nobody is on stays bare ground; turn
  every piece until there is neither, and the frame is covered exactly once.
  **It is called Pinwheel and nothing else**, in code, in a comment or on
  screen: Puzzmo ships the genre under its own name, which the spec records
  once in order to forbid it. It is the newest link in the chain this file
  **names rather than numbers** -- Code Break, Hidden Word, Word Trail,
  Bridges, Quilt, Paper Planes and now Pinwheel -- for the reason Paper
  Planes' bullet already gives: two branches numbered it two different ways
  on the same day.
  **A tap must skip an out-of-frame orientation, not refuse it**, and this is
  the one thing on this board a future board would otherwise re-derive the
  hard way. Rotation is a discrete state change, so a piece cannot pass
  *through* an illegal orientation on the way to a legal one: a 1x4 bar
  pinned at its end against the frame edge has its solving orientation two
  clockwise steps away with an out-of-frame step in between, and a refusing
  tap makes that solution unreachable for ever. **The generator cannot see
  it**, because it reasons about orientation *sets* and not about
  reachability, so the boards it hands out would be unsolvable and every
  test would pass. Skipping fixes it by construction: the in-frame
  orientations form a cycle, a tap advances one place round it, and every one
  is reachable from every other.
  **A pinned piece cannot translate, so it has at most four placements in the
  whole frame** -- and that is why `puzzles/quilt_gen.gd`'s header warning,
  that a patch free to rotate would make almost every region tileable a dozen
  ways and uniqueness would stop being worth proving, **does not apply here
  and must not be carried over**. Quilt's patches translate and Pinwheel's
  cannot, so Pinwheel is far *more* constrained, the exact cover collapses
  almost at once, and **the proof is the cheap stage here where it is the
  expensive one on Quilt**. There is no wall-clock give-up and no
  `graded: false`: the attempt loop is bounded by `ATTEMPTS` and the honest
  flag is Quilt's `unique: false`.
  **A legibility rule measured against the solved frame is measured against
  the state the player spends the least time in.** The piece colouring
  shipped once on a rule that forbade a shared cloth to two pieces that could
  overlap or that touched *in the answer*. Every measurement behind it was
  true -- at most seven colours over 180 boards, zero clashes over 600 -- and
  the promise was about the wrong state: over 300 seeds a band it left a
  same-cloth pair **orthogonally touching in the opening** on **149, 219 and
  241 boards of 300** (re-measured 145, 214 and 233 on a different seed
  block), and two apricot pieces edge to edge read as one shape. The fix was
  not a weaker rule but a wider graph -- one piece's orientations dilated by
  one orthogonal step meeting the other's, which holds in *every* state the
  board can be in -- and **rejecting the boards eight cloths cannot colour**,
  which costs 3, 17 and 132 extra grows out of 619, 721 and 1125, about ten
  percent on the worst band. Rejection is affordable only because generation
  is. **Any board that colours, shades or outlines its pieces to keep them
  apart should check the rule against the opening, not the answer.**
  **And a wash alone cannot signal state on pieces coloured by index.** The
  stain over a doubled-up cell was first drawn as `Pal.TEXT` at 0.30 and
  nothing else, and on the first rendered band-0 frame a coral under it came
  back as **a maroon piece** and a butter as an olive one -- not "shaded",
  *another cloth*, and a player counting pieces would have counted them. So
  the stain is also **hatched**, diagonal lines in `Pal.TEXT` at 0.20 drawn
  across the union of the stain rather than per cell, because **a hatch
  cannot be mistaken for a cloth**: nothing else on the screen is drawn in
  lines. That is Quilt's "a patch cannot blush" from the other end -- there
  the refusal could not be a colour, here the state could not be -- and
  together they are the general form: **on a board whose pieces are coloured
  by index, no state may be signalled by a shade of the piece's own colour.**
  The refusal on this board follows the same rule and is Quilt's exactly: a
  `Pal.BAD` halo stroked round the silhouette with the shiver, the cloth left
  alone.
  **The turn is its signature and the one thing it added to
  `core/motion.gd`**: `TURN_TIME` 0.26 and `turn_angle()`, a curve reader on
  `back_out`, because a quarter turn is a thing the next board may want and
  every turn before it was an idle or Hidden Word's flip, which is a scale on
  one axis and not a rotation. The piece and its pinwheel read the same
  recipe with different `time`s -- the blades go on to 1.55 times it, so the
  handle carries the overshoot the cloth does not -- which is one recipe and
  one parameter, not two numbers. The stain settles in **Queens' `_settle` in
  a fourth shape**: a snapshot of `cover` diffed before against after, each
  changed cell taking king-move distance from the pin at `Motion.WAVE_STEP`,
  derived and never stored, so a hint that walks a piece through three
  quarters and the undo that walks it back both animate with nothing to clean
  up. Only two constants are the board's own and both are shape rather than
  timing: `STAIN_ALPHA` 0.26 and `PIN_R` 0.19.
  **Its cell is 183 on the shipping band, the largest of any flat board** --
  against Paper Planes' 58 at the other end -- and that is not indulgence: the
  tap target is the pin cell and nothing else, so the input surface is `N`
  cells out of `cols * rows` and a generous cell is what stops a mis-tap
  turning a neighbour. It seats no character (the fifth board to seat none)
  and adds `ui/faces/pin_wheel.gd`, a drawing rather than a character, the
  third after Nonogram's tile and Quilt's cloth; its cloth is Quilt's
  unchanged.
  Measured with `tests/_shot_anim.gd -- pinwheel` at `--resolution 810x1440`,
  2026-09-20: **59** draw calls played and 59-60 bare (the 60 is one frame's
  worth of the wordmark's sun-dot glint, inferred and not measured), 59 under
  reduce motion, against the 855 budget -- the third-cheapest board in the
  game behind Paper Planes' 55 and Quilt's 58, and **a turn costs nothing
  measurable**, because the swinging piece, the stain and eleven pinwheels
  are all inside the same three meshes as the bare board. Queens (71, 71) and
  Word Trail (65, 65) reproduced their recorded counts as controls at both
  ends of the session, which is what makes those counts quotable; the
  milliseconds are not, because Queens read 2.83-2.89 there against the 3.83
  of its own spec. **59 again after `main` was merged in**, with Paper Planes
  in the tree. ANGLE agrees on 59 and 110,002 pixels of 1,166,400 differ by
  **no more than 1/255**, the tightest agreement between the two drivers any
  board here has recorded; the reduce-motion pair 1.5 s apart is
  pixel-identical, in both runs. Generation worst **9.08 ms** in the quiet
  session and 16.42 ms in a loaded one, against the 194 ms gate.
  **Polished on 2026-09-26** (the spec's amendment): Quilt's printed cloth
  and quilting stitch on every piece, a resting shadow that says which of
  two pieces is on top, a tufted backing, the stain's wash down to 0.12
  with a dashed outline carrying the state, and folded pinwheels at 0.28
  with the piece's deep cloth on two vanes and a brass hub (a push-pin for a
  piece pinned fast). A swing lifts and lands with a squash and a puff. An
  idle breeze spins one wheel a half turn every few seconds, never
  continuously, and the win is a gust through every wheel. 56 draw calls
  bare, 57 played, ANGLE agreeing.
- **Rings is the twentieth card, and the one a merge deleted** (built
  2026-09-20, `puzzles/rings2d.gd`, spec `2026-09-20-rings-flat-design.md`).
  Pinwheel's `merge: main into pinwheel` (`57c8539`) took Pinwheel's side of
  every conflict and dropped Rings' registry entry, card picture, suite line
  and win-harness solver without a conflict marker saying so. The board, its
  state and its tests survived, so it sat built and unreachable for three
  days; it came back on 2026-09-24 from that merge's second parent. The same
  merge also dropped `ui/menu.gd`'s `Ads.banner_changed` inset handler, which
  is still missing. After merging a parallel board, diff the merge against
  **both** parents, not only against the side you were on. On the grid it is
  the eighth card on page two at 1080x1920 (8 % 3 = 2, so one filler), page
  two reads **181** draw calls and the board **58** (47 on Insane).
  **Its Insane is a move budget, not a harder deal**: the screen caps it at
  8 pegs and 6 colours, and less slack (6 on 7, 7 on 8) makes 85-93% of
  deals unsolvable and the survivors *shorter*. So Insane is Hard's deal
  sorted within the **shortest** solve plus `PAR_SLACK` 2
  (`rings_state.gd`'s `par`), shown as "N moves left" under the second row;
  Undo gives a move back, so the budget binds the finishing line and not the
  exploring, and there is no hint, because the game's own depth-first solver
  plays lines of 35-63 against optima of 16-24. The optimum is a
  breadth-first search of 90-600 ms a deal on this Mac, so it is mined
  (`tools/insane/rings_ladder.gd`, `content/insane/rings.json`, optima
  22-26) -- the first board with an Insane bank. Its sounds are wired and
  generated (lift, drop, lock, refused, undo, hint, reset, solved, enter).
  **Polished on 2026-09-25** (the spec's amendment): the rings are donuts with
  the post going into the top ring's hole, drawn through one `_append_peg` that
  the menu card shares; the board lays out in a 1000-wide design box scaled to
  the card, so the win screen shrinks it rather than spilling it; a lock is a
  glint and a gold cap, never a wash; a drop is threaded down its post. 54 draw
  calls bare, 60 played. **Polished again on 2026-09-26** (toward the same
  reference): a paved terrace built once into a third mesh, mossy planks with
  leafy daisy clumps (`_append_plank`, shared with the menu card), wooden
  dowels, and an inlaid emblem per colour in place of the pips (heart, sprout,
  circle, flower, diamond, triangle). A held ring turns on its post, shown by
  its emblem walking round the band; a flight whirls it to the next half turn;
  the lock's cap is a daisy; the solve spins every ring. 56 bare, 61 played. **Run windowed harnesses with `--always-on-top`**: a
  covered window stops presenting after about 1.7 s and every later shot repeats
  the last frame.
- **Caterpillar is the twenty-first card** (2026-09-25,
  `puzzles/caterpillar2d.gd`, spec `2026-09-25-caterpillar-flat-design.md`,
  mock `docs/brainstorm/concepts.html#caterpillar`). Drag one walk from leaf
  1 through every square, eating the numbered leaves in order, never across a
  fence; the walk is drawn as the caterpillar (`ui/faces/caterpillar.gd`) and
  the solve turns it into a butterfly. LinkedIn ships the genre under its own
  name; **it is called Caterpillar and nothing else**. Two things travel:
  **a proof capped by a node count is never a proof** -- the first generator
  read a capped search that had found one walk as unique and 14 of 60 hard
  and insane boards had two (`tests/_probe_cat_gen.gd` re-proves uncapped) --
  and **a board whose idle breath rebuilds its whole mesh pays for it every
  frame**: 12.2 ms idle until only the head's small mesh breathed (3.3 ms,
  Pinwheel 2.44 as the control). 58 draw calls on Hard, ANGLE included.
  **Polished on 2026-09-26** (the spec's amendment): a lawn and a
  wooden-framed bed of grass tiles, real leaves under the body with a bite a
  chew, legs that step in a wave while it is dragged, three smooth chews on a
  leaf scrap and a gulp down the body, a head that runs back over a cut rather
  than jumping, and a butterfly that loops away. 58 half-walked, 57 under
  reduce motion, ANGLE agreeing.
  **The tip card is gone from every board** since `1a04e0a` (2026-09-21): the
  bottom-slot figures and tip-card rules elsewhere in this file predate that.
- **Sunbeam is the twenty-second card** (2026-09-26, `puzzles/sunbeam2d.gd`,
  spec `2026-09-26-sunbeam-flat-design.md`, mock
  `docs/brainstorm/concepts.html#sunbeam`). A greenhouse floor: drag brass
  mirrors and copper cups along their rails, the beam re-traced live; light
  every dewdrop, then end in the bud. The reference ships as a game this
  repo names once in the spec to forbid; **it is called Sunbeam and nothing
  else**. Two things travel: **a proof bounded by the pieces' own freedom
  needs no cap** -- `sunbeam_gen.gd`'s `count()` follows the beam and
  branches only on a peg it reaches, so it is exhaustive at 83 ms worst
  (Hard) -- and **hit-test a two-cell piece as the box round both cells**:
  a cup's middle is the line between them, the point a thumb aims at, and a
  per-cell strict test missed it. **What is drawn is a ray, what is judged
  is the grid**: the beam is cast against each piece where it is drawn
  (mid-drag, mid-settle) so it bends continuously, and on pegs it equals the
  grid trace, which alone decides the win. Its drawing is `ui/faces/sunbeam_parts.gd`,
  shared with the menu card. 65 draw calls played, 68 solved, ANGLE agreeing.
  Sounds are prompts in `tools/gen_sfx.py`, not yet generated.
- **Knight is the twenty-third card** (2026-09-26, `puzzles/knight2d.gd`,
  spec `2026-09-26-knight-flat-design.md`, mock
  `docs/brainstorm/concepts.html#knight`). Hop a cream knight in Ls to take
  the rose king; rose knights answer every hop by a fixed greedy rule, and a
  hop into their reach is caught and slid back one move. The reference is a
  Portuguese app's *Cavalo*; **it is called Knight**. Two things travel:
  **a deterministic opponent makes the whole game a graph** -- a position is
  only where everyone stands, so `knight_gen.gd`'s `solve` is a plain
  breadth-first search and the proof is the shortest line -- and **a knight
  always changes colour**, so a rose knight on your colour can catch you and
  you can never take it, and one on the other colour the reverse; the
  corners show it without a word. Its drawing is `ui/faces/chess_piece.gd`,
  shared with the menu card. 67 draw calls bare, 66 played, 71 solved,
  ANGLE agreeing. Sounds are prompts in `tools/gen_sfx.py`, not yet
  generated. The board toasts its own explanations (Rings' toast), because
  the tip card is gone and `tip_line()` reaches no screen, and a Hint on a
  lost position rewinds to the last one that still has a line (`KN_REWOUND`).
- **Hedgehogs is the twenty-fourth card** (2026-09-26,
  `puzzles/hedgehogs2d.gd`, spec `2026-09-26-hedgehogs-flat-design.md`, mock
  `docs/brainstorm/concepts.html#hedgehogs`). Rake an autumn lawn's leaf
  piles; a number counts the hedgehogs asleep in the eight cells round it,
  a nought blows its neighbours clear, and a wrong rake only wakes one up
  grumpy (`woken`, on the win screen and the share line). It is the
  dig-and-flag game Mushroom Patch was drawn *away* from, off the same
  reference; **it is called Hedgehogs**. Two things travel: **a proof that
  plays the day out from its opening is also its uniqueness** --
  `hedgehogs_gen.gd`'s `prove` rakes every bare cell by singles, subsets and
  the count, never guessing, so no separate second-answer search is asked --
  and **a board whose moves all resolve in the state at once needs no input
  lock**: every cell carries its own gust timers, so a tap mid-gust is taken
  and the drawing still lands on the state. Its drawings are
  `ui/faces/leaf_pile.gd` (shared with the tray and the card) and
  `ui/faces/hedgehog_face.gd`. 79 draw calls bare, 80 raked, 83 with one
  woken and 115 on the win wave, ANGLE agreeing.
  Sounds are prompts in `tools/gen_sfx.py`, not yet generated.
- **Shikaku's clues can ask for a shape** (2026-09-25). A clue is
  `{pos, area, shape}`: `shape` is `shikaku_gen.gd`'s `Shape` (any, square,
  tall, wide) and `area` 0 means no number -- the plot may be any size of
  that shape. `Gen.fits()` is the one rule every check goes through. The
  ladder is `shikaku_state.gd`'s `SHAPES`: Easy numbers only, Medium shapes
  on some numbers, Hard and Insane take numbers off shaped clues (about 19%
  and 54% of clues over 40 seeds), each removal kept only if the board stays
  unique. The solver is a cell-first exact cover now, because a numberless
  clue breaks the "areas sum to the field" shortcut; worst generation 57.5 ms
  on Insane. The sign *is* the shape (`marker_face.gd`'s `PLAQUES`), and a
  shaped sign carries an inked inner frame so a square never reads as the
  plain card. The win's flowers are coloured so no two touching beds match.
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

## Sound

Full rules: `docs/art/sound-direction.md`. Sounds are generated with
ElevenLabs by `tools/gen_sfx.py <puzzle_id>` into
`assets/sfx/<puzzle_id>/<cue>.ogg`, and `Fx2D.cue()` plays whichever cue has
a file -- a missing file is silence, on purpose. Soft wood, marimba, kalimba,
glockenspiel and paper; never a buzzer; up means good, down means not yet;
cues that fire on every touch (Binairo's `focus`, `blush_out`) get no file.
One take per cue; the user listens and names the ones to redo. The set is
keyed by `puzzle_id()`, not the card's name (Code Break's is `mastermind`).
Every flat board has a set, Fairy Lights included (2026-09-23). Every button clicks through `ui/ui_sound.gd`, wired by
`CozyTheme.dress()`, and keeps quiet when a board cue answered the same frame.

## Art: shading direction

The look everything aims for is in `docs/art/shading-direction.md`: soft
painted cel, no harsh black outlines, warm muted pastels, diffuse and
painterly surfaces, soft coloured shadows, minimal specular, depth through
colour rather than fog. Read it before touching a shader, palette or light.

The HUD's paper takes the same wash through `CozyTheme.dress()`, installed
once by `world/main.gd` before any screen builds: every Button, Panel and
PanelContainer that enters the tree without a material gets the one shared
paper material (`shaders/paper_2d.gdshader`, measured in screen space), so
a new widget needs nothing. A widget that wants another surface sets its
own material and keeps it, the way the wood trays do. Harnesses that build
a screen without `main.tscn` show the faces flat; that is the harness, not
a regression.

## Playing on an Android phone

The game ships as a native APK through Firebase App Distribution (project
`daily-games-420bf`, package `com.peeplet.daily`). Run `tools/deploy_android.sh`
to export and distribute; the build lands in the Firebase App Tester app on
the phone. Nothing deploys on push.

The export is the Gradle path (`use_gradle_build=true`, since
`feat/gradle-export`), arm64-v8a only, debug-signed. Machine-local setup it
depends on: the Android SDK at
`/opt/homebrew/share/android-commandlinetools` and `~/.android/debug.keystore`,
both wired into Godot's editor settings, plus the 4.7 Android export
templates. `build/` is ignored -- it is output.

## Analytics

Gameplay events go to Firebase (project `daily-games-420bf`) over the GA4
Measurement Protocol, in `core/analytics.gd`. No native SDK of its own --
the Android export moved to the Gradle path for AdMob's and godot-iap's,
see "Ads and the purchase" below.

- **Nothing sends unless `Analytics.start()` runs**, and only `world/main.gd`
  calls it. Tests and harnesses build the same screens and stay silent; keep
  it that way rather than making this an autoload.
- The API secret lives in `analytics_secret.cfg` beside `project.godot`:
  untracked, packed by the preset's `include_filter`, overridable with
  `GA_API_SECRET`. Missing secret means the game runs untracked, not broken.
- Events: `game_open`, `puzzle_start`, `puzzle_complete`, `puzzle_abandon`,
  `hint_used`, `undo_used`, `check_used`, `board_reset`, `rules_opened`,
  `new_puzzle`, `reduce_motion`, `tab_opened` (the menu's Stats or Streak
  tab, with `tab`), and on a board that can be turned,
  `view_turn` and `peek_used`. A daily turn adds `turn_lock`, `turn_reveal`,
  `turn_share` and `crowd_reveal_opened`. Board events carry puzzle_id,
  difficulty, day, seconds, moves, hints, checks; the last two tell us
  whether Pipes' third dimension is a puzzle or a nuisance. Since 2026-09-25:
  `store_opened` (with `door`: banner, header or settings), `purchase_started`,
  `purchase_complete`, `purchase_failed` (with `reason`), `restore_used` (with
  `found`), `consent_failed`, and `ad_banner_loaded` / `ad_banner_failed` /
  `ad_banner_impression` -- see "Ads and the purchase" below.
- **`puzzle_complete` carries a `solved` boolean**, added when Hidden Word
  landed (2026-09-19): until then `done` implied solved, so the event had
  nothing to say either way. Hidden Word can run out of rows
  (`PuzzleBase.finish_unsolved`) without solving, and that ending fires
  `puzzle_complete` with `solved: false` from `ui/puzzle_host.gd`'s
  `_on_ended` -- a lost board is still a terminal event, and without one a
  player who reads six rows and backs out looks identical to a crash. Every
  other board only ever sends `solved: true`, from `_on_solved`. Since
  2026-09-24 a flat daily solve's `puzzle_complete` also carries `hearts`
  (that day's boards, 0-3) and `streak`; a board dealt from New carries
  neither, because it is not a daily and is not logged.
- **`locale` rides on every event**, stamped by `Analytics.track()` beside
  `session_id` and `engagement_time_msec` on whatever it is handed, so any
  event can be split by language without a caller remembering to pass it.
- To debug the wiring: `Analytics.validate = true` posts to GA4's validation
  endpoint and prints the verdict instead of recording; `Analytics.debug_mode`
  puts events in the console's DebugView.
- `tools/analytics_secret.sh <secret>` installs the secret in both places that
  need it (the untracked file and the `ANALYTICS_API_SECRET` repo secret) and
  then sends one DebugView-tagged event, so the wiring is visible rather than
  assumed. GA4's collect endpoint answers 204 to everything, so DebugView is
  the only proof a secret actually works.

## Ads and the purchase

A banner (Poing's `godot-admob-plugin` v5.1.0) and a lifetime remove-ads
purchase (`godot-iap` 3.5.2, `hyodotdev/openiap`), built 2026-09-25
(`docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md`) on branch
`feat/ads-store`. **Two adapters, and a screen never touches a plugin**:
`core/ads.gd` (autoload `Ads`) owns the banner and consent, `core/store.gd`
(autoload `Store`) owns the purchase, both to the rule `core/ads.gd` already
stated before the 3D game left.

- **`Ads.start()` runs once, from `world/main.gd`**, so tests never ask for
  an ad -- `Analytics.start()`'s own discipline. Order: if
  `Store.owns_remove_ads()`, stop for good; else Google's UMP consent
  update, its form when required, `MobileAds.initialize`, then an anchored
  adaptive bottom banner. A failed consent update still proceeds to ads
  (non-personalised) rather than a blank band forever. iOS has no ATT call
  of its own: the tracking prompt is UMP's IDFA message, set up in the
  AdMob console, showing Apple's system dialog; Info.plist still carries
  `NSUserTrackingUsageDescription`. `Store.owned_changed(true)` calls
  `Ads.remove()`, which destroys the banner and never reloads it this run.
- **`ADS_FAKE_BANNER=<design px>` and `STORE_FAKE=1`**, debug-build-only env
  overrides, walk the whole flow on this Mac with no device or plugin:
  the first reports a banner of that height everywhere (`ui/ads/banner_host.gd`
  paints a grey "AD" stand-in), the second makes `Store.buy()` /
  `Store.restore()` succeed at once, at a fake `$1.99`.
- **The owned flag lives in `user://store.cfg`**, holding offline and across
  restarts, but re-checked against the store's real purchases on every
  launch -- except a *failed* query (offline, store unreachable) never
  clears it; only a query that succeeded and found `remove_ads` missing is a
  refund. Android acknowledges every purchase the moment it is seen,
  launch-found ones included, because Play auto-refunds an unacknowledged
  one after three days.
- **`godot-iap`'s GDExtension is iOS-only and stays `.disabled` elsewhere**
  (editor, CI, this Mac). `tools/export_ios.sh` renames it on, runs the
  plugin's `fix_ios_embed.sh` to embed its frameworks, and renames it back
  (clearing `.godot/extension_list.cfg`, which the editor would otherwise
  error on next run) whichever way the export goes. It raises the **iOS
  minimum to 17.0**, dropping iPhones stuck on iOS 16 (8 and X).
- **Both plugins run on Google's published test IDs until the user's AdMob
  account exists** (`project.godot`'s `ads/` keys, per-platform overrides).
  The AdMob app IDs are Poing's own registered *defaults* for those same
  test values, not something this project set explicitly.
- **The Android template needs AGP 8.9.1, not Godot 4.7's stock 8.6.1**:
  `godot-iap`'s `openiap-google` 3.5.2 pulls `androidx.core:core:1.18.0`,
  which refuses an older AGP. Godot only honours
  `--install-android-build-template` inside a full export, which would run
  Gradle on the unpatched template first -- so `tools/patch_android_template.sh`
  installs the template itself (Godot's own way, when
  `android/.build_version` is missing) and bumps the pinned AGP line; CI and
  `tools/deploy_android.sh` call it **instead of**
  `--install-android-build-template`, before a plain `--export-debug`. Safe
  to run twice; fails loudly if neither AGP line is found.
- **Both plugins' native libraries are committed**: `addons/admob` 17M,
  `addons/godot-iap` 27M (mostly `SwiftGodotRuntime.framework`, 21M). Each
  installer's own `bin/.gitignore` was deleted on purpose so the binaries
  ship, the same call already made for Poing's other `/bin` folders.
- **`tools/strip_dev_addons.sh` now edits a multi-plugin list**: `admob` and
  `godot-iap` stay enabled through export (their exporters run during it)
  while only `godot_mcp`'s entry and its `MCPGameBridge` autoload strip out.
- **iOS needs an app icon, not only the Team ID.** A dummy Team ID alone
  gets past the (expected) Team ID stop and fails next on "Invalid icon" --
  the project has no icon, and none of the three `launcher_icons/*` Android
  slots either.
- **Every bottom-anchored node clears the inset**, not only the two
  screens' own margins: every `ui/hud/sheet.gd` subclass re-offsets its card
  from `SafeArea.insets()` on open and on `Ads.banner_changed`, and the
  first-play card (`ui/hud/how_to_play.gd`) centres in the room above the
  inset rather than the whole screen -- Pinwheel's card (1636 tall in
  pt-BR) clears a 180 banner by 24 px and would not fit a 1080x1920 phone
  with a 180 banner plus a top inset over ~48. Height-bound boards lose
  cell size in proportion to the slot at a 180 banner (Hidden Word 1140 to
  904, Sudoku 1114 to 878, Code Break 1180 to 944) -- still playable in
  every shot, but tap size wants a phone to judge it. iOS banner height
  (points vs. pixels) is unverified on a device. See "The first screen"
  above for the grid's own page-count change.
- **The purchase sheet has three doors**: a paper "Remove ads" tab
  (`Ads.TAB_H` 56) `ui/ads/banner_host.gd` stands on the banner's top edge,
  a third header icon button, and a Remove ads row in settings (Restore
  purchases lives on the sheet itself, one tap away). The tab and the header
  icon go for good once owned; the settings row is the one door that stays,
  disabled, reading "Ads removed". `price_text()` is empty until the store
  answers, so nothing shows a price until a real product exists in Play
  Console or App Store Connect.

## Turns and the backend

A **turn** is one committed input a day, an immediate reveal and a graded
result -- never a pass or a fail. The only one, How Big?, was 3D and was
removed on 2026-09-24 with the rest of the 3D game; a future turn would be
drawn flat and would need its own host again (`legacy/ui/turn_host.gd` and
`legacy/core/turn_base.gd` are in git history).

**The live project is `daily-games-420bf`** (provisioned 2026-09-17; it
replaced `peeplet-daily`, which now holds nothing this game uses). Firestore
is a `nam5` multi-region database with the rules from `server/` released,
anonymous sign-in is on, and `core/backend.gd`'s `API_KEY` is the project's
Web app key. The project is on Blaze and the three functions are deployed in
`us-central1` (`tools/deploy_functions.sh`), with their schedules enabled and
a one-day cleanup policy on their container images. Everything below was
verified against the local emulator suite first, then against the live
project.

**The project lives in a Google Cloud organisation with the "secure by
default" policies on**, and three of them bite anything that provisions it:
no service-account keys (`iam.disableServiceAccountKeyCreation`), no members
from other domains (`iam.allowedPolicyMemberDomains`, so a navlio account
cannot own the project and billing is attached from the hypertradeworx side),
and no automatic roles for default service accounts
(`iam.automaticIamGrantsForDefaultServiceAccounts`, so a fresh project's
functions cannot even build). Two one-time scripts hold the answers and are
safe to re-run: `tools/ci_identity.sh` (keyless CI sign-in for App
Distribution) and `tools/functions_identity.sh` (build and Firestore roles
for the functions' identity) and `tools/public_invoker.sh` (the domain
restriction also rejects `allUsers`, so `firebase deploy` leaves `submitTurn`
with no invoker and every call answers 403 from Cloud Run; this overrides the
constraint on this project alone and grants the invoker). All three grant
roles or change policy, so a person runs them, not an agent session. Billing
is the navlio account `013342-E2B1D4-0E3351`.

`core/backend.gd` is the only way out of the game. It is static and woken by
`world/main.gd` alone, exactly like `Analytics` -- **unstarted means offline**,
which is how the suite and the harnesses build these screens without touching
the network, and why neither is an autoload.

- Identity is **Firebase Auth anonymous** over the Identity Toolkit REST API,
  not an install id: a security rule cannot verify an unsigned id, and the
  leaderboard is coming. It upgrades in place to a real account later.
- Reads go straight to **Firestore's REST API**; writes go to one Cloud
  Function. Every document a client reads carries a **single `json` field**,
  which is what keeps Firestore's typed values from becoming a decoder.
- There is **no percentile endpoint**: the tally ships the 101-bucket
  histogram and `Backend.percentile()` does the arithmetic on the device.
  Instant reveal, works offline, and "the number moves if you come back" is
  just a second read.
- A submit is queued to disk before it is sent and flushed on the next
  launch. The server keys on uid, day and game, so a double flush is
  harmless. Nothing waits on the network, and in particular **nothing blocks
  Lock**. `submitTurn` itself only accepts a submit dated today or yesterday
  in UTC -- yesterday stays open so the offline queue can still flush after
  the day rolls over mid-queue.
- Server lives in `server/` (Cloud Functions v2, TypeScript, Node 22).
  `tools/deploy_functions.sh` deploys the functions and the rules; it is not
  in CI yet, and it has not been run against `peeplet-daily` for the reason
  above. `server/.gdignore` keeps Godot out of `node_modules`.
- `tools/_backend_probe.gd` drives the whole path against the emulator suite
  and prints what came back. It is a harness, not a suite entry.

Running the emulator suite locally has three traps worth knowing before you
lose an hour to them. The Firestore emulator needs **JDK 21+**; the `java` on
this Mac's `PATH` is Homebrew's 17, and firebase-tools refuses to start
against it, so every emulator command runs prefixed with
`PATH="/opt/homebrew/opt/openjdk/bin:$PATH"`. The suite itself is started
`--project demo-peeplet` -- the `demo-` prefix is what forces the emulator
into fully offline mode with no real credentials touched -- which is why
`core/backend.gd` reads a `FIREBASE_PROJECT` environment override alongside
`FIREBASE_EMULATOR`, rather than hardcoding the project id it addresses.
And **`firebase functions:shell` cannot invoke a v2 `onSchedule` function** in
CLI 15.14.0: it prints "Successfully invoked function" and does nothing. To
trigger `publishDay` or `rollupTally` by hand, wrap the body in a temporary
`onRequest` function and curl it, or write to Firestore directly over the
emulator's REST API; this has already cost two implementers an afternoon
each. Against the live project, `tools/seed_turn_day.sh <game> <day> <json>`
writes one day's document the way `publishDay` would (create-only), for the
day a game ships on, which the 03:00 scheduler never reaches. How Big?'s
first two days (2026-09-17 and -18) were seeded this way.

**How Big?**, the only turn, was removed with the 3D game on 2026-09-24.
The backend, the functions and `content/how_big.json` are still in place;
whether they stay for a future flat turn is open in
`docs/roadmap-to-release.md`.

`core/locale.gd` picks between `en`, `pt` and `es` and does the number
formatting `TranslationServer` does not. The turn flow's strings are keyed
in `locale/turn.csv` (European Portuguese, unlike everything since), and
since 2026-09-23 `locale/ui.csv` (pt-BR) keys the chrome every flat board
shares -- menu, bottom bar, sheets, actions row, win screen, keyboard -- and
all of Hidden Word's and Word Trail's own text. A static Label or IconButton
holds the key itself, so Godot's auto-translate re-reads it live when the
language changes; anything formatted, drawn or measured goes through `tr()`
(`day_row.gd` re-formats on `NOTIFICATION_TRANSLATION_CHANGED`). Board
titles stay English in every language, by the user's decision. **Every
board is keyed since 2026-09-24**: the other eighteen boards' rules, tips,
refusals, win lines, share lines, the registry's `short`, `motto`, `blurb`
and worded level lines, the trays, the first-play card and the island names
under Day N live in `locale/boards.csv` (500 rows, en/pt-BR/es), beside
`ui.csv` in `project.godot`'s translation list. A board keeps its tip lines
as keys in its constants and `tr()`s them when it speaks. A count in a
sentence is a `_ONE`/`_N` pair of keys, never an English plural built in
code, because pt and es agree the verb and the gender (Mushroom Patch's
number words and Balance's fruit have per-gender keys). Registry `footer`s
stay English because nothing shows them. The pt/es rows are machine-fluent
and still want a native speaker's pass. Upper-case accented capitals turned out to be fine:
`ÁÉÍÓÚ` and `ÃÕÇÑ` both extrude cleanly at weight 700 (18,024 and 21,228
faces, in the same 3,600-5,600-faces-per-glyph range as `GUESS` at 22,356) --
the only glyphs that need the weight dropped to 550 are digits 8 and 9. That
was measured once with a throwaway probe; there is no need to re-run it for
a new accented title.

**The two word boards deal words in the player's language** (2026-09-23).
`Locale.content(path)` turns `content/hidden_word.json` into
`content/hidden_word.pt.json` when that file exists and falls back to the
English one otherwise, and both states cache per language, so a change in the
settings sheet reaches the next board dealt and never an open one. Hidden
Word plays on `Locale.fold()`ed words -- accents off, so CORAÇÃO is typed
CORACAO, the way Portuguese players already know the game -- but **Ñ is a
letter in Spanish** and gets its own key at the end of the middle row
(`KeyBoard.ROWS_ES`, ten keys, the top row's width exactly). `state.written`
keeps the accents for the reveal. The keyboard outlives the board, so
`match_locale()` re-lays it when the language changed under it. Word Trail
types nothing, so its tiles wear the accents. The pt and es lists come from
`wordfreq` (CC-BY-SA 4.0, attributed in each file's `note`), with the answers
curated by hand to the English rules; the accept lists are every five-letter
word `wordfreq` knows, folded, because being told a real word is not a word
is still the worst thing that board can do.

Roadmap: `docs/brainstorm/single-turn-roadmap.md`. Phase 0's design:
`docs/superpowers/specs/2026-09-17-single-turn-foundation-design.md`.

## CI

`.github/workflows/android.yml` runs on push to `main` (and on demand from the
Actions tab): tests, then the APK, then Firebase App Distribution. The suite
gates it -- the job stops on a non-zero failure count before anything reaches
a phone. Each run stamps `version/code` with the run number so two builds are
never the same version.

Two repo secrets feed it, and the build says so when one is missing:

- `ANDROID_DEBUG_KEYSTORE` -- base64 of `~/.android/debug.keystore`. It must
  be *that* key: Android will not install a build over one signed differently.
- `ANALYTICS_API_SECRET` -- the GA4 Measurement Protocol secret. Absent, the
  build warns and reports nothing.

App Distribution itself needs no secret. The organisation the Firebase project
sits in forbids service-account keys, so the run signs in to Google keylessly
(Workload Identity Federation): the job's `id-token` is exchanged for the
`app-distribution` service account through the `github` identity pool, and
only runs from this repository are allowed to. `tools/ci_identity.sh` is the
one-time setup on the Google side; a failed sign-in fails the job rather than
warning, because there is no longer a missing secret to excuse it.

CI gets its Android SDK path into Godot by appending to the editor settings
file that `--import` generates, rather than writing one by hand; the appended
keys win over the defaults above them.
