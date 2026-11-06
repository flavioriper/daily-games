extends SceneTree

## Throwaway probe for Light Up's themed court (daily theme wave 2): the
## night pictures this Mac's game has cached are cut per band and dealt as
## State.setup deals them. Prints per band the days that took a thing, the
## slowest deal, the stones, lamps and numbers, and how often the board's own
## reader (State.read, from an empty court, the answer laid as it reads) has
## no rule and must say "a good place to start" -- the share of the court
## the rules alone cannot reach -- beside the plain court off the same seeds.
##
##     godot --headless --path . --script res://tests/_probe_lu_theme.gd -- [bands=012] [draw]
const Gen = preload("res://puzzles/lightup_gen.gd")
const State = preload("res://puzzles/lightup_state.gd")

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
		var stones := 0.0
		var lamps := 0.0
		var nums := 0.0
		var starts := 0.0
		var p_stones := 0.0
		var p_starts := 0.0
		var two := 0
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
			if not st.themed():
				print("  (plain) %d ms" % ms)
				continue
			took += 1
			if Gen.solve_count(st.grid, st.w, st.h, 2) != 1:
				two += 1
			var r2 := RandomNumberGenerator.new()
			r2.seed = 1000 + i * 7 + band
			var plain := State.new()
			plain.setup(r2, band, 0, [])
			var a := _starts(st)
			var b := _starts(plain)
			var n := _numbers(st)
			stones += st.white_cells().size()
			lamps += st.solution.size()
			nums += n
			starts += a
			p_stones += plain.white_cells().size()
			p_starts += b
			print("  %s %dx%d stones %d lamps %d numbers %d starts %d (plain %d stones, %d starts) deal %d ms" % [
				st.theme.id, st.w, st.h, st.white_cells().size(), st.solution.size(), n, a,
				plain.white_cells().size(), b, ms])
			if draw:
				for y in st.h:
					var line := "    "
					for x in st.w:
						var c := Vector2i(x, y)
						var v := int(st.grid[y][x])
						line += " " if st.is_void(c) else ("*" if st.solution.has(c) else ("." if v == Gen.WHITE else ("#" if v < 0 else str(v))))
					print(line)
		var k := maxf(took, 1)
		print("band %d: themed %d/%d, worst deal %d ms; stones %.1f lamps %.1f numbers %.1f starts %.2f | plain stones %.1f starts %.2f | two answers %d" % [
			band, took, days.size(), worst, stones / k, lamps / k, nums / k, starts / k, p_stones / k, p_starts / k, two])
	quit()

func _numbers(st) -> int:
	var n := 0
	for y in st.h:
		for x in st.w:
			if int(st.grid[y][x]) >= 0:
				n += 1
	return n

## Readings with no rule behind them, laying each read lamp down.
func _starts(st) -> int:
	var n := 0
	for _i in 64:
		var r: Dictionary = st.read()
		if r.is_empty():
			break
		if int(r.why) == State.WHY_START:
			n += 1
		st.tap(r.cell)
	st.reset()
	return n
