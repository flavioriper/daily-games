extends RefCounted

## Rings: the generator's guarantees and the state's rules.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md

const Gen = preload("res://puzzles/rings_gen.gd")

## The runner calls one static run(t) a suite (tests/run_tests.gd), so every
## test below is reached from here and nowhere else.
static func run(t) -> void:
	_test_deal_shape(t)
	_test_hard_band_is_three_a_peg(t)
	_test_every_deal_is_solvable(t)
	_test_deal_is_seeded(t)
	_test_key_is_canonical(t)
	_test_moves_and_solved(t)

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

## Every band deals the right number of rings, four of every colour, onto the
## right number of pegs, none over CAP.
static func _test_deal_shape(t) -> void:
	for band in 3:
		var want: Dictionary = Gen.BANDS[band]
		var pegs := Gen.deal(_rng(band * 100 + 7), band)
		t.eq(pegs.size(), want["pegs"], "band %d peg count" % band)
		var seen := {}
		var total := 0
		for s in pegs:
			t.check(s.size() <= Gen.CAP, "band %d peg within CAP" % band)
			total += s.size()
			for c in s:
				seen[c] = int(seen.get(c, 0)) + 1
		t.eq(total, want["colours"] * Gen.CAP, "band %d ring count" % band)
		t.eq(seen.size(), want["colours"], "band %d colour count" % band)
		for c in seen:
			t.eq(int(seen[c]), Gen.CAP, "band %d four of colour %d" % [band, c])

## The hard band is the reference's own deal: eight pegs of exactly three.
static func _test_hard_band_is_three_a_peg(t) -> void:
	var pegs := Gen.deal(_rng(11), 2)
	t.eq(pegs.size(), 8, "eight pegs")
	for s in pegs:
		t.eq(s.size(), 3, "three rings a peg")

## Every deal the generator hands over can actually be sorted, and the path it
## returns is legal move by move and ends solved.
static func _test_every_deal_is_solvable(t) -> void:
	for band in 3:
		for i in 6:
			var pegs := Gen.deal(_rng(i * 31 + band), band)
			t.check(not Gen.solved(pegs), "band %d seed %d is not already solved" % [band, i])
			var path: Array = Gen.solve(pegs, 20000)
			t.check(not path.is_empty(), "band %d seed %d has a solution" % [band, i])
			var work: Array = []
			for s in pegs:
				work.append((s as Array).duplicate())
			for m in path:
				var from: Array = work[m.x]
				var to: Array = work[m.y]
				t.check(not from.is_empty(), "source not empty")
				t.check(to.size() < Gen.CAP, "destination has room")
				t.check(to.is_empty() or to.back() == from.back(), "lands on its own colour")
				to.append(from.pop_back())
			t.check(Gen.solved(work), "band %d seed %d: the path finishes it" % [band, i])

## The same seed deals the same board, on every phone and every run.
static func _test_deal_is_seeded(t) -> void:
	t.eq(str(Gen.deal(_rng(4242), 2)), str(Gen.deal(_rng(4242), 2)), "same seed, same deal")

## Two positions that differ only in which peg is which share a key -- that is
## what collapses the symmetry group and makes the search cheap.
static func _test_key_is_canonical(t) -> void:
	var a := [[0, 0], [1], [], [2, 2, 2]]
	var b := [[2, 2, 2], [], [0, 0], [1]]
	t.eq(Gen.key(a), Gen.key(b), "peg order does not change the key")
	t.check(Gen.key(a) != Gen.key([[0], [1], [], [2, 2, 2]]), "content does")

## A position with nothing legal in it returns no moves, and one that is solved
## says so.
static func _test_moves_and_solved(t) -> void:
	t.check(Gen.solved([[0, 0, 0, 0], [1, 1, 1, 1], []]), "full monochrome pegs and an empty one")
	t.check(not Gen.solved([[0, 0, 0], [0, 1, 1, 1], [1]]), "not sorted")
	# Two full pegs, mismatched tops, nowhere to go.
	t.eq(Gen.moves_from([[0, 1, 0, 1], [1, 0, 1, 0]]).size(), 0, "no legal move")
