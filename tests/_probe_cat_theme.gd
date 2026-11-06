extends SceneTree

## Throwaway probe for Caterpillar's themed garden (daily theme wave 2): the
## night pictures this Mac's game has cached are cut per band and dealt as
## State.build deals them. Prints per band the days that took a thing, the
## slowest deal, the squares, leaves and fences, an uncapped re-proof, and
## the careful guesser's wasted squares (tests/_probe_cat_fun.gd's measure),
## beside the plain garden's off the same seeds.
##
##     godot --headless --path . --script res://tests/_probe_cat_theme.gd -- [bands=0123] [draw]
const Gen = preload("res://puzzles/caterpillar_gen.gd")
const State = preload("res://puzzles/caterpillar_state.gd")

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
		var total := 0
		var waste := 0.0
		var waste_plain := 0.0
		var wworst := 0
		var cells := 0.0
		var leaves := 0.0
		var fences := 0.0
		var two := 0
		for i in days.size():
			var pics: Array = []
			for side in (Gen.THEMED_SIZES[band] if band < Gen.THEMED_SIZES.size() else []):
				if days[i].has(side):
					pics.append(days[i][side])
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 + i * 7 + band
			var st := State.new()
			var t0 := Time.get_ticks_usec()
			st.build(rng, band, 0, pics)
			var ms := (Time.get_ticks_usec() - t0) / 1000
			worst = maxi(worst, ms)
			total += ms
			if not st.themed():
				print("  (plain) %d ms" % ms)
				continue
			took += 1
			var s := Gen.count(st.cols, st.rows, st.leaves, st.hedges.keys(), 2, 1 << 40, 0, st.mask)
			if int(s.count) != 1:
				two += 1
			var w := _wasted(st, i)
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			var plain := State.new()
			plain.build(r2, band, 0, [])
			var wp := _wasted(plain, i)
			waste += w
			waste_plain += wp
			wworst = maxi(wworst, w)
			cells += st.size()
			leaves += st.leaves.size()
			fences += st.hedges.size()
			print("  %s %dx%d squares %d leaves %d fences %d walks %d wasted %d (plain %d) deal %d ms" % [
				st.theme.id, st.cols, st.rows, st.size(), st.leaves.size(), st.hedges.size(), int(s.count), w, wp, ms])
			if draw:
				for y in st.rows:
					var line := "    "
					for x in st.cols:
						var c := y * st.cols + x
						line += " ." if st.is_void(c) else ("%2d" % st.clue[c] if st.clue[c] > 0 else " o")
					print(line)
		var k := maxf(took, 1)
		print("band %d: themed %d/%d, worst deal %d ms, mean %d; squares %.1f leaves %.1f fences %.1f; two walks %d; wasted %.1f (worst %d) vs plain %.1f" % [
			band, took, days.size(), worst, total / maxi(days.size(), 1), cells / k, leaves / k, fences / k, two, waste / k, wworst, waste_plain / k])
	quit()

func _wasted(st, d: int) -> int:
	var w := 0
	for g in 8:
		var r := RandomNumberGenerator.new()
		r.seed = g * 7 + d
		st.body = PackedInt32Array([st.path[0]])
		var n := [0]
		_dfs(st, r, n)
		w += n[0]
	st.body = PackedInt32Array()
	return w / 8

func _ways(st) -> Array:
	var out := []
	var h: int = st.head()
	for nb in [h - 1, h + 1, h - st.cols, h + st.cols]:
		if nb < 0 or nb >= st.box() or not st.adjacent(h, nb) or st.body.has(nb):
			continue
		if st.why(nb) != "":
			continue
		if not st.stranded(nb).is_empty():
			continue
		out.append(nb)
	return out

func _dfs(st, r: RandomNumberGenerator, n: Array) -> bool:
	if st.is_solved():
		return true
	if n[0] > 20000:
		return true
	var ways := _ways(st)
	for i in range(ways.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var t = ways[i]; ways[i] = ways[j]; ways[j] = t
	for nb in ways:
		st.body.append(nb)
		if _dfs(st, r, n):
			return true
		st.body.resize(st.body.size() - 1)
		n[0] += 1
	return false
