# Family G — Adversarial & Combinatorial (70-75)

"Find the winning move" rather than "fill in the grid." Language-free. These share one
big structural advantage: for solved or small games, difficulty is *exactly* computable
by search, so you can guarantee a puzzle is solvable in precisely N moves. They share one
big disadvantage: they require the player to understand a game's rules before the puzzle
even starts, which is a steep onboarding cost for a 90-second round.

---

## 70. Nim variant

**Rules.** Take any number of objects from one row. Whoever takes the last one wins. You move first — beat the machine.
**Params.** Row count and sizes, misere or normal play, per-move take limits.
**Generator.** Nim is *completely solved* — the winning strategy is to leave a position whose rows XOR to zero. So you can generate positions that are exactly winnable, and the machine can play perfectly.
**Uniqueness.** The set of winning moves is exactly computable. Often there's precisely one, which makes it a real puzzle rather than a game.
**Touch.** Tap objects to remove, confirm.
**Round.** 30-90s.
**Share.** Won or lost, plus move count.
**Risk.** Once a player learns the XOR trick the puzzle is permanently over — and unlike Sudoku technique, it's a single fact, not a skill, and it's one web search away. That's a hard ceiling on a *daily*. Variants (limits per move, misere) buy a little time but the same reasoning generalises.

## 71. Tower of Hanoi micro

**Rules.** Move the stack to the other peg. Never put a bigger disc on a smaller one.
**Params.** Disc count (3-5), peg count, non-standard starting configurations.
**Generator.** Any legal configuration works; optimal move count is computable exactly.
**Uniqueness.** With three pegs and a standard start the optimal solution is unique and famously 2^n - 1 moves. Non-standard starts are more interesting.
**Touch.** Drag a disc, or tap source then destination.
**Round.** 3 discs in 30s; 5 discs in 2 min of pure mechanical execution.
**Share.** Move count versus optimum.
**Risk.** Everyone has met this, the algorithm is trivially memorable, and executing it is repetitive rather than thoughtful. Recommend against — it's recognition, not puzzling.

## 72. Peg solitaire micro

**Rules.** Jump one peg over another to remove it. Finish with one peg left.
**Params.** Board shape and size, starting peg layout, target end position.
**Generator.** Backward generation from the solved state: start with one peg and un-jump repeatedly. Guarantees solvability, and the depth sets difficulty.
**Uniqueness.** Solvability guaranteed by construction; minimum move count is fixed (each jump removes exactly one peg, so the move count is determined by the peg count). "Difficulty" is therefore about how many *dead ends* the position offers — measurable by counting losing branches in the search tree, which is a nicer difficulty metric than it first appears.
**Touch.** Drag a peg over its neighbour, or tap peg then destination.
**Round.** 6-10 pegs in 60-90s.
**Share.** Solved plus time.
**Risk.** Like Sokoban, you can brick the position irreversibly, so undo and restart are mandatory. Small boards are pleasant; the classic 33-peg board is far over budget. Underexposed enough to feel fresh.

## 73. Find the winning move (Hex, Tak, or similar)

**Rules.** It's your turn. One move wins. Find it.
**Params.** Which game, board size, search depth of the win (mate-in-1, mate-in-3).
**Generator.** Generate positions by random legal play, then search for positions with exactly one winning move at the target depth. Small Hex boards (5x5, 6x6) are searchable exhaustively.
**Uniqueness.** Exact — the search tells you precisely how many winning moves exist. Keep only single-solution positions.
**Touch.** Tap a cell.
**Round.** 30-90s.
**Share.** Found it or not, plus time. Very clean.
**Risk.** The onboarding problem is acute: the player must learn a whole abstract game before the first puzzle makes sense, and Hex and Tak are unknown to almost everyone. Hex has the redeeming property that its rules fit in one sentence ("connect your two sides"). Randomly generated positions also tend to look strategically incoherent to anyone who knows the game.

## 74. Mate-in-two with custom pieces

**Rules.** These pieces move like this. Force a win in two moves.
**Params.** Board size, piece set, required depth.
**Generator.** Define custom pieces (which sidesteps the barrier of assuming chess knowledge), generate positions, and search exhaustively for forced wins at the target depth on a small board.
**Uniqueness.** Exact by search. Forced-win positions with a unique first move are the good ones.
**Touch.** Drag a piece; legal destinations highlight on pickup.
**Round.** 60-120s.
**Share.** Solved plus time.
**Risk.** Custom pieces dodge the chess-knowledge barrier but replace it with a *new* rules-learning cost every session unless the piece set stays fixed. A fixed set becomes learnable and then genuinely good. Search must be exhaustive and correct — a published puzzle with an unintended second solution, or no solution, is the worst possible bug in a daily game. Highest correctness stakes in the catalog.

## 75. Deduction from partial information (Clue-like)

**Rules.** Work out the answer from the clues. Only one possibility fits them all.
**Params.** Category count and size (the classic "5 houses, 5 attributes" shape), clue count and type (positional, relational, negative).
**Generator.** Choose a secret solution, generate true statements about it, then remove statements while a solver confirms the solution stays unique. Exactly the build-then-strip shape that makes the cheap generators cheap.
**Uniqueness.** Constraint-propagation solver counting to 2. Fast for small instances. Fully exact.
**Touch.** A grid of maybe/yes/no cells that you tap to cycle — the classic logic-grid interface, which works well on a phone at small sizes.
**Round.** 2-4 min for a small instance.
**Share.** Solved plus time and mistakes.
**Risk.** **Clue text is language-locked** unless you render the clues as pictograms ("the star is left of the circle" as icons and an arrow). The pictogram version is genuinely language-free and worth prototyping, but it constrains which clue types you can express — negative and conditional clues are hard to draw. The logic-grid UI is also dense on a phone and intimidating to newcomers, though it's the single most *satisfying* solve in the catalog when it lands.
