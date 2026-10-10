extends RefCounted

## Deckchair's game, as pure data: the seven-column card game for one (spec
## docs/superpowers/specs/2026-10-10-arcade-deckchair-design.md). No clock of
## its own but the seconds the screen hands to `tick`; a move resolves at
## once and leaves what happened in `events` for the screen to play.
##
## A card is a number, 0 to 51: its rank is `c % 13` (0 the ace, 12 the
## king) and its suit `c / 13` (spades, hearts, clubs, diamonds, so an odd
## suit is red). Seven columns (`cols`, the first `down[c]` cards of each
## face down), the stock and the waste (the top of each is its last), and
## four homes, one a suit, which only ever hold ace upward and so are kept
## as a count (`home`).
##
## The rules: a column is built downward in alternating colours; any face-up
## card moves with everything on it; an empty column takes a king; a home is
## built upward in its suit, and its top card may come back down. The stock
## is turned one card at a time and gone through as often as wanted.

enum Phase { PLAY, WON, OVER }
enum At { COL, WASTE, HOME, STOCK }

const COLS := 7
const SUITS := 4
const RANKS := 13
const DECK := 52
const KING := 12
## The score, a card at a time: a card home, a card off the waste onto a
## column, a card turned face up, a card taken back down from its home.
const PTS_HOME := 10
const PTS_WASTE_COL := 5
const PTS_FLIP := 5
const PTS_DOWN := -15
## A deal won pays this over its seconds, never fewer than BONUS_FLOOR.
const BONUS := 700000.0
const BONUS_FLOOR := 30.0
const HINTS := 3
const UNDO_MOST := 400
## The most positions the search for a way on looks at. Past it the deal is
## called stuck all the same and `unsure` says so: the screen's card can be
## put away, so a way on that deep is still the player's to find.
const SEARCH_MOST := 600
const REVIVE_TRIES := 200

var cols: Array = []
var down: Array = []
var stock: Array = []
var waste: Array = []
var home: Array = [0, 0, 0, 0]
var score := 0
var moves := 0
## Times the waste was turned back over into the stock.
var passes := 0
var t := 0.0
var bonus := 0
var hints := HINTS
var phase := Phase.PLAY
## Nothing left that gets anywhere: no card can be turned up, sent home or
## played off the stock, however the columns are rearranged first.
var stuck := false
## A move has been made, so the seconds count.
var began := false
## The cards are being sent home by themselves, every one face up.
var sweeping := false
var events: Array = []
var seed_used := 0

var _rng := RandomNumberGenerator.new()
var _undo: Array = []
## The way on, as moves: what `find_move` hands out, kept across the moves
## that follow it so a card brought down for a reason is not sent back.
var _plan: Array = []
var unsure := false

static func rank_of(c: int) -> int:
	return c % RANKS

static func suit_of(c: int) -> int:
	return c / RANKS

static func is_red(c: int) -> bool:
	return suit_of(c) % 2 == 1

func _init(seed_value := -1) -> void:
	if seed_value < 0:
		_rng.randomize()
		seed_value = int(_rng.randi() & 0x7fffffff)
	seed_used = seed_value
	_deal(false)

## The booster's deal: the same shuffle with the four aces already home.
func start_aces() -> void:
	_deal(true)

func _deal(aces_home: bool) -> void:
	var deck := []
	for c in DECK:
		if not (aces_home and rank_of(c) == 0):
			deck.append(c)
	_rng.seed = seed_used
	_shuffle(deck)
	cols = []
	down = []
	for c in COLS:
		var pile := []
		for k in c + 1:
			pile.append(deck.pop_back())
		cols.append(pile)
		down.append(c)
	stock = deck
	waste = []
	home = [1, 1, 1, 1] if aces_home else [0, 0, 0, 0]
	score = 0
	moves = 0
	passes = 0
	t = 0.0
	bonus = 0
	phase = Phase.PLAY
	began = false
	sweeping = false
	_undo.clear()
	events = [{"type": "deal"}]
	_replan()
	stuck = _plan.is_empty()

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var keep = a[i]
		a[i] = a[j]
		a[j] = keep

func tick(delta: float) -> void:
	if phase == Phase.PLAY and began:
		t += delta

func is_over() -> bool:
	return phase != Phase.PLAY

func home_count() -> int:
	return int(home[0]) + int(home[1]) + int(home[2]) + int(home[3])

func hidden_count() -> int:
	var n := 0
	for c in COLS:
		n += int(down[c])
	return n

## Where a card is: x the place (At), y which column or home, z how far up
## its pile.
func where(card: int) -> Vector3i:
	if rank_of(card) < int(home[suit_of(card)]):
		return Vector3i(At.HOME, suit_of(card), rank_of(card))
	for c in COLS:
		var i: int = (cols[c] as Array).find(card)
		if i >= 0:
			return Vector3i(At.COL, c, i)
	var w := waste.find(card)
	if w >= 0:
		return Vector3i(At.WASTE, 0, w)
	return Vector3i(At.STOCK, 0, stock.find(card))

func is_face_up(card: int) -> bool:
	var w := where(card)
	return w.x == At.WASTE or w.x == At.HOME or (w.x == At.COL and w.z >= int(down[w.y]))

## A card that can be picked up: face up in a column (with what lies on it),
## the top of the waste, or the top of a home.
func movable(card: int) -> bool:
	if phase != Phase.PLAY or sweeping:
		return false
	var w := where(card)
	match w.x:
		At.COL:
			return w.z >= int(down[w.y])
		At.WASTE:
			return w.z == waste.size() - 1
		At.HOME:
			return w.z == int(home[w.y]) - 1
	return false

## The card and everything lying on it.
func run_of(card: int) -> Array:
	var w := where(card)
	if w.x == At.COL:
		return (cols[w.y] as Array).slice(w.z)
	return [card]

static func fits(card: int, pile: Array) -> bool:
	if pile.is_empty():
		return rank_of(card) == KING
	var top: int = pile[pile.size() - 1]
	return rank_of(top) == rank_of(card) + 1 and is_red(top) != is_red(card)

func can_drop(card: int, kind: int, i: int) -> bool:
	if not movable(card):
		return false
	var w := where(card)
	var n := 1
	if w.x == At.COL:
		n = (cols[w.y] as Array).size() - w.z
	if kind == At.HOME:
		return n == 1 and w.x != At.HOME and suit_of(card) == i and rank_of(card) == int(home[i])
	if kind != At.COL or (w.x == At.COL and w.y == i):
		return false
	# a king that already heads its column gains nothing in an empty one
	if (cols[i] as Array).is_empty() and w.x == At.COL and w.z == 0:
		return false
	return fits(card, cols[i])

## Where a tap sends a card: its home when it may go, else the first column
## that takes it, one that is not empty before one that is.
func auto_dst(card: int) -> Vector2i:
	if can_drop(card, At.HOME, suit_of(card)):
		return Vector2i(At.HOME, suit_of(card))
	var empty := -1
	for c in COLS:
		if can_drop(card, At.COL, c):
			if not (cols[c] as Array).is_empty():
				return Vector2i(At.COL, c)
			if empty < 0:
				empty = c
	if empty >= 0:
		return Vector2i(At.COL, empty)
	return Vector2i(-1, -1)

func drop(card: int, kind: int, i: int) -> bool:
	if not can_drop(card, kind, i):
		return false
	_save()
	var follows := not _plan.is_empty() and int(_plan[0].card) == card \
		and int(_plan[0].kind) == kind and int(_plan[0].i) == i
	_do(card, kind, i)
	if follows:
		_plan.pop_front()
	else:
		_plan.clear()
	_after()
	return true

func _do(card: int, kind: int, i: int) -> void:
	var w := where(card)
	var cards := [card]
	match w.x:
		At.COL:
			cards = (cols[w.y] as Array).slice(w.z)
			(cols[w.y] as Array).resize(w.z)
		At.WASTE:
			waste.pop_back()
		At.HOME:
			home[w.y] = int(home[w.y]) - 1
		At.STOCK:
			stock.erase(card)
	var gain := 0
	if kind == At.HOME:
		home[i] = int(home[i]) + 1
		gain = PTS_HOME
	else:
		(cols[i] as Array).append_array(cards)
		if w.x == At.WASTE:
			gain = PTS_WASTE_COL
		elif w.x == At.HOME:
			gain = PTS_DOWN
	events.append({"type": "move", "cards": cards, "from": Vector2i(w.x, w.y), "to": Vector2i(kind, i), "gain": gain})
	if w.x == At.COL and int(down[w.y]) > 0 and (cols[w.y] as Array).size() == int(down[w.y]):
		down[w.y] = int(down[w.y]) - 1
		gain += PTS_FLIP
		events.append({"type": "flip", "card": cols[w.y][int(down[w.y])], "col": w.y, "gain": PTS_FLIP})
	score = maxi(0, score + gain)
	moves += 1
	began = true

func _after() -> void:
	if home_count() == DECK:
		phase = Phase.WON
		sweeping = false
		stuck = false
		bonus = int(BONUS / maxf(t, BONUS_FLOOR))
		score += bonus
		events.append({"type": "win", "bonus": bonus})
		return
	if _plan.is_empty():
		_replan()
	var was := stuck
	stuck = _plan.is_empty()
	if stuck and not was:
		events.append({"type": "stuck"})
	if not sweeping and hidden_count() == 0:
		sweeping = true
		_undo.clear()
		events.append({"type": "sweep"})

## The stock's top card onto the waste, or the waste turned back over once
## the stock is out.
func draw() -> bool:
	if phase != Phase.PLAY or sweeping or (stock.is_empty() and waste.is_empty()):
		return false
	_save()
	if stock.is_empty():
		stock = waste.duplicate()
		stock.reverse()
		waste = []
		passes += 1
		events.append({"type": "recycle", "n": stock.size()})
	else:
		var c: int = stock.pop_back()
		waste.append(c)
		events.append({"type": "draw", "card": c})
	moves += 1
	began = true
	return true

## With every card face up the deal is won: a card goes home each call, the
## lowest that may. False once there is nothing more to send.
func sweep_step() -> bool:
	if phase != Phase.PLAY or not sweeping:
		return false
	var pick := -1
	for c in COLS:
		var pile: Array = cols[c]
		if not pile.is_empty():
			var top: int = pile[pile.size() - 1]
			if rank_of(top) == int(home[suit_of(top)]) and (pick < 0 or rank_of(top) < rank_of(pick)):
				pick = top
	for c: int in waste + stock:
		if rank_of(c) == int(home[suit_of(c)]) and (pick < 0 or rank_of(c) < rank_of(pick)):
			pick = c
	if pick < 0:
		sweeping = false
		return false
	var w := where(pick)
	if w.x == At.WASTE:
		waste.erase(pick)
		waste.append(pick)
	_do(pick, At.HOME, suit_of(pick))
	_plan.clear()
	_after()
	return true

# --- undo ---

func can_undo() -> bool:
	return phase == Phase.PLAY and not sweeping and not _undo.is_empty()

func _save() -> void:
	_undo.append([cols.duplicate(true), down.duplicate(), stock.duplicate(), waste.duplicate(), home.duplicate(),
		score, moves, passes, stuck])
	if _undo.size() > UNDO_MOST:
		_undo.pop_front()

## The last move taken back, its points with it. The seconds are not.
func undo() -> bool:
	if not can_undo():
		return false
	var s: Array = _undo.pop_back()
	cols = s[0]
	down = s[1]
	stock = s[2]
	waste = s[3]
	home = s[4]
	score = s[5]
	moves = s[6]
	passes = s[7]
	stuck = s[8]
	_plan.clear()
	events.append({"type": "undo"})
	return true

# --- the way on ---

## A move that gets somewhere, or {} when there is none: {card, kind, i} to
## hand to `drop`, or {draw} when the card wanted is still in the stock.
func find_move() -> Dictionary:
	if phase != Phase.PLAY:
		return {}
	if _plan.is_empty():
		_replan()
	if _plan.is_empty():
		return {}
	var e: Dictionary = _plan[0]
	var w := where(int(e.card))
	if w.x == At.STOCK or (w.x == At.WASTE and w.z != waste.size() - 1):
		return {"draw": true, "card": e.card}
	return e

## The bulb: one of the run's hints spent on `find_move`.
func hint() -> Dictionary:
	if hints <= 0 or sweeping:
		return {}
	var m := find_move()
	if m.is_empty():
		return {}
	hints -= 1
	return m

## Two looks: the columns rearranged among themselves, which is quick and
## looked at to the end; then, only when that finds nothing, with the homes'
## top cards brought down too, which is many times the positions and is
## given up at SEARCH_MOST.
func _replan() -> void:
	_plan = _search(false)
	if _plan.is_empty():
		_plan = _search(true)

## Breadth first over what the columns can be rearranged into without
## getting anywhere, for the nearest position from which a card is turned
## up, sent home past where the homes stand now, or played off the stock.
## The stock is turned one at a time and for ever, so every card of it and
## of the waste is within reach. Returns the moves to there and that move
## last; nothing when there is no such position.
func _search(with_homes: bool) -> Array:
	unsure = false
	var total := home_count()
	var first := _progress(cols, home, total)
	if not first.is_empty():
		return [first]
	var seen := {_key(cols, home): true}
	var queue := [[cols, home, []]]
	var at := 0
	while at < queue.size():
		var node: Array = queue[at]
		at += 1
		for mv: Dictionary in _shuffles(node[0], node[1], total, with_homes):
			var nc: Array = (node[0] as Array).duplicate(true)
			var nh: Array = (node[1] as Array).duplicate()
			_apply_light(nc, nh, mv)
			var key := _key(nc, nh)
			if seen.has(key):
				continue
			seen[key] = true
			var path: Array = (node[2] as Array).duplicate()
			path.append(mv)
			var hit := _progress(nc, nh, total)
			if not hit.is_empty():
				path.append(hit)
				return path
			if with_homes and seen.size() > SEARCH_MOST:
				unsure = true
				return []
			queue.append([nc, nh, path])
	return []

## A position's name. Columns with no card face down under them are one as
## good as another, so they are named in order and a rearranging that only
## swaps two of them is not looked at twice.
func _key(cs: Array, hs: Array) -> String:
	var open := []
	var key := ""
	for c in COLS:
		if int(down[c]) == 0:
			open.append(str(cs[c]))
		else:
			key += str(cs[c])
	open.sort()
	return key + "/" + "".join(open) + str(hs)

## A move from this position that gets somewhere, or {}.
func _progress(cs: Array, hs: Array, total: int) -> Dictionary:
	# a card turned up
	for c in COLS:
		var d: int = down[c]
		var pile: Array = cs[c]
		if d > 0 and pile.size() > d:
			var head: int = pile[d]
			for to in COLS:
				if to != c and fits(head, cs[to]):
					return {"card": head, "kind": At.COL, "i": to}
	# a card home, past where the homes stood
	if int(hs[0]) + int(hs[1]) + int(hs[2]) + int(hs[3]) == total:
		for c in COLS:
			var pile: Array = cs[c]
			if not pile.is_empty():
				var top: int = pile[pile.size() - 1]
				if rank_of(top) == int(hs[suit_of(top)]):
					return {"card": top, "kind": At.HOME, "i": suit_of(top)}
	# a card off the stock: the waste's top first, as it needs no turning
	for k in range(waste.size() - 1, -1, -1):
		var m := _stock_play(int(waste[k]), cs, hs)
		if not m.is_empty():
			return m
	for k in range(stock.size() - 1, -1, -1):
		var m := _stock_play(int(stock[k]), cs, hs)
		if not m.is_empty():
			return m
	return {}

func _stock_play(card: int, cs: Array, hs: Array) -> Dictionary:
	if rank_of(card) == int(hs[suit_of(card)]):
		return {"card": card, "kind": At.HOME, "i": suit_of(card)}
	for to in COLS:
		if fits(card, cs[to]):
			return {"card": card, "kind": At.COL, "i": to}
	return {}

## The moves that only rearrange: a run from one column to another with no
## card turned by it, a home's top card brought down, and a card put back
## home while the homes are under where they stood.
func _shuffles(cs: Array, hs: Array, total: int, with_homes: bool) -> Array:
	var out := []
	for c in COLS:
		var pile: Array = cs[c]
		var d: int = down[c]
		for idx in range(d, pile.size()):
			if idx == d and d > 0:
				continue
			var head: int = pile[idx]
			for to in COLS:
				if to == c or not fits(head, cs[to]):
					continue
				if (cs[to] as Array).is_empty() and idx == 0:
					continue
				out.append({"card": head, "kind": At.COL, "i": to})
	if not with_homes:
		return out
	var under := int(hs[0]) + int(hs[1]) + int(hs[2]) + int(hs[3]) < total
	if under:
		for c in COLS:
			var pile: Array = cs[c]
			if not pile.is_empty():
				var top: int = pile[pile.size() - 1]
				if rank_of(top) == int(hs[suit_of(top)]):
					out.append({"card": top, "kind": At.HOME, "i": suit_of(top)})
	for s in SUITS:
		if int(hs[s]) > 0:
			var card := s * RANKS + int(hs[s]) - 1
			for to in COLS:
				if fits(card, cs[to]):
					out.append({"card": card, "kind": At.COL, "i": to})
	return out

func _apply_light(cs: Array, hs: Array, mv: Dictionary) -> void:
	var card: int = mv.card
	var cards := [card]
	var found := false
	for c in COLS:
		var i: int = (cs[c] as Array).find(card)
		if i >= 0:
			cards = (cs[c] as Array).slice(i)
			(cs[c] as Array).resize(i)
			found = true
			break
	if not found:
		hs[suit_of(card)] = int(hs[suit_of(card)]) - 1
	if int(mv.kind) == At.HOME:
		hs[int(mv.i)] = int(hs[int(mv.i)]) + 1
	else:
		(cs[int(mv.i)] as Array).append_array(cards)

# --- the ends ---

## The run ended by hand, with the deal not out: what Finish does.
func finish() -> void:
	if phase != Phase.PLAY:
		return
	phase = Phase.OVER
	sweeping = false
	events.append({"type": "over"})

## The Second chance: every card still face down and the whole stock are
## shuffled and laid back in the same places, until there is a way on.
func revive() -> void:
	var pool := []
	for c in COLS:
		for k in int(down[c]):
			pool.append(cols[c][k])
	pool.append_array(stock)
	pool.append_array(waste)
	phase = Phase.PLAY
	waste = []
	_undo.clear()
	_rng.seed = seed_used + 7919 * (moves + 1)
	for attempt in REVIVE_TRIES:
		_shuffle(pool)
		var at := 0
		for c in COLS:
			for k in int(down[c]):
				cols[c][k] = pool[at]
				at += 1
		stock = pool.slice(at)
		_replan()
		if not _plan.is_empty():
			break
	stuck = _plan.is_empty()
	events.append({"type": "revive"})
	if stuck:
		events.append({"type": "stuck"})
