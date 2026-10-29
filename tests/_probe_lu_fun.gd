extends SceneTree

## Light Up, measured for the made-fun pass (2026-10-29): played by a hand
## that sets the answer's lamps down in a random order, what share of
## readings the rules alone decide (State.read: a block, a lone lighter, a
## cat) against the answer's next lamp with no reason; that a decided stone
## is always the answer's. And a careless hand (one lamp in four off the
## answer, fair by the rules): how often a stone is stuck, and how soon.
##
##     godot --headless --script res://tests/_probe_lu_fun.gd -- [n=<days a band>]

const State = preload("res://puzzles/lightup_state.gd")

func _initialize() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.substr(2))
	var names := ["block", "only", "cat", "start"]
	for band in 4:
		var kinds := {}
		var first_kinds := {}
		var wrong := 0
		var steps := 0
		var worst := 0
		var stuck_days := 0
		var stuck_wrong := 0
		var wrongs := 0
		for seed in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 9000 + seed
			var st = State.new()
			st.setup(rng, band, seed)
			var order: Array = st.solution.duplicate()
			order.shuffle()
			var first := true
			for b: Vector2i in order:
				var t0 := Time.get_ticks_usec()
				var r: Dictionary = st.read()
				worst = maxi(worst, Time.get_ticks_usec() - t0)
				if r.is_empty():
					break
				kinds[r.why] = int(kinds.get(r.why, 0)) + 1
				if first:
					first_kinds[r.why] = int(first_kinds.get(r.why, 0)) + 1
					first = false
				steps += 1
				if not st.solution.has(r.cell):
					wrong += 1
				st.tap(b)
			# the careless hand: a fair lamp off the answer, then is anything stuck?
			var st2 = State.new()
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 9000 + seed
			st2.setup(rng2, band, seed)
			var whites: Array = st2.white_cells()
			whites.shuffle()
			for c: Vector2i in whites:
				if st2.solution.has(c): continue
				st2.tap(c)
				if not st2.lamp_fair(c):
					st2.undo()
					continue
				wrongs += 1
				if not st2.stuck().is_empty() or not st2.starved().is_empty():
					stuck_wrong += 1
				break
		var line := "band %d: %d readings, wrong %d, worst %d us | " % [band, steps, wrong, worst]
		for k in 4:
			line += "%s %d%% " % [names[k], int(100.0 * kinds.get(k, 0) / maxi(1, steps))]
		line += "| opening: "
		for k in 4:
			line += "%s %d " % [names[k], first_kinds.get(k, 0)]
		line += "| one fair wrong lamp leaves a stone stuck or a block starved %d/%d" % [stuck_wrong, wrongs]
		print(line)
	quit()
