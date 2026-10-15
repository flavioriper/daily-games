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
  it is taken either way. A drag on its way takes only a pin it passes
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
  bare reached from it) along half or more of its contact and is at least
  `BACKDROP` 15% of the drawn squares (a themed picture's white board, a
  bank scene's sky; a whale's body touching the edge at four squares fronts
  far less than its outline and stays). (2) `_dissolve`: the one-square
  dark outline, thin runs and specks under `SPECK` (regions with under
  half their squares in a 2x2 block of their own) flooded with the nearest
  kept colour. (3) `_trace`: every edge between two colours walked on the
  squares' corners from junction to junction. (4) `_place`: each chain
  simplified (Douglas-Peucker, `TOLERANCE`), the junctions kept first, no
  pin nearer another than `SPACING`; both shares are of the side of a
  square the drawn thing would half fill, so a small thing cuts as fine as
  a scene, and both grow 20% a pass while the cut comes out too fine. (5)
  `_mesh`: Delaunay (`Geometry2D.triangulate_delaunay`) over the pins, each
  triangle the colour most of its beads say (`_read_half`, 21 samples,
  cached by corners across the splits), one mostly bare or a sliver under
  `MIN_ANGLE` left out, every one wound clockwise on screen (positive
  `_area`; `offset_polygon(-SEAM)` needs it). (6) The biggest triangle
  whose middle is the spacing clear of every pin is split about it until
  there are `PANELS` x `OVER` (1.18). (7) `_quads`: two neighbours of one
  colour making a convex four-sided shape are one panel at `QUADS`.
  Measured on the 36 bank pictures and this Mac's cached themed ones (a
  48 teapot, a 32 sun hat, two 24s): 24-29 / 44-56 / 78-88 panels in
  5-25 ms, and Insane 266-298 in 125-160 ms, its shortest side 0.8-1.6
  squares (18-40 px on the phone, hence the zoom). Edges that are not Delaunay edges leave
  a triangle straddling two colours now and then; that is the look.
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
  screw, linen with a weave, purple pins, terracotta yarn with a twist; a
  filled panel is a darker ground in its bead colour with columns of lighter
  V stitches, each panel a shade of its own so the picture reads as facets.
  Two balls of yarn and a needle dress the foot. The win swells the picture
  once, then slides the hoop to the win's span.
- **Meshes**: the table, the hoop and the clamp built a layout; the knitting
  in chunks of ten panels, rebuilt when one fills; threads, pins and marks a
  mesh each, rebuilt on a thread; what moves as two meshes a frame. The
  zoom is a transform over them all while fingers pinch; once it settles
  (2026-10-15, the user, at 4x on Hard: "check why the game resolution is
  so terrible") everything under it is rebuilt for that zoom (`_built_k`,
  `_rebuild_for_zoom`): built at 1x and scaled 4x, Face's 1.5 px feather
  was a 6 px blur, the numerals' 0.9 px strokes blots, the leaves hexagons.
  The Builder now takes `feather` (FEATHER / k) and `detail` (k); the
  knitting got the feather it never had (`_knit_rim`, ground and leaves),
  whose stair-stepped edge showed at any zoom. Hard zoomed: 90 draw calls
  peak. Draw calls on
  `opengl3_angle` at 810x1440 (2026-10-14, after the numerals and the
  zoom): 85 at rest, 82-88 zoomed and threading on Medium, 117 peak on the
  Insane solve (budget 855). Building every panel's knitting on Insane
  takes ~20-27 ms headless.
- **Sounds** (`tools/gen_sfx.py` "hoop", no new take: Button Box's raws
  copied into `build/sfx_raw/hoop/`): `pick`, `stitch`, `fill`, `locked`,
  `enter`, `reset`, `double`, `run`, `whole`, `hint`, `solved`, `party`,
  `stamp`. All 13 pass `measure_sfx.py`; **none has been heard by the user**.
- **Harnesses**: `tests/_shot_hoop.gd -- d=<0..3> rest|zoom|play|solve|howto` (a
  greedy drag through the board's own input path; `zoom` presses the
  button twice, pans from bare linen, drags close and wheels out),
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
