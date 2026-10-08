<!-- Moved verbatim from CLAUDE.md on 2026-09-29. -->

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
  one night row: ink fill, paper lettering, a sun-coloured crescent. The
  sheet itself (`ui/menu/difficulty_sheet.gd`) is drawn to the user's mock
  since 2026-09-28: a tinted card a level with a plaque (sprout, sun, cloud,
  moon), the name with a bare size beside it behind grid dots and a line of
  its own (`DIFF_LINE_*`) under it -- a worded level line takes that line's
  place -- a vista washed in from the right (`Vistas.LEVELS`) and a round
  go; Insane has a gold rim. 335-343 draw calls with it up over the menu
  (319 before). Band 3
  is a provisional generator row on every board -- the same generator, one
  step harder -- until that board's batch is mined into a bank
  (`core/insane_bank.gd`, `tools/mine_insane.gd`, `content/insane/`); a
  board then reads its bank and falls back to the row without one. Spec: `docs/superpowers/specs/2026-09-23-insane-level-design.md`.
  One provisional row misses the 194 ms gate and is accepted by ruling
  rather than weakened: Sudoku's 22-given Insane shares Hard's own 300 ms
  budget. (Binairo's Insane was the other until 2026-10-03; it is built
  live now and has no bank, `docs/agents/boards/binairo.md`.) `tools/` never reaches
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
  a hushed linen brush (`assets/sfx/ui/page.ogg`, `UiSound.page`; a paper swish until 2026-09-28, which the house marimba style made tonal), never the click:
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
  **Streak's calendar is a garden since 2026-09-28**: each week a soil
  bed (grass fringe, specks) only as long as its days, and each day a plant
  by its boards -- a sprout for one, a bud for two, a flower for three (kept)
  -- a fallen leaf on a rest day, a sun glow and ring round today, a legend
  under it; beds, plants and legend are one mesh built on repaint. The run's
  flame, number and "day streak" stand centred as one group, the rest days
  held are leaves, and the side picture narrowed to 220 so the pt list fits
  at the true 1080 width. **220** draw calls on Streak.
  **Stats' boards are paged since 2026-09-28**: four across stopped fitting
  at twenty-nine boards (a cell's lines spilled into the row under it), so
  it is two across and four down, eight a page, with the home grid's pager
  pill, a swipe and the page slide (`ui/menu/stats_tab.gd`'s `turn`). A
  cell is its banner, the title, and Solved / Best / Average as a dim label
  over a bold value, or "Not solved yet". Only the page's banners are shown:
  **347** draw calls on Stats (619 with all twenty-nine standing).
- **Horse Pen is the thirty-first card (2026-10-08).** Its picture is
  `_draw_horse()` in `ui/menu/card_art.gd`: five cells by two of the board's
  meadow built from `ui/faces/horse_parts.gd` (three bales, the wheat, a
  boulder, an apple, a stream, the pony at 1.3 of a cell so it reads), one
  mesh kept in `_horse_mesh` and rebuilt only when `_u` changes; its vista is
  the meadow at `(0.12, 0.45)`. Three rows of six cells was tried first and
  left the pony too small to read at 810x1440. Thirty-one cards at eight a
  page are four pages, the last holding seven; `_shot_menu.gd -- last`
  shoots it and read **215** draw calls there (216 on one of three runs).
- **How Big? is the thirty-second card (2026-10-08).** Its picture is
  `_draw_how_big()` in `ui/menu/card_art.gd`: the board's own card in small
  (sky over a strip of grass on a rim, because the two shapes alone were
  lost against the vista), the horse in ink with its bracket and the
  elephant in white beside it, plainly too small, with the grip on its
  corner -- `ui/faces/how_big_art.gd`'s shapes, one mesh kept in
  `_how_big_mesh`. Its vista is the sky at `(0.30, 0.50)`. Thirty-two cards
  at eight a page fill four pages; `_shot_menu.gd -- last` read **225** draw
  calls on the last.
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
