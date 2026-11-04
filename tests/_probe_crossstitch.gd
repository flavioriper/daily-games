extends SceneTree

## Cross Stitch's banks against its rules: every sampler's fewest solved
## again here must be its banked `min`, and a few played out by the bulb
## alone stitch in exactly that many swaps. Prints the time it takes.
##   godot --headless --script tests/_probe_crossstitch.gd

const State = preload("res://puzzles/crossstitch_state.gd")

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	var bad := 0
	var slow := 0
	for lang in ["", ".pt", ".es"]:
		for bank in State.BANKS:
			var path := "res://content/insane/%s%s.json" % [bank, lang]
			var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var boards: Array = doc.boards
			var t0 := Time.get_ticks_usec()
			var worst := 0
			for k in boards.size():
				var st = State.new()
				st.band = State.BANKS.find(bank)
				var t1 := Time.get_ticks_usec()
				st.load_day(boards[k])
				worst = maxi(worst, Time.get_ticks_usec() - t1)
				if st.to_go != int(boards[k].min):
					bad += 1
					if bad < 5:
						print("MISMATCH ", path, " #", k, " ", st.to_go, " vs ", boards[k].min)
				if k < 12:
					# the bulb's swaps alone, each must cut the fewest by one
					var n := 0
					while not st.solved() and n < 40:
						var h: Vector2i = st.hint_swap()
						var before: int = st.to_go
						st.swap(h.x, h.y)
						if st.to_go != before - 1:
							slow += 1
						n += 1
					if n != int(boards[k].min):
						print("BULB ", path, " #", k, " took ", n, " vs ", boards[k].min)
			print("%s%s: %d boards, %.1f ms each, worst %.1f ms" % [bank, lang, boards.size(), (Time.get_ticks_usec() - t0) / 1000.0 / boards.size(), worst / 1000.0])
	print("mismatches ", bad, " bulb steps not cutting ", slow)
	quit()
	return true
