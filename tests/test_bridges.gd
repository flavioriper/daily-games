extends RefCounted

## Bridges' generator (puzzles/bridges_gen.gd): what a grown board promises,
## and the uniqueness the clues are proved to have. Then its rules
## (puzzles/bridges_state.gd): the cycle, the two refusals, undo and reset,
## the hint that never overshoots, and the conjunction is_solved() is.

const Gen = preload("res://puzzles/bridges_gen.gd")
const State = preload("res://puzzles/bridges_state.gd")

static func run(t) -> void:
	_test_bands(t)
	_test_grown_board_is_legal(t)
	_test_unique(t)
	_test_repeatable(t)
	_test_cycle(t)
	_test_refusals(t)
	_test_undo_reset(t)
	_test_hint_check(t)
	_test_solved_needs_one_network(t)
	_two_rings_are_not_solved(t)

static func _built(seed_value: int, difficulty: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Gen.generate(rng, difficulty)

## The three bands are the spec's table, section 4.
static func _test_bands(t) -> void:
	t.eq(Gen.band(0).n, 7, "band 0 is a 7x7")
	t.eq(Gen.band(1).n, 9, "band 1 is a 9x9")
	t.eq(Gen.band(2).n, 11, "band 2 is an 11x11")
	t.eq(Gen.band(0).islets, 11, "band 0 stands 11 islets")
	t.eq(Gen.band(1).islets, 16, "band 1 stands 16 islets")
	t.eq(Gen.band(2).islets, 24, "band 2 stands 24 islets")
	t.check(Gen.band(0).guess_free, "band 0 must need no guess")

## Everything a grown board promises, over enough seeds that a rare layout
## cannot hide: the answer is legal, it is connected, no run crosses another,
## every clue is the islet's own degree, and no clue passes the cap of 6.
static func _test_grown_board_is_legal(t) -> void:
	for difficulty in 3:
		var b: Dictionary = Gen.band(difficulty)
		for s in range(1, 21):
			var g := _built(s, difficulty)
			t.eq(g.islets.size(), b.islets, "band %d seed %d stands its islets" % [difficulty, s])
			var lanes: Dictionary = Gen.lanes_for(g.n, g.islets)
			# Every run in the answer is a real lane, and 1..3 planks.
			for key in g.answer:
				t.check(lanes.has(key), "answer run %s is a lane" % key)
				var k: int = int(g.answer[key])
				t.check(k >= 1 and k <= 3, "answer run %s is 1..3 planks, got %d" % [key, k])
			# The clue is the degree, and never over 6.
			for cell in g.islets:
				var deg := 0
				for key in g.answer:
					var lane: Dictionary = lanes[key]
					if lane.a == cell or lane.b == cell:
						deg += int(g.answer[key])
				t.eq(int(g.need[cell]), deg, "clue at %s is its degree" % cell)
				t.check(deg >= 1 and deg <= 6, "degree at %s is 1..6, got %d" % [cell, deg])
			# No two laid runs cross.
			var used := {}
			for key in g.answer:
				for cell in lanes[key].cells:
					t.check(not used.has(cell), "no two answer runs cross at %s" % cell)
					used[cell] = true
			# One network.
			t.check(_connected(g.islets, lanes, g.answer), "the answer is one network")

static func _connected(islets: Array, lanes: Dictionary, runs: Dictionary) -> bool:
	if islets.is_empty():
		return true
	var seen := {islets[0]: true}
	var stack := [islets[0]]
	while not stack.is_empty():
		var cell = stack.pop_back()
		for key in runs:
			if int(runs[key]) <= 0:
				continue
			var lane: Dictionary = lanes[key]
			var other = null
			if lane.a == cell:
				other = lane.b
			elif lane.b == cell:
				other = lane.a
			if other != null and not seen.has(other):
				seen[other] = true
				stack.append(other)
	return seen.size() == islets.size()

## The clues admit exactly one answer -- checked with the generator's own
## counter, and band 0 additionally needs no guess.
static func _test_unique(t) -> void:
	for difficulty in 3:
		for s in range(1, 16):
			var g := _built(s, difficulty)
			var lanes: Dictionary = Gen.lanes_for(g.n, g.islets)
			var r: Dictionary = Gen.count_solutions(g.n, g.islets, g.need, lanes, 2)
			t.eq(int(r.count), 1, "band %d seed %d has exactly one answer" % [difficulty, s])
		if Gen.band(difficulty).guess_free:
			for s in range(1, 16):
				var g2 := _built(s, difficulty)
				t.check(bool(g2.guess_free), "band %d seed %d needs no guess" % [difficulty, s])

## A seed is a day: the same seed hands out the same board on every phone.
static func _test_repeatable(t) -> void:
	for difficulty in 3:
		for s in [7, 99, 1234]:
			var a := _built(s, difficulty)
			var b := _built(s, difficulty)
			t.eq(a.islets, b.islets, "band %d seed %d stands the same islets twice" % [difficulty, s])
			t.eq(a.need, b.need, "band %d seed %d sets the same clues twice" % [difficulty, s])
			t.eq(a.answer, b.answer, "band %d seed %d grows the same answer twice" % [difficulty, s])
# ------------------------------------------------ the rules, scene-free

static func _state(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.build(rng, difficulty)
	return st

## A drag cycles the run 0-1-2-3-0 and nothing else does.
static func _test_cycle(t) -> void:
	var st := _state(3, 0)
	var key: String = st.answer.keys()[0]
	t.eq(st.cycle(key), 1, "the first drag lays one plank")
	t.eq(st.cycle(key), 2, "the second lays a second")
	t.eq(st.cycle(key), 3, "the third lays a third")
	t.eq(st.cycle(key), 0, "the fourth clears the run")
	t.check(not st.runs.has(key) or int(st.runs[key]) == 0, "a cleared run holds no planks")

## The two refusals of the spec's section 5, and the one thing that is not
## refused: an islet may be pushed over its number.
static func _test_refusals(t) -> void:
	var st := _state(5, 1)
	t.eq(st.lane_at(Vector2i(0, 0), Vector2i(0, 0)), "", "a cell does not face itself")
	# Find a crossing pair and lay the first; the second must report blocked.
	var blocked_pair := []
	for key in st.lanes:
		var others: Array = st.crossing.get(key, [])
		if not others.is_empty():
			blocked_pair = [key, others[0]]
			break
	if blocked_pair.is_empty():
		t.check(true, "this seed has no crossing pair to test")
	else:
		st.cycle(blocked_pair[0])
		t.eq(st.blocked_by(blocked_pair[1]), blocked_pair[0], "a crossed lane names its blocker")
		var before: int = int(st.runs.get(blocked_pair[1], 0))
		t.eq(st.cycle(blocked_pair[1]), before, "a crossed lane lays nothing")

## Undo lifts the last change only; reset lifts them all.
static func _test_undo_reset(t) -> void:
	var st := _state(11, 0)
	var keys: Array = st.answer.keys()
	st.cycle(keys[0])
	st.cycle(keys[1])
	t.check(st.undo(), "undo reports it undid something")
	t.eq(int(st.runs.get(keys[1], 0)), 0, "undo lifted the last run")
	t.eq(int(st.runs.get(keys[0], 0)), 1, "undo left the one before it")
	st.reset_board()
	t.eq(st.runs.size(), 0, "reset lifts every plank")
	t.check(not st.undo(), "undo on an empty board reports nothing")

## A hint never overshoots, and check names exactly what differs.
static func _test_hint_check(t) -> void:
	var st := _state(21, 0)
	var key: String = st.hint()
	t.check(key != "", "a hint on an empty board lays something")
	t.check(int(st.runs[key]) <= int(st.answer[key]), "a hint never overshoots the answer")
	t.eq(st.wrong_runs().size(), 0, "a hinted board has nothing wrong on it")
	# Lay a plank the answer does not have.
	for lane_key in st.lanes:
		if not st.answer.has(lane_key) and st.blocked_by(lane_key) == "":
			st.cycle(lane_key)
			t.check(st.wrong_runs().has(lane_key), "check names a run the answer lacks")
			break

## The near-miss: every number met, the islets in two rings, and the board
## is NOT solved. This is the rule the whole puzzle rests on.
static func _test_solved_needs_one_network(t) -> void:
	for difficulty in 3:
		for s in range(1, 11):
			var st := _state(s, difficulty)
			t.check(not st.is_solved(), "an empty board is not solved")
			for key in st.answer:
				for i in int(st.answer[key]):
					st.cycle(key)
			t.check(st.is_solved(), "the answer solves the board")
			t.eq(st.groups().size(), 1, "the answer is one group")

## The plan's loop above proves the answer solves and an empty board does
## not, but neither of those would fail an is_solved() that only counted
## degrees. This is the case that would: a board built by hand where every
## islet has exactly its number and the islets stand in two rings. Four
## islets at the corners of a 5x5, each wanting one plank, joined across the
## top and across the bottom. Every number is met; the board is not solved.
static func _two_rings_are_not_solved(t) -> void:
	var st := State.new()
	st.n = 5
	var corners: Array[Vector2i] = [Vector2i(0, 0), Vector2i(4, 0), Vector2i(0, 4), Vector2i(4, 4)]
	st.islets = corners
	st.need = {Vector2i(0, 0): 1, Vector2i(4, 0): 1, Vector2i(0, 4): 1, Vector2i(4, 4): 1}
	st.lanes = Gen.lanes_for(st.n, st.islets)
	st.crossing = Gen.crossings(st.lanes)
	st.answer = {}
	st.runs = {}
	st.history = []
	st.cycle(Gen.lane_key(Vector2i(0, 0), Vector2i(4, 0)))
	st.cycle(Gen.lane_key(Vector2i(0, 4), Vector2i(4, 4)))
	for cell in st.islets:
		t.eq(st.degree(cell), int(st.need[cell]), "the near-miss meets the number at %s" % cell)
	t.eq(st.groups().size(), 2, "the near-miss stands in two rings")
	t.check(not st.is_solved(), "every number met in two rings is NOT solved")
