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

## GDScript's String has no reverse(); Array does.
static func _reverse_str(s: String) -> String:
	var out := ""
	for i in range(s.length() - 1, -1, -1):
		out += s.substr(i, 1)
	return out

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
	if (w0["word"] as String) != _reverse_str(w0["word"] as String):
		t.eq(st.trace(back), -1, "a trail traced backwards does not lock")
		t.check(not st.words[0]["found"], "and nothing was marked found")

	# A prefix is not the word either. It has to be a prefix of at least
	# three cells to reach the length test at all: words[0] is the shortest
	# and its path is three, so its prefix is turned away by trace()'s "a
	# trail under three tiles locks nothing" and never exercises the
	# mismatch. words[1] is four, so its three-cell prefix does.
	var long_path: Array = (st.words[1]["path"] as Array).duplicate()
	t.eq(st.trace(long_path.slice(0, long_path.size() - 1)), -1, "a prefix does not lock")
	t.check(not st.words[1]["found"], "and the longer word is still unfound")
	t.eq(st.trace(path.slice(0, path.size() - 1)), -1, "a two-tile trail locks nothing either")

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
