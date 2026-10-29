# Domino Patio

- **Domino Patio is a Puzzles card (2026-10-22, unattended)**, the roadmap's
  third: lay the house's dominoes on a patio of flower beds so every bed
  keeps the rule on its tag. Logic (numbers live inside Logic). Spec
  `docs/superpowers/specs/2026-10-22-domino-patio-design.md`. The genre's
  own name, and the same word for a tile's dots, are never used: they are
  spots.
- Files: `puzzles/patio2d.gd` (the board, extends `core/puzzle_base.gd`),
  `puzzles/patio_state.gd` (placements, beds, Undo, the bulb's move),
  `puzzles/patio_gen.gd` (the day, the counting solver),
  `puzzles/patio_world.gd`, `ui/hud/patio_tutorial_diagram.gd`,
  `ui/menu/cards/patio.gd`. The tile is `ui/faces/domino_tile.gd`, lifted
  out of `versus/dominoes_board.gd` (which now calls it) so both boards and
  both cards share one drawing.
- **A tile is drawn where the rules put it**: `_process` compares each
  tile's `[at, dir]` with the place it was gliding to (`_key`) and starts a
  glide from where it was shown last frame (`_last_pos`) when it changed.
  So a drop, Undo, the bulb and the bin need no animation code of their
  own. A turn is `Motion.turn_angle` on the new mesh.
- Input: a press on a tile (patio by square, rack by bay), a move past
  `TAP_PX` lifts it (`_press.moved`), the release lays it at `_drop_at`
  (nearest fitting pair within `REACH`), refuses it over the patio, or
  sends it to its bay. A release without a move is `_tap`, a quarter turn.
- **A turn on the rack is no move**: it pushes no history, and `undo()`
  keeps the way a tile still on the rack was turned.
- The answer is the bulb's only (`hint_move`): solved is the beds' rules
  (`State.solved`). `right(t)` treats a tile turned end for end inside one
  bed as right.
- **The board is its own tutorial**: `demo` set before it enters the tree
  makes it silent and deaf; the diagram lays tiles with `demo_lay(t)` and
  turns with `demo_turn(t)`. Lessons LAY, TURN, BEDS, BOUNDS (Medium on),
  SPARE (Insane), HINT.
- Sounds: `tools/gen_sfx.py` set `patio`, bank pops plus Birdsong's takes
  copied into `build/sfx_raw/patio/`. Unheard.
- Harness: `tests/_win.gd -- patio` (real touches: turn taps on the rack,
  drags onto the patio, one tile dragged off and laid again, one bulb);
  `tests/_shot_patio.gd -- <dir> d=<0..3> [tut|card]` shoots rest, held,
  half, refuse, broken, the win, the reopened day and the card, with draw
  calls. `tests/_probe_patio_gen.gd -- n=<seeds>` times the generator.
- Seen windowed on ANGLE at 810x1440: Medium and Insane at rest, a tile
  held, half laid with ticks, a refusal, a broken bed, the win and its brain
  report, a solved day reopened, the first tutorial page (Insane), the card,
  and a level change from Medium to Hard (`tests/_probe_level_slide.gd --
  patio to=2`: the world still, the board slid, one board left).
  Draw calls: Medium 114 rest, 132 at most in play, 200 on the win; Insane
  159 rest, 188 in play, 269 on the win. `tests/_probe_insane_hints.gd --
  id=patio seeds=4`: 0 failures, every day carried by the bulb. Not seen: a
  phone, reduce motion, Easy and Hard on screen, pt/es read by a speaker,
  the sounds heard.
- Open, the user's to call: everything in the spec's section 7, in
  particular the worst generation time (~260 ms on this Mac on Hard and
  Insane, over Quilt's 194 ms gate) and Insane's many lone-square beds.

### Made fun (2026-10-29)

The user: "make mini golf and domino patio experience way better to play,
and game itself way funnier to play, right now nobody likes it",
autonomous, push when done. References from the web: Defector's review of
the genre's daily ("the rush" is working out *how*, the a-ha of a mental
map before the exact placement; Hard looks overwhelming on a phone);
bossrush.net's and other solving guides (start from the most restrictive
bed, single squares and lone-square outcrops force a tile, count the
numbers you hold). Nothing in the references says the board should flag a
wrong bed; this board already does, from the rules alone.

**Measured first** (`tests/_probe_dp_fun.gd`, 40 days a band, the answer
laid in a random order, the bulb read before each tile): with the rules
alone and one step ahead (`State.lives`: neither bed broken, and no free
square beside it stranded), a reading that can honestly say "only one" --
a square only one tile can cover (`State.ways`) or a tile with only one
place (`State.places`) -- stands at 62-65% of readings on Easy, 63-68%
Medium, 70-74% Hard, 79-81% Insane (first-order only, without the step
ahead: 49/46/68/74%). The rest name the tile with the fewest places,
which is the guides' first tip. 70-82% of tiles laid keep a bed. A reading
is up to 54 ms on this Mac (a memo of judged places; 151 ms without), so
it runs on the press, on the frame.

**What changed**:

- **The bulb teaches in two presses** (`hint`, `_lay_hint`, as Paper Box):
  the first reads (`State.read_hint`: a bed already broken -- its wrong
  tile goes; a square only one tile can cover; a tile with only one place;
  else the fewest), rims the squares the tile goes to and the tile itself
  in sun (the lone square thicker), and the toast says why
  (`DP_READ_*`, tiles named `a|b`), for one hint; a second press lays it
  free. Any move by hand, or Undo, puts the reading out. The Spare laid
  in a bed it breaks is read first and goes back to the rack
  (`at` -1, `DP_READ_AGAIN_MOVE`; `_probe_dp_fun.gd` checks it, 20/20).
  On Insane, when the toast falls back over the rack's top and the read
  tile is in the first row, it stands at the foot instead. The tutorial's
  HINT page presses twice.
- **A broken bed says why** (a tile laid or turned into it) on the toast (`State.bed_why`, `DP_BAD_*`:
  over its sum, short of it, not under, not over, two numbers that differ,
  a number twice) and its squares are rimmed rose while the toast shows;
  mended, the toast goes.
- **A bed's running sum**: a sum, under or over bed of two squares or more
  with spots in it shows what it holds so far in a small chip under its
  tag (the bed's own deep ink, a number, never a shade of the bed).
- **The drop is judged before it is made**: the held tile's ghost is rose
  where it would break a bed and sun where it would fill one to its rule
  (`State.try_drop`), leaf otherwise.
- **The bed lines are drawn again over the laid tiles** (`_draw_lines`,
  one cached mesh, 5 px at 0.95): a tile's halves had hidden which bed
  they lay in.
- **Live stars** (`star_line.gd`) over the patio, by slips: beds broken by
  a tile laid and bulbs read (`STARS_CUT` [0, 2]). The party's toots need
  three stars (they needed no bulb and no refusal).
- **Runs**: a tile that keeps a bed and breaks none carries the run on; the
  "bed" cue climbs with it; three in a row, or one tile keeping two beds at
  once, gets a big word and a spray of stars (`DP_W_RUN`, `DP_W_TWO`,
  `DP_W_MANY`). The win names the best run (`DP_WIN_RUN`).
- The toast is the shared `ui/flat/toast_card.gd`, under the rack, or over
  the rack's top when there is no room (Insane). The old word over the
  rack (`_draw_say`) is gone; "A bed's rule is broken" (`DP_ALMOST`) is on
  the toast.
- Deals, bands, the rules and the sounds unchanged. en/pt/es.
- Harnesses: `_win.gd -- patio` checks both bulb presses and a tile laid
  where it breaks a bed (toast, rims, the star count) then dragged off;
  `_shot_patio.gd` shoots `hinted`. `opengl3_angle` 810x1440: Medium 122
  rest, 145 at most in play, 211 win; Insane 131 rest, 154 in play, 220
  win. `_probe_insane_hints.gd -- id=patio seeds=4`: 0 failures. Unseen on
  a phone.
