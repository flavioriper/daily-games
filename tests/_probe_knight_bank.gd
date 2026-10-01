extends SceneTree

## Knight's Brambles bank re-proved in GDScript: every banked board's line
## replays through `step` to a win never caught, and the board's own breadth
## first search finds a shortest line of the same length the miner wrote.
## Then lost()'s cost on random Hard and Easy positions. A harness.
##     godot --headless --path . --script tests/_probe_knight_bank.gd
const G := preload("res://puzzles/knight_gen.gd")
const S := preload("res://puzzles/knight_state.gd")
const InsaneBank := preload("res://core/insane_bank.gd")

func _initialize() -> void:
	var rows: Array = InsaneBank.boards("knight")
	var bad := 0
	var worst := 0.0
	var naps := 0
	for i in rows.size():
		var g := G.from_bank(rows[i])
		var you: int = g.you
		var foes: PackedInt32Array = g.foes
		var mask := 0
		var ok := true
		for k in g.line.size():
			mask |= 1 << you
			var r: Dictionary = G.step(g, you, foes, g.line[k], mask)
			naps += r.napped.size()
			if int(r.caught) >= 0 or (bool(r.won) != (k == g.line.size() - 1)):
				ok = false
				break
			you = r.you
			foes = r.foes
		var t0 := Time.get_ticks_usec()
		var line := G.solve(g, g.you, g.foes, 64)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		worst = maxf(worst, ms)
		if not ok or line.size() != int(g.opt):
			bad += 1
			print("BAD row %d: replay %s, solve %d vs %d" % [i, ok, line.size(), g.opt])
	print("bank: %d boards, bad %d, naps on the lines %d, solve worst %.1f ms" % [rows.size(), bad, naps, worst])
	for band in 3:
		var lw := 0.0
		var lost := 0
		var n := 0
		for s in 30:
			var st = S.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = s * 31 + band
			st.build(rng, band)
			var walk := RandomNumberGenerator.new()
			walk.seed = s
			for k in 12:
				var lg: PackedInt32Array = st.legal()
				st.play(lg[walk.randi_range(0, lg.size() - 1)])
				if st.won:
					break
				var t0 := Time.get_ticks_usec()
				if st.lost():
					lost += 1
				lw = maxf(lw, (Time.get_ticks_usec() - t0) / 1000.0)
				n += 1
		print("band %d: lost() on %d random positions, %d lost, worst %.1f ms" % [band, n, lost, lw])
	quit()
