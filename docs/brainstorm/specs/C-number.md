# Family C — Number & Arithmetic (43-48)

Language-free but *notation*-dependent: they assume Arabic numerals and comfort with
basic arithmetic. That's a smaller barrier than language, but it isn't zero — arithmetic
puzzles reliably alienate a slice of the casual audience.

---

## 43. Reach the target (24 game)

**Rules.** Use each of the given numbers exactly once, with + - x and /, to make the target.
**Params.** Number count (4-6), target magnitude, allowed operations, whether intermediate fractions are permitted, whether parentheses are implicit.
**Generator.** Pick numbers, then brute-force every expression tree over them (for 4 numbers this is a few thousand cases, evaluated in microseconds) and read off the achievable targets. Choose a target reachable by exactly one or two distinct expressions for difficulty, or by many for an easy round.
**Uniqueness.** Complete and exact — the brute force enumerates the entire solution space, so you know precisely how many solutions exist and how hard the easiest one is. Best-characterised difficulty of any entry in the catalog.
**Touch.** Tap a number, tap an operator, tap another number; the two collapse into their result. This "combine two into one" interaction is far better on a phone than typing an expression, and it makes the state always valid.
**Round.** 45-90s.
**Share.** Solved or not, plus time and hint use. Compact.
**Risk.** Divides the audience sharply — people who like mental arithmetic love it, others bounce immediately. Also rewards a systematic search more than insight, so it can feel like grinding.

## 44. KenKen / Calcudoku

**Rules.** Fill each row and column with 1-N, no repeats. Each outlined cage shows a target and an operation; the digits in that cage must combine to make it.
**Params.** Grid size 4x4 to 6x6, cage size distribution, which operations appear, whether subtraction and division are order-free.
**Generator.** Generate a Latin square, partition into small cages, compute each cage's value under a randomly chosen operation, then strip cages or merge them while uniqueness holds.
**Uniqueness.** Latin-square backtracking plus cage-arithmetic propagation, counting to 2. Fast at 4x4 and 5x5.
**Touch.** Tap cell, tap number pad. Cage borders and their little clue labels are the rendering challenge at phone size.
**Round.** 4x4 in 90s; 6x6 in 4-5 min.
**Share.** Digit grid; poor.
**Risk.** Two skills at once — Latin-square logic plus arithmetic — which compounds the audience-narrowing problem. The trademark on "KenKen" is real; "Calcudoku" and "MathDoku" are the generic names.

## 45. Balance scales

**Rules.** The scales balance. Work out what each shape weighs.
**Params.** Shape count (2-4), number of scales shown, whether weights are integers, whether one shape's weight is given.
**Generator.** Assign secret integer weights to the shapes, then emit scale statements (linear equations) until the system has a unique solution. Emit one or two extra for redundancy or omit one for difficulty.
**Uniqueness.** This is a linear system — check the rank of the coefficient matrix over the integers. Exact, instant, and the difficulty is directly controlled by how much slack you leave in the rank. One of the cleanest generators here.
**Touch.** Drag shapes onto a scale to test, or tap to assign a value from a pad. The interactive-scale version is more fun but needs more UI.
**Round.** 45-90s.
**Share.** Solved plus time.
**Risk.** Low. Reads as visual algebra without looking like algebra, which is the trick — it's the most approachable arithmetic puzzle in the family and illustrates beautifully. Good early-round candidate. The risk is a low ceiling: past 4 shapes it stops being intuitive and starts being simultaneous equations.

## 46. Cryptarithm

**Rules.** Each letter stands for a different digit. Work out which, so the sum is correct.
**Params.** Word length, number of addends, whether leading zeros are banned.
**Generator.** Two paths. Authored (SEND+MORE=MONEY) — memorable but a content treadmill and *language-locked*, since the words must be real words in the player's language. Generated with abstract symbols instead of letters — fully language-free, but loses all the charm.
**Uniqueness.** Brute force over digit assignments (at most 10! / (10-k)!, trivial for k up to 8), counting solutions exactly.
**Touch.** Tap a letter, tap a digit.
**Round.** 2-4 min.
**Share.** Solved plus time.
**Risk.** The good version is language-locked and hand-authored; the generatable version is charmless. That fork is why this sits low on the list despite an easy solver.

## 47. Sequence completion

**Rules.** What comes next?
**Params.** Sequence type (arithmetic, geometric, alternating, recursive, figurate), length shown.
**Generator.** Pick a rule family, instantiate it with random parameters, emit the terms, hide the last.
**Uniqueness.** Formally impossible. *Any* finite sequence extends infinitely many ways, so "the" answer is a convention, not a fact. You can reduce complaints by checking that no *simpler* rule (by some description-length measure) also fits the given terms, but you cannot eliminate them.
**Touch.** Tap a number pad or choose from options.
**Round.** 20-40s.
**Share.** Correct or not.
**Risk.** The uniqueness problem above is disqualifying for a daily puzzle. A player who finds a defensible alternative answer and is marked wrong will be correctly aggrieved, and will say so publicly. Recommend against.

## 48. Magic square completion

**Rules.** Fill in the missing numbers so every row, column, and both diagonals sum to the same total.
**Params.** Order (3 or 4), how many cells are pre-filled.
**Generator.** Take a known magic square, apply a symmetry (rotate, reflect, or for order 3 that's the entire family — there is only one 3x3 magic square up to symmetry), then blank some cells.
**Uniqueness.** Trivially checkable by brute force over the blanks.
**Touch.** Tap cell, tap number pad.
**Round.** 30-60s.
**Share.** Poor.
**Risk.** At order 3 there is exactly one magic square up to symmetry, so the puzzle is the same puzzle every single day — a player learns it once and it's over forever. Order 4 has 880 up to symmetry, which is better but still a finite, memorisable pool. Structurally unsuited to a *daily*. Recommend against.
