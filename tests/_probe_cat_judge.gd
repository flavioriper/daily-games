extends SceneTree
## The judge never takes a heart along the answer, and how often it fires off
## it. Headless:  godot --headless --script tests/_probe_cat_judge.gd
const S := preload("res://puzzles/caterpillar_state.gd")
const G := preload("res://puzzles/caterpillar_gen.gd")
func _initialize() -> void:
	for d in [2, 3]:
		var bad := 0
		var legal_off := 0
		var judged_off := 0
		var strands := 0
		var us := 0
		var calls := 0
		for seed in 15:
			var st = S.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = seed * 31 + d
			if d == 3:
				st.setup(G.generate_peckish(rng, 7, 7, 5, 16, 4000))
				st.difficulty = 3
			else:
				st.build(rng, d)
			st.start(st.path[0])
			for i in range(1, st.path.size()):
				for nb in [-1, 1, -st.cols, st.cols]:
					var m: int = st.head() + nb
					if m < 0 or m >= st.size() or m == st.path[i] or not st.adjacent(st.head(), m) or st.why(m) != "":
						continue
					legal_off += 1
					var t0 := Time.get_ticks_usec()
					var j: String = st.judge(m)
					us += Time.get_ticks_usec() - t0
					calls += 1
					if j != "":
						judged_off += 1
					if j == "strand":
						strands += 1
				var t1 := Time.get_ticks_usec()
				if st.judge(st.path[i]) != "":
					bad += 1
				us += Time.get_ticks_usec() - t1
				calls += 1
				if st.why(st.path[i]) != "":
					print("answer refused d=%d seed=%d at %d: %s" % [d, seed, i, st.why(st.path[i])])
					break
				st.grow(st.path[i])
			if not st.is_solved():
				print("not solved d=%d seed=%d" % [d, seed])
		print("d=%d: answer judged wrong %d; legal off-answer steps %d, judged %d (strand %d); judge %.2f ms mean" % [d, bad, legal_off, judged_off, strands, us / 1000.0 / maxi(calls, 1)])
	quit()
