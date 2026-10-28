extends SceneTree
## Which bank things cut for Word Trail's bands, and how often a
## shaped deal grows (else falls back to the square).
const State = preload("res://puzzles/word_trail_state.gd")
func _initialize() -> void:
	var things := State.shared_shapes()
	print("shared things: ", things.size(), " ", things.map(func(p): return p.id))
	for b in 4:
		var ok := 0
		var walls := 0
		var ns := {}
		var ms := 0
		for s in 40:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + s
			var cut := State.shape_for(rng, b)
			var st := State.new()
			var t0 := Time.get_ticks_msec()
			st.build(rng, b, {}, cut)
			ms = maxi(ms, Time.get_ticks_msec() - t0)
			if not st.mask.is_empty():
				ok += 1
				walls += st.walls.size()
				ns[st.n] = int(ns.get(st.n, 0)) + 1
		print("band %d: shaped %d/40, mean walls %.1f, n %s, worst %d ms" % [b, ok, float(walls) / maxf(ok, 1), ns, ms])
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cut := State.shape_for(rng, 2)
	var st := State.new()
	st.build(rng, 2, {}, cut)
	print(st.shape_id, " ", st.shape_name)
	for y in st.n:
		var line := ""
		for x in st.n:
			var c := Vector2i(x, y)
			line += String(st.letters[c]) if st.letters.has(c) else ("#" if st.walls.has(c) else ".")
		print(line)
	quit()
