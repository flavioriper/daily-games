# Tier 1 prototypes — build notes

Ten playable prototypes in one Godot 4.7 project, portrait, touch-only.
699 generator tests plus a 10/10 end-to-end win suite.

Run: `godot --path .`
Unit tests: `godot --headless --path . --script res://tests/run_tests.gd`
Win suite: `godot --path . --resolution 540x960 --script res://tests/_win.gd`
Screenshots: `godot --path . --resolution 540x960 --script res://tests/_shot.gd`

| Puzzle | Gesture | Generator shape | Uniqueness proof |
|---|---|---|---|
| Binairo | tap-cycle | build-then-strip | backtracking count to 2 |
| Code Break | tap-cycle | random code | n/a -- calibration, not uniqueness |
| Balance | tap-cycle | constructive secret + anchor | brute force over the domain |
| Pipes | tap-rotate | spanning tree, then scramble | free by construction |
| Untangle | drag | Delaunay, thinned, then scatter | n/a -- any planar embedding wins |
| Shikaku | drag rect | recursive partition | exact cover count to 2 |
| Tents | tap-cycle | place pairs directly | matching search count to 2 |
| Light Up | tap-cycle | walls, bulbs, strip clues | backtracking count to 2 |
| One Line | drag path | random lattice, fix parity | degree parity -- no search at all |
| Nonogram | tap-cycle | random blob, line-solve to check | line-solvable implies unique |

## What building them changed

**1. Three of the ten had no unique solution at all, and it took a test to notice.**
Balance scales are homogeneous equations, so if `(1,2)` works then so does
`(2,4)`. Every generated puzzle had nine answers. The fix is a revealed anchor
weight. A second, subtler failure: with pans capped at three shapes, a secret
like `(1, 9)` has no expressible relation between its shapes, so uniqueness is
*unreachable* no matter how many scales you add. The secret now gets built
constructively, each shape a sum of shapes already introduced.

**2. Untangle had a false win.** Drag every node onto the same point and all
edges become zero-length; zero-length segments never intersect, so the
crossing count is zero and the game declares victory. A player finds this in
under a minute. `is_solved()` now requires a minimum node separation too.
This was found by an end-to-end test, not by a unit test -- the generator was
perfectly correct.

**3. Delaunay is the wrong density for a phone.** Triangulation gives ~3 edges
per node, which rendered as 47-crossing spaghetti with nodes stacked on top of
each other. Thinned to ~1.7 edges per node while preserving connectivity and a
minimum degree of 2.

**4. A naive Shikaku partition is not a puzzle.** Splitting at a uniformly
random cut shaves off width-1 slivers, and the board fills with 1x1 clues that
are forced on sight -- 26 rectangles on a 48-cell board. Constraining cuts so
both sides stay above a minimum area brought that to 10 real clues.

**5. Pure noise almost never line-solves.** Nonogram bitmaps need one smoothing
pass to clump into shapes before the line-solver can finish them. Random noise
at 50% density fails the fairness check nearly every time.

**6. Nothing was locking input after a win.** All ten now refuse input once
solved, which also stops a solved board being edited back out of its win.

## Open work

- **Code Break has no difficulty calibration.** The win test cracks it in one
  guess because it knows the answer. Proving the code is findable within the
  guess budget from a realistic opener is not done.
- **Nonogram needs an art pipeline.** Generated blobs are fair but they do not
  look like anything. Recognisable images are a content task.
- **Pipes has a low skill ceiling**, as predicted -- local greedy tapping always
  converges. Good opener, cannot anchor a set.
- **No difficulty curve is tuned.** Each puzzle has three difficulty steps,
  picked by eye, never measured against real solve times.
