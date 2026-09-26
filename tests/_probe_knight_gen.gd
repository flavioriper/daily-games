extends SceneTree

## Knight's generator, timed and checked: forty seeds a level, the mean and
## worst wall time in GDScript, the shortest line's range, and every board's
## line replayed through `step` to a win that is never caught, with the naive
## line proved to fail. A harness, not a suite entry.
##     godot --headless --path . --script tests/_probe_knight_gen.gd
const G := preload("res://puzzles/knight_gen.gd")

func _initialize() -> void:
	for d in 4:
		var worst := 0.0
		var sum := 0.0
		var lo := 99
		var hi := 0
		var bad := 0
		var short := 0
		var att_max := 0
		var cnt := 40
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			att_max = maxi(att_max, int(g.attempts))
			var opt: int = g.opt
			lo = mini(lo, opt)
			hi = maxi(hi, opt)
			if opt < int(G.band(d).min):
				short += 1
			var you: int = g.you
			var foes: PackedInt32Array = g.foes
			var ok := true
			for i in g.line.size():
				var r: Dictionary = G.step(g, you, foes, g.line[i])
				if r.caught >= 0 or (r.won != (i == g.line.size() - 1)):
					ok = false
					break
				you = r.you
				foes = r.foes
			if not ok or G.naive_wins(g):
				bad += 1
				print("  BAD d=%d s=%d" % [d, s])
		print("level %d: mean %.1f ms worst %.1f ms, shortest %d-%d, below min %d, attempts max %d, bad %d" % [
			d, sum / cnt, worst, lo, hi, short, att_max, bad])
	quit()
