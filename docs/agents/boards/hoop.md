# Yarn Hoop

- **Yarn Hoop is the thirty-ninth card** (2026-10-14, `puzzles/hoop2d.gd`,
  `puzzles/hoop_state.gd`, `ui/hud/hoop_tutorial_diagram.gd`,
  `ui/menu/cards/hoop.gd`; no spec and no concept tab -- asked for from two
  screenshots and built in one sitting, "Build end to end ... Do it
  autonomous"). The web game it follows is Rope Stitch Puzzle, and **that
  name goes nowhere else**: not in code, comments, commits or on screen.
  The puzzle id is `hoop` and the locale prefix `YH_`.
- **The rules, as the screenshots showed** (the game's page says only that
  you connect points with a rope and the shapes form a hidden picture):
  a low-poly picture is hidden on linen, only its corners showing as pins;
  the number written in each unfilled panel says how many corners it has
  (the screenshots' 3s and 4s). Drag a thread from pin to pin: it is taken
  only along a panel's side, refused (rose ring, `locked`) between pins
  that share none. A panel whose every side is threaded knits in, in its
  colour. A pin with nothing left to thread pops off. The pill reads panels
  filled of all, as the screenshots' 5/54.
- **The magnet** (2026-10-14, the user: "some helper to help user when
  clicking near the dot to avoid miss click by requiring something too
  accurate"): a tap, or a drag let go, takes the nearest standing pin out
  to `_reach` (0.8 of the shortest side, 24-78 px) when it is clearly the
  nearest, `REACH_CLEAR` 1.35 times nearer than the next; within the snap
  it is taken either way. **With a thread in hand** (2026-10-15, the user:
  players "have to click exactly on the dot to connect after clicking on
  the start point") only the pins a side joins to the pin held compete
  (`_target_at`): a tap off every pin takes the nearest of those when the
  finger is nearer it than the pin held and no farther from it than the
  pin held is (or within the reach), however many other pins lie about
  it and however far apart the two are (the reach alone, 0.8 of the
  board's shortest side, was 30 px on a Medium board whose pins lie 96 px
  apart, and a tap 60% of the way to the next pin missed: a throwaway
  headless probe pressing off the pins found it; the probe and `_win.gd`
  press pins dead centre and never would); a tap on a pin is that pin
  (refused if no side joins it, which puts the thread down, as the
  chain's rules say). A drag let go goes the same way. A drag on its way takes only a pin it passes
  within `PASS_SHARE` 0.6 of the snap (three pins all but in a line, and a
  straight drag to the far one was taken by the middle one at the full
  snap: `_win.gd` found it). A drag let go near a pin takes it only along
  a side from the pin held (`_reached`), never as a refusal. A pale halo
  on the pin the finger would take shows while it is down.
- **The tap chain** (the same day: "keeping the line drawing till there is
  an error or maybe a double click on the previous dot, so user can click
  once into start point and keep clicking on the next one"): a tap on a
  pin takes the thread up (as before); a tap on another lays the thread
  along their side and the thread stays in hand there (`_chain`), on and
  on, and the panels closed count as one combo until it is put down. Put
  down by: a tap on the pin held, a tap on bare linen, or a tap no side
  allows (the refusal still counts). A drag from a fresh press still puts
  the thread down when let go. `YH_RULES_TAP`, and a fourth tutorial page
  (`Lesson.TAP`: taps 3, 4, 1, 3, 0, 1, then a tap on 1 to put it down).
- **The numerals** (2026-10-14, the user: "make the numbers clear (instead
  of just dots, write the number)"; they were dots at first, a numeral a
  panel through draw_string being a draw call a panel): a 3 and a 4 as
  strokes of grey yarn (`GLYPH_FOUR`, two bows for the 3) baked into the
  one marks mesh, so they cost nothing. Each sits at its panel's centre
  of area (`_mark_at`; a triangle's incentre until the user, 2026-10-14
  evening: "the number should always stay at the center of the region
  it's indicating"), sized to the room about that point (`MARK_ROOM`
  0.9 x the nearest side's distance, `MARK_H` 3.5-5.5 px seen whole, a
  stroke never under `MARK_STROKE` 0.8 px; they were 10-22, then 7-13
  until the user, with the reference's screen where the numerals are
  specks beside the dots, asked that they "be really small to be properly
  seeing on zoom in, to avoid making the screen polluted like it's today",
  2026-10-14 evening) so a thin panel's never spills; a cramped panel's
  may touch its sides, but every panel says its count. They scale with
  the zoom (the marks mesh is drawn under `zoom.xf()`), so whole they are
  specks and close up (Insane to 4x, fingers 5x) they are 14-22 px and
  read (`_shot_hoop.gd -- d=3 zoom`, `opengl3_angle`: 91 draw calls at
  the peak, the marks clear of the pins at 4x). Insane shows them too,
  since the same evening.
- **The zoom** (the same day: "make sure it has zoom in and out properly";
  the web game zooms with the wheel and pans with a drag): `PanZoom`
  (ui/flat/pan_zoom.gd) over the whole table, every band. Its room is the
  full screen, so nothing is clipped: the table, ring and linen all come
  close like a camera, the pill, bubble and button stay on the glass. Close
  is the shortest side between two pins made `ZOOM_SIDE` (110 px) wide,
  within 1.6-4x; the fingers may go to 5x. Two fingers pinch and pan, the
  wheel zooms on a desk, the round button at the foot's left (the thumb's
  side stays clear) steps whole / half way / close and back, and a finger
  pressed on bare linen when close pans (`PanZoom.pan_by`, new; a drag from
  a pin is a thread, so `one_finger_pan` stays off). A gesture that begins
  drops the thread in hand. `pin_screen` answers through the zoom, so the
  harnesses keep pressing what they see; the fx and the bubble go through
  `_at`. The win glides the zoom out before the slide. `YH_RULES_ZOOM` says
  it on the sheet; the tutorial's small boards set `zoomable = false`.
- **Combos** (the user: "Combos come from filling multiple panels at once
  (by connecting around and triggering the next one)"): one drag goes on
  from pin to pin (it can also walk along threads already laid, and goes on
  from a pin that has just popped off), and every panel it closes counts; the bubble
  shows xN from 2, `fill` climbs a step a panel (five at the most), a side
  two panels share fills both (`double`), and a drag of 3+ ends on `run`
  and a sparkle, 5+ with confetti. A press and release on one pin holds it,
  and a press on another lays the thread between them (tap-tap, for one
  hand).
- **The picture** is cut from the bead pictures Pixel Garden, Button Box and
  Toy Cannons deal: every band from the bank's 32- and 24-side pictures
  (`content/pixel_garden.json` bands 3 and 2, `State.BANDS`), or the day's
  themed one at the biggest side this phone holds (48, 32, 24, 12, 10 in
  turn, `ThemedPictures.picture`). So the daily theme reaches this board
  with no server work, and the bank's pick is drawn off the rng either way.
- **The cut** (2026-10-14; the first was a jittered lattice with each cell
  cut on a diagonal, which no panel count could make read like the low-poly
  fox the user set beside it): the way low-poly art is cut, in
  `hoop_state.gd`, all on the phone (an advisor's call: the themed wiring
  was there, the cutter was the gap, and the bank needs it too). (1)
  `_carve`: the background made bare, so the thing drawn stands on the
  linen: the one thick region that fronts the outside (the edge, or the
  bare reached from it) along half or more of its contact, is at least
  `BACKDROP` 15% of the drawn squares, **and** (2026-10-15) either lies on
  the picture's own edge for `EDGE_SHARE` 0.3 of its perimeter (a bank
  scene's sky or grass: 0.48-0.63 measured) or fills its bounding box,
  holes included, to `BOARD_FILL` 0.95 (the teapot's white board inside
  its bare margin: 1.00). The day's lantern (63 squares, a dark body on
  bare linen fronting the outside along all its contact: edge 0, box fill
  0.63) was carved by the first rule, and the user saw its flame, leaves
  and base floating ("Our game board do not even look the same of the
  drawed image"); the mug's and the ladybird's bodies were carved the
  same way. Measured over the bank's 36 and the Mac's 13 cached themed
  pictures: only those three cuts changed. (2) `_dissolve`: the one-square
  dark outline, thin runs and specks under `SPECK` (regions with under
  half their squares in a 2x2 block of their own) flooded with the nearest
  kept colour. (3) `_trace`: every edge between two colours walked on the
  squares' corners from junction to junction. (4) `_place`: each chain
  simplified (Douglas-Peucker, `TOLERANCE`), the junctions kept first, no
  pin nearer another than `SPACING`; both shares are of the side of a
  square the drawn thing would half fill, so a small thing cuts as fine as
  a scene, and both grow 20% a pass while the cut comes out too fine. (5)
  `_mesh`: Delaunay (`Geometry2D.triangulate_delaunay`) over the pins,
  **made to keep the picture's edges** (2026-10-15): `_place` also hands
  back every chain as steps between the pins it kept (a point dropped
  for being near a pin hands its place to that pin), and an edge the
  triangles miss has a pin put at its middle and the Delaunay run again,
  up to `CONFORM` 8 times (a middle all but on a pin is skipped; an edge
  still missing is let go). So no triangle straddles two colours or
  bridges two parts of the drawing, which the plain Delaunay did (gaps
  beside the lantern's flame, a leaf's corner in the body's colour). Each
  triangle is then the colour most of its beads say (`_read_half`, 21
  samples, cached by corners across the splits); one with `BARE_MAX` 0.7
  of them bare is left out (only a bridge can be, now), a sliver under
  `MIN_ANGLE` is left out when a tenth of its beads disagree and kept
  when it is plainly a piece of the drawing (a hole is worse), one flat
  under `FLAT` always; every one wound clockwise on screen (positive
  `_area`). (6) The biggest triangles whose middles are the spacing clear
  of every pin are split about them, a quarter of the shortfall a pass,
  until there are `PANELS` x `OVER` (1.18); the cut starts at `FINE` 0.5
  of the band's tolerance and spacing and coarsens a step (1.2x, ten
  tries) while the outline alone overflows the count, so the panels go
  to the drawing's shape first (the whale on Hard: 78 pins, were 68). (7) `_quads`: two neighbours of one
  colour making a convex four-sided shape are one panel at `QUADS`.
  Measured on the 36 bank pictures and this Mac's cached themed ones
  (2026-10-15, a throwaway cut report over every picture: carved colour,
  panels a colour, ms): Hard 77-93 panels in 7-27 ms (the 63-square
  lantern 52 ms), Insane 303-318 in 26-48 ms (were 125-160: the splits
  come a batch a pass now), its shortest side 0.8-1.6 squares (18-40 px
  on the phone, hence the zoom).
- **Insane** (2026-10-14 evening, the user: "keep the numbers, but make it
  way more complex, like the others picture games does") is about 300
  panels (`PANELS` 330 before the quads; 266-298 measured), pins 18-40 px
  apart at the whole, cut at `TOLERANCE` 0.024 and `SPACING` 0.034, with
  three hints; it is played through the zoom (close up to 4x, the fingers
  to 5x), and the numbers show. The blind rule and its tutorial page went
  with it. Nothing counts and nothing can be lost. The cut takes 125-160 ms
  on this Mac and the knitting ~25 ms.
- **Tools row**: the bulb on every band (3, 3, 2, 3; it threads a side of
  the panel nearest done) and the bin. **No Undo**: a thread is only ever
  taken along a side, so nothing laid is wrong. The seal: any Insane day, or
  a day with no thread refused ("Neat stitch").
- **The look**: a sewing table of oat check, the hoop's wood ring with its
  screw, linen with a weave, purple pins, terracotta yarn with a twist.
  **The knit** (2026-10-15, the user, with the reference's screens beside
  ours: "see how different in quality they are ... it's insanely
  terrible ... show a really great mosaic image, this is what I want"):
  a filled panel is its outline over one knit tile, `knit_texture()`, a
  128x144 texture drawn once in code (grey; the panel's colour is the
  vertex colour, multiplied in) of `TILE` 4x6 V stitches, each `STITCH`
  8x6 px at 1x: two leaves slim at the top and plump at the foot, the
  foot reaching a third of the way into the row below over the slim tops
  there, as stockinette lies (arms of one width stopping at their own row
  left a field of dark arrowheads; plump ones merged into a chevron
  weave). The tile repeats and is mipmapped (`texture_repeat`,
  `texture_filter` on the board), so whole it is an even grain and close
  up it is stitches; nothing is rebuilt for the zoom. Drawing the tile is
  63 ms of GDScript on this Mac, once per run, at the first board's first
  draw (a hitch to feel for on a phone). Seen the same on
  `--rendering-driver opengl3_angle` (`close`, 95 draw calls). Each panel is lit
  as a facet: `FACET` 0.13 lighter or darker by its index and
  `FACET_SLOPE` 0.08 across it toward `LIGHT`, so neighbours of one colour
  read as planes. A side's thread is terracotta yarn on bare linen and,
  once a panel beside it is knitted, **a rope in that panel's colour**
  (lighter, its twist darker and half clear), drawn over the knitting;
  a pin whose every side is threaded leaves **a knot** in the colour of a
  panel knitted at it. The rope is `_rope_w`, 0.13 of the shortest side
  within 2.4-6 px, so Insane's tiny panels are rimmed thinly rather than
  caged (a 6 px rope round 18-40 px panels was a wire mesh). The old knit
  (polygons: a dark ground, hexagon leaves, `KNIT` 15x12, `SEAM`,
  `_knit_rim`) is gone; a panel knitting in now comes in across itself
  from the side that closed it and swells. Two balls of yarn and a needle
  dress the foot. The win swells the picture once, then slides the hoop
  to the win's span.
- **Meshes**: the table, the hoop and the clamp built a layout; the knitting
  in chunks of ten panels (three or four vertices a panel, with UVs),
  rebuilt when one fills and drawn with the knit texture; threads, pins
  and marks a mesh each, rebuilt on a thread (the pins' when a fill ends,
  for the knots); what moves as three meshes a frame (the panels knitting
  in, textured; the rest under and over the pins). The
  zoom is a transform over them all while fingers pinch; once it settles
  (2026-10-15, the user, at 4x on Hard: "check why the game resolution is
  so terrible") everything under it is rebuilt for that zoom (`_built_k`,
  `_rebuild_for_zoom`): built at 1x and scaled 4x, Face's 1.5 px feather
  was a 6 px blur, the numerals' 0.9 px strokes blots, the leaves hexagons.
  The Builder now takes `feather` (FEATHER / k) and `detail` (k); the
  knitting got the feather it never had (`_knit_rim`, ground and leaves),
  whose stair-stepped edge showed at any zoom (the knit of that day; the
  textured one needs no rebuild). Hard zoomed: 90 draw calls
  peak; 2026-10-15: Hard close 95 (the same on `opengl3_angle`), Hard
  solve 114, Insane solve 140 peak, Medium play 99 (the default driver). Draw calls on
  `opengl3_angle` at 810x1440 (2026-10-14, after the numerals and the
  zoom): 85 at rest, 82-88 zoomed and threading on Medium, 117 peak on the
  Insane solve (budget 855). Building every panel's knitting on Insane
  takes ~20-27 ms headless.
- **Sounds** (`tools/gen_sfx.py` "hoop", no new take: Button Box's raws
  copied into `build/sfx_raw/hoop/`): `pick`, `stitch`, `fill`, `locked`,
  `enter`, `reset`, `double`, `run`, `whole`, `hint`, `solved`, `party`,
  `stamp`. All 13 pass `measure_sfx.py`; **none has been heard by the user**.
- **Harnesses**: `tests/_shot_hoop.gd -- d=<0..3> rest|zoom|play|solve|close|howto` (a
  greedy drag through the board's own input path; `zoom` presses the
  button twice, pans from bare linen, drags close and wheels out; `close`
  threads most sides through the state and zooms in with the button and
  the wheel, for the knit seen close),
  `tests/_probe_hoop.gd` (headless, every band), `tests/_win.gd -- hoop`
  (PASS, Medium, bulb then every side dragged through the window). On a
  Mac with the day cached (this one holds 20261014's) the shots show the
  themed picture, the way the phone will.

## Decided for the user, unconfirmed (2026-10-14)

- The name, the hoop-and-knitting look, the purple pins and terracotta yarn.
- The magnet's shares and the tap chain's three ways down (the user named
  a tap on the held pin and an error; bare linen is mine).
- The cut: every band off the big bank pictures (Easy no longer off the
  10-side ones); the carve, dissolve and spacing rules; the zoom on every
  band, as a camera over the whole table rather than clipped to the linen.
- A Delaunay over floats can place one edge differently on a phone than on
  this Mac when four pins are all but on one circle, so a day's panel count
  may differ by one between the two; a day put back on the phone that
  played it is the same cut. A picture the cut makes nothing of is dealt
  the small heart in `setup` (none of the 40 seen comes near: the fewest
  was 23 panels).
- Wrong threads refused rather than laid and judged; hence no Undo, and the
  seal's "no thread refused".
- Panel counts per band (26/50/90/140) and the quad share; Easy's pictures
  are crude at ~30 panels (the daisy reads, a mushroom only just).
- The combo rules (from 2, a step a panel, `run` from 3).
- The tutorial (five pages, hand-laid three triangles and a square) and the
  menu card (a low-poly heart in a hoop, the go button a ball of yarn).
- Owed: a phone (pin size at ~65 px spacing on Insane; the snap is 24-46 px
  by spacing), the sounds heard, pt/es read, haptics felt.

## 2026-10-15 evening: hold to thread, panels to 7 corners, the band is the picture

The user, with a Hard board's screen (a knot of pins too close to tell
apart, every panel a 3 or a 4): "User has to click and hold to connect
dots, if touch is released the string breaks ... we should be able to
handle up to 7 dots area. Difficulty should come from harder pictures,
with way more complex shapes. So just like pixel garden easier level
means simpler images". Built unattended ("do everything and when it's
done push to main").

- **Hold to thread.** The tap chain is gone (`_armed`, `_chain`,
  `_press_pin`, `_put_down`): a press on a pin takes the thread up, a drag
  lays it pin to pin, and the release breaks it off (a low `pick` and a
  puff of yarn where the finger was, when it hung loose). A drag let go
  short of a pin still takes it along a side (`_reached`). The tutorial's
  TAP page is now HOLD (two sides laid, the finger runs on past the last
  pin onto bare linen and lifts: `HTP_YH_HOLD_CAP`, `HTP_YH_BREAK_CAP`);
  `YH_RULES_TAP` became `YH_RULES_HOLD`; the `HTP_YH_TAP*` rows went.
- **The band is the picture** (`THEMED_SIDE` [24, 32, 48, 48],
  `BANK_BAND` [2, 3, 3, 3]): Easy cuts the day's 24-side themed picture,
  Medium the 32, Hard the 48, Insane the 48 again at the finest spacing
  (the themed 32, then the bank's 32, where no 48 is cached). The 10- and
  12-side pictures were tried for Easy and dropped: they are drawn in
  one-square strokes (the ladybird's grass, spots and petals), and no
  spacing a finger can take keeps them. No panel count is aimed at now:
  the tolerance is in the picture's squares (`TOLERANCE` 0.6-0.8), the
  spacing a share of the drawing's side (`SPACING` 0.09, 0.075, 0.066,
  0.042, never under `SPACING_MIN` 1.15 squares), triangles over
  `SPLIT_AREA` spacings squared are split, and the count is what the
  drawing makes. `FINE`, `OVER`, `PANELS`, `QUADS` and the coarsening
  loop are gone.
- **No pin crowds another.** The knot on the user's Hard board came from
  the cut's first try at half the spacing and from the conforming
  midpoints (a pin a quarter spacing from another); now the conform puts
  no midpoint within 0.75 of the spacing of a pin, and lets that edge go.
- **Panels of 3 to 7 corners** (`_merge`, was `_quads`): from each
  triangle in an order the rng draws, a panel grows across its sides
  over neighbours of its colour while it stays convex (no corner on a
  straight line: `_convex`), toward a size drawn from `CORNERS_AIM`.
  Numerals 5, 6 and 7 are stroked like the 3 and 4 (`_glyph`).
- **Two-tone shading joins before the dissolve** (`_join_families`,
  `FAMILY` 0.3 in RGB): a thin region and the touching regions of a near
  colour become one region of the biggest one's colour, so a grass of two
  greens stays a shape instead of dissolving square by square.
- Measured (a throwaway cut report over the bank and the Mac's three
  cached days, minimum pin distance at 810 wide, whole view): Easy 23-40
  panels, pins 48-79 px apart at the least; Medium 23-50, 35-62 px; Hard
  41-61, 30-43 px (the screenshot's knot was ~10 px); Insane 94-141, 18-24
  px (played through the zoom). Corners 3-7 on every band. Cut 7-41 ms.
  `_probe_hoop.gd` solves every band; `_shot_hoop.gd` on `opengl3_angle`:
  Hard rest 85 draw calls, close 92 peak, tutorial 111.
- `YH_LVL_*` say the picture and about how many panels (30, 40, 50,
  120); `YH_RULES` says 3 to 7 corners; `YH_RULES_INSANE` about 120.
- Unconfirmed: the user's verdict, the shares above, the break's sound
  (a low `pick`, no new take), the HOLD page seen moving, pt/es read on a
  phone. The `day_dict` metric `quads` is now `corners_3_to_7`.

## 2026-10-16: the picture is drawn as low-poly art, not cut from beads

The user: "images on gumdrop and yarn hoop are terrible, i want you to
deeply polish it to make a great image in any difficulty based on theme".
Rendered headless, the day's cut was a blob: the bead pictures' readable
parts are one-square lines (a shell's spiral, a fish's eye and spots), and
the carve, dissolve and family join that make a 24-48 side picture
threadable take exactly those away. No tuning of the cut fixes that.

- **The night draws the band's thing as a low-poly illustration**
  (`server/functions/src/hoop.ts`, `facets.ts`): flat facets, each one
  colour, shaded light/mid/shadow by the facet, on a green screen
  (`KEY_WORDS`: asked for white, a white teapot's lit facets came at 250,
  the board's own shade; asked for magenta, the flash model paints a hot
  pink that ate a red thing's edge). Easy is asked 25-35 large facets,
  Medium 40-55, Hard 70-90, Insane 130-170 small. The thing is the theme's
  `objects[band + 1]` (Easy the second thing, Insane the fifth).
- **Read back as geometry on the night**: the board is flooded from the
  edge (its colour the edge's median, joined across steps under `STEP` so
  it follows the screen's shading and stops at the thing's sharp edge); a
  patch of the board's colour enclosed by the thing is the board too (a
  mug's handle); facets are grown at a flat colour (`grow`, 16), the soft
  pixels along their seams dissolved, a region round another cut through
  the middle (`unring`); regions under a band's floor joined to the
  neighbour nearest in colour, except one that stands out from all of them
  by `SALIENT` (a seed, an eye), which is grown to the floor instead; then
  the nearest colours joined (keeping the bigger one's colour: averaged,
  they went to mud) until the panels come to the band's most (40, 60, 95,
  170). The outlines are one network (`network`): a corner where three
  regions meet is a pin of all of them, and each run between such corners
  is simplified once, so neighbours share their pins exactly. Pins nearer
  than the band's `least` (13, 10, 8, 6 of 256) along a side are made one,
  never so a facet is left under 3 corners; a region over 7 corners or bent
  in is ear-clipped and joined back into convex panels of 3-7 (Hertel and
  Mehlhorn). A cut where any pin lies inside another panel (a sliver whose
  simplified outline folds across its neighbour) has the smallest region
  caught joined to its neighbour and is cut again. 0.2-1.2 s a picture.
- **Shipped as `hoops` in the `pictures` document** (`{id, name, pins,
  panels: [{k, c}]}`, pins in a square of 100, `c` "#rrggbb"), a themeDay
  step a band (`hoop0`..`hoop3`). `ThemedPictures.hoop()` checks it (3-7
  corners, no pin twice, no side three panels share) and
  `HoopState.adopt_drawn()` lays it as it came; `colours` holds the hex,
  `HoopState.ink()` reads a bead name or a hex, and a drawn picture's knit
  gets no per-panel shade of its own (`drawn`: the facets carry the
  drawing's). Without a `hoops` band the bead picture is cut as before.
- **The image model is `DAILY_SHAPES_MODEL`**, default
  `gemini-2.5-flash-image` on Vertex: the pixel pictures'
  `gemini-3-pro-image` answered 429 for over half an hour once a day's
  drawings had run on this Mac, and flash drew the facets as cleanly (a
  teapot tray, 167 panels; a watermelon with its seeds, 59).
- `YH_LVL_*` and `YH_RULES_INSANE` now say about 35, 55, 85 and 150 panels.
- Made on this Mac for 20261019 (Picnic on the Hill); **the deployed
  `themeDay` does not have the steps until the user deploys the functions**.
  Unconfirmed: the user's eye, the counts, the green screen, Easy being the
  theme's second thing.

## 2026-10-19: a pebble for every pin reached

The user: "on yarn hoop, add a tap sound when a new dot is selected".
`_step` cues `pick` (the pebble, 0.94-1.06 at random, the same as a
press) whenever the thread goes on to a new pin, whether it lays a side
(over the `stitch` pop) or walks along one already threaded (silent
before). A quick drag over several pins in one frame plays it once
(`CUE_GAP`). Unheard by the user.

## 2026-10-19: a pin stands while a panel round it is open

The user: "the dots should only disappear when it's not connected to any
other dot ... if there is a 5 dots area ... it should show all 5 dots,
even the ones already connect by something". A pin popped off once every
side it had was threaded, so an open panel could show 3 of its 5 corners.
Now `HoopState.pin_live` counts the unfilled panels round each pin; a pin
stands (drawn, taken by a press, a drag or the magnet) while one is left
and pops off when the last of them fills. A standing pin with every side
threaded is reached by walking its threads. Probe solves every band;
unseen on screen.

## 2026-10-20: a drawn picture's pins welded at the band's spacing

The user, with a phone shot of the 21st's Easy snail: "yarn hoop still
grouping points together, making UX terrible". The 2026-10-15 fix (no pin
within 0.75 spacing) lived in the bead cut; the drawn path only had the
night's `least`, and that joined pins **along a side** and **never where
an outline would close under 3 corners**, so a sliver facet (a leaf
stem, a snail's foot) kept two pins a pixel apart and three facets
meeting kept a knot of three. Measured on the cached 20th and 21st
(of 100): closest pairs 0.45-3.3, 3 to 55 pairs a band under 3.

- **The phone welds as it lays** (`HoopState.weld`, from `adopt_drawn`,
  `DRAWN_LEAST` 5.1/3.9/3.1/2.3 of 100, the night's 13/10/8/6 of 256):
  every pair under it, nearest first, keeps the pin on the picture's edge
  (a side only one panel has), then the one more panels meet at; a panel
  closed under 3 corners or pinched is let go or split, its neighbours
  meeting along its long side. So days already written are fixed by the
  APK alone. On the 20th and 21st: least now 2.42-7.79 (every band at or
  over its spacing), no side three panels share, no pin inside a panel,
  0-8% of the picture lost (thin stems under the spacing, which no finger
  could thread), every band solves by hints.
- **The night does the same** (`panels()` in `server/functions/src/hoop.ts`:
  all pairs, no crush guard, edge pins kept). Read back from the cached
  pictures re-rendered on green: 0 pairs under the spacing (old reader on
  the same input: 1-21 a band), no overlaps; that re-render (an already
  simplified picture) left Medium's cabbage and frog at 22-23 panels, under
  `LEAST_PANELS` 26, which a real 40-55 facet drawing should clear.
  **Needs the user's functions deploy.**
- Unconfirmed: the phone, the user's verdict on what thin features the
  weld takes away.

## 2026-10-21: the map written by a model

The user, with the day viewer open on 20261021, of the pixel pictures
(Jewel Box) "are amazing, love them", of Yarn Hoop "is terrible", and
beside it a reference of what was expected (a few hundred small muted
facets, softly lit: a rain boot, a snail with its spiral, a frog with its
green body, a kettle without a face): "We can use the llm to make sure
high quality outcome, check how can we use them to make sure we have a
specific port for each game to have a high quality sharp picture game on
each". Then, with run 2's snail beside its shredded cut: "can we send the
image, some mapping field, and ask a model to generate the yarn hoop
map?" and, at the end: "amazing, apply it". Spec
`docs/superpowers/specs/2026-10-21-picture-ports-design.md`; the four
throwaway spike scripts, the four spike maps and the style crop are kept in
`docs/superpowers/specs/2026-10-21-picture-ports-spike/`. Built on
`feat/picture-ports`, **not pushed, not deployed, nothing of it run on
Vertex yet**.

- **The shape of it** (`server/functions/src/hoop.ts` `makeHoop`, one per
  band, returning `{picture, port}`): the night draws the band's thing,
  hands the drawing with a numbered grid over it to the reviewer model,
  which writes pins and panels in grid units; the mesh is repaired and
  checked as the phone checks it, coloured off the drawing, **rendered as
  the player will see it** and shown to a reviewer (the eye,
  `docs/agents/turns-and-backend.md`, "Picture ports"), which names the
  thing and scores it. The pixel reader (`readHoop`) is now only the
  fallback.
- **The key colour is chosen a thing** (`key.ts` `keyFor`): the write model
  is asked, from `thing.draw`, which of green, magenta and cyan
  (`KEY_HEX`) is farthest from the thing, and `keyWords(key)` replaces the
  old fixed `KEY_WORDS` sentence (`facets.ts` keeps `KEY_WORDS =
  keyWords("green")`, byte for byte). Why: the spike showed the green key
  was the hoop's fault, not the reader's. Flash paints green as a muted
  sage and the board flood ate every pale part near it (the snail's cream
  body, the umbrella's yellow middle, a lime frog whole); on magenta and
  cyan the umbrella read 8 and 8, the frog 8 and 6. With no model (or an
  answer out of the three) a word fallback picks: green, lime, teal, mint,
  olive, turquoise give magenta; pink, magenta, purple, violet, red, rose
  give cyan; else green. `keyFor` also answers `creature` (`Thing.creature?`
  in `theme.ts`, optional so a theme written before the field works): the
  prompt asks for a face only when the thing is a creature.
- **The prompt is the reference's** (`PROMPT(what, band, key, creature)`): a
  low-poly illustration of at least 150, about 200 flat facets **on every
  band** (`BANDS[].facets` is kept and unused), each one colour, a muted
  earthy pastel palette, soft light from the top left with light, mid and
  shadow tones, no outlines, no gradient or texture, no cast shadow or
  ground, square. "Cute cozy style" is gone. **A style reference goes with
  it**: `lib/hoop_style.png` (a crop of the user's low-poly snail, copied
  into `lib/` by `npm run build` from the spike folder, as
  `vista_style.png` is) is handed to `draw()` as `images`. In the spike the
  snail drawn with it matched the reference and read 7; the same prompt in
  words alone drew a textured, near-photographic snail the reader shredded
  (5).
- **The mapping field** (`grid.ts` `gridOver`): the drawing is scaled to
  1000 px on white with a 44 px margin, lines 0..N (`GRID_N` 20, 24, 30, 40
  by band, about each band's pin spacing), every fifth darker, the numbers
  along all four edges (every line to 24, every other past it).
- **The model's map** (`mapHoop`, `role: "review"`, Opus): the `MAPPER`
  system text states the rules the phone checks (3-7 corners, convex,
  neighbours sharing whole sides, no overlap, no gap, nothing of the
  background, every facet kept) and two things the first spike maps
  taught: a thin part (a handle, a stalk, a shaft) is drawn at least one
  grid cell wide because nearer pins are welded and it would vanish (the
  umbrella's shaft was snapped away in the spike), and the whole panel
  budget is used (the model simplifies: 30 of 40, 75 of 170) with fewer
  than the band's `LEAST_PANELS` (16, 26, 40, 80) refused. The answer is
  type-checked (`asMap`): only a pin with an id and finite x and y counts.
- **The repair and the checks** (`mesh.ts` `repairMesh`, `colourFrom`,
  `checkMesh`): grid units to the square of 100 centred on the thing's box
  as before; pins within 0.35 of a cell made one; a panel's repeated or
  unknown pins dropped, a panel under 3 corners dropped; a pin lying on
  another panel's side (a T-junction) inserted into that side; pins nearer
  than the band's `least` welded as the night and the phone weld; a panel
  laid over others (a side three panels share) dropped, the one on most
  such sides first (`unstack`, added in the build: the spike's frog and
  kettle had triangles listed over the quads beside them); a concave or
  over-7 panel ear-clipped and joined back into convex panels
  (`ears`, `regroup` from `hoop.ts`). Then the `why`: a panel not 3-7
  corners, a pin twice in a panel, a pin inside another panel, a side
  three panels share, under `LEAST_PANELS`, over the band's most. **The
  colours are the drawing's mean over each panel, never the model's hex**
  (`colourFrom`); a panel within 60 of the key (Euclidean rgb) is the
  background and is dropped, the mesh is **placed again** after it (the
  box moved: the long axis spans 0..100 and the other is centred) and
  re-checked by `checkMesh`, since losing background panels can bring a
  count under the least. A refused map is asked again with the refusal
  folded in.
- **The render the eye sees**: the repaired map as polygons, 600 px, the
  panels outlined as the board's ropes are (`#7a4a3a`, width 0.6) on linen
  `#efe2c6` (`eye.ts` `renderPolygons`). The spike showed the eye a
  256-px raster scaled up and a third of its complaints were "jagged",
  "stair-stepped" edges the player never sees; a cream handle also
  "vanished into the cream background" that a rope outlines.
- **The tries** (`HOOP_DRAWINGS` 2, `MAP_ASKS` 2): each drawing is mapped
  up to twice; a refusal or the eye's complaint ("scored N, took it for X,
  and said: ...") is the next ask's lesson (`lesson`); **a try is kept when
  the eye named the thing, found nothing wrong and scored at least
  `FLOOR.hoop` 7; the best score of the kept tries wins, across drawings
  and asks**, and the tries stop once one scores 9. When none is kept, one
  `reader` try on the last drawing: `readHoop`, judged only when it passed
  its own `why` (a refused cut can never be kept). The score gates, the
  pick alone does not: the spike's eye named every broken read (an umbrella
  with no middle at 3, a frog with no head at 2), so the pick alone only
  catches a thing that is not there. **No kept try: no picture, and the
  board is cut from the bank as before.**
- **The clock** (ruling, the controller's): the brief had no clock, and a
  band 3 map ask runs about 200 s while a run may start a step 15 minutes
  in, so `HOOP_BUDGET_MS` is 12 minutes from `makeHoop`'s start, or the
  run's own limit if that comes first (`until`, themeday.ts: 6 minutes
  before the 30-minute lease ends, 2026-10-21 review fix), past which no new
  draw, ask or reader begins; the judge of a map already asked still runs.
  The first try skipped is recorded with `why: "out of time"`. The spec's anti-goal (a night that
  runs out of its half-hour step) binds over the ask count. Cost if wrong:
  Insane falls to the reader more often on a slow night. The deadline
  bounds when a call begins, not how long it runs: a 240 s ask begun at
  11:59 reaches about 16 minutes, inside the run's 6 minutes of room.
- **Rulings on the repair** (the controller's, Task 4): the brief's "why ''
  on all four spike fixtures" was wrong, since the umbrella (26 panels,
  band 2 least 40) and the kettle (75, band 3 least 80) are under the
  band's least and are refused, which is the spec's under-count check
  working (a refused map is re-asked); `unstack` is within the spec's
  repair pass; a part thinner than the snap (0.35 cell) or the band's weld
  spacing cannot be a panel on the board (the phone's finger spacing), so
  the ask says so (cost if wrong: thin objects read chunkier than the
  drawing); `colourFrom` cannot re-check the band's counts (no band on the
  mesh), so `makeHoop` re-runs `checkMesh` after it.
- **The phone and the viewer's hoop are unchanged**: the map is the `hoops`
  document as it is (`pins`, `panels: [{k, c}]`), which
  `ThemedPictures.hoop()` checks and `HoopState.adopt_drawn()` lays, welding
  at `DRAWN_LEAST` as it lays (2026-10-20, above). Only the **picture** got
  finer; the play (35/55/85/150 panels' worth of pins, counts, spacing) is
  as it was, and the density is the picture's, never bought by crowding
  pins. The spec's "fine facets with their own corner points" was dropped
  at approval: the panels are the drawing's facets now.
- **What the spike measured** (2026-10-21, 15:25-16:03, flash drawings,
  Opus map, the eye scoring against the old crude render so the hoop's are
  low by some). Run 2, hoop snail/frog/umbrella/kettle, with/without the
  style reference: 7/5, 6/8, 8/8, 6/4. The model's maps against the pixel
  reader's cuts of the same drawings (score, panels):

  | Card | Model's map | Reader's cut |
  |---|---|---|
  | snail, Easy | 30 panels, 45 pins, 6 | 40 panels, 5 |
  | frog, Medium | 56 panels, 78 pins, 7 | 55 panels, 6 |
  | umbrella, Hard | 25 panels, 47 pins, 5 | 29 panels, 5 |
  | kettle, Insane | 75 panels, 114 pins, 7 | 121 panels, 5 |

  The model's meshes were clean (0 overlaps, no panel over 7 corners, one
  T-junction and two sides shared by three in all four); the reader's cuts
  jagged, hole-ridden, losing eye stalks, a knob, a shaft. Missed: fine
  features past the panel budget (the shell's spiral folded into a dome at
  30 panels, the shaft, 1 panel, dropped) and the counts came under the
  band's most. A map was 45-175 s and $0.11-0.42 on Opus.
- **As built** (Task 5, Step 3, the one real ask made): Easy snail on the
  style crop, one Opus ask, **90 s, $0.22, 45 pins and 40 panels**, the
  whole budget used, a clear snail with its spiral, two eye stalks, none
  dropped by repair or by `colourFrom`. Band 3 (a 40-grid map of up to 170
  panels) is **not measured**: the 20-grid ask took 90 s, an ask times out
  at 240 s and caps at 16,000 tokens, and 2 drawings x 2 asks + judges is
  the worst case the 12-minute budget exists for.
- **Not built**: the spec's floor in `readHoop` on the thing's share of the
  picture (under 12% of the raster, or a thing split into parts of which
  the biggest is under half, `why`-refused before the eye sees it). The
  eye's score does that job; `readHoop` is as it was.
- **Unconfirmed**: nothing has run on Vertex. The drawing check is the
  user's: `build/port_hoop.js` (git-ignored; Rainy Day, bands 0 and 3,
  drawings to `build/port_hoop/`), the command in
  `.superpowers/sdd/2026-10-21-picture-ports/task-5-report.md`. The
  phone's picture on screen, the user's eye on the first night's hoops, the
  keys chosen, band 3's time, how often Insane falls to the reader. **The
  deployed `themeDay` makes pictures the old way until the user deploys the
  functions** (the deploy list, `docs/agents/turns-and-backend.md`, which
  also carries the 2026-10-20 pin weld, never deployed).
- **The first Vertex check, 2026-10-21** (`build/ports_check.log`): Easy's
  snail kept at 7; Insane's kettle failed every try (maps 4/4/6/5, the
  reader 5) and the board fell back to the bead cut. Two causes, two
  fixes, both unrun on Vertex:
  - **A thin part tinted by the key.** The handle's panels, mapped a
    little wider than the handle, averaged dark grey with the sage round
    it to `(87,109,76)`, 99 from the board, so they were kept green.
    `colourFrom` now leaves out every pixel of the key's hue (within 25
    degrees of the measured board or the key's hex, chroma at least 12;
    tight because cyan is under 30 degrees from a blue thing) before it
    takes the mean, and a panel over nothing but the key is the board and
    is dropped. On the kettle's drawing the same handle panel reads
    `#2b2a2c`.
  - **Holes in the body at Insane's 40 grid.** `mapHoop` adds `FINE` for
    band 3: every grid cell of the thing under a panel, no hole, thin parts
    a whole cell wide joining the body at each end. Not yet known whether
    the holes were the model's or the mending's: each map try now carries
    `mended` (asked, kept, dropped, board, clipped, tees, snapped) on the
    port and in its log line, so the next run says.
  - **The second run said** (`build/port_hoop3.log`, a new drawing with
    cream bands, maps 3/4/4, $2.09, 15 min): `repairMesh` let go nothing;
    `colourFrom` dropped 35, 25 and 25 panels as board. The old test, a
    mean within 60 rgb of the measured sage, took the kettle's grey-blue
    and cream bands (43 to 55 from it) for background: those were the
    holes, on both runs. The board is now told by hue alone: a panel
    three quarters key pixels (`KEY_SHARE`) is dropped, and a mean of the
    key's hue; nothing is dropped for being near the board in rgb. The
    same bands now keep their grey-blue. `FINE` lost its "check the map
    cell by cell", which ran the first ask past its 32,000 tokens (and the
    time it took left the reader out of time).
  - **The third run kept it** (`build/port_hoop3.log`, 46cb5a3a): maps
    6/7/7/5, board drops 7/0/0/7, `repairMesh` still nothing; try 1 kept
    at 7, 117 panels (80..170), a whole body, the handle dark all round.
    The eye still asks for a rounder handle and softer shading. The band
    ran 15.0 min against HOOP_BUDGET_MS's 12 (a try begun before the
    deadline runs to its end), $2.07.

## 2026-10-28: made fun -- numbers that read and count down, the outline threaded, the day kept

The user: "make yarn hoop experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, pushed.
Read against the reference on its web page (its level 1 played in
Chrome: four dots, three 3s **inside the shapes**, so our rule is its
rule; bold numerals as heavy as its dots, a thick twisted rope, a gentle
ramp of levels) and Cozy Ropes (store page and reviews: saved progress,
"no penalties", players angry at a move limit and at close dots taken by
mistake).

- **The finding.** The cached days on this Mac (19th-29th): Easy ~40
  panels and **~90 sides threaded by hand**, Medium ~55 and ~130, Hard
  ~90 and ~200, Insane 130-170 and 250-390; the clue for each was a
  numeral 3.5-5.5 px tall (`MARK_H`, from the user's 2026-10-14 "really
  small"), about half a millimetre on a phone, so a day played as a poke
  through a cloud of identical pins. And **no day was kept mid-way**:
  leaving a 200-side Hard threw it away (no board in the app keeps one;
  they were minutes long).
- **The numbers count down and read** (`_mark_into`): a panel's numeral is
  the sides it still wants (`open_sides`), its corner count until the
  first thread, so each lay ticks the numbers either side of it (a swell
  over `MARK_TICK`, drawn in the moving mesh while `_ticked`). The ink
  turns from `MARK` to the panel's own colour as it is threaded, wholly at
  the last side (never paler than `MARK_LUM`, or a cream panel's sank into
  the linen). Sized to the room about the middle, `MARK_ROOM` 0.65 within
  `MARK_H` 6-18 px and never over `MARK_SEEN` 24 px as the zoom shows it;
  strokes `MARK_W` 0.21, `MARK` darker. Measured at 810x1440 on the bank
  cuts: Easy median 20 px (now 18 at the most), Hard 14, Insane 10 (6 at
  the least, read through the zoom as before). Glyphs 1 and 2 added.
- **The outline is threaded before the first touch** (`HoopState.hem`,
  on every reset of a board `setup` dealt, never `adopt_laid`'s tutorial
  boards): every side only one panel has, except one whose laying would
  close its panel, so the day opens on the thing's silhouette in yarn and
  nothing is knitted before the player's first thread. 8-35% of the sides
  on the bank cuts. The bin puts the hem back. **A taste call made for the
  user** (the reference does not do it); `hems` false in `setup` undoes it.
- **The day is kept** (`_keep`, `_resume`, `_forget`): today's daily, a
  band a key, in `<progress path>_hoop_play.cfg` (so a harness's runs keep
  their own; `_shot_hoop.gd` deletes its file): the laid sides, slips,
  hints, best, moves and time, written at the end of each stroke and the
  bulb's thread, let go on the win and the bin, other days dropped on the
  next write; a cut with another side count is not trusted.
- **The rope is chunky**: `YARN_W` 9 at the most, `ROPE_SHARE` 0.19 of the
  shortest side (was 6 and 0.13), the thread in hand and the draw-in the
  same width as the laid rope; `TWIST` 12.
- `YH_RULES` and `HTP_YH_FILL_BODY` say the count-down, the outline and the
  keeping (en/pt/es).
- Probe every band solved; suite 303252/0; `_win.gd hoop` PASS; draw calls
  86 rest (Easy), 96 peak in play (Medium), 92 zoomed on `opengl3_angle`
  (Insane). Throwaway probe: resume gives the same sides on every band,
  the bin leaves the hem only, nothing filled at the start.
- **Not done, named**: the reference's gentle ramp (three shapes on level
  1) is the night's panel budget (`server/functions/src/hoop.ts`,
  `LEAST_PANELS`), not the phone's. Whether the night's picture ports are
  deployed is the user's to say (picture-ports is on main; the deploy list
  in `docs/agents/turns-and-backend.md`). Unseen on a phone, no new sound.
