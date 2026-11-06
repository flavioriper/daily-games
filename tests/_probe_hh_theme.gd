extends SceneTree

## Throwaway probe for Hedgehogs' themed lawn (daily theme wave 2): the
## night pictures this Mac's game has cached (or Pixel Garden's bank things,
## three a day, with `bank`) are cut per band and dealt as State.setup deals
## them. Prints per band the days that took a thing, the lawn's cells and
## hedgehogs, the slowest deal, and the made-fun gates (the opening's first
## reading, a reader of singles' stall) against the rectangle's.
##
##     godot --headless --path . --script res://tests/_probe_hh_theme.gd -- [bank] [cache=<dir>]
const Gen = preload("res://puzzles/hedgehogs_gen.gd")
const State = preload("res://puzzles/hedgehogs_state.gd")

const CACHE := "/Users/flavioriper/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"

func _days(bank: bool) -> Array:
	var out: Array = []
	if bank:
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://content/pixel_garden.json"))
		var singles: Array = doc.bands[0] + doc.bands[1]
		for d in range(0, singles.size() - 3, 4):
			var sizes := {}
			var i := 0
			for side in [10, 12, 24, 32]:
				sizes[side] = {"id": singles[d + i].id, "name": singles[d + i].id, "rows": singles[d + i].rows}
				i += 1
			out.append(sizes)
		return out
	for f in DirAccess.get_files_at(CACHE):
		if not f.begins_with("pictures-202611") or not f.ends_with("-content.json"):
			continue
		var doc = JSON.parse_string(FileAccess.get_file_as_string(CACHE + "/" + f))
		var sizes := {}
		for k in (doc.get("sizes", {}) as Dictionary):
			var p: Dictionary = doc.sizes[k]
			sizes[int(k)] = {"id": p.id, "name": p.id, "rows": p.rows}
		if not sizes.is_empty():
			out.append(sizes)
	return out

func _stall(g: Dictionary) -> int:
	var open := PackedByteArray()
	open.resize(g.n)
	Gen.flood(g, open, g.start)
	var known := PackedByteArray()
	known.resize(g.n)
	var d := Gen.deduce(g, open, known, false)
	while not d.is_empty() and d.rule == "single":
		for r: int in d.hogs:
			known[r] = 1
		for r: int in d.safe:
			Gen.flood(g, open, r)
		d = Gen.deduce(g, open, known, false)
	var left := 0
	for c in int(g.n):
		if g.hog[c] == 0 and open[c] == 0 and not Gen.is_void(g, c):
			left += 1
	return left

func _initialize() -> void:
	var bank := OS.get_cmdline_user_args().has("bank")
	var days := _days(bank)
	for band in 4:
		var took := 0
		var worst := 0
		var lines: Array = []
		var stall_t := 0
		var stall_r := 0
		for i in days.size():
			var pics: Array = []
			for side in Gen.THEMED_SIZES[band]:
				if days[i].has(side):
					pics.append(days[i][side])
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i * 7 + band
			var st := State.new()
			var t0 := Time.get_ticks_msec()
			st.setup(rng, band, pics)
			worst = maxi(worst, Time.get_ticks_msec() - t0)
			var cells := 0
			for c in st.size():
				if not st.is_void(c):
					cells += 1
			if st.themed():
				took += 1
				stall_t += _stall(st.g)
				lines.append("%s %dx%d cells %d k %d open %d att %d sub %d" % [st.theme.id, st.cols(), st.rows(),
					cells, st.g.k, st.g.opened, st.g.attempts, st.g.proof.sub])
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			stall_r += _stall(Gen.generate(r2, band))
		print("band %d: themed %d/%d, slowest deal %d ms, singles stall left (themed sum %d, rect sum %d)" % [band, took, days.size(), worst, stall_t, stall_r])
		for l in lines:
			print("   ", l)
	quit()
