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

**Checked up on 2026-10-03** (`feat/checkup-trestle`, the row in
`docs/agents/checkup.md`). How it is drawn now: the still scene (sky, hills,
banks, river) is built for a width and a grid step and drawn shifted while a
relayout only slides it up; **the bridge, the front layer and the budget bar
are `RunMesh` meshes put together from looks** (`Look`, `LOOK_MEMBER`,
`_make_look`) made once at the grid step the board first laid out at (`_ru`)
and drawn scaled by `_k()`. A member is `_put_member(rm, p, q, material,
rest length, inks)`; its inks come from `_load_inks` (24 load steps) or
`Parts.member_inks` (`ui/faces/trestle_parts.gd` now splits `member` into
`member_inks` and `member_in`; the menu card still calls `member`). 92 draw
calls building and testing, 127 at the win's peak. The words are warmed at
open (`_warm_words`) and no star is ever lettered as text. **A running test
waits while the host holds the clock** (the ? or the settings up).
`tutorial_pages()` hands 5-7 pages of `ui/hud/trestle_tutorial_diagram.gd`:
its `Gap` is this board dealt a hand-made three-step gap through `_deal`,
with the layout hooks `_view`, `_strip_shown`, `_scene_top`, `_sign_top`,
`_sign_left` and the doors `_sticker`, `_tell`, `_warm_words` shut. The
lessons' bridges were tried in the sim at cart 1.6: the road alone snaps,
two struts from the low pins hold at 0.73, two ropes from posts at (-1, 1)
and (4, 1) at 0.80, and with tea the two struts spill at x 2.46 where the
two knight's-step braces carry it at 0.77 of the rim; change the sim and
try them again. **The sim's step was tightened without changing a bit of
its arithmetic** (the substeps on locals, the compliance a member a step):
any further change there must give the same hash over every banked proof,
or the bank and the tea bank are re-mined as before.

**Haptics (2026-10-03, `docs/agents/haptics.md` row 29).** The building and
Go tap, the test is silent, its verdict is the one knock (`_failed`,
`_lose_heart`, `_crossed`, `solved`). Probe: `tests/_probe_perf.gd --
trestle d=<n> x=buzz` (`_buzz_trestle` plays the whole board itself: fails
tests to the last heart, lays the proof, wins and sends the convoy).

**Left as it was on 2026-10-04** (`docs/agents/flat-screens.md`, "Insane
counts moves"). A heart here goes only when a test the player sent fails in
the sim, by snapping or spilling in plain sight: nothing is compared with
the proof as a member is laid, and nothing is refused but what every band
refuses. It is Drumbeat's case, a budget of attempts. It was not re-dressed
as the pill either: "2 moves left" would stand still through a dozen
members laid and drop only at a failed Go, and the shared lines (a piece
put down costs one) are untrue of it. `HEARTS_BY` stays `[0, 0, 0, 2]`,
Insane already has no hint, and Undo only takes back a member. A real move
counter here (a member down or off costs one, tests free) would be a new
design with a re-mined bank, not a conversion.

**Sounds redone on 2026-10-10** against the cozy rules (the `trestle` row of
`docs/agents/sound.md` has every cue): wooden tocks on felt, air and one
muffled kalimba note in place of the WORKSHOP set, 33 cues, unheard. At play
the medal's stars are `select` at 1.06, 1.16 and 1.26 (`MEDAL_PITCH`,
`MEDAL_PITCH_STEP`; they were 1.15 + 0.2 a star), a piece dropped into the
river is `splash` at 1.0 to 1.12 and -6 dB (`DROP_PITCH`, `DROP_DB`; 1.3 to
1.6 at -9), and a snap and a creak vary by 0.94 to 1.06 (`TICK_VARY`; 0.9 to
1.1). `cross` and `solved`, and `fail` and `heart_lost`, sound on one frame,
so `cross` is two notches and `heart_lost` one note: neither is a second
phrase.

**One material (2026-10-10).** The user: "Trestle should have a single
material for now, no need for 3". The strip has no chips (`CHIPS` 0 in
`puzzles/trestle2d.gd`; 3 brings them, their picking and `_mat` back) and
the budget bar takes its width. The hand lays wood, and **a piece laid along
the deck's line is the road** (`Gen.on_deck`, `Gen.mat_for`, asked by
`_mat_for` in `_lay` and for the ghost): the sim, its two kinds and their
prices are untouched, so its arithmetic and the lessons' bridges stand. What
is given up is a road anywhere but the deck's line. **Rope is offered on no
band** (`Gen.BANDS` mats are road and wood); it is still in the sim, the
drawing, the sounds and the locale, and the tutorial's rope page shows only
where `state.mats` has it. The bank was mined again without rope on the
seeds it had (band 0 kept as it was, it never had rope): 17, 19, 20 and 65
levels (69 tea levels mined on seeds 3001 to 3006, 4 dropped by
`_probe_trestle_tea.gd -- write`), every proof at 0.85 or under in
`_probe_trestle_bank.gd`, every proof's road on the deck and nothing else.
The rope bank is `build/trestle/rope/` on this Mac and in git before this
commit. Texts in three languages no longer name rope or the chips
(`TR_RULES`, `TR_LVL_0`, `TR_LVL_1`, `TR_CHEER_2`, `HTP_TR_BUDGET_BODY`,
`HTP_TR_PICK_CAP`); the tutorial's budget page taps no chip. A bolt let go
plays `select` at 0.9. Shot on Normal: 105 to 107 draw calls building and
testing, 86 to 91 after. Not on a phone; the tutorial pages were not shot
again.

**The cart drives on wood (2026-10-10, the same evening).** The user: "the
car falls to the water because it doesn't see wood as road". A piece two
long laid along the deck was wood, and nothing but road carried the cart.
Two changes: `Gen.on_deck` is any piece with both ends on the deck's line
(one step or two), and **the sim's cart takes a wooden beam where no road
leads on** (`_drivable`: road, or wood no steeper than one in one; rope
never; `_next_road` asks for a road first, so a bridge with its road laid
drives bit for bit as before, and `_land` lands on either). The bank holds
as it did (17, 19, 20, 65 at 0.85; the tea probe 65 of 65), and every
proof with its road swapped for wood still crosses on Easy, Normal and
Insane, 16 of 20 on Hard. Known and left: a deck built of wood one row off
the line is cheaper and stronger than road, so budgets are looser than the
miner meant.
