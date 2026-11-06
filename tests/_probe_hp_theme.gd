extends SceneTree

## Throwaway probe for Horse Pen's themed meadow (daily theme wave 2): the
## night pictures this Mac's game has cached are cut per band and laid as
## State.setup lays them. Prints per band the days that took a thing, the
## slowest deal, and the live search's best against a long search of the
## same meadow (the stars hang on `best`). `base` also measures the live
## search on the bank's own rectangles against the banked best.
##
##     godot --headless --path . --script res://tests/_probe_hp_theme.gd -- [base] [long=<steps>]
const Gen = preload("res://puzzles/horse_gen.gd")
const State = preload("res://puzzles/horse_state.gd")

const CACHE := "/Users/flavioriper/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"

func _days() -> Array:
	var out: Array = []
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

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var long_steps := 120000
	for a in args:
		if a.begins_with("long="):
			long_steps = int(a.substr(5))
	if args.has("base"):
		for band in 4:
			var pool := State.pool(band)
			var gap := 0.0
			var under := 0
			var k := 12
			for j in k:
				var m := Gen.unpack(pool[j])
				var rng := RandomNumberGenerator.new()
				rng.seed = 77 + j
				var f := Gen.search(rng, m, int(m.budget), Gen.GROWS_LIVE, Gen.STEPS_LIVE)
				var s := int(f.get("score", 0))
				gap += float(s) / float(m.best)
				if float(s) < 0.95 * float(m.best):
					under += 1
			print("base band %d: live/bank best mean %.3f, under 95%% %d/%d" % [band, gap / k, under, k])
	var days := _days()
	print("cached days: ", days.size())
	for band in 4:
		var took := 0
		var worst := 0
		var lines: Array = []
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
			var ms := Time.get_ticks_msec() - t0
			worst = maxi(worst, ms)
			if not st.themed():
				lines.append("  (rectangle) %d ms" % ms)
				continue
			took += 1
			var r2 := RandomNumberGenerator.new()
			r2.seed = 5
			var t1 := Time.get_ticks_msec()
			var ref := Gen.search(r2, st.m, st.budget, Gen.GROWS_MINE, long_steps)
			var lms := Time.get_ticks_msec() - t1
			lines.append("  %s %dx%d lawn %d best %d long %d (%.0f%%) deal %d ms long %d ms" % [
				st.theme.id, st.w, st.h, Gen.lawn_of({"w": st.w, "h": st.h, "void": _vb(st.m)}),
				st.best, int(ref.get("score", 0)), 100.0 * st.best / maxf(1, int(ref.get("score", 1))), ms, lms])
		print("band %d: themed %d/%d, slowest deal %d ms" % [band, took, days.size(), worst])
		for l in lines:
			print(l)
	quit()

func _vb(m: Dictionary) -> PackedByteArray:
	var v := PackedByteArray()
	var block: PackedByteArray = m.block
	v.resize(block.size())
	for i in block.size():
		v[i] = 1 if block[i] == Gen.VOID else 0
	return v
