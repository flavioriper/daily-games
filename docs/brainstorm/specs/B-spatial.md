# Family B — Spatial Manipulation (25-42)

Direct manipulation of objects. All language-free. Difficulty comes from search depth
or geometric reasoning rather than logical deduction.

---

## 25. Sliding tile (15-puzzle)

**Rules.** Slide tiles into the empty space to restore order, or to rebuild a picture.
**Params.** Grid 3x3 or 4x4. Scramble depth. Whether the goal is numeric order or an image.
**Generator.** Scramble from the solved state with K random legal moves. Solvability is automatic because every position reachable by legal moves is legal — no parity computation needed if you scramble rather than shuffle.
**Uniqueness.** Not applicable; the goal state is unique but the path is not. Difficulty is the minimal move count, computable by IDA* with a Manhattan-distance heuristic.
**Touch.** Drag or tap a tile adjacent to the gap. Row-slides (push several tiles at once) feel much better than single-tile moves.
**Round.** 3x3 in 60s; 4x4 in 3-6 min and frustrating.
**Share.** Move count versus optimal. The board itself shares poorly.
**Risk.** Feels dated, and the endgame is mechanical rather than clever — the last row is a memorised technique. Weak as a standalone round; acceptable as a picture-reveal finale.

## 26. Pipe rotation (Net / Infinity Loop)

**Rules.** Rotate each piece until every pipe connects, with no loose ends.
**Params.** Grid size, whether the board wraps at the edges, whether a power source must reach everything, presence of loops versus pure tree.
**Generator.** Build a random spanning tree over the grid graph, convert each cell's edge set into a pipe piece (end, straight, elbow, T, cross), then rotate every piece randomly.
**Uniqueness.** Free, by construction — the connected configuration is the one you built. (Caveat: symmetric pieces like straights and crosses have rotational symmetry, so the *rotation state* isn't unique, but the *connection pattern* is, which is what's checked.)
**Touch.** Tap to rotate 90 degrees. One gesture, no modes, no undo needed. The single most frictionless input in the catalog.
**Round.** 5x5 in 45s; 8x8 in 2-3 min.
**Share.** Move count and time. The board is pretty but doesn't glyph well.
**Risk.** Low skill ceiling — it's closer to a satisfying chore than a puzzle, since local greedy work always converges. Excellent as a palate-cleanser round, weak as the centrepiece. Wrapping edges add genuine difficulty.

## 27. Untangle (planar graph)

**Rules.** Drag the dots until no two lines cross.
**Params.** Node count (6-15), edge density, starting scramble severity.
**Generator.** Generate a random planar graph — e.g. Delaunay-triangulate random points, optionally delete edges — then scatter the nodes to random positions.
**Uniqueness.** Guaranteed solvable by construction (the original embedding is crossing-free). The solution is not unique — any planar embedding works — which is fine and arguably better: players find their own answer.
**Touch.** Pure drag. No modes, no buttons, no text. The most universally understandable puzzle here — a five-year-old gets it without instruction.
**Round.** 8 nodes in 30s; 14 nodes in 2-3 min.
**Share.** Time and node count. The final layout is personal to each player, which is a charming share but needs an image, not a string.
**Risk.** On a small screen, nodes get cramped and fingers occlude the very crossing you're fixing. Needs generous node spacing, a slight drag offset so the node sits above the fingertip, and pinch-zoom.

## 28. Polyomino packing

**Rules.** Fit all the pieces into the shape. No overlaps, no gaps.
**Params.** Board shape and area, piece count and sizes, whether rotation and reflection are allowed.
**Generator.** The easy direction: tile the target region with polyominoes by randomised growth, then lift the pieces out and shuffle them into a tray.
**Uniqueness.** Exact-cover (DLX) over piece placements, counting to 2. This is DLX's textbook application and it's fast. Non-unique instances are common and mostly acceptable.
**Touch.** Drag from tray to board, tap or two-finger twist to rotate, snap to grid. Needs a well-tuned snap radius and a clear "invalid placement" state.
**Round.** 5 pieces in 90s; 8 pieces in 4 min.
**Share.** The finished packing is a coloured block grid. Shares very well.
**Risk.** The most UI-intensive entry so far — tray, drag, rotate, snap, undo, and a piece-occluded-by-thumb problem. Budget real time for feel. The reward is a highly tactile, very "mobile game" experience.

## 29. Tangram silhouette

**Rules.** Arrange the seven pieces to exactly fill the silhouette.
**Params.** Which silhouette. Whether piece outlines are hinted inside the shape.
**Generator.** Essentially authored — good tangram silhouettes are recognisable figures, which is an art task, not an algorithm. You can generate random valid arrangements, but they look like abstract blobs.
**Uniqueness.** Many silhouettes have multiple valid arrangements. Verification is geometric rather than combinatorial, involving floating-point tolerance — noticeably more annoying than grid-based exact cover.
**Touch.** Drag plus free rotation, with snapping at 45-degree increments. Triangles at 45 degrees are fiddly under a thumb.
**Round.** 2-4 min, with high variance — players either see it or don't.
**Share.** The silhouette is a strong image, but binary solved/unsolved shares poorly.
**Risk.** Content is authored (treadmill), geometry is floating-point (fussy), and the difficulty is bimodal (insight-based). Recommend against unless tangram is the theme of the whole product.

## 30. Rush Hour / sliding block escape

**Rules.** Slide the blocking cars out of the way so the target car can reach the exit. Cars move only along their own axis.
**Params.** Board 6x6, car count, minimum optimal move count.
**Generator.** Two options. Forward: place cars randomly, BFS the state space, keep the layout if the optimal solution length falls in the target band. Backward: start solved and BFS outward, taking a position at the desired depth. Backward search gives tighter difficulty control.
**Uniqueness.** The *minimum move count* is the well-defined quantity, computed exactly by BFS. The move sequence itself needn't be unique.
**Touch.** Drag a car along its axis. Excellent phone gesture — constrained, forgiving, physical.
**Round.** 8-move optimum in 60-90s; 20-move optimum in 4 min and up.
**Share.** Your move count versus the optimum. Clean, comparable, spoiler-free.
**Risk.** BFS over the state space is fast enough at 6x6 to run on device, but memory needs watching. The commercial game is trademarked — the mechanic isn't, but the name, the red car, and the exact puzzle set are. Use original art and generated layouts.

## 31. Sokoban micro

**Rules.** Push the crates onto the targets. You can only push, never pull, and only one crate at a time.
**Params.** Board size (very small: 5x5 to 7x7), crate count (2-3), optimal push count.
**Generator.** Backward generation: start from the solved state and BFS by *pulling* crates, then take a state at the desired depth. Forward random generation almost always produces unsolvable or trivial boards.
**Uniqueness.** Optimal push count via BFS. Deadlock detection (a crate in a corner) is needed both for the generator and for a good hint system.
**Touch.** Swipe to move in a direction, or tap a destination cell with auto-pathing. Undo is *mandatory* — Sokoban is trivially bricked by one wrong push, and a daily puzzle with no undo would be an instant one-star review.
**Round.** 6-10 pushes in 90s-2 min.
**Share.** Push count versus optimum.
**Risk.** The irreversibility problem is the whole risk, and undo plus restart solves it. Also genuinely hard for casual players — deadlocks are invisible until you've already lost.

## 32. Concentric dial alignment

**Rules.** Rotate the rings until the pattern lines up.
**Params.** Ring count (3-5), segments per ring, what "lined up" means (colour match across a radius, symbol continuity, a path completing).
**Generator.** Start from the aligned state, rotate each ring by a random offset. Trivial.
**Uniqueness.** Unique if the aligned pattern has no rotational symmetry — check by comparing the pattern against its own rotations and re-rolling if a match appears.
**Touch.** Circular drag on a ring. Natural, physical, and visually gorgeous in motion. Godot's transform and shader tooling makes this look expensive for very little work.
**Round.** 30-60s.
**Share.** Move count. The dial image is strong marketing material.
**Risk.** Very low build cost, but also a low skill ceiling — with 4 rings there are only so many combinations, and brute force works. Best as a short opening or closing round, or as a *frame* around a harder puzzle rather than the puzzle itself.

## 33. Fold-the-net

**Rules.** Which of these flat nets folds into the solid shown?
**Params.** Solid type (cube first, then tetrahedron, octahedron, or a marked cube), number of choices, how similar the decoys are.
**Generator.** Enumerate the valid nets of the chosen solid (there are exactly 11 for a cube), apply face markings, and generate decoys by perturbing a valid net just past validity.
**Uniqueness.** Exact — validity is decidable by attempting the fold combinatorially. Decoy quality is the real design work: a decoy that's obviously wrong makes the round free.
**Touch.** Tap to choose. Optionally, drag to rotate the 3D solid for inspection — which is where Godot earns its place, since this is nearly free in a 3D engine and painful in a 2D one.
**Round.** 20-40s. A genuine micro-round.
**Share.** Correct or not, plus time. Shares as a single glyph.
**Risk.** Multiple choice means a 25% guess rate, so it can't carry scoring weight alone. Also strongly correlated with innate spatial ability — some players find it trivial, others impossible, with little middle ground or learning curve.

## 34. Mirror & laser routing

**Rules.** Place or rotate the mirrors so the beam reaches every target.
**Params.** Grid size, mirror count, fixed versus placeable mirrors, splitters, filters, walls.
**Generator.** Trace a beam path first — choose a source, walk a path through the grid, place mirrors at each turn, drop targets along the way — then scramble the mirror orientations or move some to a tray.
**Uniqueness.** Simulate the beam and compare against the target set; count solutions by enumerating mirror orientations, which is 4^n and therefore fine for n up to about 8. Beyond that, prune with search.
**Touch.** Tap to rotate a mirror; drag from a tray for placeable ones. Beam animation gives continuous feedback — every tap shows immediate consequence, which is excellent for learning.
**Round.** 60-90s with 4-6 mirrors.
**Share.** Beam path renders as an image, not a glyph string.
**Risk.** Low. Highly themeable (lasers, prisms, lighthouses, plumbing), which matters for store presence. Colour splitters and filters give a long, natural difficulty ladder — this mechanic has more headroom than most in the family.

## 35. Marble drop / gravity routing

**Rules.** Place the deflectors so every marble lands in the right bucket.
**Params.** Board height and width, marble count and colours, piece types (ramps, splitters, gates, one-way doors).
**Generator.** Place pieces, simulate, keep boards whose outcome matches a target assignment and whose solution isn't trivially reachable. Or run backward from the buckets.
**Uniqueness.** Simulation is deterministic *if the board is grid-based and turn-stepped*. Do not use a real physics engine — floating-point and frame-rate variance would make the same puzzle resolve differently on different phones, which is fatal for a shared daily puzzle.
**Touch.** Drag pieces onto the board, tap Run to watch it play out.
**Round.** 90s-2 min.
**Share.** Success plus piece count. The run animation is very shareable as a clip.
**Risk.** The determinism trap above is the main one, and it's avoidable by design. Secondary risk: the "place, run, watch, adjust" loop has a slow feedback cycle compared with instant-feedback puzzles.

## 36. Edge-matching tiles

**Rules.** Place every tile so that touching edges match in colour.
**Params.** Grid size, edge colour count, whether tiles may rotate, square versus hexagonal tiles.
**Generator.** Assign random colours to every internal edge of the grid, read off each cell's four (or six) edge colours as a tile, then shuffle and rotate the tiles.
**Uniqueness.** Valid by construction. Uniqueness needs a DLX or backtracking count to 2, and edge-matching notoriously explodes combinatorially — keep boards at or below 4x4, or accept non-unique solutions.
**Touch.** Drag from tray, tap to rotate.
**Round.** 3x3 in 60s; 4x4 in 3 min and up, steeply.
**Share.** The finished mosaic is attractive; shares as an image.
**Risk.** Difficulty scales viciously and unpredictably with size — 4x4 can be minutes or an hour. This is the hardest entry in the catalog to calibrate, and calibration is exactly what a daily puzzle needs most.

## 37. Magnets

**Rules.** Some of the dominoes are magnets with a + end and a - end; the rest are blank. Like poles never touch. The numbers beside each row and column count the + and - symbols there.
**Params.** Board size, magnet-to-blank ratio, how many of the four clue tracks are shown.
**Generator.** Tile the board with dominoes, assign each one magnet-or-blank and an orientation respecting the pole rule, then emit the counts.
**Uniqueness.** Backtracking over per-domino states (blank, +/-, -/+) with adjacency and count constraints, to 2. Cheap — the per-piece branching factor is only 3.
**Touch.** Tap a domino to cycle its three states.
**Round.** 6x6 in 2 min.
**Share.** Sparse symbol grid; good.
**Risk.** Low build risk. Genuinely underexposed, and the physical metaphor teaches the adjacency rule for free. The four separate clue tracks crowd a phone screen — needs a compact layout.

## 38. Flow Free (connect and fill)

**Rules.** Connect each pair of matching dots with a pipe. Pipes never cross, and together they must fill every cell.
**Params.** Grid size (5x5 to 9x9), pair count, whether full coverage is required.
**Generator.** Generate the solution first: partition the grid into non-crossing paths that cover every cell, then keep only each path's endpoints as the dots.
**Uniqueness.** This is the catch. Naive generation frequently admits alternate solutions. Verification needs a solver over disjoint covering paths, and counting to 2 is expensive. Practical answer: bake puzzles offline, verify uniqueness there, ship a validated set.
**Touch.** Drag from dot to dot. Proven at enormous scale on mobile — the gesture is the reason the genre succeeded.
**Round.** 5x5 in 30-45s; 8x8 in 2-3 min.
**Share.** The filled grid is a coloured block grid. Shares very well.
**Risk.** Commercially saturated — there are thousands of these. Cloning it invites comparison with polished free-to-play incumbents. Needs a genuine twist (a rule modifier, an unusual topology) to justify inclusion.

## 39. Ball / water sort

**Rules.** Pour to move the top ball onto a matching colour or an empty tube. Sort every colour into its own tube.
**Params.** Colour count, tube capacity, spare tube count.
**Generator.** Start sorted, then scramble by legal reverse pours. Guarantees solvability.
**Uniqueness.** Not applicable; minimum move count via BFS, which is expensive for larger instances.
**Touch.** Tap source tube, tap destination. Two taps, no dragging, very phone-friendly.
**Round.** 60-90s.
**Share.** Move count.
**Risk.** The honest assessment: this is a sorting chore, not a deduction puzzle. It's addictive in a slot-machine way rather than a satisfying one, players succeed by undo-spamming, and the market is flooded with ad-monetised clones. Wrong fit for a premium daily product.

## 40. Zip / one path through checkpoints

**Rules.** Draw one path that passes through every cell exactly once, visiting the numbered checkpoints in order.
**Params.** Grid size, checkpoint count, walls or blocked cells.
**Generator.** Generate a Hamiltonian path on the grid graph (easy to do constructively — snake patterns perturbed by random 2-opt style rewrites), then number a subset of cells along it in visit order.
**Uniqueness.** Backtracking Hamiltonian-path search with checkpoint-order constraints, counting to 2. Cost grows quickly with board size; keep to 6x6 or smaller, or bake offline. Adding more checkpoints both lowers difficulty and makes uniqueness far cheaper to establish.
**Touch.** Single continuous drag. Outstanding on a phone — one gesture, self-correcting (backtrack by dragging back over your path), no modes.
**Round.** 5x5 in 45-60s; 6x6 in 2 min.
**Share.** The path on a grid; renders as an image well, glyphs less well.
**Risk.** LinkedIn's Zip has made this mechanic prominent very recently, so it reads as current rather than original. Uniqueness cost is the main engineering constraint.

## 41. Hexagon fitting

**Rules.** Place the hex pieces to fill the board, matching whatever the local rule is (colour, number, adjacency).
**Params.** Board radius, piece shapes (single hexes, trominoes), rule variant.
**Generator.** Same as polyomino packing, on a hex lattice: tile then lift.
**Uniqueness.** DLX over hex placements. Same cost profile as polyominoes.
**Touch.** Drag and rotate in 60-degree steps.
**Round.** 90s-3 min.
**Share.** Hex mosaic; attractive image.
**Risk.** Hex coordinate maths (axial or cube coordinates) is a known, solved, but non-trivial cost, and every piece of art has to be authored for hexes. The payoff is purely aesthetic freshness. Only worth it if hexes become the product's visual identity.

## 42. Rope untangle, 3D

**Rules.** Pull the tangled rope apart so no strands cross.
**Params.** Strand count, tangle depth, whether the camera is fixed or free.
**Generator.** Same idea as Untangle but embedded in 3D: build an untangled configuration, then perturb node positions.
**Uniqueness.** Solvable by construction; the solution is not unique.
**Touch.** Drag nodes in 3D. This is the problem — dragging in three dimensions on a two-dimensional touch surface is genuinely unsolved UX. Either constrain drags to a plane (which makes some tangles unreachable) or add a separate camera-orbit gesture (which doubles the input complexity).
**Round.** 2-3 min, highly variable.
**Share.** Time. Needs a video, not a string.
**Risk.** The highest UX risk in the catalog. It's the entry that most showcases Godot's 3D capability, and simultaneously the one most likely to feel bad on a phone. If you want 3D, entry 33 (fold-the-net) gets you the visual payoff with tap-only input.
