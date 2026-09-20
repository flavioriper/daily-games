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
	var taken := {}
	for path in paths:
		var bucket: Array = bank.get(str(path.size()), [])
		var word: String = "?".repeat(path.size())
		if not bucket.is_empty():
			# A day never writes the same word twice: the two larger bands
			# repeat a length on purpose, so two paths draw from one bucket.
			# The shallowest bucket is 108 deep and at most two paths share a
			# length, so eight tries is overwhelming.
			for tries in 8:
				word = str(bucket[rng.randi_range(0, bucket.size() - 1)])
				if not taken.has(word):
					break
		taken[word] = true
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
	var pick := hint_target()
	if pick < 0:
		return false
	given[pick] = hint_shown(pick) + 1
	return true

## Which word the next hint would light, or -1 when there is none: the
## shortest unfound word that still has a tile left to give. `hint()` picks
## through this, and so does the board, which has to know which tile to ring
## before it spends the hint -- one seam, so the two can never disagree.
func hint_target() -> int:
	var pick := -1
	for i in words.size():
		if words[i]["found"]:
			continue
		if hint_shown(i) >= (words[i]["path"] as Array).size():
			continue
		if pick < 0 or (words[i]["path"] as Array).size() < (words[pick]["path"] as Array).size():
			pick = i
	return pick

func hint_shown(index: int) -> int:
	return int(given.get(index, 0))

## The next tile a hint would light, or (-1, -1) when there is none.
func hint_cell(index: int) -> Vector2i:
	var shown := hint_shown(index)
	var path: Array = words[index]["path"]
	if shown >= path.size():
		return Vector2i(-1, -1)
	return path[shown]
