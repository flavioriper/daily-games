extends RefCounted

const Gen = preload("res://puzzles/untangle_gen.gd")
const State = preload("res://puzzles/untangle_state.gd")

static func run(t) -> void:
	# Four holes interleave or they do not.
	t.check(Gen.crosses(0, 5, 2, 7), "0-5 and 2-7 cross")
	t.check(not Gen.crosses(0, 5, 1, 4), "0-5 holds 1-4 inside it, no crossing")
	t.check(not Gen.crosses(0, 3, 4, 8), "0-3 and 4-8 are apart")
	t.eq(Gen.chord(10, 1, 9), 2, "a chord is the short way round")
	for k in Gen.pair_count(9):
		var pr := Gen.pair_of(k, 9)
		t.eq(Gen.pair_index(pr.x, pr.y, 9), k, "pair slot %d round trips" % k)

	# The knot rule on two ropes. Rope 0 runs 0-5, rope 1 runs 1-4 beside it.
	var at := PackedInt32Array([0, 5, 1, 4])
	var tw := Gen.empty_tangle(2)
	# Rope 1's peg carried from 1 over rope 0 to 7: a crossing, rope 1 on top.
	t.eq(Gen.apply(at, tw, 2, 2, 7), 1, "carried over another rope: one crossing")
	t.eq(Gen.top_at(at, tw, 2, 1, 0, 0), 1, "the rope carried over lies on top")
	t.eq(Gen.top_at(at, tw, 2, 0, 0, 1), 0, "the other lies under")
	# Rope 0 (underneath) carried across rope 1: wrapped, not undone.
	t.eq(Gen.apply(at, tw, 2, 1, 3), 1, "the rope underneath carried across wraps tighter")
	t.eq(Gen.count(tw, 0), 2, "twice round")
	t.check(not Gen.crosses(at[0], at[1], at[2], at[3]), "wrapped twice, the pegs no longer interleave")
	# Taken back, the same way: each move undone by the move made back.
	t.eq(Gen.apply(at, tw, 2, 1, 5), -1, "rope 0 lifted back off")
	t.eq(Gen.apply(at, tw, 2, 2, 1), -1, "rope 1 lifted back off")
	t.check(Gen.is_solved(tw), "and nothing crosses")

	# Random walks: a move made back restores everything, and a pair's count is
	# odd exactly when its pegs interleave.
	var rng := RandomNumberGenerator.new()
	var bad_back := 0
	var bad_parity := 0
	for trial in 60:
		rng.seed = 400 + trial
		var cfg: Dictionary = Gen.BANDS[trial % Gen.BANDS.size()]
		var goal := Gen._goal(rng, cfg)
		var here: PackedInt32Array = goal.at.duplicate()
		var knots := Gen.empty_tangle(cfg.ropes)
		for step in 25:
			var ms := Gen.legal_moves(here, cfg.holes, goal.reach)
			if ms.is_empty():
				break
			var m: Array = ms[rng.randi() % ms.size()]
			var from := here[m[0]]
			var a0 := here.duplicate()
			var k0 := knots.duplicate()
			Gen.apply(here, knots, cfg.ropes, m[0], m[1])
			var a1 := here.duplicate()
			var k1 := knots.duplicate()
			Gen.apply(a1, k1, cfg.ropes, m[0], from)
			if a1 != a0 or k1 != k0:
				bad_back += 1
			for k in knots.size():
				var pr := Gen.pair_of(k, cfg.ropes)
				var inter := Gen.crosses(here[2 * pr.x], here[2 * pr.x + 1], here[2 * pr.y], here[2 * pr.y + 1])
				if (Gen.count(knots, k) % 2 == 1) != inter:
					bad_parity += 1
	t.eq(bad_back, 0, "every move is undone by the move made back")
	t.eq(bad_parity, 0, "a pair crosses an odd number of times exactly when its pegs interleave")

	for band in 4:
		for i in 3:
			var r := RandomNumberGenerator.new()
			r.seed = 900 + i
			var out: Dictionary = Gen.generate(r, band)
			var cfg: Dictionary = Gen.BANDS[band]
			var name := "band %d seed %d" % [band, i]
			var start: PackedInt32Array = out.start
			t.check(not Gen.is_solved(out.tw), name + " starts tangled")
			t.eq(start.size(), 2 * out.ropes, name + " a peg per rope end")
			t.check(Gen.crossing_count(out.tw) <= int(cfg.most), name + " stays readable")
			t.check(Gen.most_wraps(out.tw, out.ropes) <= Gen.WRAPS_PER_ROPE, name + " no rope wrapped round more than two")
			var seen := {}
			for h in start:
				seen[h] = true
			t.eq(seen.size(), start.size(), name + " no two pegs in a hole")
			# The answer replays, kitten included, and ends untangled.
			var here := start.duplicate()
			var knots: PackedInt32Array = out.tw.duplicate()
			var reach: PackedInt32Array = out.reach
			var ok := true
			for j in out.plan.size():
				var m: Array = out.plan[j]
				if not Gen.fits(here, out.holes, reach, m[0], m[2], Gen.occupancy(here, out.holes)):
					ok = false
					break
				Gen.apply(here, knots, out.ropes, m[0], m[2])
				if out.cat and (j + 1) % Gen.CAT_EVERY == 0 and not Gen.is_solved(knots):
					var peg: int = out.swipes.get(j + 1, Gen.swipe_fallback(j + 1, here.size()))
					var to := Gen.cat_hole(here, out.holes, reach, peg)
					if to >= 0:
						Gen.apply(here, knots, out.ropes, peg, to)
			t.check(ok and Gen.is_solved(knots), name + " the dealer's answer wins")
			if band >= 2:
				t.check(out.budget >= out.par, name + " the thread covers the answer")

	# The state: a move raises its rope, undo restores, reset keeps the thread spent.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 31
	var st := State.new()
	st.setup(rng2, 2)
	var before := st.at.duplicate()
	var before_tw := st.tw.duplicate()
	var move: Array = st.plan[0]
	var res: Dictionary = st.move(move[0], move[2])
	t.check(not res.is_empty(), "the first step of the answer is a legal move")
	t.eq(st.order.back(), move[0] >> 1, "the moved rope lies on top")
	t.eq(st.spent, 1, "a move uses a stitch")
	st.undo()
	t.check(st.at == before and st.tw == before_tw, "undo puts the peg and the knots back")
	t.eq(st.spent, 2, "undo is a stitch too")
	st.reset()
	t.eq(st.spent, 2, "reset gives no thread back")

	# The dealer's answer, played through the state's own move (the kitten's
	# swipes included), on the two bands that run on thread: it must win inside
	# the budget without winning early, and end where the deal says it does.
	for band in [2, 3]:
		for i in 20:
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
	for i in 30:
		var r3 := RandomNumberGenerator.new()
		r3.seed = 77 + i
		var fb: Dictionary = Gen._fallback(r3)
		var seen := {}
		for h in fb.start:
			seen[h] = true
		t.eq(seen.size(), fb.start.size(), "fallback %d has distinct holes" % i)
		t.check(not Gen.is_solved(fb.tw), "fallback %d starts tangled" % i)
		var here: PackedInt32Array = fb.start.duplicate()
		var knots: PackedInt32Array = fb.tw.duplicate()
		for m in fb.plan:
			Gen.apply(here, knots, fb.ropes, m[0], m[2])
		t.check(Gen.is_solved(knots), "fallback %d answer wins" % i)
