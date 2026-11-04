extends SceneTree

## Padlock's banks against its rules: every lock's par solved again here
## over its fair words must be its banked `min`, the fewest over every word
## never more than par, and a few locks played by the bulb alone open in
## exactly par words. Prints the time it takes.
##   godot --headless --script tests/_probe_padlock.gd

const State = preload("res://puzzles/padlock_state.gd")

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	var bad := 0
	var over := 0
	var bulb := 0
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
				var fair_par: int = st._fewest_fair(st.full)
				worst = maxi(worst, Time.get_ticks_usec() - t1)
				if fair_par != int(boards[k].min):
					bad += 1
					if bad < 5:
						print("MISMATCH ", path, " #", k, " ", fair_par, " vs ", boards[k].min)
				if st.to_go > st.par:
					over += 1
				if st.knows(st.window()):
					print("START IS A WORD ", path, " #", k)
				if k < 20:
					var n := 0
					while not st.solved() and n < 20:
						var w: String = st.hint_word()
						if w == "":
							break
						st.dial_to(w)
						st.read()
						n += 1
					if n != st.par or not st.solved():
						bulb += 1
						print("BULB ", path, " #", k, " took ", n, " vs ", st.par, " solved ", st.solved())
			print("%s%s: %d locks, %.2f ms each, worst %.1f ms" % [bank, lang, boards.size(), (Time.get_ticks_usec() - t0) / 1000.0 / boards.size(), worst / 1000.0])
	print("mismatches ", bad, " fewest over par ", over, " bulb off par ", bulb)
	quit()
	return true
