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
  the same slide. Draw calls at rest are unchanged (253 / 222). **Since 2026-10-09
  the pages beside the one up are built ahead and parked, never built or
  shown under the finger** (the user: the swipe "feels waaay too laggy, it
  doesn't feel like a scrolling responsive"). The peek page used to be
  built on the frame a drag began and freed as the turn landed: 10 ms of
  building and a 29 ms first frame on this Mac, every swipe, several times
  that on a phone. Now `_warm` builds a neighbour 0.05 s after a page
  comes to rest (the next first, then the previous; 0.9 s after the menu
  rises), the page turned away from stays built as the peek, and pages
  further than one away are freed (`_spare`). **A page out of sight is
  parked `PARK` spans to the side, shown, not hidden**: showing a hidden
  grid made every card draw again, 10-40 ms on the frame the finger first
  moved. Parked pages are culled (276 / 227 draw calls at rest on pages two
  and three, the same as hidden). Measured with real ScreenTouch drags
  through the viewport, ten swipes: the worst frame of a drag was 30-42 ms
  before and 7-8 ms after, against 6 ms at rest. Not felt on a phone yet.
  Still paid, once a page: the build itself, just after a landing. **Since 2026-10-15 every list is kept and the tabs swap, never rebuild**
  (the user: "check why menu is so laggy ... we should use the initial
  loading to load most of UI lists, so it's instant when user click").
  Measured headless on this Mac before: the first tap on Versus 156 ms in
  the call and a 212 ms frame, Arcade 175/221, Stats 157/182, and every
  later switch between Puzzles, Versus and Arcade 80-128 ms, because a tab
  freed the grid and built the next list's cards. ~440 ms of the first taps
  was compiling the 58 card faces' scripts. Now: `_load_faces` asks for
  every face script on a thread from `_ready` (`ResourceLoader.
  load_threaded_request`, polled in `_process`; boot already loads
  `main.tscn` this way); a tab parks the list it leaves in `_kept` (its
  grid, peek, spares, page and fit) and takes its own back, refreshing
  marks in place (`_refresh_cards`: done seals and rings, an Arcade best);
  `_warm`, once the page's neighbours are built, bakes the lists not yet
  shown at the fit they will have (`_measure_fit`), **a card a frame**
  (`_bake`/`_bake_step`), held under a drag or a slide and while the next
  card's face is still loading. A kept list built on another day, or whose
  ids changed, is built again on the tap. Page neighbours are baked a card
  a frame too, no longer a page in one frame. After: Versus 5/9 ms,
  Arcade 10/13, Puzzles 3/10, at the first tap and every one after; the
  idle bake's worst frames are 15-40 ms, one card each. Draw calls
  unchanged (182 Home, 151 Arcade on opengl3_angle; parked grids are
  culled). `Progress.completed_on` reads the completed marks once a page:
  `Progress.completed` opened the save file once a card (Puzzles' take was
  23 ms on that alone). **Still paid on the first visit**: Stats 46-61 ms
  and Streak 33 ms, the first layout and draw (Stats bakes a face for all
  32 boards); hidden `refresh()` does not move it, only drawing does. Not
  felt on a phone yet. A turn sounds
  a thick card slid over felt (`assets/sfx/ui/page.ogg`, `UiSound.page`; a paper swish until 2026-09-28, which the house marimba style made tonal, then a linen brush the user called "too harsh" on 2026-10-09: a rumble under 400 Hz and a hiss as loud at 6 kHz as at 3, so the new take has its body in the middle, is rolled off above 3.5 kHz and eased in over 30 ms; unheard by the user), never the click. The card under a lifting swipe is still pressed, and until 2026-10-09 it clicked: the release of a swipe calls `UiSound.hush()` from `_input`, which drops any click asked for in that frame (Stats' pages too; a touch-drag probe saw the click's player made before the fix and not after, and a plain tap still clicks):
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
- **Golden Acorn is the thirty-third card (2026-10-08).** Its picture is
  `_draw_acorn()` in `ui/menu/card_art.gd`: the board in small -- the
  question's paper with the golden acorn between two pairs of ruled lines,
  and the four plates two by two under it, the second turned leaf with its
  tick -- `ui/faces/acorn_art.gd`'s shapes, one mesh kept in `_acorn_mesh`.
  Its vista is the sky at `(0.62, 0.42)`. **Thirty-three cards at eight a
  page are five pages, the last holding this card alone**;
  `_shot_menu.gd -- last` (three turns now) read **143** draw calls there.
- **Pearl Dive is the thirty-fourth card (2026-10-09).** Its picture is
  `_draw_pearl()` in `ui/menu/card_art.gd`: the board in small -- the paper
  with the clock's bar, a prompt's two ruled lines and an answer on its line
  in the Pearl's gold, and beside it the water, light to dark, with the bell
  on its rope over the shell -- `ui/faces/pearl_art.gd`'s shapes, one mesh
  kept in `_pearl_mesh`. Its vista is the beach at `(0.28, 0.60)`, Bridges'
  own. The fifth page holds two cards now. **`_shot_menu.gd -- last` could
  not show it on 2026-10-09**: the harness reads the player's own save, and
  that day's Daily gifts sheet stood over the page; the card's picture was
  shot alone by a throwaway probe instead, and its draw calls on the page
  were not read.
- **Lattice is the thirty-fifth card (2026-10-09).** Its picture is
  `_draw_lattice()` in `ui/menu/card_art.gd`: a strip of the board, five
  cells by three with its two gaps -- `ui/faces/lattice_art.gd`'s slats,
  sockets, tiles and knots, nine tiles home and four not -- one mesh kept in
  `_lattice_mesh` with its fifteen numerals drawn over it. One gap and the
  eight tiles round it was tried first and read as too small. Its vista is
  the meadow at `(0.42, 0.30)`. The fifth page holds three cards;
  `_shot_menu.gd -- last` read **173** draw calls there.
- **Button Box is the thirty-seventh card (2026-10-11).** Its picture is
  `_draw_buttons()` in `ui/menu/card_art.gd`: a swatch of
  `ui/faces/button_art.gd`'s patches and buttons, five across and two
  down, six sewn with their cross of thread and four loose on the wrong
  patch (three by three at 38 was tried first and ran over the strip), one mesh kept in
  `_buttons_mesh`. Its vista is the meadow at `(0.58, 0.34)`.
- **Toy Train (Toy Cannons since 2026-10-13: the engine on the card is
  `train_art.gd`'s cannon now, its muzzle toward the blocks by the same
  quarter turn; not seen) is the thirty-eighth
  card (2026-10-12).** Its picture is
  `_draw_train()` in `ui/menu/card_art.gd`: a red engine with a 5 on its
  plate on a length of `ui/faces/train_art.gd`'s track, rolling up to two
  rows of four blocks, one mesh kept in `_train_mesh` (three rows of blocks
  with the engine under them were tried first and ran out of the strip).
  Its vista is the meadow at `(0.50, 0.36)`.
- **Gumdrop is the thirty-sixth card (2026-10-11)**, come over from the
  Arcade tab. Its picture is `_draw_gumdrop()` in `ui/menu/card_art.gd`: the
  tray with the flower mould on it, every cell its flavour --
  `puzzles/gumdrop_art.gd`'s own tray and picture, the picture one mesh kept
  in `_gumdrop_mesh`. Its vista is the meadow at `(0.7, 0.55)`, the one it
  had on the Arcade tab. The fifth page holds four cards;
  `tests/_shot_gumdrop.gd -- <out> tutor` turns the grid to it and read
  **178** draw calls there. The Arcade tab is ten cards again.
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

### A card of its own (2026-10-13)

The user, 2026-10-13: "let's start redesign the game cards to something
completely customized for every card game, not something default. Start with
the first one ... Card should be elegant, cozy, but carry the game elements".

- **The seam.** A registry entry that names a script under `card` hands it
  the whole paper. `ui/menu/puzzle_card_2d.gd` is the shell and keeps what
  every card does (tap, squash, done seal, SOON pill, `CARD_H`, `fit_height`);
  `ui/menu/cards/card_face.gd` is the base of a face: `_paint(b)` for
  everything still, as one mesh built at the card's size and kept until the
  next resize, `_lay()` for what lives (children through `_keep`, so a resize
  takes them and leaves the shell's seal), `seal_centre()` for where the seal
  is pinned (top right, 38 in), `ground()` for the paper inside the shell's
  line, `shade()` for a top-to-bottom gradient over vertices already taken,
  `_words()` for the sun-dotted name over the blurb. An entry without the key
  wears the template, untouched: the Versus tab's cards and the other
  thirty-seven. **A custom card costs one file under `ui/menu/cards/` and one
  registry key**; the grid's budget (490 by 246) is not the face's to move.
- **Binairo is the first** (`ui/menu/cards/binairo.gd`): a day and a night on
  one paper, a three-by-three corner of the board across the line between
  them in the board's own tiles and faces, an = between the two suns, the top
  right place left to the night sky (stars; the seal goes there) and the last
  tile the go button in the card's colour. Two moons stand beside it, so the
  tile it wants is a sun. No vista under it.
- **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440, second
  of two readings: 321 draw calls (316 before: seven idling faces where the
  template had two still ones and a plate). Suite 249797/0. A throwaway
  windowed probe laid the card at 490x246, 490x272, 620x300 and 1040x246, in
  pt, with two, four and the Insane level done: the seal sits in the sky's
  corner and the words clear the line.
- **Mine, the user's to call**: the go button as the missing tile rather
  than the round disc; no white margin round the picture; the faces idling
  (blink, turn, rock) on the menu, which the template's did not.
- **Code Break is the second** (`ui/menu/cards/codebreak.gd`, the same day,
  on "do next"): the board's box. A dark shelf across the top holds the code
  under three of the board's own lids (`codebreak2d.gd`'s `Lid._plank`), one
  seat open with the cloud looking out of it, and a pouch at the row's end
  with one filled pip and two rings; the parchment under the shelf's lip has
  the name, and the go button is a lid in the card's colour with a chevron
  where the others carry a question mark. The row has its own scale (`_ks`)
  so a taller card never runs the pouch under the seal. 313 draw calls with
  both cards on the page (321 with Binairo's alone: this face is one live
  friend and three labels where the template had three friends and a plate),
  second of two readings; suite 249797/0. Mine, the user's to call: the dark
  wood, which is the heaviest thing on the page; the cloud as the friend
  shown; a score of one and two.
- **Balance, Untangle and Shikaku are the third, fourth and fifth** (the same
  day, on "Do next 3 games at once"; three workers, one file each, then one
  windowed look at each).
  - **Balance** (`ui/menu/cards/balance.gd`): the board's meadow over the
    whole paper (sky, two hills, a cloud, a lawn with tufts and flowers) and
    the seesaw on the right, its left end down on a straw bale under a
    pumpkin, the brass level's bubble run to the high side. The go button is
    the weight the beam is missing: a round fruit in the card's colour with
    a chevron, hovering over the lit far cup. One live child, the pumpkin
    (`ui/faces/fruit.gd`). The plank, keel, level, bale and trestle are
    redrawn small from `balance2d.gd`'s builders, which are instance
    methods tied to the sim.
  - **Untangle** (`ui/menu/cards/untangle.gd`): the board's linen with a
    stitched sprig in the top left corner and a running-stitch hem, and the
    wooden hoop on the right with eight holes and three whole ropes peg to
    peg (`untangle_rope.gd`'s own `lay_knot` and `draw`): coral and blue
    wound in one knot, yellow under the coral. The go button is the coral
    rope's near peg lifted off its hole, large, in the card's colour.
    Nothing lives on it: no kitten, no idle.
  - **Shikaku** (`ui/menu/cards/shikaku.gd`): a three-by-four corner of the
    garden field down the left side, three beds tilled and fenced round
    their signs (3 in a 1x3, 4 in a 2x2, 2 in a 2x1, each the board's
    `MarkerFace` baked settled), and the bottom row the plot not yet drawn:
    a 3x1 bed in the card's colour with a chevron, its cream 3 waiting in
    it, alive. Words on the right, the mirror of Binairo. The baked signs'
    numerals are three `draw_string`s over the mesh, as the board writes
    them.
  - **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440,
    second of two readings: 235 draw calls with all five on the page (both
    readings 235). Suite 249797/0. A throwaway windowed probe laid each
    card at 490x246, 490x272, 620x300 and 1040x246 in pt with two, four and
    the Insane level done: the seal's corner is clear on all three (the
    hoop passes 5 px from it at 490x246) and the pt words fit.
  - **Mine, the user's to call**: Balance's go button hovering over a cup
    rather than standing low right, the pumpkin as the fruit shown, a lower
    hub than the board's so the weight clears the seal; Untangle's go peg
    near three times its siblings, pegs fatter than the board's so eight
    read, coral/blue/yellow, the sprig and hem; Shikaku's signposts on a
    card whose brief said no mascot (the board has them), a wide bar for a
    go button on the card's left, the blurb ink `6f6a4c`. **Seen and left**:
    Shikaku's signs are small at card size, the grin sitting close under
    each digit.
- **Tents, Light Up and One Line are the sixth, seventh and eighth** (the
  same day, the user sending the same words again; the same recipe), and
  with them every card of page one is its own.
  - **Tents** (`ui/menu/cards/tents.gd`): a misty mint wood with a line of
    far pines, the words on top, and one row of the board's meadow along the
    foot with its count chip (a cream 2): tree, pitched tent with its lamp
    lit, bare grass, the go tent, tree. The go button is the tent the second
    tree waits for, in the card's colour, a chevron for its doorway. Two
    live children, the trees (`ConiferFace`); `TentFace` and `CountChip`
    baked, the chip's numeral one `draw_string`.
  - **Light Up** (`ui/menu/cards/lightup.gd`): a dusk of its own, plum to
    rose-brown, cream ink; a walk of flagstones along the foot that turns up
    the right side, the board's `CourtLantern` at the corner (the one live
    child), the stones it sees warm, a block reading 2 beside it and the
    stones past the block cold. The go button is the stone on the block's
    other side, where its second lamp goes. No beam shafts: warm floor, halo
    and motes.
  - **One Line** (`ui/menu/cards/oneline.gd`): dew-teal paper; the stroke
    starts at a post under the name, runs the card's foot as a laid
    boardwalk and enters a figure of two stacked triangles on the right,
    four lines planked, the snail (`SnailFace`, the one live child) on the
    fifth, three still bare stone. The walk shown is a legal single stroke.
    The go button is the apex post she climbs toward.
  - **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440,
    second of two readings: 194 draw calls with eight faces on the page
    (both readings 194). Suite 249797/0. The throwaway probe again, each
    card at the four sizes, this time in es: the seal's corner is clear on
    all three and the words fit.
  - **Mine, the user's to call**: Tents' row left-aligned (on a 1040-wide
    card the right half is mist), its chip larger than the board's, the mint
    wood; Light Up's dusk colours (`46384f` to `8d6252`), a second dark card
    on the page beside Code Break's shelf, its go button bottom middle, no
    beams; One Line's teal ground, the boardwalk as the name's underline
    (800 px long on a 1040-wide card), a go post smaller than the other
    cards' go pieces and grey because the card's colour is.
- **Nonogram, Queens and Hidden Word are the ninth, tenth and eleventh**
  (the same day, the same words a third time; the same recipe), the first
  three of page two.
  - **Nonogram** (`ui/menu/cards/nonogram.gd`): a pale glaze-blue cloth, two
    daisies in its corner, and on the right a parchment tray leaning 2.5
    degrees with a heart five wide and four tall in the board's sockets and
    tiles, three sockets pebbled and one empty. The clue tabs are counted
    from the picture in code; the lines that already read right are green
    as the board washes them, and the row and the column still in ink cross
    at the empty socket. The go button is the tile that socket wants, in
    the card's colour, lifted over the tray's corner. Two spare tiles and a
    pebble lie over the tray. Nothing lives on it; nine `draw_string`s.
  - **Queens** (`ui/menu/cards/queens.gd`): the court is the paper. Four
    rows of it fill the card to its edges in five regions of `Pal.REGION`
    under the board's ink seams, anchored right and running on to the left
    for as wide as the card is; the words stand on a plain tan region top
    left. The bee is seated on her gold near the right (the one live
    child), her crosses run her row and column, two blooms stand in her
    region, and the go button is the next queen's seat: a tile in the
    card's colour, in another row, column and colour, not touching.
  - **Hidden Word** (`ui/menu/cards/hiddenword.gd`): warm parchment, the
    words top left, and three rows of the board's tiles stepping down to
    the left on the right side: BREAD and LEMON judged by a `marks()`
    function against HONEY (one amber, then three), H O N E typed on paper,
    and the fifth tile the go button. The sprout idles on a tump of the
    board's turf in the bottom left corner (the one live child). Fourteen
    letter strings.
  - **Measured**, `tests/_shot_menu.gd -- page2` on `opengl3_angle` at
    810x1440, second of two readings: 227 draw calls on page two with the
    three faces and five template cards (both readings 227; page one 194).
    Suite 249797/0. The throwaway probe, each card at the four sizes in es:
    the seal's corner is clear on all three and the words fit. Fixed from
    the first look: Hidden Word's blades and flower stood outside the paper,
    Nonogram's es blurb touched the tray (the words' room is 258 now), and
    Queens wore a cross on every cell the board would derive, twenty on a
    wide card.
  - **Mine, the user's to call**: Nonogram's picture 5x4 rather than 5x5
    (the seal's corner caps the tray), a heart, the blue cloth and a tray
    the board does not have, nothing alive; Queens' crosses on her row and
    column only and none on the tan (the board also crosses her neighbours
    and her region), the tan as the words' ground, a second card with no
    margin at all; Hidden Word's rows stepping left and not overlapping,
    the three words, no green mark shown, and **its go tile is green
    because the card's colour is, which is also the board's right-letter
    green** (true of the Y it stands for, but it reads as a mark). **Seen
    and left**: on a 1040-wide card Nonogram and Hidden Word are bare in
    the middle, as Tents is.
- **Word Trail, Mushroom Patch and Sudoku are the twelfth, thirteenth and
  fourteenth** (the same day, the same words a fourth time; the same
  recipe).
  - **Word Trail** (`ui/menu/cards/wordtrail.gd`): a peach morning with
    three fallen leaves, and a 3x3 corner of the board's field on the right
    in its paper pieces: M A P L traced right, down, right by the board's
    sun beam, the four tiles lit, and the go button the tile where the E
    lands. O A K fills the rest and the top right cell is a wall, so the two
    words and the wall fill the nine cells as a real board's do; both words
    are in `content/word_trail.json`. Nothing lives on it; seven strings.
  - **Mushroom Patch** (`ui/menu/cards/mushroom.gd`): a warm autumn floor
    with leaf litter, and the board's patch coming in from the bottom right
    corner and running off the right and bottom edges: a 1, a 2 and the go
    sod on top, a pebble, the planted mushroom (`MushroomFace`, the one live
    child) and a 2 under them, turf below. The numbers are counted in code
    from two mushrooms; the go button is the sod the top 2 proves holds the
    second.
  - **Sudoku** (`ui/menu/cards/sudoku.gd`): a sage cloth and the board's
    wooden tray as a corner: the grid's bottom row along the card's foot,
    its seventh column climbing off the top left of the seal, and the 3x3
    they share whole in the bottom right. Row, column and region each lack
    only the 7, and the cell they share is the go button. Givens in ink,
    written digits in leaf green. Nothing lives on it; up to twenty strings.
  - **Measured**, `tests/_shot_menu.gd -- page2` on `opengl3_angle` at
    810x1440, second of two readings: 185 draw calls on page two with six
    faces and two template cards (both readings 185; 227 before, page one
    194). Suite 249797/0. The throwaway probe, each card at the four sizes
    in es: the seal's corner is clear on all three and the words fit.
    Changed after the first look: Sudoku's go tile stood lifted over the 2
    above it (it sits in its cell now) and its cloth was a blush, the third
    warm paper in a row on the page.
  - **Mine, the user's to call**: Word Trail's field 3x3 rather than wider,
    MAPLE and OAK, the off-trail letters at 62% ink where the board inks
    them full; Mushroom Patch's go sod is red because the card's colour is,
    which is near the cap's red and the board's too-many colour, and it
    marks a cell that holds a mushroom rather than a safe one; its name
    ends 4 px short of the seal at 490 wide; Sudoku's crossing as a corner
    rather than a cross, cells cropped by the card's edge left without a
    digit, the sage. **Seen and left**: Hidden Word, Word Trail and
    Mushroom Patch are three warm papers together on page two.
- **Bridges, Quilt and Fairy Lights are the fifteenth, sixteenth and
  seventeenth** (the same day, the same words a fifth time; the same
  recipe). With the first two every card of page two is its own; Fairy
  Lights opens page three.
  - **Bridges** (`ui/menu/cards/bridges.gd`): a deep teal lagoon over the
    whole paper (`37889b` to `246a86`), four wave marks, cream ink, and four
    islets anchored right: three along the foot and one up the right side
    under the seal, pale shallows round each. A double run joins the first
    two and a single climbs to the upper one; the numbers are counted in
    code from the runs and the go span (2, 3, 2, 1), the two end islets met
    and green, the middle two still short. The go button is the span they
    lack: one wide plank in the card's colour with a chevron, lifted over
    its shadow. Nothing lives on it; four numeral strings.
  - **Quilt** (`ui/menu/cards/quilt.gd`): the paper is the backing, a
    heather linen (`ebe6f2` to `dad2e7`) with a chalk-dashed grid, and the
    quilt is sewn on from the right, running off the top, bottom and right
    edges, its left edge the stair the patches' own shapes make: five
    patches on a 5x6 grid in `patch_cloth.gd`'s silhouettes, prints and
    quilting stitch (plain butter under the seal, sky gingham, coral sprig,
    sage pinstripe, teal off the foot). The go button is the three-cell
    elbow its notch wants, in the card's grey, lifted over a shadow with a
    pale stitched hem and a chevron. A needle and a curl of thread lie
    bottom left. Nothing lives on it and it writes no string.
  - **Fairy Lights** (`ui/menu/cards/fairylights.gd`): a night garden (sky
    `1c3540` to lawn `2c5854`, two hedge rows along the foot), the wire in
    from the left edge and hung in swags across the top with a lit
    `LanternFace` baked under each swag (three at 490 and 620 wide, five at
    1040), its halo a soft disc and two motes, no rays. The wire drops clear
    of the seal's corner to the go button low right: a paving stone in the
    card's colour whose elbow sits a quarter turn off, with the clockwise
    arrow of the turn the board makes; a cold wire runs from it to one dark
    lantern. Words in cream under the canopy. Nothing lives on it.
  - **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440,
    second of two readings: `-- page2` 175 draw calls with eight faces on
    the page (both readings 175; 185 before), `-- page3` 205 with one face
    and seven template cards (both 205; no reading from before). Suite
    249797/0. The throwaway probe, each card at the four sizes in es: the
    seal's corner is clear on all three and the words fit. Changed after
    the first look: Bridges' islets from 25 to 30 (respaced to 156 apart, a
    row 4 px higher, the go span 25 to 29 thick) and Fairy Lights' lanterns
    from 16 to 20 (the words 4 px lower), both having read small at 490
    wide. Fairy Lights' glow stays inside the shell's line at the left edge
    and its es blurb clears the hedge and the dark lantern. Page two was
    looked at whole: the lagoon and the heather sit under the warm papers
    without a clash.
  - **Mine, the user's to call**: Bridges' four islets in an L rather than a
    wider zig-zag, the dark sea (a third dark paper after Code Break and
    Light Up, the first on page two), planks 1.4 times the board's
    thickness, islets with no flowers or pennants; Quilt's heather ground,
    the grid in chalk, the five cloths, **a grey go patch on a quilt**
    (the card's colour; it leans on its lift, hem and chevron to read as
    the piece to place), the seal sitting on the butter patch rather than
    on bare paper; Fairy Lights' wire hung in swags where the board lays it
    on stones, the cold wire paler than the board's, the dark lantern
    beside the stone rather than on the string, smiling lanterns, no stars,
    a fourth dark card. **Seen and left**: on a 1040-wide card Bridges and
    Quilt are bare in the middle, as Tents is.
- **Paper Planes, Pinwheel and Rings are the eighteenth, nineteenth and
  twentieth** (the same day, the same words a sixth time; the same recipe),
  the second, third and fourth of page three.
  - **Paper Planes** (`ui/menu/cards/planes.gd`): a pale morning sky
    (`cbe4f1` to `fdf5e4`), two flat clouds and no board frame. Three of
    `paper_plane.gd`'s darts anchored right, each on a dotted lane that runs
    the paper edge to edge: a short blue one heading down onto the go
    plane's body, a bent yellow one heading left onto the blue one's, and
    the go plane along the foot with nothing ahead, so only it may launch,
    as the board rules. The go button is that plane in the card's colour,
    larger, lifted over a shadow, three chevrons leading off the right
    edge. Nothing lives on it and it writes no string.
  - **Pinwheel** (`ui/menu/cards/pinwheel.gd`): primrose paper (`fdf7dc` to
    `f9e9ab`) with a soft rise along the foot and a toy pinwheel on a stick
    bottom left. The board's frame comes up from the foot on the right,
    five columns, 2.3 rows showing, three pieces on it in `patch_cloth.gd`'s
    coral, lilac and sky, each with its pin, leaving a three-cell elbow
    hole. The go button is that elbow in the card's colour, lifted half a
    cell and caught 24 degrees short of home about its pin, with a chevron
    and a short clockwise arrow (the board turns clockwise). Nothing lives
    on it.
  - **Rings** (`ui/menu/cards/rings.gd`): a blush plaster wall (`fbeeec` to
    `f2d5d6`) with a soft light behind the pegs, a wooden base in from the
    right edge along the foot and three pegs in the board's own ring, post
    and daisy builders: two yellow, three in the card's purple, four teal
    under the daisy cap. The go button is the fourth purple ring, larger,
    hovering over the middle post with a chevron for its emblem; the drop
    is legal under `can_drop`. Nothing lives on it.
  - **Measured**, `tests/_shot_menu.gd -- page3` on `opengl3_angle` at
    810x1440, second of two readings: 190 draw calls on page three with
    four faces and four template cards (both readings 190; 205 before).
    Suite 249797/0. The throwaway probe, each card at the four sizes in es,
    then the two small sizes in pt, and page three whole in en. **es is not
    always the longest locale**: Pinwheel's en and pt blurbs outrun its es
    one, and the en one touched the frame's corner on the page, which the
    es probe had passed. Changed after the looks: Pinwheel's frame from
    2.72 rows showing to 2.3; Paper Planes' lanes lay no dot under the
    words (`WORDS_CLEAR`), the left-heading lane having run through the
    blurb.
  - **Mine, the user's to call**: Paper Planes' three planes rather than
    four, chevrons as the go mark, lane dots 1.3 times the board's, a lane
    that stops at the words; Pinwheel's toy pinwheel (the board has none),
    the three cloths, the go piece overlapping the sky piece's corner, only
    2.3 rows of the frame; Rings' low peg on the left and the full one
    under the seal (the brief had them the other way; the blurb wanted the
    room), yellow and teal as the other colours, a plain base, the go ring
    passing 14 px from the seal at 490 wide. **Seen and left**: on a
    1040-wide card all three are bare in the middle, as Tents is.
- **Caterpillar, Sunbeam and Knight are the twenty-first, twenty-second and
  twenty-third** (the same day, the same words a seventh time; the same
  recipe), the fifth, sixth and seventh of page three.
  - **Caterpillar** (`ui/menu/cards/caterpillar.gd`): a mint lawn (`eaf6e6`
    to `cfe9cd`) and no frame. The body is `ui/faces/caterpillar.gd`'s own
    `body` and `head`: tail tip low on the left, along the foot, up the
    right side and back left under the seal, the head facing left, with the
    board's squares laid only under and beside it. Leaf 2 with its badge
    lies two squares ahead. The go button is the square ahead of the head,
    in the card's red, lifted, its chevron pointing left, the way she
    crawls. On a wider card the tail runs further along the foot. One
    numeral string; nothing lives on it.
  - **Sunbeam** (`ui/menu/cards/sunbeam.gd`): a lilac-to-apricot dawn
    (`ebe2f5` to `fbe2cc`), no floor or frame. The board's window and sun
    low left; the beam runs the foot, lights a drop, steps up at two brass
    mirrors on their two-peg rails, lights a second drop and stops in a
    potted fern, with the bud above fed but shut and a faint beam to it.
    The go button is the third mirror, one peg down its rail, mounted in
    the card's blue, lifted, a chevron up the rail to a ringed peg. Five
    motes; nothing lives on it and it writes no string.
  - **Knight** (`ui/menu/cards/knight.gd`): an oat linen (`f6efe1` to
    `ead9bf`) with a pale pool behind the path, and only the squares of two
    hops laid as stepping stones in the board's sage and paper tones: two
    right and one up, twice, seven squares at 52 px. The cream knight at
    the low left end, the rose king at the top right under the seal, the
    board's hoofprints along the first L. The go button is the first hop's
    landing square in the card's mustard, lifted, with a chevron. Nothing
    lives on it and it writes no string.
  - **Measured**, `tests/_shot_menu.gd -- page3` on `opengl3_angle` at
    810x1440, second of two readings: 175 draw calls on page three with
    seven faces and one template card (both readings 175; 190 before).
    Suite 249797/0. The throwaway probe, each card at the four sizes in es
    (the longest or within a character of it on all three), and page three
    whole in en. Changed after the looks: Knight's squares from 46 to 52,
    their shadow from 0.15 to 0.22, the stair 7 px lower so the crown
    clears the seal, and its linen lightened from `ece2ce`/`dccdb3`, which
    read muddy on the page.
  - **Mine, the user's to call**: Caterpillar's chevron pointing left where
    every other card's points right, the leaf beyond the go square rather
    than on it, the tail tip inside the left edge, no hedges or clovers;
    Sunbeam's window and sun as the source, the fern as the beam's stop,
    rails under all three mirrors, the chevron on the rail rather than the
    piece, and a picture with more small parts than its neighbours';
    Knight's hoofprints where the brief asked for a dashed arc (the board
    has none), no mark on the second hop, stepping stones rather than a
    board. **Seen and left**: on a 1040-wide card Sunbeam's first leg is a
    600 px beam and Knight is bare in the middle.
- **Hedgehogs, Super Slider and Marigold are the twenty-fourth,
  twenty-fifth and twenty-sixth** (the same day, the same words an eighth
  time; the same recipe). With Hedgehogs every card of page three is its
  own; the other two open page four.
  - **Hedgehogs** (`ui/menu/cards/hedgehogs.gd`): a leaf-green lawn
    (`eaf3d8` to `d3e5b5`), three fallen leaves and no grid, so it does not
    compose like Mushroom Patch, its cousin on page two. One big pile of
    `leaf_pile.gd`'s leaves on the right with the board's flag in it and
    the hedgehog asleep at its foot (`HedgehogFace`, SLEEPY, the one live
    face; a second small child lays two leaves over its back). Left of it
    two raked patches stacked, each reading 1, counted in code from where
    she lies, and one pile they prove safe. The go button is the rake over
    that pile: a wooden handle and a head in the card's grey with the
    chevron. Two numeral strings.
  - **Super Slider** (`ui/menu/cards/slider.gd`): the paper is the tray's
    floor, a light birch (`f8f0de` to `eddfc2`), and the card a close crop
    of the board at its gate: four columns against the right at 58 px, the
    walnut wall along the whole foot with its doors ajar and the mat lit
    under columns one and two. The red block, baked with its happy face,
    stands one step above the mat; a blue bar and a yellow square stand by.
    The go button is the square under the red one, in the card's teal,
    lifted, its chevron pointing right into an empty hollow; the position
    is checked legal in code (`_legal`). Nothing lives on it.
  - **Marigold** (`ui/menu/cards/marigold.gd`): the board's dusk kept light,
    a lilac-to-peach sky (`e6e2f7` to `fbe8dc`) over one soft range, the
    pond and a green bank along the foot. The sun stands left of the seal
    with its spout down the aim; the board's dotted guide glances off a
    violet and a bluebell, both open, and comes down into the pot. Two
    marigolds are still shut on the pond. The bounces are true mirrors
    worked out in code from `AIM`. The go button is the pot on the bank in
    the card's terracotta, lifted, a chevron on its belly and the seed over
    its mouth. **On the board the sun shoots and the pot catches**, so the
    guide ends in the go button rather than leaving it. Nothing lives on
    it and it writes no string.
  - **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440,
    second of two readings: `-- page3` 171 draw calls with eight faces
    (both readings 171; 175 before), `-- page4` 212 with two faces and six
    template cards (both 212; no reading from before). `page4` is new in
    the harness: one turn more than `page3`. Suite 249797/0. The throwaway
    probe, each card at the four sizes in es (Super Slider's pt blurb is a
    character longer and was not probed), then pages three and four whole
    in en. Changed after the first look: Marigold's whole shot turned 20
    degrees about the sun (`AIM` 122.5 to 102.5), its violet having sat on
    the es blurb, and its shut buds moved left of the pot; Super Slider's
    cell from 62 to 58, the red block having stood 4 px from the seal;
    Hedgehogs' pile, hedgehog and flag up by an eighth. Marigold's shut
    buds were moved after the last probe: their place was seen only on
    page four in en.
  - **Mine, the user's to call**: Hedgehogs' rake as the go button (a grey
    pile would read as a stone), the hedgehog in front of her pile rather
    than under it, two counts rather than three, a picture that does not
    grow on a taller card (its scale is the lesser of height and width);
    Super Slider's blocker a square rather than a bar, no block cropped by
    the card's edge, the wall running the full foot as a thin rail, teal
    beside the board's blue bar; Marigold's guide ending in the go button,
    four flowers, both marigolds left shut and away from the shot, a baked
    sun. **Seen and left**: on a 1040-wide card all three are bare in the
    middle; Marigold's two bounces sit close together at 490 wide. One
    `page4` run printed a JSON parse error from `core/backend.gd`'s
    `_refresh`; the other run and the suite did not.
- **Pixel Garden, Drumbeat and Trestle are the twenty-seventh,
  twenty-eighth and twenty-ninth** (the same day, on "do the missing games
  card renew 3 at time": the last twelve in four batches, the same recipe).
  - **Pixel Garden** (`ui/menu/cards/pixelgarden.gd`): an aqua craft mat
    (`e6f5f2` to `cfe9e5`) with a faint cutting grid, and the whole 7x7
    pegboard straight in its wooden tray low right, a rose tulip half made
    on it in `bead.gd`'s beads with green leaves, the stem's top peg bare
    and lit. The go button is the bead that peg wants, in the card's sage,
    2.5 beads across, lifted left of the tray, a dotted hop to its peg.
    Three loose beads and the baked iron lie on the mat. Nothing lives on
    it.
  - **Drumbeat** (`ui/menu/cards/drumbeat.gd`): a warm apricot evening
    (`fdf0de` to `f8d9b6`) with two soft glows. The board's road comes in
    from the right edge and ends round at the ring, three berries on it,
    the red one in the ring, the others' marks on the strip below; the hand
    drum and the tongue drum stand along the foot. The go button is the big
    drum under the ring in the card's lavender, lifted, a chevron on its
    belly. **The road runs right to left into one ring**, not down toward
    the viewer as the brief had it. One mesh, nothing live.
  - **Trestle** (`ui/menu/cards/trestle.gd`): a sandstone morning (`fbf1e2`
    to `f3e2c9`), two cliffs along the foot and pale water between. The
    bridge is four lengths of road pin to pin and six wooden members in
    `trestle_parts.gd`'s own builders, with no top chord, its two upper
    joints ringed. The cart waits at the left lip with a pear aboard (the
    one live child). The go button is the missing top chord in the card's
    rose, thick, lifted and leaning, with a chevron.
  - **Measured**, `tests/_shot_menu.gd -- page4` on `opengl3_angle` at
    810x1440, second of two readings: 183 draw calls with five faces and
    three template cards (both readings 183; 212 before). Suite 249797/0.
    The throwaway probe, each card at the four sizes in es, and page four
    whole in en. Changed after the first look: Trestle's lattice step from
    40 to 48 and its deck 10 px lower, the bridge having read small.
  - **Mine, the user's to call**: Pixel Garden's tulip, the grid on the
    mat, the dotted hop, the iron under the blurb; Drumbeat's dark road
    (lighter than the board's, still the heaviest thing on the card), no
    critter, side drums smaller than the go drum by a third, a picture that
    does not grow on a taller card; Trestle's top chord as the missing
    member, the pear as the rider, a cart that is small beside the bridge.
    **Seen and left**: on a 1040-wide card all three are bare in the
    middle.
- **Mini Golf, Horse Pen and How Big? are the thirtieth, thirty-first and
  thirty-second** (the same day, the second of the four batches), and with
  them every card of page four is its own.
  - **Mini Golf** (`ui/menu/cards/minigolf.gd`): the green is the paper, a
    light felt (`e4f3d5` to `cbe7b6`) with two mown pools. One bent kerb
    runs the foot and up the right side with a sand patch in its elbow;
    the cup and flag stand under the seal's corner and a bumper post on
    the straight line to it. The dotted aim banks off the foot kerb into
    the cup, the mirror worked out in code. The go button is the ball in
    the card's sky blue, radius 26, lifted, a chevron along the aim and
    the board's pull-back mark behind it. Nothing lives on it.
  - **Horse Pen** (`ui/menu/cards/horse.gd`): a pale sky over two soft
    rises of meadow and a free-standing 4x3 patch low right: a stream
    along its bottom row, two hay bales above and one to the left, the
    baked pony across the two penned cells in its wheat, facing the lit
    open cell. The go button is the bale that shuts it, in the card's
    mustard, larger, lifted, with a chevron; the pen is checked in code.
    **The board pens with hay bales and water is a wall**; the brief had
    fence panels. The plain bales are washed toward cream so the mustard
    one reads.
  - **How Big?** (`ui/menu/cards/how_big.gd`): periwinkle paper (`efeefa`
    to `dedcf2`) and one ground line. The known thing is a person in ink
    with the board's bracket; the answer is a white elephant in an ink
    outline at 0.76 of its true size, a faint line round it at the size it
    must reach (to scale, 1.65 m to 3.2 m). The go button is the board's
    grip on the answer's top left corner, in the card's grey, radius 25,
    lifted, its chevron up and left along the pull. **The board's Lock is
    a worded button in the actions row**, so the grip is the go piece.
    Nothing lives on it.
  - **Measured**, `tests/_shot_menu.gd -- page4` on `opengl3_angle` at
    810x1440, second of two readings: 168 draw calls with eight faces
    (both readings 168; 183 before). Suite 249797/0. The throwaway probe,
    each card at the four sizes in es, and page four whole in en (the
    longest for Mini Golf and How Big?). Nothing changed after the look.
  - **Mine, the user's to call**: Mini Golf's ball as the go button and
    blue where the board's is white, a 15 px pull-back, one kerb rather
    than a course; Horse Pen's pale bales, no apple or boulder, the pony
    overlapping the far bales, the top bale 7 px under the seal at 490
    wide; How Big?'s person and elephant, the faint true-size line (the
    board shows none mid-guess), a chevron pointing up-left, no height
    rule. All three cap their scale by width, so a taller card draws the
    same picture. **Seen and left**: bare in the middle at 1040 wide.
- **Golden Acorn, Pearl Dive and Lattice are the thirty-third,
  thirty-fourth and thirty-fifth** (the same day, the third of the four
  batches), the first three of page five.
  - **Golden Acorn** (`ui/menu/cards/acorn.gd`): golden parchment (`fdf5dc`
    to `f8e6b4`), an oak and a maple leaf bottom left, and the board's four
    answer plates stacked against the right, lettered A to D on their
    discs with two blank lines each where the day's words would be. The
    golden acorn stands left of the stack in a soft glow with three motes,
    baked: **on this board the acorn is a prize and a mark, not a
    character**. The go button is plate C in the card's teal, a little
    larger, lifted and slid left, a chevron at its far end. Four letter
    strings; nothing lives on it.
  - **Pearl Dive** (`ui/menu/cards/pearl.gd`): the sea in section, a pale
    sky strip, the waterline between the name and the blurb, water from
    `d6eff2` to `9fd0dc` and a sandy bed with one slow dune. A rope hangs
    from a float on the waterline with two of the board's pips beside it,
    four bubbles, and the pearl in its shell on the bed low right. The go
    button is the board's diving bell, redrawn in the card's terracotta,
    lifted, a chevron pointing down where its window was. No answer is
    shown. Nothing lives on it.
  - **Lattice** (`ui/menu/cards/lattice.gd`): slate paper (`eef2f9` to
    `dde5f1`) and four rows of the 5x5 lattice against the right and foot
    in `lattice_art.gd`'s slats, sockets and tiles, the top row left off
    for the seal. **The tiles carry numbers 1 to 5 and the board's home
    mark is leaf green**, so the go button is not a tile: every tile is
    home but a 4 over a 3 in column four, sun-rimmed, and the go button is
    a round token in the card's sage between them with an up and a down
    arrow. The trade is checked in code to finish both rows
    (`_swap_finishes`); the three knots' sums are counted. Nineteen
    numeral strings.
  - **Measured**, `tests/_shot_menu.gd -- last` on `opengl3_angle` at
    810x1440, second of two readings: 178 draw calls on page five with
    three faces and three template cards (179 on the first; no reading
    from before). Suite 249797/0. The throwaway probe, each card at the
    four sizes in es, and page five whole in en. Changed after the first
    look: Pearl Dive's bell from radius 31 to 36 and its pearl from 19 to
    25, the picture having read small and bare; Lattice's `WORDS_END` from
    252 to 274, its left column having touched the es blurb.
  - **Mine, the user's to call**: Golden Acorn's plate C as the chosen one,
    the go plate covering part of the acorn, no ladder pips; Pearl Dive's
    waterline crossing between name and blurb, the bell as the go button,
    a cream and gold float, no depth scale and no answer slip, a card that
    is mostly water; Lattice's token with two arrows and no chevron (the
    only go button without one), a sage token on a board of green tiles,
    the top row dropped. **Seen and left**: bare in the middle at 1040
    wide; Lattice's top right tile clears the seal by about 4 px at 490.
- **Gumdrop, Button Box and Toy Cannons are the thirty-sixth,
  thirty-seventh and thirty-eighth** (the same day, the last of the four
  batches). **Every card of the Puzzles tab is its own now**; the template
  is left to the Versus tab.
  - **Gumdrop** (`ui/menu/cards/gumdrop.gd`): candy-pink paper (`fdeff1`
    to `f8dbe2`) and the board's dark tray low right with the cupcake
    jelly on it, its cup blueberry, its cherry poured and its icing still
    clear. Left of the tray the board's taped card shows it wanted, the
    icing in the card's lavender. The go button is the pot under that
    card: a glass jar of lavender syrup, lifted, with a chevron. **The
    board's syrup is a shader fluid**, so what is poured is a flat tint
    here. Nothing lives on it.
  - **Button Box** (`ui/menu/cards/buttons.gd`): warm linen (`fbf4e7` to
    `f1e3cd`) with one stitched hem, and a 5x5 toadstool inside the
    board's stitched border low right, its cap in the card's rose, nearly
    all sewn. A tan button lies loose on the yellow spot, the stem's foot
    is bare, a yellow button waits in a three-place tin, and one cap patch
    is bare and lit. The go button is the rose button, 54 px, lifted, a
    chevron in its dish and a dotted hop to that patch. **The board has no
    sorted stacks**: the tin is a tray of hollows. The sewn squares are
    drawn as the board draws a small picture seen close, the patch and the
    whole button with thread through its holes (`Art.button`), not as the
    flat square a big picture wears. Nothing lives on it.
  - **Toy Cannons** (`ui/menu/cards/train.gd`): a mint floor (`e9f6ee` to
    `d3ecdf`), a 4x4 mat of the board's blocks at 30 px low right, the
    track along the foot and up the right side. A rose cannon at the foot
    has popped two blocks and has a cork in flight to the next rose one; a
    yellow cannon stands up the side. The go button is a 60 px cannon in
    the card's sky blue, lifted out of a wooden tray where a green one
    still waits, two blue blocks nearest the foot for it. Nothing lives on
    it.
  - **Measured**, `tests/_shot_menu.gd -- last` on `opengl3_angle` at
    810x1440, second of two readings: 162 draw calls on page five with six
    faces (161 on the first; 178 before). Suite 249797/0. The throwaway
    probe, each card at the four sizes in es, and page five whole in en.
    Changed after the looks: Button Box's sewn squares from flat colour to
    whole buttons, the toadstool having read as a red blob with no button
    in it, and its square from 33 to 31, the stitched border having run
    under the seal (that last change was seen on the probe only).
  - **Mine, the user's to call**: Gumdrop's dark tray, the heaviest thing
    on the page, grape shown as the card's lavender, a jar and no dropper,
    the pot 2 px under the taped card; Button Box's toadstool, whole
    buttons where the board would show flat squares at this size, the
    border meeting the seal's foot at 490 wide; Toy Cannons' open L of
    track rather than the loop, a chevron pointing up along the muzzle, no
    number plates on the cannons, blocks at 30 px.
  - **A JSON parse error from `core/backend.gd`'s `_refresh`** was printed
    by one run of the two in four of the day's five pairs of page-four and
    page-five shots; the suite never printed it. Left alone.
- **The other tabs wear faces too** (the same day, on "do the same redesign
  to all cards from others tabs, also make sure they use the same style ...
  arcade i think has a totally wrong button to scroll list instead of
  reusing the right one from main list"). Twenty-one workers, one file
  each, then a windowed look at every card and at each tab whole.
  - **One grid.** The user, an hour on: "why slide is not working to
    scroll on arcade (just like puzzles), as I told you, it should be the
    exactly same component, just with different games". The first pass
    had shared only the pill. Now `ui/menu.gd`'s grid serves three lists
    (`_deck`: "home", "versus", "arcade"; `_source()` is the registry or
    the tab's `entries()`), so the swipe, the drag that follows the
    finger, the slide, the peek and spare pages, the fit and the pager in
    the seam over the bar are the Puzzles tab's own on all three. Only the
    row over the grid changes (`_top_row()`): the day row, the Versus
    tab's Friends row, the Arcade tab's gold strip. Each list keeps the
    page it was left on (`_deck_page`). `versus_tab.gd` and
    `arcade_tab.gd` are that row and the list now (194 and 124 lines);
    a card still opens through the tab's `open` / `play` signal, and a
    swipe that starts on a card does not open it. Proved with a touch
    drag in a throwaway harness: Arcade turned from page 0 to 1 and
    Puzzles came back on the page it was left on.
  - **One pager.** `ui/menu/pager_pill.gd` is the prev, dots, next pill,
    lifted out of `ui/menu.gd`; the grid owns one and the Stats tab
    another (`show_page`, `turned`). The Arcade tab's two chevrons and
    "1/2" beside the Shop button are gone. Stats' dots were 12 px and are
    the grid's 14 now.
  - **The base says a line.** `card_face.gd`'s `say(text, leaf)` puts a
    line where the blurb stands (`puzzle_card_2d.gd` forwards it and keeps
    it until the face is built); a said line, and a blurb with no break of
    its own, wraps to the words' column. `leaf` draws the boosters' leaf
    after the first line. The members are `_line_said` and `_line_leaf`:
    `_said` and `_leaf` were taken by Hidden Word, Shikaku, Bridges and
    Caterpillar, which parse-failed for the minutes the first names stood.
  - **Versus** (`ui/menu/cards/vs_<game>.gd`, eight): the tab already used
    the shell, so each card only gained its `card` key and the banner code
    (six `_*_banner`s, two lineups) left `versus_tab.gd`. Snooker: the
    baize is the paper, a corner pocket, a red beside it, three colours
    beyond, the cue low from the left with a teal sleeve as the go button.
    Chess: lilac marble and the board's top right corner with a back-rank
    mate checked through `chess_rules.gd`, the go button the terracotta
    rook. Checkers: five loose dark squares climbing to a crown, two rose
    men to hop, the go button our man in sage. Air Hockey: the ice is the
    paper, the goal cut into the right edge, the go button our mallet in
    lavender. Toy Boats: a pale tub, a 4x3 patch with a boat two thirds
    found, the go button a rose peg over its last square. Penny Drop: a
    butter ground and a 4x3 piece of the rack, three of ours along the
    floor, the go button the fourth penny in sky blue. Dominoes: a blush
    cloth, a line of three tiles turning a corner, the go button a mustard
    two-four at its open end. Reversi: mint felt, one strip of five cells
    with a run mid-flip, the go button a grey disc over the ringed cell.
  - **Arcade** (`ui/menu/cards/arc_<game>.gd`, thirteen): the tab is
    rebuilt on the shell. The whole card is the tap; the Play button, the
    long blurb, the one-a-row layout and the four compaction levels are
    gone; two a row, eight a page. Under the name a card says its best
    and how far (`arcade_tab.line(game)`, which
    `tests/_shot_nightlight.gd` now reads). Colours are `Pal.CAT` by index, where every Play button was
    gold. The thirteen banner classes left `arcade_tab.gd` (876 lines to
    236). Firefly and Nightlight are night cards in cream ink; the rest
    are light. The go buttons: Firefly's firefly, Molehill's mallet,
    Stackwood's falling 512, Lucky Thirteen's last 6 of a chain, Posy's
    third flower, Peapod's pod, Nightlight's star, Beeline's stone
    tap-pad, Deckchair's 6 of hearts, Eddy's eye, Furrow's seed packet,
    Griddle's tray on the pass, Trivet's rose stack.
    **Tally's** (2026-10-15, `ui/menu/cards/arc_tally.gd`, the fourteenth
    Arcade card, on the second page) is a corner of the game's squared
    paper ruled over the whole face: a dig on a 1, two 1s riding a walnut
    belt into an adder facing up, a 2 on the square of belt above it, and a
    printed 2 in pencil. Its go button is the counting box in the card's
    colour with a cream panel saying the 2 it asks for and a chevron; the
    pieces are `arcade/tally_art.gd`'s own meshes laid by a transform, the
    numerals draw_strings over the one mesh. Seen once on `opengl3_angle`
    (`tests/_shot_menu.gd -- arcade turn`: the tab's second page 142 draw
    calls idle, 182 at most).
  - **Stats** cells are the boards' own faces over the whole cell, saying
    "Solved 3 · Best 0:41 / Average 1:02" (or not solved yet) where the
    card says its blurb; the plate, `CardArt` and the drawn figures left
    `stats_tab.gd`. The seal is in the face's corner, 38 in.
  - **Measured**, `tests/_shot_menu.gd` on `opengl3_angle` at 810x1440,
    second of two readings (the harness takes `arcade`, `arcade turn` and
    `versus` now): Arcade 166 draw calls (290 before), its second page 140
    (193), Versus 128 (232), Stats 300 (426), the Puzzles grid 194
    (unchanged). Suite 249797/0. The probe: every new card at the four
    sizes in pt or es, the Arcade ones with a three-line line and the
    leaf.
  - **Workers who followed the game over the brief**: Furrow's field is
    isometric lots now (the card uses the side-view beds its seed cards
    keep), Griddle's stand is seen from above and the press is the pass
    (the card's front view is its own).
  - **Mine, the user's to call**: card colours on Arcade in place of gold;
    no Play word and no long blurb there; the leaf kept as a mark after
    the score; Stats figures as two lines of words where they were three
    columns; Furrow's beds enlarged by an eighth after the look. **Seen
    and left**: Eddy's pt line ("Maior redemoinho: nível 7") wraps to four
    lines and meets the duckling; Penny Drop's go penny stands close after
    its name; Lucky Thirteen's column is wide enough for a long line to
    reach the chain; `tests/_shot_friends.gd` reads `versus_tab._blurbs`,
    which that tab did not have before this either.
- **Owed**: the Streak tab's Today row still wears the old picture
  (`CardArt` + `Vistas.card_plate`), and `ui/menu/card_art.gd` now serves
  only it and the template; Balance, Untangle and Shikaku in es; the
  `ARC_*_BLURB` strings are unused; the user's eye on all fifty-nine
  faces; a phone.

### The categories replace the bottom bar (2026-10-13)

The user: "Remove the bottom nav, instead add the categories before the game
list as daily - multiplayer (or a better name) - arcades". Asked, they chose
Factory as a card inside Arcade, Stats from inside Streak, and Versus as the
middle word; the first chip stays **Puzzles** (the wordmark over it already
says Daily).

- **The row is the bar** (`ui/menu/category_row.gd`, `bottom_bar.gd` moved
  and cut): three chips, icon beside the word, the gold pill on the one that
  is up; the end sprigs and the dot are gone. It keeps `picked`, `show_tab`
  and `_tabs`, and `ui/menu.gd` still calls it `bar`. It is the column's
  second row: header, categories, the list's own row (day row, Friends row,
  gold strip), cards, the pager's seam.
- **The budget is the same 1040** at 1080x1920: the row is 88 where the bar
  was 120 and the 32 went to `PAGER_SEAM` (52), now the last row of the
  column with the pill in it (`PAGER_MID` = margin + half the seam). Four
  rows of 246 still fit. The toast lies over the seam on a paper plate of
  its own (`TOAST_OVER`); it had the bar under it before.
- **Streak and Stats**: the calendar and the day row's chevron open Streak
  as before; Streak's card has a Stats button in its top right corner
  (`open_stats`), the only door to Stats. The row stays up over both with
  nothing lit and a tap on a chip leaves. Android back: Stats to Streak,
  Streak to Puzzles.
- **Factory** is the fourteenth Arcade card (`ui/menu/cards/arc_factory.gd`,
  its line the coins held); see `docs/agents/factory.md`.
- Measured on `opengl3_angle` at 810x1440, one run: **179** draw calls on
  Puzzles, **151** on Arcade page one and 129 on page two, 214 on Streak,
  283 on Stats. A throwaway harness drove chip, page turn, Factory open and
  close, calendar, the Stats button and both backs: 9/9.
- **Mine, the user's to call**: the chip's icon beside the word rather than
  over it; the Stats button's place on the streak card (it stands over the
  top of the signpost picture); Factory's card drawing; the toast's plate.
- **Owed**: a phone; pt and es at the row's width were not looked at.

- **Themed vistas** (2026-10-17): on a themed day the difficulty sheet's four
  rows and the day card take the day's own paintings (`Vistas.level_row`,
  `THEMED_LEVEL`, `THEMED_DAY`; core/themed_vistas.gd), the bundled six
  otherwise. Spec: `docs/superpowers/specs/2026-10-17-themed-vistas-design.md`.

## The grid re-sorted by popularity (2026-10-20)

The user: "check on web what are the top rating games we have, and reorder
the lists so the best ones come first". Read as popularity of the genre each
board follows (downloads, store chart places), since the app has no store
ratings of its own yet. `Registry.PUZZLES` now runs, best first:

1. Hidden Word, Sudoku -- the most-played daily game and the evergreen.
2. Rings (sort: Sensor Tower's record 166M sort downloads in April 2026),
   Paper Planes (arrows: 100M+, #2 free US puzzle, the H1 2026 trend),
   Quilt (block fit: the #2 download of H1 2026), Jewel Box (#8 free US
   puzzle, 4.9).
3. Queens (83% of LinkedIn's surveyed players' favourite), Nonogram (50M+
   for the leading app), Super Slider (the sliding-block leader 50M+, "100M"),
   Hedgehogs, Word Trail, Toy Cannons, Yarn Hoop, Golden Acorn.
4. Caterpillar, Binairo, Mini Golf, Fairy Lights, Untangle, Bridges, Pixel
   Garden, Lattice, Gumdrop, Light Up, Shikaku.
5. No store data found, or niche: How Big?, Horse Pen, Pearl Dive, Knight,
   Pinwheel, Sunbeam, Trestle (the bridge builder sold ~0.7M on PC),
   Drumbeat.

**A card's colour comes off its index, so every card recoloured** (as on
2026-10-13). Tests that meant Binairo by `PUZZLES[0]` now ask
`Registry.find("binairo")`.
