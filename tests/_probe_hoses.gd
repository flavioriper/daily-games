extends SceneTree
## Throwaway: Hosepipes' days. `days` deals a band: the worst and mean deal
## time, the attempts a deal took, and every dealt answer re-proved unique
## and checked to water every square.
##   godot --headless --path . --script tests/_probe_hoses.gd -- [days] [bands]
const Gen = preload("res://puzzles/hoses_gen.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 365
	var bands := String(args[1]) if args.size() > 1 else "0123"
	for bc in bands:
		var band := int(bc)
		var worst := 0
		var total := 0
		var att := 0
		var bad := 0
		var fails := 0
		var hoses := {}
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261022 + s * 7919 + band
			var t := Time.get_ticks_msec()
			var day := Gen.deal(rng, band)
			var dt := Time.get_ticks_msec() - t
			worst = maxi(worst, dt)
			total += dt
			if day.is_empty():
				fails += 1
				continue
			att += int(day.attempts)
			hoses[(day.ends as Array).size()] = int(hoses.get((day.ends as Array).size(), 0)) + 1
			var seen := {}
			for p: Array in day.paths:
				for c in p:
					seen[c] = true
			if seen.size() != int(day.n) * int(day.n) or Gen.count(day, 3) != 1:
				bad += 1
		print("band %d: worst %d ms mean %.1f ms, attempts mean %.1f, hoses %s, fails %d bad %d" % [band, worst, total / float(days), att / float(maxi(1, days - fails)), str(hoses), fails, bad])
	# a day is the same bed every time it is dealt from the same seed
	for band in 2:
		var same := true
		for s in 20:
			var r1 := RandomNumberGenerator.new()
			r1.seed = 777 + s
			var r2 := RandomNumberGenerator.new()
			r2.seed = 777 + s
			var d1 := Gen.deal(r1, band)
			var d2 := Gen.deal(r2, band)
			same = same and d1.paths == d2.paths and d1.ends == d2.ends
		print("band %d deterministic: %s" % [band, same])
	# the tutorial's Insane bed is not today's
	var tut_pool := InsaneBank.boards("hoses")
	var tut := Gen.from_bank(tut_pool[20261022 % tut_pool.size()])
	var today := Gen.from_bank(InsaneBank.pick("hoses", 0))
	print("tutorial bed is today's: %s" % [tut.ends == today.ends])
	# the banks: every day loads, waters every square and has one answer
	for bank in ["hoses_hard", "hoses"]:
		var pool := InsaneBank.boards(bank)
		var bad_bank := 0
		var worst_load := 0
		var sizes := {}
		for entry in pool:
			var t := Time.get_ticks_usec()
			var day := Gen.from_bank(entry)
			worst_load = maxi(worst_load, Time.get_ticks_usec() - t)
			if day.is_empty() or Gen.count(day, 2) != 1:
				bad_bank += 1
				continue
			sizes[(day.ends as Array).size()] = int(sizes.get((day.ends as Array).size(), 0)) + 1
		print("bank %s: %d days, %d bad, hoses %s, worst load %d us" % [bank, pool.size(), bad_bank, str(sizes), worst_load])
	# the state plays the answer to a solve, and a stroke across a hose cuts
	# it and grows it back
	var S = load("res://puzzles/hoses_state.gd")
	for band in 4:
		var st = S.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 99 + band
		st.deal(rng, band)
		for c in st.count():
			var p: Array = st.answer[c]
			st.begin(int(p[0]))
			for i in range(1, p.size()):
				st.step(int(p[i]))
			st.end_stroke()
		print("band %d state: solved %s, strokes %d, %d seeds" % [band, st.solved(), st.strokes, st.seeds.size()])
	quit()
