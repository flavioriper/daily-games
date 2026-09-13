extends RefCounted

const Gen = preload("res://puzzles/mastermind_gen.gd")

static func run(t) -> void:
	# Scoring is the whole game; get it exactly right.
	t.eq(Gen.score([0, 1, 2, 3], [0, 1, 2, 3]), {"exact": 4, "colour": 0}, "perfect guess")
	t.eq(Gen.score([3, 2, 1, 0], [0, 1, 2, 3]), {"exact": 0, "colour": 4}, "all present, none placed")
	t.eq(Gen.score([4, 4, 4, 4], [0, 1, 2, 3]), {"exact": 0, "colour": 0}, "nothing matches")
	# Duplicate handling: each code peg is consumed at most once.
	t.eq(Gen.score([0, 0, 0, 0], [0, 1, 2, 3]), {"exact": 1, "colour": 0}, "guess repeats, code does not")
	t.eq(Gen.score([0, 1, 1, 1], [1, 0, 1, 2]), {"exact": 1, "colour": 2}, "duplicates on both sides")
	t.eq(Gen.score([1, 1, 0, 0], [0, 0, 1, 1]), {"exact": 0, "colour": 4}, "swapped pairs")

	# Exact + colour can never exceed the code length.
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 200:
		var code: Array = Gen.make_code(rng, 4, 6, true)
		var guess: Array = Gen.make_code(rng, 4, 6, true)
		var s: Dictionary = Gen.score(guess, code)
		if s.exact + s.colour > 4:
			t.check(false, "score exceeded length for %s vs %s" % [guess, code])
			return
	t.check(true, "score never exceeds code length over 200 random pairs")

	# No-repeat mode really has no repeats.
	for i in 50:
		var c: Array = Gen.make_code(rng, 4, 6, false)
		var uniq := {}
		for v in c:
			uniq[v] = true
		if uniq.size() != 4:
			t.check(false, "no-repeat code had repeats: %s" % [c])
			return
	t.check(true, "no-repeat mode produces distinct pegs")
