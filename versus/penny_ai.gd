extends RefCounted

## The computer at Penny Drop. It reads the rack into two 49-bit boards (a
## column is seven bits, the seventh a spare above the top row, so a shift
## never runs one column into the next) and searches: negamax with alpha-beta,
## the middle columns tried first, deepening a ply at a time inside a budget.
## A position it cannot see the end of is scored by the places each side
## would win at were a penny to reach them.
##
## The levels are how far it looks and how sure its eye is:
##   0  two plies and a heavy blur; it misses a win or a block now and then
##   1  four plies and a light blur
##   2  as deep as the budget allows, up to DEPTH_MAX, no blur
## The game is a win for the side that drops first when played perfectly, and
## the top level is nowhere near perfect: a person who plans can beat it.
##
## `plan` is safe on a worker thread: it touches nothing but the copy it is
## given (versus/penny_screen.gd's _think).

const Rules = preload("res://versus/penny_rules.gd")

const W := Rules.W
const H := Rules.H
const H1 := H + 1
const WIN := 100000
const ORDER := [3, 2, 4, 1, 5, 0, 6]
const DEPTH := [2, 4, 10]
const BLUR := [26.0, 5.0, 0.0]
## How often the easy level does not see a win it has, or a line it must stop.
const MISS_WIN := 0.25
const MISS_BLOCK := 0.4
const BUDGET_MS := 420
const HINT_BUDGET_MS := 300
const DEPTH_MAX := 10

var _bottom := 0
var _board := 0
var _nodes := 0
var _stop_at := 0
var _stopped := false

func _init() -> void:
	for c in W:
		_bottom |= 1 << (c * H1)
	_board = _bottom * ((1 << H) - 1)

## The column to play for the side to move in `rules`, -1 when there is none.
func plan(rules: RefCounted, level: int, rng_seed: int, budget_ms := -1) -> int:
	var moves: PackedInt32Array = rules.legal_moves()
	if moves.is_empty():
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var cur := 0
	var mask := 0
	for col in W:
		for row in H:
			var v: int = rules.at(col, row)
			if v == Rules.EMPTY:
				continue
			var bit := 1 << (col * H1 + row)
			mask |= bit
			if v - 1 == rules.turn:
				cur |= bit
	# A win in hand, then a line that must be stopped: the easy level may
	# look past either.
	var mine := _winning(cur, mask) & _possible(mask)
	var theirs := _winning(cur ^ mask, mask) & _possible(mask)
	if mine != 0 and (level > 0 or rng.randf() >= MISS_WIN):
		return _col_of(mine, rng)
	if mine == 0 and theirs != 0 and (level > 0 or rng.randf() >= MISS_BLOCK):
		return _col_of(theirs, rng)
	_stop_at = Time.get_ticks_msec() + (BUDGET_MS if budget_ms < 0 else budget_ms)
	if level < 2:
		return _root(cur, mask, DEPTH[level], BLUR[level], rng)
	# The top level: a ply deeper each round, keeping the last round finished.
	var best := _root(cur, mask, 2, 0.0, rng)
	var depth := 3
	while depth <= mini(DEPTH_MAX, Rules.CELLS - int(rules.ply)):
		var found := _root(cur, mask, depth, 0.0, rng)
		if _stopped:
			break
		best = found
		depth += 1
	return best

## One of the columns holding a bit of `cells`, the middle ones first.
func _col_of(cells: int, rng: RandomNumberGenerator) -> int:
	var cols: Array[int] = []
	for c: int in ORDER:
		if cells & (((1 << H) - 1) << (c * H1)) != 0:
			cols.append(c)
	return cols[0] if cols.size() == 1 else cols[rng.randi() % cols.size()]

## The best column at `depth`, each move's score blurred by up to `blur`.
func _root(cur: int, mask: int, depth: int, blur: float, rng: RandomNumberGenerator) -> int:
	_stopped = false
	var best := -1
	var best_score := -INF
	var alpha := -WIN * 2
	for c: int in ORDER:
		if mask & (1 << (H - 1 + c * H1)) != 0:
			continue
		var next_mask := mask | (mask + (1 << (c * H1)))
		# With a blur every move needs its true score, so the window stays
		# open; without one the best so far narrows it.
		var score := float(-_search(cur ^ mask, next_mask, depth - 1, -WIN * 2, -alpha if blur == 0.0 else WIN * 2, 1))
		if _stopped:
			return best if best >= 0 else c
		if blur > 0.0 and absf(score) < WIN * 0.5:
			score += rng.randf_range(-blur, blur)
		# A tie goes to the column nearer the middle, tried first.
		if score > best_score:
			best_score = score
			best = c
			if blur == 0.0:
				alpha = maxi(alpha, int(score))
	return best

## Negamax for the side to move (`cur` its pennies): how good the position is
## for it, a win sooner worth more than a win later.
func _search(cur: int, mask: int, depth: int, alpha: int, beta: int, ply: int) -> int:
	_nodes += 1
	if _nodes & 1023 == 0 and Time.get_ticks_msec() > _stop_at:
		_stopped = true
	if _stopped:
		return 0
	var open := _possible(mask)
	if open == 0:
		return 0
	if _winning(cur, mask) & open != 0:
		return WIN - ply
	var theirs := _winning(cur ^ mask, mask)
	var forced := theirs & open
	if forced != 0:
		# Two lines to stop and one penny: lost next turn.
		if forced & (forced - 1) != 0:
			return -(WIN - ply - 1)
		open = forced
	if depth <= 0:
		return _score(cur, mask)
	for c: int in ORDER:
		var col := ((1 << H) - 1) << (c * H1)
		if open & col == 0:
			continue
		var score := -_search(cur ^ mask, mask | (mask + (1 << (c * H1))), depth - 1, -beta, -alpha, ply + 1)
		if score >= beta:
			return score
		if score > alpha:
			alpha = score
	return alpha

## A quiet position's worth to the side to move: the empty places that would
## finish a line of its own, less the other side's, and a little for holding
## the middle column.
func _score(cur: int, mask: int) -> int:
	var other := cur ^ mask
	var mid := ((1 << H) - 1) << (3 * H1)
	return 4 * (_count(_winning(cur, mask)) - _count(_winning(other, mask))) \
		+ _count(cur & mid) - _count(other & mid)

static func _count(bits: int) -> int:
	var n := 0
	while bits != 0:
		bits &= bits - 1
		n += 1
	return n

## The lowest free place of every column that has one.
func _possible(mask: int) -> int:
	return (mask + _bottom) & _board

## Every empty place where one more penny would give `pos` four in a line.
func _winning(pos: int, mask: int) -> int:
	# up a column
	var r := (pos << 1) & (pos << 2) & (pos << 3)
	# across, then the two slants: the same pattern at three strides
	for s: int in [H1, H, H + 2]:
		var p := (pos << s) & (pos << (2 * s))
		r |= p & (pos << (3 * s))
		r |= p & (pos >> s)
		p = (pos >> s) & (pos >> (2 * s))
		r |= p & (pos << s)
		r |= p & (pos >> (3 * s))
	return r & (_board ^ mask)
