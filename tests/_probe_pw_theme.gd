extends SceneTree

## Throwaway probe for Pinwheel's themed frame (daily theme wave 5): the
## night pictures this Mac's game has cached are cut per band and dealt as
## State.setup deals them. Prints per band the days that took a thing, the
## slowest deal, the squares, pieces, par and how much of the frame the
## board's own reading carries, beside the plain frame off the same seeds.
##
##     godot --headless --path . --script res://tests/_probe_pw_theme.gd -- [bands=012] [draw]
const Gen = preload("res://puzzles/pinwheel_gen.gd")
const State = preload("res://puzzles/pinwheel_state.gd")

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
	for bc in bands:
		var band := int(bc)
		var took := 0
		var worst := 0
		var sq := 0.0
		var pcs := 0.0
		var par := 0.0
		var read := 0.0
		var p_par := 0.0
		var p_read := 0.0
		var bad := 0
		for i in days.size():
			var pics: Array = []
			for side in Gen.THEMED_SIZES[band]:
				if days[i].has(side):
					pics.append(days[i][side])
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i * 7 + band
			var st := State.new()
			var t0 := Time.get_ticks_usec()
			st.setup(rng, band, pics)
			var ms := (Time.get_ticks_usec() - t0) / 1000
			worst = maxi(worst, ms)
			if not st.themed():
				print("  (plain) %d ms" % ms)
				continue
			took += 1
			if Gen.count_tilings(st.shapes, st.cols, st.rows, 2, st.voids) != 1 or st.is_solved():
				bad += 1
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			var plain := State.new()
			plain.setup(r2, band)
			var cells := st.cols * st.rows - st.voids.size()
			var a := float(st.reading_chain().size()) / float(st.shapes.size())
			var b := float(plain.reading_chain().size()) / float(plain.shapes.size())
			sq += cells
			pcs += st.shapes.size()
			par += st.par
			read += a
			p_par += plain.par
			p_read += b
			print("  %s %dx%d squares %d pieces %d par %d read %.2f (plain par %d read %.2f) deal %d ms" % [
				st.theme.id, st.cols, st.rows, cells, st.shapes.size(), st.par, a, plain.par, b, ms])
			if draw:
				print(st.share_glyphs())
		var k := maxf(took, 1)
		print("band %d: themed %d/%d, worst deal %d ms; squares %.1f pieces %.1f par %.1f read %.2f | plain par %.1f read %.2f | bad %d" % [
			band, took, days.size(), worst, sq / k, pcs / k, par / k, read / k, p_par / k, p_read / k, bad])
	quit()
