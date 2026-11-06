# Hosepipes

- **Hosepipes is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  eleventh, a path board under Space. Taps and flowers on a raised garden
  bed; drag a hose from each tap to its flower, hoses never share a square,
  and every square must be watered. Spec
  `docs/superpowers/specs/2026-10-22-hoses-design.md`. The id is `hoses` and
  the locale prefix `HS_` (`HP_` is Horse Pen's).
- Files: `puzzles/hoses2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/hoses_state.gd` (hoses, strokes, cut and grow-back, Undo, the
  bulb's hose), `puzzles/hoses_gen.gd` (the deal, the solver, the bank's
  encoding), `puzzles/hoses_world.gd`, `ui/faces/hoses_art.gd` (soil, frame,
  hose, tap, flower, seed, halo, the pair marks and the colour order),
  `ui/hud/hoses_tutorial_diagram.gd`, `ui/menu/cards/hoses.gd`; the miners
  `tools/insane/hoses_ladder.gd` (Insane) and `hoses_hard_ladder.gd`.
- **The deal grows hoses, it never cuts a walk**: every square a hose of
  one, neighbouring ends joined shortest first, never so a hose runs
  alongside itself (`_grow`, `_touches`). Pieces of one random walk nearly
  always ran alongside themselves and were almost never unique.
- **The proof is uncapped and pruned** (`Solver._ok`): an empty square
  with fewer than two ways in, an open hose with no move, a patch of empty
  ground no open hose can both enter and finish in, a seed nothing can
  reach. Change a rule in `hoses_state.gd` and the solver must change with
  it: the win is exactly what the deal proves (every flower joined and
  every square watered).
- **Hard and Insane are banked** (240 and 225 days, `InsaneBank`), Easy and
  Medium dealt on the phone (365 days each, none failed, worst 37 and 134 ms on
  the Mac; the same seed deals the same bed, the probe checks it). A day that
  stalls is dealt again from seeds its own rng hands on (`State.deal`). Re-mine with
  `godot --headless --path . --script tools/mine_insane.gd -- hoses_hard 240 280`
  (and `-- hoses 240 300`); `tests/_probe_hoses.gd` re-proves both banks.
- **A stroke keeps its start** (`_before`): every step the other hoses are
  that start cut at the first square the live hose holds, so a cut grows
  back when the finger backs off. `end_stroke` turns a hose of its end
  alone into no hose, so a press and lift on a tap is no stroke.
- **The drag is walked a square at a time** toward the finger, the longer
  axis first and the other when that is refused (`_drag`); a finger slid
  back over its own hose cuts it there (`back_to`). A refusal sounds once a
  square under the finger (`_refused_for`).
- **Meshes**: the frame and soil are one mesh keyed by the watered squares,
  the hoses one keyed by the hoses, the ends one rebuilt only while one
  moves (shapes laid in by `_put`, never a mesh a piece). The head's halo is
  kept as a member: a mesh made in `_draw` and dropped is freed before the
  frame renders ("Parameter mesh is null").
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram drags with `demo_press`, `demo_move` and
  `demo_release`. Lessons JOIN, WATER, CUT (a straight run from another tap
  into the first hose, `run_into`, and back), SEEDS (Insane only, a fixed bed
  from the bank, never today's, which would spoil the answer), HINT.
- **Draw calls**: 78-93 in play on Medium, Hard and Insane (ANGLE agreeing
  on Hard), 141-144 on the win with the report, 85 a tutorial page, 8 on
  the card.
- Harness: `tests/_win.gd -- hoses` (real touches: bare soil pressed, the
  longest hose drawn, another tap dragged across it and back (cut, grown
  back, no stroke counted), a stroke and its Undo, the bulb, then every
  hose); `tests/_shot_hoses.gd -- <dir> d=<0..3> [tut=<page>|card]` shoots
  rest, drawing, cut, joined, undone, hinting, hinted, midway, the win and
  the reopened day.

## Made fun (2026-10-28)

The user: "make hosepipes experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, push when
done. References, by genre (the classic path-pair games; never their names):
reviewers praise the tactile drag and a sound for each join, and the
"perfect" of one stroke a pair, with the share of the board filled kept
apart from it; the genre's complaints are boards that need a guess with no
word on a mistake, and the full-fill rule making perfect play tedious on
large boards.

**Measured first** (`tests/_probe_hs_fun.gd`, headless, 40 beds a band,
`puzzles/hoses_reader.gd`): a player reading one square at a time (a square
whose free sides are exactly the links it still needs takes them) gets
94% of an Easy bed's links on average, 76% Medium, 61% Hard, 20% Insane
(live-dealt beds of the same bands), and never a wrong link. So the bulb
can say why most of the time, and Insane's beds ask for reading past one
square. The deals are unchanged.

**What changed:**

- **Water runs only through a joined hose** (`_wet`): the soil under a
  hose stays dry until its tap reaches its flower, then darkens square by
  square from the tap as the drops run, and each wet square sprouts a tuft
  of grass in a corner (`Art.sprout`, `GROW_TIME`). The count line's
  "watered" share counts joined hoses' squares (`_watered`). On the win
  every tuft opens a cream daisy in a diagonal wave; a reopened day stands
  in bloom. Grass and cream, never a hose's colour.
- **Joins climb**: each join's cue a step (`JOIN_STEP` 0.05) higher than
  the last, its ring a little bigger. No new sounds.
- **The other end pulses** while a hose is in hand (the halo mesh,
  `PULSE_TIME`); on Seedlings every bare seed does.
- **Live stars** under the count line (`ui/flat/star_line.gd`, `_rate`):
  three while strokes + hoses the bulb laid are at most one past the hoses,
  two up to four past, one beyond (a reading alone costs no star, so drawing
  the read hose yourself costs what letting the bulb lay it does). Read off strokes only, never the answer, so a
  star never falls to say a hose is wrong. **A stroke on the same hose as
  the one before is not counted again** (`State._last_drawn`, the genre's
  moves: a hose drawn in two goes is one); a laid hose counts as drawn.
  Reset keeps the day's strokes. "Every hose in one go" still means
  strokes <= hoses.
- **The bulb teaches in two presses** (`_read`, `_why`): the first reads the
  bed from the links the player has right (`State.right_links`) with
  `hoses_reader.gd`, rims in sun the square that decides a hose and softly
  the squares it must link to, and says why (`HS_WHY_TAP/FLOWER/SEED`,
  `HS_WHY_CORNER`, `HS_WHY_LAST`, then `HS_WHY_AGAIN`) for one hint, the
  toast standing while the reading does. A second press lays that hose,
  free. Where no square decides anything, it rims the first wrong pair's two
  ends (`HS_WHY_PAIR`). Any stroke that changes the bed, Undo or Reset puts
  the reading out. `hints_held()` is the badge, `hints_left()` counts the
  reading. The tutorial's HINT page presses twice.
- **All joined but dry**: the dry squares are rimmed in sun and the toast
  says what it means (`HS_SAY_DRY` + `HS_SAY_DRY_HOW`).
- The count line takes two lines for a toast (`|` between keys in `_say`);
  `COUNT_H` 150 for the stars. `HS_RULES_STARS` and `HTP_HS_HINT_BODY` in
  en/pt/es.

Draw calls on opengl3_angle, 810x1440, Insane: 75-93 in play, 85 with a
reading, 141 on the win (Medium on the default driver 79-94, 144).
`_win.gd -- hoses` PASS (the bulb reads, nothing laid, then lays); suite
303252/0.

Decided for the user, unconfirmed: the star thresholds, the second press
free, soil dry under an unjoined hose, sprouts and daisies. The reader
ignores the player's wrong hoses, so a reading can rim a square a wrong hose
lies on and call its sides free (the second press cuts and lays, so it
resolves). The tutorial's HINT page shows the rims without the words (a
demo has no count line); its caption says it. The all-joined-but-dry rims
have no harness mode and are unseen. Owed: a phone
(the drag on a diagonal flick, the pulse), the pitch climb heard, pt/es by a
reader.

## The day's theme (2026-11-06)

Wave 2 of the daily theme roadmap (`docs/superpowers/specs/2026-10-13-daily-theme-design.md`,
memory `daily-theme-roadmap`). The user: "start integrating the daily theme
into all games, get the next on the list", autonomous. The genre's own
shaped-board spin-off (never named) keeps the same rules on boards that are
not squares and is among its best-rated, so a bed cut to a shape is in
keeping.

- **Easy and Medium are cut to the day's thing** (`Gen.THEMED_SIZES`:
  Easy the 10 first, Medium the 12): `Gen.shape_fit` is Horse Pen's and
  Hedgehogs' cut (`PlanesState.cut_shape`, `HHGen._smooth`, its largest
  piece), centred in the square of its longer side (5-6 Easy, 6-7 Medium),
  kept when it holds at least `SHAPE_MIN` 0.7 of the band's square and at
  most `SHAPE_MAX` 0.88 of its own. Outside it is `void`: no hose, no water,
  never counted (`State.squares()`), never a way in the solver
  (`Solver` owner `VOID`, its neighbours dropped) or the reader (`need` 0).
  The deal grows hoses on the shape alone and turns down a bed whose longest
  hose takes over `LONGEST` 0.34 of it (the roadmap's "floor on hose count":
  a thin shape snakes one hose through). `THEME_TRIES` 120 cuts a thing
  before the next, then the square, off a copy of the day's rng, so the
  square deals as before.
- **Hard and Insane stay on their banks.** Measured on 24 cached nights
  (`tests/_probe_hs_theme.gd`): every band deals a shape every day, but a
  live proof of a shaped 7-9 bed took 0.5-3.4 s on the Mac, and a shape's
  edge decides so much that its beds read through square by square (the
  reader, `hoses_reader.gd`, finished 100% of most themed Hard and Insane
  beds, against 61% and 20% for the banks). Gating them by the reader's
  reach before the proof made it worse: themed beds are bimodal (100% or
  8-63%), so the passing ones were harder than the square and seconds slow.
  Medium is ungated for the same reason, so **a themed Medium reads easier
  than the square's 76%** (23 of 24 at 100%); decided for the user.
- Measured, Mac: Easy 24/24 themed, worst 38 ms; Medium 24/24, worst 236 ms
  (square deals unchanged: 39 and 140 ms, `_probe_hoses.gd`).
- **The board**: the bed is laid by the shape's extent (`_extent`), so a
  shape narrower than its square is centred and as big as it can be; the
  frame follows the shape (`Art.frame_shape`: a plank's width round every
  square, lit where the top faces out, one mesh). A press outside the shape
  is nothing (`cell_at` -1); a drag aimed there walks to the edge and stops.
- **The win**: the soil takes the picture's beads (`Pal.PG_BEADS`, pale ones
  shaded) in the daisies' diagonal wave, the tufts sinking as it comes (no daisies), the hoses ease
  to `HOSE_REST` 0.4 so the picture shows through, the `theme` cue rings
  (wraps climbing an octave, Horse Pen's) with a GOOD knock, the card says
  "Today's bed: %s." (`HS_WIN_THEME`), and the report waits `THEME_HOLD` 0.9
  s more so the picture is seen whole. A reopened day stands painted.
  `day_dict` says `source: theme`, the thing's id and the `void` squares.
- Harness: `tests/_shot_hoses.gd -- <dir> d=<0|1> theme` re-deals on the
  newest cached night and, in place of the menu reopen, restores the won bed
  on the board (`reopen`); `won_paint` is the picture before the report.
  Note the harness boots the real main scene, so a plain run on a day this
  Mac has cached is themed too (20261106's Easy is the Towel, a 4x5 bed), and its menu reopen restored it whole (4 joined, 20 watered).
  The theme run logs one "Parameter mesh is null" on its re-deal frame (the
  world rebuilt and drawn in one frame); plain runs and `_win.gd` are clean.
- Draw calls (opengl3_angle, 810x1440): 78-91 in play, 146 peak on the win.
  `_win.gd -- hoses` PASS.
- Owed: a phone (the shaped frame at a phone's width, a drag along a
  shape's notch), the cue heard, the pt/es lines by a reader.
