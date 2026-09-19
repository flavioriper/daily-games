extends RefCounted

## Queens' generator (puzzles/queens_gen.gd): across 7x7/8x8/9x9 and five
## seeds each, checks a generated court has one queen a row, its answer is
## legal and the only seating, every region holds exactly one answer queen
## and is connected, and every cell has a region; plus `legal`'s two
## rejections (a corner touch, a shared column) and that a seed reproduces
## the same court.

const Gen = preload("res://puzzles/queens_gen.gd")
const State = preload("res://puzzles/queens_state.gd")

static func run(t) -> void:
	_test_generator(t)
	_test_state(t)

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

## A 5x5 court by hand, whose answer is forced cell by cell: region 4 is the
## one cell (4,4), so its queen is given; row 3's region 3 then has only
## (2,3) clear of her; region 2 then only (0,2); region 0 only (1,0); and
## region 1 takes (3,1). Answer (row -> col): [1, 3, 0, 2, 4].
##   region:  0 0 0 1 1
##            0 0 1 1 1
##            2 2 1 1 1
##            2 2 3 3 3
##            2 2 3 3 4
static func _court() -> State:
	var s := State.new()
	s.n = 5
	s.region = [
		[0, 0, 0, 1, 1],
		[0, 0, 1, 1, 1],
		[2, 2, 1, 1, 1],
		[2, 2, 3, 3, 3],
		[2, 2, 3, 3, 4],
	]
	s.solution = PackedInt32Array([1, 3, 0, 2, 4])
	s.queens = {}
	s.crosses = {}
	s.locked = {}
	s.history = []
	s.recompute()
	return s

static func _test_state(t) -> void:
	var s := _court()
	t.check(Gen.legal(s.region, 5, s.solution), "the hand court's answer is legal")
	t.eq(Gen.solve_count(s.region, 5, 3), 1, "the hand court has one answer")
	t.eq(s.mark_at(Vector2i(0, 0)), State.BLANK, "a bare court is blank")

	# Seat a queen: her row, column, region and eight neighbours are seen.
	var q := Vector2i(2, 1)
	var res: Dictionary = s.seat(q)
	t.check(res.ok, "a queen seats on a bare cell")
	t.eq(s.mark_at(q), State.QUEEN, "the cell holds the queen")
	t.eq(s.mark_at(Vector2i(4, 1)), State.AUTO, "her row is crossed")
	t.eq(s.mark_at(Vector2i(2, 4)), State.AUTO, "her column is crossed")
	t.eq(s.mark_at(Vector2i(4, 0)), State.AUTO, "her region is crossed")
	t.eq(s.mark_at(Vector2i(1, 2)), State.AUTO, "her diagonal neighbour is crossed")
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "a cell she cannot see stays blank")
	# Her row (4), her column (4), the rest of her region ((3,0), (4,0), (3,2),
	# (4,2)) and the two neighbours not already counted ((1,0), (1,2)).
	t.eq(s.sees(q).size(), 14, "she sees fourteen cells on this court")
	t.eq(State.distance(q, Vector2i(4, 4)), 3, "distance is the king's move")

	# A crown on a seen cell is refused; on a given queen, too.
	res = s.seat(Vector2i(4, 1))
	t.check(not res.ok and res.why == State.SEEN, "a seen cell refuses a queen")
	t.eq(s.history.size(), 1, "a refusal is not a move")

	# The player's cross, and a queen replacing it.
	t.check(s.cross(Vector2i(0, 4)), "a cross lays on a bare cell")
	t.eq(s.mark_at(Vector2i(0, 4)), State.CROSS, "the player's cross is her own")
	t.check(not s.cross(Vector2i(4, 1)), "a cross does not lay on a seen cell")
	t.check(not s.cross(q), "a cross does not lay on a queen")
	t.check(s.seat(Vector2i(0, 4)).ok, "a queen replaces the player's cross")
	t.eq(s.queens.size(), 2, "two queens seated")
	t.eq(s.queens_left(), 3, "three to go")

	# Undo takes the queen off and the cross comes back; undo again and the
	# cross goes too.
	t.eq(s.undo().size(), 1, "undo returns the one cell")
	t.eq(s.mark_at(Vector2i(0, 4)), State.CROSS, "undoing a seat restores the cross")
	s.undo()
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "undoing a cross clears it")

	# Lift the queen: her crosses leave with her.
	res = s.lift(q)
	t.check(res.ok, "a queen lifts")
	t.eq(s.mark_at(Vector2i(4, 1)), State.BLANK, "her crosses leave with her")
	t.eq(s.seen.size(), 0, "nothing is seen on an empty court")
	s.undo()
	t.eq(s.mark_at(q), State.QUEEN, "undoing a lift seats her again")
	t.eq(s.mark_at(Vector2i(4, 1)), State.AUTO, "and her crosses return")

	# A sweep is one move however many cells it crossed, and skips seen cells.
	var path: Array = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]
	var changed: Array = s.sweep(path, true)
	t.eq(changed.size(), 3, "a sweep skips the cell the queen sees")
	t.eq(s.mark_at(Vector2i(1, 4)), State.CROSS, "a swept cell is crossed")
	s.undo()
	t.eq(s.mark_at(Vector2i(1, 4)), State.BLANK, "one undo takes the whole sweep back")
	s.sweep(path, true)
	changed = s.sweep([Vector2i(0, 4), Vector2i(1, 4)], false)
	t.eq(changed.size(), 2, "a rub-out takes the player's crosses")
	t.eq(s.mark_at(Vector2i(0, 4)), State.BLANK, "a rubbed-out cell is blank")

	# The hint seats the first missing answer queen, lifting a wrong queen in
	# its way, and pins it.
	var s2 := _court()
	s2.seat(Vector2i(2, 0))   # wrong: the answer's row 0 queen is at column 1
	var out: Dictionary = s2.hint()
	t.eq(out.cell, Vector2i(1, 0), "the hint seats row 0's answer")
	t.eq(out.lifted, [Vector2i(2, 0)], "the wrong queen beside it is lifted")
	t.eq(s2.mark_at(Vector2i(2, 0)), State.AUTO, "the lifted queen's cell is now seen")
	t.check(s2.locked.has(Vector2i(1, 0)), "the hint's queen is pinned")
	t.check(s2.history.is_empty(), "a hint clears the history")
	res = s2.lift(Vector2i(1, 0))
	t.check(not res.ok and res.why == State.PINNED, "a pinned queen refuses to lift")
	t.eq(s2.wrong_queens().size(), 0, "no wrong queens after the hint")

	# Reset keeps the given queen and clears the rest.
	s2.seat(Vector2i(3, 2))
	s2.cross(Vector2i(0, 4))
	var cleared: Array = s2.reset()
	t.eq(cleared.size(), 2, "reset clears the player's queen and cross")
	t.eq(s2.mark_at(Vector2i(1, 0)), State.QUEEN, "reset keeps the given queen")

	# Seat the answer: the fifth queen is the win.
	var s3 := _court()
	for r in 5:
		t.check(not s3.is_solved(), "not solved with %d queens" % r)
		t.check(s3.seat(Vector2i(int(s3.solution[r]), r)).ok, "answer queen %d seats" % r)
	t.check(s3.is_solved(), "the answer is solved")
	t.eq(s3.queens_left(), 0, "none to go")
	t.eq(s3.share_glyphs().split("\n").size(), 6, "five rows and a trailing newline")
	t.check(s3.share_glyphs().contains("👑"), "the share carries a crown")
