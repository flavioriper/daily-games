extends SceneTree

## Lattice, measured for the made-fun pass (2026-10-29): played by a hand
## that makes the answer's swaps in a random order, what share of readings
## the rules alone decide (State.read: a line's last square, a knot, a square
## one number fits, a number one square of a line takes) against the
## answer's swap with no reason; that a decided square is always the
## answer's; and the opening's reading.
##
##     godot --headless --script res://tests/_probe_la_fun.gd -- [n=<days a band>]

const State = preload("res://puzzles/lattice_state.gd")

func _initialize() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.substr(2))
	for band in 4:
		var kinds := {}
		var first_kinds := {}
		var wrong := 0
		var steps := 0
		var worst := 0
		var cands_sum := 0.0
		var cands_n := 0
		for seed in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + seed
			var st = State.new()
			st.setup(rng, band)
			var first := true
			var guard := 0
			while not st.is_solved() and guard < 200:
				guard += 1
				var t0 := Time.get_ticks_usec()
				var r: Dictionary = st.read()
				worst = maxi(worst, Time.get_ticks_usec() - t0)
				kinds[r.why] = int(kinds.get(r.why, 0)) + 1
				if first:
					first_kinds[r.why] = int(first_kinds.get(r.why, 0)) + 1
					for i in st.count():
						if not st.is_home(i):
							cands_sum += st.candidates(i).size()
							cands_n += 1
					first = false
				steps += 1
				if r.cell >= 0 and st.sol[r.cell] != r.value:
					wrong += 1
				# the hand: a random answer swap (any tile to a square that wants it)
				var pairs: Array = []
				for a in st.count():
					if st.is_home(a): continue
					for b in st.count():
						if b != a and not st.is_home(b) and st.cur[b] == st.sol[a]:
							pairs.append([a, b])
				var p: Array = pairs[rng.randi_range(0, pairs.size() - 1)]
				st.swap(p[0], p[1])
		var line := "band %d: %d readings, wrong %d, worst %d us | " % [band, steps, wrong, worst]
		for k in 5:
			line += "%s %d%% " % [["last", "knot", "only", "hidden", "pair"][k], int(100.0 * kinds.get(k, 0) / maxi(1, steps))]
		line += "| opening: "
		for k in 5:
			line += "%s %d " % [["last", "knot", "only", "hidden", "pair"][k], first_kinds.get(k, 0)]
		line += "| mean candidates at the opening %.2f" % (cands_sum / maxf(1.0, cands_n))
		print(line)
	quit()
