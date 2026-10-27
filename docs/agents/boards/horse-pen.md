# Horse Pen

- **Horse Pen is the thirty-first card** (2026-10-08, `puzzles/horse2d.gd`,
  `puzzles/horse_state.gd`, `puzzles/horse_gen.gd`,
  `ui/faces/horse_parts.gd`; no spec -- asked for and built in one sitting
  while the user was away). It was one of the thirteen 3D island boards,
  removed with the 3D game on 2026-09-24 and never drawn flat; this is that
  board brought back as a flat one. Its look is the one agreed on
  `docs/brainstorm/concepts.html#horse` on 2026-09-15 (the meadow fills the
  card, hay bales and not rails, wheat that stands up, apples and not
  cherries), which is also the one place the daily web game it follows is
  named. **That name goes nowhere else**: not in code, comments, commits or
  on screen. The puzzle id is `horse`, as it always was.
- **The rules were checked against that game on 2026-10-08** and the old
  board already matched it move for move: the horse walks up, down, left
  and right, never through a wall, water or (ours) a boulder; a way to the
  edge of the field is an escape; a penned cell is a point; a bonus fruit
  is three more. What the original has that the island never had became the
  bands: a golden fruit worth ten more, a swarm worth five fewer, and pairs
  of cells the horse steps between. Ours are the golden apple, the beehive
  and the tunnel. One difference kept on purpose: the original is one
  submission a day against everyone's score; ours has a target, and Submit
  is refused (kindly) until the pen is closed and worth it.
- **One move**: tap bare grass to drop a hay bale, tap a bale to lift it. A
  bale stands on bare grass only -- never on water, a boulder, the horse,
  an apple, a hive or a tunnel's mouth. The wheat is the horse's reach, so
  the pen is read off the board. The score is the reach once it touches no
  edge cell: a point a cell, +3 an apple, +10 the golden apple, -5 a hive.
  A tunnel's two mouths (the same ribbon) are neighbours.
- **The day ends on Submit, not on the pen closing.** The actions row's
  third button reads Submit (`check_label` → `HP_SUBMIT`). On an open pen
  the edge cells the horse still reaches blush and the horse shakes its
  head; on a closed pen under the target, the shake alone; on a pen worth
  the target the day is done. Until then the pen can be rebuilt for a
  bigger one, and the right-hand pill reads score / target, leaf green at
  the target and gold with a star at the best pen known. `check()` returns
  -1 always (there is nothing to count), so the host never says All good.
- **The bands** (`Gen.BANDS`): Easy 7 by 8 with 7 bales, water and boulders
  only, target 80% of the best; Medium 8 by 10, 8 bales, three apples, 85%;
  Hard 9 by 11, 10 bales, apples, the golden apple and two hives, 90%;
  Insane is **Tunnels**, 10 by 12, 11 bales, three hives and a tunnel, 90%,
  with the moves counted: a bale laid or lifted costs one and the budget is
  the stock and three more (`State.MOVES_SLACK`,
  `docs/agents/flat-screens.md`, "Insane counts moves"). (Stale since 2026-10-12: no board counts moves on Insane,
  `MOVES_SLACK` is all zero, and the bulb is back there since 2026-10-13.) No Undo and no bulb
  there; **Submit stays on Insane**, since it is the ending and says nothing
  the score pill does not. Out of moves with no pen worth submitting is the
  loss; out of moves with one, the Submit is still the player's to press.
  Easy to Hard cannot be lost.
- **The phone never lays a meadow.** `tools/mine_horse.gd <band> <count>
  [seed]` lays one (streams that run off the field, pools, boulders, the
  horse where it can wander furthest, the things on cells it can reach),
  then searches for the best pen the stock can close: 200 pens grown out
  from the horse along the water, then 120,000 steps of annealing over the
  bales from the four best. `tools/merge_horse.py` gathers the lines into
  `content/horse.json`, a pool a band (158 / 137 / 160 / 153). A day is one
  meadow of its band's pool, picked by the day's seed. **`best` is the best
  a long search found, not a proof**: a search four times as long beat it
  on one Insane meadow in ten (45 against 43), which is why the screen says
  "the best we know" and why a player's pen may beat it (the pill and the
  seal ask `>=`). A meadow is kept when its answer uses all the bales or
  all but one, pens at least 14 / 20 / 26 / 30 cells and at most 62% of the
  field. `tests/_probe_horse_bank.gd` (headless) re-proves the bank:
  **re-mine when a rule in `horse_gen.gd` changes**. Without the bank the
  phone lays its own with a short search (`GROWS_LIVE`, `STEPS_LIVE`, about
  60 ms on this Mac), a fallback only.
- **The bulb** drops one bale of the bank's answer, the one beside the
  horse's reach first, in older straw, and pins it; with the stock spent it
  lifts one of the player's own bales that is not the answer's to pay for
  it. Three on Easy and Medium, two on Hard.
- **Drawn as** unit meshes under transforms, baked with `Face.FlatBuilder`:
  `_still` (the meadow to the card's edge, the field and its plot lines,
  the water with its banks, the boulders; a layout), `_wheat` (the reach,
  rebuilt only while it spreads or shrinks), `_items` (apples, hives,
  tunnel mouths), `_live` (the shade under the finger, blushes, the win's
  flowers, the bales). The horse and the bees are on a layer of their own
  that draws every frame (the tail swings, the bees fly; under reduce
  motion only when asked), the pills and the toast on another. 76-103 draw
  calls on both drivers; `ui/faces/horse_parts.gd` is builder shapes, not
  Controls, shared with the menu card and the tutorial. **The horse is the
  one creature on the board**: a chestnut pony from the side
  (`Parts.horse`), its looks the family's `Face.Expr`, its head turning
  about the neck.
- **The toast** carries what the tip card used to (a refusal, the pen
  closing, a Submit that is not one yet), Knight's and Rings', at the foot
  of the field, or at its head when the finger is in the lowest third. It
  speaks when the pen becomes something else, never on every bale.
- **Motion that is this board's own**: the wheat spreading a step at a time
  from the horse and sinking at once; a bale dropping half a cell with the
  squash; the horse landing after the field, hopping when the pen reaches
  the target, shaking its head at a refused Submit; the win (the horse
  kicks, the bales hop in the order they were laid, flowers open over the
  pen from the horse outward, the seal for the best pen or any Insane one).
- **Harnesses**: `tests/_shot_horse.gd` (rest, play, refuse, notyet, hint,
  solve, out, reset, restore); `tests/_probe_perf.gd -- horse` lays the
  answer and submits (`x=buzz` for the knocks); `tests/_win.gd -- horse`
  wins through the input path; `tests/_probe_moves.gd -- id=horse`.
- **Not seen on a phone.** Shots and probes on this Mac only. The sounds
  are one take a cue and unheard by the user; the pt and es lines are
  unreviewed.
- **Sounds redone 2026-10-10** against the cozy rules (the row in
  `docs/agents/sound.md`): a bale laid and a bale lifted are one soft
  wooden tock each and, with the undo, vary by 0.94 to 1.06 at random
  (`TICK_VARY`; all three played at 1.0 every time), the pen shutting and opening are notches,
  a refused Submit three falling notches, the reset a breath, and the
  pony keeps its own voice, rolled off. Measured, not heard.
- **Calls made without the user** (2026-10-08): the bands' content (apples
  from Medium, golden apple and hives on Hard, Insane = Tunnels); the
  target as a share of the best pen known (80 / 85 / 90 / 90%) rather than
  the best itself; Submit kept on Insane; the bulb pinning a bale; the
  tunnel as the cozy stand-in for the original's paired cells; the pony's
  drawing.

### The paddock is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/horse_world.gd` is a pale sky down to a
horizon behind the tools row with two far hills, a pasture lighter than
the field, a cloud, a bale, a wheat ear and an apple in the gap of the
tools row, and at the foot, left of Submit, a stable front, a two-rail
fence, a water trough, a stack of three bales and windfall apples; six
pollen motes breathe. The dark meadow card and its ring are gone. Height
binds on Medium to Insane; the pills stay on the margin.

- Registry: `bleed`, `level_card`, and **Submit stays** on the actions
  row: closing a pen never ends the day by itself, the player declares it.
- `opengl3_angle`, 810x1440: 85 draw calls at rest; `tests/_win.gd --
  horse` passes.
- Decided for the user, unconfirmed: Submit kept; a small yard (the field
  comes to 190 of the bottom). Owed: a phone, the level slide.

### Made fun (2026-10-27)

The user: "make horse pen experience way better to play, and game itself
way funnier to play, right now nobody likes it", autonomous, push when done.

**Measured first** (`tests/_probe_hp_fun.gd`, headless, 60 meadows a band
out of the bank, three players: a *plugger* who lays each bale where it
leaves the fewest ways out and stops when the pen shuts; a *casual*
`Gen.search` with a short look, 8 pens grown and 60 steps; a *keen* one
with the phone's own fallback look, 40 and 400). Under the old rule,
Submit refused until the pen reached the target (80/85/90/90% of the best
known): the casual player finished the day 53/37/28/24 of 60 on Easy to
Insane, the keen one 59/48/47/37, the plugger 17/10/6/10, and the plugger
did not close a pen at all on half the days (30/24/19/20 closed). So on
Hard and Insane a fair player was refused on most days, Submit after
Submit, with the bulb the only way through.

**Taken from the daily it follows** (its own design notes, enclose.horse's
blog, "How we design daily puzzles" and "by the numbers"; players on
Tildes): there, any closed pen submits and is *graded* (diamond at the
best, gold 90-99%, silver 70-89%, bronze 50-69%), the header counts walls
and score against the best, tapping the horse shows its reach, and after
the submission the optimal pen is shown: "a poor score should prompt 'ah,
I see what I should have done'".

- **Any closed pen submits; stars grade it** (`State.stars`, `need`,
  `STAR_SHARES` [0.7, 0.9]): one star for a closed pen worth a point, two
  at 70% of the best known, three at 90%. `state.target` is now what three
  stars take, so `day_dict` and `_win.gd` read on. `submit()` still says
  OPEN for an open pen (the gaps blush, the head shakes) and SMALL only for
  a pen worth nothing (a hive in a pen of a few cells, `HP_SUBMIT_TINY`).
  The casual player now finishes 60/56/52/54 days of 60 (stars 1/2/3/best
  60-55-48-40, 56-44-33-25, 52-36-27-15, 54-37-24-13). Easy to Hard still
  cannot be lost; Insane has no counter, so nothing can.
- **The right-hand pill**: open, it counts the ways out (`HP_PILL_WAYS_*`,
  the edge cells the horse reaches), so each bale that closes one shows;
  closed, the score and three stars from `ui/flat/star_line.gd` (Market's
  and Super Slider's), a star won popping in (`star_up`, a ring), one lost
  falling off (`star_down`). Gold ink and the sun star at the best, leaf at
  three stars, as before. The sprout's line names the next star
  (`HP_STAR2_*`, `HP_STAR3_*`), and `HP_READY` names the best at three.
- **The horse tests the fence.** Left alone `IDLE_ESCAPE` (3.5 s) on an
  open pen with a bale down, it trots (`WALK_STEP` a cell, a hoof's pop a
  cell, `trot`) by plain steps (`State.path_out`, never through a tunnel)
  to the nearest way out, leans over the edge, nickers (`peek`), the cell
  blushes and the toast says one of six lines (`HP_ESCAPE_0..5`), then it
  trots back. In a closed pen it waits `IDLE_GRAZE` (6 s) and ambles to the
  golden apple, an apple or the pen's far corner (`path_graze`) and nibbles.
  `STROLLS` (2) a pen, so a pen left alone goes quiet; any press or change
  sends it home in `HOME_TIME`, and the tap still lands. Off under reduce
  motion, and in the tutorial's meadows. It is drawn where `_walk_pose`
  puts it; `state.horse` never moves, and a pat is still its home cell.
- **The best pen after the win**: a day won short of the best shows the
  bales of the best pen known that the player did without, in older straw
  at `GHOST_ALPHA`, popping in one by one from `GHOST_AT` (after the
  flowers); `HP_WIN_SUB_GHOST` says the faint ones are its bales. A
  reopened day shows them too.
- Tutorial: the TARGET page is "Earn the stars" -- the pen of one is one
  star, the bales moved out make it three, Submit ends the day (the refused
  Submit is gone with `HTP_HP_SUBMIT_CAP` and `HTP_HP_NOTYET_CAP`). Rules,
  `HP_TIP_BIGGER`, the share line (stars) rewritten; `HP_PILL_OPEN`,
  `HP_SHORT_*` and `HP_SUBMIT_SMALL_*` removed. en/pt/es.
- Not changed: the bank (`horse_gen.gd`'s rules are as they were, so
  `content/horse.json` still proves), the bulb, the bands.
- Harness: `tests/_shot_horse.gd` `stroll` (the walk out, the peek, the
  graze, a tap mid-walk) and `notyet` (an open Submit, then a pen of one
  submitted: one star, the win, the ghosts).
- **Mine, the user's to call**: the ladder (one star for any closed pen, 70
  and 90%), Submit on a one-star pen with no second ask, the ways-out count
  being edge cells rather than holes, the six lines, the strolls' timing and
  count, the ghosts. Not on a phone; the four new cues unheard.
