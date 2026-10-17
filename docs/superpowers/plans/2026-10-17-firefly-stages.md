# Firefly in stages (2026-10-17)

The user, 2026-10-17: "firefly will be a staged arcade, with stage 1 - N",
"instead of having upgrades, let's keep only the points for every stage so
user can replay to try getting more points, let's add a easy, medium, hard
and insane clear for each stage, and the upgrades comes as goals for each
phase for skilled players ... reward player with a buff for that stage".
Then: "B is what I meant" (four difficulties a stage, each its own best),
"let's do the first 15 stage", and of the proposal page: "all good, let's
build it now".

**The design is `docs/brainstorm/firefly-stages.py`**, the data the page
is generated from: `S` (each stage's text, goal and counts, buff, Medium
numbers `m`/`fb`, entrance fire, twists `e`/`h`/`i`), `FULLW`/`WAVES`
(every wave's exact seats as (kind, column, row) and paths by name and
mirror; kinds G gnat, L ladybird, M moth; rows 0-4 from the top), `DIFF`
and `PATHS`. The sim's stage table is a transcription of it. Its page,
`docs/brainstorm/firefly-stages.html`, is the same thing for a person (stages 1-15, one
by one: what is new, the swarm, the wave order with a picture a wave, the
dives, the goal and its counts by difficulty, the buff, and a table of
numbers for Easy / Medium / Hard / Insane with each stage's own twists in
its "Also" column; the shared rules and the difficulty scaling at the top).
Read the .py before a task; open the HTML only for a stage's wording (it is 300 KB of pictures). Where this plan and the page disagree, the
page wins; where the page is silent, this plan decides.

The page's open calls, settled by "all good" (the page's proposals stand):

- A stage reached has all four difficulties open; clearing a stage at any
  difficulty opens the next one.
- Flybys stay on 3, 7 and 11. On Easy, Medium and Hard a flyby cannot be
  failed (passers never hit you); on Insane a passer that flies into you
  costs a firefly.
- No extra fireflies from points.
- Spare firefly and Twin start apply to one stage attempt. Second chance
  gives one firefly back on the stage being played (the sim's `revive()`).
- The stage map shows a stage's four clears (one mark a difficulty) and its
  best at the chosen difficulty. After 15, a "more stages soon" tile.

Decided here too:

- **Gold**: 5 an attempt as today, and the 20 only on the first clear of a
  stage at a difficulty (not on every new best, which every first attempt
  would be). The Arcade's daily cap of 60 still holds.
- **Double fire won while already a pair** (Twin start, a rescue) is a
  Silk shield instead.
- **Break a wave** on stages 10 and 15, where two waves fly in together:
  each seat group is its own wave (two waves, either one counts).
- **The record stays generic**: `arcade_tab.gd` reads Firefly's stage
  record for its line itself; `best(game)` is not redefined as a sum.

Every task: run `godot --headless --check-only --script <file>` on each
touched script and the suite (`godot --headless --path . --script
tests/run_tests.gd`, 248522 passed before this branch), then **commit at
the end of the task** on `feat/firefly-stages` (conventional message,
saying what was measured). Do not push, do not merge.

Rules that bind every task: the name is Firefly only (CLAUDE.md, renamed
genres; never name the 1981 game). No new test suites
(memory: MVP, throwaway probes only); existing harnesses are updated
where the change breaks them. Headless probes over windowed runs; batch any
windowed run and say so. 855 draw calls. Text through `locale/ui.csv`
(en, pt, es), counts as `_ONE`/`_N`. Motion from `core/motion.gd`, honour
`Motion.reduce`. The house sound (pops from `tools/sfx_bank/` by `bank:`
rows) for any new cue; reuse Firefly's cues where one fits.

## Task 1. The sim plays one stage

`arcade/firefly_sim.gd`. A run is now one stage at one difficulty:
`_init(seed, stage, difficulty)` (difficulty 0-3). Phases INTRO -> PLAY ->
WON (cleared, or a flyby's end) or OVER (last firefly lost). No SHOP, no
next stage inside a run.

- **Out**: energy, orbs, `Card`, `price`, `buy`, `leave_shop`,
  `Phase.SHOP`, the crit dice, `hp_base` growth, `EXTRA_*` extra ships,
  `level()` as a growth curve. The gun is fixed: power 1, `RATE` 3, one
  shot a volley (keep `shot_off` and `volley` for the pair and buffs).
- **A stage table** (`const STAGES`, one Dictionary a stage, 1-15): kind
  (play / flyby), the cast, the waves in order (each wave its paths and
  seats, or for a flyby its paths and kinds), the Medium numbers (dive
  gap, divers at once, seeds a dive, swarm speed; for a flyby the gap
  between waves and flight speed), entrance fire from stage 6, the goal
  (kind and the four counts), the buff, and the stage's flags for its
  "New" rule and its Easy / Hard / Insane twists. Seats and paths exactly
  as the page's pictures (the full swarm is today's `_plan_stage`; stage
  1, 2, 10, 13, 14, 15 and the three flybys differ as the page says).
- **Difficulty** (`const DIFF`, one row a difficulty) as the page's
  "How the difficulties scale" table: fireflies 4/3/3/2; shots
  gnat/ladybird/moth 1-1-2, 1-2-3, 1-2-4, 2-3-5 (a rogue as a ladybird;
  stage 15 Insane moths 7; flyby passers 1, but stage 11 Insane half of
  them 2); swarm speed x0.85/1/1.12/1.25; dive gap x1.4/1/0.8/0.65;
  divers -1 (at least 1)/0/+1/+2; seeds -1/0/+1/+2 (0..4); seed speed
  125/150/170/195; entrance fire never / 1 in 4 from stage 6 / 2 in 5
  from stage 6 / 1 in 2 from stage 2. Flybys: wave gap x1.2/1/0.85/0.6
  and flight speed x0.8/1/1.15/1.3.
- **Every stage rule and twist on the page is built**, each a flag the
  stage table names: gnats diving in pairs (1 I), ladybird seeds two side
  by side (2 I), pair start on a flyby (3, 7, 11 E), passers ram only on
  Insane, a moth's second pass (4 I), one escort (5 E) / two escorts that
  drop seeds (5 I), every entering bug fires (6 I), beam opens in 1.2 s
  (8 E) / stays 1 s longer and catches 25% wider (8 I), the held captive
  at the start (9: the second moth from the left carries it, no life
  spent; its moth dives within 10 s of being seated; slower on E; on I it
  dives once and a captive brought home turns rogue), dives from two
  thirds seated and the last two gnat waves together (10) / dives that
  never wait (10 I), seeds in a fan of three from a ladybird (12, not E) /
  seeds aimed where the firefly is going (12 I), moths first, beams on
  three lone dives in four and a beam drifting toward the firefly (13,
  no drift on E) / two beams at once (13 I), reversed order, dives from
  the first wave seated and bugs flying home dropping seeds (14, not on
  E) / no pause after the banner (14 I), waves in pairs (15; one at a
  time on E) / a wider breath (15 I).
- **Goals**, counted in the sim and sent as events (`goal_step` with
  `have`/`need`, `goal_met` with the buff): catch in flight (a kill of a
  bug that has not yet sat in its seat: give each bug `seated`), shoot
  moths diving, an escorted moth at 1,600, break a wave (every bug of one
  wave down before any of it sat: give each bug its wave), win a firefly
  back (a docking), bring the held firefly home (stage 9: its docking),
  reach a chain (kills within 1.5 s, counted in the sim now; the screen
  reads `sim.chain`), go untouched N s once the whole swarm has first
  sat (a hit or a capture starts it again), shoot moths while their beam
  is open, and for flybys all forty (the 10,000 bonus, no buff). A goal
  is met once an attempt.
- **Buffs** until the stage ends: quick gun (4.5 volleys a second),
  double fire (the twin docks as a rescue does: `pair = true`, flying in
  from the side), piercing spark (a shot goes on through its first bug),
  silk shield (the next hit, seed or bug, is taken by the shield:
  `shield` event), slow seeds (every seed, in the air and to come, at
  half speed), score x1.5 and x2 (kills after the goal). `buff` holds
  the one won.
- Score as today (seated/diving, escorts, rogue, flyby 100 and its end
  bonus), times the score buff.
- Keep the events the screen already plays (pop, hurt, dive, beam,
  captured, carried, rescue, docked, ship_pop, stage_start,
  challenge_start, challenge_result, game_over, revive, shoot...). Add
  `won` and the goal events. `revive()` stays.
- `tests/_probe_firefly.gd -- [stage] [difficulty] [seeds] [skill]`
  plays one stage per seed with its bot and prints, per stage and
  difficulty, the clear rate, the goal rate, the median score and the
  median time; `all` for the stage plays 1-15 at all four. Update it,
  run it, and paste the table in the report.

## Task 2. The record keeps stages

`arcade/arcade_record.gd` gains, for Firefly (generic enough for a later
staged game): `stage_best(game, stage, difficulty)`,
`stage_cleared(game, stage, difficulty)`, `reached(game)` (the highest
stage open, at least 1), and `add_stage(game, stage, difficulty, score,
cleared, boosted) -> bool` (true on a new best for that stage and
difficulty), stored in the game's own section of `user://arcade.cfg`.
`best(game)` for Firefly is the sum of each stage's best at any
difficulty, and `best_stage` the furthest stage cleared, so the tab's
existing reads keep working. The Arcade card line says the furthest stage
and how many of the 60 clears are done (a new `_ONE`/`_N` key). The old
run record (`best`, `stage`) is left unread. `wipe` already clears it all.

## Task 3a. The screen: out, the map, the flow

`arcade/firefly_screen.gd` (and whatever new file the stage map needs).

- **Out**: the shop card and everything for it (`_open_shop` ..
  `_buy`), the ENERGY plate, the motes (`_drop_energy`,
  `_on_motes_landed`), the hit numbers' crit gold, `_extra_ship`.
  Keep the wounded bar and the hit numbers.
- **The stage map** opens with the screen and from the end card: a grid
  of the 15 stages (number, name, four marks for the four clears in
  `difficulty_sheet.gd`'s tints, the chosen difficulty's best), locked
  past `reached`, and a "more stages soon" tile. Above it, the
  difficulty row **is `ui/flat/level_card.gd`, fed Firefly's four
  levels** (memory: same component, same code): give the card a way to
  be told which cells are done instead of asking `Progress` (an optional
  Callable), and use its `pick` signal. The chosen difficulty is kept
  with `Record.set_pick`. A tap on an open stage starts it (through the
  boost card as today).
Task 3a ends here (with the removals, the map, `level_card`'s change,
Record wiring at the end of an attempt, start/back/restart flow, and the
end card's buttons working however plain). Task 3b is the rest:

## Task 3b. The screen: goal, buffs, end card, harnesses

- **The paper row**: SCORE, BEST (this stage at this difficulty) and the
  stage with the difficulty's name ("Stage 4 · Hard").
- **The goal**: on the stage banner under the stage's name (goal text and
  count, "then: buff name"), and as a small counter plate at the top of
  the field (`3 / 5`) that beats on each step; on `goal_met` a Rewards
  moment with the buff's name ("Quicker gun!") and the plate turns gold
  with the buff's icon. Flybys say their own line as today.
- **Buffs drawn**: the twin flies in (as the docking does), the shield is
  a soft silk ring round the firefly that bursts with `shield`, a
  piercing spark is a longer, brighter spark, slow seeds trail longer;
  quick gun and score need no drawing beyond the plate.
- **The end card**: Cleared! or the night wins, the score counting up,
  the best for this stage and difficulty, the goal met or not, and
  buttons: Next stage (when cleared and there is one), Again, Stages.
  New best rains as today. Second chance as today (one firefly back on
  the stage). `Record.add_stage` on every finished attempt. Analytics:
  `arcade_start` and `arcade_end` and `arcade_abandon` carry `stage` and
  `difficulty`, and `arcade_end` carries `cleared` and `goal`.
- Restart replays the same stage and difficulty. Back from a stage goes
  to the stage map; back from the stage map leaves the game.
- Haptics as today for the events that remain; `goal_met` and `won`
  bump, `shield` warns. Sounds: reuse Firefly's cues (`docked` for a
  goal met, `stage`/`clear` for won, `hurt` low for the shield) unless a
  bank pop fits better.
- `tests/_shot_firefly.gd` and `tests/_probe_arcade_buzz.gd` updated so
  they run (they bought through the shop); `_probe_start_over.gd`,
  `_probe_chance.gd`, `_shot_doubler.gd` and `_shot_howto_screen.gd`
  checked and mended where they read what went.

## Task 4. Words and the tutorial

- `locale/ui.csv`: the stage names, goal texts (with `%d`), buff names and
  lines, the map's strings, the end card's, the card line; en, pt, es.
  Shop keys (`FF_SHOP_*`, `FF_CARD_*`) and energy go if nothing reads them.
- The tutorial (`ui/hud/firefly_tutorial_diagram.gd`, the screen's
  `tutorial_pages()`): the shop page becomes "Goals and buffs" (the goal
  plate and the six buffs), the swarm page loses "every stage the swarm
  takes more", the HUD page loses the extra fireflies at 20,000 and says
  stages and difficulties. A page's night stays stage 1, Medium.
- `ARC_FIREFLY_BLURB` and the boosters' lines checked against the new
  game.

## Task 5. Calibrate, then write it down

- Run `_probe_firefly.gd all` with the bot at skill 1 and 0.6. Aim, at
  skill 1: Medium from about 95% clears on stage 1 to about 60% on 15
  with a dip and recovery around each new rule; Easy above Medium; Hard
  about 20 points under Medium; Insane under Hard but never 0. Flybys E-H
  always cleared. Goals met on Medium about half the time. The bot sits under the lowest
  bug and never stops firing: its rates for catch in flight, break a wave,
  untouched and win a firefly back are artefacts of that, so label them as
  such in the table and do not tune toward them. Move the
  stage table's numbers, never the shared scaling, unless a whole
  difficulty is off. Paste the before and after tables.
- A windowed `_shot_firefly.gd` pass (one batch, said beforehand): the
  stage map, a stage with its goal plate, a buff live, the end card
  cleared and failed; draw calls under 855.
- Write it down: a section 11 amendment in
  `docs/superpowers/specs/2026-09-27-arcade-firefly-design.md`, the
  Firefly entry in `docs/agents/arcade.md` (the energy-and-shop bullet
  becomes history), haptics row 33, the sound notes, and the spec page
  `docs/brainstorm/firefly-spec.html`'s sections that changed.
