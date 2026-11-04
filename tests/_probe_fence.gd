extends SceneTree

## Garden Fence's banks against its rules, in every language: each fence
## has three posts a side, every letter once; its route strings on the fence
## (no two in a row from one side), chains last letter to first, is par
## words long and uses every post (Insane: ends on the gate); a hand tying
## the route solves at par; the bulb alone solves too, in a few words more
## at most. Prints the time a fence takes to load (the word list filtered by
## its posts) and a bulb press.
##   godot --headless --path . --script tests/_probe_fence.gd

const State = preload("res://puzzles/fence_state.gd")

## Fences a bank the bulb plays (all are checked).
const PLAYED := 25

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
			if boards.size() != 365:
				bad += 1
				print("COUNT ", path, " ", boards.size())
			var load_us := 0
			var hint_us := 0
			var hints := 0
			var worst := 0
			var stranger := 0
			var slowest := 0
			for k in boards.size():
				var day: Dictionary = boards[k]
				var st = State.new()
				st.band = band
				var t0 := Time.get_ticks_usec()
				st.load_day(day)
				load_us += Time.get_ticks_usec() - t0
				var why := ""
				var letters := {}
				for p in st.posts:
					letters[p] = true
				if st.posts.size() != st.sides * 3 or letters.size() != st.posts.size():
					why = "posts"
				elif (band == 3) != (st.gate >= 0):
					why = "gate"
				elif st.route.size() != st.par:
					why = "par"
				else:
					for w in st.route:
						if st.mask_of(w) < 0 or not st.knows(w):
							why = "route strings " + w
					for i in range(1, st.route.size()):
						if st.route[i].substr(0, 1) != st.route[i - 1].right(1):
							why = "chain"
				if why == "":
					for w in st.route:
						st.string_word(w)
						st.tie()
					if not st.solved() or st.tied.size() != st.par:
						why = "route does not solve"
				if why == "" and k < PLAYED:
					st.restart()
					var n := 0
					while not st.solved() and n < st.par + 6:
						var t1 := Time.get_ticks_usec()
						var h: Dictionary = st.hint_word()
						hint_us += Time.get_ticks_usec() - t1
						hints += 1
						if h.is_empty() or h.has("back"):
							break
						st.string_word(String(h.word))
						st.tie("bulb")
						n += 1
					if not st.solved():
						why = "the bulb alone does not solve"
					worst = maxi(worst, st.tied.size() - st.par)
					# again from a stranger's first word: a common word on
					# the fence that is not the route's
					st.restart()
					var first := ""
					for p in st.posts:
						for e: Array in st._fair.get(p, []):
							if e[0] != st.route[0] and String(e[0]).length() >= 5 and (k + p.unicode_at(0)) % 3 == 0:
								first = e[0]
								break
						if first != "":
							break
					if first != "":
						st.string_word(first)
						st.tie()
						var m := 0
						while not st.solved() and m < st.par + 8:
							var t2 := Time.get_ticks_usec()
							var h2: Dictionary = st.hint_word()
							var took := Time.get_ticks_usec() - t2
							hint_us += took
							slowest = maxi(slowest, took)
							hints += 1
							if h2.is_empty():
								break
							if h2.has("back"):
								while st.tied.size() > int(h2.back):
									st.untie()
								continue
							st.string_word(String(h2.word))
							st.tie("bulb")
							m += 1
						if not st.solved():
							why = "the bulb does not finish from %s" % first
						stranger = maxi(stranger, st.tied.size() - st.par)
				if why != "":
					bad += 1
					if bad < 30:
						print("BAD %s %s #%d %s: %s %s" % [lang, bank, k, why, day.posts, day.route])
			print("%s %s: load %.1f ms a fence, bulb %.1f ms a press (slowest %.1f), over par at most %d (from a stranger's word %d)" % [
				lang, bank, load_us / 1000.0 / boards.size(), hint_us / 1000.0 / maxi(1, hints), slowest / 1000.0, worst, stranger])
	Locale._current = was
	print("bad: %d" % bad)
	quit(1 if bad > 0 else 0)
	return true
