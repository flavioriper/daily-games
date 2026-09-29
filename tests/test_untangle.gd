extends RefCounted

const Gen = preload("res://puzzles/untangle_gen.gd")
const State = preload("res://puzzles/untangle_state.gd")

static func run(t) -> void:
	# The rule: four holes interleave or they do not.
	t.check(Gen.crosses(0, 5, 2, 7), "0-5 and 2-7 cross")
	t.check(not Gen.crosses(0, 5, 1, 4), "0-5 holds 1-4 inside it, no crossing")
	t.check(not Gen.crosses(0, 3, 4, 8), "0-3 and 4-8 are apart")
	t.eq(Gen.chord(10, 1, 9), 2, "a chord is the short way round")

	for band in 4:
		for i in 3:
			var rng := RandomNumberGenerator.new()
			rng.seed = 900 + i
			var out: Dictionary = Gen.generate(rng, band)
			var name := "band %d seed %d" % [band, i]
			var at: PackedInt32Array = out.start
			t.check(not Gen.is_solved(at, out.ropes), name + " starts tangled")
			t.eq(at.size(), 2 * out.ropes, name + " a peg per rope end")
			var seen := {}
			for h in at:
				seen[h] = true
			t.eq(seen.size(), at.size(), name + " no two pegs in a hole")
			# The answer replays, kitten included, and ends untangled.
			var here := at.duplicate()
			var reach: PackedInt32Array = out.reach
			var ok := true
			for j in out.plan.size():
				var m: Array = out.plan[j]
				if not Gen.fits(here, out.holes, reach, m[0], m[2], Gen.occupancy(here, out.holes)):
					ok = false
					break
				here[m[0]] = m[2]
				if out.cat and (j + 1) % Gen.CAT_EVERY == 0 and not Gen.is_solved(here, out.ropes):
					var peg: int = out.swipes.get(j + 1, Gen.swipe_fallback(j + 1, here.size()))
					var to := Gen.cat_hole(here, out.holes, reach, peg)
					if to >= 0:
						here[peg] = to
			t.check(ok and Gen.is_solved(here, out.ropes), name + " the dealer's answer wins")
			if band >= 2:
				t.check(out.budget >= out.par, name + " the thread covers the answer")

	# The state: a move raises its rope, undo restores, reset keeps the thread spent.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 31
	var st := State.new()
	st.setup(rng2, 2)
	var before := st.at.duplicate()
	var move: Array = st.plan[0]
	var res: Dictionary = st.move(move[0], move[2])
	t.check(not res.is_empty(), "the first step of the answer is a legal move")
	t.eq(st.order.back(), move[0] >> 1, "the moved rope lies on top")
	t.eq(st.spent, 1, "a move uses a stitch")
	st.undo()
	t.check(st.at == before, "undo puts the peg back")
	t.eq(st.spent, 2, "undo is a stitch too")
	st.reset()
	t.eq(st.spent, 2, "reset gives no thread back")

	# The dealer's answer, played through the state's own move (the kitten's
	# swipes included), on the two bands that run on thread: it must win inside
	# the budget without winning early, and end where the deal says it does.
	for band in [2, 3]:
		for i in 30:
			var r := RandomNumberGenerator.new()
			r.seed = 5000 + i
			var sb := State.new()
			sb.setup(r, band)
			var name := "band %d seed %d through State.move" % [band, i]
			var won_at := -1
			for j in sb.plan.size():
				var m: Array = sb.plan[j]
				var moved := sb.move(m[0], m[2])
				if moved.is_empty():
					break
				if sb.is_solved():
					won_at = j
					break
			t.eq(won_at, sb.plan.size() - 1, name + " wins on its last step")
			t.check(sb.spent <= sb.budget, name + " inside the thread")
			t.check(sb.at == sb.goal_at, name + " ends on the deal's layout")

	# The fallback board is a real one: distinct holes, tangled, and its answer wins.
	for i in 40:
		var r2 := RandomNumberGenerator.new()
		r2.seed = 77 + i
		var fb: Dictionary = Gen._fallback(r2)
		var seen := {}
		for h in fb.start:
			seen[h] = true
		t.eq(seen.size(), fb.start.size(), "fallback %d has distinct holes" % i)
		t.check(not Gen.is_solved(fb.start, fb.ropes), "fallback %d starts tangled" % i)
		var here: PackedInt32Array = fb.start.duplicate()
		for m in fb.plan:
			here[m[0]] = m[2]
		t.check(Gen.is_solved(here, fb.ropes), "fallback %d answer wins" % i)
