extends SceneTree

## Dominoes' rules and computer, headless:
##     godot --headless --path . --script res://tests/_probe_dominoes.gd -- [games] [seed]
## The rules' own cases (the deal, a tile that fits and one that does not, a
## double, a draw only for a hand that cannot play, the boneyard's last two,
## a pass, a blocked line, going out, the score, the lead changing sides, a
## game to its target, the same seed the same game), what a view shows and
## hides, what the computer knows of a hand that drew, then every pairing of
## levels over `games` games (40), the lead alternating: each level must beat
## the one under it. Prints how long the top level takes a move.

const Rules = preload("res://versus/dominoes_rules.gd")
const AI = preload("res://versus/dominoes_ai.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var games := int(args[0]) if args.size() > 0 else 40
	var rng := RandomNumberGenerator.new()
	rng.seed = int(args[1]) if args.size() > 1 else 7
	_rules()
	_sees()
	_pairs(games, rng)
	print("FAILS ", _fails)
	quit(1 if _fails > 0 else 0)

func _ok(what: String, yes: bool) -> void:
	if not yes:
		_fails += 1
	print("  ", "ok  " if yes else "FAIL", " ", what)

static func T(a: int, b: int) -> int:
	return Rules.id(a, b)

func _rules() -> void:
	print("rules")
	var ids := {}
	for a in 7:
		for b in range(a, 7):
			ids[T(a, b)] = true
			if Rules.LO[T(a, b)] != a or Rules.HI[T(a, b)] != b or T(b, a) != T(a, b):
				ids[-1] = true
	_ok("twenty-eight tiles, each pair once", ids.size() == 28 and not ids.has(-1))
	var r := Rules.new()
	r.deal(1234)
	var all := {}
	for t in r.hands[0]:
		all[t] = true
	for t in r.hands[1]:
		all[t] = true
	for t in r.stock:
		all[t] = true
	_ok("seven each and fourteen in the boneyard, no tile twice",
		r.hands[0].size() == 7 and r.hands[1].size() == 7 and r.stock.size() == 14 and all.size() == 28)
	var again := Rules.new()
	again.deal(1234)
	var other := Rules.new()
	other.deal(1235)
	_ok("the same seed deals the same hand, another seed another", again.digest() == r.digest() and other.digest() != r.digest())
	_ok("the leader may lay any tile", r.legal_moves().size() == 7 and r.turn == Rules.FIRST)

	r = Rules.new()
	r.lay([T(6, 4), T(3, 3), T(1, 0)], [T(4, 4), T(5, 2)], [T(0, 0), T(1, 1), T(6, 6), T(2, 2)], [T(6, 3) * 2])
	_ok("the line's ends are the first tile's numbers", r.ends[0] == 3 and r.ends[1] == 6)
	_ok("a tile fits the end with its number and no other", r.can(T(6, 4) * 2 + 1) and not r.can(T(6, 4) * 2))
	_ok("a tile with neither number is refused, and one not held", not r.can(T(1, 0) * 2) and not r.can(T(5, 5) * 2 + 1))
	_ok("no draw while a tile fits", not r.can(Rules.DRAW) and not r.can(Rules.PASS))
	_ok("laid: the end takes the tile's other number, the turn passes",
		r.make(T(6, 4) * 2 + 1) and r.ends[1] == 4 and r.turn == Rules.SECOND and r.hands[0].size() == 2)
	_ok("a double leaves the end as it was", r.make(T(4, 4) * 2 + 1) and r.ends[1] == 4)
	_ok("3-3 at the 3 end", r.make(T(3, 3) * 2) and r.ends[0] == 3)
	# second holds 5-2 against 3 and 4: it draws 2-2, 6-6, and then may not.
	_ok("a hand that cannot play must draw", r.legal_moves() == PackedInt32Array([Rules.DRAW]) and not r.can(Rules.PASS))
	r.make(Rules.DRAW)
	_ok("the draw is the boneyard's last tile and the turn stays", r.hands[1].has(T(2, 2)) and r.turn == Rules.SECOND and r.stock.size() == 3)
	r.make(Rules.DRAW)
	_ok("the last two are never drawn: it passes", r.stock.size() == 2 and r.legal_moves() == PackedInt32Array([Rules.PASS]) and not r.can(Rules.DRAW))
	r.make(Rules.PASS)
	_ok("one pass does not end the hand", not r.hand_over and r.turn == Rules.FIRST)
	r.make(Rules.PASS)
	_ok("both passing blocks the line", r.hand_over and r.hand_blocked)
	# first holds 1-0 (1), second 5-2, 2-2, 6-6 (23)
	_ok("blocked: the lighter hand takes the difference", r.hand_winner == Rules.FIRST and r.hand_points == 22 and r.scores[0] == 22)
	_ok("nothing is played in a hand that is over", r.legal_moves().is_empty() and not r.make(T(1, 0) * 2))
	_ok("the lead changes sides", r.leader == Rules.SECOND and r.turn == Rules.SECOND)

	r = Rules.new()
	r.lay([T(6, 4)], [T(5, 5), T(6, 5)], [T(0, 0), T(1, 1)], [T(6, 3) * 2])
	r.make(T(6, 4) * 2 + 1)
	_ok("laying the last tile ends the hand and takes the other hand's pips",
		r.hand_over and not r.hand_blocked and r.hand_winner == Rules.FIRST and r.hand_points == 21 and r.last_mover == Rules.FIRST)
	r = Rules.new()
	r.lay([T(2, 1)], [T(3, 0)], [T(0, 0), T(1, 1)], [T(6, 6) * 2])
	r.make(Rules.PASS)
	r.make(Rules.PASS)
	_ok("blocked with the same count is nobody's hand", r.hand_over and r.hand_winner == -1 and r.scores[0] == 0 and r.scores[1] == 0)

	# whole games by the first legal move
	var hands := 0
	var longest := 0
	for s in 200:
		var g := Rules.new()
		g.deal(s * 7919 + 1, s % 2)
		var twin := Rules.new()
		twin.deal(s * 7919 + 1, s % 2)
		var guard := 0
		while g.status() == Rules.PLAYING and guard < 4000:
			guard += 1
			if g.hand_over:
				hands += 1
				g.next_hand()
				twin.next_hand()
				continue
			var m := g.legal_moves()[0]
			g.make(m)
			twin.make(m)
		longest = maxi(longest, g.plays.size())
		if g.status() != Rules.WON or g.scores[g.winner] < Rules.TARGET or twin.digest() != g.digest():
			_ok("game %d ends at the target, the same at both ends" % s, false)
	_ok("200 games end with a side at %d (%.1f hands a game)" % [Rules.TARGET, hands / 200.0 + 1.0], true)

func _sees() -> void:
	print("what a side sees")
	var r := Rules.new()
	r.deal(99)
	var v := r.view(Rules.FIRST)
	var leak := false
	for k: String in v:
		var val: Variant = v[k]
		if val is PackedInt32Array and k != "hand" and k != "line" and k != "ends" and k != "scores" and k != "legal":
			leak = true
	_ok("a view holds its own hand and two counts, no other tiles",
		not leak and v.hand == r.hands[0] and int(v.theirs) == 7 and int(v.stock) == 14 and not v.has("hands"))
	r = Rules.new()
	r.lay([T(6, 4), T(1, 0)], [T(5, 2)], [T(0, 0), T(1, 1), T(3, 2), T(2, 2)], [T(6, 3) * 2], Rules.SECOND)
	r.make(Rules.DRAW)   # 2-2: no
	r.make(Rules.DRAW)   # 3-2: fits the 3
	r.make(T(3, 2) * 2)
	var none := AI.lacks(r.view(Rules.FIRST))
	_ok("a side that drew is known to hold no 3 and no 6", none.has(3) and none.has(6) and none.size() == 2)
	var ai := AI.new()
	var at := Time.get_ticks_msec()
	r = Rules.new()
	r.deal(5)
	var m := ai.plan(r.view(Rules.FIRST), 2, 1)
	_ok("the top level opens with a tile it holds, in %d ms" % (Time.get_ticks_msec() - at), r.can(m))

## One game, `levels[0]` leading its first hand. The winner's index.
func _game(levels: Array, rng: RandomNumberGenerator, budget: int) -> int:
	var r := Rules.new()
	r.deal(rng.randi() & 0x7fffffff)
	var ai := AI.new()
	var guard := 0
	while r.status() == Rules.PLAYING and guard < 5000:
		guard += 1
		if r.hand_over:
			r.next_hand()
			continue
		var m := ai.plan(r.view(r.turn), levels[r.turn], rng.randi(), budget)
		if not r.make(m):
			_fails += 1
			print("  FAIL level ", levels[r.turn], " made move ", m, " which the rules refuse")
			return -1
	return r.winner

func _pairs(games: int, rng: RandomNumberGenerator) -> void:
	print("pairs over ", games, " games (the top level at 25 ms a move)")
	for a in 3:
		for b in range(a + 1, 3):
			var tally := [0, 0]
			for g in games:
				var swap := g % 2 == 1
				var w := _game([b, a] if swap else [a, b], rng, 25)
				if w >= 0:
					tally[(1 - w) if swap else w] += 1
			print("  level %d v level %d: %d - %d" % [a, b, tally[0], tally[1]])
			_ok("level %d beats level %d" % [b, a], tally[1] > tally[0])
