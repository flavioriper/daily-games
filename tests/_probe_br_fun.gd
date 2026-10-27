extends SceneTree
## Throwaway: how Bridges plays, 60 days a band. A player who never pushes an
## islet over its number lays a plank on a random legal lane until nothing
## is left. Counted: how often they stall short of the solve; how often a
## group closes off (every islet in it met, the rest of the sea out of
## reach) before the end, and how many planks they lay after the first one
## with the board silent about it; how often an islet goes dead (short of
## its number with no lane left that can take a plank) and the planks laid
## after; and how many lanes an islet faces.
const State = preload("res://puzzles/bridges_state.gd")

func _initialize() -> void:
	var days := 60
	for band in 3:
		var stalled := 0
		var closed_games := 0
		var closed_after := 0
		var dead_games := 0
		var dead_after := 0
		var faces := 0
		var islets := 0
		var planks := 0
		var heed_stalled := 0
		for s in days:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4242 + s * 97 + band
			var st = State.new()
			st.build(rng, band)
			for cell in st.islets:
				islets += 1
				for key in st.lanes:
					if st.lanes[key].a == cell or st.lanes[key].b == cell:
						faces += 1
			var play := RandomNumberGenerator.new()
			play.seed = s * 13 + 5
			var closed_at := -1
			var dead_at := -1
			var laid := 0
			while true:
				var legal: Array = []
				for key in st.lanes:
					if st.planks(key) >= State.MAX_PLANKS or st.blocked_by(key) != "":
						continue
					var la: Dictionary = st.lanes[key]
					if st.degree(la.a) >= st.need_of(la.a) or st.degree(la.b) >= st.need_of(la.b):
						continue
					legal.append(key)
				if legal.is_empty():
					break
				st.cycle(String(legal[play.randi() % legal.size()]))
				laid += 1
				if closed_at < 0 and _closed(st):
					closed_at = laid
				if dead_at < 0 and _dead(st):
					dead_at = laid
			planks += laid
			if not st.is_solved():
				stalled += 1
			heed_stalled += 0 if _heeding(st, s) else 1
			if closed_at >= 0:
				closed_games += 1
				closed_after += laid - closed_at
			if dead_at >= 0:
				dead_games += 1
				dead_after += laid - dead_at
		print("band %d: stalled %d/%d, closed-off group %d games (%.1f planks laid after, silent), dead islet %d games (%.1f planks after), lanes an islet %.2f, planks a game %.1f; a player heeding the rose halo stalls %d/%d" % [
			band, stalled, days, closed_games, float(closed_after) / maxi(1, closed_games),
			dead_games, float(dead_after) / maxi(1, dead_games), float(faces) / islets,
			float(planks) / days, heed_stalled, days])
	quit()

## The same player, on the same board from bare water, who takes back a
## plank the moment it leaves an islet stranded or a group sealed (the halo
## shows), and tries another lane. True when they solve it.
static func _heeding(st, s: int) -> bool:
	st.reset_board()
	var play := RandomNumberGenerator.new()
	play.seed = s * 13 + 5
	while true:
		var legal: Array = []
		for key in st.lanes:
			if st.planks(key) >= State.MAX_PLANKS or st.blocked_by(key) != "":
				continue
			var la: Dictionary = st.lanes[key]
			if st.degree(la.a) >= st.need_of(la.a) or st.degree(la.b) >= st.need_of(la.b):
				continue
			legal.append(key)
		var moved := false
		while not legal.is_empty():
			var k: String = legal.pop_at(play.randi() % legal.size())
			st.cycle(k)
			if st.stranded().is_empty() and st.sealed().is_empty():
				moved = true
				break
			st.undo()
		if not moved:
			break
	return st.is_solved()

## A group smaller than the sea with every islet in it met.
static func _closed(st) -> bool:
	var groups: Array = st.groups()
	if groups.size() <= 1:
		return false
	for g in groups:
		if g.size() <= 1:
			continue
		var all_met := true
		for cell in g:
			if st.degree(cell) != st.need_of(cell):
				all_met = false
				break
		if all_met:
			return true
	return false

## An islet short of its number that no lane can add a plank to.
static func _dead(st) -> bool:
	for cell in st.islets:
		var short: int = st.need_of(cell) - st.degree(cell)
		if short <= 0:
			continue
		var room := 0
		for key in st.lanes:
			var la: Dictionary = st.lanes[key]
			if la.a != cell and la.b != cell:
				continue
			if st.blocked_by(key) != "":
				continue
			var other: Vector2i = la.b if la.a == cell else la.a
			room += mini(State.MAX_PLANKS - st.planks(key), maxi(0, st.need_of(other) - st.degree(other)))
		if room < short:
			return true
	return false
