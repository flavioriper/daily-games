# Insane Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every one of the nineteen flat boards gets a fourth, playable **Insane** level (difficulty 3): the ink sheet row, its locale key, a provisional band-3 row in every generator, the bank loader that later batches fill, and the miner's skeleton.

**Architecture:** Difficulty 3 already flows through seeds (`Daily.seed_for` round = difficulty), progress (`Registry.progress_id`) and analytics. This batch adds the registry level rows, draws the Insane row differently, gives every generator a real band 3 instead of the silent clamp to Hard, and adds `core/insane_bank.gd` + a `bank_step` on `PuzzleBase` so banked boards (batches 2-5) can pick a no-repeat board per day. No board reads a bank yet in this batch; the provisional band 3 is what every board plays until its batch lands, and stays as the fallback after.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility. Headless runs: `godot --headless --path . --script <script>`.

**Spec:** `docs/superpowers/specs/2026-09-23-insane-level-design.md`

## Global Constraints

- Level name is exactly `"Insane"`; locale row `DIFF_INSANE,Insane,Insano,Demencial` in `locale/ui.csv`.
- Every Insane board is unique and logic-solvable wherever the board's existing generator already proves that; never weaken a generator's proof to make band 3 fit.
- Generation worst case for band 3 must stay under the **194 ms** gate on this Mac (Sudoku: under its own 300 ms `TIME_BUDGET_MS`), measured over at least 40 seeds. If a provisional row misses it, use the task's named fallback row and change the registry line to match.
- Render harnesses run at `--resolution 810x1440`, placed **before** `--script`; one windowed harness at a time.
- No new test suites (MVP rule, memory `no-new-tests-for-now`): throwaway probes in the scratchpad dir `/private/tmp/claude-501/-Users-flavioriper-dev-daily/ff0552af-1d53-469b-b7fd-7d21a683ed82/scratchpad`, never committed. The existing suite must still pass: `godot --headless --path . --script tests/run_tests.gd` ends `failed=0`.
- Never write the names of the games these boards rename (see CLAUDE.md) in code, comments or strings.
- Draw calls for any screen stay under the 855 budget.
- Work in place on branch `feat/insane-foundation` off `main`; commit per task; merge locally at the end; the user calls the push.

## Review Focus

1. **The New button on an Insane board** must hand a *different* board, not today's again: `bank_step` increments in `_on_new`, and Redo resets it to 0. Pinned in Task 1 Step 4.
2. **A pick card opened without the sheet** (`_open_at(entry, 1)`) must still open medium; nothing may default to 3. Checked in Task 7 Step 2.
3. **The sheet on a short phone**: four rows plus title must fit at 810x1440 without clipping the Insane row. Shot in Task 2 Step 5.
4. **A band-3 generator that fails** (`ok: false` / fallback path) must still hand a board, never an empty card. The probe in Task 3/4 counts `ok == false` per board and must read 0 across 40 seeds.
5. **pt/es sheet**: `Demencial` / `Insano` must fit the name label beside the longest line without overflowing into the mark. Shot in Task 2 Step 5.

---

### Task 1: `InsaneBank` and the host's `bank_step`

**Files:**
- Create: `core/insane_bank.gd`
- Modify: `core/puzzle_base.gd` (add `bank_step` var near the other state vars around line 30)
- Modify: `ui/puzzle_host.gd:167-190` (`_spawn`), `:267-270` (`_on_new`)
- Modify: `ui/flat/flat_host.gd:450-457` (`_on_redo`)

**Interfaces:**
- Produces: `InsaneBank.pick(puzzle_id: String, step: int) -> Dictionary` (empty dict when no bank), `InsaneBank.size(puzzle_id: String) -> int`, `InsaneBank.day_ordinal() -> int`; `PuzzleBase.bank_step: int` set by the host before `start()`.

- [ ] **Step 1: Write `core/insane_bank.gd`**

```gdscript
extends RefCounted

## Insane boards mined on the Mac (tools/mine_insane.gd) and shipped as
## content, one file a board: content/insane/<puzzle_id>.json, shaped
## {"version": 1, "note": "...", "boards": [ {...}, ... ]}. A word board's
## file follows the player's language through Locale.content().
##
## A day picks through one fixed shuffle of the pool, so nothing repeats
## until the whole pool has been played; `step` is how many times New has
## been pressed since the board opened. An absent or unreadable bank is an
## empty dict, and the board falls back to its live band 3.

const DIR := "res://content/insane/"

static var _cache: Dictionary = {}

static func path_for(puzzle_id: String) -> String:
	return Locale.content(DIR + puzzle_id + ".json")

static func boards(puzzle_id: String) -> Array:
	var path := path_for(puzzle_id)
	if _cache.has(path):
		return _cache[path]
	var out: Array = []
	if FileAccess.file_exists(path):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
		if doc is Dictionary and doc.get("boards") is Array:
			out = doc.boards
		else:
			push_warning("InsaneBank: %s is not a bank" % path)
	_cache[path] = out
	return out

static func size(puzzle_id: String) -> int:
	return boards(puzzle_id).size()

## Whole UTC days since the epoch: the same instant the daily rolls over.
static func day_ordinal() -> int:
	return int(Time.get_unix_time_from_system()) / 86400

static func pick(puzzle_id: String, step: int) -> Dictionary:
	var pool := boards(puzzle_id)
	if pool.is_empty():
		return {}
	var order: Array = range(pool.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = Daily.fnv1a("insane|" + puzzle_id)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return pool[order[(day_ordinal() + step) % order.size()]]
```

- [ ] **Step 2: Add `bank_step` to `core/puzzle_base.gd`**

Beside `moves`, `elapsed`, `hints_used`:

```gdscript
## How many times New was pressed since this board's card opened; a banked
## Insane board (core/insane_bank.gd) steps its pick by it. The host sets it
## before start().
var bank_step := 0
```

- [ ] **Step 3: Wire the host**

In `ui/puzzle_host.gd` add `var _bank_step := 0` beside `_difficulty`. In `_spawn`, before `_puzzle.start(...)`, add `_puzzle.bank_step = _bank_step`. `_on_new` becomes:

```gdscript
func _on_new() -> void:
	# Prototype affordance only. The shipped game gets one puzzle per day.
	Analytics.track("new_puzzle", {"puzzle_id": _entry.get("id", "")})
	_bank_step += 1
	_spawn(randi())
```

In `ui/flat/flat_host.gd` `_on_redo`, set `_bank_step = 0` before `_spawn(...)`.

- [ ] **Step 4: Throwaway probe**

`$SCRATCH/probe_bank.gd` (SceneTree script): write a fake bank of 5 boards `{"n": i}` to `res://content/insane/_probe.json`, then assert: `pick("_probe", 0) != pick("_probe", 1)`; the 5 picks for steps 0-4 are the 5 distinct boards; `pick("nope", 0).is_empty()`; `size("_probe") == 5`. Print PASS/FAIL, delete the fake file, quit.

Run: `godot --headless --path . --script $SCRATCH/probe_bank.gd`
Expected: `PASS`, and `git status` shows no `content/insane/_probe.json`.

- [ ] **Step 5: Suite and commit**

Run: `godot --headless --path . --script tests/run_tests.gd` → `failed=0`.

```bash
git add core/insane_bank.gd core/puzzle_base.gd ui/puzzle_host.gd ui/flat/flat_host.gd
git commit -m "feat(insane): a bank loader and a New step for banked boards"
```

---

### Task 2: The Insane row on the sheet

**Files:**
- Modify: `ui/menu/difficulty_sheet.gd` (`LEVEL_KEYS`, `_row`)
- Modify: `locale/ui.csv` (after the `DIFF_HARD` row, ~line 16)
- Modify: `ui/registry.gd` (every `PUZZLES` entry's `levels`)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: registry rows `{"difficulty": 3, "name": "Insane", "line": ...}` on all nineteen `PUZZLES` entries, which Tasks 3-5 may re-word if a fallback row is used.

- [ ] **Step 1: Locale key**

Add after `DIFF_HARD` in `locale/ui.csv`: `DIFF_INSANE,Insane,Insano,Demencial`. Run `godot --headless --path . --import` so the `.translation` files regenerate.

- [ ] **Step 2: Map the name and draw the night row**

`LEVEL_KEYS` gains `"Insane": "DIFF_INSANE"`. In `_row`, compute `var night := int(level.get("difficulty", index)) == 3`. When `night`:
- fill is `Pal.TEXT` (pressed `Pal.TEXT.lightened(0.08)`), name colour `Pal.PAPER`, line colour `Pal.PAPER` at alpha 0.72;
- the mark draws the done check in `Pal.SUN` and the chevron in `Pal.PAPER` at 0.72;
- a crescent moon sits left of the mark: a `Control` 40x40 whose `draw` does `draw_circle(c, 16, Pal.SUN)` then `draw_circle(c + Vector2(7, -5), 14, Pal.TEXT)` (the bite drawn in the row's own fill). Offset it so its right edge is 16 left of the mark; widen `text.offset_right` by 56 on the night row so the line never runs under it.
Other rows are unchanged.

- [ ] **Step 3: Registry rows**

Append to each entry's `levels` (the line matches Tasks 3-5's provisional knobs):

| id | line |
|---|---|
| binairo | `10 × 10` |
| mastermind | `5 friends of 7, 7 tries` |
| balance | `5 fruits, weights to 12` |
| untangle | `20 lanterns` |
| shikaku | `8 × 10` |
| tents | `10 × 10` |
| lightup | `9 × 9` |
| oneline | `5 × 4 posts` |
| nonogram | `10 × 10` |
| queens | `9 × 9` |
| hiddenword | `Any word, no hints` |
| wordtrail | `6 words, 8 × 8` |
| mushroom | `16 mushrooms, 9 × 9` |
| sudoku | `9 × 9, 22 clues` |
| bridges | `30 islets, 11 × 11` |
| quilt | `10 patches, 7 × 7` |
| fairylights | `8 × 8 garden` |
| planes | `16 × 22 sky, long planes` |
| pinwheel | `16 pieces, 7 × 8` |

Also change each entry's `"difficulties": [0, 1, 2]` to `[0, 1, 2, 3]` (data only, kept in step).

- [ ] **Step 4: Check every entry has four levels**

`$SCRATCH/probe_levels.gd`: load `ui/registry.gd`, for every `PUZZLES` entry assert `levels.size() == 4` and `levels[3].name == "Insane"`; print offenders; quit.
Expected: no offenders.

- [ ] **Step 5: Shoot the sheet**

Use `tests/_shot_sheets.gd` (read its header for how it opens the difficulty sheet; if it cannot, copy it to `$SCRATCH/shot_diff.gd` and call `menu.difficulty_sheet.ask(Registry.PUZZLES[13])` for Sudoku, the longest lines). Shoot en, pt, es:
`godot --path . --resolution 810x1440 --script $SCRATCH/shot_diff.gd -- <lang>`
Look at each frame: four rows whole, the ink row with its moon, no text under the moon or mark. Read the draw-call count; it must be under 855.

- [ ] **Step 6: Suite and commit**

```bash
git add ui/menu/difficulty_sheet.gd locale/ ui/registry.gd
git commit -m "feat(insane): a fourth row, lettered in the night's ink, on every sheet"
```

---

### Task 3: Band 3 on the first ten generators

**Files (one constant row each unless noted):**
- `puzzles/binairo2d.gd:72` `LEVELS`
- `puzzles/untangle_state.gd:22` `NODES`, `puzzles/untangle2d.gd:55` `R_OF`
- `puzzles/shikaku_state.gd:23` `SIZES` (+ a `MAX_AREA_INSANE := 12` const)
- `puzzles/tents_state.gd:28` `SIZES`
- `puzzles/lightup_state.gd:33` `SIZES`
- `puzzles/oneline_state.gd:30` `DIMS`
- `puzzles/nonogram_state.gd:31` `SIZES`
- `puzzles/queens_state.gd:35` `SIZES`
- `puzzles/mushroom_gen.gd:26-32` `SIZES`, `SUBSETS`, `GIVE_BACK`
- `puzzles/fairy_lights_gen.gd:41,166` `SIZES` and the hard-coded clamp

**Interfaces:**
- Consumes: registry lines from Task 2.
- Produces: `build(rng, 3)` on each board makes a band-3 board.

- [ ] **Step 1: Write the timing probe**

`$SCRATCH/probe_band3.gd` (SceneTree): for a board id from the user args, load its registry entry's script, and in `_process` (memory `godot-headless-ready-deferred`) for 40 seeds: instance the board, `root.add_child`, `var t := Time.get_ticks_usec()`, `board.start(rng_seeded(seed), 3)`, record ms, read any `ok`/`proved`/`unique`/`graded` flag the board's state exposes (print which one it found), free the board. Print `id n worst mean fails`. If a board's build needs a sized rect, set `board.size = Vector2(1000, 1340)` before `start`.

Run: `godot --headless --path . --script $SCRATCH/probe_band3.gd -- binairo`
Expected before the change: numbers for the **hard** board (the clamp).

- [ ] **Step 2: Add the rows**

| board | band 3 row | fallback if over the gate |
|---|---|---|
| binairo | `{"size": 10, "min_clues": 14, "signs": 10}` | `{"size": 8, "min_clues": 0, "signs": 6}` (line `8 × 8, bare`) |
| untangle | `NODES` 20, `R_OF` 38.0 | 18 / 40.0 |
| shikaku | `[8, 10, MAX_AREA_INSANE]` | `[8, 10, MAX_AREA]` |
| tents | `[10, 10, 14]` | `[9, 9, 12]` (line `9 × 9`) |
| lightup | `[9, 9, 0.18]` | `[8, 8, 0.18]` (line `8 × 8`) |
| oneline | `[5, 4, 0.45]` | `[4, 4, 0.60]` (line `4 × 4, dense`) |
| nonogram | `10` | `9` (line `9 × 9`) |
| queens | `9` (same court as hard; the bank in batch 2 is what makes it insane) | none |
| mushroom | `SIZES` `[9, 16]`, `SUBSETS` `true`, `GIVE_BACK` `0.0` | `[8, 14]` (line `14 mushrooms, 8 × 8`) |
| fairylights | `SIZES` 8, clamp to `SIZES.size() - 1` | 7 (line `7 × 7 garden`) |

Each row gets a one-line comment saying it is Insane's provisional band, replaced by the bank in its batch.

- [ ] **Step 3: Measure each**

Run the probe for all ten ids, sequentially. Record `worst mean fails` in the commit message. Any board over 194 ms worst or with `fails > 0`: switch to its fallback row, update the registry line, re-measure.

- [ ] **Step 4: Look at the two that grow the screen**

Nonogram 10x10 (the long clue case) and Untangle at 20 lanterns: shoot `tests/_shot_anim.gd -- nonogram` / `-- untangle` at `--resolution 810x1440` after making the harness open difficulty 3 (read its level arg at line ~331; pass `3` if supported, else a scratch copy that does). The grid must be whole inside the card, clues unclipped. If Nonogram's clues clip, use its fallback.

- [ ] **Step 5: Suite and commit**

```bash
git commit -am "feat(insane): band 3 on ten generators

<one line per board: row, worst/mean ms over 40 seeds, fails>"
```

---

### Task 4: Band 3 on the next six generators

**Files:**
- `puzzles/sudoku_gen.gd:32-34,156` `SIZE`, `TARGET`, grade test
- `puzzles/bridges_gen.gd:14-18` `BANDS`
- `puzzles/quilt_gen.gd:73-77,166-168` `BANDS`, thresholds
- `puzzles/planes_state.gd:23-27` `BANDS`
- `puzzles/pinwheel_gen.gd:40-44` `BANDS`
- `puzzles/word_trail_state.gd:20,61` `BANDS`, the hard-coded `n` clamp

**Interfaces:**
- Consumes: `$SCRATCH/probe_band3.gd` from Task 3.
- Produces: `build(rng, 3)` makes a band-3 board on each.

- [ ] **Step 1: Add the rows**

| board | band 3 | fallback |
|---|---|---|
| sudoku | `SIZE` 9, `TARGET` 22; grade test becomes `singled if d == 0 else not singled` unchanged (d 3 wants not-singled, as hard) | `TARGET` 24 (line `9 × 9, 24 clues`) |
| bridges | `{"n": 11, "islets": 30, "span": 6, "loops": 12, "guess_free": false}` | `islets` 27 (line `27 islets, 11 × 11`) |
| quilt | `{"box": 7, "patches": 10, "sizes": [3, 4, 5, 6]}`; change `d == 2` to `d >= 2` for `HARD_NODES` | `patches` 9 (line `9 patches, 7 × 7`) |
| planes | `{"cols": 16, "rows": 22, "min_len": 4, "max_len": 12, "weights": [2, 3, 4, 5, 5, 5, 4, 3, 2], "floor": 0.80}` (9 weights for lengths 4-12) | `floor` 0.76 |
| pinwheel | `{"cols": 7, "rows": 8, "sizes": [2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4, 4, 3, 3], "min_turns": 26, "max_stack": 3}` (sums to 56) | `min_turns` 22 |
| wordtrail | `BANDS` row `[6, 7, 8, 8, 8, 8]`; `n = 5 + clampi(difficulty, 0, BANDS.size() - 1)` gives 8 | `[5, 6, 7, 8, 8, 8]` |

Before writing planes' and pinwheel's rows, read how `weights` is indexed against `min_len..max_len` and how `sizes` must relate to `cols * rows` in each file's header, and correct the row if the rule differs from the note above.

- [ ] **Step 2: Measure each**

Run the probe for all six, sequentially. Sudoku's gate is its own 300 ms and `graded` must be true on all 40. Any miss: fallback, registry line, re-measure.

- [ ] **Step 3: Look at planes and wordtrail**

`tests/_shot_anim.gd -- planes` and `-- wordtrail` at band 3, `--resolution 810x1440`. The field must fit the card (Word Trail 8x8 is about 107 a cell).

- [ ] **Step 4: Suite and commit**

```bash
git commit -am "feat(insane): band 3 on six more generators

<one line per board: row, worst/mean ms over 40 seeds, fails>"
```

---

### Task 5: The three rule boards

**Files:**
- `puzzles/codebreak_state.gd:18,45-50`; `puzzles/codebreak2d.gd:146,280,364,397,480,808`
- `puzzles/hidden_word_state.gd:27,40,76`
- `puzzles/balance_gen.gd:11` and `puzzles/balance2d.gd` (where `generate` is called)

**Interfaces:**
- Produces: `State.tries` (instance var) on Code Break; `hints_left` 0 at band 3 on Hidden Word; `BalanceGen.generate(rng, shapes, max_w := MAX_W)`.

- [ ] **Step 1: Code Break, seven tries**

`const TRIES := 8` stays as the default; add `var tries := TRIES`. `setup`'s match gains `3: length = 5; palette_size = 7; repeats = true; tries = 7` before `_`, and every other arm sets `tries = TRIES`. Replace each `TRIES` read in the state's logic (line ~165) with `tries`, and each `State.TRIES` in `codebreak2d.gd` with `state.tries` (six sites listed above). Line 364's layout then sizes seven rows.

- [ ] **Step 2: Hidden Word, no hints**

In `build`, after `hints_left = HINTS`: `if difficulty >= 3: hints_left = 0`. The band clamp already hands band 3 the whole list. Check the hint button reads `hints_left()` and shows disabled at 0 (read `hidden_word2d.gd:1120` callers).

- [ ] **Step 3: Balance, heavier weights**

Give `generate` a `max_w: int = MAX_W` parameter and thread it to every `MAX_W` read inside `balance_gen.gd` (search the file; brute force ranges over `1..max_w`). `balance2d.gd` passes `12 if difficulty >= 3 else BalanceGen.MAX_W`. Measure with the probe: brute force grows by about (12/9)^4, roughly 3x; must stay under the gate.

- [ ] **Step 4: Shoot Code Break at band 3**

`tests/_shot_anim.gd -- codebreak` (or its registry id `mastermind`, whichever the harness takes) at band 3: seven rows laid out whole.

- [ ] **Step 5: Suite and commit**

```bash
git commit -am "feat(insane): seven tries, no hints and heavier fruit"
```

---

### Task 6: The miner's skeleton

**Files:**
- Create: `tools/mine_insane.gd`
- Create: `tools/insane/README.md`

**Interfaces:**
- Consumes: `InsaneBank.DIR` (Task 1).
- Produces: the ladder contract later batches implement: a script at `res://tools/insane/<puzzle_id>_ladder.gd` with `static func candidate(rng: RandomNumberGenerator) -> Dictionary` (a board in the state's `from_bank` encoding), `static func grade(board: Dictionary) -> Dictionary` returning `{"rung": int, "work": int, "unique": bool}`, and `const HARD_RUNG: int` (the highest rung Hard's own generator accepts).

- [ ] **Step 1: Write `tools/mine_insane.gd`**

A SceneTree script: parse `-- <puzzle_id> <count> [tries]` (tries default `count * 50`); load the ladder or print "no ladder for <id>" and quit 1; loop `tries` times with `rng.seed = i`, `candidate`, `grade`; keep boards with `unique and rung > HARD_RUNG`; sort kept by `(rung, work)` descending; take `count`; write `{"version": 1, "note": "<id> Insane, mined <date>, <kept>/<tries> kept, rungs <min>-<max>", "boards": [...]}` with each board carrying its `grade` to `res://content/insane/<id>.json`; print a histogram of rungs. Never overwrite without printing the old file's size first.

- [ ] **Step 2: Write `tools/insane/README.md`**

Ten lines: the contract above, the run line (`godot --headless --path . --script tools/mine_insane.gd -- sudoku 400`), that ladders never load in the game, and that a bank must be re-proven through the board's `from_bank` path before it ships.

- [ ] **Step 3: Smoke it with a throwaway ladder**

`$SCRATCH/_probe_ladder.gd` copied to `tools/insane/_probe_ladder.gd` for the run only: `candidate` returns `{"n": rng.randi() % 100}`, `grade` returns `{"rung": n % 4, "work": n, "unique": true}`, `HARD_RUNG` 1. Run `-- _probe 5 50`; expect a 5-board file with every rung ≥ 2. Delete the probe ladder and the file; `git status` clean of both.

- [ ] **Step 4: Commit**

```bash
git add tools/mine_insane.gd tools/insane/README.md
git commit -m "feat(insane): the miner's skeleton and the ladder contract"
```

---

### Task 7: Sweep and merge

- [ ] **Step 1:** Probe all nineteen ids at band 3 once more (`probe_band3.gd`), one after another; paste the table into the merge commit.
- [ ] **Step 2:** Open three pick cards straight (no sheet) and check `_open_at(entry, 1)` still opens medium; open Sudoku via the sheet's Insane row in the windowed game and play one move, press New, confirm a different board.
- [ ] **Step 3:** `godot --headless --path . --script tests/run_tests.gd` → `failed=0`; `tests/_win.gd` windowed (memory `win-harness-needs-a-display`).
- [ ] **Step 4:** Update CLAUDE.md's first-screen section with one short bullet: Insane exists, its row is ink with a moon, band 3 is provisional until each batch's bank, and the spec path.
- [ ] **Step 5:** Merge `feat/insane-foundation` into `main` locally (`git merge --no-ff`), delete the branch, report; the user calls the push.
