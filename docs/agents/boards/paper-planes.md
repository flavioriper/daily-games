# Paper Planes

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

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
- **The polish, board side (2026-09-30, spec
  `2026-09-30-paper-planes-polish-design.md` sections 1, 3 and 5; numbers in
  its section 7).** Hard and Insane judge a tap: a blocked plane crashes
  (`_crash`, one clock: the rush up the lane to `blocker_cell`, the bonk, the
  crumple, the flutter home) and a heart splits on the paper pill in a 64 px
  strip over the panel; `busy()` holds input, Undo, Hint and Reset while it
  plays. Out of hearts: the planes droop (`_droop_at`, a still-mesh rebuild a
  frame for 0.5 s), dusk, the card with `PP_OUT_BODY`/`PP_OUT_REST`, Try
  again (Reset's wave, clouds blown back, hearts full), One more heart.
  **Windy Day** is drawn on its own layer (`_sky_layer`, so the sock's sway
  and a glide never rebuild the field): one cloud mesh (puffs traced as a
  single outline so the 0.8 alpha shows no seams) under a transform per
  cloud, a twin drawn while one wraps, a ghost mesh of dotted rings at
  `cloud_cells(count() + 1)` rebuilt only when the count moves, and the sock
  (pole in the still mesh, sleeve on the sky layer). The clouds are drawn
  at a continuous count (`_cloud_k`) that glides to the glide's own end
  (`_glide_to`), never straight to the state's count -- the first cut read
  the state and jumped a whole cell, because the state ticks on the tap
  before the glide is asked for. A stuck sky (`State.stuck()`) says
  `PP_TIP_STUCK` once a count, the pill breathes, and a cloud tap gusts.
  Input follows Fairy Lights' review (fde0e7a): one finger, the plane goes
  on release from the plane pressed. Hooks for the rewards pass:
  `_on_launched`, `_break_streak`, `_reset_rewards`, `_party`; the
  `completion_record` keeps `hearts` and `flawless`. Harness:
  `tests/_shot_planes.gd` (modes in its header).
- **The polish, rewards (2026-09-30, spec section 4; numbers in section 7,
  calls in section 8).** The hooks are filled: `_on_launched(i, gag)` (the
  streak, the bubble, confetti, the countdown), `_break_streak`,
  `_reset_rewards`, `_clear_gags` (undo, Reset and Try again) and `_party`.
  **A gag shapes the flight itself**: `_flight(i, gag)` returns the flight
  dictionary, and a loop is a circle spliced into the track (`_track` reads
  `_fly[i]["loop"]`) with its own time warp (`_s_at`/`_tau_at`, which every
  timing reader now goes through -- covers, the leaves' flutter, the
  contrail, the puff -- instead of `_ease_inv` straight), so the body runs
  round the loop like a ribbon and an undo mid-loop flies home back round
  it; a roll is a slower flight whose dart's wings scale through -1. The
  bird, hearts, flock, straggler, bubble and seal live on a life layer
  (`_life_layer`, z 3) as moments drawn through transforms of cached meshes;
  Windy Day's gold clouds are a second cloud mesh on the sky layer.
  `PaperPlane.dart` takes `shadow := false` for darts that turn over in the
  air. `force_gag` is the harness's switch. Harness modes `right` and
  `solve` (any band) in `tests/_shot_planes.gd`.
- **Review findings, fixed (2026-09-30**, polish spec section 8). A judged
  tap is refused for free when its blocker is not on screen yet (a plane
  still flying home after Undo, Reset or Try again, or a cloud still
  gliding to the count the state already reads: `_unseen_block`). The host
  is told after `busy()` is set and again by `_process` the frame it ends
  (`_was_busy`), never by a timer, which fires up to a frame early. A Windy
  Day hint goes dark on every tick; no gag sound plays once the hearts are
  gone; Undo lets go of a held press; `_sky_shown` keeps the sky's meshes.
- **The maze (2026-10-02).** The user's second reference (a phone screen
  packed nearly full of long, bent arrows -- the original SETAS screenshot
  in the concept tab was this dense too) said the 0.72-0.91 sky of short
  darts was too easy and not a maze. Easy, Medium and Hard are now **12 x 17,
  16 x 23 and 21 x 30** (cells ~76 / ~55 / ~40), carved by
  `_carve_maze` in `puzzles/planes_state.gd` to **0.95-0.98** of the field
  (GDScript, 20 seeds a band: 0.974 / 0.975 / 0.978; 37 / 50 / 74 planes;
  6 / 14 / 36 ms a board, worst 60), planes up to 15 / 22 / 29 cells whose
  tails walk straight on with `straight` odds. The carve gives every plane
  a **launch key** (highest flies first): a new plane fits anywhere in the
  order where it goes after every plane in its own lane (`hi`) and before
  every plane whose lane crosses its body (`lo`), `lo < hi`, and takes a key
  between (keys renumbered to ranks after each, so halves never run out).
  That is the replay proof, and it is what lets the leftovers fill where the
  backward carve (a new plane only at the front of the order) stalled near
  0.8: after the drawn placements every empty cell is offered as a head
  (three passes), then tails grow into empty neighbours no later-flying
  lane crosses. `order` is the keys, highest first. The JS prototype
  measured the player down to two launches or fewer on ~40% of steps (20%
  before), ~3 free at a time (6 before). **Insane keeps its banked Windy
  Day sky** (10 x 14, mined offline against the 62-plane exact search):
  making it a maze means re-mining the bank with a new miner, not done.
- **The board checkup (2026-10-02).** The still mesh (panel, glows, every
  plane at rest) was built whole in script whenever the set of moving planes
  changed -- every launch, landing, beat, press and idle flutter: 14-18 ms a
  time on the old Insane, 28-38 on a Hard maze. Now `_rm_still` (a
  `RunMesh`) holds the panel and every plane's look (`_look_id(i, droop)`,
  a droop step of ten) as shapes made once a layout, each in a run laid in
  `_lay_still` and put once there so the runs' offset indices are worked
  out while the board opens (~50 ms then on a Hard maze, nothing after);
  the glows are a Builder between. The ground (every dot and leaf at rest)
  is its own mesh keyed on which planes stand, fly or have gone
  (`_ground_key_now`), so a frame of flight draws only the dots under a
  flight and the leaves one passes (`_passed`). The entrance popped every
  plane in live (30 ms frames on a Hard maze): a popping plane is its look
  under its pop (`_pop_xf`, its 0.1 s fade not carried) in its own run of
  the still mesh; a plane that only beats, shivers, nudges or flutters is
  its trail alone (`_trail_id`), slid, on `_rm_live` (no runs, the same
  shapes through `RunMesh.share_shapes`), with its dart drawn live. The sky
  layer's clouds and sock were a draw call each: now one mesh a frame
  (`_sky_put`, colours faded once per alpha, indices offset once per place).
  Figures in `docs/agents/checkup.md`.
- **The tutorial** (`ui/hud/planes_tutorial_diagram.gd`) plays a quietened
  board (`TutorialSky`: no sounds, tips, idle flutter, gags, streak, party
  or card; a crash never runs the hearts out) on a hand-made 6 x 5 sky of
  seven planes laid by `lay()`. Pages: LAUNCH, then REFUSE (Easy/Medium:
  a blocked plane waits for free, then the one in front goes and it
  follows) or ORDER and HEARTS (Hard/Insane: the crash and a heart), WIND
  (Insane: the cloud in C's lane blows past after B's launch), DONE (the
  last two planes and the solve wave), UNDO (Reset alone on Insane, where
  there is no Undo), HINT (bands with hints).
- Probe: `tests/_probe_perf.gd -- planes d=<0..3> [fill]` taps the deal's
  own order, each plane on its head; `x=pp_count` times a field and a still
  build every 1.5 s, with the dots', leaves', contrails' and planes' share.
- **Insane counts moves (2026-10-04,** `docs/agents/flat-screens.md`,
  "Insane counts moves"**).** `State.HEARTS` is `[0, 0, 0, 0]`, so `judged`
  is false on every band: a tap on a blocked plane is Easy's refusal (the
  lane flashes, nothing is spent) on Windy Day too, and the crash, the
  hearts and their pill are left in place, dormant. Windy Day hands out
  `State.moves_budget()` = `shortest_solve()` + max(3, a quarter of it,
  rounded up); the shortest solve is the plane count, a true optimum (a
  launch a plane, and the stored `order` replays with no gust): 19-28
  planes over the bank, budgets 24-35. A launch costs one and **a gust
  costs one** (it cost a heart; `_gust_left()` asks for a move where it
  asked for a heart, and `PP_TIP_STUCK_MOVES` says so). Since every plane
  flies exactly once, **the slack is only ever spent on gusts** -- five to
  seven of them, where two hearts bought two gusts or crashes; say if a flat
  slack of three reads better. Out of moves is `out_of_hearts` and the old
  droop; the card takes `MOVES_BONUS` (5); Reset and Try again hand the
  budget back; `capabilities()` is empty on Insane; the tutorial shows
  REFUSE in place of ORDER + HEARTS on every band and ends on
  `MovesDiagram.page`; the completion record keeps `moves_left`. New keys
  at the end of `locale/boards.csv`: `PP_RULES_WIND_MOVES`,
  `PP_TIP_STUCK_MOVES`. Kept: the refusal's lane flash, the dotted rings
  where the clouds go next and the stuck line, all read off the sky. Not
  updated: `PP_LVL_3` still says "two hearts".

- **Insane is Hard's maze with the wind over it (2026-10-12).** The user:
  "the insane is not carrying the same board like of hard"; asked, they
  chose Hard's maze plus wind over a bigger maze with none. `BANDS[3]` is
  Hard's row and `"clouds": 12`; the carve is the maze's, and
  `_stand_clouds` then picks the wind and the clouds (never more than two a
  row) until `has_moments()`: every plane's lane clear of them on some tick
  of their 21-tick round, one cloud fewer after `CLOUD_DRAWS` failed draws.
  The maze's order never depended on the clouds, and a gust is free since
  the counter went the same day (`_gust_left`, `PP_TIP_STUCK_FREE`), so no
  sky dead-ends: `tests/test_planes.gd` plays five of them with any free
  plane and a gust when none can fly. The bank (`content/insane/
  planes.json`) is no longer dealt; `from_bank`, the exact search and the
  miner stay, on `WINDY_SMALL` (the old 10 x 14 row). `solve_order()` on a
  windy maze is the carve's order (past the search's 62 planes), and
  `restore_completed_board` sweeps what a cloud held back. Six seeds:
  68-78 planes, 12 clouds, 35-52 ms to carve, 11-18 planes cloud-held at
  the deal, 7-17 gusts in a random play. One window, `d=3 stuck` on
  opengl3_angle: stuck after 11 greedy launches, the free tip, 74 draw
  calls. Mine, the user's to call: 12 clouds, and that a gust is free.
  Not played through by hand, no phone; the tutorial's WIND page unseen on
  the new size. `tests/_shot_planes.gd`'s `solve` and `cloud` modes were
  written for the small banked sky and are unrun on the maze.

- **The forgiving finger, and three motions (2026-10-12).** The user: "add
  some better animations to the paper plane game, and a helper to user click
  to avoid needing a exactly touch". **The finger.** The press took the plane
  whose cell it landed in, and a drag or a release that named another cell's
  plane dropped the launch without a word: on a 40 px Hard cell a thumb
  rolling a few pixels did that, and a tap on a dart's tip (half a cell into
  the next cell, most often another plane's body) took the wrong plane. Now
  `_target_at` takes the nearest plane within `TOUCH_REACH` (0.8 cell) of the
  finger, measured to its body's line and its dart out to the tip
  (`_reach_to`), a plane that can go counting `TOUCH_FREE` (0.3 cell) nearer
  than it is; under half a cell on purpose, so the middle of a cell is always
  that cell's plane (`tests/_win.gd` and the perf probe tap there). A held
  finger is its press until it is past `TOUCH_SLOP` (0.45 cell, never under
  22 px) of where it went down *and* names something else (`_strayed`). No
  band judges a tap, so the worst a generous finger does is show a lane.
  **The press** was a sink to 0.94 about the body's middle (two pixels, under
  the finger): the dart now lifts (`PRESS_LIFT`, its shadow falling away),
  the trail keeps its shade, and **the way it would take is laid down its
  lane** in `SUN` at 0.35 (`_way_ahead`: to the edge of the first cell
  something stands in, or the grid's edge), which is the mock's held-finger
  lane, struck in Task 6 when the board acted on press-down. Under reduce
  motion the lane and the shade are simply there while the finger is. **A
  refusal** leaned the plane three pixels: it now runs up its lane until its
  nose meets what is in the way and springs home (`_bump`, a fifth book;
  `_bump_s`; 0.07-0.26 s out, 0.3 home), the nose folding as it meets it, the
  band and the blocker's shiver (a cloud's swell) timed to the meeting. It
  holds nothing, and a plane freed in the middle of it launches from where
  it is. The crash (dormant since Insane counts moves) is untouched. **In
  flight** the dart stretches with its speed (`STRETCH`), read off the
  flight's own curve, so no flight is longer and `WIN_WAIT` stands. No new
  draw call: the lane is in the live field mesh. A throwaway headless probe
  (deleted): every occupied cell's centre names its own plane on three bands,
  a free plane's tip a tenth into the next cell is its own, a 15 px drift
  still launches, a slide three cells off launches nothing, the run goes out
  and home and is retired; suite 249797/0; `tests/_win.gd -- planes` PASS;
  `tests/_shot_planes.gd` on opengl3_angle at 810x1440: `d=1 refuse` (its
  mode shoots the run now) and `d=2 press` twice, 84 draw calls peak both.
  Mine, the user's to call: the reach, the pull toward a free plane, the
  slop, the lane showing where a blocked plane stops before the finger
  lifts, the run in place of the lean, the stretch. No phone; the tutorial's
  pages unseen (REFUSE now shows the run, every press its lane); no new sound
  (the refusal's cue plays at the tap, not at the meeting). `_nudge` is gone
  (the run was its only reader's writer); 84 is a reading, not a comparison
  with the commit before.

### The air above the clouds is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/planes_world.gd` is pale blue at the top
turning to cream, the card's lattice of dots across the sky, a small cloud
and a folded plane on a dotted way in the gap of the tools row, flat
clouds half off the sides, and a sea of cloud in three scalloped bands at
the foot with two planes skimming it; five glints breathe. The board's
clip goes off on the first `set_clear`: **a launched plane flies on to
the edge of the screen**, under the host's rows. Height binds, so the
panel stands 36 to 50 inside the margin, with 56 kept open under it.

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 77 draw calls at rest; `tests/_win.gd --
  planes` passes.
- Decided for the user, unconfirmed: the 56 open foot; planes flying out
  across the screen; the dusk of spent hearts dimming the world too.
  Owed: a phone, Insane's wind sock against the tools row, the level slide.

### Insane is the day's shape, and the clouds are gone (2026-10-16)

The user, with a screenshot of an arrow maze cut into an apple: "paper
planes insane should not have the clouds anymore, it should only be a
bigger harder board, also it could carry different shapes based on the day
theme". Insane is now Hard's carve with no wind, inside a silhouette
(`PlanesState.shape`, `live()`): the day's themed thing (the first of
`SHAPE_SIZES` this phone holds, `ThemedPictures.picture`), else one of
Pixel Garden's single things (its 10 and 12 bands), picked by
`Daily.fnv1a("planes_shape|<day>|<step>")` so every phone cuts the same.
`cut_shape` trims the picture to what it covers and scales it, cell centre
by cell centre, into `SHAPE_BOX` (30 x 42) on its own proportions; a cut
under `SHAPE_MIN` (630, Hard's whole board) is passed over -- 27 of the
bank's 60 things pass, a flat or thin themed thing falls back to the bank.
A plane only stands inside the shape; its lane still runs to the grid's
edge over the bare sky round it. The board tints the shape a shade deeper
than the paper (a rect a run of cells in the panel mesh), and dots and
leaves stay on it. Undo is back on Insane (`undo_allowed = not windy()`),
and the tutorial's WIND page and Reset-only page follow `windy()`.

- Twelve seeds on the Mac: 30 x 30 to 30 x 41 boxes, 648-941 cells,
  69-119 planes (Hard 68-78 on the same seeds), 0.97-0.98 cover, 38-79 ms
  to carve; every stored order replays.
- `opengl3_angle`, 810x1440, `_shot_planes.gd d=3 rest`: 76 draw calls
  peak, cell 32 px in the 1080-wide board (Hard's ~45).
- A cut that fills over `SHAPE_FILL` (0.9) of its box is a block, not a
  shape (the old scene pictures at 24/32 cut a plain 30 x 30): passed
  over; 26 bank things deal. The Mac's four themed-pixel days, cut
  headless: 20261014 deals the 16's sunflower, 20261018 the 10's mug,
  20261019 the 32's fruit basket, 20261015 (shell, crab, a scene) falls
  back to the bank. A phone holding the day's document and one without it
  deal different Insane boards, as Pixel Garden's do.
- Two of twelve seeds came out at or under Hard's plane count (mushroom 69
  against 76): the floor guarantees cells, not planes. `SHAPE_MIN` ~700
  would keep about 18 bank things and put every seed over Hard.
- The Windy Day engine, `WINDY_SMALL`, the miner and the windy tests stay;
  no band deals them. Removing them is the user's call.
- Decided for the user, unconfirmed: the 30 x 42 box (smaller cells than
  Hard), the 630-cell floor and the bank fallback on a flat themed thing,
  `max_len` 29 as Hard, the tint, undo back. Owed: a phone, a themed day
  seen (none checked on this Mac), the shape read on a 12-side bank thing
  scaled 2.5 times is blocky.

### Every band is the day's shape (2026-10-20)

The user: "paper planes should have a themed shape on all difficulties".
Each `BANDS` row now carries a `box` and a `least`: Easy, Medium and Hard
cut the day's thing into the grid they dealt before (12 x 17, 16 x 23,
21 x 30, so their cells keep their size) and ask half the box; Insane keeps
`SHAPE_BOX` and `SHAPE_MIN` (Hard's whole board). `build` cuts for any row
with a `box`, so the `shaped` flag is gone. The bank fallback now picks among
`shared_things()`, the things every band's box deals (23 of the bank), so
a day's four bands cut the same thing; this changes which bank thing
Insane deals on a given day. The themed thing is taken at the first of
`SHAPE_SIZES` that cuts a shape in every band's box, else the day falls to
the bank on all four, so the bands never split between the two. Easy-Hard's
level labels (`PP_LVL_0..2`) now read "The day's shape: a maze up to ...",
as Insane's did. A completed board restores by solving the fresh deal, so a
board finished on the old rectangle reopens solved on the shape.

- Twelve seeds on the Mac, planes (old rectangles in brackets): Easy 16-26,
  102-142 cells; Medium 22-38 (shapes 192-247 cells); Hard 37-62 (old
  68-78), 326-440 cells; Insane 75-106. Carve 4-7 / 7-13 / 19-33 / 46-62 ms.
  Every stored order replays.
- Days 20261014/15/18/19/20 headless (no Backend, so the bank): gnome,
  pear, acorn, pepper, honey pot, the same thing on all four bands.
- `_shot_planes.gd d=0 rest` on opengl3_angle: 76 draw calls peak; the
  shape reads, blocky at 12 cells across.
- `test_planes` checks each band's deal for a shape, the box, the floor
  and planes on live cells; its check count fell 208319 -> 122934 (smaller
  boards), the suite 248522 -> 163137, 0 failed.
- Decided for the user, unconfirmed: the boxes stay the old grids (so the
  lower bands hold about 60% of their old planes; a bigger box would mean
  smaller cells), half the box as the floor. Owed: a phone, a themed day
  seen.
