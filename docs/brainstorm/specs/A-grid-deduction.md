# Family A — Grid Deduction (1-24)

Pencil-and-paper logic. All language-free. The player deduces; nothing is timed or dexterous.

Template: **Rules** (as told to the player) / **Params** (difficulty knobs) /
**Generator** / **Uniqueness** (how we prove one solution) / **Touch** /
**Round** (target solve time) / **Share** (share-string glyph) / **Risk**.

---

## 1. Nonogram (Picross)

**Rules.** Numbers beside each row and column give the lengths of consecutive filled runs, in order, separated by at least one blank. Fill the grid to reveal a picture.
**Params.** Grid 5x5 to 15x15. Density of filled cells (40-60% reads best). Whether runs-per-line is capped at 2, 3, or unlimited.
**Generator.** Author or generate a target bitmap, derive row/column clues directly from it. No clue removal step — the clues *are* the image.
**Uniqueness.** Run a line-solver to fixpoint: repeatedly compute, for each line, the intersection of all clue-satisfying placements. If it completes the grid, the puzzle is uniquely solvable *by line logic alone* — which is also the definition of "fair." If it stalls, discard the bitmap or perturb it. This is the cheapest uniqueness check of any puzzle in the catalog.
**Touch.** Tap to fill, long-press or a mode toggle to mark X. Drag-paint along a row is essential — without it the puzzle feels like work.
**Round.** 5x5 in 30s; 10x10 in 3-5 min; 15x15 exceeds the budget.
**Share.** The solved grid is already a pixel grid. Render it directly as blocks. Best share artifact in the catalog.
**Risk.** Needs an art pipeline — a supply of recognisable small bitmaps. That's a content treadmill, though a cheap one (they can be generated from an icon font or authored in bulk).

## 2. Sudoku, mini 6x6

**Rules.** Fill the grid so each row, column, and 2x3 box contains 1-6 exactly once.
**Params.** Grid 4x4 / 6x6 / 9x9. Number of givens. Which solving techniques are required (naked single, hidden single, pointing pair...).
**Generator.** Generate a completed Latin-square-with-boxes by randomised backtracking. Remove givens one at a time, each time re-running the solver to confirm the solution is still unique. Stop when removal would break uniqueness.
**Uniqueness.** Exact-cover solver (Knuth's DLX) counting solutions, stopping at 2. Sub-millisecond at 6x6.
**Touch.** Tap a cell, tap a number on a pad. Pencil-mark mode is table stakes for 9x9, optional at 6x6.
**Round.** 6x6 in 60-90s. 9x9 is 8-20 min — out of budget.
**Share.** Grid of digits; too detailed to share spoiler-free. Share time/mistakes instead.
**Risk.** Zero novelty. Every phone already has fifty Sudoku apps. Only justifiable as a familiar on-ramp round.

## 3. Killer / Jigsaw Sudoku

**Rules.** Killer: dotted cages each show a sum; digits inside a cage don't repeat. Jigsaw: boxes are irregular shapes instead of rectangles. Standard Sudoku rules otherwise.
**Params.** Cage size distribution. Whether *any* givens are shown (a pure Killer has none).
**Generator.** Complete grid first, then partition into cages (random growth, cap size at 4-5), compute sums, drop the givens entirely. Verify uniqueness; re-partition on failure.
**Uniqueness.** Same DLX solver plus cage-sum constraints. Slower than plain Sudoku but still fast at 6x6.
**Touch.** Same as Sudoku. Cage borders need careful rendering at phone size — dotted insets, not just colour.
**Round.** 6x6 Killer in 2-3 min.
**Share.** Same limitation as Sudoku.
**Risk.** Onboarding cost is real — two rules to teach instead of one. The payoff is that it feels substantially fresher than plain Sudoku.

## 4. Kakuro

**Rules.** Fill white cells with 1-9. Each horizontal or vertical run sums to the clue at its head, and no digit repeats within a run.
**Params.** Board size, run-length distribution, whether the classic "no zero" rule holds.
**Generator.** Lay out a crossword-like skeleton of runs, fill with digits satisfying the no-repeat rule via backtracking, then emit sums. Re-layout if not unique.
**Uniqueness.** Constraint solver counting to 2. Sum-run combinations are a small precomputable table (all subsets of 1-9 by length and total), which makes propagation fast.
**Touch.** Tap + number pad. The clue triangles are small; needs a zoom or a focused-cell inspector.
**Round.** A small board in 3-5 min.
**Share.** Poor — dense digits.
**Risk.** Visually dense and intimidating on a 6-inch screen. Highest "looks like homework" factor in Family A.

## 5. Hitori

**Rules.** Shade cells so that no number appears twice unshaded in any row or column, no two shaded cells are orthogonally adjacent, and all unshaded cells form one connected group.
**Params.** Grid size 5x5 to 9x9. Duplicate density.
**Generator.** Start from a grid where you decide the shading pattern first (respecting non-adjacency and connectivity), fill unshaded cells with a Latin-ish assignment, then fill shaded cells with values that duplicate a same-row or same-column unshaded value.
**Uniqueness.** Backtracking over shade/unshade with the three constraints, counting to 2. Connectivity check via union-find on each candidate.
**Touch.** Tap to cycle unshaded -> shaded -> marked-safe.
**Round.** 6x6 in 2 min.
**Share.** Shading pattern is a clean two-colour grid. Shares well.
**Risk.** The connectivity rule is the hard one to teach and the one players violate constantly. Needs live feedback highlighting a disconnected region.

## 6. Slitherlink

**Rules.** Draw a single closed loop along the grid lines. A number says exactly how many of its four surrounding edges are part of the loop.
**Params.** Grid size. Clue density. Whether 0-clues appear (they make it much easier).
**Generator.** Hard. Generate a random simple loop (e.g. by growing a region and taking its boundary), derive all clues, then remove clues while a solver confirms uniqueness. Loop generation that yields *interesting* puzzles is the research-y part.
**Uniqueness.** Solver must handle the global single-loop constraint — local edge propagation plus a connectivity/parity check. Meaningfully harder to write than any Sudoku-family solver.
**Touch.** Tapping *edges* between cells, not cells. On a phone this is the core problem: edge hit-targets are thin. Mitigation is tapping near a cell corner and inferring intent, which is fiddly to tune.
**Round.** 5x5 in 2-4 min.
**Share.** The loop is a lovely shape but needs vector rendering, not glyphs.
**Risk.** Two compounding risks — hardest generator in the family, worst touch ergonomics in the family. Beautiful puzzle, wrong platform.

## 7. Masyu

**Rules.** Draw one closed loop through every pearl. At a white pearl the loop goes straight, and must turn in at least one of the two neighbouring cells. At a black pearl the loop turns, and must go straight in both neighbouring cells.
**Params.** Grid size, pearl count, black/white ratio.
**Generator.** Generate a loop, then place pearls at cells whose local geometry satisfies white or black conditions, then remove pearls while uniqueness holds.
**Uniqueness.** Same class of solver as Slitherlink — loop propagation plus connectivity. Shared solver infrastructure if you build both.
**Touch.** Drag a path through cell centres. Notably better than Slitherlink because the loop runs cell-to-cell, so hit targets are full cells.
**Round.** 6x6 in 3-4 min.
**Share.** Loop shape; same rendering caveat as Slitherlink.
**Risk.** The two pearl rules are genuinely hard to state in one line. High onboarding cost, but the solving experience is among the best in the catalog.

## 8. Nurikabe

**Rules.** Each number is an island of exactly that many cells. Islands never touch each other orthogonally. All remaining cells form one connected sea, and the sea contains no 2x2 block.
**Params.** Grid size, island count, island size distribution.
**Generator.** Place islands first (random growth with the non-touching rule), verify the complement is connected and 2x2-free, then emit one number per island.
**Uniqueness.** Expensive. Requires search over island shapes with connectivity and 2x2 constraints. Counting to 2 is slow enough that you'd precompute puzzles offline rather than generate on-device.
**Touch.** Tap to cycle sea / island / unknown.
**Round.** 7x7 in 4-6 min.
**Share.** Two-colour grid, shares well.
**Risk.** Four rules. Slow generator. Best treated as an offline-baked puzzle pack rather than an on-device generator.

## 9. Shikaku

**Rules.** Divide the grid into rectangles so that every rectangle contains exactly one number, and that number equals the rectangle's area.
**Params.** Grid size 5x5 to 10x10. Rectangle count and aspect distribution.
**Generator.** The easy direction: recursively partition the grid into rectangles, then drop one number into each at a random position. Every generated instance is valid by construction.
**Uniqueness.** Exact-cover: each number's candidate rectangles are enumerable and small; DLX over "cover every cell exactly once" counting to 2. Fast.
**Touch.** Drag from one corner to the opposite corner. This is an excellent phone gesture — big targets, direct manipulation, immediate visual confirmation.
**Round.** 7x7 in 90s-2 min.
**Share.** The partition is a coloured block grid. Shares well.
**Risk.** Very few. This is one of the strongest all-round candidates: trivial generator, cheap uniqueness, native gesture, clean share. Main risk is that it's less famous, so it needs a good 10-second tutorial.

## 10. Hashiwokakero (Bridges)

**Rules.** Connect the numbered islands with horizontal or vertical bridges. Each island has exactly as many bridge-ends as its number. At most two bridges join any pair, bridges never cross, and all islands end up connected.
**Params.** Island count, board size, maximum island number, how much crossing-avoidance is required.
**Generator.** Build the solution first: place islands, connect them into a connected planar network of horizontal/vertical bridges with 1-2 multiplicity and no crossings, then emit each island's degree.
**Uniqueness.** Backtracking on bridge counts per pair with degree and crossing constraints, plus a final connectivity check, counting to 2. Cheap — instance sizes are small.
**Touch.** Drag from island to island, or tap a gap to cycle 0 -> 1 -> 2 bridges. Islands are large circular targets, ideal for thumbs.
**Round.** 8-12 islands in 2 min.
**Share.** Network diagram; doesn't reduce to glyphs cleanly.
**Risk.** Low. Chunky, readable, forgiving of small screens. The connectivity rule occasionally surprises players who satisfy every number but leave two separate clusters.

## 11. Light Up (Akari)

**Rules.** Place bulbs in white cells. A bulb lights its whole row and column until a black wall blocks it. No bulb may light another bulb. A numbered wall touches exactly that many bulbs orthogonally. Every white cell must end up lit.
**Params.** Grid size, wall density, fraction of walls that carry numbers.
**Generator.** Place walls, place a legal set of bulbs (no mutual illumination, everything lit), then number some walls by counting adjacent bulbs. Remove numbers while uniqueness holds.
**Uniqueness.** Backtracking over bulb placements with propagation from numbered walls, counting to 2. Fast for small boards.
**Touch.** Tap to place or remove a bulb; long-press to mark "definitely empty." Cell-sized targets.
**Round.** 7x7 in 90s.
**Share.** Bulb positions on a wall grid; shares acceptably as a two-glyph grid.
**Risk.** Low. Immediate visual feedback — light spreading across the board as you tap — makes it feel good before the player fully understands it. Strong candidate for an early round.

## 12. Minesweeper, no-guess variant

**Rules.** Numbers show how many mines touch that cell, including diagonals. Flag every mine. Guaranteed solvable by logic alone — you never have to guess.
**Params.** Grid size, mine density, whether the first tap is free.
**Generator.** Place mines, then *simulate* a logical solver from an opening. If the solver ever stalls with cells remaining, re-roll the mine layout or relocate the offending mines. This regenerate-until-solvable loop is the whole trick.
**Uniqueness.** The solvability simulation *is* the uniqueness check: if pure constraint propagation (single-cell counts plus subset rules) completes the board, no guessing is required.
**Touch.** Tap to reveal, long-press to flag. A classic phone mis-tap hazard — needs an explicit flag-mode toggle, not just long-press.
**Round.** 8x8 in 2 min.
**Share.** Final board is a number grid; shares poorly. Share time instead.
**Risk.** Everyone thinks they know Minesweeper and therefore skips the tutorial, missing that this variant never requires guessing — which is the entire selling point. Needs to be stated loudly.

## 13. Star Battle

**Rules.** Place stars so that every row, every column, and every outlined region contains exactly N stars. No two stars touch, not even diagonally.
**Params.** Grid size, N (1 or 2), region shapes.
**Generator.** Choose a legal star placement first (satisfying row/col counts and non-adjacency), then grow regions around the grid such that each region contains exactly N stars. Region growth is the fiddly part.
**Uniqueness.** Backtracking over star placements with row/col/region counters and an adjacency mask, counting to 2. Fast at small N.
**Touch.** Tap to cycle empty -> star -> marked-empty. Marking eliminated cells matters here more than in most puzzles.
**Round.** 6x6 with N=1 in 90s; 8x8 with N=2 in 4 min.
**Share.** Star positions on a region-coloured grid. Shares nicely.
**Risk.** Low, and it's fashionable right now. Region rendering must be crisp at phone size — thick borders, subtle fills.

## 14. Binairo / Takuzu

**Rules.** Fill every cell with one of two symbols. Never three of the same in a row or column. Each row and column holds equal numbers of both. No two rows are identical, and no two columns are identical.
**Params.** Grid size (even only): 6x6, 8x8, 10x10. Number of givens.
**Generator.** Generate a full valid grid by backtracking with the three rules, then remove givens while uniqueness holds. The classic build-then-strip shape.
**Uniqueness.** Constraint propagation (the three rules are all local or line-level) plus backtracking, counting to 2. Among the fastest solvers in the catalog.
**Touch.** Tap to cycle A -> B -> blank. Nothing else needed.
**Round.** 6x6 in 45-60s; 8x8 in 2 min.
**Share.** Two symbols on a grid — an ideal share string, structurally identical to Wordle's.
**Risk.** Low. The "no identical rows" rule is rarely needed to solve and rarely noticed; consider dropping it at small sizes to cut the tutorial in half. Strongest cheap-to-build candidate in Family A.

## 15. Futoshiki

**Rules.** Fill the grid so each row and column contains 1-N exactly once. The greater-than signs between cells must hold.
**Params.** Grid size 4x4 to 7x7. Number of inequality signs. Number of given digits.
**Generator.** Generate a Latin square, emit inequality signs between some adjacent pairs, add a few givens, then remove both signs and givens while uniqueness holds.
**Uniqueness.** Latin-square backtracking with inequality propagation, counting to 2. Trivially fast.
**Touch.** Tap cell, tap number pad. Signs are static decoration — no interaction needed.
**Round.** 5x5 in 60-90s.
**Share.** Digit grid; shares poorly.
**Risk.** Low build risk. The inequality chevrons need to be large and unambiguous at phone size — easy to misread direction, which produces "the puzzle is broken" reports.

## 16. Skyscrapers

**Rules.** Each cell holds a building of height 1-N; heights don't repeat in a row or column. A number outside the grid says how many buildings you can see from there — a taller building hides every shorter one behind it.
**Params.** Grid size 4x4 to 6x6. How many of the 4N border clues are shown.
**Generator.** Generate a Latin square, compute all four border clue sets by visibility scan, then remove clues while uniqueness holds.
**Uniqueness.** Latin-square backtracking with visibility constraints, counting to 2. Fast.
**Touch.** Tap cell, tap height pad.
**Round.** 4x4 in 45s; 5x5 in 2 min.
**Share.** Digit grid; poor. But the *solved state* can be rendered as a skyline, which is a strong visual moment.
**Risk.** The visibility rule takes a diagram to teach, not a sentence — but once seen, it's obvious forever. A one-time animated tutorial covers it. Good candidate.

## 17. Yin-Yang

**Rules.** Colour every cell black or white. All black cells connect into one group, all white cells connect into one group, and no 2x2 block is a single colour.
**Params.** Grid size, number of pre-coloured givens.
**Generator.** Generate a valid two-colouring (grow one region, check the complement's connectivity and the 2x2 rule), then reveal a subset of cells as givens and strip while unique.
**Uniqueness.** Backtracking with union-find connectivity and a 2x2 scan, counting to 2. Moderate cost — connectivity is rechecked often.
**Touch.** Tap to cycle black -> white -> blank.
**Round.** 6x6 in 2 min.
**Share.** Pure two-colour grid. Excellent share artifact.
**Risk.** Deceptively hard to get difficulty right — small boards are trivial, medium boards spike. Needs careful calibration.

## 18. Kuromasu

**Rules.** Shade some cells black. A numbered cell says how many white cells it can see in the four directions, counting itself, stopping at black cells. No two black cells touch orthogonally, and all white cells stay connected.
**Params.** Grid size, clue count.
**Generator.** Choose a black-cell pattern satisfying non-adjacency and white connectivity, then compute visibility counts for candidate clue cells, then strip.
**Uniqueness.** Expensive — visibility is a long-range constraint, so propagation is weak and search is wide. Bake offline.
**Touch.** Tap to cycle.
**Round.** 6x6 in 3-5 min.
**Share.** Two-colour grid; good.
**Risk.** Niche, slow generator, long-range reasoning that frustrates newcomers. Include only if you want a hard weekend round.

## 19. Lights Out

**Rules.** Tapping a light toggles it and its four orthogonal neighbours. Turn every light off.
**Params.** Grid size, toggle shape (plus, X, knight), number of moves in the intended solution.
**Generator.** Start from all-off, apply K random taps. The resulting board is solvable in at most K moves by construction — press the same cells again. Choose K for difficulty.
**Uniqueness.** Different in kind from every other entry: this is a linear system over GF(2). Solvability and the full solution space are computable by Gaussian elimination in microseconds. Note the *solution set* is not always unique (the toggle matrix can be singular), but the minimal move count is well-defined and that's what you score.
**Touch.** Single tap. Simplest input model in the catalog.
**Round.** 5x5 in 45-90s.
**Share.** Move count plus a small grid. Shares well.
**Risk.** Players brute-force it by flailing rather than reasoning, which makes the puzzle feel random. Mitigate by scoring against the minimal move count rather than mere completion.

## 20. Mastermind / code break

**Rules.** Guess the hidden sequence of coloured pegs. After each guess you learn how many are the right colour in the right place, and how many are the right colour in the wrong place.
**Params.** Sequence length (4-5), palette size (6-8), repeats allowed or not, guess budget.
**Generator.** Pick a random code. That's it — the cheapest generator in the catalog.
**Uniqueness.** Not applicable in the usual sense. What matters is *difficulty calibration*: simulate an optimal or greedy solver against the code to confirm it's crackable within the guess budget, and reject codes that are trivially easy.
**Touch.** Tap to cycle each slot's colour, tap Submit. Identical interaction skeleton to Wordle, minus the keyboard.
**Round.** 60-90s.
**Share.** The feedback history is a grid of black/white pegs — structurally *exactly* Wordle's share string, with zero language content. This is the single most under-exploited property in the catalog.
**Risk.** Colour-only encoding is an accessibility failure; pegs must carry shapes or numerals too. Also, it's a guessing game rather than a pure deduction game, so a lucky player can win without reasoning.

## 21. Tents & Trees

**Rules.** Pitch one tent next to each tree, orthogonally adjacent. No two tents touch, not even diagonally. The numbers beside each row and column count the tents there.
**Params.** Grid size, tree count, tree clustering.
**Generator.** Place tent-tree pairs directly: pick a cell for a tent, pick an orthogonal neighbour for its tree, respecting non-adjacency of tents. Then emit row and column counts. Valid by construction.
**Uniqueness.** Bipartite matching between trees and candidate tent cells, plus row/column counts; count solutions to 2. Cheap.
**Touch.** Tap to cycle grass -> tent -> blank.
**Round.** 8x8 in 90s-2 min.
**Share.** Sparse two-glyph grid; shares fine.
**Risk.** Very low. Warm, illustratable theme (a real asset for store screenshots), trivial generator, obvious rules. One of the best beginner-round candidates.

## 22. Aquarium

**Rules.** The grid is divided into aquariums. Water finds its level, so within one aquarium every cell at or below the water line is filled, across the whole aquarium's width. Numbers beside rows and columns count filled cells.
**Params.** Grid size, aquarium count and shape irregularity.
**Generator.** Partition the grid into connected regions, pick a water level per region, derive row/column counts. Valid by construction.
**Uniqueness.** The search space is tiny — one integer (water level) per aquarium. Enumerate all combinations directly for small boards and count matches to 2. Among the cheapest uniqueness checks here.
**Touch.** Tap a cell to fill or empty its aquarium up to that row.
**Round.** 6x6 in 90s.
**Share.** Filled-cell grid; good.
**Risk.** Underexposed, which cuts both ways — it feels fresh, but no player arrives knowing it. The physical intuition ("water finds its level") does most of the teaching, which is a big advantage.

## 23. Dominosa

**Rules.** The grid holds every domino from 0-0 up to N-N exactly once, with the dividing lines erased. Restore the lines.
**Params.** N (usually 5-7), which fixes the grid size exactly.
**Generator.** Lay out the full domino set in a random legal tiling, then print the numbers and discard the borders.
**Uniqueness.** Exact-cover over "each domino used once, each cell covered once" via DLX, counting to 2. Fast, and the instance size is fixed.
**Touch.** Tap the boundary between two cells to place or remove a divider; or drag across two cells to pair them.
**Round.** N=5 (7x8 grid) in 3-4 min.
**Share.** The tiling is a nice block pattern but needs rendering, not glyphs.
**Risk.** Fixed size means difficulty can only be tuned by re-rolling layouts, not by scaling — a real constraint for a difficulty ramp. Also requires the player to understand what a domino set *is*.

## 24. Norinori / LITS / Heyawake

**Rules.** Norinori: shade exactly two cells in each region, and every shaded cell touches exactly one other shaded cell. LITS: shade a tetromino in each region so shaded cells connect globally, no 2x2 is fully shaded, and same-shaped tetrominoes never touch. Heyawake: shade cells so no two touch, unshaded cells stay connected, numbered regions hold exactly that many shaded cells, and no unshaded straight line crosses more than one region border.
**Params.** Grid size, region partition.
**Generator.** All three need region partitioning plus a valid shading, then verification. LITS and Heyawake have expensive global constraints.
**Uniqueness.** Hard for all three. Bake offline if used at all.
**Touch.** Tap to cycle.
**Round.** 4-8 min. Over budget.
**Share.** Two-colour grids; fine.
**Risk.** These are connoisseur puzzles. Wrong for onboarding, wrong for a 1-2 minute round, and the generators are the most expensive in the family. Listed for completeness; recommend against for v1.
