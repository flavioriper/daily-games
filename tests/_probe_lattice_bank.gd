extends SceneTree

## Re-proves Lattice's bank (content/lattice.json) against the rules as they
## stand: every deal reads, is its band's size with its band's knots, its
## answer holds 1 to n once on every whole line, its opening is the answer's
## own tiles moved about, and the swaps the bulb would make finish it. It
## prints how far over par the bulb's own solve runs. Headless:
##
##     godot --headless --script res://tests/_probe_lattice_bank.gd
##
## Re-mine (tools/build_lattice.py) when a band in puzzles/lattice_gen.gd
## changes; that script is what proves a deal has one answer.

const Gen = preload("res://puzzles/lattice_gen.gd")
const State = preload("res://puzzles/lattice_state.gd")

func _initialize() -> void:
	var bad := 0
	for band in Gen.BANDS.size():
		var pool: Array = State.pool(band)
		var over := 0
		var worst := 0
		for line: String in pool:
			var deal := Gen.unpack(line)
			var st = State.new()
			st.band = band
			var ok := not deal.is_empty()
			if ok:
				st.adopt(deal)
				ok = st.n == int(Gen.BANDS[band].n) and st.knots.size() == int(Gen.BANDS[band].knots)
				for l: PackedInt32Array in st.lines:
					var seen := {}
					for i in l:
						seen[st.sol[i]] = true
					ok = ok and seen.size() == st.n
				var a := Array(st.sol)
				var b := Array(st.cur)
				a.sort()
				b.sort()
				ok = ok and a == b and not st.is_solved()
				while ok and not st.is_solved():
					var h: Array = st.hint()
					ok = not h.is_empty() and st.swap(h[0], h[1]) == State.OK and st.swaps <= 60
				if st.swaps > st.par:
					over += 1
				worst = maxi(worst, st.swaps - st.par)
				ok = ok and st.swaps >= st.par
			if not ok:
				bad += 1
				print("band %d: a deal that does not prove: %s" % [band, line])
		print("band %d: %d deals, the bulb over par on %d (by %d at most)" % [band, pool.size(), over, worst])
	print("bank ok" if bad == 0 else "bank BAD: %d" % bad)
	quit()
