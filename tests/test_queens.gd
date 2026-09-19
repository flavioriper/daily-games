extends RefCounted

## Queens' generator (puzzles/queens_gen.gd): across 7x7/8x8/9x9 and five
## seeds each, checks a generated court has one queen a row, its answer is
## legal and the only seating, every region holds exactly one answer queen
## and is connected, and every cell has a region; plus `legal`'s two
## rejections (a corner touch, a shared column) and that a seed reproduces
## the same court.

const Gen = preload("res://puzzles/queens_gen.gd")

static func run(t) -> void:
	_test_generator(t)

static func _test_generator(t) -> void:
	for n in [7, 8, 9]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + n * 100 + i
			var out: Dictionary = Gen.generate(rng, n)
			var tag := "%dx%d seed=%d" % [n, n, i]
			t.check(out.ok, "%s generated a puzzle" % tag)
			if not out.ok:
				continue
			t.eq(out.solution.size(), n, "%s has one queen per row" % tag)
			t.check(Gen.legal(out.region, n, out.solution), "%s answer is legal" % tag)
			t.eq(Gen.solve_count(out.region, n, 3), 1, "%s is uniquely solvable" % tag)
			# Every region holds exactly one of the answer's queens, and every
			# cell belongs to a region.
			var seen: Dictionary = {}
			for r in n:
				var g := int(out.region[r][int(out.solution[r])])
				t.check(not seen.has(g), "%s region %d holds one queen" % [tag, g])
				seen[g] = true
			var covered := true
			for r in n:
				for c in n:
					var g := int(out.region[r][c])
					if g < 0 or g >= n:
						covered = false
			t.check(covered, "%s every cell has a region" % tag)
			# Regions are connected: a flood from any cell of a region reaches
			# every cell of it.
			t.check(_connected(out.region, n), "%s every region is connected" % tag)
	# Two queens on neighbouring rows a column apart touch at a corner.
	var flat: Array = [[0, 0, 1], [0, 1, 1], [2, 2, 2]]
	t.check(not Gen.legal(flat, 3, PackedInt32Array([0, 1, 2])), "queens touching at a corner are illegal")
	t.check(not Gen.legal(flat, 3, PackedInt32Array([0, 2, 0])), "two queens in one column are illegal")
	# The same seed twice is the same board.
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	t.check(Gen.generate(a, 7).region == Gen.generate(b, 7).region, "the same seed gives the same court")

static func _connected(region: Array, n: int) -> bool:
	for g in n:
		var cells: Array = []
		for r in n:
			for c in n:
				if int(region[r][c]) == g:
					cells.append(Vector2i(c, r))
		if cells.is_empty():
			return false
		var reached: Dictionary = {cells[0]: true}
		var stack: Array = [cells[0]]
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			for d in Gen.DIRS:
				var q: Vector2i = p + d
				if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
					continue
				if int(region[q.y][q.x]) == g and not reached.has(q):
					reached[q] = true
					stack.append(q)
		if reached.size() != cells.size():
			return false
	return true
