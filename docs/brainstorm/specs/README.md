# Mini-Puzzle Specs — index

75 candidate mechanics, one small spec each. Brainstorming artifacts, not commitments.

| File | Family | Entries |
|------|--------|---------|
| `A-grid-deduction.md` | Grid deduction | 1-24 |
| `B-spatial.md` | Spatial manipulation | 25-42 |
| `C-number.md` | Number & arithmetic | 43-48 |
| `D-perception.md` | Perception & pattern | 49-56 |
| `E-graph.md` | Graph & routing | 57-61 |
| `F-word.md` | Word & language | 62-69 |
| `G-adversarial.md` | Adversarial & combinatorial | 70-75 |

Each entry: **Rules** (as told to the player) / **Params** (difficulty knobs) /
**Generator** / **Uniqueness** (how we prove one solution) / **Touch** /
**Round** (target solve time) / **Share** (share-string glyph) / **Risk**.

---

## What writing all 75 actually surfaced

**1. The generator, not the UI, decides what you can ship.**
Every mechanic here splits into one of three buckets, and the bucket predicts the
schedule better than anything else:

- *Build-then-strip* — construct a valid solution, then remove clues while a solver
  re-confirms uniqueness. Days of work. Entries 1, 2, 3, 9, 10, 11, 13, 14, 15, 16,
  21, 22, 26, 27, 32, 37, 44, 45, 75.
- *Search-characterised* — no uniqueness to prove; instead compute the exact optimum
  by BFS/IDA* and score against it. Entries 19, 30, 31, 39, 43, 57, 59, 70, 72, 73, 74.
- *Research-y* — global constraints make uniqueness expensive; bake puzzles offline or
  skip. Entries 6, 7, 8, 18, 24, 36, 38, 40(modified), 67.

**2. Nine entries have a fatal flaw, not a cost.** Worth deciding once and never
revisiting: **47** (sequence completion) and **53** (Raven's) cannot have provable
unique answers; **50** (off-shade) and **55** (hidden shape) fail for colour-blind
players and cheap screens; **48** (magic square) has a finite memorisable pool, which is
structurally incompatible with a *daily*; **63, 67, 69** (Connections, crossword,
cryptic) are permanent daily editorial jobs, not software; **71** (Hanoi) is recall,
not puzzling.

**3. Entry 20 is the quiet headline.** Mastermind produces *Wordle's exact share grid* —
same guess-feedback rhythm, same coloured block history — with a one-line generator and
zero language content. The whole of Family F exists to buy something entry 20 gives away
free. Worth a hard look before anyone writes a dictionary loader.

**4. Four gestures, and they predict coherence.** Tap-to-cycle (most of A),
drag-a-path (9, 38, 40, 57, 59), drag-and-rotate-a-piece (28, 29, 36, 41),
rotate-in-place (26, 32, 34). A daily set drawing on one or two of these reads as *one
game*. A set using all four reads as a shovelware bundle. This is probably a better
basis for choosing a lineup than puzzle family is.

**5. Determinism is a hard requirement, and one entry nearly breaks it.**
Entry 35 (marble drop) must be grid-stepped, never physics-simulated: float and
frame-rate variance would resolve the same daily puzzle differently on different phones.
Fine by design, fatal by accident.

**6. Godot's 3D earns its place exactly once.** Entry 33 (fold-the-net) gets the
3D payoff with tap-only input. Entry 42 (3D rope) gets the same payoff and inherits the
unsolved problem of dragging in three dimensions on a flat screen.

---

## Tiers, on these criteria

Criteria: touch-native / 1-2 min round / provable uniqueness / language-free / shareable.

**Tier 1 — cheap generator, native gesture, clean share.**
9 Shikaku, 14 Binairo, 20 Mastermind, 21 Tents & Trees, 26 Pipe rotation,
27 Untangle, 11 Light Up, 1 Nonogram, 57 One-line drawing, 45 Balance scales.

**Tier 2 — strong, with one identified cost.**
13 Star Battle, 16 Skyscrapers, 15 Futoshiki, 10 Bridges, 22 Aquarium, 37 Magnets,
30 Rush Hour, 34 Laser routing, 32 Dial alignment, 40 Zip, 59 Shortest-path-with-twist,
33 Fold-the-net, 19 Lights Out, 43 Reach-the-target, 75 Pictogram deduction,
28 Polyomino packing, 51 Symmetry, 49 Odd-one-out.

**Tier 3 — viable but costly, niche, or saturated.**
2, 3, 4, 5, 12, 17, 23, 25, 31, 35, 38, 39, 41, 44, 46, 52, 54, 56, 58, 60, 61, 62,
64, 65, 66, 68, 70, 72, 73, 74.

**Tier 4 — recommend against.** 6, 7, 8, 18, 24, 29, 36, 42, 47, 48, 50, 53, 55,
63, 67, 69, 71.

Note 59 and 60 are near-duplicates — build one, you have both.
Note 19 and 61 are the same puzzle (binary toggles with propagation) under two skins.
