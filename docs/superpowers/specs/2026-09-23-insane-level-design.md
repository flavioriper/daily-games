# Insane: a fourth level on every board

2026-09-23. Foundation spec; each board's own Insane is specified in a batch
spec that follows this one (section 6).

## 1. What it is for

A fourth row, **Insane**, on every one of the nineteen difficulty sheets, for
really skilled players. It should make Hard read as a warm-up, close to
impossible, and still **fair**: every Insane board has exactly one answer,
and that answer is reachable by logic without a guess. The difficulty comes
from the depth of the deduction the board demands, never from a coin flip.

It is open to everyone from day one (the user's choice over an earned unlock
or a separate daily).

## 2. Why the boards cannot simply grow

The phone already caps several Hard boards at the thumb: Paper Planes' cell
is 58, Bridges' 84, Nonogram's 88 and Sudoku's 100. And twelve of the
nineteen generators only prove uniqueness by search; only Mushroom Patch,
Sudoku (singles), Bridges (`guess_free`), Quilt (node count), Nonogram (line
logic) and Fairy Lights (propagation) grade at all, each with one tier. A
bigger or sparser board graded by uniqueness alone is Hard made longer, not
harder. So Insane is graded by **technique depth**, and the grading happens
off the phone.

## 3. The fourth row

- Every flat registry entry gains
  `{"difficulty": 3, "name": "Insane", "line": "..."}`; the line names what
  makes it brutal, the way the other three name their size.
- `ui/menu/difficulty_sheet.gd` maps `"Insane"` to `DIFF_INSANE`, and
  `locale/ui.csv` gains `DIFF_INSANE,Insane,Insano,Demencial`.
- The row is drawn as the night level: filled in ink (`Pal.TEXT`) with paper
  lettering and a small moon mark from the family's sun and moon, so it reads
  as a dare rather than as the next step. The sheet sizes to its content; the
  row adds 142 (128 + 14).
- Seeds (`DailySeed.seed_for`, round = difficulty) and progress
  (`Registry.progress_id`, `id_3`) already take a fourth level: it keeps its
  own daily and its own tick. Analytics carries `difficulty: 3` unchanged.
- The three places that hand band 3 the Hard board today get explicit Insane
  arms: `codebreak_state.gd`'s `match` (`_` falls through to hard),
  `word_trail_state.gd`'s and `fairy_lights_gen.gd`'s hard-coded
  `clampi(difficulty, 0, 2)`. Every other board already clamps against its
  own table's size.

## 4. Banks

Deduction boards ship their Insane boards as content, mined on the Mac,
the way Hidden Word ships its words.

- **Format.** `content/insane/<puzzle_id>.json`:
  `{"version": 1, "note": "...", "boards": [ {...}, ... ]}`. A board is the
  board state's own encoding (givens, regions, clues, size) plus `grade`, the
  miner's measure of it. `content/*` is already in the export preset's
  `include_filter`.
- **Per language.** A word board's bank is `<id>.pt.json` / `<id>.es.json`
  through `Locale.content()`, falling back to English as the word lists do.
- **Picking.** `core/insane_bank.gd` (static, cached per path) shuffles a
  pool once with a fixed seed per board and indexes it by day number, so no
  board repeats until the pool has been played through. About 400 boards is
  more than a year.
- **New.** The New button steps to the next index in the same shuffle.
- **Loading.** A banked board's `build(rng, 3)` asks `InsaneBank.pick(id,
  day, offset)` and hands the dict to its state's new `from_bank(dict)`.
- **Safety net.** A missing, empty or unreadable bank logs a warning and
  falls back to the board's live generator at its Insane band's knobs. The
  card is never empty.

Boards whose Insane is a change of rules rather than a harder board (Code
Break, Untangle, One Line; see section 6) have no bank and are generated live.

## 5. The miner

`tools/mine_insane.gd`, headless:
`godot --headless --script tools/mine_insane.gd -- <puzzle_id> <count>`.

- Candidates come from the board's own generator at the Insane band's knobs,
  so a mined board is always one the game could have drawn.
- Each candidate is rated by a **technique ladder** written for that board:
  an ordered list of solvers, each strictly stronger than the last, the top
  rung complete (it never guesses). A candidate's grade is the lowest rung
  that finishes it plus that rung's work (steps or search nodes).
- A candidate is kept only if **every rung up to and including the one Hard
  needs fails to finish it**, and it is proven unique. The hardest `count`
  by grade are written.
- The graders run only on the Mac and have no time budget. They live under
  `tools/insane/` and are never loaded by the game.

## 6. What Insane means, board by board

The first drafts below are refined, measured and approved in the batch
specs. Caps named in brackets come from the generator survey
(2026-09-23).

| Board | Insane (first draft) | Source |
|---|---|---|
| Sudoku | 9x9, 21-24 givens, needs chains (SE ~6+); a pairs/wings/chains ladder above today's singles | bank |
| Queens | 9x9 [palette 9], needs multi-region forcing | bank |
| Nonogram | 10x10 (lifts the deliberate 9 cap), line logic alone fails; needs contradiction probing | bank |
| Bridges | 11x11 [84 cell floor], ~30 islets, must branch deeply | bank |
| Binairo | 10x10, minimal clues, needs contradiction chains | bank |
| Shikaku | 8x10, areas to 12, non-local deduction | bank |
| Tents | 10x10, contradiction required | bank |
| Light Up | 9x9, few numbered walls, contradiction required | bank |
| Mushroom Patch | 9x9, a tier above today's 1-2-1 subsets | bank |
| Quilt | 7x7 [64-cell mask], 9-10 patches, top proof node counts | bank |
| Fairy Lights | 8x8, propagation alone fails | bank |
| Pinwheel | 7x8, more pieces, deep interlocked turns | bank |
| Word Trail | 8x8, six words [colour cap] of long lengths, proven unique | bank |
| Paper Planes | 16x22 [58 cell floor], chokepoint skies: most steps have one legal launch | bank |
| Hidden Word | rarest words, 5 rows, no hints | bank (per language) + rules |
| Code Break | 5 seats of 7 friends, repeats, **7 tries** (Super Mastermind's optimal worst case: no slack) | live |
| Balance | 5 fruits [art cap], no revealed anchor, heavier weights, minimal scales | decided in batch 5 |
| Untangle | ~20 lanterns | live |
| One Line | a larger, denser lattice | live |

**Batches**, in order (each its own spec, plan and merge):
1. Foundation (this spec): the row, the key, `InsaneBank`, the miner's
   skeleton, the three explicit arms, and a provisional fourth table row on
   every generator (its Hard knobs pushed as far as the screen allows), so
   Insane is playable everywhere and is the fallback once banks land.
2. Sudoku, Queens, Nonogram, Bridges.
3. Binairo, Shikaku, Tents, Light Up.
4. Mushroom Patch, Quilt, Fairy Lights, Pinwheel.
5. Word Trail, Paper Planes, Hidden Word, Code Break, Balance, Untangle,
   One Line.

## 7. Checking it

No new suites (MVP rule); throwaway self-driven checks instead:

- Every registry entry has four levels and every board's `build(rng, 3)`
  runs without error (the registry walk `tests/test_planes.gd` already does
  for `can_instantiate`).
- The sheet at `--resolution 810x1440` shows the ink row whole, in all three
  languages.
- With no bank present, each board opens its live Insane fallback; with a
  bank, two days pick two different boards and New steps to a third.
- Draw calls of the sheet read against the 855 budget.
- Per batch: each mined board is re-proven unique and re-graded by the
  shipped `from_bank` path, and Hard's own solver is shown to fail on it.
