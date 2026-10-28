extends SceneTree
## Throwaway (the made-fun pass, 2026-10-28): how far a player reading one
## square at a time gets on a fresh Hosepipes bed (puzzles/hoses_reader.gd),
## and that every link it finds is the answer's.
##   godot --headless --path . --script tests/_probe_hs_fun.gd -- [days] [bands]
const Gen = preload("res://puzzles/hoses_gen.gd")
const Reader = preload("res://puzzles/hoses_reader.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 40
	var bands := String(args[1]) if args.size() > 1 else "0123"
	for bc in bands:
		var band := int(bc)
		var share := 0.0
		var full := 0
		var wrong := 0
		var worst := 1.0
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 20261028 + s * 7919 + band
			var day := Gen.deal(rng, band)
			if day.is_empty():
				continue
			var truth := {}
			var total := 0
			for p: Array in day.paths:
				for i in p.size() - 1:
					truth[Reader.key(int(p[i]), int(p[i + 1]))] = true
					total += 1
			var r := Reader.new(day)
			r.run()
			for k in r.side:
				if int(r.side[k]) == Reader.YES and not truth.has(k):
					wrong += 1
			var f := r.links() / float(total)
			share += f
			worst = minf(worst, f)
			if r.links() == total:
				full += 1
		print("band %d: read %.0f%% of links on average, worst %.0f%%, whole bed %d/%d, wrong links %d" % [band, 100.0 * share / days, 100.0 * worst, full, days, wrong])
	quit()
