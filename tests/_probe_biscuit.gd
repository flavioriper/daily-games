extends SceneTree

## Biscuit Tin's banks against its rules: in every tin the runs of four
## pieces the tin takes are exactly its biscuits, every piece is different
## and the biscuits' pieces and the crumbs make up the tin; a few tins
## played by the bulb alone come out whole with no points; a few played by
## a hand that lays each biscuit's pieces come out whole at 8 a biscuit; the
## line lies between the biscuits' points and half again. Prints the time.
##   godot --headless --path . --script tests/_probe_biscuit.gd

const State = preload("res://puzzles/biscuit_state.gd")

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	var bad := 0
	for lang in ["", ".pt", ".es"]:
		for bank in State.BANKS:
			var path := "res://content/insane/%s%s.json" % [bank, lang]
			var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var boards: Array = doc.boards
			var t0 := Time.get_ticks_usec()
			var band := State.BANKS.find(bank)
			for k in boards.size():
				var st = State.new()
				st.band = band
				st.load_day(boards[k])
				var nb: int = [3, 5, 5, 5][band]
				var crumbs: int = 4 if band == 3 else 0
				if st.biscuits.size() != nb or st.pieces.size() != nb * 4 + crumbs or st.crumbs.size() != crumbs:
					bad += 1
					print("SHAPE ", path, " #", k)
				var seen := {}
				for p in st.pieces:
					if seen.has(p):
						bad += 1
						print("SAME PIECE ", path, " #", k, " ", p)
					seen[p] = true
				# every biscuit's word is taken whole and no other run of four is a word
				for b in nb:
					if not st.knows(st.biscuit_words[b]):
						bad += 1
						print("BISCUIT NOT A WORD ", path, " #", k, " ", st.biscuit_words[b])
				for w in st.word_list:
					if int(st._words[w]) == 4 and st.biscuit_of(w) < 0:
						bad += 1
						print("OTHER FOUR ", path, " #", k, " ", w)
				if st.line < 8 * nb or st.line > 8 * nb * 3 / 2:
					bad += 1
					print("LINE ", path, " #", k, " ", st.line)
				if k < 12:
					# the hand: each biscuit's pieces in order
					for b in nb:
						for i in st.biscuits[b]:
							st.add(int(i))
						st.read()
					if not st.solved() or st.points < 8 * nb:
						bad += 1
						print("HAND ", path, " #", k, " solved ", st.solved(), " points ", st.points)
					if st.in_tin().size() != 0:
						bad += 1
						print("CRUMBS LEFT ", path, " #", k)
					# the bulb alone
					st.restart()
					var n := 0
					while not st.solved() and n < 10:
						var b: int = st.hint_biscuit()
						st.clear_plate()
						for i in st.biscuits[b]:
							st.add(int(i))
						st.read(true)
						n += 1
					if not st.solved() or st.points != 0 or n != nb:
						bad += 1
						print("BULB ", path, " #", k, " took ", n, " points ", st.points)
			print("%s%s: %d tins, %.2f ms each" % [bank, lang, boards.size(), (Time.get_ticks_usec() - t0) / 1000.0 / boards.size()])
	print("bad ", bad)
	quit()
	return true
