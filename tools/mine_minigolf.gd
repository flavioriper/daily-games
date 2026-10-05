extends SceneTree

## Mines Mini Golf's holes: grows one for the band (puzzles/minigolf_gen.gd),
## plays it out for its par, and prints the survivors as JSON lines.
##
##     godot --headless --script res://tools/mine_minigolf.gd -- <band> <count> [seed]
##
## Par is what a decent hand takes (Gen.rate), never under the proof's putts.
## A hole is kept when its par is one of the band's, its proof still drops
## after rounding, and it is not a hole already printed. Then
## `python3 tools/merge_minigolf.py` gathers the bands' lines into
## content/minigolf.json.

const Sim = preload("res://puzzles/minigolf_sim.gd")
const Gen = preload("res://puzzles/minigolf_gen.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var band := int(args[0])
	var count := int(args[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[2]) if args.size() > 2 else 4000 + band
	var pars: Array = Gen.BANDS[band].par
	var short_cap := int(ceil(float(Gen.BANDS[band].get("short", 1.0)) * count))
	var short := 0
	var made := 0
	var tries := 0
	var seen := {}
	while made < count and tries < count * 40:
		tries += 1
		var hole := Gen.grow(rng, band)
		if hole.is_empty():
			continue
		var t0 := Time.get_ticks_msec()
		var got := Gen.solve(hole)
		var ms := Time.get_ticks_msec() - t0
		if got.is_empty():
			printerr("band %d try %d: no way down (%d ms)" % [band, tries, ms])
			continue
		var mean := Gen.rate(hole, rng)
		var par := maxi(int(got.best), roundi(mean - 0.1))
		ms = Time.get_ticks_msec() - t0
		if par == int(pars[0]) and short >= short_cap:
			printerr("band %d try %d: par %d, enough of those" % [band, tries, par])
			continue
		if par < int(pars[0]) or par > int(pars[1]):
			printerr("band %d try %d: par %d (best %d, mean %.2f, %d ms)" % [band, tries, par, got.best, mean, ms])
			continue
		hole["par"] = par
		hole["proof"] = got.proof
		hole["band"] = band
		if not Gen.proves(hole):
			printerr("band %d try %d: the rounded proof misses" % [band, tries])
			continue
		var key := JSON.stringify([hole.cells, hole.get("cuts", [])])
		if seen.has(key):
			continue
		seen[key] = true
		if par == int(pars[0]):
			short += 1
		print(JSON.stringify(hole))
		printerr("band %d #%d: par %d (best %d, mean %.2f), %d squares (%d ms)" % [band, made, par, got.best, mean, hole.cells.size(), ms])
		made += 1
	quit()
