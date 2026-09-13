# Family E — Graph & Routing (57-61)

Path-drawing puzzles. Strong on phones because the gesture is a single continuous drag,
and strong for difficulty control because graph properties are computable exactly.

---

## 57. One-line drawing (Eulerian path)

**Rules.** Trace the whole figure without lifting your finger and without going over any line twice.
**Params.** Node and edge count, figure aesthetics, whether a specific start node is forced.
**Generator.** Build a graph and then *make* it Eulerian: a connected graph has an Eulerian path exactly when it has zero or two odd-degree vertices. So generate a random connected graph, count odd-degree vertices, and add or remove edges until the count is 0 or 2. Directly constructive.
**Uniqueness.** Existence is decided instantly by the degree-parity theorem — no search at all, which makes this the cheapest correctness guarantee in the entire catalog. The path itself is usually not unique, which is fine.
**Touch.** One continuous drag. Excellent: self-evident, self-correcting, no modes, no buttons.
**Round.** 30-90s depending on edge count.
**Share.** Solved plus time. The figure itself is a nice image.
**Risk.** Very low build risk. The real design work is *aesthetic* — random Eulerian graphs look like scribbles, so figures should be curated or generated from a template library (envelopes, houses, stars, lattices) to feel intentional. Skill ceiling is moderate; experienced players learn the odd-vertex trick and then it's mechanical. Counter that with edge counts high enough that execution, not insight, is the challenge.

## 58. Graph colouring

**Rules.** Colour the regions so that no two touching regions share a colour. Use at most N colours.
**Params.** Region count, colour budget (3 is hard and interesting; 4 is always possible for planar maps and therefore easy), map irregularity.
**Generator.** Generate a planar subdivision (Voronoi over random points is the standard trick and looks like a map), then verify a colouring exists within the budget.
**Uniqueness.** Colourability is decidable by backtracking, fast at these sizes. The colouring is essentially never unique — any permutation of colours is another solution — so score on completion, not on matching a specific answer.
**Touch.** Tap a region to cycle through colours. Big, forgiving targets.
**Round.** 60-90s.
**Share.** The coloured map is an attractive image.
**Risk.** Colour is load-bearing, so it needs a colour-blind-safe palette *plus* patterns or symbols in each region — non-optional. With 4 colours on a planar map, greedy tapping nearly always succeeds, which makes it feel free; the puzzle only becomes interesting at a 3-colour budget, and verifying 3-colourability is where the real constraint lies.

## 59. Shortest path with a twist

**Rules.** Get from start to finish in the fewest steps. One extra rule applies today.
**Params.** Grid or graph size, the twist (must collect all keys, may not turn twice in a row, doors need matching keys, some tiles cost more, direction reverses in marked zones).
**Generator.** Build the graph, apply the twist as a state augmentation, run Dijkstra or BFS over the augmented state space to get the exact optimum, and keep instances whose optimum sits in the target band.
**Uniqueness.** The optimal cost is exact; multiple optimal paths are common and acceptable. Score against the optimum.
**Touch.** Drag a path, or tap waypoints.
**Round.** 45-90s.
**Share.** Your step count versus the optimum. Clean and spoiler-free.
**Risk.** Low build risk and *very* high content leverage — the twist is a swappable parameter, so one engine yields dozens of distinct-feeling puzzles. That makes it the best candidate in the catalog for the "weekly rule modifier" idea. Risk is that without a twist it's a plain maze, which is boring; the twists carry the whole thing and need authoring.

## 60. Maze with a rule modifier

**Rules.** Find the way out. Today's rule changes how you move.
**Params.** Maze size and generation algorithm, the modifier (one-way doors, teleports, colour-gated corridors, momentum where you slide until you hit a wall).
**Generator.** Standard maze generation (recursive backtracker or Wilson's algorithm for unbiased mazes), then apply the modifier and verify solvability by BFS over the modified rules.
**Uniqueness.** Perfect mazes have exactly one simple path between any two cells by construction. Modifiers can break that, so re-verify after applying them.
**Touch.** Drag to trace, or swipe to move.
**Round.** 30-90s.
**Share.** Time and path length.
**Risk.** A plain maze is not a puzzle — it's a search, and on a small screen it's a search you can often solve at a glance. Everything interesting lives in the modifier, which makes this a near-duplicate of entry 59. If you build one, you've built both; pick whichever framing you prefer and drop the other. The momentum variant (slide until you hit a wall) is the strongest single modifier and is effectively its own well-liked genre.

## 61. Valve / flow network

**Rules.** Open and close the valves so the right amount reaches each outlet.
**Params.** Network size, valve count, whether flow splits evenly or by capacity, outlet targets.
**Generator.** Build a DAG, choose a valve configuration, simulate the flow, and read the outlet amounts as the targets.
**Uniqueness.** Enumerate valve configurations (2^n, fine up to about n=16) and count how many produce the target outputs. Exact for reasonable sizes.
**Touch.** Tap valves to toggle. Flow animates on each change, giving instant visible consequence.
**Round.** 60-90s.
**Share.** Solved plus valve count.
**Risk.** Mechanically this is close to Lights Out (19) — a set of binary toggles with propagating effects — dressed in industrial theming. That's a genuine strength for theme and readability, but check you aren't shipping the same puzzle twice under two skins. The flow-splitting rule needs to be stated exactly or players will infer a different physics than you implemented.
