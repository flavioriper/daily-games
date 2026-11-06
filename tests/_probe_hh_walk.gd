extends SceneTree

## Plays Sleepwalkers days out by logic alone (hint_step from what the
## player sees), timing each walk: every day must finish with no guess.
## `-- theme` lays each day in Pixel Garden bank things' shapes (four a day,
## as the night's sizes would come), the daily theme's cut lawns.
const State = preload("res://puzzles/hedgehogs_state.gd")

func _initialize() -> void:
	var days := 30
	var bad := 0
	var worst := 0.0
	var total_walks := 0
	var none := 0
	var themed := OS.get_cmdline_user_args().has("theme")
	var singles: Array = []
	if themed:
		var doc = JSON.parse_string(FileAccess.get_file_as_string("res://content/pixel_garden.json"))
		singles = doc.bands[0] + doc.bands[1]
	var cut := 0
	for d in days:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + d
		var st = State.new()
		var t0 := Time.get_ticks_usec()
		var pics: Array = []
		if themed:
			for i in 4:
				var p: Dictionary = singles[(d * 4 + i) % singles.size()]
				pics.append({"id": p.id, "name": p.id, "rows": p.rows})
		st.setup(rng, 3, pics)
		if st.themed():
			cut += 1
		var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var guard := 0
		while not st.is_solved() and guard < 400:
			guard += 1
			var step: Dictionary = st.hint_step()
			if step.is_empty():
				bad += 1
				print("day ", d, " stuck after ", st.walks, " walks")
				break
			var c: int = step.cell
			var t1 := Time.get_ticks_usec()
			var r: Dictionary
			if step.kind == "rake":
				r = st.rake(c)
			else:
				st.toggle_flag(c)
				continue
			var ms := (Time.get_ticks_usec() - t1) / 1000.0
			worst = maxf(worst, ms)
			if r.get("walk", Vector2i(-1, -1)) == Vector2i(-1, -1) and st.bell == 0 and String(r.kind) != "none":
				pass
			if String(r.kind) == "woke":
				bad += 1
				print("day ", d, " a proved rake woke one")
				break
		total_walks += st.walks
		print("day %d gen %.0f ms walks %d solved %s" % [d, gen_ms, st.walks, st.is_solved()])
	print("themed ", cut, "/", days, " bad ", bad, " worst rake+walk ms ", worst, " mean walks ", float(total_walks) / days)
	quit()
