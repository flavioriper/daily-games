# Trestle polish: hearts, the Tea Party, the troll and the workshop's sound

2026-10-01, built unattended on `feat/trestle-tea` at the user's word
("let's polish the trestle game, add more smooth animations, reinforce that
the sfx sounds are really cozy, add more visual rewards even if silly to
the user to keep engagement, and make sure the insane difficulty is really
insane, with something totally new (something only us do) that make the
game nearly impossible, user can also fail on insane and hard ... also
don't worry if you need to redo something on the logic or design, as long
as it keep the cozy vibe").

Marigold's, Knight's and Super Slider's passes the same day are the pattern
for hearts, dusk, the card and the seal. The board's own spec
(`2026-09-28-trestle-flat-design.md`, sections 9 and 10 included) stands
except where this says otherwise. The calls at the end are for the user.

## 1. Bands and hearts

| band | gap | hints | hearts | Go | Insane's rule |
|---|---|---|---|---|---|
| Easy | 4-5 | 3 | - | Stop allowed | - |
| Medium | 5-7 | 3 | - | Stop allowed | - |
| Hard | 7-9 | **2** | **3** | **a promise** | - |
| Insane | 8-10, level banks | 0 | **2** | **a promise** | **Tea Party** |

`HINTS_BY` / `HEARTS_BY` in `puzzles/trestle2d.gd`.

- **A failed test costs a heart** on Hard and Insane: a snap that drops
  the cart, a cart in the river, a road that doesn't reach, a stuck cart,
  spilled tea. The heart splits and falls off its sign the moment the test
  fails; the toast after says how many are left (`TR_HEART_LOST_*`).
- **The Go is a promise** (`_committed()`): once the cart sets off it runs
  to the end. Without this a player could press Stop at the first red
  member and every test would be free. Go during a test says
  `TR_ROLLING`; Reset, Undo and Hint wait (`can_reset()`). The convoy and
  the free build after the solve are never committed.
- **The sign** hangs off the strip's left end on two strings (the strip is
  full: chips and budget). The toast moves down under it on those bands.
- **Out of hearts**: the riders and the troll nod off, dusk falls
  (`modulate` to `DUSK`), and the shared card (`ui/hud/out_of_hearts.gd`,
  `TR_OUT_BODY` / `TR_OUT_REST`). **Try again**: the bridge tumbles into
  the river (a hint's members stay: hints spent stay spent), hearts full,
  clock, moves and tests from zero, and **the last bridge stays sketched in
  pencil** (dashed, faint) where nothing stands, to rebuild from. **One more
  heart** (a video, once): one heart, the bridge exactly as it was.
  **Back**: `finish_unsolved()` and `leave`.

## 2. Insane: the Tea Party

**The riders carry cups of tea filled to the brim. A bridge that sags, or
bends sharply at a bolt, tilts the cart and spills the tea, and a spill
fails the test. The bridge must be stiff and level, not only strong.**

- **Why it is ours**: checked 2026-10-01 against the genre (Poly Bridge 1-3,
  Bridge Constructor, Build a Bridge!): hydraulics, springs, jumps, boats,
  checkpoints, drawbridges, many vehicles. Every one judges a bridge by
  whether it breaks. None judges how level the deck stays under the load
  -- the engineer's serviceability limit, here as a cup of tea.
- **The rule in the sim** (`puzzles/trestle_sim.gd`, `tea`): the tea's
  surface against its cup is an underdamped spring (`TEA_HZ` 1.4,
  `TEA_ZETA` 0.22) chasing minus the cart's tilt, so a slow lean leans it
  and a kink at a joint (the cart's angle stepping from one member to the
  next) sloshes it past the lean. Past `TEA_RIM` 0.03 rad it spills:
  `spilled`, an event, `done()`; `crossed()` is never true after a spill.
  Only the lead cart carries tea. Level banks only (`dy` 0): a ramp would
  spill by its own slope.
- **Why 0.03**: calibrated on the shipped bank before the change. The
  strength-only proofs of Insane leaned the tea 0.04-0.05 rad and Pratt
  trusses under the deck about 0.05; a truss both over and under the road
  leaned 0.015-0.025 at twice the cost. 0.03 puts the obvious strong bridge
  over the rim and the stiff one under it.
- **Why it is nearly impossible**: measured by
  `tests/_probe_trestle_tea.gd` on the shipped levels: on **every** level
  no obvious full truss (six shapes, three diagonal patterns) both fits the
  budget and gets the tea over, and on every level a strong truss that
  holds the cart still spills. Only a pruned, tuned design crosses, the
  budget is the proof's cost times **1.08** (Hard's slack is 1.25), the
  cart is the heaviest, there are no hints and two hearts.
- **Fair, always**: the levels are mined (`tools/mine_trestle.gd`, band 3
  is `tea`): `Gen.proves` also asks that the proof's tea lean stays under
  `TEA_MARGIN` 0.85 of the rim, and the miner tries a truss over and under
  the road twice (`[1, 2]` joined the shapes). `tests/_probe_trestle_bank.gd`
  re-proves every level with the tea (under 0.95 of the rim).
- **What the player sees**: a teacup before each rider on the cart, steam
  curling while it stands; during the test the tea's surface leans in its
  cup (drawn `TEA_DRAWN` 0.5 rad at the rim, the real 0.03 being invisible)
  and a drop shows at the low rim when it is close. A near miss sloshes
  (`slosh`); a spill splashes tea off every cup, "Spilled!", and the toast
  `TR_TEA_SPILLED` names the cure. **After the test the deck as it stood at
  the tea's worst moment is drawn dashed, its dip ten times over**
  (`SAG_GAIN`), purple, red when it spilled, with a tag over where the cart
  was: "Tea 101%". That is the learning loop the hearts pay for.
- `TR_LVL_3` "Tea Party: a heavy cart carrying brim-full tea";
  `TR_TIP_TEA`; `TR_RULES_TEA` appended to the rules on Insane (and
  `TR_RULES_HEARTS` from Hard). A solve shares `🫖`, says "Not a drop
  spilled!", clinks the cups with hearts off them, and stamps the night
  seal ("Insane" over "Tea Party", or "Flawless"). The troll's card goes
  to eleven for a three-star tea bridge.

## 3. Rewards, even silly

- **The bridge troll** (`ui/faces/troll_face.gd`, new): small, mossy and
  friendly, with a daisy in his moss, freckles, a big round nose and two
  baby tusks. He stands chest-deep behind reeds on a stone at the foot of
  the near bank, bobbing, and watches the cart while it runs (the joint
  being built from, otherwise). He nods (a hop) every fourth member laid
  and when the cart honks, ducks under from a snap, looks puzzled at a
  splash or a spill, sleeps when the hearts run out, and after the solve
  **holds up a score card**: 10 for three stars, 8 for two, 6 for one,
  **11** for a three-star Tea Party. The card stays up while the solved
  bridge stands.
- **The horn**: the cart honks at mid-span every test, notes off its front.
- **Party hats** on every rider at the crossing, one after another, and
  **sunglasses** too when the bridge crossed on its first test, with
  "First try!" (or "Not a drop spilled!" on a Tea Party).
- **Ducks**: a duck and three ducklings paddle along the river under the
  new bridge (`quack`).
- **The nap cat** hops in from the far bank along the deck and curls up on
  its middle joint (`purr`); she stays asleep there while the bridge rests.
- **The seal** stamps in the sky left of the medal: gold Flawless (no
  hint, and no heart lost on Hard and Insane or the first test on Easy and
  Medium), night for any Tea Party solve. `completion_record()` keeps
  `hearts` and `flawless`; a share adds ✨ for Flawless.
- **Bridge wisdom** (`TR_CHEER_0..7`), the same one for the same day.
- The win screen waits `PARTY_END` 4.2 s (was 3.0) for it all.

## 4. Smoother motion

- **The bridge settles**: back to building after a test, every member eases
  from the shape the test bent it to back to rest on a back-out
  (`SETTLE_TIME`, `settle` creak), instead of snapping straight.
- **Load tags pop in** one after another (`TAG_POP`, `TAG_STEP`).
- **The budget figure rolls** to the cost rather than jumping.
- **The cart rolls in** from off the card when the board opens, wheels
  turning, the roll sound under it.
- Hearts split and fall, and pop back; dusk fades in and out.
- All of it off under reduce motion (the settle, the roll-in, the tags'
  pop, the ducks; the party's pieces appear in place).

## 5. Sound

A new style in `tools/gen_sfx.py`: **WORKSHOP** -- close-mic foley of a
small wooden toy workshop by a stream (pine planks, hemp rope, brass bolts,
a wooden toy cart, china teacups, a brook) -- and **WORKSHOP_TUNE** -- a
real kalimba, music box and hand bells. All 21 old cues taken again (the
house marimba, the cartoon slide whistle and splash and the tape-rewind
undo are gone; the clicks use `cut:` so a take keeps one transient) and 12
new: `settle`, `honk`, `clink`, `slosh`, `spill`, `heart_lost`,
`out_of_hearts`, `heart_back`, `scorecard`, `stamp`, `quack`, `purr`.
ElevenLabs takes no clip under 0.5 s, so the shortest are asked at 0.5 and
cut. Rendered on the fallback key, each checked for length and level
(peaks -5 to -14 dBFS); **unheard** by a person.

## 6. Numbers

`tests/_shot_trestle.gd` at `--resolution 810x1440 --always-on-top`,
windowed, one at a time (new modes: `spill`, `out`, and a party shot after
a solve):

| run | band | draws |
|---|---|---|
| empty / built / test | Insane | 88 / 88 / 86 |
| win, party | Insane | 163, 144 |
| win, party, ANGLE | Insane | 163, 92 |
| win, reduce motion | Insane | 212 |
| spill, test then building | Insane | 123, 88 |
| out of hearts (card), Try again | Hard | 125, 103 |

Peak 212, 643 under the 855 budget. The suite `passed=122403 failed=0`;
`_probe_trestle.gd` and `_probe_trestle_convoy.gd` as before;
`_probe_trestle_bank.gd` holds every level of every band;
`_probe_trestle_tea.gd` as in section 2.

## 7. Calls for the user

- **Insane is the Tea Party.** Considered: wind gusts on the span (a side
  load in a 2D truss reads as a heavier cart, not new); a cart that grows
  heavier as it picks up fruit (a load case, not a rule); woodworm (members
  that weaken each crossing: invisible, unfair); one Go only (that is just
  hearts). The tea changes what a good bridge is, and it shows.
- **Hard's hearts are tests**, since a failed test is the only way to lose
  in this genre; three tests against a bridge the hint lays in a few
  members can still be lost, by a careless Go.
- **The Go is a promise** on Hard and Insane (no Stop mid-test).
- **Try again clears the bridge** (into the river) but sketches it in
  pencil: losing costs the work, not the memory. Easy and Medium keep free
  tests and no hearts.
- **The old Insane levels** (ramps, any `dy`) are gone from the bank; 
  Insane is level banks only. Hard keeps ramps.
- The troll, his card, ducks, hats, cat and cups were judged on stills.
  Sounds unheard.
