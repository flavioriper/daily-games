extends SceneTree

## Untangle, headless: how the day's deals play for a player. Per band, over
## N days: the moves open at the deal and how many of them lower the
## crossings or free a rope; a greedy player (the move that leaves the fewest
## crossings, a rope freed first) to the win or a stall, against par; when
## the first rope leaves on the dealer's answer and on the greedy run.
##
##     godot --headless --path . --script res://tests/_probe_ut_fun.gd -- [n=40]

const State = preload("res://puzzles/untangle_state.gd")
const Gen = preload("res://puzzles/untangle_gen.gd")

func _initialize() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	for band in 4:
		var open := 0.0
		var better := 0.0
		var frees := 0.0
		var won := 0
		var over := 0.0
		var stalls := 0
		var first_plan := 0.0
		var first_greedy := 0.0
		var up_moves := 0.0
		var ms := 0
		var multi := 0
		var greedy_moves := 0
		var hist := {}
		for day in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + day * 31 + band
			var s := State.new()
			var t0 := Time.get_ticks_msec()
			s.setup(rng, band)
			ms += Time.get_ticks_msec() - t0
			var moves: Array = Gen.legal_moves(s.plate, s.at, s.reach)
			open += moves.size()
			var c0 := s.crossings()
			for m in moves:
				var a := s.at.duplicate()
				var t := s.tw.duplicate()
				Gen.apply(s.plate, a, t, s.ropes, m[0], m[1])
				if Gen.crossing_count(t) < c0:
					better += 1
				if Gen.retire(a, t, s.ropes).size() > 0:
					frees += 1
			# The dealer's answer: the move a rope first leaves on.
			var p := State.new()
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = 7000 + day * 31 + band
			p.setup(rng2, band)
			var k := 0
			for step in p.plan:
				k += 1
				if p.at[step[0]] < 0:
					continue
				var res := p.move(step[0], step[2])
				if res.is_empty():
					break
				if (res.gone as Array).size() > 0:
					break
			first_plan += k
			# Greedy.
			var g := 0
			var first := -1
			var ups := 0
			while not s.is_solved() and g < 60:
				var best: Array = []
				var low := 1 << 30
				for m in Gen.legal_moves(s.plate, s.at, s.reach):
					var a := s.at.duplicate()
					var t := s.tw.duplicate()
					Gen.apply(s.plate, a, t, s.ropes, m[0], m[1])
					var sc := Gen.crossing_count(t) * 10 - Gen.retire(a, t, s.ropes).size()
					if sc < low:
						low = sc
						best = m
				if best.is_empty():
					break
				var before := s.crossings()
				var res := s.move(best[0], best[1])
				g += 1
				if s.crossings() > before:
					ups += 1
				if first < 0 and (res.gone as Array).size() > 0:
					first = g
				if (res.gone as Array).size() >= 2:
					multi += 1
			up_moves += ups
			if s.is_solved():
				won += 1
				over += g - s.par
				hist[g - s.par] = int(hist.get(g - s.par, 0)) + 1
			else:
				stalls += 1
			greedy_moves += g
			first_greedy += first if first > 0 else g
		print("band %d: open %.1f, lower %.1f, free %.2f | greedy won %d/%d, +%.1f over par, %d stalls, %.1f up-moves | first rope plan %.1f greedy %.1f | gen %.0f ms" % [
			band, open / n, better / n, frees / n, won, n, over / maxi(1, won), stalls, up_moves / n, first_plan / n, first_greedy / n, float(ms) / n])
		print("   multi-free moves %d of %d greedy moves; over-par spread %s" % [multi, greedy_moves, str(hist)])
	quit(0)
