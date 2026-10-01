extends SceneTree
const Gen = preload("res://puzzles/sunbeam_gen.gd")
func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	for seed_i in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_i
		var a := Time.get_ticks_msec()
		var g := Gen.generate(rng, 2)
		print("hard %d: snails %s unique %s %d ms" % [seed_i, g.snails, g.unique, Time.get_ticks_msec() - a])
	for seed_i in 8:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + seed_i
		var a := Time.get_ticks_msec()
		var g := Gen.generate_shy(rng)
		if g.is_empty():
			print("shy %d: none %d ms" % [seed_i, Time.get_ticks_msec() - a]); continue
		var b := Gen.from_bank(Gen.to_bank(g))
		print("shy %d: dark %d par %d drops %d %d ms count %d" % [seed_i, g.dark, g.par, g.drops.size(), Time.get_ticks_msec() - a, Gen.count(b, 3)])
	quit()
