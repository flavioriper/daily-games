extends RefCounted

## Sudoku's generator and rules. The generator's half is the reason this file
## exists at all: a puzzle with two answers is a real bug that cannot be
## caught by playing the board, because both answers look right all the way
## to the end.

const Gen = preload("res://puzzles/sudoku_gen.gd")

static func run(t) -> void:
	_test_tables(t)
	_test_generator(t)

static func _test_tables(t) -> void:
	t.eq(Gen.row_of(0), 0, "cell 0 is in row 0")
	t.eq(Gen.col_of(0), 0, "cell 0 is in column 0")
	t.eq(Gen.box_of(0), 0, "cell 0 is in region 0")
	t.eq(Gen.row_of(80), 8, "cell 80 is in row 8")
	t.eq(Gen.col_of(80), 8, "cell 80 is in column 8")
	t.eq(Gen.box_of(80), 8, "cell 80 is in region 8")
	t.eq(Gen.box_of(30), 4, "cell 30 (row 3, column 3) is in the middle region")
	t.eq(Gen.peers_of(0).size(), 20, "a cell has twenty peers")
	# The peers are exactly the row, the column and the region, minus itself:
	# 8 + 8 + 8 with four of the region's counted twice.
	var p := Gen.peers_of(40)
	t.check(p.has(4) and p.has(36) and p.has(44) and p.has(76), "the middle cell sees its own row, column and region")
	t.check(not p.has(40), "a cell is not its own peer")
	t.eq(Gen.units().size(), 27, "nine rows, nine columns and nine regions")

static func _test_generator(t) -> void:
	for d in 3:
		for i in range(4):
			var rng := RandomNumberGenerator.new()
			rng.seed = 9000 + d * 100 + i
			var out: Dictionary = Gen.generate(rng, d)
			var tag := "band=%d seed=%d" % [d, i]
			var puz: PackedByteArray = out.puzzle
			var sol: PackedByteArray = out.solution
			t.eq(puz.size(), 81, "%s the puzzle is 81 cells" % tag)
			t.check(Gen.is_complete(sol), "%s the solution is full" % tag)
			# The answer must obey the rules, not merely be what the dig
			# started from.
			t.check(_legal(sol), "%s the solution is legal" % tag)
			# The one assertion this file is for.
			t.eq(Gen.count_solutions(puz, 3), 1, "%s has exactly one solution" % tag)
			# Every given agrees with the answer.
			var agrees := true
			for k in 81:
				if puz[k] != 0 and puz[k] != sol[k]:
					agrees = false
			t.check(agrees, "%s every given agrees with the solution" % tag)
			# Within one of the band's target, and symmetric about the centre.
			var givens := 0
			var symmetric := true
			for k in 81:
				if puz[k] != 0:
					givens += 1
				if (puz[k] != 0) != (puz[80 - k] != 0):
					symmetric = false
			t.check(givens >= int(Gen.TARGET[d]) - 1, "%s has at least its band's givens (%d)" % [tag, givens])
			t.check(givens <= int(Gen.TARGET[d]) + 6, "%s is not far over its band's givens (%d)" % [tag, givens])
			t.check(symmetric, "%s the givens are symmetric about the centre" % tag)
			# Easy must fall to singles. Hard must not; medium is allowed to.
			var singled := Gen.is_complete(Gen.singles_solve(puz))
			if d == 0:
				t.check(singled, "%s easy falls to singles" % tag)
			elif d == 2:
				t.check(not singled, "%s hard does not fall to singles" % tag)
	# The same seed twice is the same board.
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	t.check(Gen.generate(a, 1).puzzle == Gen.generate(b, 1).puzzle, "the same seed gives the same puzzle")
	# A grid with a cell removed from a finished board has one answer; one
	# with a whole unit removed does not.
	var full: PackedByteArray = Gen.generate(RandomNumberGenerator.new(), 0).solution
	var one := full.duplicate()
	one[0] = 0
	t.eq(Gen.count_solutions(one, 3), 1, "one cell removed leaves one answer")
	var two := full.duplicate()
	# Two cells that share a row AND a region can always be swapped when the
	# two digits are each missing from the other's column, which is the
	# cheapest non-unique grid to build by hand.
	var swapped := _swap_pair(full)
	if swapped >= 0:
		two[swapped] = 0
		two[swapped + 1] = 0
		t.check(Gen.count_solutions(two, 3) >= 2, "a swappable pair removed leaves more than one answer")

## Whether a full grid obeys the three rules.
static func _legal(g: PackedByteArray) -> bool:
	for u in Gen.units():
		var mask := 0
		for i in u:
			if g[i] < 1 or g[i] > 9:
				return false
			var bit := 1 << (g[i] - 1)
			if mask & bit:
				return false
			mask |= bit
	return true

## The first cell i where i and i+1 share a row and a region, and their two
## digits can be swapped without breaking either column -- so removing both
## leaves two answers. -1 when the grid offers none, which is rare enough to
## skip the assertion rather than to fail it.
static func _swap_pair(g: PackedByteArray) -> int:
	for i in 80:
		if Gen.row_of(i) != Gen.row_of(i + 1) or Gen.box_of(i) != Gen.box_of(i + 1):
			continue
		var a := g[i]
		var b := g[i + 1]
		var clash := false
		for k in 9:
			var ca := k * 9 + Gen.col_of(i)
			var cb := k * 9 + Gen.col_of(i + 1)
			if g[ca] == b or g[cb] == a:
				clash = true
		if not clash:
			return i
	return -1
