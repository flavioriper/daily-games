# Bridges

Moved verbatim from CLAUDE.md's "The flat screens" on 2026-09-29.

- **Bridges is the first board whose field is not paper** (2026-09-20,
  `puzzles/bridges2d.gd`, spec `2026-09-20-bridges-flat-design.md`, mock
  `docs/brainstorm/concepts.html#bridges`). Islets with numbers, 0 to 3
  planks between facing pairs, no two runs crossing, and **every islet in one
  single network** at the end. **It is called Bridges and nothing else**, in
  code, in a comment or on screen: it is Hashiwokakero, and the reference it
  was designed from ships it under a third name; the spec records both once
  in order to forbid them. That is the fourth rename after Code Break, Hidden
  Word and Word Trail.
  **The sea taught the set something.** It was first drawn in `Pal.WATER` and
  was the loudest surface in the game; it is now
  `mix(WATER_HI, PAPER, 0.46)`, and letting the blue down into *paper* rather
  than into a sky colour is what keeps it warm. Two things invert on a pale
  ground -- the ripples are darker than the water and the shallow band is
  paler than the open water -- and the beach had to move from `STONE` (value
  237 against a 230 sea, so the islets stopped reading at all) to `ACORN`.
  **A warm-ink alpha tuned against a dark ground is not portable to a light
  one, in either direction**: three of five re-tunes were reversals, and the
  pale sea *deleted* the special case where `BAD` over deep water came back
  mauve and had to be drawn opaque.
  **The generator grows the answer and then proves it.** Range propagation
  plus a group rule with **two** halves, and the second is load-bearing: a
  group with no still-open lane out is a contradiction, and a group with
  exactly one **must take it**. Drop the forcing half and the guess-free
  rates collapse. The GDScript solver and the mock's JavaScript one agree to
  within two points on attempts, second-answer rejection and guess-free rate
  across all three bands, and both were cross-checked against brute-force
  counters -- which is a better statement about the proof than either alone.
  Worst case 47 ms against the 194 ms gate.
  **`is_solved()` is every rule at once and never a subset** -- every number
  met, no two runs crossing, and one single network. The crossing clause is a
  backstop (`cycle()` refuses a crossed lane) and it was added on 2026-09-20
  with the bug that made it reachable: `hint()` lifted only the **first** lane
  blocking the plank it wanted, and a lane can be blocked by several, so a
  hint could leave two runs crossing with both frozen. A hint now lifts every
  blocker, and costs one undo per blocker plus one. The near-miss
  -- every number met, the islets in two rings -- is **unsignposted by
  decision**. Check is the only door and it costs a check, which is why
  **Check's marks flash and then hold until the next move** rather than
  fading as Nonogram's do: a paid-for answer is kept, and a reduce-motion
  player, who is drawn no flash at all, is shown something.
  Measured with `tests/_shot_anim.gd -- bridges` at `--resolution 810x1440`:
  **64 bare, 64-65 played**, against the 855 budget, with Word Trail (65, 65)
  and Queens (71, 71) both reproducing their recorded counts as controls in
  the same session. Idle read 3.11 to 4.22 ms over eight runs -- but Word
  Trail's idle came back 20-40% above *its* record in that same session, so
  **the counts from it are trustworthy and the milliseconds are comparable
  only within it**. ANGLE agrees on 65 and matches to 4/255 on the sea's
  gradient rounding; the one three-figure difference is the shared wordmark's
  sun-dot, whose glint is on its own clock and differs that much between two
  runs of the *same* driver.
  **It was designed against a grid that had no pager, and merged into one
  that had.** While this board was being built, `ui/menu.gd` still looped the
  whole registry with no cap, so its own registry entry made a fifth card row
  and pushed the bottom bar off the screen -- the menu read 313 draw calls
  against 322 because the bar had left, which is a symptom that looks nothing
  like its cause. Mushroom Patch and Sudoku landed the pager before this
  merged, so Bridges is simply **the fifteenth entry and the third card on
  page two**, and none of that bites. It is written down because the next
  board added without a pager in front of it will see exactly the same thing.

- **The polish of 2026-09-30** (spec `2026-09-30-bridges-polish-design.md`)
  started from "players can't understand the game". **Two planks, not
  three** -- every other telling allows two, and our own How-to-play caption
  already said so while the board took three. A ring of slots round each coin
  fills per plank; a tap on a lane's water lays a plank; a tap on an islet
  reads it out; the near-miss is **named now** (it was silent by decision,
  and the silence read as a broken board); a ghost finger shows the drag on
  Easy and Medium until the first plank; the How-to-play diagram got its own
  sea. Hard and Insane judge every plank (`state.add`): a wrong one is never
  laid in the state -- `_sinking` draws it rolling, landing, cracking and
  sinking -- and the lane keeps a buoy (`state.ruled`). Insane is **Lantern
  Night**: a lantern counts linked islets, not planks (`state.count()`), dealt
  from `content/insane/bridges.json`.
  **With two planks the proof is strong enough that uniqueness nearly
  implies "propagation finishes it".** Lighting lanterns in a shuffled order
  left 59 of 60 boards propagation-solvable; lighting them best first
  (whichever leaves the most lanes open) and mining 4000 tries is what finds
  boards needing suppositions (one in six). Dark islets with no number were
  tried and dropped: ~50 s a proof and no harder boards.
  **`restore_completed_board` used `now - 100` as "long solved", and
  negative was the unsolved sentinel**, so a day reopened in the first 100 s
  of a session came back unlit. The sentinel is `-INF` now; any board that
  writes `t - 100.0` into a clock that is also checked `< 0.0` has the same
  bug.

- **The checkup of 2026-10-02** (`docs/agents/checkup.md`, row 15). The lag
  was the board mesh -- 84k vertices, every plank's slats and posts and every
  islet's moss, sprouts, coin and ring -- built in script on every animating
  frame (30-53 ms), and a move animates for a second. It is now two
  `RunMesh`es: an islet is its body (per islet, and per over-or-not), its
  pennant (per hue), its coin (one shape, painted through three slots, so the
  wave's gold and a glint are a fill) or lantern (five slots; a turning one is
  drawn live) and its ring of slots (per want, got, over), each a shape under
  the islet's own scale and offset, so a bumping, hopping or dancing islet
  costs a transform; a run at rest is one shape cached by its rest key
  (`_run_rest`: count, halo, Check's held tint, the wave's gold all on or not
  come), and only a run rolling out, previewed, rattling or half lit is drawn
  live, into the room its lane got the first time it was drawn. **The win
  card's glint is hidden under a lit run's gold**, which is why a run at rest
  after the wave ignores its shine. Shapes are made in the first layout's
  space and the meshes drawn under `_relay()`, so the win card's half-size
  board reuses them; the sea cannot follow (its pool changes shape there) and
  is made again once, ~17 ms, inside the host's win frame. What idle is left
  is the sea's stacked translucent pool (fill, ~1 ms on native GL).
  The tutorial (`ui/hud/bridges_tutorial_diagram.gd`) deals its own 5x5 seas
  by hand (`Sea.lay`, through `_begin()`, the half of `build()` after the
  deal) and plays them through `_gui_input`; its seas have no ripple dashes,
  which are spaced in pixels for a full-size pool and bunch up on a page.

### Solved by the four rules, no guess (2026-10-04)

The user, after Nonogram, Sudoku and Queens: "include them both in this new
rules" (Bridges and Mushroom Patch). Only Easy asked for a board propagation
finishes; Medium and Hard asked for one answer, and Lantern Night's bank was
lit best first to *find* boards needing suppositions.

- `BANDS[].guess_free` is true on every band: `generate` regrows until the
  four rules (`_propagate`) pin every lane. With two planks that costs
  nothing: 60 seeds a band, 1.9 / 2.2 / 2.9 attempts mean (worst 11), 1-2 ms
  mean, worst 10 ms.
- `Gen.reasoned(n, islets, need, lanes, lanterns)` is the proof: propagate,
  every lane pinned, the board legal. `solve_logic`, `_pinned_wrong` and
  `_open_after` are gone.
- `generate_lanterns(rng)` (no `quick`) lights islets in one shuffled walk
  while `reasoned` holds; the base board is `reasoned` too. 30 of 30 seeds
  kept `LANTERN_MIN`, 21 ms mean, so the live fallback is the same deal.
- The ladder's rung is the lanterns kept (gate `LANTERN_MIN`). Re-mined:
  3000 of 3000 passed, the 150 kept carry 12 to 15 lanterns, all re-proved
  through `from_bank` and counted to one answer.
- No tip told the player to suppose; nothing on screen changed. Medium, Hard
  and banked Insane days finished earlier restore a different board.

- **Insane counts moves** (2026-10-04, `docs/agents/flat-screens.md`,
  "Insane counts moves"). `State.HEARTS` is `[0, 0, 0, 0]`, so every band
  lays planks through `cycle` (0-1-2-0): nothing cracks and sinks, no lane is
  `ruled`, no buoy (`add`, `_judged_move` and `_wrong_plank` stay, never
  reached). Lantern Night hands out the answer's planks + **4**
  (`MOVES_SLACK`, `moves_budget()`; 49 for 45 planks): every step of a lane's
  cycle costs one, the lift included. Four and not the family's three because
  a plank only comes off by going round, so one slip is three moves to mend;
  three would leave nothing to spare. `BR_RULES_MOVES` says so in the board's
  words (the shared sentence speaks of taking a piece back). No Undo, hint or
  Check on Insane; its tutorial drops the OVER page (it teaches Check) and
  the Undo page for the shared moves page. **The ghost finger is off on
  Insane** (`_pick_coach`): with `judged()` false it would have started
  showing a lane of the answer there. What stays is Medium's: an islet over
  its number in rose, the two refusals, the named near-miss.

### The open sea is the whole screen (2026-10-13)

The redesign (`docs/agents/flat-screens.md`, "Every board gets a world of
its own"), built unattended. `puzzles/bridges_world.gd` is the board's own pale
sea under a cream morning mist at the top (the wordmark is ink), lily pads
and a red buoy in the gap of the tools row, and at the foot a curved beach
with a jetty and its lantern, a stack of spare planks, a dinghy and an
oar, rocks, tufts and a starfish; glints and the lantern's glow breathe.
**The framed pool is gone**: once bled the basin, its wall, the shore band
and the rim are not drawn, and the islets stand in open water. Insane's
Lantern Night is the world's dusk veil (`set_night(true)`), whole from
0.285 down. The lattice is on the host's margin; the party boat sails the
water just under it.

- Registry: `bleed`, `level_card`, no actions row. **Check is gone**:
  the board solves itself.
- `opengl3_angle`, 810x1440: 85 draw calls at rest; `tests/_win.gd --
  bridges` passes with real drags.
- Decided for the user, unconfirmed: no pool; no Check; a cream-to-blue
  mist, not the card's dark teal. Seen and left: the win's grey line
  under "Well done!" is faint on the blue. Owed: a phone, Insane's dusk
  over the beach, the level slide.

### Seen from above (2026-10-17)

The user, of the 2026-10-13 world: "i hate bridges design, it looks like a
old flash game made in canvas or something like this, nothing elegant". Of
three directions (calm top-down water, a nautical chart, a lantern lake at
dusk) they picked **calm top-down water**. Rules, generator, state, sound
and motion are untouched; only the drawing changed.

- **One point of view.** The islets were side-on drums under a moss lip and
  a lipped coin, on a top-down sea, beside an angled beach. Now everything is
  straight from above: an islet (`_islet_body`) is its shadow thrown down
  and right (`ISLET_SHADOW`), wet sand, dry sand (`SAND_DRY`), moss
  (`TURF_R`) shaded at its rim and lit up and left, outlines wandering only
  `MOSS_WOB` from round on two slow waves (nine quick ones read as a cog).
  No sprouts, flowers or pennant. The number sits in a flat inlay
  (`_inlay`, `COIN_FACE`, `COIN_LIFT` 0); the slots are grooves on the sand
  ring (`SLOT_R` 1.48), wood when filled, leaf when met, rose when over, and
  an empty one is `SAND` toward ink by 0.24: at 0.12 it vanished.
- **The planks** are 0.17 of a cell with 0.06 between (two read as a deck,
  not two hairs); the deep wood shows as an even `PLANK_EDGE` of 1.5 px along
  both long sides; **no pilings** (`_posts` is gone, so are `POST_*`). Their
  shadow lies down and right like the islets'.
- **The drag's lane** is a pale wash (`SURFACE` at 0.42), 0.42 of a cell, a
  hair wider than two planks, so the ghost plank sits on it; it was a gold
  band 0.62 wide that read as a beige bar on the blue. The aim ring is pale
  and thinner (0.09, floor 4 px).
- **The open water** (`_build_open_sea`) carries only the shallows round each
  islet (`SHALLOWS`, two soft discs). Ripples, pads, blots are not drawn
  bled; the tutorial's framed pool still uses them.
- **The world** (`bridges_world.gd`) is mist over water easing from a clear
  blue to a deeper teal at the foot, three broad patches of light breathing
  (the old glint child), and three lily pads at the screen's edges. The
  beach, jetty, lantern post, planks, dinghy, oar, rocks, tufts, starfish,
  ripples, glints and buoy are gone.
- **The lattice is centred** down the span the rows leave (`_pool`, bled);
  at the top it left a third of bare sea under it once the beach went.
- **The menu card** (`ui/menu/cards/bridges.gd`) draws the same islet,
  inlay, grooves and plank; it keeps its own dark lagoon.
- `opengl3_angle`, 810x1440, `_shot_anim.gd -- bridges`: 80 draw calls at
  rest (was 85), Insane (`d=3`) 80; `tests/_win.gd -- bridges` passes with
  real drags; suite 248522/0.
- Decided for the user, unconfirmed: the lattice centred; the pennant
  dropped (the coin's wash and the grooves already say "met"); the menu
  card's lagoon left dark. Owed: a phone, the user's eye on Insane's dusk.

### Made fun: the board says when it is lost (2026-10-27)

The user: "make bridges experience way better to play, and game itself way
funnier to play, right now nobody likes it", autonomous, pushed when done.

- **Measured first** (`tests/_probe_br_fun.gd`, 60 days a band): a player
  who never pushes an islet over its number and lays planks at random
  stalls short of the solve in 49/57/59 of 60 games on Easy/Medium/Hard.
  In 49/57/59 an islet goes dead (short of its number, no lane left that
  can make it up) and they lay 8.8/14.8/28.2 more planks before stalling,
  the board silent; a sealed-off group (every number in it met, cut from
  the rest) forms in 3/8/10 and 7/9/27 planks follow it. The near-miss
  line came only once *every* number was met, i.e. at the very end. The
  same player who takes a plank back the moment one of the two is true
  stalls in **10/15/39**: the facts alone carry a guesser most of the way.
- **Taken from the apps.** The solver's "too few, certain" flag and its
  isolated-group flag (Simon Tatham's Bridges marks both red as they
  happen), and Conceptis Hashi's highlight of the allowed directions from a
  pressed island.
- `State.stranded()` (an islet short of its number whose open lanes cannot
  supply it: a crossed lane gives nothing, a full one nothing more, a lane
  no more than the far islet still wants; lanterns never named) and
  `State.sealed()` (every group of met islets while there is more than one).
- **The rose halo** (`SHAPE_HALO`, `Pal.FLOWER`, `HALO_*`): `_stuck` is the
  stranded islets and every islet of a sealed group, recomputed in
  `_network` after every move, Undo and hint; a cached shape in the islet
  mesh, so no draw call. With every number met all groups are sealed and
  the biggest goes bare (the near-miss's own rule, which still speaks
  `BR_SPLIT`). A hand that puts a halo on hears `split`, feels WARN, sees
  the new islets pulse with the near-miss's rings, and the card says
  `BR_STRANDED` or `BR_SEALED` ("Take a plank back"). Undo takes it off
  silently. A plank that leaves any halo standing builds no streak.
  Easy to Hard (`STUCK_BANDS`): **Lantern Night keeps its silence**, the
  user's to call.
- **The ways out** (`_way_bands`, `WAY_ALPHA` 0.2): while an islet is
  pressed, every lane it faces that a drag could lay on is a faint wash, the
  picked one `_aim_band`'s as before. Every band.
- `BR_TIP_STUCK` joins the tips below Insane; the tutorial's OVER page
  gains `HTP_BR_OVER_BODY_STUCK`. Rows en/pt/es.
- `tests/_shot_bridges.gd stuck` (new mode): opengl3_angle 810x1440, Medium,
  the ways out, a halo on a stranded 3, Undo taking it off: peak 92 draw
  calls, as `right` read before the change. `_win.gd -- bridges` PASS with
  real drags; suite passed=303276 failed=0; every band's tutorial pages
  played 6 s headless, no script error.
- Decided for the user, unconfirmed: the halo free on every band but
  Insane; the pulse and WARN on a fresh halo; no streak while one stands;
  the ways-out wash on every band. Not on a phone; the `split` cue on a
  halo not heard.
