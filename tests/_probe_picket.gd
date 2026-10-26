extends SceneTree
## Throwaway: Picket Sums' days. Live generation per band (time, givens,
## lost tags), then every banked day re-proved by from_bank + deduce (and
## how hard it reasons, PG.pencil_steps), and
## PicketState.setup timed per band as the board opens it.
const PG = preload("res://puzzles/picket_gen.gd")
const Gen = preload("res://puzzles/sudoku_gen.gd")
const PS = preload("res://puzzles/picket_state.gd")
func _initialize() -> void:
	for band in 2:
		var worst := 0
		var giv := []
		for s in 12:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + s * 7919 + band
			var t := Time.get_ticks_msec()
			var out := PG.generate(rng, band)
			worst = maxi(worst, Time.get_ticks_msec() - t)
			giv.append(Gen.givens_of(out.puzzle))
			assert(PG.deduce(out.puzzle, out.plots, out.sums, PG.TIER[band]))
		print("live band %d worst %d ms givens %s" % [band, worst, str(giv)])
	for bank in ["picket_hard", "picket"]:
		var tier: int = PG.TIER[2 if bank == "picket_hard" else 3]
		var bad := 0
		var giv := {}
		var lost := {}
		var pencils := 0
		for b in InsaneBank.boards(bank):
			var d := PG.from_bank(b)
			if d.is_empty() or not PG.deduce(d.puzzle, d.plots, d.sums, tier):
				bad += 1
				continue
			var g := Gen.givens_of(d.puzzle)
			giv[g] = int(giv.get(g, 0)) + 1
			var l := Array(d.sums).count(-1)
			lost[l] = int(lost.get(l, 0)) + 1
			pencils += PG.pencil_steps(d.puzzle, d.plots, d.sums)
		print("%s: %d boards, %d bad, givens %s, lost %s, pencil steps a day %.1f" % [bank, InsaneBank.size(bank), bad,
			giv, lost, pencils / float(maxi(1, InsaneBank.size(bank)))])
	for band in 4:
		var t := Time.get_ticks_msec()
		var st := PS.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		st.setup(rng, band)
		print("setup band %d: %d ms, %dx%d, %d plots, %d lost" % [band, Time.get_ticks_msec() - t, Gen.N, Gen.N, st.plots.size(), st.lost_count()])
	quit()
