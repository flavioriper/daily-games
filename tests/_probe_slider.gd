extends SceneTree

## Super Slider's solver and state, headless: the classic layout's famous
## figures (25,955 positions, 81 moves), then a day dealt from every band,
## played down its hints with an undo and a reset on the way, checking the
## key stays true to the blocks and the par to the solver.
##     godot --headless --script tests/_probe_slider.gd
const Gen = preload("res://puzzles/slider_gen.gd")
const State = preload("res://puzzles/slider_state.gd")

func _process(_d: float) -> bool:
	var k := Gen.decode(Gen.CLASSIC)
	var t0 := Time.get_ticks_msec()
	var r := Gen.distances(k)
	print("classic: %d positions, %d moves, %d ms" % [r.keys.size(), r.dist[0], Time.get_ticks_msec() - t0])
	var bad := 0
	for band in 4:
		for seed_ in 3:
			var rng := RandomNumberGenerator.new()
			rng.seed = 100 * band + seed_
			var st := State.new()
			st.build(rng, band)
			t0 = Time.get_ticks_msec()
			var d := st.distance()
			var wait := Time.get_ticks_msec() - t0
			if d != st.par:
				print("  band %d seed %d: par %d but solver says %d" % [band, seed_, st.par, d])
				bad += 1
			var n := 0
			var undone := false
			while not st.is_solved() and n < 400:
				var m := st.hint_move()
				if m.is_empty():
					break
				st.play(m.p, m.to)
				n += 1
				if n == 3 and not undone:
					st.undo()
					st.undo()
					n -= 2
					undone = true
			var sum := 0
			for b: Array in st.blocks:
				sum += Gen.contrib(int(b[0]), int(b[1]))
			if sum != st.key or not st.is_solved() or n != st.par:
				print("  band %d seed %d: solved=%s moves %d par %d key ok=%s" % [band, seed_, st.is_solved(), n, st.par, sum == st.key])
				bad += 1
			st.reset_board()
			if st.key != st.start_key:
				bad += 1
			print("band %d seed %d: par %d, %d positions, hint wait %d ms, played in %d" % [
				band, seed_, st.par, st.dist_table().keys.size(), wait, n])
	print("bad=", bad)
	return true
