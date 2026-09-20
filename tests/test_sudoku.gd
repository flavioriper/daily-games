extends RefCounted

## Sudoku's generator and rules. The generator's half is the reason this file
## exists at all: a puzzle with two answers is a real bug that cannot be
## caught by playing the board, because both answers look right all the way
## to the end.

const Gen = preload("res://puzzles/sudoku_gen.gd")
const State = preload("res://puzzles/sudoku_state.gd")

static func run(t) -> void:
	_test_tables(t)
	_test_generator(t)
	_test_deadline(t)
	_test_state(t)

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
	# The same seed twice is the same board. Budget disabled (-1) on both
	# calls: generate()'s output is otherwise contingent on wall-clock timing
	# as well as the seed since round 1 added TIME_BUDGET_MS, and this
	# assertion is about the seed, not about whether two calls happen to
	# cross the same 300 ms deadline the same way on whatever machine runs
	# the suite -- a CI runner slower than this Mac could see one call clip
	# and the other not, for two puzzles that would otherwise be identical.
	var a := RandomNumberGenerator.new()
	a.seed = 4242
	var b := RandomNumberGenerator.new()
	b.seed = 4242
	t.check(Gen.generate(a, 1, -1).puzzle == Gen.generate(b, 1, -1).puzzle, "the same seed gives the same puzzle")
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

## dig()'s intra-attempt deadline (round 1 of the code review): checked
## before every pair, so a caller past its budget stops removing rather than
## finish the dig it started. An already-expired deadline is the maximally
## adversarial case -- past before dig() is even entered, so no pair is ever
## tried and sol comes back untouched -- and it is the one this suite would
## otherwise never exercise, since generate()'s own attempts never cross the
## deadline mid-pair in practice (see the probe figures in the commit
## history). Covering it here is what stops a future rewrite of dig()'s
## control flow from moving the check inside the zero-then-restore window
## and silently reintroducing round 1's hang with the suite still green.
static func _test_deadline(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var sol := Gen.full_grid(rng)
	var expired := Time.get_ticks_msec() - 1
	var puz := Gen.dig(rng, sol, 30, expired)
	t.eq(puz.size(), 81, "an expired deadline still returns 81 cells")
	t.eq(Gen.count_solutions(puz, 3), 1, "an expired deadline's puzzle still has exactly one solution")
	var agrees := true
	for k in 81:
		if puz[k] != 0 and puz[k] != sol[k]:
			agrees = false
	t.check(agrees, "an expired deadline's puzzle still agrees with the solution")
	# "Returns the full grid" is the legitimate answer here, not a bug: no
	# pair was ever tried, so nothing was ever removed.
	t.check(Gen.is_complete(puz), "an already-expired deadline returns the solution untouched")

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

static func _test_state(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var s := State.new()
	s.setup(rng, 1)

	# The first empty cell, and the first given.
	var empty := -1
	var filled := -1
	for i in 81:
		if empty < 0 and s.given[i] == 0:
			empty = i
		if filled < 0 and s.given[i] != 0:
			filled = i
	t.check(empty >= 0 and filled >= 0, "the board has both an empty cell and a given")

	# A given is refused and nothing changes.
	var before := s.grid[filled]
	t.eq(s.place(filled, 5), State.GIVEN, "a digit at a given is refused")
	t.eq(s.grid[filled], before, "a refused place changes nothing")
	t.eq(s.history.size(), 0, "a refused place writes no history")

	# A digit goes in, and the same digit again takes it out.
	t.eq(s.place(empty, 7), State.OK, "a digit goes into an empty cell")
	t.eq(s.grid[empty], 7, "the cell holds it")
	t.eq(s.place(empty, 7), State.OK, "the same digit again is accepted")
	t.eq(s.grid[empty], 0, "and takes it out")
	t.eq(s.undo(), empty, "undo reports the cell")
	t.eq(s.grid[empty], 7, "undo puts the digit back")
	t.eq(s.undo(), empty, "undo again reports the cell")
	t.eq(s.grid[empty], 0, "undo again empties it")
	t.eq(s.undo(), -1, "undo on an empty log is -1")

	# Pencil marks: empty cells only.
	t.eq(s.mark(filled, 3), State.GIVEN, "a mark at a given is refused")
	t.eq(s.place(empty, 4), State.OK, "fill the cell")
	t.eq(s.mark(empty, 3), State.FILLED, "a mark at a filled cell is refused")
	s.undo()
	t.eq(s.mark(empty, 3), State.OK, "a mark goes into an empty cell")
	t.check(s.has_note(empty, 3), "the mark is there")
	t.eq(s.mark(empty, 3), State.OK, "the same mark again is accepted")
	t.check(not s.has_note(empty, 3), "and toggles it off")

	# THE assertion this file exists for: placing a digit strikes it off the
	# peers' marks, and undo puts every one of them back.
	s.clear_board()
	var peer := -1
	for j in Gen.peers_of(empty):
		if s.given[j] == 0:
			peer = j
			break
	t.check(peer >= 0, "the empty cell has an empty peer")
	t.eq(s.mark(peer, 6), State.OK, "pencil a 6 into the peer")
	t.check(s.has_note(peer, 6), "the peer holds the mark")
	t.eq(s.place(empty, 6), State.OK, "place a 6 where the peer can see it")
	t.check(not s.has_note(peer, 6), "the peer's 6 is struck off")
	t.eq(s.undo(), empty, "undo the placement")
	t.check(s.has_note(peer, 6), "the peer's 6 comes back")

	# A cell's own marks survive a round trip through a digit.
	s.clear_board()
	t.eq(s.mark(empty, 2), State.OK, "pencil a 2")
	t.eq(s.mark(empty, 8), State.OK, "pencil an 8")
	t.eq(s.place(empty, 5), State.OK, "then place a 5 over them")
	t.eq(s.notes[empty], 0, "the marks are gone while a digit is in")
	s.undo()
	t.check(s.has_note(empty, 2) and s.has_note(empty, 8), "undo brings both marks back")

	# Derived, not cached. Digit 9 is not safe to hardcode here: a real
	# puzzle's own givens can already hold it somewhere among `empty`'s
	# peers (seed 31337's medium band does, at band 1), which would make
	# `empty` clash with a given the moment 9 goes in, undo or no undo, and
	# would throw off "one placed leaves the baseline one lower" by however
	# many givens of 9 are already on the board. So the test finds a digit
	# free of every given among `empty`'s peers and measures `remaining`
	# against its own baseline rather than a number assumed off an empty
	# board.
	s.clear_board()
	var a := -1
	for j in Gen.peers_of(empty):
		if s.given[j] == 0 and a < 0:
			a = j
	t.check(a >= 0, "found a peer to clash with")
	var clash_d := 0
	for d in range(1, 10):
		var taken := false
		for j in Gen.peers_of(empty):
			if s.grid[j] == d:
				taken = true
				break
		if not taken:
			clash_d = d
			break
	t.check(clash_d > 0, "found a digit none of the peers already give")
	var base := s.remaining(clash_d)
	s.place(empty, clash_d)
	s.place(a, clash_d)
	var cl: Dictionary = s.clashes()
	t.check(cl.has(empty) and cl.has(a), "two of a digit in one unit clash")
	t.check(s.twins(empty).has(a), "and are twins of each other")
	s.undo()
	t.check(not s.clashes().has(empty), "lifting one clears the clash with no bookkeeping")
	t.eq(s.remaining(clash_d), base - 1, "one placed digit leaves the baseline one lower")

	# Check names only what is wrong against the answer, and never a given.
	s.clear_board()
	var bad := (int(s.sol[empty]) % 9) + 1
	s.place(empty, bad)
	var w: PackedInt32Array = s.wrong()
	t.check(w.has(empty), "a wrong digit is found by check")
	s.undo()
	s.place(empty, int(s.sol[empty]))
	t.check(not s.wrong().has(empty), "a right digit is not")

	# Solved is the whole grid agreeing with the answer.
	s.clear_board()
	t.check(not s.is_solved(), "a fresh board is not solved")
	for i in 81:
		if s.given[i] == 0:
			s.place(i, int(s.sol[i]))
	t.check(s.is_solved(), "filling every cell from the answer solves it")
	# A full grid with one digit wrong is not solved.
	var last := -1
	for i in 81:
		if s.given[i] == 0:
			last = i
	s.place(last, int(s.sol[last]))          # takes it out
	s.place(last, (int(s.sol[last]) % 9) + 1)  # puts a wrong one in
	t.check(not s.is_solved(), "a full grid with a wrong digit is not solved")

	# Reset leaves the givens and nothing else.
	s.clear_board()
	var left := 0
	for i in 81:
		if s.grid[i] != 0:
			left += 1
		if s.notes[i] != 0:
			left += 100
	var givens := 0
	for i in 81:
		if s.given[i] != 0:
			givens += 1
	t.eq(left, givens, "reset leaves exactly the givens and no marks")
	t.eq(s.history.size(), 0, "and no history")

	# Three hints, each one right, each one undoable.
	s.clear_board()
	t.eq(s.hints_left, State.HINTS, "three hints to start")
	var h := s.hint()
	t.check(h >= 0, "a hint fills a cell")
	t.eq(s.grid[h], s.sol[h], "with the right digit")
	t.eq(s.hints_left, State.HINTS - 1, "and spends one")
	s.undo()
	t.eq(s.grid[h], 0, "a hint can be undone")
