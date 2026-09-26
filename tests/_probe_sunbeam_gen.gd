extends SceneTree

## Sunbeam's generator, timed and checked: forty seeds a band, the mean and
## worst wall time in GDScript, the pieces, cups, drops and pots it lays, and
## every board re-counted (cap 3) and its answer re-traced to a solve.
## A harness, not a suite entry.
##     godot --headless --script tests/_probe_sunbeam_gen.gd
const G := preload("res://puzzles/sunbeam_gen.gd")
func _initialize() -> void:
	for d in 4:
		var worst := 0.0
		var sum := 0.0
		var att := 0
		var att_max := 0
		var bad := 0
		var shape := {}
		var cnt := 40
		for s in cnt:
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 7919 + d
			var t0 := Time.get_ticks_usec()
			var g := G.generate(rng, d)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			sum += ms
			att += int(g.attempts)
			att_max = maxi(att_max, int(g.attempts))
			var home := PackedInt32Array()
			var cups := 0
			for pc in g.pieces:
				home.append(int(pc.home))
				if pc.kind == "u":
					cups += 1
			var key := "%d/%d/%d" % [g.pieces.size(), cups, g.drops.size()]
			shape[key] = int(shape.get(key, 0)) + 1
			if not g.unique or G.count(g, 3) != 1 or not G.trace(g, home).won or G.trace(g, g.start).won:
				bad += 1
				print("  BAD d=%d s=%d unique=%s count=%d" % [d, s, g.unique, G.count(g, 3)])
		print("band %d: mean %.1f ms worst %.1f ms, grows mean %d max %d, bad %d, pieces/cups/drops %s" % [
			d, sum / cnt, worst, att / cnt, att_max, bad, shape])
	quit()
