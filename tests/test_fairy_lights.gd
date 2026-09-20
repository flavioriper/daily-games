extends RefCounted

## Fairy Lights' generator. The state's half arrives with the board; this
## file is the promise -- that every garden the day hands out is a spanning
## tree the propagate-only solver can finish, so nobody ever has to guess,
## and that the deal opens dark and scrambled rather than half-solved.
## A board that needs a guess cannot be caught by playing it: it looks
## exactly like a board that is merely hard, right up to the coin flip.

const Gen = preload("res://puzzles/fairy_lights_gen.gd")
const State = preload("res://puzzles/fairy_lights_state.gd")

static func run(t) -> void:
	_test_turning(t)
	_test_bands(t)
	_test_tree(t)
	_test_promise(t)
	_test_deal(t)
	_test_seeded(t)
	_test_state(t)

## 1. Turning four times is the identity, and cw/ccw are inverses.
static func _test_turning(t) -> void:
	for m in range(16):
		t.eq(Gen.cw(Gen.cw(Gen.cw(Gen.cw(m)))), m, "mask %d turned four times is itself" % m)
		t.eq(Gen.ccw(Gen.cw(m)), m, "mask %d turned back is itself" % m)
		t.eq(Gen.cw(m) & ~15, 0, "mask %d stays inside four bits" % m)
	t.eq(Gen.cw(Gen.N), Gen.E, "north turns to east")
	t.eq(Gen.cw(Gen.E), Gen.S, "east turns to south")
	t.eq(Gen.cw(Gen.S), Gen.W, "south turns to west")
	t.eq(Gen.cw(Gen.W), Gen.N, "west turns to north")
	# The distinct rotations are the whole of the piece set: a stub four, an
	# elbow four, a tee four, a straight two, a cross one.
	t.eq(Gen.rotations(Gen.N).size(), 4, "a stub has four rotations")
	t.eq(Gen.rotations(Gen.N | Gen.E).size(), 4, "an elbow has four rotations")
	t.eq(Gen.rotations(Gen.N | Gen.E | Gen.S).size(), 4, "a tee has four rotations")
	t.eq(Gen.rotations(Gen.N | Gen.S).size(), 2, "a straight has two rotations")
	t.eq(Gen.rotations(15).size(), 1, "a cross has one rotation")
	for m in range(1, 16):
		var rs: Array = Gen.rotations(m)
		t.check(rs.has(m), "mask %d is one of its own rotations" % m)
		for r in rs:
			t.eq(_degree(r), _degree(m), "a rotation of %d keeps its degree" % m)

## 2. Every band builds: n is 5/6/7, sol.size() == n*n, post is in range.
static func _test_bands(t) -> void:
	for d in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4100 + d
		var out: Dictionary = Gen.build(rng, d)
		var n: int = out.n
		t.eq(n, Gen.SIZES[d], "band %d is %dx%d" % [d, Gen.SIZES[d], Gen.SIZES[d]])
		t.eq(out.sol.size(), n * n, "band %d fills every cell" % d)
		t.eq(out.deal.size(), n * n, "band %d deals every cell" % d)
		t.check(out.post >= 0 and out.post < n * n, "band %d seats the post on the grid" % d)
		t.check(out.attempts >= 1 and out.attempts <= Gen.BUDGET, "band %d stays inside the budget" % d)
		# An even side has four middle cells and the seed picks one; an odd
		# side has exactly one. Either way the post is in the middle block.
		var lo: int = (n - 1) / 2
		var hi: int = int(ceil((n - 1) / 2.0))
		var pr: int = out.post / n
		var pc: int = out.post % n
		t.check(pr >= lo and pr <= hi and pc >= lo and pc <= hi, "band %d puts the post in the middle" % d)

## 3. The solution is a tree: exactly n*n-1 edges, every cell reachable from
##    the post, and no cell has a stub pointing off the grid.
static func _test_tree(t) -> void:
	for d in 3:
		for i in range(6):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4200 + d * 50 + i
			var out: Dictionary = Gen.build(rng, d)
			var n: int = out.n
			var sol: PackedInt32Array = out.sol
			var tag := "band=%d seed=%d" % [d, i]
			var stubs := 0
			var off := 0
			for c in range(n * n):
				stubs += _degree(sol[c])
				for dir in range(4):
					if sol[c] & (1 << dir) == 0:
						continue
					var r: int = c / n + Gen.DR[dir]
					var col: int = c % n + Gen.DC[dir]
					if r < 0 or col < 0 or r >= n or col >= n:
						off += 1
					else:
						# A tree edge is open from both ends or it is not an
						# edge; a one-sided stub inside the grid is a bug.
						var j: int = r * n + col
						if sol[j] & (1 << ((dir + 2) % 4)) == 0:
							off += 1
			t.eq(off, 0, "%s no stub in the solution points at a wall or a closed neighbour" % tag)
			t.eq(stubs / 2, n * n - 1, "%s the solution has exactly n*n-1 edges" % tag)
			t.eq(_reach(n, out.post, sol), n * n, "%s every cell hangs off the post" % tag)
			t.check(_degree(sol[out.post]) >= 2, "%s the post has at least two arms" % tag)
			var lanterns := 0
			for c in range(n * n):
				if _degree(sol[c]) == 1:
					lanterns += 1
			t.check(lanterns >= int(ceil(n * n * 0.22)), "%s at least 22%% of the field is lanterns" % tag)

## 4. Every board over 40 seeds a band comes back proved, solvable() refuses
##    a board that genuinely needs a guess, and its verdict is about shape
##    and never about the orientation it is handed.
static func _test_promise(t) -> void:
	# The negative control, and the only assertion in this file that fails if
	# the solver goes unsound. Every other check here is a positive: a
	# `solvable()` stubbed to `return true` leaves them all green, because
	# `build()` only ever hands back trees that function has already
	# approved, so asking it again re-runs a call that cannot disagree with
	# itself. A 2x2 of straights is the smallest Netwalk board no amount of
	# propagation can settle -- every cell has two walls and a straight has
	# only two rotations, so the candidate sets empty out -- and it must be
	# refused.
	t.check(not Gen.solvable(2, PackedInt32Array([5, 5, 5, 5])),
		"a 2x2 of straights cannot be settled by propagation and is refused")
	t.check(not Gen.solvable(2, PackedInt32Array([10, 10, 10, 10])),
		"the same four straights laid the other way round are refused too")
	for d in 3:
		var unproved := 0
		var disagreed := 0
		var orientation := 0
		for i in range(40):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4300 + d * 1000 + i
			var out: Dictionary = Gen.build(rng, d)
			if not out.proved:
				unproved += 1
			var verdict: bool = Gen.solvable(out.n, out.sol)
			if not verdict:
				disagreed += 1
			# The solver reads a cell's *shape* -- its set of distinct
			# rotations -- and never the orientation it happens to arrive in.
			# Turning every cell a quarter turn is not the same board, but it
			# is the same shape in every cell, so the verdict may not move.
			# A solver that seeded its candidates from the given mask in any
			# order-dependent way would come apart here.
			var turned := PackedInt32Array()
			turned.resize(out.sol.size())
			for c in range(out.sol.size()):
				turned[c] = Gen.cw(out.sol[c])
			if Gen.solvable(out.n, turned) != verdict:
				orientation += 1
		t.eq(unproved, 0, "band %d proves every one of forty boards" % d)
		t.eq(disagreed, 0, "band %d: solvable() agrees with build() on every board" % d)
		t.eq(orientation, 0, "band %d: the verdict is about shape, not the orientation handed in" % d)

## 5-7. The deal is a rotation of the solution cell for cell, it is not the
##      solution, and it opens dark.
static func _test_deal(t) -> void:
	for d in 3:
		for i in range(8):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4400 + d * 50 + i
			var out: Dictionary = Gen.build(rng, d)
			var n: int = out.n
			var sol: PackedInt32Array = out.sol
			var deal: PackedInt32Array = out.deal
			var tag := "band=%d seed=%d" % [d, i]
			var stray := 0
			var turnable := 0
			var wrong := 0
			for c in range(n * n):
				var rs: Array = Gen.rotations(sol[c])
				if not rs.has(deal[c]):
					stray += 1
				if rs.size() > 1:
					turnable += 1
				else:
					# A cross is already every way round: it is never dealt
					# anywhere but where it stands.
					if deal[c] != sol[c]:
						stray += 1
				if deal[c] != sol[c]:
					wrong += 1
			t.eq(stray, 0, "%s every dealt piece is a rotation of its own answer" % tag)
			t.check(wrong >= int(ceil(turnable * 0.6)),
				"%s at least 60%% of the turnable pieces are out of place (%d of %d)" % [tag, wrong, turnable])
			var lit := _reach(n, out.post, deal)
			t.check(lit <= int(n * n * 0.25),
				"%s the deal opens with at most a quarter of the garden live (%d of %d)" % [tag, lit, n * n])

## 8. The same seed twice is the same garden, and two seeds differ.
static func _test_seeded(t) -> void:
	for d in 3:
		var a := RandomNumberGenerator.new()
		a.seed = 4500 + d
		var b := RandomNumberGenerator.new()
		b.seed = 4500 + d
		var c := RandomNumberGenerator.new()
		c.seed = 4600 + d
		var one: Dictionary = Gen.build(a, d)
		var two: Dictionary = Gen.build(b, d)
		var other: Dictionary = Gen.build(c, d)
		t.eq(one.sol, two.sol, "band %d: the same seed grows the same tree" % d)
		t.eq(one.deal, two.deal, "band %d: the same seed deals the same board" % d)
		t.eq(one.post, two.post, "band %d: the same seed seats the same post" % d)
		t.check(one.sol != other.sol or one.deal != other.deal,
			"band %d: another seed is another garden" % d)

static func _degree(m: int) -> int:
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1)

## 9.  A fresh state is not solved, and grid == deal.
## 10. turn() on an ordinary cell returns OK, advances turns by one, and
##     leaves grid[i] == cw(previous).
## 11. Four turns of one cell come back to where they started.
## 12. turn() on a cross returns CROSS, does not change grid, and does not
##     count a turn.
## 13. Setting grid to sol makes is_solved() true; turning any one
##     non-cross cell off it makes it false again.
## 14. depths(): post is 0, a cell joined to the post is 1, and a cell whose
##     stub faces a closed neighbour is -1.
## 15. matched() is symmetric: matched(i, side) == matched(j, opposite)
##     for every neighbouring pair, and false at the grid's edge.
## 16. undo() turns the last cell back and returns it; on an empty log it
##     returns -1 and changes nothing.
## 17. hint() settles the first unsolved cell in reading order to sol,
##     pins it, counts a hint, and empties the undo log.
## 18. turn() on a pinned cell returns PINNED and changes nothing.
## 19. reset_board() puts every unpinned cell back to deal and leaves a
##     pinned cell where the hint put it.
## 20. Solving a whole board by turning each cell to sol reaches
##     is_solved() with no cell left loose().
## 21. lanterns() returns the degree-1 cells of the real board, in reading
##     order -- Task 3 seats a lantern face off it, so it needs its own
##     assertion rather than riding along with something else.
static func _test_state(t) -> void:
	for d in 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4700 + d

		# 9.
		var fresh := State.new()
		fresh.start(rng, d)
		var tag := "band=%d" % d
		t.check(not fresh.is_solved(), "%s a fresh state is not solved" % tag)
		t.eq(fresh.grid, fresh.deal, "%s a fresh state's grid is the deal" % tag)

		# 10.
		var i10 := _first_turnable(fresh)
		var prev10: int = fresh.grid[i10]
		var turns10 := fresh.turns
		t.eq(fresh.turn(i10), State.OK, "%s turning an ordinary cell returns OK" % tag)
		t.eq(fresh.turns, turns10 + 1, "%s turning an ordinary cell advances turns" % tag)
		t.eq(fresh.grid[i10], Gen.cw(prev10), "%s the turned cell is the previous cell, turned" % tag)

		# 11.
		var i11 := _first_turnable(fresh)
		var start11: int = fresh.grid[i11]
		for _k in range(4):
			fresh.turn(i11)
		t.eq(fresh.grid[i11], start11, "%s four turns of one cell come back to where it started" % tag)

		# 12.
		var cross := State.new()
		cross.start(rng, d)
		var i12 := 0
		cross.grid[i12] = 15
		var grid12 := cross.grid.duplicate()
		var turns12 := cross.turns
		t.eq(cross.turn(i12), State.CROSS, "%s turning a cross returns CROSS" % tag)
		t.eq(cross.grid, grid12, "%s turning a cross does not change the grid" % tag)
		t.eq(cross.turns, turns12, "%s turning a cross does not count a turn" % tag)

		# 13.
		var solved := State.new()
		solved.start(rng, d)
		solved.grid = solved.sol.duplicate()
		t.check(solved.is_solved(), "%s grid == sol is solved" % tag)
		var i13 := _first_turnable(solved)
		solved.turn(i13)
		t.check(not solved.is_solved(), "%s turning one non-cross cell off sol is unsolved again" % tag)

		# 13b. The control that tells the rule from the answer: `grid == sol`
		# can be true while the board is still unsolved, because "every stub
		# meets a stub" says nothing about whether the tree it forms actually
		# reaches the post. n=2, post=0, grid=sol=[E,W,E,W]: cell 0 meets
		# cell 1 and cell 2 meets cell 3, so every stub is matched and
		# loose() is 0 everywhere -- but nothing joins that pair to the post,
		# so depths() only reaches {0,1} and is_solved() must be false. A
		# gutted `is_solved()` that returns `grid == sol` passes this fixture
		# by accident; the real rule cannot.
		var ctl := State.new()
		ctl.n = 2
		ctl.post = 0
		var gctl := PackedInt32Array([Gen.E, Gen.W, Gen.E, Gen.W])
		ctl.grid = gctl
		ctl.sol = gctl.duplicate()
		for k in 4:
			t.eq(ctl.loose(k), 0, "band=%d control: cell %d has every stub matched" % [d, k])
		t.eq(ctl.depths(), PackedInt32Array([0, 1, -1, -1]),
			"band=%d control: depths() only reaches the post's own pair" % d)
		t.check(not ctl.is_solved(),
			"band=%d control: grid == sol is not enough -- unreached cells make it unsolved" % d)

		# 14.
		var tiny := State.new()
		tiny.n = 3
		tiny.post = 4
		var g14 := PackedInt32Array()
		g14.resize(9)
		g14.fill(0)
		g14[4] = Gen.S
		g14[7] = Gen.N
		g14[1] = Gen.S
		tiny.grid = g14
		var depths14 := tiny.depths()
		t.eq(depths14[4], 0, "%s depths(): the post is 0" % tag)
		t.eq(depths14[7], 1, "%s depths(): a cell joined to the post is 1" % tag)
		t.eq(depths14[1], -1, "%s depths(): a stub facing a closed neighbour is -1" % tag)
		# loose() is asserted at a specific non-zero mask, not merely "not
		# zero": cell 1's only stub faces south into the post (cell 4), which
		# has no north bit, so that stub is unmatched and loose(1) is exactly
		# Gen.S. Spec rule 5 draws every loose end straight off loose(), so a
		# gutted `return 0` would draw every unfinished join on the board as
		# though it were already joined.
		t.eq(tiny.loose(1), Gen.S, "%s loose(): cell 1's south stub faces the post's closed side" % tag)
		t.eq(tiny.loose(4), 0, "%s loose(): the post's own stub is matched to cell 7" % tag)

		# 14b. depths() must reflect a move the instant it happens, never a
		# cached snapshot -- the guard that matters most going into Task 3,
		# where the wash wants a depth snapshot per settle and a cache is the
		# obvious shortcut to reach for. Hand-built so it does not depend on
		# a seed: the post starts facing east (no stub south), so cell 2 is
		# unreached; turning the post once brings it to face south, which
		# meets cell 2's own north-facing stub, and depths() must show cell 2
		# joined on the very next call.
		var cache := State.new()
		cache.n = 2
		cache.post = 0
		cache.grid = PackedInt32Array([Gen.E, 0, Gen.N, 0])
		cache.pinned = PackedByteArray([0, 0, 0, 0])
		var before_cache := cache.depths()
		t.eq(before_cache[2], -1, "%s depths() cache guard: cell 2 starts unreached" % tag)
		t.eq(cache.turn(0), State.OK, "%s depths() cache guard: the post turns" % tag)
		var after_cache := cache.depths()
		t.eq(after_cache[2], 1, "%s depths() cache guard: cell 2 is reached the instant the post turns" % tag)
		t.check(before_cache != after_cache,
			"%s depths() reflects the move, and is never a stale cache" % tag)

		# 15.
		var sym := State.new()
		sym.start(rng, d)
		for i in sym.n * sym.n:
			var r: int = i / sym.n
			var c: int = i % sym.n
			for dd in range(4):
				var side := 1 << dd
				var a: int = r + Gen.DR[dd]
				var b: int = c + Gen.DC[dd]
				if a < 0 or b < 0 or a >= sym.n or b >= sym.n:
					t.check(not sym.matched(i, side), "%s matched() is false at the grid's edge" % tag)
					continue
				var j: int = a * sym.n + b
				var od := 1 << ((dd + 2) % 4)
				t.eq(sym.matched(i, side), sym.matched(j, od),
					"%s matched(%d, %d) == matched(%d, %d)" % [tag, i, side, j, od])

		# 16.
		var un := State.new()
		un.start(rng, d)
		t.eq(un.undo(), -1, "%s undo() on an empty log returns -1" % tag)
		var i16 := _first_turnable(un)
		var prev16: int = un.grid[i16]
		un.turn(i16)
		t.eq(un.undo(), i16, "%s undo() returns the cell just turned" % tag)
		t.eq(un.grid[i16], prev16, "%s undo() turns the cell back" % tag)
		t.eq(un.undo(), -1, "%s undo() on an empty log again returns -1" % tag)

		# 17.
		var hi := State.new()
		hi.start(rng, d)
		hi.turn(_first_turnable(hi))
		var want17 := -1
		for k in hi.n * hi.n:
			if hi.grid[k] != hi.sol[k]:
				want17 = k
				break
		var hints17 := hi.hints
		var settled17 := hi.hint()
		t.eq(settled17, want17, "%s hint() settles the first unsolved cell in reading order" % tag)
		t.eq(hi.grid[settled17], hi.sol[settled17], "%s hint() settles the cell to sol" % tag)
		t.eq(hi.pinned[settled17], 1, "%s hint() pins the settled cell" % tag)
		t.eq(hi.hints, hints17 + 1, "%s hint() counts a hint" % tag)
		t.eq(hi.undo(), -1, "%s hint() empties the undo log" % tag)

		# 18.
		var pin := State.new()
		pin.start(rng, d)
		var i18: int = pin.hint()
		var prev18: int = pin.grid[i18]
		var turns18 := pin.turns
		t.eq(pin.turn(i18), State.PINNED, "%s turning a pinned cell returns PINNED" % tag)
		t.eq(pin.grid[i18], prev18, "%s turning a pinned cell does not change the grid" % tag)
		t.eq(pin.turns, turns18, "%s turning a pinned cell does not count a turn" % tag)

		# 19.
		var rb := State.new()
		rb.start(rng, d)
		var pinned19: int = rb.hint()
		var other19 := _first_turnable_excluding(rb, pinned19)
		rb.turn(other19)
		rb.reset_board()
		for k in rb.n * rb.n:
			if rb.pinned[k] == 1:
				t.eq(rb.grid[k], rb.sol[k], "%s reset_board() leaves a pinned cell where the hint put it" % tag)
			else:
				t.eq(rb.grid[k], rb.deal[k], "%s reset_board() puts an unpinned cell back to the deal" % tag)

		# 20.
		var solve := State.new()
		solve.start(rng, d)
		for k in solve.n * solve.n:
			var guard := 0
			while solve.grid[k] != solve.sol[k] and guard < 4:
				solve.turn(k)
				guard += 1
		t.check(solve.is_solved(), "%s turning every cell to sol reaches is_solved()" % tag)
		for k in solve.n * solve.n:
			t.eq(solve.loose(k), 0, "%s no cell is left loose once solved" % tag)

		# 21.
		var lant := State.new()
		lant.start(rng, d)
		var want_lanterns := PackedInt32Array()
		for k in lant.n * lant.n:
			if Gen.degree(lant.sol[k]) == 1:
				want_lanterns.append(k)
		t.check(want_lanterns.size() > 0, "%s the real board has at least one lantern" % tag)
		t.eq(lant.lanterns(), want_lanterns,
			"%s lanterns() returns the degree-1 cells of the real board in reading order" % tag)

## The first cell whose shape has more than one distinct rotation -- an
## ordinary turnable piece, never a cross.
static func _first_turnable(st) -> int:
	for i in st.n * st.n:
		if Gen.rotations(st.sol[i]).size() > 1:
			return i
	return -1

static func _first_turnable_excluding(st, skip: int) -> int:
	for i in st.n * st.n:
		if i == skip:
			continue
		if Gen.rotations(st.sol[i]).size() > 1:
			return i
	return -1

## How many cells a breadth-first walk from the post reaches over sides that
## are open from both ends -- the board's own definition of live.
static func _reach(n: int, post: int, cells: PackedInt32Array) -> int:
	var seen := {post: true}
	var queue: Array[int] = [post]
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for dir in range(4):
			if cells[i] & (1 << dir) == 0:
				continue
			var r: int = i / n + Gen.DR[dir]
			var col: int = i % n + Gen.DC[dir]
			if r < 0 or col < 0 or r >= n or col >= n:
				continue
			var j: int = r * n + col
			if cells[j] & (1 << ((dir + 2) % 4)) == 0:
				continue
			if seen.has(j):
				continue
			seen[j] = true
			queue.append(j)
	return seen.size()
