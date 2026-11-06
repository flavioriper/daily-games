extends SceneTree

## Throwaway probe for Hosepipes' themed bed (daily theme wave 2): the night
## pictures this Mac's game has cached are cut per band and dealt as
## State.deal deals them. Prints per band the days that took a thing, the
## slowest deal, hose lengths and the bulb reader's reach on each bed.
##
##     godot --headless --path . --script res://tests/_probe_hs_theme.gd -- [bands=0123]
const Gen = preload("res://puzzles/hoses_gen.gd")
const State = preload("res://puzzles/hoses_state.gd")
const Reader = preload("res://puzzles/hoses_reader.gd")

const CACHE := "/Users/flavioriper/Library/Application Support/Godot/app_userdata/Peeplet Daily/backend_cache"

func _days() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(CACHE):
		if not f.begins_with("pictures-202611") and not f.begins_with("pictures-202610"):
			continue
		if not f.ends_with("-content.json"):
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
	var bands := "0123"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("bands="):
			bands = a.substr(6)
	var days := _days()
	print("cached days: ", days.size())
	for bc in bands:
		var band := int(bc)
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
			st.deal(rng, band, 0, pics)
			var ms := Time.get_ticks_msec() - t0
			worst = maxi(worst, ms)
			if not st.themed():
				lines.append("  (square) %d ms" % ms)
				continue
			took += 1
			var lens := []
			for p: Array in st.answer:
				lens.append(p.size())
			lens.sort()
			var day := {"n": st.n, "ends": st.ends, "seeds": st.seeds, "void": st.voids, "paths": st.answer}
			var r = Reader.new(day)
			var got: int = r.run()
			var need := st.squares() - st.count()
			# re-proved from scratch: one answer
			var one := Gen.count(day, 2)
			lines.append("  %s n%d cells %d hoses %d lens %s read %d%% one=%d deal %d ms" % [
				st.theme.id, st.n, st.squares(), st.count(), str(lens), roundi(100.0 * got / maxf(1, need)), one, ms])
		print("band %d: themed %d/%d, slowest deal %d ms" % [band, took, days.size(), worst])
		for l in lines:
			print(l)
	quit()
