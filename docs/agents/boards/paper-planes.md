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
