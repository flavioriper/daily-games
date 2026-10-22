extends SceneTree

## Throwaway: Domino Patio's generator over many seeds a band; time, tries,
## uniqueness, steps. `-- n=<seeds>`.

const Gen = preload("res://puzzles/patio_gen.gd")

func _initialize() -> void:
	var n := 60
	for a in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n = int(a.substr(2))
	for band in 4:
		var worst := 0.0
		var total := 0.0
		var not_unique := 0
		var tries := 0
		var beds := 0
		var rules := {}
		var singles := 0
		for s in n:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261022 + s * 7919 + band
			var g = Gen.new()
			var t0 := Time.get_ticks_usec()
			g.deal(rng, band)
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			worst = maxf(worst, ms)
			total += ms
			tries += g.tries
			beds += g.beds.size()
			if not g.unique:
				not_unique += 1
			for b in g.beds:
				rules[b.rule] = int(rules.get(b.rule, 0)) + 1
				if (b.cells as Array).size() == 1 and int(b.rule) != 0:
					singles += 1
			# the answer keeps every rule
			if g.count(2) < 1:
				print("BAD: answer does not count, band %d seed %d" % [band, s])
		print("band %d: mean %.1f ms, worst %.1f ms, tries %.2f, beds %.1f, singles %.1f, not unique %d/%d, rules %s" % [
			band, total / n, worst, float(tries) / n, float(beds) / n, float(singles) / n, not_unique, n, str(rules)])
	quit()
