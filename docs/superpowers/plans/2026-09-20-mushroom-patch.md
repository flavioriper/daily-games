# Mushroom Patch, flat: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a thirteenth flat board, Mushroom Patch, on the first screen: a meadow of covered cells over hidden mushrooms, numbers counting the eight cells around them, and a win that is the last mushroom planted.

**Architecture:** The pattern every flat board follows here: a scene-free state class over a seeded generator (`puzzles/mushroom_state.gd`, `puzzles/mushroom_gen.gd`), a `PuzzleBase` Control that draws the field as cached meshes with the mushrooms as nodes in slots (`puzzles/mushroom2d.gd`), Nonogram's tile tray taught a third chip set, a registry line, a card picture and the two harness branches. **Queens is the board to copy**: `puzzles/queens2d.gd` is the same shape — a square grid, two chips, a tap-or-sweep gesture, pieces in slots over a drawn ground, and one `_settle` that diffs a snapshot against the state. Every motion goes through `core/motion.gd`'s recipes and curve readers; the board's one signature is the count wash, two constants of its own.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer. Verification through throwaway probes and the windowed harnesses `tests/_win.gd`, `tests/_shot_anim.gd`, `tests/_shot_menu.gd`.

**Spec:** `docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md`. Concept page: `docs/brainstorm/concepts.html#mushroom` (built before this plan; where the mock and this plan disagree on a drawing number, **the mock wins** and the spec is amended in Task 9).

## Global Constraints

- Branch: `feat/mushroom-patch`, already checked out **in the worktree `/Users/flavioriper/dev/daily/.claude/worktrees/mushroom`**. Run every command from there. Two other agents are working in sibling worktrees on `feat/word-trail` and `feat/sudoku`; never touch those trees, and never `git stash` (the stack is shared).
- Commit after every task; **never push** — the user calls the push.
- Godot is `godot` on PATH. The worktree has already been `--import`ed.
- **No new test-suite entries.** The user's standing rule is that Daily is an MVP and test upkeep is not worth the turn: verify with throwaway probes under `/tmp` and with the windowed harnesses, and delete the probe when the task is done. If an existing suite breaks because a constant moved, make the smallest edit that unbreaks it. Confirm the suite still passes at the end of each task that touches shared code: `godot --headless --path . --script res://tests/run_tests.gd`.
- Windowed harnesses need a display and **must never overlap**: run one at a time, and take two readings when a number matters. A single reading off `_shot_anim.gd` is worth nothing (CLAUDE.md); quote every reading, including the flattering one.
- Godot re-saves `project.godot` with a header comment after a windowed run: `git checkout project.godot` before committing if it shows as modified.
- Never write an `instance uniform` in a shader. Never bake a drawing to an image. Faces are code (`ui/faces/`), drawn as cached meshes.
- **A canvas command holds a mesh by RID**: keep the mesh the last `_draw` handed over referenced (`_shown`) until the next one replaces it, or a harness's `force_draw()` renders a freed RID.
- A probe that pokes the board and shoots in the same frame photographs the state *before* the poke: `queue_redraw` flushes on the next idle frame. Let a frame pass.
- Only `world/main.gd` starts `Analytics` and `Backend`; harnesses and probes stay silent.
- **Copy, exactly:** the board is `Mushroom Patch`; the motto `Every patch has its count`; the footer `Count · Prove · Plant`; the blurb `Every number counts the mushrooms around it. Find them all.`; the card's `short` is `The numbers count\nwhat is hidden.`; the chips read `Mushroom` and `Pebble`; the win line is `Every patch has its count.`. Never call it Minesweeper or Campo Minado in code, in a comment or on screen.
- **Numbers from the spec:** `SIZES := [[6, 6], [7, 9], [8, 12]]` (n, mushrooms), `SUBSETS := [false, false, true]`, `GIVE_BACK := [0.45, 0.20, 0.0]`, `HINTS := 3`, `PAD` 34, `TALLY` 72, `WASH_TIME` 0.35, `WASH_LEVEL` 0.30, rose wash 0.34, bottom slot 460, `WIN_WAIT` 1.6.
- Comment style: every file opens with a `##` doc explaining what it is and why, in prose, naming the spec section. A constant carries a `##` line when the number is a decision.

---

## File structure

| File | Task | Responsibility |
|---|---|---|
| `puzzles/mushroom_gen.gd` (new) | 1 | Scatter, count, carve; the non-branching solver. Pure functions, seeded only by the `rng` handed in. |
| `puzzles/mushroom_state.gd` (new) | 2 | The rules with no scene: the givens, the marks, every move, undo, hint, check, solved. |
| `ui/flat/tile_tray.gd`, `ui/flat/flat_host.gd` | 3 | A third chip set, `PATCH`; `"tray": "patch"`. |
| `ui/flat/flat_top_bar.gd` | 4 | Fit a wordmark wider than the block it is given. |
| `puzzles/mushroom2d.gd` (new) | 5 | The board: the field, the numerals, the wash, the tally strip, the pieces, input, the sprout's lines, the win. |
| `ui/registry.gd`, `tests/_win.gd` | 5 | The thirteenth grid entry; the solve branch. |
| `tests/_shot_anim.gd` | 6 | The tap branch; the strip and the measurements. |
| `ui/menu/card_art.gd` | 7 | The card's picture. |
| `ui/menu.gd` | 8 | The pager. Its own commit; not this board's work. |
| `CLAUDE.md`, `docs/art/flat-motion.md`, the spec | 9 | The record. |

---

### Task 1: The generator and its solver

**Files:**
- Create: `puzzles/mushroom_gen.gd`
- Throwaway: `/tmp/_mushroom_probe.gd`, copied to `tools/` to run, then deleted.

**Interfaces:**
- Produces:
  - `MushroomGen.SIZES: Array` — `[[6, 6], [7, 9], [8, 12]]`, n and mushrooms per difficulty.
  - `MushroomGen.SUBSETS: Array` — `[false, false, true]`.
  - `MushroomGen.GIVE_BACK: Array` — `[0.45, 0.20, 0.0]`.
  - `MushroomGen.generate(rng: RandomNumberGenerator, n: int, k: int, subsets: bool, give_back: float) -> Dictionary` with keys `n: int`, `k: int`, `mushrooms: Dictionary` (`Vector2i -> true`), `given: Dictionary` (`Vector2i -> int`), `ok: bool`.
  - `MushroomGen.neighbours(cell: Vector2i, n: int) -> Array[Vector2i]` — the eight, clipped to the field.
  - `MushroomGen.solvable(given: Dictionary, n: int, k: int, subsets: bool) -> bool`.

- [ ] **Step 1: Write the generator**

Create `puzzles/mushroom_gen.gd`. Port the concept page's generator (`docs/brainstorm/concepts.html`, the `mp` IIFE, functions `neigh`, `solvable`, `generate`) number for number. The shape:

```gdscript
extends RefCounted

## Mushroom Patch's fields, generated backwards from a field that is entirely
## turned over.
##
## Scatter k mushrooms, count every bare cell's eight neighbours, then turn
## *every* bare cell over and walk them in a shuffled order trying to cover
## each one back up -- keeping the cover only while `solvable` still proves
## the whole field. What survives is a near-minimal set of givens, and the
## board is solvable by logic alone **by construction**: carving can only
## remove information from a field that started fully solved, so a board with
## a guess in it is never produced. `ok` is asserted rather than relied on.
##
## A minimal board is the hardest board, so easy and medium hand a share of
## the carved-away numbers back (GIVE_BACK), chosen at random so the givens
## stay scattered. That, the size and whether the solver may subtract subsets
## are the whole ladder: measured on the concept page over 200 seeds, 168 hard
## boards cannot be solved without subset subtraction and 0 medium ones need
## it.
##
## Seeded only by the `rng` handed in, so a day is the same patch on every
## phone. Spec: docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md,
## section 4.

## n and mushrooms per difficulty: easy, medium, hard.
const SIZES := [[6, 6], [7, 9], [8, 12]]
## Whether the solver may subtract subsets while carving -- the 1-2-1 pattern.
## Hard only, which is what makes hard a different kind of thinking and not
## just a bigger field.
const SUBSETS := [false, false, true]
## What share of the carved-away numbers is handed back.
const GIVE_BACK := [0.45, 0.20, 0.0]
const DIRS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]

static func neighbours(cell: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var p: Vector2i = cell + d
		if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
			out.append(p)
	return out
```

`solvable` runs to a fixpoint and **never branches**:

```gdscript
## Whether `given` decides every covered cell by logic alone. Two rule
## families, the global count, and -- when `subsets` -- subtraction between
## overlapping numbers. It never guesses and never backtracks: a field it
## cannot finish is a field with a guess in it.
static func solvable(given: Dictionary, n: int, k: int, subsets: bool) -> bool:
	var nb := {}                       # given cell -> its covered neighbours
	for g in given:
		var open: Array[Vector2i] = []
		for p in neighbours(g, n):
			if not given.has(p):
				open.append(p)
		nb[g] = open
	var unknown: Array[Vector2i] = []
	for y in n:
		for x in n:
			var c := Vector2i(x, y)
			if not given.has(c):
				unknown.append(c)
	var st := {}                       # covered cell -> true mushroom, false bare
	var mines := 0
	var left := unknown.size()
	var moved := true
	while moved and left > 0:
		moved = false
		var cons: Array = []            # [{"open": Array[Vector2i], "need": int}]
		for g in given:
			var open: Array[Vector2i] = []
			var have := 0
			for p in nb[g]:
				if st.has(p):
					have += 1 if st[p] else 0
				else:
					open.append(p)
			if open.is_empty():
				continue
			var need: int = int(given[g]) - have
			if need <= 0:
				for p in open:
					st[p] = false
					left -= 1
					moved = true
				continue
			if need >= open.size():
				for p in open:
					st[p] = true
					mines += 1
					left -= 1
					moved = true
				continue
			cons.append({"open": open, "need": need})
		if moved:
			continue
		# The global count. This is why the tally strip is on the screen: it
		# is a clue the carve leans on, not decoration.
		if mines == k or mines + left == k:
			var v := mines + left == k
			for p in unknown:
				if not st.has(p):
					st[p] = v
					if v:
						mines += 1
					left -= 1
					moved = true
			if moved:
				continue
		if not subsets:
			break
		for pair in _subtract(cons):
			var cell: Vector2i = pair[0]
			if st.has(cell):
				continue
			st[cell] = bool(pair[1])
			if pair[1]:
				mines += 1
			left -= 1
			moved = true
	return left == 0
```

`_subtract` only *reports*; the loop above owns the counters, so a cell can
never be written twice or counted twice:

```gdscript
## Where one number's covered cells sit inside another's, the cells outside
## carry the difference of their counts. The 1-2-1 every player of this game
## knows by feel; hard boards only.
static func _subtract(cons: Array) -> Array:
	var done: Array = []                # [[cell, is_mushroom], ...]
	for a in cons:
		for b in cons:
			if a == b or a.open.size() >= b.open.size():
				continue
			var inside := true
			for p in a.open:
				if not b.open.has(p):
					inside = false
					break
			if not inside:
				continue
			var rest: Array[Vector2i] = []
			for p in b.open:
				if not a.open.has(p):
					rest.append(p)
			var dv: int = int(b.need) - int(a.need)
			if dv <= 0:
				for p in rest:
					done.append([p, false])
			elif dv >= rest.size():
				for p in rest:
					done.append([p, true])
			if not done.is_empty():
				return done
	return done
```

`generate` is the carve:

```gdscript
static func generate(rng: RandomNumberGenerator, n: int, k: int,
		subsets: bool, give_back: float) -> Dictionary:
	var cells: Array[Vector2i] = []
	for y in n:
		for x in n:
			cells.append(Vector2i(x, y))
	_shuffle(cells, rng)
	var mushrooms := {}
	for i in k:
		mushrooms[cells[i]] = true
	var num := {}
	for c in cells:
		if mushrooms.has(c):
			continue
		var m := 0
		for p in neighbours(c, n):
			if mushrooms.has(p):
				m += 1
		num[c] = m
	var bare: Array[Vector2i] = num.keys()
	_shuffle(bare, rng)
	var given := num.duplicate()
	var dropped: Array[Vector2i] = []
	for g in bare:
		var v: int = given[g]
		given.erase(g)
		if solvable(given, n, k, subsets):
			dropped.append(g)
		else:
			given[g] = v
	_shuffle(dropped, rng)
	for i in int(round(dropped.size() * give_back)):
		given[dropped[i]] = num[dropped[i]]
	return {"n": n, "k": k, "mushrooms": mushrooms, "given": given,
		"ok": solvable(given, n, k, subsets)}
```

`_shuffle` is a Fisher–Yates over the array using `rng.randi_range`.

- [ ] **Step 2: Write the throwaway probe**

Create `/tmp/_mushroom_probe.gd`:

```gdscript
extends SceneTree

## Throwaway. Checks the three claims the spec makes about the generator:
## every board is proved, the givens land where the spec says, and hard
## boards need subset subtraction while medium ones do not.

const Gen = preload("res://puzzles/mushroom_gen.gd")

func _initialize() -> void:
	for d in 3:
		var step: Array = Gen.SIZES[d]
		var bad := 0
		var givens := 0
		var t0 := Time.get_ticks_msec()
		for sd in range(1, 121):
			var rng := RandomNumberGenerator.new()
			rng.seed = sd * 2654435761 + d * 40503 + 7
			var p: Dictionary = Gen.generate(rng, step[0], step[1],
				Gen.SUBSETS[d], Gen.GIVE_BACK[d])
			if not p.ok:
				bad += 1
			givens += p.given.size()
		print("d%d  %dx%d  %d mushrooms  givens avg %.1f  unproved %d/120  %.1f ms a board"
			% [d, step[0], step[0], step[1], givens / 120.0, bad,
				(Time.get_ticks_msec() - t0) / 120.0])
	var needs := 0
	var medium := 0
	for sd in range(1, 201):
		var r := RandomNumberGenerator.new()
		r.seed = sd * 2654435761 + 2 * 40503 + 7
		var h: Dictionary = Gen.generate(r, 8, 12, true, 0.0)
		if not Gen.solvable(h.given, 8, 12, false):
			needs += 1
		var r2 := RandomNumberGenerator.new()
		r2.seed = sd * 2654435761 + 1 * 40503 + 7
		var m: Dictionary = Gen.generate(r2, 7, 9, false, 0.20)
		if not Gen.solvable(m.given, 7, 9, false):
			medium += 1
	print("hard boards needing subset subtraction: %d/200 (browser: 168)" % needs)
	print("medium boards needing it: %d/200 (must be 0)" % medium)
	quit()
```

- [ ] **Step 3: Run the probe**

```bash
cp /tmp/_mushroom_probe.gd tools/_mushroom_probe.gd
godot --headless --path . --script tools/_mushroom_probe.gd
```

Expected: **0 unproved at every difficulty**, **0/200 medium** needing subsets, and hard in the neighbourhood of 168/200 (GDScript's shuffle is not the browser's, so the exact figure will differ; anything above 120 confirms the ladder). Under a tenth of a second a board on hard. If a board comes back unproved, the carve has a bug — the guarantee is structural and cannot legitimately fail.

- [ ] **Step 4: Delete the probe and commit**

```bash
rm tools/_mushroom_probe.gd tools/_mushroom_probe.gd.uid
git add puzzles/mushroom_gen.gd
git commit -m "feat(mushroom): the generator, carved backwards from a full field"
```

Record the probe's three lines in the commit body — they are the evidence for the spec's section 4.2.

---

### Task 2: The state

**Files:**
- Create: `puzzles/mushroom_state.gd`

**Interfaces:**
- Consumes: `MushroomGen.generate`, `MushroomGen.neighbours`, `MushroomGen.SIZES`, `SUBSETS`, `GIVE_BACK`.
- Produces:
  - Constants `BLANK := 0`, `FOUND := 1`, `CLEAR := 2`; `SHORT := 0`, `SETTLED := 1`, `OVER := 2`; `OK := 0`, `GIVEN := 1`, `PINNED := 2`, `COVERED := 3` (why a move was turned down).
  - `n: int`, `k: int`, `mushrooms: Dictionary`, `given: Dictionary`, `marks: Dictionary`, `pinned: Dictionary`.
  - `setup(rng: RandomNumberGenerator, difficulty: int) -> void`
  - `place(cell: Vector2i, v: int) -> int` — returns `OK` or a refusal reason.
  - `sweep(cells: Array[Vector2i], on: bool) -> Array[Vector2i]` — one history entry, returns the cells that changed.
  - `undo() -> Array[Vector2i]`
  - `reset_board() -> Array[Vector2i]`
  - `hint() -> Vector2i` — the cell planted, or `Vector2i(-1, -1)`.
  - `wrong_marks() -> Array[Vector2i]`
  - `standing(cell: Vector2i) -> int` — `SHORT`, `SETTLED` or `OVER` for a given.
  - `around(cell: Vector2i) -> int`, `left() -> int`, `is_solved() -> bool`, `share_glyphs() -> String`.

- [ ] **Step 1: Write the state**

Create `puzzles/mushroom_state.gd`. `puzzles/queens_state.gd` is the file to
read first; this is the same shape with a simpler board. The rules that must
be in the code and in its comments:

- `place` returns `GIVEN` and changes nothing when `given.has(cell)`, and
  `PINNED` when the cell is pinned and `v != FOUND`. A pebble aimed at a
  planted mushroom returns `COVERED` and changes nothing — **a pebble never
  lifts a mushroom**.
- `place(cell, FOUND)` on a cell already `FOUND` **pulls it up** (sets BLANK).
  `place(cell, CLEAR)` on a cell already `CLEAR` rubs it out.
- **A wrong mark is never refused.** The state knows the answer and must not
  use it to turn a move down: refusing would let a player tap every cell in
  turn and read the answer off what stuck. The only refusals are structural.
- `standing(cell)` is derived from `around(cell)` against `given[cell]` and is
  **never stored**. A given of nought is `SETTLED` from the start and the
  board draws it as bare (section 4.3); `standing` still returns `OVER` for it
  when a mushroom is planted beside it.
- `hint()` plants the next unfound mushroom **in reading order** (sort by
  `y` then `x`), pins it, rubs out a pebble there first, and **clears the
  history** — Shikaku's rule.
- `reset_board()` clears every mark that is not pinned and clears the history.
- `is_solved()` is an exact set match between the `FOUND` marks and
  `mushrooms`, not a count.
- `wrong_marks()` is every `FOUND` on a bare cell **and** every `CLEAR` on a
  mushroom. Check answers both.
- `share_glyphs()` is one row per line: a mushroom glyph for a planted cell, a
  pale square for a covered one, and the numeral's own square for a given.

- [ ] **Step 2: Verify by hand with a throwaway probe**

Create `/tmp/_mushroom_state_probe.gd` as a `SceneTree` script that builds a
medium board from a fixed seed and asserts, printing a line each:

```gdscript
# 1. A fresh board is not solved and has k mushrooms to find.
# 2. Planting every mushroom in `mushrooms` and nothing else solves it.
# 3. Planting k mushrooms of which one is wrong does NOT solve it,
#    and wrong_marks() names exactly that one.
# 4. place() on a given returns GIVEN and leaves marks unchanged.
# 5. A pebble on a planted mushroom returns COVERED and leaves it planted.
# 6. A sweep of five covered cells is ONE undo.
# 7. hint() plants a real mushroom, pins it, and reset_board() keeps it.
# 8. standing() of a given with all its mushroom neighbours planted is
#    SETTLED; one more beside it is OVER.
```

Run it the same way as Task 1's probe, confirm every line passes, then delete
it.

- [ ] **Step 3: Commit**

```bash
git add puzzles/mushroom_state.gd
git commit -m "feat(mushroom): the rules, scene-free"
```

---

### Task 3: The tray's third chip set

**Files:**
- Modify: `ui/flat/tile_tray.gd` — the header doc, the preloads, the sets, and the glyph branch.
- Modify: `ui/flat/flat_host.gd:171-200` — the `match` on `"tray"`.

**Interfaces:**
- Consumes: `MushroomState.FOUND`, `MushroomState.CLEAR`.
- Produces: `TileTray.PATCH`; `"tray": "patch"` builds `TileTray.new(TileTray.PATCH)`.

- [ ] **Step 1: Add the set**

In `ui/flat/tile_tray.gd`, beside `MOSAIC` and `QUEENS`:

```gdscript
const MushroomState = preload("res://puzzles/mushroom_state.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")

const PATCH := {
	"values": [MushroomState.FOUND, MushroomState.CLEAR],
	"labels": ["Mushroom", "Pebble"],
	"names": ["MushroomChip", "PebbleChip"],
	"glyphs": ["mushroom", "pebble"],
}
```

Extend the glyph branch that seats a `BeeFace` for `"bee"` to seat a
`MushroomFace` for `"mushroom"`, at the same `GLYPH` size and `GLYPH_X`,
`GLYPH_Y` seat. Update the file's header doc: it is **three** sets now, and
name the spec section (`2026-09-20-mushroom-patch-flat-design.md`, section 7).

- [ ] **Step 2: Wire the host**

In `ui/flat/flat_host.gd`'s `match`, beside `"queens"`:

```gdscript
	"patch":
		# Mushroom Patch's pair: the same tray again, with the patch set.
		tray = TileTray.new(TileTray.PATCH)
		tray.pick.connect(_on_brush)
```

Update the host's header doc, which lists the tray names, to include
`"patch"`.

- [ ] **Step 3: Check nothing else moved**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
```

Expected: the same check count as before the task, **0 failures**. The tray is
shared with Nonogram and Queens; a regression here shows up there.

- [ ] **Step 4: Commit**

```bash
git add ui/flat/tile_tray.gd ui/flat/flat_host.gd
git commit -m "feat(mushroom): the tile tray takes a third chip set"
```

---

### Task 4: The top bar fits a long wordmark

**Files:**
- Modify: `ui/flat/flat_top_bar.gd`

**Interfaces:**
- Produces: nothing new to callers; the bar shrinks its own title when it is too wide.

Why: measured on 2026-09-20 in Fredoka 700 at the `GameWordmark` size of 84,
`Mushroom Patch` is **635** wide against a block of
`1000 − 110 − 3 × 110 − 4 × 16` = **496**. `Hidden Word` at 482 is the longest
that fits today, and it fits by fourteen pixels. Spec section 5.1.

- [ ] **Step 1: Add the fit**

Add a constant and apply it where `_title` is built:

```gdscript
## The width the title's block gets: the row less the back button, the three
## icon buttons and the four separations. A title wider than this is shrunk
## to fit rather than clipped -- Mushroom Patch measures 635 in Fredoka 700 at
## the theme's 84 (2026-09-20), where Hidden Word's 482 is the longest that
## fits as it stands.
const BLOCK := 496.0
## No title shrinks below this; past it the name is too long for the screen
## and the answer is a shorter name.
const TITLE_MIN := 56
```

After setting `_title.text`, measure with the theme's own font and override
the size only when it does not fit. Take the font from the label
(`_title.get_theme_font("font")`) and the size from
`_title.get_theme_font_size("font_size")` so the bar never hard-codes 84, and
guard against a null font in a harness that builds the bar without the theme.

A board whose title fits must come out **byte-identical**: check that the
override is not applied at all when the measured width is under `BLOCK`.

- [ ] **Step 2: Verify against the eleven titles**

Throwaway probe under `/tmp` that instantiates the bar for each shipping title
and prints the size it chose:

Expected: 84 for every existing board (`Binairo` 268, `Queens` 287,
`Nonogram` 390, `Code Break` 430, `Hidden Word` 482), and **65** for
`Mushroom Patch`. Delete the probe.

- [ ] **Step 3: Check the suite and commit**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
git add ui/flat/flat_top_bar.gd
git commit -m "feat(mushroom): the flat top bar fits a wordmark too wide for its block"
```

---

### Task 5: The board, on the grid and under the win harness

**Files:**
- Create: `puzzles/mushroom2d.gd`
- Modify: `ui/registry.gd` — the thirteenth `PUZZLES` entry and the header doc.
- Modify: `tests/_win.gd:72-116` — the `_note` and `_solve` branches.

**Interfaces:**
- Consumes: `MushroomState`, `TileTray.PATCH`, `PuzzleBase`, `core/motion.gd`, `ui/flat/scenery.gd`, `ui/faces/mushroom_face.gd`, `ui/faces/mosaic_tile.gd`.
- Produces: `MushroomBoard.cell_centre(cell: Vector2i) -> Vector2` (the win harness taps these), `n: int`, `state: MushroomState`.

**Read `puzzles/queens2d.gd` before writing a line of this.** It is the same
board with different rules: a square grid, two chips, tap-or-sweep, pieces in
slots over a drawn ground, and one `_settle` that diffs a snapshot against the
state and hands each changed cell its moment. Copy its structure; do not copy
its constants.

- [ ] **Step 1: Write the board**

The shape, in the order `queens2d.gd` has it:

1. **Header doc.** What the board is, that the rules live in
   `mushroom_state.gd`, that the count wash is its signature and why the wash
   is honest (spec section 8), how it is drawn, and the spec and concept page
   paths.
2. **Constants.** `PAD := 34.0`, `TALLY := 72.0`, `WASH_TIME := 0.35`,
   `WASH_LEVEL := 0.30`, `WASH_OVER := 0.34`, `HINTS := 3`, `WIN_WAIT := 1.6`,
   the piece fractions of a cell (the mushroom at 0.33, the pebble at 0.26,
   the numeral at 0.52), the ring and shiver sizes. Each with a `##` line.
3. **Two cached meshes**, rebuilt only while something moves, both kept in
   `_shown` until the next `_draw` replaces them:
   - **the floor**: the cell backs (covered `Pal.TURF_REACH`, given
     `Pal.SURFACE`, pebbled `Pal.SOCKET_OUT`, planted `Pal.MUSHROOM_TILE`),
     each shaded toward the ink while the finger holds it, and the wash laid
     over a given's back (`Pal.LEAF` at `WASH_LEVEL`, `Pal.BAD` at
     `WASH_OVER`). Built about the field's centre so the entrance pop is one
     transform.
   - **the ground**: the blushes, the soft discs under the mushrooms
     (`Scenery.soft_disc`), and the pebbles.
4. **The numerals are drawn text**, one `draw_set_transform` a cell, so they
   pop in, bump and take the wash's ink off `Motion`'s readers — Nonogram's
   clue numbers are the precedent. **A given of nought draws no numeral.**
5. **The mushrooms are nodes in slots** (`ui/faces/mushroom_face.gd`), one
   slot each, made the first time a cell is planted and kept afterwards; a
   cell tapped twice must not build and free a node with a mesh cache behind
   it on every tap. A pinned mushroom wears a leaf sprig.
6. **The tally strip**, `TALLY` tall inside the card over the field: a small
   mushroom and the line from spec section 11 (`four mushrooms still hidden`
   / `every mushroom is planted` / `two too many planted` in rose).
7. **`_settle`**, the one place a move becomes motion: snapshot the field,
   apply the state's move, diff, and hand each changed cell its moment with a
   `Callable` saying when — a sweep's path, Reset's far corner, a plant's own
   instant. **Every given whose `standing()` changed bumps and takes its
   wash**, and that is the wash's only entry point.
8. **Input**: touch and drag, as every flat board takes them. A tap with the
   mushroom chip plants or pulls up; a tap with the pebble chip lays or rubs
   out; a drag with the pebble chip sweeps, the stroke's job read off its
   first cell, filling in the cells between two samples so a fast finger
   leaves no holes, painting each cell once, and passing over givens and
   planted mushrooms alike. **No line lock.** The mushroom chip does not
   sweep.
9. **The `PuzzleBase` overrides**: `puzzle_id()` is `"mushroom"`, `title()`,
   `rules()`, `build()`, `is_solved()`, `capabilities()` returns
   `["undo", "hint", "check"]`, `can_undo()`, `undo()`, `hints_left()`,
   `hint()`, `check()`, `reset_board()`, `share_glyphs()`. **Analytics needs
   nothing new**: `ui/puzzle_host.gd` sends `puzzle_start`,
   `puzzle_complete` (with `solved: true` — this board cannot end unsolved,
   only Hidden Word can), `hint_used`, `undo_used`, `check_used`,
   `board_reset` and `rules_opened` off these overrides and `puzzle_id()`
   alone, so getting `puzzle_id()` right is the whole of section 12.
10. **The flat chrome's optional asks**: `tip_line()`, `flat_win()` (one
    mushroom in `JOY`), `card_height(available)` and `card_centred()` → true.
    `card_height` must account for `TALLY`: the cell is
    `min((width − 2 * PAD) / n, (available − 2 * PAD − TALLY) / n)`.
11. **`cell_centre(cell)`** — Control-local, for the win harness.

- [ ] **Step 2: Add the registry entry**

Append to `Registry.PUZZLES`, **after** `hiddenword` and **before** the
`pipes` `soon` entry, the block from spec section 2 verbatim. Update the
registry's header doc: the grid is thirteen now, and the pager (Task 8) is
what holds it.

- [ ] **Step 3: Add the win-harness branches**

In `tests/_win.gd`, beside the `"queens"` branches:

```gdscript
		"mushroom": return "%dx%d patch, %d mushrooms, board fit=%s, hud=%s" % [
			_puzzle.n, _puzzle.n, _puzzle.state.mushrooms.size(), _fit_ok, _hud_ok]
```

and a `_solve_mushroom()` that arms the mushroom chip (the tray's default) and
taps `cell_centre` on every cell of `state.mushrooms` in reading order, one
real touch each, the way `_solve_queens` does.

- [ ] **Step 4: Run the win harness**

```bash
godot --path . --script res://tests/_win.gd -- mushroom
```

It needs a display — run it **windowed**, never headless (headless silently
reports 0/0). Expected: **10/10**, and `board fit=true, hud=true` on each.

- [ ] **Step 5: Check the suite, restore project.godot, commit**

```bash
godot --headless --path . --script res://tests/run_tests.gd 2>&1 | tail -3
git checkout project.godot 2>/dev/null
git add puzzles/mushroom2d.gd ui/registry.gd tests/_win.gd
git commit -m "feat(mushroom): the board, the thirteenth card, and the win harness"
```

---

### Task 6: The animation strip and the numbers

**Files:**
- Modify: `tests/_shot_anim.gd:160-175` and a new `_tap_mushroom()` beside `_tap_queens()`.

- [ ] **Step 1: Add the branch**

```gdscript
		elif _entry.id == "mushroom" and not _empty:
			_tap_mushroom()
```

`_tap_mushroom()` plants the answer's first mushroom with one real touch,
using the mushroom chip the tray arms by default, so the strip catches the
pop, the ring, the puff **and the wash arriving on the numbers around it** —
which is the moment the whole board is for.

- [ ] **Step 2: Shoot the strip, twice**

```bash
godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- mushroom
```

**`--resolution` is a Godot engine flag and must come BEFORE `--script`.** After a
`--` it is handed to the script as a user argument and silently ignored, and the
run then happens at the default window — which is exactly the 1237-wide canvas
this rule exists to avoid. **`810x1440` and never `1080x1920`** — this Mac's display cannot show 1920
rows, and the old flag comes back 1237 wide, 15% wider than the phone
(CLAUDE.md). Run it **twice, sequentially, never overlapping another harness**,
and take a control reading of an existing board (`queens`) in the same session:
a single reading off this harness is worth nothing, and this machine's spread
has been measured at a factor of 1.6 on an unchanged board.

- [ ] **Step 3: Record every reading**

Write the draw-call counts and the idle millisecond figures into the spec as a
new section 14, **quoting every run including the flattering one**, with the
Queens control beside them and the date. If the count is above the 855 budget,
stop and say so rather than rounding it away.

- [ ] **Step 4: Commit**

```bash
git checkout project.godot 2>/dev/null
git add tests/_shot_anim.gd docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md
git commit -m "feat(mushroom): the animation strip, and what the board measures"
```

---

### Task 7: The menu card's picture

**Files:**
- Modify: `ui/menu/card_art.gd` — one `_build` branch and, for the turf strip, one `_draw` branch.

- [ ] **Step 1: Draw the card**

Mushroom Patch's picture, in the 320 × 118 box: **two mushrooms on a turf
strip beside a cream tile carrying a number**, all of it reuse —
`ui/faces/mushroom_face.gd` for the pair and the board's own cell colours for
the tile. Follow the branch Queens added (six cells of the court under the
crown) for the seat and scale conventions.

**It is never an image and never a `SubViewport`** (CLAUDE.md).

- [ ] **Step 2: Shoot the menu, twice**

```bash
godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd
```

Expected: the thirteenth card drawn on page one or two depending on whether
Task 8 has landed. Note the draw-call count against the 311 recorded for the
twelve-card screen and the 855 budget, two readings.

- [ ] **Step 3: Commit**

```bash
git checkout project.godot 2>/dev/null
git add ui/menu/card_art.gd
git commit -m "feat(mushroom): the card's picture"
```

---

### Task 8: The pager

**Files:**
- Modify: `ui/menu.gd` — `_build_list`, `_enter`, and a new page row.

**This task is not Mushroom Patch's work.** It is the first screen's, and it
serves all three boards in flight. It is a separate commit so it can be
cherry-picked by whichever branch lands first, and so a reviewer can reject it
without rejecting the board.

- [ ] **Step 1: Page the grid**

Twelve cards a page (`PER_PAGE := COLS * 4`), a row under the grid with a prev
button, a dot per page and a next button. The row takes **no height from the
cards**: the card must stay **252** and the picture **92**. Put the row where
the toast already sits — laid over the bottom bar rather than given a row of
the column — or, if that reads badly, take its height from the 20 of gap
between the grid and the bar and say in the comment which pixels paid for it.

The campsite menu's pager (`legacy/ui/camp_menu.gd`) is the precedent for the
buttons and the wording; it turned pages of nine.

- [ ] **Step 2: Keep the entrance honest**

`_enter()` staggers a wave down the cards. Stagger only the cards **on the
current page**, and replay the wave when the page turns.

- [ ] **Step 3: Shoot both pages**

```bash
godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd
```

Confirm by measurement, not by eye, that a card is still **252** tall and its
picture **92**. Record the draw-call count for each page against the 311 of
the single twelve-card screen.

- [ ] **Step 4: Commit**

```bash
git checkout project.godot 2>/dev/null
git add ui/menu.gd
git commit -m "feat(menu): the grid pages again, twelve cards at a time"
```

---

### Task 9: The record

**Files:**
- Modify: `CLAUDE.md` — "The flat screens", "The first screen", the registry's two lists, the bottom-slot list.
- Modify: `docs/art/flat-motion.md` — Mushroom Patch on the vocabulary, and what it is the precedent for.
- Modify: `docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md` — a final "Amendments from the build" section.

- [ ] **Step 1: CLAUDE.md**

- "The flat screens" opens *Eleven cards open a flat 2D board*: it is thirteen
  now (twelve with Word Trail, thirteen with this) — **read the file as it
  stands when the task runs**, because two other branches are editing the same
  paragraphs, and change only this board's share of it.
- Add Mushroom Patch to the spec and mock lists.
- Add its bottom slot to the list of numbers (`460`).
- Add `"patch"` to the tray names.
- Under "The first screen", record the pager and why the five-row grid was
  refused, with the 252 and 92 figures.
- Record the wordmark fit and the 496 block.

- [ ] **Step 2: `docs/art/flat-motion.md`**

Mushroom Patch is **the precedent for a board whose feedback is derived from
public information**: the count wash is a running signal, unlike every other
board's, and it is legitimate because it reads only the numbers already
printed and the pieces the player placed. Say that plainly, and say the two
constants it added are its own and are not for anyone else.

- [ ] **Step 3: Spec amendments**

Every place the build disagreed with the spec, with the reason. If the mock
and the spec disagreed on a drawing number, the mock won and the spec says so.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/art/flat-motion.md docs/superpowers/specs/2026-09-20-mushroom-patch-flat-design.md
git commit -m "docs(mushroom): the thirteenth flat board on the record"
```

---

## Done when

- `godot --path . --script res://tests/_win.gd -- mushroom` is **10/10**, run windowed.
- `godot --headless --path . --script res://tests/run_tests.gd` reports the
  same check count as `main` and **0 failures**.
- The strip and the menu have been shot at `810x1440`, **twice each**, with a
  control board measured in the same session, and every reading is written
  down in the spec.
- The card opens from the first screen, plays, refuses a given, sweeps
  pebbles, hints, checks, resets, and wins.
- Nothing in the source, the UI or a comment says Minesweeper or Campo Minado.
- `git log --oneline main..HEAD` reads as nine commits that each make sense
  alone.
