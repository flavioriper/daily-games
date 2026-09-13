extends RefCounted

const Gen = preload("res://puzzles/shikaku_gen.gd")

static func run(t) -> void:
	for dim in [[5, 5, 6], [7, 7, 8], [6, 8, 9]]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 2000 + i
			var out: Dictionary = Gen.generate(rng, dim[0], dim[1], dim[2])
			var tag := "%dx%d seed=%d" % [dim[0], dim[1], i]
			t.check(out.ok, "%s generated a puzzle" % tag)
			if not out.ok:
				continue
			t.eq(Gen.solve_count(out.clues, dim[0], dim[1], 3), 1, "%s is uniquely solvable" % tag)

			# The rectangles must tile the board with no overlap and no gap.
			var covered: Dictionary = {}
			var area := 0
			for r in out.rects:
				area += r.size.x * r.size.y
				for x in range(r.position.x, r.position.x + r.size.x):
					for y in range(r.position.y, r.position.y + r.size.y):
						covered[Vector2i(x, y)] = true
			t.eq(area, dim[0] * dim[1], "%s rectangles tile the board" % tag)
			t.eq(covered.size(), dim[0] * dim[1], "%s no overlaps or gaps" % tag)

			# Exactly one clue per rectangle, and its area matches.
			var one_each := true
			for r in out.rects:
				var n := 0
				for c in out.clues:
					if r.has_point(c.pos):
						n += 1
						if int(c.area) != r.size.x * r.size.y:
							one_each = false
				if n != 1:
					one_each = false
			t.check(one_each, "%s one matching clue per rectangle" % tag)

			# 1x1 clues are forced on sight; a board full of them is not a puzzle.
			var smallest := 999
			for r in out.rects:
				smallest = mini(smallest, r.size.x * r.size.y)
			t.check(smallest >= 3, "%s no rectangle below the minimum area (%d)" % [tag, smallest])
			t.check(out.rects.size() <= (dim[0] * dim[1]) / 3,
				"%s rectangle count is sane (%d)" % [tag, out.rects.size()])

	# Areas that do not tile the board are rejected outright.
	t.eq(Gen.solve_count([{"pos": Vector2i(0, 0), "area": 3}], 2, 2, 2), 0,
		"clue areas must sum to the board area")

	# A 1x2 board with two 1-cell clues has exactly one solution.
	t.eq(Gen.solve_count([{"pos": Vector2i(0, 0), "area": 1}, {"pos": Vector2i(1, 0), "area": 1}], 2, 1, 3), 1,
		"trivial board solves once")

	# Determinism.
	var a := RandomNumberGenerator.new(); a.seed = 11
	var b := RandomNumberGenerator.new(); b.seed = 11
	t.eq(Gen.generate(a, 6, 6, 8).clues, Gen.generate(b, 6, 6, 8).clues, "same seed, same puzzle")
