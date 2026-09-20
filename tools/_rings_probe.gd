extends SceneTree

## Throwaway: how long does a Rings deal cost in GDScript, per band, on this
## machine? The concept page measured the same algorithm in JavaScript at
## 0.3-0.6 ms worst; GDScript is commonly thirty to eighty times slower, and
## the gate is 300 ms. Delete once the figure is in CLAUDE.md.

const Gen = preload("res://puzzles/rings_gen.gd")

func _process(_delta: float) -> bool:
	for band in 3:
		var worst := 0.0
		var total := 0.0
		var runs := 12
		for i in runs:
			var rng := RandomNumberGenerator.new()
			rng.seed = i * 977 + band
			var t0 := Time.get_ticks_usec()
			var pegs := Gen.deal(rng, band)
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0
			total += ms
			worst = maxf(worst, ms)
			assert(not Gen.solve(pegs, Gen.NODE_BUDGET).is_empty())
		print("band %d: mean %.1f ms, worst %.1f ms over %d seeds" % [band, total / runs, worst, runs])
	quit()
	return true
