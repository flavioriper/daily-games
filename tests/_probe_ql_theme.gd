extends SceneTree

## Throwaway probe for Quilt's themed outline (daily theme wave 2): the night
## pictures this Mac's game has cached are cut per band and dealt as
## State.setup deals them. Prints per band the days that took a thing, the
## slowest deal, the patches, the proof re-run and how far the quilt reads,
## and checks a plain deal is the same quilt with no pictures handed in.
##
##     godot --headless --path . --script res://tests/_probe_ql_theme.gd -- [bands=012] [draw]
const Gen = preload("res://puzzles/quilt_gen.gd")
const State = preload("res://puzzles/quilt_state.gd")

const CACHE := "/Users/flavioriper/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"

func _days() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(CACHE):
		if not (f.begins_with("pictures-202611") or f.begins_with("pictures-202610")) or not f.ends_with("-content.json"):
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
	var bands := "012"
	var draw := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bands="):
			bands = a.substr(6)
		if a == "draw":
			draw = true
	var days := _days()
	print("cached days: ", days.size())
	if "prof" in OS.get_cmdline_user_args():
		_prof(days, int(bands[0]))
		quit()
		return
	if "tries" in OS.get_cmdline_user_args():
		_tries(days, bands)
		quit()
		return
	for bc in bands:
		var band := int(bc)
		var took := 0
		var worst := 0
		var total := 0
		var lines: Array = []
		for i in days.size():
			var pics: Array = []
			for side in Gen.THEMED_SIZES[band]:
				if days[i].has(side):
					pics.append(days[i][side])
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i * 7 + band
			var st := State.new()
			var t0 := Time.get_ticks_usec()
			st.setup(rng, band, 0, pics)
			var ms := (Time.get_ticks_usec() - t0) / 1000
			worst = maxi(worst, ms)
			total += ms
			# the plain deal off the same seed is untouched by the pictures
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			var plain := State.new()
			plain.setup(r2, band, 0, [])
			if not st.themed():
				lines.append("  (plain) %d ms" % ms)
				continue
			took += 1
			var proof := Gen.count_tilings(st.cols, st.rows, st.region, st.shapes, 2)
			var read := Gen.readable(st.cols, st.rows, st.region, st.shapes)
			lines.append("  %s %dx%d cells %d patches %d one=%s nodes %d read %d/%d deal %d ms" % [
				st.theme.id, st.cols, st.rows, st.quilt_cells, st.shapes.size(),
				str(int(proof.count) == 1), int(proof.nodes), read, st.shapes.size(), ms])
			if draw:
				for r in st.rows:
					var line := "    "
					for c in st.cols:
						line += "#" if st.region[r * st.cols + c] == 1 else "."
					lines.append(line)
		print("band %d: themed %d/%d, slowest %d ms, mean %d ms" % [band, took, days.size(), worst, total / maxi(1, days.size())])
		for l in lines:
			print(l)
	quit()

## Per band, per picture: the grows a shaped deal takes (up to 3000) and the
## time a grow costs, so THEME_TRIES can be read off.
func _tries(days: Array, bands: String) -> void:
	for bc in bands:
		var band := int(bc)
		var got: Array = []
		var fail := 0
		var us := 0
		var n := 0
		var why := [0, 0, 0]
		for i in days.size():
			for side in Gen.THEMED_SIZES[band]:
				if not days[i].has(side):
					continue
				var shape := Gen.shape_fit(days[i][side].rows, band)
				if shape.is_empty():
					continue
				var rng := RandomNumberGenerator.new()
				rng.seed = 77 + i * 13 + side
				var t0 := Time.get_ticks_usec()
				var tries := 0
				var ok := false
				for k in 3000:
					tries += 1
					var g := Gen._grow_in(rng, shape, Gen.BANDS[band], int(Gen.THEME_PATCHES[band]))
					if g.is_empty():
						why[0] += 1
						continue
					var bd := Gen._proved(g, k)
					if not bool(bd.unique):
						why[1] += 1
						continue
					var need := ceili(float(Gen.READ_SHARE[band]) * bd.shapes.size())
					if Gen.readable(bd.cols, bd.rows, bd.region, bd.shapes, PackedByteArray(), need) >= need:
						ok = true
						break
					why[2] += 1
				us += Time.get_ticks_usec() - t0
				n += tries
				if "each" in OS.get_cmdline_user_args():
					print("   %s %d: %s %d cells %d" % [days[i][side].id, side, "ok" if ok else "FAIL", tries, int(shape.cells)])
				if ok:
					got.append(tries)
				else:
					fail += 1
		got.sort()
		print("  wedged %d, two tilings %d, unread %d" % why)
		print("band %d: ok %d fail %d, tries p50 %d p90 %d max %d, %.2f ms a try" % [band, got.size(), fail,
			got[got.size() / 2] if got.size() > 0 else -1, got[got.size() * 9 / 10] if got.size() > 0 else -1,
			got.max() if got.size() > 0 else -1, us / 1000.0 / maxf(1, n)])

func _prof(days: Array, band: int) -> void:
	var tg := 0
	var tp := 0
	var tr := 0
	var ng := 0
	var np := 0
	var nr := 0
	var hist := {}
	for i in days.size():
		for side in Gen.THEMED_SIZES[band]:
			if not days[i].has(side):
				continue
			var shape := Gen.shape_fit(days[i][side].rows, band)
			if shape.is_empty():
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = i
			for k in 80:
				var t0 := Time.get_ticks_usec()
				var g := Gen._grow_in(rng, shape, Gen.BANDS[band], int(Gen.THEME_PATCHES[band]))
				tg += Time.get_ticks_usec() - t0
				ng += 1
				if g.is_empty():
					continue
				t0 = Time.get_ticks_usec()
				var bd := Gen._proved(g, k)
				tp += Time.get_ticks_usec() - t0
				np += 1
				if not bd.unique:
					continue
				t0 = Time.get_ticks_usec()
				var got := Gen.readable(bd.cols, bd.rows, bd.region, bd.shapes, PackedByteArray(), bd.shapes.size())
				hist[got if got < bd.shapes.size() else 9] = int(hist.get(got if got < bd.shapes.size() else 9, 0)) + 1
				tr += Time.get_ticks_usec() - t0
				nr += 1
	print("read reached (9 = all): ", hist)
	print("grow %d x %.3f ms, proof %d x %.3f ms, read %d x %.3f ms" % [ng, tg / 1000.0 / ng, np, tp / 1000.0 / maxi(1, np), nr, tr / 1000.0 / maxi(1, nr)])
