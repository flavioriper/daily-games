# Mini Golf

- **Mini Golf is the thirtieth card** (2026-10-05, `puzzles/minigolf2d.gd`,
  `puzzles/minigolf_state.gd`, `puzzles/minigolf_sim.gd`,
  `puzzles/minigolf_gen.gd`, `ui/faces/minigolf_parts.gd`; no spec and no
  concept tab -- asked for and built in one sitting while the user was
  away). A daily course of mined holes played in order: drag back anywhere
  on the card and let go to putt, the dots show where the ball goes first,
  fewest strokes against par. After the daily course-a-day golf games (one
  of five holes sunk in any order, one of nine with a stroke limit and an
  emoji card); **it is called Mini Golf**, the sport's own name, and no
  game's name is in the tree.
- **The bands.** Easy is 3 holes of kerbs, cut corners and blocks; Medium 4
  with sand and bumper posts; Hard 5 with ponds and slopes; Insane is
  **Swing Gates**, 5 holes whose gates shut on every other putt (they swap
  when the ball stops, so what is seen while aiming is what the putt
  meets) with the strokes counted: the course's par + max(3, a quarter of
  it), no bulb, and the card closed before the last cup is the loss
  (`docs/agents/flat-screens.md`, "Insane counts moves"). Easy to Hard
  cannot be lost: the day is done when the last cup is filled, whatever it
  took. No Undo on any band (a stroke played is on the card); Reset is the
  course from the first tee. The pond puts the ball back on its lie and
  the stroke stands.
- **The physics is pure data at a fixed step** (`minigolf_sim.gd`, `DT`
  1/120): the guide, the bulb, the miner, the tutorial's finder and the
  harnesses all play a putt on a `clone()`. A hole is squares on a 4 by 6
  grid (18 units a square); its kerbs are the squares' outer edges joined
  into runs, looked up through 6-unit buckets; a ball over the cup under
  `CAPTURE_V` drops, faster it rims out, and a slow one inside `FUNNEL_R`
  rolls in. About 0.2 ms a putt on this Mac, so the bulb's ~600 putts are a
  tenth of a second, on a `WorkerThreadPool` task all the same.
- **Par is what a decent hand takes, not the best putt there is**
  (`Gen.rate`): twelve rounds of the steady putt (`Sim.best_shot`, limited
  to one bank a putt) struck a little off each time, the mean rounded, and
  never under the proof's putts. The first miner used the fewest putts a
  search could find and called nearly every hole a 1 or a 2: with the whole
  fan played out there is always some four-bank line into a generous cup.
  The physics was tamed for the same reason (118 units of roll at most, a
  kerb gives back 0.62, capture under 56). **A trick shot is how par is
  beaten**, and the bulb prefers the putt off fewer kerbs (`BANK_COST`).
- **The phone never grows a hole.** `tools/mine_minigolf.gd <band> <count>
  [seed]` grows (a lane walked over the grid that never runs beside itself,
  widened, corners cut, furniture a square), proves (`Gen.solve`, a beam
  search for the fewest one-bank putts whose last still drops a little
  off) and rates; `tools/merge_minigolf.py` gathers the lines into
  `content/minigolf.json`, a pool a band. A day's course is `holes` of the
  pool, no hole twice, the lower pars first. Hard keeps at most three
  par-2 holes in ten (`short`). `tests/_probe_minigolf_bank.gd` re-proves
  the bank against the sim as it stands: **re-mine when a constant in the
  sim changes** (a proof is chaotic past a bank; par is only a number, so
  the game itself never replays one).
- **A small hole is drawn big**: the hole's own bounds fill the card up to
  `ZOOM` (1.4) times the whole field's scale, so Easy's three-square holes
  have a ball and a cup half as big again. Every hole mesh and the live
  mesh are built from the hole's own top-left, and the swap moves them by
  transform (no fade: a hole is layers in one mesh, and a faint one shows
  them all).
- **Drawn as** `still` (the lawn, a relayout), `hole` (Parts.hole, once a
  hole), `hud` (the pips, when one changes) and `live` (gates, aim, trail,
  ball, flag, ripples; a few hundred vertices, every frame something
  moves, and the flag always flutters unless reduce motion is on). **The
  green's kerb is a rounded square a square plus a plain bar across every
  join**, in opaque colours only: the first pass drew the lawn shade
  see-through and every overlap showed darker. 85-97 draw calls playing,
  ~115 at the win.
- **The scorecard** is a pip a hole over the green (gold under par, paper
  at par, rose over, the strokes lettered in it), the running score beside
  them and the hole's line under them; the words are golf's own (Hole in
  one, Eagle, Birdie, Par, Bogey, Double bogey), and the share line is a
  mark a hole with the total against par.
- **The tutorial** (`ui/hud/minigolf_tutorial_diagram.gd`): the putt, the
  bank, the card, then sand and posts (Medium up), ponds and slopes (Hard
  up), the gates (Insane), the bulb, and Insane's shared moves page with
  its own words. Each page is the board itself on a hand-made hole lying
  along the page; the putts are found by `tests/_gf_tut_search.gd` (re-run
  it if the physics or the page's holes change) and struck exact after the
  finger's pull.
- **Harnesses**: `tests/_shot_minigolf.gd` (rest, aim, putt, hint, solve,
  out, reset, restore, holes); `tests/_probe_perf.gd -- minigolf` plays the
  steady putt from every lie (`x=buzz` for the knocks); `tests/_win.gd --
  minigolf` wins through the input path with `settle_now()` between putts.
- **Sounds**: 22 cues generated 2026-10-05 (`tools/gen_sfx.py minigolf`,
  the LINKS foley set and the garden's kalimba, music box and hand bells),
  one take a cue, unheard by the user. **Redone 2026-10-10 against the cozy
  rules** (`docs/agents/sound.md`, the `minigolf` row): three takes, a
  wooden block on felt (`putt`), a lighter button (`wall`) and one muffled
  kalimba note, and every cue written from them or borrowed air; unheard.
  At play: the softest putt is 4 dB under the hardest and the softest kerb
  5 (`PUTT_SOFT_DB`, `WALL_SOFT_DB`; they were 8 and 12, and the new files
  are 6 dB under the old), the rim, the sand and the gates vary by 0.94 to
  1.06 (`TICK_VARY`; 1.0), and **the last cup's word (Par, Birdie, Hole in
  one) is shown and no longer sounded**: `solved` starts on the frame the
  ball drops and `party` 0.6 s after, and the word's phrase 0.32 s in made
  three tunes at once. The sticker and the sprout's line are unchanged.
- **Not seen on a phone.** Shots on both drivers and under reduce motion
  only; the pull's length (`PULL`, 300 px) and the ball's size were judged
  on this Mac's window. The pt and es lines are unreviewed.
