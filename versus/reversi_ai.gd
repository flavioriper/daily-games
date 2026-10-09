extends RefCounted

## The computer at Reversi. It copies the board into an array of its own and
## searches: negamax with alpha-beta, the squares worth most tried first,
## deepening a ply at a time inside a budget. A position it cannot see the end
## of is scored by where the discs lie (a corner is worth a great deal, the
## squares that give one away cost), by how many squares each side could play
## and, late on, by the count. With few squares left the top level plays the
## game out and takes the best count.
##
## The levels are how far it looks and how sure its eye is:
##   0  one ply and a heavy blur, and now and then any square at all
##   1  three plies and a light blur
##   2  as deep as the budget allows, up to DEPTH_MAX, no blur, the last
##      SOLVE_AT squares played out exactly
##
## `plan` is safe on a worker thread: it touches nothing but the copy it is
## given (versus/reversi_screen.gd's _think).

const Rules = preload("res://versus/reversi_rules.gd")

const W := Rules.W
const CELLS := Rules.CELLS
const WIN := 50000
const DEPTH := [1, 3, 8]
const BLUR := [60.0, 10.0, 0.0]
## How often the easy level sets its disc on any square it may.
const WILD := 0.3
const BUDGET_MS := 420
const HINT_BUDGET_MS := 300
const DEPTH_MAX := 8
const SOLVE_AT := 9
## What a disc is worth where it lies.
const WEIGHT := [
	120, -20, 20, 5, 5, 20, -20, 120,
	-20, -45, -5, -5, -5, -5, -45, -20,
	20, -5, 15, 3, 3, 15, -5, 20,
	5, -5, 3, 3, 3, 3, -5, 5,
	5, -5, 3, 3, 3, 3, -5, 5,
	20, -5, 15, 3, 3, 15, -5, 20,
	-20, -45, -5, -5, -5, -5, -45, -20,
	120, -20, 20, 5, 5, 20, -20, 120,
]
## Each corner and the three squares beside it, which stop being a gift once
## the corner is held.
const CORNERS := [[0, 1, 8, 9], [7, 6, 15, 14], [56, 57, 48, 49], [63, 62, 55, 54]]
const MOBILITY := 9

var _b := PackedByteArray()
var _rays: Array = []
var _order := PackedInt32Array()
var _nodes := 0
var _stop_at := 0
var _stopped := false

func _init() -> void:
	_rays = Rules.rays()
	var cells := range(CELLS)
	cells.sort_custom(func(a: int, b: int) -> bool: return WEIGHT[a] > WEIGHT[b] if WEIGHT[a] != WEIGHT[b] else a < b)
	_order = PackedInt32Array(cells)

## The cell to play for the side to move in `rules`, -1 when there is none.
func plan(rules: RefCounted, level: int, rng_seed: int, budget_ms := -1) -> int:
	var moves: PackedInt32Array = rules.legal_moves()
	if moves.is_empty():
		return -1
	if moves.size() == 1:
		return moves[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if level == 0 and rng.randf() < WILD:
		return moves[rng.randi() % moves.size()]
	_b = rules.cells.duplicate()
	var side: int = rules.turn
	var empties := _b.count(Rules.EMPTY)
	_stop_at = Time.get_ticks_msec() + (BUDGET_MS if budget_ms < 0 else budget_ms)
	if level < 2:
		return _root(side, DEPTH[level], BLUR[level], rng)
	# The top level: a ply deeper each round, keeping the last round finished;
	# near the end, the whole game.
	var best := _root(side, 2, 0.0, rng)
	var depth := 3
	var top := empties if empties <= SOLVE_AT else mini(DEPTH_MAX, empties)
	while depth <= top:
		var found := _root(side, depth, 0.0, rng)
		if _stopped:
			break
		best = found
		depth += 1
	return best

## The best cell at `depth`, each move's score blurred by up to `blur`.
func _root(side: int, depth: int, blur: float, rng: RandomNumberGenerator) -> int:
	_stopped = false
	var best := -1
	var best_score := -INF
	var alpha := -WIN * 2
	for c in _order:
		if _b[c] != Rules.EMPTY:
			continue
		var turned := _flips(c, side)
		if turned.is_empty():
			continue
		_put(c, turned, side)
		# With a blur every move needs its true score, so the window stays
		# open; without one the best so far narrows it.
		var score := float(-_search(1 - side, depth - 1, -WIN * 2, -alpha if blur == 0.0 else WIN * 2, false))
		_take(c, turned, side)
		if _stopped:
			return best if best >= 0 else c
		if blur > 0.0 and absf(score) < WIN * 0.5:
			score += rng.randf_range(-blur, blur)
		if score > best_score:
			best_score = score
			best = c
			if blur == 0.0:
				alpha = maxi(alpha, int(score))
	return best

## Negamax for `side` to move: how good the position is for it. `skipped`
## says the other side has just passed.
func _search(side: int, depth: int, alpha: int, beta: int, skipped: bool) -> int:
	_nodes += 1
	if _nodes & 1023 == 0 and Time.get_ticks_msec() > _stop_at:
		_stopped = true
	if _stopped:
		return 0
	if depth <= 0:
		return _score(side)
	var any := false
	for c in _order:
		if _b[c] != Rules.EMPTY:
			continue
		var turned := _flips(c, side)
		if turned.is_empty():
			continue
		any = true
		_put(c, turned, side)
		var score := -_search(1 - side, depth - 1, -beta, -alpha, false)
		_take(c, turned, side)
		if score >= beta:
			return score
		if score > alpha:
			alpha = score
	if any:
		return alpha
	if skipped:
		# Neither side has a square: the count decides.
		var d := _b.count(side + 1) - _b.count(2 - side)
		return 0 if d == 0 else (WIN + d * 100 if d > 0 else -WIN + d * 100)
	return -_search(1 - side, depth, -beta, -alpha, true)

func _flips(c: int, side: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var mine := side + 1
	var theirs := 2 - side
	for ray: PackedInt32Array in _rays[c]:
		var n := 0
		for q in ray:
			var v := _b[q]
			if v == theirs:
				n += 1
				continue
			if v == mine:
				for i in n:
					out.append(ray[i])
			break
	return out

func _put(c: int, turned: PackedInt32Array, side: int) -> void:
	_b[c] = side + 1
	for q in turned:
		_b[q] = side + 1

func _take(c: int, turned: PackedInt32Array, side: int) -> void:
	_b[c] = Rules.EMPTY
	for q in turned:
		_b[q] = 2 - side

## A quiet position's worth to `side`: where the discs lie, the squares each
## side could play, and the count once the board is nearly full.
func _score(side: int) -> int:
	var mine := side + 1
	var total := 0
	var discs := 0
	var filled := 0
	for c in CELLS:
		var v := _b[c]
		if v == Rules.EMPTY:
			continue
		filled += 1
		if v == mine:
			total += WEIGHT[c]
			discs += 1
		else:
			total -= WEIGHT[c]
			discs -= 1
	for k: Array in CORNERS:
		var v := _b[k[0]]
		if v == Rules.EMPTY:
			continue
		# The squares beside a corner held are safe, and good for its holder.
		for i in range(1, 4):
			var q := _b[k[i]]
			if q == Rules.EMPTY:
				continue
			var fix: int = 30 - WEIGHT[k[i]] if q == v else 0
			total += fix if q == mine else -fix
	total += MOBILITY * (_mobility(side) - _mobility(1 - side))
	if filled > 48:
		total += discs * (filled - 48)
	return total

func _mobility(side: int) -> int:
	var n := 0
	var mine := side + 1
	var theirs := 2 - side
	for c in CELLS:
		if _b[c] != Rules.EMPTY:
			continue
		for ray: PackedInt32Array in _rays[c]:
			if ray.is_empty() or _b[ray[0]] != theirs:
				continue
			var found := false
			for q in ray:
				var v := _b[q]
				if v == theirs:
					continue
				found = v == mine
				break
			if found:
				n += 1
				break
	return n
