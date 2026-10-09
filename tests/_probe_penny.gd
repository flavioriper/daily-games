extends SceneTree

## Penny Drop's rules and computer, headless:
##     godot --headless --path . --script res://tests/_probe_penny.gd -- [games] [seed]
## The rules' own cases (a penny's fall, a full column, the four lines, a
## line of five, a draw, a move taken back), then every pairing of levels
## over `games` games (40), who drops first alternating: each level must beat
## the one under it. Prints how long the top level takes a move, and how a
## planless player (a random column) fares against each.

const Rules = preload("res://versus/penny_rules.gd")
const AI = preload("res://versus/penny_ai.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 40
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 7
	_rules()
	_sees(rng)
	_pairs(games, rng)
	_planless(games, rng)
	print("FAILS ", _fails)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	if not yes:
		_fails += 1
	print("  ", "ok  " if yes else "FAIL", " ", what)

static func _played(cols: Array) -> RefCounted:
	var r := Rules.new()
	for c: int in cols:
		r.make(c)
	return r

func _rules() -> void:
	print("rules")
	var r := Rules.new()
	_ok("a penny falls to the bottom", r.make(3) == Rules.cell(3, 0) and r.at(3, 0) == Rules.FIRST + 1)
	_ok("the next lands on it, the other side's", r.make(3) == Rules.cell(3, 1) and r.at(3, 1) == Rules.SECOND + 1)
	_ok("the turn passes", r.turn == Rules.FIRST and r.ply == 2)
	for k in 4:
		r.make(3)
	_ok("a full column takes no more", not r.can(3) and r.make(3) == -1 and r.landing(3) == -1 and r.legal_moves().size() == 6)
	_ok("a column off the rack is refused", r.make(-1) == -1 and r.make(7) == -1)
	_ok("six in a column of two sides is no line", r.status() == Rules.PLAYING)
	var up := _played([0, 1, 0, 1, 0, 1, 0])
	_ok("four up a column win", up.status() == Rules.WON and up.winner == Rules.FIRST and up.line.size() == 4)
	_ok("nothing is played after a win", up.legal_moves().is_empty() and up.make(2) == -1)
	var across := _played([0, 0, 1, 1, 2, 2, 3])
	_ok("four across win", across.winner == Rules.FIRST and across.line.size() == 4)
	var slant := _played([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3])
	_ok("four up a slant win", slant.winner == Rules.FIRST and slant.line.size() == 4)
	var down := _played([6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3])
	_ok("four down a slant win", down.winner == Rules.FIRST)
	var second := _played([0, 1, 0, 1, 0, 1, 6, 1])
	_ok("the second side wins too", second.winner == Rules.SECOND)
	var five := _played([0, 0, 1, 1, 3, 3, 4, 4, 2])
	_ok("a penny joining two runs makes a line of five", five.winner == Rules.FIRST and five.line.size() == 5)
	five.unmake()
	_ok("taken back, the game is on again", five.status() == Rules.PLAYING and five.winner == -1 and five.line.is_empty()
		and five.turn == Rules.FIRST and five.at(2, 0) == Rules.EMPTY and five.ply == 8)
	# A full rack with no line: columns filled in an order that never gives
	# four (pairs of columns, two of a side at a time).
	var full := Rules.new()
	for c: int in [0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1, 0, 2, 3, 2, 3, 2, 3, 3, 2, 3, 2, 3, 2,
			4, 5, 4, 5, 4, 5, 5, 4, 5, 4, 5, 4, 6, 6, 6, 6, 6, 6]:
		if full.make(c) < 0:
			break
	_ok("a full rack with no line is a draw", full.ply == Rules.CELLS and full.status() == Rules.DRAW and full.winner == -1
		and full.legal_moves().is_empty())
	var c2: RefCounted = across.copy()
	c2.unmake()
	_ok("a copy is its own", across.winner == Rules.FIRST and c2.winner == -1)

## What every level above the first must never miss.
func _sees(rng: RandomNumberGenerator) -> void:
	print("the computer's eye")
	var ai := AI.new()
	var win := _played([3, 0, 3, 0, 3, 1])
	var block := _played([3, 0, 3, 0, 3])
	var both := _played([3, 0, 3, 0, 3, 0, 6])
	for level in [1, 2]:
		_ok("level %d takes a win" % level, ai.plan(win, level, rng.randi()) == 3)
		_ok("level %d stops a line" % level, ai.plan(block, level, rng.randi()) == 3)
		_ok("level %d wins rather than stops" % level, ai.plan(both, level, rng.randi()) == 0)
	# Three on the floor open at both ends cannot be stopped; one move
	# earlier it can, and only by looking two plies on.
	var open := _played([2, 2, 3])
	var m := ai.plan(open, 2, rng.randi())
	_ok("the top level stops two on the floor from becoming an open three (played %d)" % m, m == 1 or m == 4)
	var t := Time.get_ticks_msec()
	var first := ai.plan(Rules.new(), 2, rng.randi())
	print("  the top level opens in column %d after %d ms" % [first, Time.get_ticks_msec() - t])
	_ok("and it opens in the middle", first == 3)
	_ok("a full rack has no move", ai.plan(_played([0, 1, 0, 1, 0, 1, 0]), 2, 1) == -1)

## One game, `levels[0]` dropping first; a level of -1 plays any column. The
## winner's index, -1 a draw. The top level is given `budget` ms a move.
func _game(levels: Array, rng: RandomNumberGenerator, budget: int) -> int:
	var r := Rules.new()
	var ai := AI.new()
	while r.status() == Rules.PLAYING:
		var lv: int = levels[r.turn]
		var c := -1
		if lv < 0:
			var open: PackedInt32Array = r.legal_moves()
			c = open[rng.randi() % open.size()]
		else:
			c = ai.plan(r, lv, rng.randi(), budget)
		if r.make(c) < 0:
			_fails += 1
			print("  FAIL level ", lv, " played column ", c, " which has no room")
			return -1
	return r.winner

func _pairs(games: int, rng: RandomNumberGenerator) -> void:
	print("pairs over ", games, " games (the top level at 60 ms a move)")
	for a in 3:
		for b in range(a + 1, 3):
			var tally := [0, 0, 0]
			for g in games:
				var swap := g % 2 == 1
				var w := _game([b, a] if swap else [a, b], rng, 60)
				if w < 0:
					tally[2] += 1
				else:
					tally[(1 - w) if swap else w] += 1
			print("  level %d v level %d: %d - %d, %d drawn" % [a, b, tally[0], tally[1], tally[2]])
			_ok("level %d beats level %d" % [b, a], tally[1] > tally[0] * 1.5)

func _planless(games: int, rng: RandomNumberGenerator) -> void:
	print("a random column against each level, ", games, " games")
	for level in 3:
		var tally := [0, 0, 0]
		for g in games:
			var swap := g % 2 == 1
			var w := _game([level, -1] if swap else [-1, level], rng, 60)
			if w < 0:
				tally[2] += 1
			else:
				tally[(1 - w) if swap else w] += 1
		print("  random v level %d: %d - %d, %d drawn" % [level, tally[0], tally[1], tally[2]])

