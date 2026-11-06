extends SceneTree

## Throwaway probe for Bridges' themed sea (daily theme): the night pictures
## this Mac's game has cached are cut per band and dealt as State.build deals
## them. Prints per band the nights that took a thing, its mask share and
## islets, attempts and the slowest deal against the square sea's.
##
##     godot --headless --path . --script res://tests/_probe_br_theme.gd -- [show]
const Gen = preload("res://puzzles/bridges_gen.gd")
const State = preload("res://puzzles/bridges_state.gd")

const CACHE := "/Users/flavioriper/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"

func _days() -> Array:
	var out: Array = []
	var files := DirAccess.get_files_at(CACHE)
	files.sort()
	for f in files:
		if not f.begins_with("pictures-2026") or not f.ends_with("-content.json"):
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
	var show := OS.get_cmdline_user_args().has("show")
	var days := _days()
	for band in 3:
		var took := 0
		var worst := 0
		var worst_plain := 0
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
			st.build(rng, band, 0, pics)
			var ms := Time.get_ticks_msec() - t0
			worst = maxi(worst, ms)
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			var t1 := Time.get_ticks_msec()
			Gen.generate(r2, band)
			worst_plain = maxi(worst_plain, Time.get_ticks_msec() - t1)
			if st.themed():
				took += 1
				lines.append("%s mask %d/%d islets %d unique %s gf %s %d ms" % [st.theme.id, st.theme.mask.size(),
					st.n * st.n, st.islets.size(), st.unique, st.guess_free, ms])
				if show:
					for y in st.n:
						var row := ""
						for x in st.n:
							var c := Vector2i(x, y)
							row += (str(st.need[c]) if st.need.has(c) else ("~" if st.theme.mask.has(c) else "."))
						lines.append("      " + row)
			else:
				var why := []
				for p in pics:
					var sh := Gen.shape_fit(p.rows, band)
					why.append("%s:%s" % [p.id, "cut" if sh.is_empty() else "grow(%d/%d,%d)" % [sh.mask.size(), st.n * st.n, sh.islets]])
				lines.append("PLAIN " + ", ".join(why))
		print("band %d: themed %d/%d, slowest %d ms (square %d ms)" % [band, took, days.size(), worst, worst_plain])
		for l in lines:
			print("   ", l)
	quit()
