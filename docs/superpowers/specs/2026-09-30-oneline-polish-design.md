# One Line polish: failing, Sunny Spells, rewards, motion and sound

2026-09-30, built unattended on `feat/oneline-polish` at the user's word
("polish the line up game, add more smooth animations, reinforce that the sfx
sounds are really cozy, add more visual rewards even if silly to the user to
keep engagement, and make sure the insane difficulty is really insane, with
something totally new (something only us do) that make the game nearly
impossible, user can also fail on insane and hard ... don't worry if you need
to redo something on the logic or design, as long as it keep the cozy
vibe"). "Line up" was read as **One Line**: Shikaku, Tents and Light Up took
the same pass that morning in registry order, and One Line is next. If
another board was meant, this one stands on its own and the pattern moves
over unchanged.

Shikaku's, Tents' and Light Up's passes are the pattern: this follows them
wherever the boards meet, so the game fails and celebrates one way. No
concept tab: polish of a built screen plus a rule, with the user away. The
calls below are for the user to judge on the phone.

## 1. Hard and Insane can be failed

- **Hearts**: Hard 3, Insane 1 (`State.HEARTS`), on the shared paper pill in
  a `HEART_ROW` strip over the figure (`_heart_row()` in `card_height`,
  `_step_for` and `_layout`).
- **What costs one**: a step the board takes (a line not walked, and on
  Insane not a second sunny one) that leaves the rest of the figure
  unwalkable: `state.step_leaves_finish(n)`, asked before the step. On Hard
  that is Fleury's question (does what is left still hang together from the
  far post); on Insane it is the Sunny Spells search (section 2). It is wrong
  by proof, not by comparison with one answer: One Line has many walks and
  any finishing one is fine. A step the board refuses (a walked line, a
  second sunny line) costs nothing: the board has said so.
- **The wrong step**: the plank is laid as usual, the snail lands WORRIED,
  the plank blushes rose, on Hard the lines it stranded wobble and blush,
  the heart's halves fall as she lands, and `EJECT_AFTER` (0.85 s) later the
  plank sinks back to stone under her as she slides home (`state.undo()`,
  no history left) with a soft wooden `slip`. Input, undo, hint, check and
  reset wait on `_ejecting`; `busy()` holds the host's hint video.
- **Out of hearts**: the whole board eases to dusk (`modulate` toward
  `DUSK`), the snail curls up SLEEPY, the ladybugs fly home, and
  `ui/hud/out_of_hearts.gd` comes up with `OL_OUT_BODY`/`OL_OUT_REST`. Try
  again takes every plank up in Reset's wave and deals the same figure with
  every heart back (hints spent stay spent); One more heart wakes her where
  she stands.
- **Insane has one hint** (`State.HINTS_BY_BAND`). Easy and Medium are as
  they were: stranding is shown after the fact and undone by hand.

## 2. Insane: Sunny Spells

The known variants of the one-stroke puzzle are directed lines (one-way
arrows), lines walked twice, and portals. None changes *which order* the
lines may come in. Sunny Spells does, and it is the snail's own need:

- Every line is **sunny** (baked sand with gold sparkles) or **dewy** (the
  ford's slate cooled toward the pond, carrying drops of dew). A sunny line
  dries the snail out, so **she may never cross two sunny lines in a row**:
  after one, the next has to be dewy. The board refuses a second sunny line
  (`STEP_SUN`, "Too sunny!"), fades the refused ones while she is dry, and
  hangs a bead of sweat by her head until a dewy line has wet her foot again
  (a puff of dew and `OL_DEW`).
- Why it is hard: an Eulerian trail with a forbidden transition. Fleury's
  rule (never cross a bridge you can avoid) no longer carries the day: a
  step that keeps the figure in one piece can still leave it where sun has
  to follow sun. The reasoning it asks is per post -- every pass through a
  post pairs a line in with a line out, and no pair may be two sunny lines,
  so a post needs as much dew as sun (`OL_TIP_POSTS`) -- and it has to hold
  for the whole walk at once.
- **The board**: 5x5 posts, 42 to 46 lines, about 20 sunny. Built by
  `Gen.generate_sun`: an ordinary figure, a random trail through it
  (`Gen.random_trail`), and the sun planted along that trail at 0.7 unless
  the line before was sunny (`Gen.plant_sun`), so a walk always exists. The
  planted walk is banked with the figure and is what a restored day walks
  (`state.solution_path()`).
- **Judging** (`Gen.Sun`): a depth-first search over (lines walked, post,
  dry) with a dead-state memo, pruned at every node on the figure staying in
  one piece and on every post having dew enough to pair its sun with. On the
  banked boards it answers in 55 nodes or fewer and 3 ms or less, a proof of
  "no walk" included (1095 steps probed); `budget` bounds it anyway.
- **Banked** (`content/insane/oneline.json`, mined by
  `tools/insane/oneline_ladder.gd`). The rung is how often a player who
  knows the old rule and not the new one fails: `Gen.sun_blind_odds` walks
  the figure 400 times at random, never taking a refused line and never
  stranding it, and the rung is the per-mille of walks that still dead-end.
  A kept board fails more than 96.5% of such walks (Hard's rule alone always
  finishes). `work` is the dead steps along the planted walk. An empty bank
  falls back to a live `generate_sun` at the same knobs.
- Level card: "5 × 5, sunny spells" (`OL_LVL_3`). Rules add `OL_RULES_SUN`
  and the hearts line.

## 3. Rewards

- **Daisies**: a post with no line left to walk opens a daisy on its pale
  cap (`_bloom`, `bloom`), on every level. Undo and the eject fold them.
- **Streak** (Binairo's, Shikaku's, Tents', Light Up's): right steps in a
  row -- one that keeps the figure finishable. `combo` pitched up the major
  pentatonic from the second, an "x3" paper bubble by the post, confetti at
  5 and 10. A stranding step, a wrong one, an undo or a reset ends it. `lay`
  itself rises a little with the streak.
- **Ladybugs** on Hard and Insane: a judged step (the player's own, never a
  hint's) calls one to fly in and ride the shell (`SnailFace.riders`): one
  at the first, then past 40% and 75% of the figure.
- **Gags**, three of every five right steps by the line's hash: the snail
  slides on **sunglasses** (`cool`); little **hearts float up** off the plank
  she just laid (`love`); a **mushroom pops up** beside the post and grins
  (`mushroom`, `ui/faces/mushroom_face.gd`).
- **Seal**: Flawless (no hint, and no heart lost on Hard and Insane, or no
  Check on Easy and Medium) stamps the gold seal; any Insane solve stamps the
  night seal, "Insane" over "Flawless" or "Sunny Spells". `share_glyphs()`
  gains the sun count and `🏅 Flawless` or `🌙 Sunny Spells[ · Flawless]`.
- **Party**: after the retrace, the snail puts on a party hat, every daisy
  opens (the last posts too) and lets its petals go in a shower, and two
  confetti sweeps. `win_delay()` gains `PARTY_EXTRA`.

## 4. Motion

- The snail lands every step with a small squash; the plank's `lay` note
  climbs with the streak.
- The refused sunny lines fade while she is dry; the sparkles on sunny lines
  twinkle.
- The wrong step, the eject, the heart split and return, the dusk, the
  ladybugs' flight, the daisies opening with a twist, the love hearts, the
  mushroom, the hat and the petal shower. Under reduce motion: no gags, no
  flights, no petals or confetti; ladybugs arrive at once, daisies stand
  open, the seal stands still.

## 5. Sound

Re-prompted toward felt, wood and kalimba, as the other three were: `start`,
`lay`, `locked`, `undo`, `check`, `reset`. New: `sun`, `dew`, `bloom`,
`combo`, `confetti`, `cool`, `love`, `mushroom`, `ladybug`, `heart_lost`,
`slip`, `out_of_hearts`, `heart_back`, `stamp`, `party`, `petals`. Rendered
on the fallback key; unheard.

## 6. Numbers

Draw-call peaks from `tests/_shot_oneline.gd -- d=<n> <mode> [rm]`
(810x1440, `--always-on-top`, `opengl3_angle`), two readings each, matched
within one:

| mode | d=0 | d=1 | d=2 | d=3 |
|---|---|---|---|---|
| solve (petals in one mesh) | 111 | -- | 113 | 115 |
| solve, petals a mesh each (before the review) | 136 | 150 | 171 | 218 |
| solve, reduce motion | 51 | 51 | 53 | 51 |
| right | -- | -- | 96 | 98 |
| right, reduce motion | -- | -- | 90 | 91 |
| wrong | -- | -- | 109 | 110 |
| wrong, reduce motion | -- | -- | 109 | 109 |

All far under the 855 budget. Suite: 122778 passed, 0 failed.
`tests/_win.gd -- oneline`: PASS.
