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
