# Sunbeam

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Sunbeam is the twenty-second card** (2026-09-26, `puzzles/sunbeam2d.gd`,
  spec `2026-09-26-sunbeam-flat-design.md`, mock
  `docs/brainstorm/concepts.html#sunbeam`). A greenhouse floor: drag brass
  mirrors and copper cups along their rails, the beam re-traced live; light
  every dewdrop, then end in the bud. The reference ships as a game this
  repo names once in the spec to forbid; **it is called Sunbeam and nothing
  else**. Two things travel: **a proof bounded by the pieces' own freedom
  needs no cap** -- `sunbeam_gen.gd`'s `count()` follows the beam and
  branches only on a peg it reaches, so it is exhaustive at 83 ms worst
  (Hard) -- and **hit-test a two-cell piece as the box round both cells**:
  a cup's middle is the line between them, the point a thumb aims at, and a
  per-cell strict test missed it. **What is drawn is a ray, what is judged
  is the grid**: the beam is cast against each piece where it is drawn
  (mid-drag, mid-settle) so it bends continuously, and on pegs it equals the
  grid trace, which alone decides the win. Its drawing is `ui/faces/sunbeam_parts.gd`,
  shared with the menu card. 65 draw calls played, 68 solved, ANGLE agreeing.
  Sounds generated (2026-09-26), one take a cue, awaiting the user's listen.
  **Polished on 2026-09-26** (the spec's amendment): a dressed greenhouse (a
  potting shelf, a window box, light shafts, slab tiles, moss), the glow wide
  enough to pool on the floor, pulses flowing out of the sun and a twinkling
  star on every struck mirror at rest, a lift, a sheen and a landing peg on
  a held piece and a dip and a puff when it lands, a bloom that unfurls (the
  shut bud used to vanish as it began), and a gold wave down the beam on the
  win. 65 at rest, 69 solved; a drag frame costs ~1.7 ms more on this Mac.
- **The second polish, 2026-10-01** (unattended, spec
  `2026-10-01-sunbeam-polish-design.md`): Hard and Insane can be lost, and
  the rule is about **where the light is let go**, never where a piece
  stands -- holding a piece is a free peek, and a move released with the
  light resting on a **sleeper** costs a heart and slides back
  (`State.judge`, `_misstep`). Hard's sleepers are three **snails**
  (`Gen.lay_snails`: never on a reference way home, where near misses put the
  light); Insane is **Shy Dew**, whose sleepers are the drops themselves, so
  the last move lights them all at once (`Gen.dark_path`, exact BFS over
  arrangements on the lean tracer `Gen.Fast`; 200 banked floors, each needing
  a detour). Two lessons: **a board with no wrong placement can still judge
  its release** -- price the state a move is let go in, and prove a way home
  through unpriced states, so backtracking is always safe; and **"long ago"
  is not a negative time** -- `t - 100` read as "never" in the first 100 s
  after launch and showed a restored day's bud shut (both clocks use `AGO`
  now). Rewards, party and the GLASSHOUSE sound set as Caterpillar's. Peak
  107 draw calls (out of hearts), ANGLE agreeing on the solve. Same day: the
  light leaves the sun weak and gains a step at every drop it passes, and the
  bud grows (shut) by the strength that reaches it (spec section 9).
- **The board checkup, 2026-10-02** (row 22 of `docs/agents/checkup.md`):
  five meshes -- glass (the card, made again on a resize), bed (made once
  in a reference layout, joined with the glass while the relay is the
  identity), lower (cups and the beam), upper (sparks, drops, mirrors,
  rings) and air -- every piece a look under its transform, the pieces in
  rooms of their own. A board tutorial `ui/hud/sunbeam_tutorial_diagram.gd`
  plays a quietened `Floor` on hand-made floors; the board gained the
  `_inset()` and `_hearts_at()` hooks for it.
- **Insane counts moves (2026-10-04,** `docs/agents/flat-screens.md`,
  "Insane counts moves"**).** `State.HEARTS_BY` is `[0, 0, 0, 0]`. Shy Dew's
  own rule stays as Hard's snails did: a move let go with the light on a
  drop still dries it and slides back (`_misstep`, `costs` false, the hearts
  code dormant) -- it is read off the floor, not off the answer, and holding
  a piece is still the free peek. What it costs now is **a move, like any
  other let-go**: `_spend(1, ...)` from `_release` for a move that stands
  and from `_misstep` for one sent back. `State.moves_budget()` =
  `shortest_solve()` + max(3, a quarter of it, rounded up); the shortest
  solve is the bank's `dark` (the miner's exact breadth-first count of the
  way home that never lets go on a drop; 8-11 over the 200 floors, so
  budgets 11-14), or on the live fallback (Hard's floor on band 3) the
  pieces that open off home. Out of moves is `out_of_hearts` and the old
  dusk; the card takes `MOVES_BONUS` (5); Reset and Try again hand the
  budget back; `capabilities()` is empty on Insane (it used to list an Undo
  that `can_undo()` refused). New keys at the end of `locale/boards.csv`:
  `SB_RULES_SHY_MOVES`, `HTP_SB_SHY_MOVES_BODY`, `HTP_SB_RESET_MOVES_BODY`,
  `HTP_SB_DRIED_BACK_CAP` (the tutorial's SHY page no longer says "a
  heart"). `SB_SHY_WARN` (said once, mid-drag) stays: it restates the rule.
  Surprising: the budget is tight in absolute terms -- three spare moves on
  eight -- because the formula's quarter rounds under its floor here.

### The greenhouse is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/sunbeam_world.gd` is the greenhouse's glass
wall the board drew inside its card: cream light across the top, sage
glass from the top rail down with white mullions, slant shafts of light
and two glints; a small hanging shelf of three seedlings in the gap of the
tools row; and at the foot a potting bench with a terracotta trough of
leaves and flowers, a watering can, a trowel and two potted plants; seven
motes breathe. The iron frame is on the host's margin; the 180 cell cap is
off (an Easy cell is 191).

- Registry: `bleed`, `level_card`; no tray, no actions row, as before.
- `opengl3_angle`, 810x1440: 77 draw calls at rest; `tests/_win.gd --
  sunbeam` passes.
- Decided for the user, unconfirmed: the larger Easy cell; the shelf
  staying over "Well done!". Seen and left: on the win the wall's top rail
  and the rainbow run close to the grey line. Owed: a phone, the level
  slide.

### Made fun (2026-10-29)

The user: "make pinwheel and sunbeam experience way better to play, and game
itself way funnier to play, right now nobody likes it. Use web for
reference on how good games does it". Built unattended.

- **What the web said.** The genre's reference is loved as relaxing and
  faulted for coming down to "picking the right spot to aim at"; the fun
  is the light snapping where you meant it to go, the frustration is
  fiddling until it does.
- **Measured first** (`tests/_probe_sb_fun.gd`, 30 floors a band): a
  fiddler (a random piece to its best peg by drops lit, a random peg a
  third of the time) ran a median 15, 71 and 175 moves over the shortest on
  Easy to Hard, and 4 Medium and 21 Hard floors of 30 went unsolved in 300.
  A player who only lets go a piece on a peg the light crosses ran 1, 4 and
  35 over, unsolved 0, 1 and 20. What the floor never showed was where the
  light crosses a rail.
- **Sun rings on a held piece's rail** (`State.catches`): every peg the
  light crosses **with the piece lifted off the floor** (`Gen.trace`'s new
  `skip`; read with the piece in place, a peg past its own bend is crossed
  only because it stands there). The lifted light is the same all drag
  long, so it is read once on the press. The ring under the piece now is
  filled.
- **Where the light gave out, said**: after a move by hand that leaves the
  light short of the bud, once an arrangement, "The light stops at a pot. 2
  of 4 drops lit." (pot, a cup's back, off the floor, a loop). The bud
  reached with drops dry keeps its own line.
- **Live stars on a pill in the tools row's gap** on every band that has no
  hearts or move counter (all four since Insane's counter went): moves plus
  the pieces still off home, against `shortest_solve()` (on Shy Dew the
  bank's `dark`, so the stars there can only fall late); three within 1, two
  within 4 (`State.STAR_SLACK`). The hanging shelf steps out of the gap
  while the pill shows (`World.gap`), and the pill goes when the win screen
  takes over (`_won`). Win line: moves against the shortest.
- **The bulb in two presses**: the first (one hint) rings the piece the
  light needs next (`State.hint_piece`, what the bulb always slid) and says
  whether its place is one of its sun rings -- true on 88/90, 116/123,
  127/180 and 47/196 presses walking home band by band, so the line only
  promises it when it is so -- and the second, free, slides it home and pins
  it, counted as a move. `_win.gd` presses twice and checks the rung piece
  was pinned; the tutorial's bulb page rings then slides, twice.
- `SB_RULES_CATCH` in the rules; en/pt/es. `opengl3_angle` 810x1440 Hard,
  a piece held: peak 89 draw calls (twice). `_win.gd -- sunbeam` PASS. No
  new sound file. Unseen on a phone; the thresholds are unconfirmed.
