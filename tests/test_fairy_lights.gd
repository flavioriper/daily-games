extends RefCounted

## Fairy Lights' generator. The state's half arrives with the board; this
## file is the promise -- that every garden the day hands out is a spanning
## tree the propagate-only solver can finish, so nobody ever has to guess,
## and that the deal opens dark and scrambled rather than half-solved.
## A board that needs a guess cannot be caught by playing it: it looks
## exactly like a board that is merely hard, right up to the coin flip.

const Gen = preload("res://puzzles/fairy_lights_gen.gd")

static func run(t) -> void:
	_test_turning(t)
	_test_bands(t)
	_test_tree(t)
	_test_promise(t)
	_test_deal(t)
	_test_seeded(t)

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

## 4. Every board over 40 seeds a band comes back proved, and solvable()
##    agrees when handed the solution back.
static func _test_promise(t) -> void:
	for d in 3:
		var unproved := 0
		var disagreed := 0
		for i in range(40):
			var rng := RandomNumberGenerator.new()
			rng.seed = 4300 + d * 1000 + i
			var out: Dictionary = Gen.build(rng, d)
			if not out.proved:
				unproved += 1
			if not Gen.solvable(out.n, out.sol):
				disagreed += 1
		t.eq(unproved, 0, "band %d proves every one of forty boards" % d)
		t.eq(disagreed, 0, "band %d: solvable() agrees with build() on every board" % d)

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
