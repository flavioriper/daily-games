# Balance

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Balance is a seesaw since 2026-09-27** (`puzzles/balance2d.gd`,
  `balance_state.gd`, `balance_sim.gd`, `balance_gen.gd`, spec
  `2026-09-27-balance-seesaw-design.md`; built unattended at the user's word,
  with no concept tab). The column of scales and the weight cards are gone:
  drag fruit from a basket into cups at 1..D either side of a pivot; every
  kind's weight is hidden; every fruit on the plank with the beam dead level
  wins, and pinned fruit make that arrangement unique. Two things travel:
  **a free plank only says left or right** (PhET's, and why weighing games
  turn into trial and error), so the hub carries a stone keel and the beam
  rests at tan(angle) = torque / K -- the spirit level shows one tick a
  unit and the sign the number at rest, which is how a player weighs; and
  **a cup's pull must be stiff at its core**, or a fruit on a leaning plank
  settles a tenth of a cup off-centre and "seated" is never true (the sign
  stayed dim until `CORE` went in). The physics is data at 1/120 s, not
  Godot's server. `"tray": "none"`; `ui/flat/weight_tray.gd` is unused now.
  Faces there are `shadowless` (a new `Face` flag: the offset shadow disc
  reads as a grey halo against the sky). Generation worst 29 ms (Insane,
  after `seed_pins`). 87 draw calls, idle 3.3-3.5 ms, ANGLE agreeing within
  4/255. Four cues generated (`lift`, `land`, `thud`, `tock`; `land` is
  pitched by weight), `enter` and `reset` re-taken, awaiting the user's
  listen.
  **Rewards made loud on 2026-09-27** (the spec's last amendment): a sky
  layer behind the board (turning sun, bunting, drifting clouds, a rainbow
  on the solve) and an air layer over the fruit (trails, sweat, two
  butterflies), a hanging sign that swings and pops, a picnic blanket
  under the basket; `arcade/rewards.gd` over the card cheers a move that
  leaves the beam nearer level (Closer! to Superb!, So close!), a Level!
  and the Balanced! solve. 91 draw calls at rest, 204 at the solve's peak,
  ANGLE agreeing. The solve is checked on any calm frame, not only on the
  step into calm, or a snapped board never solves.
