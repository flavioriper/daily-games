extends SceneTree
## Throwaway: Who Ate the Pie?'s days. 365 deals a band: the worst and mean
## deal time, failed deals, and a replay of every day by the wavefront (the
## opening baker, then everyone proven) that must mark every baker right.
const Gen = preload("res://puzzles/pie_gen.gd")
func _initialize() -> void:
	var days := int(OS.get_environment("PIE_DAYS")) if OS.get_environment("PIE_DAYS") != "" else 365
	for band in 4:
		var worst := 0
		var total := 0
		var failed := 0
		var bad := 0
		var rounds_sum := 0
		var kinds := {}
		var worst_step := 0
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261022 + s * 7919 + band
			var t := Time.get_ticks_msec()
			var day: Dictionary = Gen.deal(rng, band)
			var dt := Time.get_ticks_msec() - t
			worst = maxi(worst, dt)
			total += dt
			if day.is_empty():
				failed += 1
				continue
			var n: int = day.cols * day.rows
			var heard := 1 << int(day.start)
			var rounds := 0
			while Gen.popcount(heard) < n:
				var cons := Gen.constraints(day.clues, heard, day.cols, day.rows, day.dish)
				var t2 := Time.get_ticks_msec()
				var f := Gen.forced(cons, n, heard, day.ate & heard)
				worst_step = maxi(worst_step, Time.get_ticks_msec() - t2)
				if f.is_empty() or int(f.set) == 0 or int(f.ate) != day.ate & int(f.set):
					break
				heard |= int(f.set)
				rounds += 1
			if Gen.popcount(heard) < n:
				bad += 1
			rounds_sum += rounds
			for c in day.clues:
				kinds[int(c.k)] = int(kinds.get(int(c.k), 0)) + 1
		print("band %d worst %d ms mean %.1f ms failed %d bad %d rounds %.1f step worst %d ms kinds %s" % [band, worst, total / float(days), failed, bad, rounds_sum / float(days), worst_step, str(kinds)])
	quit()
