extends RefCounted

## Paper Planes' rules (puzzles/planes_state.gd): the lane, the launch, reset
## and hint, and the generator's one promise -- a board carved backwards out
## of an empty sky can always be cleared.
##
## It also carries the one check that is not this board's: that every
## registered board's script parses at all (`_test_boards_parse`). That
## belongs to no puzzle in particular and it is three lines, so it lives in
## the newest suite rather than in a file of its own.

const State = preload("res://puzzles/planes_state.gd")
const Registry = preload("res://ui/registry.gd")

static func run(t) -> void:
	_test_boards_parse(t)
	_test_lane(t)
	_test_launch(t)
	_test_reset(t)
	_test_hint(t)
	_test_degenerate_plane_refused(t)
	_test_generator(t)
	_test_repeatable(t)

## Every board on the first screen has a script that parses.
##
## Until 2026-09-20 **nothing under tests/ loaded a board's `*2d.gd`**: a
## parse error in `puzzles/planes2d.gd` left the suite reporting
## `passed=94534 failed=0`, and only `tests/_win.gd` -- which needs a display
## and is not in CI -- caught it. That was true of all fifteen boards, not
## just this one. A script with a parse error still `load()`s as a GDScript
## object and only gives itself away at `can_instantiate()`, which is exactly
## the trap `tests/run_tests.gd` already guards its own suites against, and
## for the same reason. The board is not instantiated here: it is a Control
## that wants a live tree, and loading it is all that proves it compiles.
static func _test_boards_parse(t) -> void:
	for e in Registry.PUZZLES:
		var path: String = e.get("script", "")
		t.check(not path.is_empty(), "%s: the registry names a script" % e.get("id", "?"))
		var script := load(path)
		t.check(script != null and script.can_instantiate(),
			"%s: %s parses" % [e.get("id", "?"), path])

static func _empty(rows: int, cols: int) -> State:
	var st := State.new()
	st.rows = rows
	st.cols = cols
	st.planes = []
	st.order = []
	st.clear_occupancy()
	return st

## A plane laid by hand: cells tail..head, direction taken from the last step.
static func _add(st: State, cells: Array) -> int:
	var typed: Array[Vector2i] = []
	for c in cells:
		typed.append(c)
	return st.add_plane(typed)

## The lane is every cell beyond the head, out to the edge -- and a plane is
## free exactly when nothing stands in it.
static func _test_lane(t) -> void:
	var st := _empty(5, 5)
	# A plane along row 2, heading right, head at (2, 2).
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	t.eq(st.planes[a]["dir"], Vector2i(1, 0), "the dart heads the way the last step went")
	t.eq(st.lane(a).size(), 2, "two cells between the head and the right edge")
	t.check(st.is_free(a), "an empty lane is a free plane")
	t.eq(st.blocker(a), -1, "nothing blocks it")
	# A second plane standing in that lane.
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.is_free(a), "a plane in the lane blocks the launch")
	t.eq(st.blocker(a), b, "and it is named as the blocker")
	t.check(st.is_free(b), "the blocker itself heads down a clear lane")

## A launch empties the plane's cells and can never block anything; an undo
## puts it back exactly as it was.
static func _test_launch(t) -> void:
	var st := _empty(5, 5)
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(not st.launch(a), "a blocked plane refuses to launch")
	t.eq(st.left(), 2, "and nothing left the board")
	t.check(st.launch(b), "the free one goes")
	t.eq(st.plane_at(Vector2i(4, 1)), -1, "its cells are empty behind it")
	t.check(st.is_free(a), "which frees the one it was blocking")
	t.check(st.launch(a), "and that one goes too")
	t.check(st.solved(), "an empty sky is a solved board")
	t.eq(st.undo(), a, "undo puts the last one back")
	t.check(not st.solved(), "so the board is not solved any more")
	t.eq(st.plane_at(Vector2i(1, 2)), a, "and it is back on its own cells")

## reset() puts every launched plane back on the board and empties the
## launch history, so a fresh undo() after it has nothing left to call back.
static func _test_reset(t) -> void:
	var st := _empty(5, 5)
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	t.check(st.launch(b), "the free one goes")
	t.check(st.launch(a), "and the one it was blocking goes too")
	t.check(st.solved(), "an empty sky is a solved board")
	st.reset()
	t.check(not st.solved(), "reset puts the board back in play")
	t.eq(st.left(), 2, "and both planes are back")
	t.eq(st.plane_at(Vector2i(1, 2)), a, "each on its own cells")
	t.eq(st.plane_at(Vector2i(4, 1)), b, "the other on its own cells too")
	t.eq(st.undo(), -1, "and the history is empty: nothing left to call back")

## hint_plane() names a plane that is actually free, and -1 when none is --
## on an empty board, or once the sky is cleared.
static func _test_hint(t) -> void:
	var st := _empty(5, 5)
	t.eq(st.hint_plane(), -1, "no planes at all: nothing to hint")
	var a := _add(st, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)])
	var b := _add(st, [Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2)])
	var hinted := st.hint_plane()
	t.eq(hinted, b, "the only free plane is the one named")
	t.check(st.is_free(hinted), "and it really is free")
	st.launch(b)
	st.launch(a)
	t.eq(st.hint_plane(), -1, "an empty sky leaves nothing left to hint")

## A single cell has no last step and so no heading; add_plane refuses it
## rather than hand out a zero direction lane() would spin on forever.
static func _test_degenerate_plane_refused(t) -> void:
	var st := _empty(5, 5)
	t.eq(_add(st, [Vector2i(2, 2)]), -1, "a one-cell body is refused")
	t.eq(st.planes.size(), 0, "and nothing was placed")

static func _built(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.build(rng, difficulty)
	return st

## The generator's promises, over enough seeds that a rare layout cannot
## hide: the band's grid, well-formed planes, no overlap, no plane blocking
## itself, and -- the one that matters -- every board clears.
static func _test_generator(t) -> void:
	for difficulty in 3:
		var b: Dictionary = State.band(difficulty)
		for s in range(1, 41):
			var st := _built(s, difficulty)
			t.eq(st.cols, int(b["cols"]), "band %d seed %d: columns" % [difficulty, s])
			t.eq(st.rows, int(b["rows"]), "band %d seed %d: rows" % [difficulty, s])
			t.check(st.planes.size() >= 8, "band %d seed %d: a board worth playing" % [difficulty, s])
			var seen := {}
			for i in st.planes.size():
				var cells: Array = st.planes[i]["cells"]
				t.check(cells.size() >= int(b["min_len"]) and cells.size() <= int(b["max_len"]),
					"band %d seed %d: plane %d is within the band's lengths" % [difficulty, s, i])
				for j in cells.size():
					var c: Vector2i = cells[j]
					t.check(st.in_board(c), "band %d seed %d: plane %d stays on the board" % [difficulty, s, i])
					t.check(not seen.has(c), "band %d seed %d: plane %d shares no cell with another" % [difficulty, s, i])
					seen[c] = true
					if j > 0:
						var step: Vector2i = c - cells[j - 1]
						t.eq(absi(step.x) + absi(step.y), 1,
							"band %d seed %d: plane %d walks one cell at a time" % [difficulty, s, i])
				# A plane may never stand in its own lane: the launch rule
				# would then have to special-case the plane being tapped.
				var body := {}
				for c in cells:
					body[c] = true
				for c in st.lane(i):
					t.check(not body.has(c), "band %d seed %d: plane %d never blocks itself" % [difficulty, s, i])
			t.eq(st.solve_order().size(), st.planes.size(),
				"band %d seed %d: the whole board clears" % [difficulty, s])
			t.eq(st.order.size(), st.planes.size(),
				"band %d seed %d: the generator's own order is complete" % [difficulty, s])

## The same seed is the same board, which is what a daily puzzle means.
static func _test_repeatable(t) -> void:
	for difficulty in 3:
		var a := _built(77, difficulty)
		var b := _built(77, difficulty)
		t.eq(a.planes.size(), b.planes.size(), "band %d: same seed, same plane count" % difficulty)
		for i in a.planes.size():
			t.eq(a.planes[i]["cells"], b.planes[i]["cells"], "band %d: plane %d is the same" % [difficulty, i])
