extends SceneTree

## Whether a Paper Planes deal draws its picture. Over `seeds` days a band
## (the bank's thing for the day, as a phone without the day's document
## deals it), the planes, the cover of the shape, the carve's time, how many
## colours the shape holds and how many of a plane's cells lie on the
## colour its head lies on (1.0 is every plane one colour), and how many
## planes are free at a step of a greedy play. Headless, not in the suite:
##
##     godot --headless --path . --script res://tests/_probe_pp_fun.gd -- [seeds=12]

const State = preload("res://puzzles/planes_state.gd")

func _initialize() -> void:
	var seeds := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seeds="):
			seeds = int(a.substr(6))
	print("shared things: %d" % State.shared_things().size())
	for band in 4:
		var planes: Array = []
		var cover: Array = []
		var ms: Array = []
		var tones: Array = []
		var same := 0
		var cells := 0
		var free_sum := 0
		var steps := 0
		var tight := 0
		var holes := 0
		for s in seeds:
			var rng := RandomNumberGenerator.new()
			rng.seed = 7000 + s
			var st := State.new()
			var t0 := Time.get_ticks_usec()
			st.build(rng, band, 0, 20261001 + s)
			ms.append((Time.get_ticks_usec() - t0) / 1000)
			planes.append(st.planes.size())
			var occ := 0
			for p in st.planes:
				occ += (p.cells as Array).size()
				var head = st.shape.get((p.cells as Array).back())
				for c in p.cells:
					cells += 1
					if st.shape.get(c) == head:
						same += 1
			cover.append(snappedf(float(occ) / float(st.shape.size()), 0.001))
			holes += st.shape.size() - occ
			var seen := {}
			for c in st.shape:
				seen[st.shape[c]] = true
			tones.append(seen.size())
			while not st.solved():
				var free := st.free_planes()
				if free.is_empty():
					break
				free_sum += free.size()
				steps += 1
				if free.size() <= 2:
					tight += 1
				st.launch(free[0])
		planes.sort()
		ms.sort()
		print("band %d: planes %d-%d mean %.1f | cover %s | carve ms %d-%d | tones %s | same-colour cells %.3f | holes/board %.1f | free a step %.2f, <=2 free %.0f%%" % [
			band, planes[0], planes[-1], planes.reduce(func(a, b): return a + b, 0) / float(seeds),
			str(cover), ms[0], ms[-1], str(tones), float(same) / float(cells),
			float(holes) / float(seeds), float(free_sum) / float(steps), 100.0 * tight / float(steps)])
	quit()
