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
