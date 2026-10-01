extends SceneTree
## Peckish's generator, timed and re-proved uncapped. A harness.
##     godot --headless --script tests/_probe_cat_peck.gd -- w=8 h=8 hunger=5 cap=4000 n=20
const G := preload("res://puzzles/caterpillar_gen.gd")
func _initialize() -> void:
	var o := {"w": 8, "h": 8, "hunger": 5, "cap": 4000, "n": 20, "fences": 16}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		o[kv[0]] = int(kv[1])
	var worst := 0.0
	var sum := 0.0
	var ok := 0
	var ks := 0
	var hs := 0
	for s in o.n:
		var rng := RandomNumberGenerator.new()
		rng.seed = s * 7919 + 3
		var t0 := Time.get_ticks_usec()
		var g := G.generate_peckish(rng, o.w, o.h, o.hunger, o.fences, o.cap)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		sum += ms
		if g.unique:
			ok += 1
			ks += g.leaves.size()
			hs += g.hedges.size()
			var chk := G.count(g.cols, g.rows, g.leaves, Array(g.hedges), 2, 2000000, g.hunger)
			if chk.count != 1: print("  NOT UNIQUE uncapped s=%d count=%d capped=%s" % [s, chk.count, chk.capped])
	print("%s: unique %d/%d mean %.0f ms worst %.0f ms leaves %.1f fences %.1f" % [o, ok, o.n, sum / o.n, worst, float(ks) / maxi(ok, 1), float(hs) / maxi(ok, 1)])
	quit()
