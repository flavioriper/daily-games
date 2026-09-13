extends RefCounted

const Gen = preload("res://puzzles/balance_gen.gd")

static func run(t) -> void:
	# Uniqueness is brute-forced over the whole domain, so it is exact.
	for shapes in [2, 3, 4]:
		for i in range(5):
			var rng := RandomNumberGenerator.new()
			rng.seed = 500 + i
			var out: Dictionary = Gen.generate(rng, shapes)
			t.check(out.unique, "shapes=%d seed=%d has a unique solution" % [shapes, i])
			t.eq(Gen.count_solutions(out.scales, shapes, 3, out.anchor), 1,
				"shapes=%d seed=%d counts exactly one" % [shapes, i])
			# The secret must actually satisfy every scale we show.
			var all_balance := true
			for sc in out.scales:
				if not Gen.balances(sc, out.secret):
					all_balance = false
			t.check(all_balance, "shapes=%d seed=%d every scale balances under the secret" % [shapes, i])
			# No scale is redundant: dropping one must lose uniqueness.
			var minimal := true
			for sc in out.scales:
				var trial: Array = out.scales.duplicate()
				trial.erase(sc)
				if Gen.count_solutions(trial, shapes, 2, out.anchor) == 1:
					minimal = false
			t.check(minimal, "shapes=%d seed=%d no redundant scale" % [shapes, i])

	# The anchor must be truthful: it reveals the secret weight of its shape.
	var rng3 := RandomNumberGenerator.new(); rng3.seed = 21
	var oa: Dictionary = Gen.generate(rng3, 3)
	t.eq(oa.secret[oa.anchor.shape], oa.anchor.value, "anchor reports the true weight")

	# Without the anchor, scaling means the answer is never unique.
	var free_anchor := {"shape": -1, "value": 0}
	t.check(Gen.count_solutions(oa.scales, 3, 3, free_anchor) >= 2,
		"scales alone admit multiple solutions -- the anchor is load-bearing")

	# A scale with identical sides would be vacuously true and is never emitted.
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 77
	var o: Dictionary = Gen.generate(rng2, 3)
	var vacuous := false
	for sc in o.scales:
		var l: Array = sc.left.duplicate(); l.sort()
		var r: Array = sc.right.duplicate(); r.sort()
		if l == r:
			vacuous = true
	t.check(not vacuous, "no vacuously balanced scale is emitted")
