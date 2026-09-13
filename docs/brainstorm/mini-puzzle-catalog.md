# Mini-Puzzle Catalog — candidates for the daily set

Status: brainstorming artifact, not a spec. Nothing here is chosen yet.

## Scoring legend

- **Gen** — cost to procedurally generate a puzzle with a *provably unique* solution.
  `E` easy, `M` moderate, `H` hard/research-y.
- **Lang** — `free` = no language content. `locked` = needs a curated wordlist per locale.
- **Touch** — primary phone gesture.
- **Star** — strong fit for a 1-2 min round on a phone.

---

## A. Grid deduction (pencil-and-paper logic)

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 1 | Nonogram / Picross | E | free | tap, drag-paint | Generate from a target image, verify uniqueness by line-solver. Result grid IS the art. * |
| 2 | Sudoku (mini 6x6) | E | free | tap + number pad | Utterly known. 6x6 fits a 1-2 min round; 9x9 does not. |
| 3 | Killer / Jigsaw Sudoku | M | free | tap + pad | Cage sums add depth without adding size. |
| 4 | Kakuro | M | free | tap + pad | Crossword shape, arithmetic content. Dense for small screens. |
| 5 | Hitori | M | free | tap to shade | Shade duplicates; connectivity constraint is elegant. |
| 6 | Slitherlink | H | free | tap edges | Beautiful, but edge-tapping is fiddly on a phone. |
| 7 | Masyu | H | free | drag path | Loop through pearls. Gorgeous solutions, hard generator. |
| 8 | Nurikabe | H | free | tap to shade | Islands and sea. Uniqueness proof is expensive. |
| 9 | Shikaku | E | free | drag rectangles | Divide grid into rectangles matching numbers. Drag is very phone-native. * |
| 10 | Hashiwokakero (Bridges) | M | free | drag between islands | Reads well at small size, chunky touch targets. * |
| 11 | Light Up (Akari) | M | free | tap | Place bulbs to light the board. Instant visual feedback. * |
| 12 | Minesweeper, no-guess variant | M | free | tap / long-press | Must guarantee logic-only solvability or it is infuriating. |
| 13 | Star Battle | M | free | tap | Two stars per row/col/region. Small grids work. * |
| 14 | Binairo / Takuzu | E | free | tap to cycle | Binary grid, three simple rules. Trivial generator. * |
| 15 | Futoshiki | E | free | tap + pad | Latin square with inequality signs. Tiny and clean. * |
| 16 | Skyscrapers | E | free | tap + pad | Visibility clues around the border. Teaches in one sentence. * |
| 17 | Yin-Yang | M | free | tap to cycle | Two-color connectivity. Visually striking. |
| 18 | Kuromasu | H | free | tap | Niche, heavy generator. |
| 19 | Lights Out | E | free | tap | Pure linear algebra over GF(2); solvability is provable instantly. * |
| 20 | Mastermind / code break | E | free | tap colors | Guess-feedback loop, Wordle's actual skeleton, language-free. * |
| 21 | Tents & Trees | E | free | tap | Pair tents to trees. Cute, readable, easy uniqueness. * |
| 22 | Aquarium | M | free | tap | Water levels in regions. Underused, feels fresh. |
| 23 | Dominosa | M | free | drag / tap pairs | Place a full domino set. Fixed piece count = fixed difficulty. |
| 24 | Norinori, LITS, Heyawake | H | free | tap | Deep cuts. Great for hardcore, bad for onboarding. |

## B. Spatial manipulation

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 25 | Sliding tile (15-puzzle) | E | free | drag | Solvability parity is trivial to enforce. Feels dated alone. |
| 26 | Pipe rotation (Net / Infinity Loop) | E | free | tap to rotate | Generate a spanning tree, then scramble rotations. Uniqueness is free. Extremely satisfying. * |
| 27 | Untangle (planar graph) | E | free | drag nodes | Generate a planar graph, scramble positions. Pure drag, zero text. * |
| 28 | Polyomino packing | M | free | drag + rotate | Fit pieces into a region. Tangram energy, tactile. * |
| 29 | Tangram silhouette | M | free | drag + rotate | Needs snapping polish to not feel bad. |
| 30 | Rush Hour / block escape | M | free | drag | Solvable-in-N generation via BFS over states. Very phone-native. * |
| 31 | Sokoban micro (<=8 moves) | M | free | swipe | BFS-generate small boards. Undo is mandatory. |
| 32 | Concentric dial alignment | E | free | rotate drag | Rings you spin to align. Gorgeous, near-trivial to generate. * |
| 33 | Fold-the-net (which net makes this solid) | E | free | tap choice | 3D reasoning, Godot renders it for free. Multiple-choice = fast round. * |
| 34 | Mirror & laser routing | M | free | tap to rotate | Place/rotate mirrors to hit targets. Reads instantly. * |
| 35 | Marble drop / gravity routing | M | free | drag pieces | Physics-flavored but deterministic if grid-based. |
| 36 | Edge-matching tiles (Carcassonne-like) | M | free | drag + rotate | Match colors across edges. Scales difficulty smoothly. |
| 37 | Magnet / polarity placement | M | free | tap to cycle | Classic Magnets puzzle. Underexposed. |
| 38 | Flow Free (connect + fill) | M | free | drag paths | Proven mobile megahit mechanic. Uniqueness needs care. * |
| 39 | Ball / water sort | E | free | tap, tap | Enormously popular, but it is a sort, barely a puzzle. |
| 40 | Zip / one-path-through-checkpoints | E | free | drag path | LinkedIn's hit. Hamiltonian path with ordered waypoints. * |
| 41 | Hexagon fitting | M | free | drag | Hex packing. Fresh geometry, more art cost. |
| 42 | Rope / knot untangle (3D) | M | free | drag | Showcases Godot 3D. Camera control on phone is the risk. |

## C. Number and arithmetic

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 43 | 24 game / reach-the-target | E | free | tap numbers + ops | Brute-force verify every solution. Trivial generator. * |
| 44 | KenKen / Calcudoku | M | free | tap + pad | Sudoku plus arithmetic cages. |
| 45 | Balance scales (deduce weights) | E | free | drag / tap | Visual algebra. Reads without instructions. * |
| 46 | Cryptarithm (SEND+MORE=MONEY) | E | locked-ish | tap + pad | Language-flavored but solvable as pure digits. |
| 47 | Number chain / sequence completion | E | free | tap | Risk: feels like an IQ test, ambiguity complaints. |
| 48 | Magic square completion | E | free | tap + pad | Small solution space, gets stale fast. |

## D. Perception and pattern (fast rounds, 15-45s)

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 49 | Odd-one-out tile | E | free | tap | Great as a warm-up round 1. Not a whole game. * |
| 50 | Off-shade colour spot | E | free | tap | Accessibility landmine (colour-blindness). Careful. |
| 51 | Symmetry completion | E | free | tap cells | Mirror the given half. Instantly legible. * |
| 52 | Rotation matching | E | free | tap choice | Which shape is a rotation of the target. Fast. * |
| 53 | Raven's-style matrix continuation | M | free | tap choice | Pattern continuation. Ambiguity risk is real. |
| 54 | Simon / flash sequence recall | E | free | tap | Memory, not deduction. Different muscle; good variety. |
| 55 | Hidden shape in noise | M | free | tap | Camouflage find. Art-cost heavy. |
| 56 | Glyph scan ("find all the X") | E | free | tap | Speed round. Shallow but satisfying. |

## E. Graph and routing

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 57 | One-line drawing (Eulerian path) | E | free | drag path | Draw without lifting your finger. Verify via degree parity. * |
| 58 | Graph colouring (4-colour a map) | M | free | tap to cycle | Pretty; needs colour-blind-safe palette plus patterns. |
| 59 | Shortest path with a twist rule | E | free | drag path | Rule modifiers give endless variants. |
| 60 | Maze with a rule modifier | E | free | drag | Plain mazes are boring; the modifier is the game. |
| 61 | Valve / network flow | M | free | tap to toggle | Reads as a machine. Good theming hook. |

## F. Word and language (language-locked, dictionary per locale)

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 62 | Wordle-like guess | E | locked | keyboard | The category king. Also the most cloned thing on earth. |
| 63 | Connections-like grouping | H | locked | tap + submit | Needs *authored* categories. Not generatable. Editorial cost forever. |
| 64 | Anagram unscramble | E | locked | drag letters | Cheap to build, cheap to feel cheap. |
| 65 | Word ladder | M | locked | tap | Needs a graph over the dictionary. |
| 66 | Strands-like word search | M | locked | drag | Themed, so partly editorial. |
| 67 | Crossword mini | H | locked | tap + keyboard | Authored clues. A full-time job. |
| 68 | Letter Boxed (spell around sides) | M | locked | tap | Elegant, still dictionary-bound. |
| 69 | Cryptic clue, single | H | locked | keyboard | Purely authored. Delightful, unscalable. |

## G. Adversarial / combinatorial

| # | Puzzle | Gen | Lang | Touch | Notes |
|---|--------|-----|------|-------|-------|
| 70 | Nim variant vs perfect AI | E | free | tap | "Beat the machine." Solved game, so difficulty is exact. |
| 71 | Tower of Hanoi micro | E | free | drag | Too well-known to feel like a puzzle. |
| 72 | Peg solitaire micro | E | free | drag | BFS-generated small boards. |
| 73 | Hex / Tak micro-position | M | free | tap | "Find the winning move" from a generated position. * |
| 74 | Chess-like mate-in-2 (custom pieces) | M | free | drag | Custom pieces dodge the chess-knowledge barrier. |
| 75 | Deduction from partial info (Clue-like) | M | free | tap grid | One-round whodunnit. Theming carries it. |

---

## Cross-cutting observations

1. **Language-free is a hard filter if you want one global build.** Family F costs a curated wordlist, an offensive-word blocklist, and a difficulty curve *per locale*. Families A-E cost one generator, translated only in UI strings.
2. **Generation cost is the real schedule risk, not the UI.** The board renders in an afternoon. Proving a unique solution is where weeks go. Prefer puzzles whose generator is "build the solution first, then remove clues while a solver confirms uniqueness."
3. **Touch verbs cluster into four gestures**: tap-to-cycle, drag-a-path, drag-and-rotate-a-piece, and rotate-in-place. A set that reuses one or two gestures feels coherent; one that uses all four feels like a shovelware bundle.
4. **Result-sharing wants a grid.** Wordle's share text works because the board is a small colour grid. Nonogram, Lights Out, Flow, and Zip all share this property. Path puzzles and 3D puzzles do not, natively.
5. **A round-1 warm-up should be near-free to solve.** Perception puzzles (49, 51, 52) exist to give the player a win in 10 seconds before difficulty arrives.
