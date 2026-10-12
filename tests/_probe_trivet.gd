extends SceneTree

## Plays Trivet's sim headless with two bots and prints how the runs went.
## Run after touching arcade/trivet_sim.gd.
##   godot --headless --script tests/_probe_trivet.gd -- [runs] [first seed]
## One bot sets every stack on a place at random; the other looks one move
## ahead (the place that puts the most away, else the one beside the most
## mats of its top colour) and uses its brush when the tray is full. After
## every move the tray is checked: the mats set down are the mats lying and
## the mats put away, no stack is left with CLEAR of a colour on top, no two
## stacks that touch share a top colour, a lid covers nothing, and the run
## is over only with the tray full and no brush. Then the tools, the levels
## and the Second chance on their own.

const Sim = preload("res://arcade/trivet_sim.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := int(args[0]) if args.size() > 0 else 200
	var first := int(args[1]) if args.size() > 1 else 1
	for bot in ["random", "careful"]:
		var scores: Array = []
		var levels: Array = []
		var moves: Array = []
		var chains: Array = []
		for k in runs:
			var s = Sim.new(first + k)
			moves.append(play(s, bot == "careful", 6000))
			scores.append(s.score)
			levels.append(s.level)
			chains.append(s.best_chain)
		scores.sort()
		levels.sort()
		moves.sort()
		chains.sort()
		print("%s, %d runs from seed %d: score %d / %d / %d  level %d / %d / %d  stacks set down %d / %d / %d  best chain %d / %d / %d (lowest / median / highest)" % [
			bot, runs, first, scores[0], scores[runs / 2], scores[-1], levels[0], levels[runs / 2], levels[-1],
			moves[0], moves[runs / 2], moves[-1], chains[0], chains[runs / 2], chains[-1]])
	_tools_check()
	_levels_check()
	_revive_check()
	_gather_check()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
		print("FAILED: ", what)

## Plays a run out. Returns the stacks set down.
func play(s, careful: bool, most: int) -> int:
	var laid := 0
	var down := 0
	while not s.is_over() and s.placed < most:
		if s.is_full():
			# full with a brush held: the tallest stack goes
			var tall := 0
			for i in s.cells.size():
				if (s.stacks[i] as Array).size() > (s.stacks[tall] as Array).size():
					tall = i
			down -= (s.stacks[tall] as Array).size()
			_check("a full tray takes the brush", s.sweep(tall))
			s.events.clear()
			continue
		var slot := -1
		for i in Sim.HAND:
			if not (s.hand[i] as Array).is_empty():
				slot = i
				break
		var cell := _careful(s, slot) if careful else _random(s)
		var n: int = (s.hand[slot] as Array).size()
		var was: int = s.cleared
		_check("a stack is set on an empty place", s.place(slot, cell))
		down += n
		laid += 1
		_whole(s, down - s.cleared, was)
		s.events.clear()
	_check("a run ends", s.is_over() or s.placed >= most)
	return laid

func _random(s) -> int:
	var open: Array = []
	for i in s.cells.size():
		if s.can_place(i):
			open.append(i)
	return open[s.rng.randi_range(0, open.size() - 1)]

## The place beside the most mats of this stack's top colour, a stack of one
## colour first.
func _careful(s, slot: int) -> int:
	var stack: Array = s.hand[slot]
	var col: int = stack[stack.size() - 1]
	var best := -1
	var best_v := -1.0
	for i in s.cells.size():
		if not s.can_place(i):
			continue
		var v := 0.0
		for n: int in s.near[i]:
			var t: Array = s.stacks[n]
			if not t.is_empty() and t[t.size() - 1] == col:
				v += Sim.run_of(t) + (2.0 if Sim.runs_of(t) == 1 else 0.0)
			elif t.is_empty() and not s.closed[n]:
				v += 0.1
		if v > best_v:
			best_v = v
			best = i
	return best

func _whole(s, lying: int, cleared_before: int) -> void:
	_check("the mats lying are the mats set down less the mats put away (%d, %d)" % [s.mats(), lying], s.mats() == lying)
	_check("the score never falls behind the mats put away", s.score >= s.cleared and s.cleared >= cleared_before)
	for i in s.cells.size():
		var t: Array = s.stacks[i]
		if t.is_empty():
			continue
		_check("a lid covers nothing", not s.closed[i])
		_check("no stack is left with %d of a colour on top" % Sim.CLEAR, Sim.run_of(t) < Sim.CLEAR)
		for n: int in s.near[i]:
			var o: Array = s.stacks[n]
			_check("no two stacks that touch share a top colour", o.is_empty() or o[o.size() - 1] != t[t.size() - 1])
	for ev: Dictionary in s.events:
		if ev.type == "over":
			_check("over only with the tray full and no brush", s.is_full() and s.sweeps == 0)
	if not s.is_over():
		_check("a hand is always held", not s._hand_empty())

func _tools_check() -> void:
	var s = Sim.new(7)
	s.events.clear()
	_check("a brush on an empty place does nothing", not s.sweep(0))
	var open := _random(s)
	s.place(0, open)
	_check("the brush takes a stack off", s.sweep(open) and (s.stacks[open] as Array).is_empty() and s.sweeps == Sim.SWEEPS - 1)
	_check("no brush, no sweep", s.sweeps > 0 or not s.sweep(open))
	var before: Array = s.hand.duplicate(true)
	_check("a fresh hand", s.redeal() and s.deals == Sim.DEALS - 1 and not s._hand_empty())
	_check("no deal left, no fresh hand", s.deals > 0 or not s.redeal())
	_check("the hand was three stacks", before.size() == Sim.HAND)

func _levels_check() -> void:
	_check("three colours at first, six at most", Sim.colours_at(1) == 3 and Sim.colours_at(99) == Sim.COLOURS_MOST)
	_check("the goals rise", Sim.goal(1) < Sim.goal(2) and Sim.floor_of(1) == 0 and Sim.floor_of(3) == Sim.goal(2))
	var s = Sim.new(3)
	var shut := 0
	for c: bool in s.closed:
		shut += 1 if c else 0
	_check("six corners under lids", shut == 6 and Sim.OPENS_AT.size() == 6)
	s.score = Sim.goal(1)
	s.events.clear()
	s._levels()
	_check("a level reached opens a place and gives a tool", s.level == 2 and s.events.size() == 1 and int(s.events[0].open) >= 0 and s.sweeps == Sim.SWEEPS + 1)

func _revive_check() -> void:
	var s = Sim.new(11)
	s.sweeps = 0
	play(s, false, 6000)
	_check("the random bot's run ends", s.is_over())
	s.events.clear()
	s.revive()
	_check("a Second chance takes four stacks off and goes on", not s.is_over() and s.empties() == Sim.REVIVE_TAKES and s.events.size() == 1)

## A line of three with one colour on top gathers on the stack of one colour,
## and ten are put away; what was under gathers in its turn.
func _gather_check() -> void:
	var s = Sim.new(5)
	for i in s.cells.size():
		s.closed[i] = false
	var mid: int = s._index[Vector2i(0, 0)]
	var a: int = s._index[Vector2i(1, 0)]
	var b: int = s._index[Vector2i(2, 0)]
	var c: int = s._index[Vector2i(-1, 0)]
	s.stacks[a] = [0, 0, 0, 0]
	s.stacks[b] = [1, 1, 0, 0, 0]
	s.stacks[c] = [1, 1, 1, 1, 1, 1, 1, 1]
	s.hand[0] = [1, 0, 0, 0]
	s.events.clear()
	_check("set down", s.place(0, mid))
	# 3 + 4 + 3 of colour 0 gather on `a` (one colour) and go: 10 points; then
	# the 1 under the middle and the 1s under `b` meet... `b` is not beside
	# the middle, so only the middle's 1 joins `c`'s eight: nine, not ten
	_check("ten gathered and put away (score %d)" % s.score, s.score == 10 and (s.stacks[a] as Array).is_empty())
	_check("what was uncovered gathered too", (s.stacks[c] as Array).size() == 9 and (s.stacks[mid] as Array).is_empty() and (s.stacks[b] as Array) == [1, 1])
	var moves := 0
	for ev: Dictionary in s.events:
		if ev.type == "move":
			moves += 1
	_check("three hops of mats were told (%d)" % moves, moves == 3)
