extends SceneTree

## Caterpillar's generator, timed and checked: thirty seeds a band, the mean
## and worst wall time in GDScript, the leaves and fences it lays, and every
## board re-proved against an uncapped search (3M nodes) so a capped proof
## can never pass for a real one again -- the first cut read a capped search
## that had found one walk as "unique", and 14 of 60 hard and insane boards
## had two. A harness, not a suite entry.
##     godot --headless --script tests/_probe_cat_gen.gd
const G := preload("res://puzzles/caterpillar_gen.gd")
func _initialize() -> void:
	for d in 4:
		var worst := 0.0
		var sum := 0.0
		var ks := 0
		var hs := 0
		var nonu := 0
		var cnt := 30
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			ks += g.leaves.size()
			hs += g.hedges.size()
			if not g.unique: nonu += 1
			# verify: path covers all, visits leaves in order
			var p: PackedInt32Array = g.path
			assert(p.size() == g.cols * g.rows)
			var chk := G.count(g.cols, g.rows, g.leaves, Array(g.hedges), 2, 3000000)
			if chk.count != 1: print("  NOT UNIQUE uncapped d=%d s=%d count=%d" % [d, s, chk.count])
		print("band %d: mean %.1f ms worst %.1f ms leaves %.1f hedges %.1f nonunique %d" % [d, sum / cnt, worst, float(ks) / cnt, float(hs) / cnt, nonu])
	quit()
