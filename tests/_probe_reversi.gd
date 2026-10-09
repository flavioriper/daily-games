extends SceneTree

## Reversi's rules and computer, headless:
##     godot --headless --path . --script res://tests/_probe_reversi.gd -- [games] [seed]
## The rules' own cases (the opening, a line shut and turned, every direction
## at once, a square that shuts nothing, the pass, the end, a draw, a move
## taken back), the move generator counted against the published numbers of
## positions after one to seven plies, then every pairing of levels over
## `games` games (20), who moves first alternating: each level must beat the
## one under it. Prints how long the top level takes a move, and how a
## planless player (any square) fares against each.

const Rules = preload("res://versus/reversi_rules.gd")
const AI = preload("res://versus/reversi_ai.gd")

## Positions reached from the opening after 1..7 plies.
const PERFT := [4, 12, 56, 244, 1396, 8200, 55092]

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 20
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 7
	_rules()
	_perft()
	_random_games(rng)
	_pairs(games, rng)
	_planless(games, rng)
	print("FAILS ", _fails)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	if not yes:
		_fails += 1
	print("  ", "ok  " if yes else "FAIL", " ", what)

static func _laid(rows: Array, side := Rules.FIRST) -> RefCounted:
	var r := Rules.new()
	r.lay(rows, side)
	return r

func _rules() -> void:
	print("rules")
	var r := Rules.new()
	_ok("four discs in the middle, two a side on the slants", r.count(Rules.FIRST) == 2 and r.count(Rules.SECOND) == 2
		and r.at(3, 3) == Rules.SECOND + 1 and r.at(4, 4) == Rules.SECOND + 1 and r.at(4, 3) == Rules.FIRST + 1 and r.at(3, 4) == Rules.FIRST + 1)
	var open := Array(r.legal_moves())
	open.sort()
	_ok("the first side has four squares", open == [Rules.cell(3, 2), Rules.cell(2, 3), Rules.cell(5, 4), Rules.cell(4, 5)])
	_ok("a square that shuts nothing is refused", not r.can(Rules.cell(0, 0)) and r.make(Rules.cell(0, 0)).is_empty()
		and r.make(Rules.cell(2, 2)).is_empty() and r.ply == 0)
	_ok("a taken square is refused", r.make(Rules.cell(3, 3)).is_empty())
	_ok("off the board is refused", r.make(-1).is_empty() and r.make(64).is_empty())
	var turned: PackedInt32Array = r.make(Rules.cell(3, 2))
	_ok("a line shut is turned over", Array(turned) == [Rules.cell(3, 3)] and r.at(3, 3) == Rules.FIRST + 1 and r.at(3, 2) == Rules.FIRST + 1
		and r.count(Rules.FIRST) == 4 and r.count(Rules.SECOND) == 1)
	_ok("the turn passes to the other side", r.turn == Rules.SECOND and r.ply == 1 and not r.passed and r.last_side == Rules.FIRST)
	r.unmake()
	_ok("taken back, the board is the opening's", r.turn == Rules.FIRST and r.ply == 0 and r.at(3, 3) == Rules.SECOND + 1
		and r.at(3, 2) == Rules.EMPTY and r.last_side == -1)
	# One disc shutting a line in all eight directions.
	var star := _laid([
		"x..x..x.",
		".o.o.o..",
		"..ooo...",
		"xoo.oox.",
		"..ooo...",
		".o.o.o..",
		"x..x..x.",
		"........"])
	var all: PackedInt32Array = star.flips(Rules.cell(3, 3), Rules.FIRST)
	_ok("every direction is turned at once", all.size() == 16)
	star.make(Rules.cell(3, 3))
	_ok("and nothing of the other side is left on those lines", star.count(Rules.SECOND) == 0 and star.count(Rules.FIRST) == 25)
	_ok("a side wiped out ends the game", star.over and star.status() == Rules.WON and star.winner() == Rules.FIRST)
	var gap := _laid(["xo.ox...", "........", "........", "........", "........", "........", "........", "........"])
	_ok("a run is shut only by a disc of the mover's own, with no gap", Array(gap.flips(2, Rules.FIRST)) == [3, 1]
		and gap.flips(2, Rules.SECOND).is_empty() and gap.flips(5, Rules.FIRST).is_empty())
	# The second side has no square after this move: the first moves again.
	var skip := _laid([
		"xo......",
		"........",
		"........",
		"....xo..",
		"........",
		"........",
		"........",
		"......ox"], Rules.FIRST)
	skip.make(Rules.cell(6, 3))
	_ok("a side with no square is passed over", skip.turn == Rules.FIRST and skip.passed and not skip.over
		and skip.status() == Rules.PLAYING and not skip.has_move(Rules.SECOND))
	skip.unmake()
	_ok("a pass is taken back with its move", skip.turn == Rules.FIRST and not skip.passed and skip.at(5, 3) == Rules.SECOND + 1)
	var none := _laid(["xo......", "........", "........", "........", "........", "........", "........", "........"], Rules.SECOND)
	_ok("laid with no square for the side to move, the other moves", none.turn == Rules.FIRST and none.passed)
	none.make(2)
	_ok("neither side with a square ends it short of a full board", none.over and none.winner() == Rules.FIRST
		and none.legal_moves().is_empty() and none.make(5).is_empty())
	var draw := _laid([
		"xxxxoooo", "xxxxoooo", "xxxxoooo", "xxxxoooo",
		"xxxxoooo", "xxxxoooo", "xxxxoooo", "xxxxoooo"])
	_ok("the same count is a draw", draw.over and draw.status() == Rules.DRAW and draw.winner() == -1)
	var c2: RefCounted = skip.copy()
	c2.make(Rules.cell(6, 3))
	_ok("a copy is its own", skip.ply == 0 and c2.ply == 1)

static func _count(r: RefCounted, depth: int) -> int:
	if depth == 0:
		return 1
	var n := 0
	for m in r.legal_moves():
		r.make(m)
		n += _count(r, depth - 1)
		r.unmake()
	return n

func _perft() -> void:
	print("positions after n plies")
	var r := Rules.new()
	for d in PERFT.size():
		var n := _count(r, d + 1)
		_ok("%d plies: %d (%d)" % [d + 1, n, PERFT[d]], n == PERFT[d])
	_ok("and the board is the opening's again", r.ply == 0 and r.count(Rules.FIRST) == 2 and r.count(Rules.SECOND) == 2)

## Whole games of any square at all: every one ends, the count adds up, and
## taking every move back gives the opening.
func _random_games(rng: RandomNumberGenerator) -> void:
	print("games of any square")
	var bad := 0
	var passes := 0
	var draws := 0
	var short := 0
	for g in 300:
		var r := Rules.new()
		while not r.over:
			var m: PackedInt32Array = r.legal_moves()
			if m.is_empty():
				bad += 1
				break
			r.make(m[rng.randi() % m.size()])
			if r.passed and not r.over:
				passes += 1
		if r.count(Rules.FIRST) + r.count(Rules.SECOND) != 4 + r.ply:
			bad += 1
		if r.status() == Rules.DRAW:
			draws += 1
		if r.ply < 60:
			short += 1
		while r.ply > 0:
			r.unmake()
		if r.cells != Rules.new().cells or r.turn != Rules.FIRST:
			bad += 1
	_ok("300 games end, add up and come back (%d passes, %d draws, %d ended short of full)" % [passes, draws, short], bad == 0 and passes > 0)

## One game, `a` the first side's level and `b` the second's (-1 any square).
## The winner's side, -1 a draw.
func _game(a: int, b: int, rng: RandomNumberGenerator, budget := 25) -> int:
	var r := Rules.new()
	var ai := AI.new()
	while not r.over:
		var lv := a if r.turn == Rules.FIRST else b
		var m := -1
		if lv < 0:
			var moves: PackedInt32Array = r.legal_moves()
			m = moves[rng.randi() % moves.size()]
		else:
			m = ai.plan(r, lv, rng.randi(), budget)
		if r.make(m).is_empty():
			_fails += 1
			print("  FAIL level ", lv, " played a square it may not: ", m)
			return -1
	return r.winner()

func _pairs(games: int, rng: RandomNumberGenerator) -> void:
	print("levels (", games, " games a pairing, the top level at 25 ms)")
	var t0 := Time.get_ticks_msec()
	var ai := AI.new()
	ai.plan(Rules.new(), 2, 1)
	print("  the top level's first move: ", Time.get_ticks_msec() - t0, " ms")
	for pair: Array in [[1, 0], [2, 0], [2, 1]]:
		var won := 0
		var lost := 0
		for g in games:
			var first: bool = g % 2 == 0
			var w := _game(pair[0] if first else pair[1], pair[1] if first else pair[0], rng)
			if w < 0:
				continue
			if (w == Rules.FIRST) == first:
				won += 1
			else:
				lost += 1
		_ok("%d beats %d: %d-%d" % [pair[0], pair[1], won, lost], won > lost)

func _planless(games: int, rng: RandomNumberGenerator) -> void:
	print("any square against each level")
	for lv in 3:
		var won := 0
		var lost := 0
		for g in games:
			var first: bool = g % 2 == 0
			var w := _game(-1 if first else lv, lv if first else -1, rng)
			if w < 0:
				continue
			if (w == Rules.FIRST) == first:
				won += 1
			else:
				lost += 1
		print("  any square against ", lv, ": ", won, "-", lost)
