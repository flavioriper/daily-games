extends SceneTree

## Plays Deckchair's sim headless with a bot and prints how the deals went.
## Run after touching arcade/deckchair_sim.gd.
##   godot --headless --script tests/_probe_deckchair.gd -- [deals] [first seed]
## The bot takes whatever `find_move` hands it (a card turned up first, then
## a card home, then a card off the stock, then the nearest rearranging that
## leads to one), sweeps once every card is face up and stops when the sim
## says stuck. After every move the whole deal is checked: 52 cards, each
## once; every face-up run built down in alternating colours; no column
## with nothing but face-down cards. Then undo, the stuck search, the
## aces-home deal and the Second chance are checked on their own.

const Sim = preload("res://arcade/deckchair_sim.gd")

var _fails := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var deals := int(args[0]) if args.size() > 0 else 200
	var first := int(args[1]) if args.size() > 1 else 1
	var won := 0
	var stuck := 0
	var capped := 0
	var scores: Array = []
	var homes: Array = []
	var lens: Array = []
	var slow := 0
	for k in deals:
		var s = Sim.new(first + k)
		var began := Time.get_ticks_usec()
		var n := play(s, 4000)
		slow = maxi(slow, int((Time.get_ticks_usec() - began) / maxi(n, 1)))
		lens.append(n)
		if s.phase == Sim.Phase.WON:
			won += 1
		elif s.stuck and not s.unsure:
			stuck += 1
		else:
			capped += 1
		scores.append(s.score - s.bonus)
		homes.append(s.home_count())
	scores.sort()
	homes.sort()
	lens.sort()
	print("%d deals from seed %d: won %d (%.0f%%), stuck %d, stuck past the search's reach %d" % [deals, first, won, 100.0 * won / deals, stuck, capped])
	print("score without the bonus: lowest %d  median %d  highest %d" % [scores[0], scores[deals / 2], scores[-1]])
	print("cards home: lowest %d  median %d  highest %d;  moves: median %d  most %d;  slowest deal %d usec a move" % [
		homes[0], homes[deals / 2], homes[-1], lens[deals / 2], lens[-1], slow])
	_check("few deals end past the search's reach", capped * 8 <= deals)
	var worst := 0
	for k in mini(deals, 60):
		var s = Sim.new(first + k)
		while s.phase == Sim.Phase.PLAY:
			var began := Time.get_ticks_usec()
			var m: Dictionary = s.find_move()
			if m.is_empty():
				break
			if s.sweeping:
				s.sweep_step()
			elif m.has("draw"):
				s.draw()
			else:
				s.drop(int(m.card), int(m.kind), int(m.i))
			worst = maxi(worst, Time.get_ticks_usec() - began)
			s.events.clear()
	print("the slowest single move of %d deals: %.1f ms" % [mini(deals, 60), worst / 1000.0])
	_check("some deals are won", won > 0)
	_undo_check()
	_stuck_check()
	_aces_check()
	_revive_check()
	_score_check()
	print("%d failed" % _fails)
	quit(1 if _fails > 0 else 0)

## Plays a deal out with the bot. Returns the moves it made.
func play(s, most: int) -> int:
	var n := 0
	_whole(s, "dealt")
	while s.phase == Sim.Phase.PLAY and n < most:
		if s.sweeping:
			if not s.sweep_step():
				_check("a sweep runs to the win", false)
				break
		else:
			var m: Dictionary = s.find_move()
			if m.is_empty():
				break
			var ok: bool = s.draw() if m.has("draw") else s.drop(int(m.card), int(m.kind), int(m.i))
			if not ok:
				_check("the sim takes its own move (seed %d, move %d: %s)" % [s.seed_used, n, m], false)
				break
		s.events.clear()
		n += 1
		_whole(s, "seed %d move %d" % [s.seed_used, n])
	return n

func _whole(s, what: String) -> void:
	var seen := {}
	var count := 0
	for c in Sim.COLS:
		var pile: Array = s.cols[c]
		var d: int = s.down[c]
		if (pile.is_empty() and d != 0) or (not pile.is_empty() and d >= pile.size()):
			_check("a column shows a card (%s)" % what, false)
		for i in pile.size():
			seen[pile[i]] = true
			count += 1
			if i > d and not (Sim.rank_of(pile[i - 1]) == Sim.rank_of(pile[i]) + 1 and Sim.is_red(pile[i - 1]) != Sim.is_red(pile[i])):
				_check("a run is built down in turn (%s)" % what, false)
	for c: int in s.stock + s.waste:
		seen[c] = true
		count += 1
	for suit in Sim.SUITS:
		for r in int(s.home[suit]):
			seen[suit * Sim.RANKS + r] = true
			count += 1
	if count != Sim.DECK or seen.size() != Sim.DECK:
		_check("52 cards, each once (%s: %d, %d)" % [what, count, seen.size()], false)
	if s.score < 0:
		_check("the score is never under nothing (%s)" % what, false)

func _key(s) -> String:
	return str(s.cols) + str(s.down) + str(s.stock) + str(s.waste) + str(s.home) + str(s.score)

func _undo_check() -> void:
	var s = Sim.new(11)
	var keys := [_key(s)]
	for k in 40:
		var m: Dictionary = s.find_move()
		if m.is_empty() or s.sweeping:
			break
		if m.has("draw"):
			s.draw()
		else:
			s.drop(int(m.card), int(m.kind), int(m.i))
		keys.append(_key(s))
	var ok := true
	while s.can_undo():
		keys.pop_back()
		s.undo()
		ok = ok and _key(s) == keys[-1]
	_check("undo walks all the way back, points and all", ok and keys.size() == 1 and s.score == 0)

## A hand-made dead end: nothing fits anywhere and the stock is out.
func _stuck_check() -> void:
	var s = Sim.new(5)
	# hearts' two on a face-down three of spades and so on: tops that take
	# nothing, an empty stock
	s.cols = [[_c(1, 4)], [_c(3, 4)], [_c(0, 9)], [_c(2, 9)], [_c(1, 7)], [_c(3, 7)], [_c(0, 0), _c(0, 2)]]
	s.down = [0, 0, 0, 0, 0, 0, 1]
	s.stock = []
	s.waste = []
	s.home = [0, 0, 0, 0]
	s._plan.clear()
	_check("a dead end has no way on", s.find_move().is_empty())
	# the same with a black six for a red five: a way on through a rearranging
	s.cols[2] = [_c(0, 5)]
	s._plan.clear()
	var m: Dictionary = s.find_move()
	_check("a five onto a six is not progress, so still none", m.is_empty())
	# an ace buried under one card that can move away: two moves to a card home
	s.cols[6] = [_c(2, 0), _c(1, 4)]
	s.down[6] = 0
	s.cols[0] = [_c(0, 5)]
	s.cols[2] = [_c(0, 9)]
	s._plan.clear()
	m = s.find_move()
	_check("the search sees a card freed by moving another", not m.is_empty() and int(m.card) == _c(1, 4))
	if not m.is_empty():
		s.drop(int(m.card), int(m.kind), int(m.i))
		m = s.find_move()
		_check("and then sends the ace home", not m.is_empty() and int(m.card) == _c(2, 0) and int(m.kind) == Sim.At.HOME)

func _c(suit: int, rank: int) -> int:
	return suit * Sim.RANKS + rank

func _aces_check() -> void:
	var s = Sim.new(21)
	s.start_aces()
	_whole(s, "aces home")
	_check("the aces begin at home and score nothing", s.home_count() == 4 and s.score == 0 and s.stock.size() == 20)
	play(s, 4000)

func _revive_check() -> void:
	var found := 0
	var ok := true
	for k in 60:
		var s = Sim.new(900 + k)
		play(s, 4000)
		if s.phase != Sim.Phase.PLAY or not s.stuck:
			continue
		found += 1
		var hidden: int = s.hidden_count()
		var held: int = s.score
		s.finish()
		s.revive()
		_whole(s, "revived")
		ok = ok and s.phase == Sim.Phase.PLAY and not s.stuck and s.hidden_count() == hidden and s.score == held \
			and not s.find_move().is_empty()
		if found >= 12:
			break
	_check("a Second chance leaves a way on (%d dead ends tried)" % found, ok and found > 0)

func _score_check() -> void:
	var s = Sim.new(1)
	s.cols = [[_c(0, 0)], [_c(1, 1)], [], [], [], [], [_c(2, 5), _c(3, 4)]]
	s.down = [0, 0, 0, 0, 0, 0, 1]
	s.stock = []
	s.waste = [_c(2, 0)]
	s.home = [0, 0, 0, 0]
	s._plan.clear()
	s.score = 0
	s.drop(_c(0, 0), Sim.At.HOME, 0)
	_check("a card home is %d" % Sim.PTS_HOME, s.score == Sim.PTS_HOME)
	s.drop(_c(2, 0), Sim.At.COL, 1)
	_check("a waste card onto a column is %d" % Sim.PTS_WASTE_COL, s.score == Sim.PTS_HOME + Sim.PTS_WASTE_COL)
	s.drop(_c(0, 0), Sim.At.COL, 1)
	_check("an ace cannot come down onto an ace", s.score == Sim.PTS_HOME + Sim.PTS_WASTE_COL)
	_check("a home refuses another suit", not s.can_drop(_c(2, 0), Sim.At.HOME, 0))

func _check(what: String, ok: bool) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", what)
	else:
		print("ok: ", what)
