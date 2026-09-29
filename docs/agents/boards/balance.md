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

## Sunset, springy bales, motion, rewards and sound (2026-09-29)

Spec `docs/superpowers/specs/2026-09-29-balance-sunset-design.md`, built
unattended on `feat/balance-sunset` at the user's word.

- **Hard and Insane can be lost.** `State.budget` is loose fruit + `sun`
  (Hard 10, Insane 8, `Gen.BANDS`); a drop, a tap home and an undo each
  `_spend()` a step; Reset and hints are free. The sun sinks toward the far
  hill (`_sun_at`, `_day_target`), the sky takes a dusk wash, a pill counts
  the moves. Out of moves at rest: `_run_out()` -- night, stars, sleepy
  fruit, `out_of_hearts`, then Code Break's card (`ui/hud/out_of_rows.gd`
  now takes a `keys` dict): One more hour (placement `"hour"`, once, +4 /
  +3) or Show the answer (`finish_unsolved()`). Hints 3/3/1/0; Insane has
  no undo.
- **Insane's springy bales**: a beam at rest past the glass with loose fruit
  on its low side bounces them home (`State.tumble()`, `_boing()`); the
  generator requires `Gen.safe_order()` and adds one pin to reach it.
  Insane generation ~70 ms mean, ~245 worst on this Mac (was 29).
- **Sim fix**: a beam already lying on its bale is resting contact. Before,
  a heavy load (Insane's pinned side, 40-120 units) thudded every step and
  the jolts floated the seated fruit above the plank; the beam never read
  calm, so no rest event fired.
- **Motion**: aim glow on the target cup, glances (basket at the held fruit,
  neighbours at a landing), bounce flips, bale squash, dizzy stars, Zzz,
  sun giggle on a tap.
- **Rewards**: Nice toss! / Trick shot! with sunglasses; party hats at the
  solve; the seal on the empty basket (`stamp_key()`, BAL_STAMP_1..5/MORE,
  night seal "Boing Bales" on Insane; kept in `completion_record()`); weight
  tags swinging under the cups at the solve and after Show the answer.
- **Sound**: `step`, `refused`, `thud` re-prompted soft; new `boing`,
  `sunset`, `hour_back`, `sun_low`, `toss`, `giggle`, `reveal`, `stamp`,
  `party`, `confetti`. Not yet judged by ear.
- **Draw calls**, `opengl3_angle`, 810x1440: Hard at rest 109, Insane 91,
  reduce-motion sunset 124, solve peak 240.
- Harness: `tests/_shot_anim.gd -- balance sunset d=2` and `boing d=3`.
- **Review fixes**: `_drop_held()` before Undo/Hint/Reset (a held fruit
  soft-locked the sunset); Hard's hints (video ones too) cost a sun step and
  the bulb goes once the sun is down; `out_of_hearts` is a getter, true from
  the last step (the card is `_out_card`); stamp baseline excludes hinted
  fruit; old saves restore with no stamp. **Open**: a lost day is not saved,
  so reopening deals it fresh -- the same gap as Code Break's, a host change.
