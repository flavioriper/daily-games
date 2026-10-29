# Paper Box

- **Paper Box is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  twelfth, a mental-rotation board under Space. A paper net on a cutting
  mat and three or four boxes under it; pick the box it folds into, five
  rounds a day. Spec `docs/superpowers/specs/2026-10-22-paperbox-design.md`.
  The id is `paperbox` and the locale prefix `PB_`.
- Files: `puzzles/paperbox2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/paperbox_state.gd` (bands, the deal, the wrong boxes, picks, the
  bulb's strike), `puzzles/paperbox_fold.gd` (the eleven nets, the fold's
  frames, the 24 turns, pictures, the iso projection),
  `puzzles/paperbox_world.gd`, `ui/faces/paperbox_art.gd` (papers, the
  sheet renderer, the box, stamps, hatch, shelf spot),
  `ui/hud/paperbox_tutorial_diagram.gd`, `ui/menu/cards/paperbox.gd`.
- **One fold model serves the rules and the animation.** `Fold.frames(net,
  root, angles)` places every square at its hinge angle (0 flat, PI/2
  shut); the rules read the shut frames' normals and stamp ways, the board
  draws the same frames at the angles of the moment. Change the fold and
  both move together.
- **A wrong box is proven against every turn of the box** (`Fold.pictures`,
  24 keys) and starts from its own random turn, never from the right
  picture (the right box would otherwise be the one the others agree with).
  `tests/_probe_paperbox.gd` re-proves 365 days a band and measures that
  tell.
- **The board runs on its own clock** (`_t`, stood still while
  `clock_held`) and a queue of timed jobs (`_after`), as Teacups' does. A
  harness steps it by calling `_process(delta)`, and must shoot a frame
  after stepping (a shot in the same frame shows the last draw).
- **Meshes**: the shelf and the net at rest are cached by key; the boxes,
  their shadows, the hatch and the ring are cached by key and size and let
  go at the end of a `_draw` that no longer used them (never in
  `_relayout`, which ran between a draw and its render and freed meshes
  still on the canvas: "Parameter mesh is null"). The fold is one mesh a
  frame, kept as a member until the next.
- **The board is its own tutorial**: `demo` makes it silent, deaf and laid
  in its own rect; the diagram taps boxes with `demo_tap`. Lessons FOLD,
  OPPOSITE (an Easy deal), CORNER (a Hard deal), STAMPS (Insane only, an
  Insane deal), HINT; each picks the wrong box of its lesson's kind, then
  the right one, and rests once that box is on the shelf.
- **Draw calls**: 77-92 in play (77-90 on Hard under ANGLE), 107-146 on the
  win with the report, 95-102 a tutorial page, 6 on the card.
- Harness: `tests/_win.gd -- paperbox` (real touches: a wrong box, a tap on
  it again, a tap on the mat's foot that picks nothing, the bulb's real button, then each round's right box with the
  fold stepped through); `tests/_shot_paperbox.gd -- <dir> d=<0..3>
  [tut=<page>|card]` shoots rest, wrong, hinted, each beat of the fold, the
  next round, the win and the reopened day.

### Made fun (2026-10-29)

The user: "make paper block experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, push when
done (read as Paper Box). References from the web: a review of the *Click
the Cube* app (dlgs.uni-potsdam.de) praises showing the fold after an
answer so the player can check their mental work (this board already
folded the right box); *Puzzle Workout*'s cube-net quiz reports *why* each
chosen wrong answer failed (which faces collide), as diagnosis rather than
a second penalty; software3d.com's net puzzle gives a clear wrong verdict,
a retry, and a reveal.

**Measured first** (`tests/_probe_paperbox.gd`, 365 days a band, the
"whys" line): every wrong box has a reason a player can check, read from
the folded box rather than the deal's kind (`State.why`). Easy: all
opposite pairs, 21% of them *bent* (not two apart in a row), so the
sentence has a row and a bent form. Medium: 1825 opposite, 1825 corner.
**Hard and Insane had not one opposite box**: every wrong box was a corner
the wrong way round (or a stamp turned), which the board had no words for.
The probe proves that every corner box reads as one rule: keep its top and
right as they stand, and the left must be the side opposite the one it
shows (100%, keep always top+right). So Hard ties back to Easy's rule.
The gap was not the deals: a wrong pick was struck and counted and said
nothing, the bulb struck a box without a word, and no band had stakes.

**What changed**:

- **A wrong box says why** (`_tell`, `_why_line`): rose rims round the net's
  squares that show it and the box's faces, and a toast at the head of the
  mat (`PB_WHY_OPP_ROW`, `PB_WHY_OPP`, `PB_WHY_CORNER_0/1/2`,
  `PB_WHY_STAMP`, colours `PB_C_0..5` as nouns). A tap on a struck box
  says it again.
- **The bulb teaches in two presses**: the first reads the box `strike()`
  would take (`State.next_strike`), rims it and its squares in sun and
  says why, for one hint; a second press, or a tap on that box, strikes it
  free (`_lay_hint`). `hints_left` counts a standing reading. The
  tutorial's HINT page presses twice (`HTP_PB_HINT_BODY` rewritten).
- **The toast** is `ui/flat/toast_card.gd`, the shared card owed after
  Shikaku, Untangle, Hosepipes and Binairo each carried a copy; only Paper
  Box uses it so far. It stands in the head of the mat (`HEAD` 150 at W,
  the ask's row made taller; the ask fades while the toast shows). pt/es
  corner lines run to three lines and just clear a three-row net.
- **Live stars** (`star_line.gd`) beside "Box n of 5", by the day's wrong
  picks (`STARS_CUT` [0, 2]: none 3, up to two 2, more 1); the wrong-pick
  count left the line (the stars say it).
- **Runs**: a box right first time climbs `RUN_STEP` in pitch on the
  "made" cue; from the second in a row a big word over the turned box
  (`PB_W_RUN`, `PB_W_ALL` at five) and a spray of stars
  (`arcade/rewards.gd`, as Untangle). A first-try box wears a gold star on
  the shelf, and on the win the line names the best run
  (`PB_WIN_RUN_ONE/N`, kept short: the longer line ran off the screen).
- The tutorial's silent board rims too (no toast): the OPPOSITE and
  CORNER pages rim the pair the struck box gets wrong. Any tap puts a
  standing reading out (as Binairo's), except a tap on the read box,
  which strikes it free.
- Deals, bands and the fold are unchanged. No new sounds.
- Harnesses: `_win.gd -- paperbox` checks the toast and the fallen star on
  the wrong pick and the bulb's two presses; `_shot_paperbox.gd` shoots
  `hinted` (the reading), `hinted2` (the strike), `run`, and takes
  `lang=<pt|es>`.
- opengl3_angle 810x1440: 84-98 draw calls in play on every band (Easy 87), the
  win 143-146, a tutorial page 99. `_win.gd paperbox` PASS; suite
  303252/0. Unseen on a phone.
