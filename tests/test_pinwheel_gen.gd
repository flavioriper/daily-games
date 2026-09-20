extends RefCounted

## The generator's own suite: the geometry it rests on, the proof it makes,
## and the promise that a seed is a board.

const Gen = preload("res://puzzles/pinwheel_gen.gd")

static func run(t) -> void:
	_test_rotate_is_clockwise_about_the_pin(t)
	_test_orientations_drop_duplicates_and_escapees(t)
	_test_count_tilings_counts(t)
	_test_every_band_builds(t)
	_test_repeatable(t)
	_test_the_answer_tiles_the_frame(t)
	_test_the_start_is_reachable_and_not_the_answer(t)
	_test_pieces_that_could_be_confused_never_share_a_cloth(t)

static func _cells(raw: Array) -> Array:
	var out: Array = []
	for p in raw:
		out.append(Vector2i(p[0], p[1]))
	return out

static func _key(cells: Array) -> String:
	var ids: Array = []
	for c: Vector2i in cells:
		ids.append("%d,%d" % [c.x, c.y])
	ids.sort()
	return ";".join(ids)

static func _test_rotate_is_clockwise_about_the_pin(t) -> void:
	# A horizontal domino pinned at its left cell swings down, not up:
	# clockwise on a y-down screen sends (+1, 0) to (0, +1).
	var cells := _cells([[2, 3], [3, 3]])
	var turned: Array = Gen.rotate(cells, Vector2i(2, 3), 1)
	t.eq(_key(turned), _key(_cells([[2, 3], [2, 4]])), "one quarter turn is clockwise")
	t.eq(_key(Gen.rotate(cells, Vector2i(2, 3), 4)), _key(cells), "four quarters come home")

static func _test_orientations_drop_duplicates_and_escapees(t) -> void:
	# A lone cell has exactly one orientation however much it is turned.
	t.eq(Gen.orientations(_cells([[0, 0]]), Vector2i(0, 0), 5, 5).size(), 1,
		"a single cell has one orientation")
	# A domino pinned in the top-left corner can only lie right or hang down:
	# the other two quarters leave the frame.
	var corner: Array = Gen.orientations(_cells([[0, 0], [1, 0]]), Vector2i(0, 0), 5, 5)
	t.eq(corner.size(), 2, "a corner domino keeps two of its four quarters")
	# The same domino in the middle keeps all four.
	t.eq(Gen.orientations(_cells([[2, 2], [3, 2]]), Vector2i(2, 2), 5, 5).size(), 4,
		"a domino with room keeps four")

static func _test_count_tilings_counts(t) -> void:
	# Two dominoes in a 2x2 frame, pinned in opposite corners. Both lying
	# flat fills it -- and so does both standing up, because each pin is on
	# the corner its domino can swing about into the other column. Two is the
	# right answer here and it is worth spelling out: the plan's own example
	# claimed one, and a proof that cannot count a second tiling on a four-cell
	# board would pass every other test in this file.
	var a: Array = Gen.orientations(_cells([[0, 0], [1, 0]]), Vector2i(0, 0), 2, 2)
	var b: Array = Gen.orientations(_cells([[0, 1], [1, 1]]), Vector2i(1, 1), 2, 2)
	t.eq(Gen.count_tilings([a, b], 2, 2, 5), 2, "a 2x2 of two corner-pinned dominoes tiles two ways")
	t.eq(Gen.count_tilings([a, b], 2, 2, 1), 1, "and the cap stops the search where it is told to")
	# Move the second domino's pin under the first one's and the frame has
	# exactly one tiling: standing up, the two would want the same cell.
	var c: Array = Gen.orientations(_cells([[0, 1], [1, 1]]), Vector2i(0, 1), 2, 2)
	t.eq(Gen.count_tilings([a, c], 2, 2, 5), 1, "pinned under each other they tile one way")

static func _test_every_band_builds(t) -> void:
	for d in 3:
		var b: Dictionary = Gen.band(d)
		var missed := 0
		var unproved := 0
		for s in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + s
			var g: Dictionary = Gen.generate(rng, d)
			if int(g.cols) == 0:
				missed += 1
				continue
			if not bool(g.unique):
				unproved += 1
			t.eq((g.shapes as Array).size(), (b.sizes as Array).size(),
				"band %d seed %d built every piece" % [d, s])
			t.check(int(g.turns) >= int(b.min_turns),
				"band %d seed %d is deep enough (%d taps)" % [d, s, int(g.turns)])
		t.eq(missed, 0, "band %d missed no seed" % d)
		t.eq(unproved, 0, "band %d proved every board unique" % d)

static func _test_repeatable(t) -> void:
	for d in 3:
		var one := RandomNumberGenerator.new()
		var two := RandomNumberGenerator.new()
		one.seed = 4242
		two.seed = 4242
		var a: Dictionary = Gen.generate(one, d)
		var b: Dictionary = Gen.generate(two, d)
		t.eq(str(a.pins), str(b.pins), "band %d: the same seed pins the same cells" % d)
		t.eq(str(a.start), str(b.start), "band %d: the same seed opens the same way" % d)
		t.eq(str(a.cloth), str(b.cloth), "band %d: the same seed colours the same" % d)

static func _test_the_answer_tiles_the_frame(t) -> void:
	for d in 3:
		for s in 12:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900 + s
			var g: Dictionary = Gen.generate(rng, d)
			var cols := int(g.cols)
			var rows := int(g.rows)
			var seen := PackedInt32Array()
			seen.resize(cols * rows)
			for p in (g.shapes as Array).size():
				for c: Vector2i in ((g.shapes[p] as Array)[int(g.answer[p])] as Array):
					t.check(c.x >= 0 and c.x < cols and c.y >= 0 and c.y < rows,
						"band %d seed %d: the answer stays in the frame" % [d, s])
					seen[c.y * cols + c.x] += 1
			for i in seen.size():
				t.eq(seen[i], 1, "band %d seed %d cell %d is covered once" % [d, s, i])

static func _test_the_start_is_reachable_and_not_the_answer(t) -> void:
	# Every orientation is reachable because a tap steps round the cycle, so
	# the only thing to check is that the board does not open solved and that
	# a piece with somewhere to go is actually moved off its answer.
	for d in 3:
		for s in 12:
			var rng := RandomNumberGenerator.new()
			rng.seed = 300 + s
			var g: Dictionary = Gen.generate(rng, d)
			var moved := 0
			for p in (g.shapes as Array).size():
				var m: int = (g.shapes[p] as Array).size()
				t.check(int(g.start[p]) >= 0 and int(g.start[p]) < m,
					"band %d seed %d piece %d opens on a real orientation" % [d, s, p])
				if m > 1:
					t.check(int(g.start[p]) != int(g.answer[p]),
						"band %d seed %d piece %d does not open solved" % [d, s, p])
					moved += 1
			t.check(moved > 0, "band %d seed %d has something to turn" % [d, s])

static func _test_pieces_that_could_be_confused_never_share_a_cloth(t) -> void:
	# Two pieces in one colour read as one shape. Eight cloths cannot keep a
	# colour off every piece another could ever brush past -- that graph is
	# nearly complete on the bigger bands, and `_colour`'s header carries the
	# measurement that killed it. What they can keep, and what is asserted
	# here, is that two pieces sharing a cloth can never **overlap** and never
	# **touch in the answer**: an invisible stack and a merged solved frame
	# are the two ways the colour would actually mislead.
	for d in 3:
		for s in 10:
			var rng := RandomNumberGenerator.new()
			rng.seed = 600 + s
			var g: Dictionary = Gen.generate(rng, d)
			var spread: Array = []
			var home: Array = []
			var home_near: Array = []
			for p in (g.shapes as Array).size():
				var every: Dictionary = {}
				for orient: Array in (g.shapes[p] as Array):
					for c: Vector2i in orient:
						every[c] = true
				spread.append(every)
				var solved: Dictionary = {}
				var near: Dictionary = {}
				for c: Vector2i in ((g.shapes[p] as Array)[int(g.answer[p])] as Array):
					solved[c] = true
					near[c] = true
					for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						near[c + dd] = true
				home.append(solved)
				home_near.append(near)
			for a in spread.size():
				for b in range(a + 1, spread.size()):
					if int(g.cloth[a]) != int(g.cloth[b]):
						continue
					for c in (spread[b] as Dictionary):
						t.check(not (spread[a] as Dictionary).has(c),
							"band %d seed %d: pieces %d and %d share a cloth and can stack" % [d, s, a, b])
					for c in (home[b] as Dictionary):
						t.check(not (home_near[a] as Dictionary).has(c),
							"band %d seed %d: pieces %d and %d share a cloth and touch in the answer" % [d, s, a, b])
