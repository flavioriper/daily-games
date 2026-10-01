extends SceneTree

## Marigold's garden and physics, headless: deals days a band, counts the
## buds, times a shot and the hint's search, and plays each day out with the
## hint's aim every shot to see how many seeds a garden takes.
##
##     godot --headless --script res://tests/_probe_marigold.gd [-- days]

const State = preload("res://puzzles/marigold_state.gd")

func _initialize() -> void:
	var days := 3
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		days = int(args[0])
	for band in 4:
		var solved := 0
		var tries_sum := 0
		var counts := []
		for d in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + d * 17 + band
			var st = State.new()
			st.build(rng, band)
			counts.append("%d/%d" % [st.pos.size(), st.orange_total])
			var t0 := Time.get_ticks_usec()
			var a: float = st.best_angle()
			var search_ms := (Time.get_ticks_usec() - t0) / 1000.0
			var done := false
			for attempt in 4:
				while not st.is_solved() and not st.is_out():
					a = st.best_angle()
					st.fire(a)
					var n := 0
					while not st.balls.is_empty() and n < 240 * 40:
						st.step([])
						st.step_pot(0.0)
						n += 1
					st.end_shot()
				if st.is_solved():
					done = true
					break
				st.regrow()
			if done:
				solved += 1
			tries_sum += st.tries
			print("band %d day %d: buds %s, search %.0f ms, %s in %d tries, %d shots, score %d, seeds left %d" % [
				band, d, counts[-1], search_ms, "SOLVED" if done else "not solved", st.tries, st.shots, st.score, st.seeds])
		print("band %d: %d/%d solved by the hint's aim" % [band, solved, days])
	_insane()
	quit()

## Insane, Sweethearts: every banked garden replayed from the shipped file
## with its proof, the pot slid a random while before each shot (it must bloom every pair), then the hint's greedy aim
## played on a few of them with the band's seeds and two tries -- a feel for
## how near impossible it is.
func _insane() -> void:
	var path := "res://content/insane/marigold.json"
	var doc = JSON.parse_string(FileAccess.get_file_as_string(path))
	var boards: Array = doc.boards
	var bad := 0
	for k in boards.size():
		var st = State.new()
		if not st.from_bank(boards[k]):
			bad += 1
			continue
		# the pot left anywhere before each shot, as a player leaves it
		var jr := RandomNumberGenerator.new()
		jr.seed = 77 + k
		for a in st.proof:
			st.step_pot(jr.randf_range(0.5, 6.0))
			st.fire(float(a))
			var n := 0
			while not st.balls.is_empty() and n < 240 * 40:
				st.step([])
				n += 1
			st.end_shot()
		if not st.is_solved():
			bad += 1
			print("insane %d: the proof does not bloom every pair (%d left)" % [k, st.oranges_left])
	print("insane: %d gardens, bad=%d" % [boards.size(), bad])
	var won := 0
	var tried := mini(12, boards.size())
	for k in tried:
		var st = State.new()
		st.from_bank(boards[k * 7 % boards.size()])
		var done := false
		for attempt in 2:
			while not st.is_solved() and not st.is_out():
				st.fire(st.best_angle())
				var n := 0
				while not st.balls.is_empty() and n < 240 * 40:
					st.step([])
					n += 1
				st.end_shot()
			if st.is_solved():
				done = true
				break
			st.regrow()
		if done:
			won += 1
		print("insane greedy %d: %s, %d of %d marigolds left" % [k, "SOLVED" if done else "lost", st.oranges_left, st.orange_total])
	print("insane: the greedy aim solved %d of %d with two tries" % [won, tried])
