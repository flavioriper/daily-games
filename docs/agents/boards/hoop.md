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
