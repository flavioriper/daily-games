extends RefCounted

## Rings: the generator's guarantees and the state's rules.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md

const Gen = preload("res://puzzles/rings_gen.gd")
const State = preload("res://puzzles/rings_state.gd")
const Board = preload("res://puzzles/rings2d.gd")
const Motion = preload("res://core/motion.gd")

## The runner calls one static run(t) a suite (tests/run_tests.gd), so every
## test below is reached from here and nowhere else.
static func run(t) -> void:
	_test_deal_shape(t)
	_test_hard_band_is_three_a_peg(t)
	_test_every_deal_is_solvable(t)
	_test_deal_is_seeded(t)
	_test_key_is_canonical(t)
	_test_moves_and_solved(t)
	_test_lift_and_put_back(t)
	_test_drop_rules(t)
	_test_locked_peg(t)
	_test_undo(t)
	_test_solved_and_stuck(t)
	_test_reset(t)
	_test_hint(t)
	_test_hint_guards_a_held_ring(t)

static func _rng(seed_value: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r

## Every band deals the right number of rings, four of every colour, onto the
## right number of pegs, none over CAP.
static func _test_deal_shape(t) -> void:
	for band in 3:
		var want: Dictionary = Gen.BANDS[band]
		var pegs := Gen.deal(_rng(band * 100 + 7), band)
		t.eq(pegs.size(), want["pegs"], "band %d peg count" % band)
		var seen := {}
		var total := 0
		for s in pegs:
			t.check(s.size() <= Gen.CAP, "band %d peg within CAP" % band)
			total += s.size()
			for c in s:
				seen[c] = int(seen.get(c, 0)) + 1
		t.eq(total, want["colours"] * Gen.CAP, "band %d ring count" % band)
		t.eq(seen.size(), want["colours"], "band %d colour count" % band)
		for c in seen:
			t.eq(int(seen[c]), Gen.CAP, "band %d four of colour %d" % [band, c])

## The hard band is the reference's own deal: eight pegs of exactly three.
static func _test_hard_band_is_three_a_peg(t) -> void:
	var pegs := Gen.deal(_rng(11), 2)
	t.eq(pegs.size(), 8, "eight pegs")
	for s in pegs:
		t.eq(s.size(), 3, "three rings a peg")

## Every deal the generator hands over can actually be sorted, and the path it
## returns is legal move by move and ends solved.
static func _test_every_deal_is_solvable(t) -> void:
	for band in 3:
		for i in 6:
			var pegs := Gen.deal(_rng(i * 31 + band), band)
			t.check(not Gen.solved(pegs), "band %d seed %d is not already solved" % [band, i])
			var path: Array = Gen.solve(pegs, 20000)
			t.check(not path.is_empty(), "band %d seed %d has a solution" % [band, i])
			var work: Array = []
			for s in pegs:
				work.append((s as Array).duplicate())
			for m in path:
				var from: Array = work[m.x]
				var to: Array = work[m.y]
				t.check(not from.is_empty(), "source not empty")
				t.check(to.size() < Gen.CAP, "destination has room")
				t.check(to.is_empty() or to.back() == from.back(), "lands on its own colour")
				to.append(from.pop_back())
			t.check(Gen.solved(work), "band %d seed %d: the path finishes it" % [band, i])

## The same seed deals the same board, on every phone and every run.
static func _test_deal_is_seeded(t) -> void:
	t.eq(str(Gen.deal(_rng(4242), 2)), str(Gen.deal(_rng(4242), 2)), "same seed, same deal")

## Two positions that differ only in which peg is which share a key -- that is
## what collapses the symmetry group and makes the search cheap.
static func _test_key_is_canonical(t) -> void:
	var a := [[0, 0], [1], [], [2, 2, 2]]
	var b := [[2, 2, 2], [], [0, 0], [1]]
	t.eq(Gen.key(a), Gen.key(b), "peg order does not change the key")
	t.check(Gen.key(a) != Gen.key([[0], [1], [], [2, 2, 2]]), "content does")

## A position with nothing legal in it returns no moves, and one that is solved
## says so.
static func _test_moves_and_solved(t) -> void:
	t.check(Gen.solved([[0, 0, 0, 0], [1, 1, 1, 1], []]), "full monochrome pegs and an empty one")
	t.check(not Gen.solved([[0, 0, 0], [0, 1, 1, 1], [1]]), "not sorted")
	# Two full pegs, mismatched tops, nowhere to go.
	t.eq(Gen.moves_from([[0, 1, 0, 1], [1, 0, 1, 0]]).size(), 0, "no legal move")

static func _state(band := 2, seed_value := 5):
	var s = State.new()
	s.build(_rng(seed_value), band)
	return s

## A lift takes the top ring into the hand and off the peg; putting it back is
## not a move and does not touch the log.
static func _test_lift_and_put_back(t) -> void:
	var s = _state()
	var before: Array = (s.pegs[0] as Array).duplicate()
	t.check(s.lift(0), "lifted")
	t.eq(s.held, int(before.back()), "the colour is in hand")
	t.eq((s.pegs[0] as Array).size(), before.size() - 1, "and off the peg")
	s.put_back()
	t.eq(str(s.pegs[0]), str(before), "back where it was")
	t.eq(s.log.size(), 0, "a put-back is not a move")

## A drop is legal onto an empty peg or onto its own colour, and refused
## otherwise -- with a line saying which rule it broke.
static func _test_drop_rules(t) -> void:
	var s = State.new()
	s.pegs = [[0, 0, 0], [1], [], [2, 2, 2, 2]]
	s.deal = [[0, 0, 0], [1], [], [2, 2, 2, 2]]
	s.colours = 3
	t.check(s.lift(0), "lifted a 0")
	t.check(not s.can_drop(1), "1's top is a different colour")
	t.eq(s.refusal(1), "A ring only lands on its own colour.", "the mismatch line, verbatim")
	t.check(s.can_drop(2), "the empty peg takes anything")
	t.check(not s.can_drop(3), "a full peg takes nothing")
	t.eq(s.refusal(3), "That peg is full.", "the full line, verbatim")
	t.eq(s.drop(2), 0, "landed in the empty peg's first slot")
	t.eq(s.log.size(), 1, "one move logged")
	t.eq(s.held, -1, "the hand is empty")

## Nothing comes off a finished peg.
static func _test_locked_peg(t) -> void:
	var s = State.new()
	s.pegs = [[1, 1, 1, 1], [0]]
	s.colours = 2
	t.check(s.locked(0), "four of a colour is locked")
	t.check(not s.can_lift(0), "and cannot be lifted from")
	t.check(not s.lift(0), "the lift is refused")

## Undo walks a move back exactly, including the one that finished a peg.
static func _test_undo(t) -> void:
	var s = State.new()
	s.pegs = [[1, 1, 1], [0, 1]]
	s.colours = 2
	s.lift(1)
	t.check(s.drop(0) >= 0, "dropped")
	t.check(s.locked(0), "peg 0 holds 1,1,1,1 -- locked")
	var m: Vector2i = s.undo()
	t.eq(m, Vector2i(1, 0), "the move that was undone")
	t.eq(str(s.pegs), str([[1, 1, 1], [0, 1]]), "exactly as it was")
	t.eq(s.log.size(), 0, "and off the log")

## Solved, and stuck, are both derived and neither is stored.
static func _test_solved_and_stuck(t) -> void:
	var s = State.new()
	s.pegs = [[0, 0, 0, 0], [1, 1, 1, 1], []]
	s.colours = 2
	t.check(s.is_solved(), "every colour on a peg of its own")
	t.check(not s.is_stuck(), "solved is not stuck")
	var d = State.new()
	d.pegs = [[0, 1, 0, 1], [1, 0, 1, 0]]
	d.colours = 2
	t.check(not d.is_solved(), "not solved")
	t.check(d.is_stuck(), "and nothing can move")

## Reset is the dealt position, not one undo at a time.
static func _test_reset(t) -> void:
	var s = _state()
	var start := str(s.pegs)
	s.lift(0)
	for j in s.pegs.size():
		if s.can_drop(j):
			s.drop(j)
			break
	s.reset_board()
	t.eq(str(s.pegs), start, "back to the deal")
	t.eq(s.log.size(), 0, "and no history")

## A hint plays a real move off the solver and spends a count.
static func _test_hint(t) -> void:
	var s = _state()
	var before: int = s.log.size()
	var m: Vector2i = s.hint()
	t.check(m.x >= 0, "a move was played")
	t.eq(s.log.size(), before + 1, "and logged like any other")
	t.eq(s.hints_used, 1, "one spent")
	for i in 5:
		s.hint()
	t.eq(s.hints_used, State.HINTS, "never more than three")

## Regression: a ring already in hand when hint() is called used to make
## lift(m.x) fail silently (held already set) while drop(m.y) tested
## can_drop against the *stale* held colour rather than the solver's -- and
## hints_used was spent either way. hint() now self-guards with put_back()
## first, so the board it hands to the solver always matches what is really
## on the pegs, and only actually crediting the move it reports.
static func _test_hint_guards_a_held_ring(t) -> void:
	var s = _state()
	t.check(s.lift(0), "a ring already in hand before hinting")
	var before_hints: int = s.hints_used
	var before_log: int = s.log.size()
	var m: Vector2i = s.hint()
	t.check(m.x >= 0, "a real move was played, off the restored board")
	t.check(not s.log.is_empty() and s.log.back() == m, "the move reported is the move made")
	t.eq(s.log.size(), before_log + 1, "the log grew by exactly one")
	t.eq(s.hints_used, before_hints + 1, "and exactly one hint was spent")

## The board's own motion needs a live tree (a real Timer, a real Fx2D child
## under _ready()), so it runs here rather than from run(t) -- see
## tests/run_tests.gd's own doc comment.
static func run_in_tree(t) -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	Motion.reduce = false
	var board = Board.new()
	root.add_child(board)
	board.start(_rng(1), 0)
	_test_overlapping_flight_settles_the_first(t, board)
	Motion.reduce = false
	root.remove_child(board)
	board.free()

## Task 5 fix round 1 (code review of 990ccac): `_flight` is a single
## Dictionary, and nothing stopped a second lift+drop from overwriting it
## while the first ring was still in the air -- trivially reachable, since
## `_state` already carries a dropped ring as its destination's top the
## instant drop() returns. The second `_fly()` used to clobber `_flight`
## before `_process()`'s own `t >= land` check ever fired for the first
## move, so the first's `_settle()` -- the only thing that ever writes
## `_lock_at` -- silently never ran, and a peg that move had just finished
## lost its gold wash for the rest of the game, even though
## `_state.locked()` was (and stayed) true. The fix is not to block the
## second tap -- a ring sort invites fast tapping -- but to land whatever is
## still in the air the moment a new flight starts (`_fly`'s own call to
## `_land_flight`), so the ring in the air snaps to its slot instead of
## finishing its arc, and nothing about `_settle` is skipped.
##
## This reproduces the review's own scenario: drop a ring that completes a
## peg, then start an unrelated second move before ARC_TIME elapses (here,
## before even one frame passes -- both moves are played synchronously), and
## check that `_lock_at` actually gained the completed peg. Failed before
## the fix (`_lock_at` stayed empty for peg 0 forever); passes after it.
static func _test_overlapping_flight_settles_the_first(t, board) -> void:
	board._state.pegs = [
		[0, 0, 0],  # peg 0: one more ring of colour 0 completes it
		[1, 0],     # peg 1: its top is colour 0 -- the ring that finishes peg 0
		[2],        # peg 2: an unrelated ring for the second, overlapping move
		[],         # peg 3: an empty peg to receive it
		[],
		[],
	]
	board._lock_at = {}
	board._flight = {}
	board._tap(1)   # lift the ring that will finish peg 0
	board._tap(0)   # drop it -- peg 0 is locked in state now, but _settle
	                # (and _lock_at) waits for the flight to land
	t.check(board._state.locked(0), "peg 0 is locked in state the instant drop() returns")
	t.check(not board._flight.is_empty(), "its ring is still flying, not settled yet")
	t.check(not board._lock_at.has(0), "so _lock_at has nothing for it yet -- the deferral is real")
	board._tap(2)   # an unrelated second move, well inside ARC_TIME of the first
	board._tap(3)
	t.check(board._lock_at.has(0), "the first peg's lock must not be lost when a second move overtakes it")
