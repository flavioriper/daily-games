extends SceneTree
## Throwaway: Honeycomb's days. Per language and band: the load time of the
## word list, the hives in the bank, and every banked hive played from its
## day's words to the jar's line (Insane following the queen's flights):
## the words it took, the honey, and any hive that cannot be filled.
##   godot --headless --path . --script tests/_probe_honeycomb.gd -- [langs]
const State = preload("res://puzzles/honeycomb_state.gd")
const Words = preload("res://puzzles/honeycomb_words.gd")
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var langs := String(args[0]) if args.size() > 0 else "en,pt,es"
	for lang in langs.split(","):
		Locale._current = lang
		var t := Time.get_ticks_msec()
		var w = Words.current()
		print("%s: %d words, loaded in %d ms" % [lang, w.words.size(), Time.get_ticks_msec() - t])
		for band in 4:
			var pool: Array = InsaneBank.boards(State.BANKS[band])
			var worst := 0
			var need := []
			var fails := 0
			var totals := []
			var shy_hints := 0
			for day: Dictionary in pool:
				var st = State.new()
				t = Time.get_ticks_msec()
				st.band = band
				st.load_day(day)
				worst = maxi(worst, Time.get_ticks_msec() - t)
				totals.append(st.total)
				# play the day's words, commonest first, until the jar fills
				var guard := 0
				while not st.solved() and guard < 200:
					guard += 1
					var h: String = st.hint_word()
					if h == "":
						break
					st.entry = h
					var said: int = st.submit()
					if said != State.Said.WORD and said != State.Said.FULL:
						break
					if st.flies_now():
						st.fly()
				if not st.solved():
					fails += 1
				need.append(st.found.size())
			need.sort()
			totals.sort()
			print("  band %d: %d hives, load worst %d ms, honey %d..%d (mid %d), words to fill %d..%d (mid %d), unfillable %d" % [
				band, pool.size(), worst, totals[0], totals[-1], totals[totals.size() / 2], need[0], need[-1], need[need.size() / 2], fails])
		# a day's four bands never share a comb's letters
		var clash := 0
		for day in 365:
			InsaneBank.day_override = 20500 + day
			var seen := {}
			for band in 4:
				var st = State.new()
				st.deal(null, band)
				if seen.has(st.letters):
					clash += 1
				seen[st.letters] = true
		InsaneBank.day_override = -1
		print("  days a year where two bands share letters: %d" % clash)
		# the tutorial's pages: enough plain words for the queen to fly
		var Diagram = load("res://ui/hud/honeycomb_tutorial_diagram.gd")
		for band in 4:
			var st = State.new()
			st.band = band
			st.load_day(Diagram.hive(band))
			print("  tutorial hive band %d: %s/%s, %d plain words, full comb %s" % [band, st.letters, st.queen, Diagram._plain(st).size(), Diagram._full_word(st)])
	quit()
