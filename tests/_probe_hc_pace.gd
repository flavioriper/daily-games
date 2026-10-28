extends SceneTree
## Throwaway: words a player needs to reach the line, per share: one sending
## the day's words in any order, one sending the shortest first.
const State = preload("res://puzzles/honeycomb_state.gd")
const Words = preload("res://puzzles/honeycomb_words.gd")
func _initialize() -> void:
	seed(7)
	for lang in ["en", "pt", "es"]:
		Locale._current = lang
		var w = Words.current()
		for band in 3:
			var pool: Array = InsaneBank.boards(State.BANKS[band])
			for pv in [[2, 0.16], [2, 0.2], [3, 0.2], [4, 0.2], [4, 0.24]]:
				var four: int = pv[0]
				var share: float = pv[1]
				var line := "%s band %d four=%d share %.2f:" % [lang, band, four, share]
				for short in [false, true]:
					var need := []
					for d in range(0, pool.size(), 3):
						var st = State.new()
						st.band = band
						st.load_day(pool[d])
						var total := 0
						for i in st.answers:
							total += _pts(w.words[i], w.mask_of(w.words[i]) == st.hive_mask, four)
						var goal := maxi(1, ceili(total * share))
						var order := Array(st.answers)
						order.shuffle()
						if short:
							order.sort_custom(func(a, b): return w.words[a].length() < w.words[b].length())
						var h := 0
						var n := 0
						for i in order:
							var word: String = w.words[i]
							h += _pts(word, w.mask_of(word) == st.hive_mask, four)
							n += 1
							if h >= goal:
								break
						need.append(n)
					need.sort()
					line += "  %s mid %d (p10 %d p90 %d)" % ["short" if short else "any", need[need.size() / 2], need[need.size() / 10], need[need.size() * 9 / 10]]
				print(line)
	quit()

func _pts(word: String, full: bool, four: int) -> int:
	var n := word.length()
	return (four if n <= 4 else n) + (7 if full else 0)
