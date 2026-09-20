# Word Trail Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Word Trail as the twelfth card on the first screen: a flat board where the player drags orthogonal trails through a field of letters, every open tile belonging to exactly one hidden word whose length is the only clue.

**Architecture:** The rules live in a scene-free `puzzles/word_trail_state.gd` (generator + moves + derived queries); `puzzles/word_trail2d.gd` draws them on the flat host's card, everything drawn rather than noded, reading the flat boards' motion vocabulary as curves off `core/motion.gd`. The registry gives it `"shell": "flat"`, `"tray": "none"`, `"actions": false`, taking the slot Pipes' `soon` card holds.

**Tech Stack:** Godot 4.7, GDScript, gl_compatibility renderer. No new autoloads, no new shaders, no new palette entries, no new characters in `ui/faces/`.

**Spec:** `docs/superpowers/specs/2026-09-20-word-trail-flat-design.md`

**Reference implementation:** `docs/brainstorm/concepts.html#wordtrail` — the concept tab plays the real generator, the real lock rule and the real motion. Its JS block (search `/* ---------- the flat word trail mock ---------- */`) is the closest thing to pseudocode for tasks 2 and 3; where this plan and that mock disagree, the plan wins.

## Global Constraints

- **Never call it Wend**, in code, in a comment or on screen. The board is **Word Trail**, id `wordtrail`. (Same rule as Wordle/Hidden Word and Mastermind/Code Break.)
- **Only a right word locks.** Any other release unwinds silently: no toast, no shiver, no penalty, no hint or move spent.
- **A trail must run along that word's own cells, in order.** Spelling the word over other tiles is not that word.
- **No new colour.** The six word colours are `Pal.LEAF/SUN/MOON_INK/BERRY/ACORN/FLOWER` with their `*_TILE` and `*_DEEP` partners, already in `core/palette.gd`.
- **No new character.** Tiles are `ui/faces/mosaic_tile.gd`; the only face is the shared sprout.
- **Nothing new in `core/motion.gd`.** The board reads existing curve readers; its own two constants (`WAVE_STEP` 0.05, `BEAM_TIME` 0.18) stay in the board.
- **The ribbon draws over the tile faces, under the letters.** A tile is opaque.
- Run the suite with `godot --headless --path . --script tests/run_tests.gd`; it must end `0` failures.
- Render harnesses run at `--resolution 810x1440`, never `1080x1920` (see CLAUDE.md, "What the harnesses actually measure"), and never two at once.

---

### Task 1: The state class and its suite

**Files:**
- Create: `puzzles/word_trail_state.gd`
- Create: `tests/test_word_trail.gd`
- Modify: `tests/run_tests.gd` (add the suite to the `suites` dictionary, after `"hidden_word"`)

**Interfaces:**
- Consumes: `content/word_trail.json` (already committed): `{"note": String, "words": {"3": [...], ..., "8": [...]}}`.
- Produces, and tasks 2-4 call exactly these:

```gdscript
const WORDS_PATH := "res://content/word_trail.json"

var n: int                        # 5, 6 or 7
var words: Array[Dictionary]      # {"word": String, "path": Array[Vector2i], "found": bool}, shortest first
var letters: Dictionary           # Vector2i -> String, one upper-case letter
var walls: Array[Vector2i]
var order: Array[int]             # indices of found words, in lock order
var given: Dictionary             # word index -> how many of its tiles a hint has lit

static func lens_for(difficulty: int) -> Array          # [3,4,5,6] / [3,4,4,5,6,7] / [4,5,6,7,8,8]
func build(rng: RandomNumberGenerator, difficulty: int) -> void
func is_wall(cell: Vector2i) -> bool
func word_at(cell: Vector2i) -> int                      # owning word index, -1 for a wall
func is_locked(cell: Vector2i) -> bool                   # owned by a found word
func can_trace(cell: Vector2i) -> bool                   # in the grid, not a wall, not locked
func trace(path: Array) -> int                           # index locked, or -1
func undo() -> bool
func reset_board() -> void
func hint() -> bool
func hint_shown(index: int) -> int                       # how many of word `index`'s tiles are lit
func is_solved() -> bool
func found_count() -> int
```

- [ ] **Step 1: Write the failing suite**

Create `tests/test_word_trail.gd`:

```gdscript
extends RefCounted

## Word Trail's rules (puzzles/word_trail_state.gd): the generator's
## guarantees, the lock rule and its two refusals, undo, reset and the hint.

const State = preload("res://puzzles/word_trail_state.gd")

static func run(t) -> void:
	_test_generator(t)
	_test_repeatable(t)
	_test_trace(t)
	_test_undo_reset(t)
	_test_hint(t)

static func _built(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.build(rng, difficulty)
	return st

## Everything the generator promises, over enough seeds that a rare layout
## cannot hide: the field is covered exactly once, the walls are what is
## left, every path is a self-avoiding orthogonal walk, and the quality rules
## in the spec's section 4 hold.
static func _test_generator(t) -> void:
	for difficulty in 3:
		var lens: Array = State.lens_for(difficulty)
		var tiles := 0
		for l in lens:
			tiles += int(l)
		for s in range(1, 31):
			var st := _built(s, difficulty)
			t.eq(st.n, 5 + difficulty, "grid size for band %d" % difficulty)
			t.eq(st.words.size(), lens.size(), "word count, seed %d band %d" % [s, difficulty])
			t.eq(st.letters.size(), tiles, "covered tiles, seed %d band %d" % [s, difficulty])
			t.eq(st.walls.size(), st.n * st.n - tiles, "wall count, seed %d band %d" % [s, difficulty])
			var seen := {}
			var got_lens: Array = []
			for w in st.words:
				var path: Array = w["path"]
				got_lens.append(path.size())
				t.eq(path.size(), (w["word"] as String).length(), "word fits its path, seed %d" % s)
				var bends := 0
				for i in path.size():
					var cell: Vector2i = path[i]
					t.check(cell.x >= 0 and cell.y >= 0 and cell.x < st.n and cell.y < st.n, "cell in grid")
					t.check(not seen.has(cell), "no tile in two words, seed %d" % s)
					seen[cell] = true
					t.eq(st.letters[cell], (w["word"] as String).substr(i, 1).to_upper(), "letter written along the path")
					if i > 0:
						var d: Vector2i = path[i] - path[i - 1]
						t.eq(abs(d.x) + abs(d.y), 1, "step is orthogonal and one cell, seed %d" % s)
					if i > 1 and path[i] - path[i - 1] != path[i - 1] - path[i - 2]:
						bends += 1
				if path.size() >= 5:
					t.check(bends >= 1, "a word of five or more bends, seed %d" % s)
			got_lens.sort()
			var want: Array = lens.duplicate()
			want.sort()
			t.eq(str(got_lens), str(want), "the band's lengths, seed %d" % s)
			t.check(_one_field(st), "the open cells are one connected field, seed %d" % s)
			t.check(not _full_wall_line(st), "no row or column is wall end to end, seed %d" % s)

static func _one_field(st) -> bool:
	var open_cells := {}
	for cell in st.letters:
		open_cells[cell] = true
	if open_cells.is_empty():
		return false
	var first: Vector2i = open_cells.keys()[0]
	var seen := {first: true}
	var stack: Array = [first]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var k: Vector2i = c + d
			if open_cells.has(k) and not seen.has(k):
				seen[k] = true
				stack.append(k)
	return seen.size() == open_cells.size()

static func _full_wall_line(st) -> bool:
	for i in st.n:
		var row := true
		var col := true
		for j in st.n:
			if st.letters.has(Vector2i(j, i)):
				row = false
			if st.letters.has(Vector2i(i, j)):
				col = false
		if row or col:
			return true
	return false

## A seed is a day: the same seed hands out the same board on every phone.
static func _test_repeatable(t) -> void:
	var a := _built(4242, 2)
	var b := _built(4242, 2)
	t.eq(str(a.letters), str(b.letters), "the same seed writes the same letters")
	for i in a.words.size():
		t.eq(a.words[i]["word"], b.words[i]["word"], "the same seed picks the same words")
		t.eq(str(a.words[i]["path"]), str(b.words[i]["path"]), "the same seed lays the same paths")
	var c := _built(4243, 2)
	t.check(str(a.letters) != str(c.letters), "a different seed is a different board")

## The lock rule, and the two things it refuses.
static func _test_trace(t) -> void:
	var st := _built(7, 0)
	var w0: Dictionary = st.words[0]
	var path: Array = (w0["path"] as Array).duplicate()

	t.eq(st.trace([]), -1, "an empty trail locks nothing")
	t.eq(st.trace([path[0]]), -1, "one tile locks nothing")

	# Backwards spells the word backwards, so it is not the word.
	var back: Array = path.duplicate()
	back.reverse()
	if (w0["word"] as String) != (w0["word"] as String).reverse():
		t.eq(st.trace(back), -1, "a trail traced backwards does not lock")
		t.check(not st.words[0]["found"], "and nothing was marked found")

	# A prefix is not the word either.
	t.eq(st.trace(path.slice(0, path.size() - 1)), -1, "a prefix does not lock")

	t.eq(st.trace(path), 0, "its own cells, in order, lock the word")
	t.check(st.words[0]["found"], "the word is found")
	t.eq(st.found_count(), 1, "one word found")
	t.eq(st.trace(path), -1, "a found word does not lock twice")
	t.check(st.is_locked(path[0]), "its tiles are locked")
	t.check(not st.can_trace(path[0]), "and cannot be traced through again")
	t.check(not st.is_solved(), "one word is not the board")

	for i in range(1, st.words.size()):
		t.eq(st.trace(st.words[i]["path"]), i, "word %d locks" % i)
	t.check(st.is_solved(), "every word found is solved")

## Undo lifts the last word in lock order; reset lifts them all and keeps
## what a hint gave.
static func _test_undo_reset(t) -> void:
	var st := _built(11, 1)
	t.check(not st.undo(), "nothing to undo on a fresh board")
	st.trace(st.words[0]["path"])
	st.trace(st.words[1]["path"])
	st.hint()
	var lit: int = st.hint_shown(2)
	t.check(st.undo(), "undo lifts a word")
	t.check(st.words[0]["found"], "the first is still found")
	t.check(not st.words[1]["found"], "the last is not")
	t.eq(st.found_count(), 1, "one left")
	st.trace(st.words[1]["path"])
	st.reset_board()
	t.eq(st.found_count(), 0, "reset lifts them all")
	t.eq(st.hint_shown(2), lit, "reset keeps what a hint gave")
	t.check(not st.undo(), "and leaves nothing to undo")

## The hint lights the next tile of the shortest unfound word.
static func _test_hint(t) -> void:
	var st := _built(19, 0)
	t.check(st.hint(), "the first hint lands")
	t.eq(st.hint_shown(0), 1, "on the shortest word's first tile")
	t.check(st.hint(), "the second hint lands")
	t.eq(st.hint_shown(0), 2, "on the same word's second tile")
	st.trace(st.words[0]["path"])
	t.check(st.hint(), "the third hint lands")
	t.eq(st.hint_shown(0), 2, "not on a found word")
	t.eq(st.hint_shown(1), 1, "on the next shortest instead")
```

- [ ] **Step 2: Register the suite**

In `tests/run_tests.gd`, add to the `suites` dictionary after the `"hidden_word"` line:

```gdscript
		"word_trail": "res://tests/test_word_trail.gd",
```

- [ ] **Step 3: Run it and watch it fail**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -20`
Expected: the `word_trail` suite errors because `puzzles/word_trail_state.gd` does not exist.

- [ ] **Step 4: Write the state class**

Create `puzzles/word_trail_state.gd`:

```gdscript
extends RefCounted

## Word Trail's rules, scene-free, as every flat board's are: the generator,
## the letters it writes, the walls it leaves, and the four moves. The board
## (puzzles/word_trail2d.gd) only draws this.
##
## The generator works backwards, and it can because **a path's shape puts no
## constraint on its letters**: any five-letter word fits any five-cell path,
## so there is no packing search and no solver. Grow the paths first, longest
## first, and every cell no path covered becomes a wall.
## Spec: docs/superpowers/specs/2026-09-20-word-trail-flat-design.md.

const WORDS_PATH := "res://content/word_trail.json"

## The bands. A wall is whatever the words do not cover, so the wall count is
## a property of the band and never a dial: 7, 7 and 11. One word per length
## would leave 16 walls on the 7x7, a third of the field, so the two larger
## bands repeat a length instead. Six words at most, which is what the
## palette's six chip colours cover.
const BANDS := [[3, 4, 5, 6], [3, 4, 4, 5, 6, 7], [4, 5, 6, 7, 8, 8]]
const ATTEMPTS := 60
const RESTARTS := 120

static var _words_cache: Dictionary = {}

var n: int = 5
var words: Array[Dictionary] = []
var letters: Dictionary = {}
var walls: Array[Vector2i] = []
var order: Array[int] = []
var given: Dictionary = {}

static func lens_for(difficulty: int) -> Array:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## The shipping list, bucketed by length and read once.
static func word_bank() -> Dictionary:
	if not _words_cache.is_empty():
		return _words_cache
	var f := FileAccess.open(WORDS_PATH, FileAccess.READ)
	if f == null:
		push_error("word_trail: cannot open " + WORDS_PATH)
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("words"):
		push_error("word_trail: " + WORDS_PATH + " has no words")
		return {}
	_words_cache = parsed["words"]
	return _words_cache

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var lens: Array = lens_for(difficulty)
	n = 5 + clampi(difficulty, 0, 2)
	var best: Array = []
	var best_score := 1 << 30
	var loose: Array = []
	for attempt in ATTEMPTS:
		var paths := _grow(rng, lens)
		if paths.is_empty():
			continue
		if loose.is_empty():
			loose = paths
		if _has_straight_long(paths):
			continue
		if not _one_field(paths):
			continue
		# A wholly walled row or column is not carving, it is a smaller grid
		# with a dead strip drawn on it -- and the wall-block score below
		# walks straight into one if it is allowed to.
		if _full_wall_line(paths):
			continue
		var score := 10 * _wall_blocks(paths) - _total_bends(paths)
		if score < best_score:
			best_score = score
			best = paths
	if best.is_empty():
		best = loose
	_write(rng, best)

## Longest first: a random free start, then a self-avoiding walk through free
## neighbours, restarting that word if it paints itself into a corner.
func _grow(rng: RandomNumberGenerator, lens: Array) -> Array:
	var used := {}
	var out: Array = []
	var order_lens: Array = lens.duplicate()
	order_lens.sort()
	order_lens.reverse()
	for want in order_lens:
		var got: Array = []
		for tries in RESTARTS:
			var start := Vector2i(rng.randi_range(0, n - 1), rng.randi_range(0, n - 1))
			if used.has(start):
				continue
			var path: Array = [start]
			used[start] = true
			while path.size() < want:
				var here: Vector2i = path[path.size() - 1]
				var opts: Array = []
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var k: Vector2i = here + d
					if k.x < 0 or k.y < 0 or k.x >= n or k.y >= n or used.has(k):
						continue
					opts.append(k)
				if opts.is_empty():
					break
				var pick: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
				path.append(pick)
				used[pick] = true
			if path.size() == want:
				got = path
				break
			for c in path:
				used.erase(c)
		if got.is_empty():
			return []
		out.append(got)
	return out

func _write(rng: RandomNumberGenerator, paths: Array) -> void:
	var bank := word_bank()
	var built: Array[Dictionary] = []
	for path in paths:
		var bucket: Array = bank.get(str(path.size()), [])
		var word: String = "?".repeat(path.size())
		if not bucket.is_empty():
			word = str(bucket[rng.randi_range(0, bucket.size() - 1)])
		built.append({"word": word.to_upper(), "path": path, "found": false})
	built.sort_custom(func(a, b): return (a["path"] as Array).size() < (b["path"] as Array).size())
	words = built
	letters = {}
	for w in words:
		var path: Array = w["path"]
		for i in path.size():
			letters[path[i]] = (w["word"] as String).substr(i, 1)
	walls = []
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if not letters.has(cell):
				walls.append(cell)
	order = []
	given = {}

# --- the quality rules (spec section 4) ---
func _total_bends(paths: Array) -> int:
	var total := 0
	for path in paths:
		total += _bends(path)
	return total

func _bends(path: Array) -> int:
	var count := 0
	for i in range(2, path.size()):
		if path[i] - path[i - 1] != path[i - 1] - path[i - 2]:
			count += 1
	return count

func _has_straight_long(paths: Array) -> bool:
	for path in paths:
		if path.size() >= 5 and _bends(path) == 0:
			return true
	return false

func _open_set(paths: Array) -> Dictionary:
	var open_cells := {}
	for path in paths:
		for c in path:
			open_cells[c] = true
	return open_cells

func _one_field(paths: Array) -> bool:
	var open_cells := _open_set(paths)
	if open_cells.is_empty():
		return false
	var first: Vector2i = open_cells.keys()[0]
	var seen := {first: true}
	var stack: Array = [first]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var k: Vector2i = c + d
			if open_cells.has(k) and not seen.has(k):
				seen[k] = true
				stack.append(k)
	return seen.size() == open_cells.size()

func _full_wall_line(paths: Array) -> bool:
	var open_cells := _open_set(paths)
	for i in n:
		var row := true
		var col := true
		for j in n:
			if open_cells.has(Vector2i(j, i)):
				row = false
			if open_cells.has(Vector2i(i, j)):
				col = false
		if row or col:
			return true
	return false

func _wall_blocks(paths: Array) -> int:
	var open_cells := _open_set(paths)
	var seen := {}
	var blocks := 0
	for y in n:
		for x in n:
			var cell := Vector2i(x, y)
			if open_cells.has(cell) or seen.has(cell):
				continue
			blocks += 1
			seen[cell] = true
			var stack: Array = [cell]
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var k: Vector2i = c + d
					if k.x < 0 or k.y < 0 or k.x >= n or k.y >= n:
						continue
					if open_cells.has(k) or seen.has(k):
						continue
					seen[k] = true
					stack.append(k)
	return blocks

# --- derived, never stored (the Queens rule) ---
func is_wall(cell: Vector2i) -> bool:
	return not letters.has(cell)

func word_at(cell: Vector2i) -> int:
	for i in words.size():
		if (words[i]["path"] as Array).has(cell):
			return i
	return -1

func is_locked(cell: Vector2i) -> bool:
	var i := word_at(cell)
	return i >= 0 and bool(words[i]["found"])

func can_trace(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= n or cell.y >= n:
		return false
	return not is_wall(cell) and not is_locked(cell)

func found_count() -> int:
	var count := 0
	for w in words:
		if w["found"]:
			count += 1
	return count

func is_solved() -> bool:
	return words.size() > 0 and found_count() == words.size()

# --- the four moves ---
## Its own cells, in order, or nothing. A trail that spells the word over
## other tiles is not that word: accepting it would break the coverage the
## whole puzzle rests on. Anything else is refused silently -- no toast, no
## penalty, nothing spent.
func trace(path: Array) -> int:
	if path.size() < 3:
		return -1
	for i in words.size():
		if words[i]["found"]:
			continue
		var want: Array = words[i]["path"]
		if want.size() != path.size():
			continue
		var same := true
		for j in want.size():
			if want[j] != path[j]:
				same = false
				break
		if same:
			words[i]["found"] = true
			order.append(i)
			return i
	return -1

func undo() -> bool:
	if order.is_empty():
		return false
	var i: int = order.pop_back()
	words[i]["found"] = false
	return true

func reset_board() -> void:
	while not order.is_empty():
		words[order.pop_back()]["found"] = false

## The one hint this game can give: the words are hidden but the letters are
## not, so the only thing a player can be short of is where a word starts.
func hint() -> bool:
	var pick := -1
	for i in words.size():
		if words[i]["found"]:
			continue
		if hint_shown(i) >= (words[i]["path"] as Array).size():
			continue
		if pick < 0 or (words[i]["path"] as Array).size() < (words[pick]["path"] as Array).size():
			pick = i
	if pick < 0:
		return false
	given[pick] = hint_shown(pick) + 1
	return true

func hint_shown(index: int) -> int:
	return int(given.get(index, 0))

## The next tile a hint would light, or (-1, -1) when there is none.
func hint_cell(index: int) -> Vector2i:
	var shown := hint_shown(index)
	var path: Array = words[index]["path"]
	if shown >= path.size():
		return Vector2i(-1, -1)
	return path[shown]
```

- [ ] **Step 5: Run the suite until it is green**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -20`
Expected: the whole suite passes with `0` failures, `word_trail` among them.

If the generator's quality rules reject too much and `best` falls back to `loose` often, the `_one_field`/`_full_wall_line` assertions in the suite will fail on some seed — raise `ATTEMPTS`, do not weaken the rules.

- [ ] **Step 6: Commit**

```bash
git add puzzles/word_trail_state.gd tests/test_word_trail.gd tests/run_tests.gd
git commit -m "feat(wordtrail): the rules, scene-free

The generator works backwards -- paths first, walls left over -- because a
path's shape puts no constraint on its letters. Only a right word locks,
along its own cells, and nothing else is refused."
```

---

### Task 2: The board that plays

**Files:**
- Create: `puzzles/word_trail2d.gd`
- Modify: `ui/registry.gd` (replace the `pipes` `soon` entry in `PUZZLES` with the `wordtrail` entry; leave `pipes_island` in `LEGACY` untouched)

**Interfaces:**
- Consumes: everything Task 1 produced; `ui/flat/flat_host.gd`'s contract (`palette()`, `tip_line()`, `card_height(available)`, `card_centred()`, `flat_win()`, `win_delay()`), `core/puzzle_base.gd`'s (`puzzle_id`, `title`, `rules`, `build`, `is_solved`, `reset_board`, `capabilities`, `can_undo`, `undo`, `hints_left`, `hint`, `share_glyphs`).
- Produces: a board the menu can open. Task 3 adds the motion; Task 4 the card art.

- [ ] **Step 1: Read the two files this one is modelled on**

Read `puzzles/nonogram2d.gd` (a fully drawn board: one `ArrayMesh` rebuilt only while something moves, `_shown` holding the mesh the last `_draw` handed over) and `puzzles/hidden_word2d.gd` (letters on `ui/faces/mosaic_tile.gd`, and its `card_height`/`card_centred`). Word Trail is the same shape as both.

- [ ] **Step 2: Write the board's layout and drawing**

Create `puzzles/word_trail2d.gd` extending `res://core/puzzle_base.gd`. The numbers are the spec's section 6 and are not negotiable:

```gdscript
const INSET := 28.0
const GAP := 14.0
const SLOTS_PAD := 24.0     # air between the field and the slots
const SLOTS_H := 150.0
const SLOT_W := 34.0
const SLOT_H := 52.0
const SLOT_GAP := 5.0
const GROUP_GAP := 22.0
const LINE_GAP := 14.0
## This board's own two, and the only two it needs.
const WAVE_STEP := 0.05
const BEAM_TIME := 0.18
```

Layout, computed in `_layout()` off `size`:

- `cell = min((size.x - 2*INSET - (n-1)*GAP) / n, (size.y - 2*INSET - SLOTS_H - SLOTS_PAD - (n-1)*GAP) / n)` — the width binds at every band, giving 178 / 146 / 123 at 1080 wide.
- the field is `n*cell + (n-1)*GAP` square, centred horizontally, top at `INSET`.
- the slots start `SLOTS_PAD` under the field and take `SLOTS_H`.
- everything below that is the scenery band (Task 3 fills it; leave it empty here).

Slot groups: shortest word first, one group of `word.length` boxes `SLOT_W` wide with `SLOT_GAP` between, `GROUP_GAP` between groups, wrapped to the next line when the line would exceed `size.x - 2*INSET`, lines `LINE_GAP` apart and the block centred vertically in `SLOTS_H` and each line centred horizontally.

Draw order, and it is the only order that works because a tile is opaque:

1. the walls — `Pal.STONE_GIVEN` rounded squares (radius `cell*0.22`) with a rim a fifth of the way to ink, and a leaf at `Pal.TEXT` alpha 0.14 on each;
2. the tile faces — `Pal.SURFACE`, rim a sixth toward ink; a found word's tiles take that word's `*_TILE`;
3. the ribbons — for each found word, a rounded polyline through its path's cell centres, width `cell*0.46`, in the word's colour at alpha 0.5; then the live trail in `Pal.SUN_RAY` at 0.6;
4. the letters — `Pal.TEXT`, or the word's `*_DEEP` when found, at `cell*0.48`;
5. the slot boxes and their letters.

Colours, in word order, from `core/palette.gd` and nowhere else:

```gdscript
const WORD_COLS := [Pal.LEAF, Pal.SUN, Pal.MOON_INK, Pal.BERRY, Pal.ACORN, Pal.FLOWER]
const WORD_TILES := [Pal.LEAF_TILE, Pal.SUN_TILE, Pal.MOON_TILE, Pal.BERRY_TILE, Pal.ACORN_TILE, Pal.FLOWER_TILE]
const WORD_DEEPS := [Pal.LEAF_DEEP, Pal.SUN_DEEP, Pal.MOON_DEEP, Pal.BERRY_DEEP, Pal.ACORN_DEEP, Pal.FLOWER_DEEP]
```

Follow Nonogram's mesh discipline: build the field into one `ArrayMesh` and keep the mesh the last `_draw` handed over in a `_shown` member until the next one replaces it, or a harness's `force_draw()` will draw a freed RID.

- [ ] **Step 3: Write the input**

`_gui_input` handles a press, a drag and a release:

```gdscript
func _gui_input(event: InputEvent) -> void:
	if _done:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var cell := _cell_at(event.position)
		if pressed:
			if cell.x >= 0 and _state.can_trace(cell):
				_trail = [cell]
				_beam_at = _clock
				accept_event()
		elif not _trail.is_empty():
			_release()
			accept_event()
	elif (event is InputEventScreenDrag or event is InputEventMouseMotion) and not _trail.is_empty():
		var cell := _cell_at(event.position)
		if cell.x < 0:
			return
		var at := _trail.find(cell)
		if at == _trail.size() - 2:
			_trail.resize(_trail.size() - 1)          # retracting takes the beam back
		elif at < 0 and _state.can_trace(cell) and _adjacent(_trail[_trail.size() - 1], cell):
			_trail.append(cell)
			_beam_at = _clock
		queue_redraw()
		accept_event()
```

`_release()` calls `_state.trace(_trail)`. On a lock: `note_move()`, start the word's wave, and `check_solved()` when `_state.is_solved()`. On `-1`: start the ghost beam unwinding and **do nothing else** — no toast, no shiver, no move counted.

`_adjacent(a, b)` is `absi(a.x-b.x) + absi(a.y-b.y) == 1`.

- [ ] **Step 4: Write the contract methods**

```gdscript
func puzzle_id() -> String: return "wordtrail"
func title() -> String: return "Word Trail"
func capabilities() -> Array[String]: return ["undo", "hint"]
func can_undo() -> bool: return not _state.order.is_empty()
func hints_left() -> int: return maxi(0, HINTS - hints_used)
func card_height(available: float) -> float: return available
func card_centred() -> bool: return false
func win_delay() -> float: return 1.4
```

`rules()` is the real text, reachable through the tip card:

```
Drag from letter to letter -- up, down, left or right, never diagonally --
to trace a hidden word. A trail may bend as often as it likes, but it may
not cross a grey wall or a word you have already found.

You are never told the words, only how long each one is: the boxes under
the field are the lengths, shortest first.

Every open tile belongs to exactly one word, so when the last word is
traced the field is full. A trail that is not one of today's words simply
unwinds -- it costs you nothing.
```

`share_glyphs()` is one line per word in lock order, a tile glyph per letter, so a shared board shows the shape of the day and not its answers:

```gdscript
func share_glyphs() -> String:
	var out: Array[String] = []
	for i in _state.order:
		out.append("🟩".repeat((_state.words[i]["path"] as Array).size()))
	return "\n".join(out)
```

`HINTS` is 3. `hint()` calls `_state.hint()`, returns its result, and rings the tile.

- [ ] **Step 5: Put it on the first screen**

In `ui/registry.gd`, replace the `pipes` entry at the end of `PUZZLES` with the entry from the spec's section 2, and update the list comment above `PUZZLES` so it says twelve live cards and no `soon` card, with Pipes' island still under More. Do not touch `LEGACY`.

- [ ] **Step 6: Run the suite and open the board**

Run: `godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5`
Expected: `0` failures.

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- wordtrail`
Expected: a strip of PNGs in `/tmp` showing the field, and a draw-call count and idle mean printed. Look at them: the field is square and centred, the walls read as blocks, the slots sit under the field, nothing overlaps the tip card.

- [ ] **Step 7: Commit**

```bash
git add puzzles/word_trail2d.gd ui/registry.gd
git commit -m "feat(wordtrail): the board, and the twelfth card

Takes the slot Pipes' soon card held; Pipes keeps its island under More, as
Snake Apple and Horse Pen did before it. No Check and no tray, so Reset
rides up into the top bar and the bottom slot is the tip card alone."
```

---

### Task 3: The motion, the scenery band and what the board says

**Files:**
- Modify: `puzzles/word_trail2d.gd`

**Interfaces:**
- Consumes: `core/motion.gd`'s curve readers (`back_out`, `wide_pop_scale`, `pop_in_scale`, `pop_out_scale`, `drop_in_lift`, `bump_scale`, `press_scale`, `hop_lift`, `flash_level`), `ui/fx2d.gd` (rings and sparkles), `ui/flat/scenery.gd` (clouds, turf, bushes and `soft_disc`).
- Produces: nothing new for other tasks.

- [ ] **Step 1: Read the vocabulary**

Read `docs/art/flat-motion.md` and the "drawn pieces off the curve readers" precedent in `puzzles/nonogram2d.gd`. Every moment below is a reader call handed the seconds since the moment began. **Add nothing to `core/motion.gd`.**

- [ ] **Step 2: Implement the moments (spec section 9)**

- **Entrance:** the field pops in wide about its centre (`Motion.wide_pop_scale`, from 0.88) while it fades; the slot groups drop in after it, `Motion.ENTER_STAGGER` apart.
- **Dragging:** the tile under the finger at `Motion.press_scale` 0.94, the rest of the trail at 0.97, and the beam growing to the finger over `BEAM_TIME`.
- **Locked:** the wave. `front = clamp((now - word.at) / (len * WAVE_STEP)) * len`; the ribbon draws up to `front` (interpolating the partial segment so the head moves smoothly); each tile bumps (`Motion.bump_scale`) as the wave passes it and its letter drops into its slot box (`Motion.drop_in_lift`). A ring and sparkles from `ui/fx2d.gd` in the word's colour on the last tile.
- **Unwound:** the ghost beam shrinks back to its first tile over `BEAM_TIME` and fades. Nothing shivers.
- **Hint:** a ring in `Pal.LEAF`, then the tile keeps a `Pal.SUN_RAY` glow at 0.45 under a dashed outline until its word is found.
- **Undo:** the same wave backwards — `front = (1 - clamp((now - word.undo_at) / (len * WAVE_STEP))) * len`.
- **Reset:** every locked word unwinds at once, each on its own reversed wave.
- **Solved:** every tile hops in one wave from the top-left corner, 0.02 a tile, with sparkles in gold.

Reduce motion (`Motion.reduce`): the field is up at once, a lock takes its colour and letters in one frame, the beam has no growth, nothing hops, rings or sparkles.

A board that rebuilds only while it is moving must ask about **every** wave: `_animating()` returns true while the entrance, any word's wave, the ghost beam, a ring, a sparkle or the solve wave is still running. One Line froze two lines at four fifths of a fade by forgetting one.

- [ ] **Step 3: Fill the scenery band**

Under the slots, lay `ui/flat/scenery.gd`'s clouds, turf strip and bushes in the 222-250 the width leaves, the way Balance's and Hidden Word's are laid.

- [ ] **Step 4: Write what the board says**

`tip_line()` returns the sprout's line: the four cycling lines from the spec's section 12 while nothing is found, and the event lines after a lock, an undo, a reset and a hint.

`flat_win()` lays the day's words across the win screen, each in its own colour, with no label under them.

- [ ] **Step 5: Shoot the strip and judge it**

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- wordtrail`
Then, one at a time and never overlapping: the same with `rm` for reduce motion.
Expected: the wave runs along the path and not all at once; the ribbon is visible over the tiles; reduce-motion frames 1.5 s apart are pixel-identical.

- [ ] **Step 6: Run the suite and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5
git add puzzles/word_trail2d.gd
git commit -m "feat(wordtrail): the wave, the beam and the band

Its signature is the ribbon: a locked word takes its colour from its first
tile to its last, WAVE_STEP apart, and undo runs the same wave backwards.
Nothing new in core/motion.gd."
```

---

### Task 4: The menu card

**Files:**
- Modify: `ui/menu/card_art.gd`

**Interfaces:**
- Consumes: the registry id `wordtrail`.
- Produces: the twelfth card's picture.

- [ ] **Step 1: Read the neighbours**

Read `ui/menu/card_art.gd`'s `_build` branches for `nonogram` and `hiddenword` — both draw tiles in the 320 by 118 box.

- [ ] **Step 2: Draw the card**

One new branch: a small field of letter tiles (the `ui/faces/mosaic_tile.gd` shapes the board uses) with one trail bending through it in `Pal.LEAF` and two grey wall slabs, and the sprout beside it. Never an image, never a `SubViewport`. It is a picture of the board, so the letters may be any letters — pick ones that spell nothing, so the card does not look like a solvable day.

- [ ] **Step 3: Shoot the first screen**

Run: `godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd`
Expected: twelve live cards, none dimmed, Word Trail in the last slot, and a draw-call count printed. Record the count — Task 5 needs it.

- [ ] **Step 4: Commit**

```bash
git add ui/menu/card_art.gd
git commit -m "feat(wordtrail): the card's picture"
```

---

### Task 5: Measure it, and write down what is true

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-20-word-trail-flat-design.md` (an amendments section at the end)

- [ ] **Step 1: Measure, twice, one harness at a time**

Run, sequentially and never overlapping (GPU contention and first-run shader compile inflate the numbers):

```bash
godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- wordtrail
godot --path . --resolution 810x1440 --script res://tests/_shot_anim.gd -- wordtrail
godot --path . --resolution 810x1440 --script res://tests/_shot_menu.gd
```

Record the draw-call count and the idle mean from **both** board runs, and the menu's count. Then run one already-measured board (Queens or Hidden Word) in the same session as a control, because a single reading off this harness is worth nothing — this Mac's spread is a factor of 1.6.

- [ ] **Step 2: Check it on the phone's driver**

Run: `godot --path . --resolution 810x1440 --rendering-driver opengl3_angle --script res://tests/_shot_anim.gd -- wordtrail`
Expected: the same draw-call count and frames that match the default driver except on edge antialiasing. A difference here means something reintroduced an `instance uniform`.

- [ ] **Step 3: Write the amendments into the spec**

Add a `## 15. Amendments from the build, 2026-09-20` section recording every number measured, every place the build departed from the spec, and why.

- [ ] **Step 4: Update CLAUDE.md**

In "The flat screens", say twelve boards rather than eleven and name Word Trail with its spec and mock. In "The first screen", say twelve live cards and **no** `soon` card, note that the `SOON` pill and `blocked` path are now unexercised, and update the measured draw-call count with the date. Add Word Trail's bottom-slot height (140) to the list of the eleven that reads `460, 460, 390, ...`.

- [ ] **Step 5: Run the whole suite one last time and commit**

```bash
godot --headless --path . --script tests/run_tests.gd 2>&1 | tail -5
git add CLAUDE.md docs/superpowers/specs/2026-09-20-word-trail-flat-design.md
git commit -m "docs(wordtrail): the twelfth flat board on the record, measured"
```

---

## Self-Review

**Spec coverage.** Section 1 (files) → all five tasks. Section 2 (registry, the slot, the unused `SOON` path) → Task 2 step 5 and Task 5 step 4. Section 3 (state) → Task 1. Section 4 (generation and its quality rules) → Task 1 steps 1 and 4, asserted in the suite. Section 5 (words) → already committed; read by Task 1's `word_bank()`. Section 6 (measurements) → Task 2 step 2. Section 7 (colour and draw order) → Task 2 step 2. Section 8 (no new cast) → Global Constraints and Task 2. Section 9 (motion) → Task 3. Section 10 (hint) → Task 1 (`hint`/`hint_shown`/`hint_cell`) and Task 3 (the glow). Section 11 (card) → Task 4. Section 12 (what it says) → Task 3 step 4 and Task 2's `rules()`. Section 13 (analytics) → nothing to do; the host already sends everything. Section 14 (calls) → Task 5's amendments.

**Types.** `trace(path: Array) -> int`, `hint_shown(index: int) -> int` and `can_trace(cell: Vector2i) -> bool` are used with those exact names and signatures in Tasks 2 and 3. `words[i]["path"]` is `Array` of `Vector2i` everywhere; `words[i]["word"]` is upper-case in the state and drawn as-is.

**One thing deliberately left out of the plan:** the board's `undo_at` per-word timestamp is a drawing concern, so it lives in `word_trail2d.gd`'s own bookkeeping, not in the state's `words` dictionaries. The state has no clock.
