extends SceneTree

## Throwaway probe for Nonogram's themed deal (daily theme wave 2): Pixel
## Garden's bank things stand in for a night's, three a day as the night
## sends them (10/12/16 here: two 10s and a 12, ids in order). Prints how
## often each themed band takes a thing, how many sweeps line logic needs
## (against the generator's own on the same boxes) and the deal time.
##
##     godot --headless --script res://tests/_probe_ng_theme.gd
const Gen = preload("res://puzzles/nonogram_gen.gd")
const State = preload("res://puzzles/nonogram_state.gd")

func _sweeps(o: Dictionary) -> int:
	var st := []
	for i in int(o.w) + int(o.h):
		st.append(false)
	var L := Gen.Lines.new(o.rows, o.cols, st)
	L.line_solve()
	return L.sweeps()[0]

func _initialize() -> void:
	var doc = JSON.parse_string(FileAccess.get_file_as_string("res://content/pixel_garden.json"))
	var singles: Array = doc.bands[0] + doc.bands[1]
	for band in [1, 2]:
		var took := 0
		var days := 0
		var sw: Array = []
		var gen_sw: Array = []
		var ms := 0
		for d in range(0, singles.size() - 2, 3):
			days += 1
			var pics: Array = []
			for p in singles.slice(d, d + 3):
				pics.append({"id": p.id, "name": p.id, "rows": p.rows})
			var rng := RandomNumberGenerator.new()
			rng.seed = d
			var drawn := Gen.shape_for(rng, band)
			var t0 := Time.get_ticks_msec()
			var o := State.themed(pics, band, drawn)
			ms = maxi(ms, Time.get_ticks_msec() - t0)
			if not o.is_empty():
				took += 1
				sw.append("%s %dx%d s%d" % [o.theme.id, o.w, o.h, _sweeps(o)])
			var g := Gen.generate(rng, drawn.x, drawn.y)
			if g.ok:
				gen_sw.append(_sweeps(g))
		print("band %d: themed %d/%d days, slowest deal %d ms" % [band, took, days, ms])
		print("  themed: ", sw)
		print("  generator sweeps: ", gen_sw)
	quit()
