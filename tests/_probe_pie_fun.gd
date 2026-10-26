extends SceneTree
## Throwaway: how Who Ate the Pie? plays, 100 days a band. A player marks
## one proven baker at a time (random among the proven): how many bakers
## are proven at each step (`opts`; 1 means a hunt for the only one), how
## often only one is, how many of the proven the clue just heard speaks of
## (`lead`: the new clue points at the next baker), the clue kinds dealt,
## and how many taps a player tapping at random spends refused per step.
const Gen = preload("res://puzzles/pie_gen.gd")
func _initialize() -> void:
	var days := 100
	for band in 4:
		var steps := 0
		var opts_sum := 0
		var single := 0
		var lead := 0
		var refused := 0.0
		var kinds := {}
		var worst := 0
		var failed := 0
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 777 + s * 131 + band
			var t0 := Time.get_ticks_msec()
			var day: Dictionary = Gen.deal(rng, band)
			worst = maxi(worst, Time.get_ticks_msec() - t0)
			if day.is_empty():
				failed += 1
				continue
			var cols: int = day.cols
			var rows: int = day.rows
			var n := cols * rows
			for c: Dictionary in day.clues:
				if not c.is_empty():
					var k: String = Gen.Kind.keys()[int(c.k)]
					kinds[k] = int(kinds.get(k, 0)) + 1
			var marked := 1 << int(day.start)
			var last := int(day.start)
			while Gen.popcount(marked) < n:
				var cons := Gen.constraints(day.clues, marked, cols, rows, int(day.dish))
				var f := Gen.forced(cons, n, marked, int(day.ate) & marked)
				var set := int(f.get("set", 0))
				var o := Gen.popcount(set)
				if o == 0:
					print("STALL band ", band, " day ", s)
					break
				steps += 1
				opts_sum += o
				if o == 1:
					single += 1
				if Gen.about(day.clues[last], cols, rows) & set:
					lead += 1
				refused += float(n - Gen.popcount(marked) - o) / float(o)
				var pick := []
				for i in n:
					if set & (1 << i):
						pick.append(i)
				last = pick[rng.randi_range(0, pick.size() - 1)]
				marked |= 1 << last
		print("band %d  opts %.2f  single %.0f%%  lead %.0f%%  refused/step %.2f  worst %d ms  failed %d" % [band,
			float(opts_sum) / steps, 100.0 * single / steps, 100.0 * lead / steps, refused / steps, worst, failed])
		print("   kinds ", kinds)
	quit()
