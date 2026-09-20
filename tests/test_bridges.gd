extends RefCounted

## Bridges' generator (puzzles/bridges_gen.gd): what a grown board promises,
## and the uniqueness the clues are proved to have.

const Gen = preload("res://puzzles/bridges_gen.gd")

static func run(t) -> void:
	_test_bands(t)
	_test_grown_board_is_legal(t)
	_test_unique(t)
	_test_repeatable(t)

static func _built(seed_value: int, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Gen.generate(rng, difficulty)

## The three bands are the spec's table, section 4.
static func _test_bands(t) -> void:
	t.eq(Gen.band(0).n, 7, "band 0 is a 7x7")
	t.eq(Gen.band(1).n, 9, "band 1 is a 9x9")
	t.eq(Gen.band(2).n, 11, "band 2 is an 11x11")
	t.eq(Gen.band(0).islets, 11, "band 0 stands 11 islets")
	t.eq(Gen.band(1).islets, 16, "band 1 stands 16 islets")
	t.eq(Gen.band(2).islets, 24, "band 2 stands 24 islets")
	t.check(Gen.band(0).guess_free, "band 0 must need no guess")

## Everything a grown board promises, over enough seeds that a rare layout
## cannot hide: the answer is legal, it is connected, no run crosses another,
## every clue is the islet's own degree, and no clue passes the cap of 6.
static func _test_grown_board_is_legal(t) -> void:
	for difficulty in 3:
		var b: Dictionary = Gen.band(difficulty)
		for s in range(1, 21):
			var g := _built(s, difficulty)
			t.eq(g.islets.size(), b.islets, "band %d seed %d stands its islets" % [difficulty, s])
			var lanes: Dictionary = Gen.lanes_for(g.n, g.islets)
			# Every run in the answer is a real lane, and 1..3 planks.
			for key in g.answer:
				t.check(lanes.has(key), "answer run %s is a lane" % key)
				var k: int = int(g.answer[key])
				t.check(k >= 1 and k <= 3, "answer run %s is 1..3 planks, got %d" % [key, k])
			# The clue is the degree, and never over 6.
			for cell in g.islets:
				var deg := 0
				for key in g.answer:
					var lane: Dictionary = lanes[key]
					if lane.a == cell or lane.b == cell:
						deg += int(g.answer[key])
				t.eq(int(g.need[cell]), deg, "clue at %s is its degree" % cell)
				t.check(deg >= 1 and deg <= 6, "degree at %s is 1..6, got %d" % [cell, deg])
			# No two laid runs cross.
			var used := {}
			for key in g.answer:
				for cell in lanes[key].cells:
					t.check(not used.has(cell), "no two answer runs cross at %s" % cell)
					used[cell] = true
			# One network.
			t.check(_connected(g.islets, lanes, g.answer), "the answer is one network")

static func _connected(islets: Array, lanes: Dictionary, runs: Dictionary) -> bool:
	if islets.is_empty():
		return true
	var seen := {islets[0]: true}
	var stack := [islets[0]]
	while not stack.is_empty():
		var cell = stack.pop_back()
		for key in runs:
			if int(runs[key]) <= 0:
				continue
			var lane: Dictionary = lanes[key]
			var other = null
			if lane.a == cell:
				other = lane.b
			elif lane.b == cell:
				other = lane.a
			if other != null and not seen.has(other):
				seen[other] = true
				stack.append(other)
	return seen.size() == islets.size()

## The clues admit exactly one answer -- checked with the generator's own
## counter, and band 0 additionally needs no guess.
static func _test_unique(t) -> void:
	for difficulty in 3:
		for s in range(1, 16):
			var g := _built(s, difficulty)
			var lanes: Dictionary = Gen.lanes_for(g.n, g.islets)
			var r: Dictionary = Gen.count_solutions(g.n, g.islets, g.need, lanes, 2)
			t.eq(int(r.count), 1, "band %d seed %d has exactly one answer" % [difficulty, s])
		if Gen.band(difficulty).guess_free:
			for s in range(1, 16):
				var g2 := _built(s, difficulty)
				t.check(bool(g2.guess_free), "band %d seed %d needs no guess" % [difficulty, s])

## A seed is a day: the same seed hands out the same board on every phone.
static func _test_repeatable(t) -> void:
	for difficulty in 3:
		for s in [7, 99, 1234]:
			var a := _built(s, difficulty)
			var b := _built(s, difficulty)
			t.eq(a.islets, b.islets, "band %d seed %d stands the same islets twice" % [difficulty, s])
			t.eq(a.need, b.need, "band %d seed %d sets the same clues twice" % [difficulty, s])
			t.eq(a.answer, b.answer, "band %d seed %d grows the same answer twice" % [difficulty, s])
