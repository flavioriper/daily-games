extends SceneTree

## Stepping Stones' banks against its rules, in every language: each
## crossing's par is the fewest stones the state's own search finds; its
## route is par stones long, every stone fair, each one step from the last
## and the last a step from the far bank; Easy's given is the route's
## middle; a hand laying the route crosses at par (Easy's given called in by
## the stone before it), and the bulb alone crosses at par too. Prints the
## time.
##   godot --headless --path . --script tests/_probe_stones.gd

const State = preload("res://puzzles/stones_state.gd")

## Crossings a bank the hand and the bulb play (all are searched).
const PLAYED := 40

var _ran := false

func _process(_d: float) -> bool:
	if _ran:
		return true
	_ran = true
	var bad := 0
	var was: String = Locale._current
	for lang in ["en", "pt", "es"]:
		Locale._current = lang
		var suffix: String = "" if lang == "en" else "." + lang
		for bank in State.BANKS:
			var band := State.BANKS.find(bank)
			var path := "res://content/insane/%s%s.json" % [bank, suffix]
			var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			var boards: Array = doc.boards
			var t0 := Time.get_ticks_usec()
			if boards.size() != 365:
				bad += 1
				print("COUNT ", path, " ", boards.size())
			for k in boards.size():
				var day: Dictionary = boards[k]
				var st = State.new()
				st.band = band
				st.load_day(day)
				var tag := "%s #%d %s>%s" % [path, k, st.from, st.to]
				if st.n != State.LENGTH[band]:
					bad += 1
					print("LENGTH ", tag)
				if st.dist(st.from) - 1 != st.par:
					bad += 1
					print("PAR ", tag, " par ", st.par, " found ", st.dist(st.from) - 1)
				if st.route.size() != st.par:
					bad += 1
					print("ROUTE SIZE ", tag)
				var prev: String = st.from
				for w in st.route:
					if not st.is_fair(w) or not st.step_ok(prev, w):
						bad += 1
						print("ROUTE ", tag, " ", prev, ">", w)
					prev = w
				if not st.step_ok(prev, st.to):
					bad += 1
					print("ROUTE END ", tag)
				if band == 0 and (st.route.size() < 2 or st.given != st.route[1]):
					bad += 1
					print("GIVEN ", tag, " ", st.given)
				if band != 0 and st.given != "":
					bad += 1
					print("GIVEN OFF EASY ", tag)
				if k >= PLAYED:
					continue
				# the hand: the route laid stone by stone
				for w in st.route:
					if st.used(w):
						continue
					var r: Dictionary = st.offer(w)
					if int(r.said) != State.Said.LAID:
						bad += 1
						print("HAND REFUSED ", tag, " ", w, " ", r.said)
						break
				if not st.crossed or st.stones() != st.par or st.stars() != 3:
					bad += 1
					print("HAND ", tag, " crossed ", st.crossed, " stones ", st.stones())
				if band == 0 and not st.given_in():
					bad += 1
					print("GIVEN NOT CALLED ", tag)
				# the bulb alone
				st.restart()
				var n := 0
				while not st.crossed and n < 12:
					var h: Dictionary = st.hint_step()
					if h.is_empty():
						break
					st.cut_to(int(h.keep))
					st.offer(String(h.word), "bulb")
					n += 1
				if not st.crossed or st.stones() != st.par:
					bad += 1
					print("BULB ", tag, " crossed ", st.crossed, " stones ", st.stones(), " presses ", n)
				# a dead end the bulb backs out of: the hand lays a stone that
				# has no way on, if one is there to lay
				st.restart()
				for y in st.neighbours(st.from):
					if st.dist(y) >= State.FAR and y != st.to:
						st.offer(y)
						break
				if st.stones() == 1:
					var h: Dictionary = st.hint_step()
					if h.is_empty() or int(h.keep) != 0:
						bad += 1
						print("DEAD END ", tag, " ", h)
			print("%s%s: %d crossings, %.2f ms each" % [bank, suffix, boards.size(), (Time.get_ticks_usec() - t0) / 1000.0 / boards.size()])
	Locale._current = was
	print("bad ", bad)
	quit()
	return true
