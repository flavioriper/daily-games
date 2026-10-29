extends SceneTree

## Teacups, measured (2026-10-29 made-fun pass): a player who lifts an unseen
## cup first and goes straight to a twin they remember, and who forgets a
## seen cup with a chance that grows with the lifts since they saw it
## (`forget` per lift of age). Optionally the opening glance: every friend
## shown once before play, remembered as weakly as `glance` of a real look.
## Reports per band: lifts, lapses, pairs found by memory vs by luck (the
## second cup's twin never seen), the longest run of pairs, and the share
## of turns that were pure guesses.

const State = preload("res://puzzles/teacups_state.gd")

func _initialize() -> void:
	for forget: float in [0.2, 0.5]:
		for glance: float in [0.0]:
			print("--- forget %.2f a lift of age, glance %.2f" % [forget, glance])
			for band in 4:
				_band(band, forget, glance)
	quit()

func _band(band: int, forget: float, glance: float) -> void:
	var rng := RandomNumberGenerator.new()
	var me := RandomNumberGenerator.new()
	me.seed = 11
	var days := 80
	var lifts := 0
	var lapses := []
	var memory_pairs := 0
	var luck_pairs := 0
	var runs := []
	var guesses := 0
	var turns := 0
	for day in days:
		rng.seed = 2000 + day
		var st = State.new()
		st.deal(rng, band)
		# what the player holds: cup id -> lift number they last saw it at
		var known := {}
		if glance > 0.0:
			for c in st.cups():
				if me.randf() < glance:
					known[c] = -8
		var clock := 0
		var run := 0
		var best := 0
		var guard := 0
		while not st.solved() and guard < 400:
			guard += 1
			turns += 1
			# forgetting, by age
			for c in known.keys():
				if me.randf() < forget * float(clock - int(known[c])) * 0.1:
					known.erase(c)
			var a := -1
			var b := -1
			# a remembered pair, both cups known
			for c in known:
				var p: int = st.partner(c)
				if not st.found[c] and known.has(p):
					a = c
					b = p
					break
			if a < 0:
				# an unseen cup first
				var fresh: Array[int] = []
				for c in st.hidden():
					if not known.has(c):
						fresh.append(c)
				if fresh.is_empty():
					fresh = st.hidden()
				a = fresh[me.randi_range(0, fresh.size() - 1)]
			st.lift(st.slot[a])
			clock += 1
			known[a] = clock
			if b < 0:
				var p: int = st.partner(a)
				if known.has(p):
					b = p
				else:
					guesses += 1
					var fresh: Array[int] = []
					for c in st.hidden():
						if c != a and not known.has(c):
							fresh.append(c)
					if fresh.is_empty():
						for c in st.hidden():
							if c != a:
								fresh.append(c)
					b = fresh[me.randi_range(0, fresh.size() - 1)]
			var twin_seen: bool = st.seen[st.partner(a)]
			var heard: int = st.lift(st.slot[b])
			clock += 1
			known[b] = clock
			if heard == State.Lifted.PAIR or heard == State.Lifted.SOLVED:
				known.erase(a)
				known.erase(b)
				if twin_seen:
					memory_pairs += 1
				else:
					luck_pairs += 1
				run += 1
				best = maxi(best, run)
			else:
				run = 0
				if st.waltz_due():
					var ab: Array[int] = st.waltz()
					# a waltz watched: kept with a coin's chance
					for c in ab:
						if me.randf() < 0.5:
							known.erase(c)
		lifts += st.lifts
		lapses.append(st.lapses)
		runs.append(best)
	lapses.sort()
	runs.sort()
	print("band %d: lifts %.1f  lapses p25/50/75/90 %d/%d/%d/%d  memory/luck pairs %d/%d  best run p50 %d  guesses %.0f%% of turns" % [
		band, float(lifts) / days, lapses[days / 4], lapses[days / 2], lapses[days * 3 / 4], lapses[days * 9 / 10],
		memory_pairs, luck_pairs, runs[days / 2], 100.0 * guesses / turns])
