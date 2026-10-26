extends SceneTree
## Throwaway: how Market Sums' stall answers a first step. 60 days a band:
## of every legal first combine (crate, sign, crate), the share that still
## reaches the order at all, and the share that keeps the fewest steps.
const Gen = preload("res://puzzles/market_gen.gd")
const MS = preload("res://puzzles/market_state.gd")
func _initialize() -> void:
	for band in 4:
		var legal := 0
		var live := 0
		var on_par := 0
		var moves_per_day := 0.0
		for s in 60:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261026 + s * 7919 + band
			var st = MS.new()
			st.deal(rng, band)
			for a in 6:
				for b in 6:
					if b <= a:
						continue
					for op in 4:
						if st.would(a, b, op) <= 0:
							continue
						legal += 1
						moves_per_day += 1.0
						st.make(a, b, op)
						var left: int = st.steps_left()
						if left >= 0:
							live += 1
						if left >= 0 and left + 1 == st.par:
							on_par += 1
						st.undo()
		print("band %d first steps %.1f a day: reach %.0f%%, keep fewest %.0f%%" % [band, moves_per_day / 60.0,
			100.0 * live / legal, 100.0 * on_par / legal])
	quit()
