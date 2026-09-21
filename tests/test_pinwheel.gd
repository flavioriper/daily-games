extends RefCounted

## Pinwheel's rules, scene-free.

const State = preload("res://puzzles/pinwheel_state.gd")

static func run(t) -> void:
	_test_a_tap_steps_round_the_cycle(t)
	_test_a_pinned_fast_piece_refuses_and_keeps_no_history(t)
	_test_the_stain_is_derived(t)
	_test_solved_only_when_every_cell_is_covered_once(t)
	_test_one_tap_one_undo(t)
	_test_hint_walks_a_piece_home_in_one_undo(t)
	_test_undo_does_not_refund_a_hint(t)
	_test_reset_clears_history(t)
	_test_the_answer_solves_every_band(t)

static func _state(seed_value: int, difficulty: int) -> State:
	var st := State.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	st.setup(rng, difficulty)
	return st

static func _movable(st) -> int:
	for p in (st.shapes as Array).size():
		if not st.fixed(p):
			return p
	return -1

static func _test_a_tap_steps_round_the_cycle(t) -> void:
	var st := _state(11, 1)
	var p := _movable(st)
	t.check(p >= 0, "a board has something to turn")
	var m: int = (st.shapes[p] as Array).size()
	var was: int = st.turned[p]
	st.turn(p)
	t.eq(int(st.turned[p]), (was + 1) % m, "a tap advances one orientation")
	for i in m - 1:
		st.turn(p)
	t.eq(int(st.turned[p]), was, "m taps come home")

static func _test_a_pinned_fast_piece_refuses_and_keeps_no_history(t) -> void:
	var st := _state(11, 1)
	var fast := -1
	for p in (st.shapes as Array).size():
		if st.fixed(p):
			fast = p
			break
	if fast < 0:
		return   # bands 0 and 1 carry a 1x1; band 2 may not. Nothing to assert.
	var before: int = (st.history as Array).size()
	t.eq(st.turn(fast), false, "a pinned-fast piece refuses the tap")
	t.eq((st.history as Array).size(), before, "a refusal keeps no history")

static func _test_the_stain_is_derived(t) -> void:
	var st := _state(23, 1)
	var p := _movable(st)
	var before: Array = []
	for i in st.cols * st.rows:
		before.append(int(st.cover[i]))
	var m: int = (st.shapes[p] as Array).size()
	for i in m:
		st.turn(p)
	for i in st.cols * st.rows:
		t.eq(int(st.cover[i]), int(before[i]),
			"turning a piece all the way round leaves the stain where it was")

static func _test_solved_only_when_every_cell_is_covered_once(t) -> void:
	var st := _state(23, 1)
	t.eq(st.is_solved(), false, "a fresh board is not solved")
	for p in (st.shapes as Array).size():
		while int(st.turned[p]) != int(st.answer[p]):
			st.turn(p)
	t.eq(st.is_solved(), true, "the answer solves it")
	for i in st.cols * st.rows:
		t.eq(int(st.cover[i]), 1, "every cell is covered exactly once")

static func _test_one_tap_one_undo(t) -> void:
	var st := _state(31, 1)
	var p := _movable(st)
	var was: int = st.turned[p]
	st.turn(p)
	var u: Dictionary = st.undo()
	t.eq(int(u.get("piece", -1)), p, "undo names the piece")
	t.eq(int(st.turned[p]), was, "undo puts it back")
	t.eq(st.undo().is_empty(), true, "there is nothing left to undo")

static func _test_hint_walks_a_piece_home_in_one_undo(t) -> void:
	var st := _state(31, 1)
	var before: int = (st.history as Array).size()
	var h: Dictionary = st.hint()
	t.check(not h.is_empty(), "a hint has something to do on a fresh board")
	var p := int(h["piece"])
	t.eq(int(st.turned[p]), int(st.answer[p]), "a hint takes the piece all the way home")
	t.eq((st.history as Array).size(), before + 1, "however many quarters, a hint is one entry")
	st.undo()
	t.eq(int(st.turned[p]), int(h["from"]), "one undo puts the whole journey back")

static func _test_undo_does_not_refund_a_hint(t) -> void:
	var st := _state(31, 1)
	var left := st.hints_left()
	st.hint()
	t.eq(st.hints_left(), left - 1, "a hint is spent")
	st.undo()
	t.eq(st.hints_left(), left - 1, "and undoing it does not buy it back")

static func _test_reset_clears_history(t) -> void:
	var st := _state(31, 1)
	var p := _movable(st)
	st.turn(p)
	st.turn(p)
	var moved: Array = st.reset()
	t.check(moved.size() >= 1, "reset reports what it moved")
	for q in (st.shapes as Array).size():
		t.eq(int(st.turned[q]), int(st.start[q]), "reset puts every piece back where it opened")
	t.eq((st.history as Array).size(), 0, "reset is not a gesture and cannot be undone")
	t.eq(st.undo().is_empty(), true, "so there is nothing to undo after it")

static func _test_the_answer_solves_every_band(t) -> void:
	for d in 3:
		for s in 10:
			var st := _state(500 + s, d)
			for p in (st.shapes as Array).size():
				st.turned[p] = int(st.answer[p])
			st.recompute()
			t.eq(st.is_solved(), true, "band %d seed %d: the answer solves it" % [d, s])
			t.check(st.share_glyphs().length() > 0, "band %d seed %d shares something" % [d, s])
