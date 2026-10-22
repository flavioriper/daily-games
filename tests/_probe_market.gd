extends SceneTree
## Throwaway: Market Sums' days. 365 deals a band: the worst and mean deal
## time, the orders' spread, and the bulb's own play from the opening, which
## must fill the order in exactly the band's fewest steps every day.
const Gen = preload("res://puzzles/market_gen.gd")
const MS = preload("res://puzzles/market_state.gd")
func _initialize() -> void:
	for band in 4:
		var worst := 0
		var total := 0
		var bad := 0
		var lo := 99999
		var hi := 0
		var fallback := 0
		for s in 365:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261022 + s * 7919 + band
			var st = MS.new()
			var t := Time.get_ticks_msec()
			st.deal(rng, band)
			var dt := Time.get_ticks_msec() - t
			worst = maxi(worst, dt)
			total += dt
			lo = mini(lo, st.target)
			hi = maxi(hi, st.target)
			if st.answer.is_empty():
				fallback += 1
			if st.steps_left() != st.par:
				bad += 1
				continue
			var n := 0
			while not st.solved() and n < 8:
				var h: Array = st.hint_step()
				if h.is_empty():
					break
				st.make(h[0], h[1], h[2], true)
				n += 1
			if not st.solved() or n != st.par:
				bad += 1
				print("  band %d day %d: %s -> %d took %d" % [band, s, str(st.numbers), st.target, n])
		print("band %d worst %d ms mean %.1f ms orders %d..%d fallback %d bad %d" % [band, worst, total / 365.0, lo, hi, fallback, bad])
	# a wasted crate: the bulb walks back to where the order is still there
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st = MS.new()
	st.deal(rng, 3)
	print("insane day ", st.numbers, " -> ", st.target, " answer ", st.answer)
	quit()
