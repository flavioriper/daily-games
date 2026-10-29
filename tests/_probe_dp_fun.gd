extends SceneTree

## Domino Patio, measured for the made-fun pass (2026-10-29): with the
## answer laid in a random order, how many places each tile still left
## could go without breaking a bed (State.places), and whether the tile the
## bulb would read (the fewest places) has only one. Also: what share of
## laid tiles keep a bed.
##
##     godot --headless --script res://tests/_probe_dp_fun.gd -- [n=<days a band>]

const State = preload("res://puzzles/patio_state.gd")

func _initialize() -> void:
	var n := 40
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="): n = int(a.substr(2))
	for band in 4:
		var mins := {}
		var forced := 0
		var steps := 0
		var first_forced := 0
		var keeps := 0
		var laid := 0
		var ms := 0
		var sq_forced := 0
		var either := 0
		var kinds := {}
		for seed in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + seed
			var st = State.new()
			st.deal(rng, band)
			var order: Array = []
			for t in st.tiles.size():
				if st.answer[t].x >= 0:
					order.append(t)
			order.shuffle()
			var first := true
			for t: int in order:
				var t0 := Time.get_ticks_usec()
				var read: Dictionary = st.read_hint()
				ms = maxi(ms, Time.get_ticks_usec() - t0)
				if not read.is_empty():
					kinds[read.kind] = int(kinds.get(read.kind, 0)) + 1
					var c := int(read.places)
					mins[c] = int(mins.get(c, 0)) + 1
					steps += 1
					if c == 1:
						forced += 1
						if first: first_forced += 1
				var lone := false
				for sq in st.bed_of.size():
					var w: Array = st.ways(sq)
					if int(w[0]) == 1:
						lone = true
						break
				if lone: sq_forced += 1
				if lone or (not read.is_empty() and int(read.places) == 1): either += 1
				first = false
				var before := 0
				for b in st.beds.size():
					if st.bed(b) == State.Bed.KEPT: before += 1
				st.place(t, st.answer[t].x, st.answer[t].y)
				var after := 0
				for b in st.beds.size():
					if st.bed(b) == State.Bed.KEPT: after += 1
				laid += 1
				if after > before: keeps += 1
		print("band %d: bulb readings %d, places of the read tile %s, only one place %.0f%% (on the first reading %d/%d); tiles that keep a bed %.0f%%; slowest reading %.1f ms; a square only one way %.0f%%, either %.0f%%; readings by kind %s" % [
			band, steps, str(mins), 100.0 * forced / maxf(1, steps), first_forced, n, 100.0 * keeps / maxf(1, laid), ms / 1000.0, 100.0 * sq_forced / maxf(1, steps), 100.0 * either / maxf(1, steps), str(kinds)])
	quit()
