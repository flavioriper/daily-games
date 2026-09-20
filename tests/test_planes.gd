extends RefCounted

## Paper Planes' rules (puzzles/planes_state.gd): the lane, the launch, and
## the generator's one promise -- a board carved backwards out of an empty
## sky can always be cleared.

const State = preload("res://puzzles/planes_state.gd")

static func run(t) -> void:
	_test_lane(t)
	_test_launch(t)
	_test_degenerate_plane_refused(t)
	_test_generator(t)
	_test_repeatable(t)

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
