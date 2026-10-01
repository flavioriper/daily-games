# Trestle

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Trestle is the twenty-ninth card** (2026-09-28,
  `puzzles/trestle2d.gd`, `trestle_state.gd`, `trestle_sim.gd`,
  `trestle_gen.gd`, spec `2026-09-28-trestle-flat-design.md`, no concept
  tab -- built while the user was away). The physics bridge builder the
  user's search page showed (Poly Bridge, Build a Bridge!, Bridge Builder);
  **it is called Trestle** ("Bridges" is Hashiwokakero). Lay road, wood
  and rope between lattice points from red pins, on a budget, press Go (the
  Check button relabelled, `check_icon()` "play"): the bridge takes its
  weight, a cart of fruit drives over, members tint by load and snap past
  their limit; the cart on the far bank is the solve. Two things travel:
  **XPBD with small steps measures every member's force for free** (the
  multiplier a substep needs is the force times h squared), and **a cart as
  a moving mass lent to its member's joints**, not a wheeled body, is
  deterministic and cannot wedge. Levels are mined (`tools/mine_trestle.gd`,
  `tools/merge_trestle.py`, `content/trestle.json`) with a pruned-truss
  proof that is also the hints; **re-prove the bank after any physics
  change** with `tests/_probe_trestle_bank.gd -- write`, because moving the
  cart's start line alone shifts every run. 79-81 draw calls building and
  testing, ~146 on the win, ANGLE agreeing, vsync-capped in every state
  once the bridge mesh stopped rebuilding on idle frames. 21 cues generated
  (`roll` a loop), one take a cue, awaiting the user's listen.
  **Second pass on 2026-09-28** (the spec's section 9): the last test's
  loads stay on the bridge while building (tint plus figures), the first
  member to snap is ringed and plays slow, a daily's cost goes to the crowd
  (`submitTurn` game `trestle_<difficulty>`, score = cost as a share of the
  budget) and the strip after the solve says how many of today's bridges
  cost more, the player's own bridge is kept with the completion, and after
  the solve there are a three-cart **Convoy** and a **Free build** with no
  budget. **Polished and made loud on 2026-09-28** (the spec's section 10):
  mountains, a turning sun, drifting clouds, trees, reeds, a leaping fish and
  birds; prices float off each member, the budget bar slides, removed members
  tumble into the river; Go!, Crack!, Splash! and a shake, riders that float;
  a wave, bunting, a stamped three-star medal, fireworks and coins on the win.
  87 building, 88 testing, 151 on the win, ~278 at its peak, ANGLE agreeing. The sim's lead cart is still its scalar fields, so one-cart runs
  are unchanged. The crowd needs `tools/deploy_functions.sh` run by a person.

**Polished unattended on 2026-10-01** (`feat/trestle-tea`, spec
`2026-10-01-trestle-polish-design.md`): **Hard 3 hearts, Insane 2**; on
those bands a Go is a promise (no Stop mid-test) and a failed test costs a
heart; out of hearts the riders and the troll sleep, dusk, the shared card;
Try again drops the bridge in the river and keeps it sketched in pencil.
**Insane is the Tea Party**: the lead cart's tea is an underdamped spring on
the cart's tilt (`Sim.tea`, `TEA_RIM` 0.03 rad) and a spill fails the test,
so a stiff deck matters as much as a strong one; level banks only, budget
1.08 of the proof; the deck at the tea's worst is drawn dashed ten times
over after each test. **The tea bank must be re-mined after any physics
change** (`tools/mine_trestle.gd -- 3 <n> <seed>`, band 3 is `tea`) and
checked with `tests/_probe_trestle_tea.gd` (no obvious truss in budget,
strong trusses spill). The bridge troll (`ui/faces/troll_face.gd`) under the
near bank holds up the score card (11 for a 3-star tea bridge); hats, first-
try sunglasses, honk, ducks, nap cat on the deck, seal. The bridge settles
after a test, tags pop, the budget rolls, the cart rolls in. WORKSHOP sound
set, 33 cues, unheard. Peak 212 draw calls.
