extends RefCounted

## The computer's checkers: alpha-beta over versus/checkers_rules.gd with a
## transposition table for move order, killer moves, iterative deepening in
## a time budget, and captures searched past the horizon (a capture is
## forced, so there is no standing pat on one) and forced moves not
## counted against the depth.
##
## The evaluation is material (a flying king is worth three men, a stepping
## one not quite two), men walking forward, a guarded back row, the centre,
## kings on the long diagonal once the board has thinned, trading down when
## ahead, and in a kings' ending the stronger side closing in.
##
## The levels differ in how far it looks and how much it wobbles: Easy two
## plies with a blur of most of a man, Medium four with a fifth of one, Hard
## as deep as the budget allows with none. The hint is Hard for the player
## on a shorter budget. Runs on a worker thread against a copy of the game;
## nothing here touches the scene tree.
##
##     AI.new().plan(game.copy(), level, seed)

const Rules = preload("res://versus/checkers_rules.gd")

const WIN := 100000
const INF := 1000000
const DEPTH := [2, 4, 16]
const NOISE := [70.0, 22.0, 0.0]
const BUDGET_MS := [400, 800, 1500]
const HINT_BUDGET_MS := 1100
const MAN_V := 100
const KING_FLY := 320
const KING_STEP := 170
## A man's worth by how far it has come (rows from its own back row).
const ADVANCE := [0, 2, 4, 7, 11, 17, 24, 0]
const MAX_PLY := 48

const EXACT := 0
const LOWER := 1
const UPPER := 2

## The dark squares, the only ones worth looking at.
static var DARK := PackedInt32Array()
## The long diagonal, a1 to h8.
static var LONG := {}

static func _static_init() -> void:
	for sq in 64:
		if Rules.is_dark(sq):
			DARK.append(sq)
	for i in 8:
		LONG[i * 9] = true

var g: RefCounted
var nodes := 0
var deadline := 0
var stopped := false
var tt := {}
var killers := PackedInt32Array()
var rng := RandomNumberGenerator.new()
## What the last plan saw, for the probes: the depth finished and its score.
var reached := 0
var score := 0

## The move to play for the side to move in `game` (a copy: it is searched
## in place). Empty when there is none.
func plan(game: RefCounted, level: int, seed: int, budget_ms := -1) -> PackedInt32Array:
	g = game
	rng.seed = seed
	nodes = 0
	stopped = false
	reached = 0
	tt.clear()
	killers.resize(MAX_PLY * 2 + 8)
	killers.fill(-1)
	var moves: Array = g.legal_moves()
	if moves.is_empty():
		return PackedInt32Array()
	if moves.size() == 1:
		return moves[0]
	level = clampi(level, 0, 2)
	var budget: int = BUDGET_MS[level] if budget_ms < 0 else budget_ms
	deadline = Time.get_ticks_msec() + budget
	# shuffled so equal moves are not always played the same way
	for i in range(moves.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: PackedInt32Array = moves[i]
		moves[i] = moves[j]
		moves[j] = t
	var noise: float = NOISE[level]
	var best: PackedInt32Array = moves[0]
	for depth in range(1, int(DEPTH[level]) + 1):
		var alpha := -INF
		var round_best: PackedInt32Array = best
		var round_score := -INF
		var round_noisy := -INF
		var complete := true
		for m: PackedInt32Array in moves:
			g.make(m)
			# with a blur every root move needs its true score, so no window
			var v := -_search(depth - 1, -INF, INF if noise > 0.0 else -alpha, 1)
			g.unmake()
			if stopped:
				complete = false
				break
			var noisy := v + (rng.randfn(0.0, noise) if noise > 0.0 else 0.0)
			if noisy > round_noisy:
				round_noisy = noisy
				round_best = m
				round_score = v
			alpha = maxi(alpha, v)
		if not complete:
			break
		best = round_best
		score = round_score
		reached = depth
		# the proven best leads the next round
		moves.erase(best)
		moves.push_front(best)
		if absi(score) > WIN - 200:
			break
	return best

func _search(depth: int, alpha: int, beta: int, ply: int) -> int:
	nodes += 1
	if (nodes & 511) == 0 and Time.get_ticks_msec() > deadline:
		stopped = true
	if stopped:
		return 0
	if g.quiet >= Rules.QUIET_PLIES or g.repeats() >= 2:
		return 0
	var moves: Array = g.legal_moves()
	if moves.is_empty():
		return -WIN + ply
	var capturing := Rules.mv_ncaps(moves[0]) > 0
	if (depth <= 0 and not capturing) or ply >= MAX_PLY:
		return evaluate()
	var alpha0 := alpha
	var entry: Array = tt.get(g.hash, [])
	var tt_key := -1
	if not entry.is_empty():
		tt_key = entry[3]
		if entry[0] >= depth:
			var v: int = entry[2]
			match entry[1]:
				EXACT:
					return v
				LOWER:
					alpha = maxi(alpha, v)
				UPPER:
					beta = mini(beta, v)
			if alpha >= beta:
				return v
	# forced moves do not cost depth
	var next := depth if moves.size() == 1 else depth - 1
	_order(moves, tt_key, ply)
	var best := -INF
	var best_key := -1
	for m: PackedInt32Array in moves:
		g.make(m)
		var v := -_search(next, -beta, -alpha, ply + 1)
		g.unmake()
		if stopped:
			return 0
		if v > best:
			best = v
			best_key = Rules.mv_key(m)
		if v > alpha:
			alpha = v
		if alpha >= beta:
			if not capturing:
				killers[ply] = Rules.mv_key(m)
			break
	if tt.size() > 400000:
		tt.clear()
	var flag := EXACT
	if best <= alpha0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	# a win's score depends on the ply it was found at; keep it for order only
	if absi(best) < WIN - 200:
		tt[g.hash] = [depth, flag, best, best_key]
	else:
		tt[g.hash] = [-1, flag, best, best_key]
	return best

func _order(moves: Array, tt_key: int, ply: int) -> void:
	var killer := killers[ply]
	var keyed: Array = []
	for m: PackedInt32Array in moves:
		var k := Rules.mv_key(m)
		var s := Rules.mv_ncaps(m) * 10
		if k == tt_key:
			s += 10000
		elif k == killer:
			s += 500
		keyed.append([s, m])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for i in moves.size():
		moves[i] = keyed[i][1]

## The position from the side to move's point of view.
func evaluate() -> int:
	var board: PackedInt32Array = g.board
	var king_v := KING_FLY if g.flying else KING_STEP
	var mat := [0, 0]
	var pieces := [0, 0]
	var kings := [0, 0]
	var s := 0
	for sq in DARK:
		var p := board[sq]
		if p == 0:
			continue
		var side := 0 if p > 0 else 1
		var r := sq >> 3
		var f := sq & 7
		var v := 0
		var central := f >= 2 and f <= 5 and r >= 2 and r <= 5
		if absi(p) == Rules.MAN:
			var adv := r if side == 0 else 7 - r
			v = MAN_V + ADVANCE[adv]
			if adv == 0:
				v += 6
			if central:
				v += 4
			# the edges are safe but slow
			if f == 0 or f == 7:
				v -= 2
		else:
			v = king_v
			kings[side] += 1
			if central:
				v += 4
		mat[side] += v
		pieces[side] += 1
		s += v if side == 0 else -v
	var total: int = pieces[0] + pieces[1]
	# the long diagonal once the board has thinned
	if total <= 10:
		for sq: int in LONG:
			var p := board[sq]
			if absi(p) == Rules.KING:
				s += 18 if p > 0 else -18
	# ahead: trade down
	var diff: int = mat[0] - mat[1]
	s += int(diff * 0.25 * (24 - total) / 24.0)
	# a kings' ending: the stronger side closes in
	if total <= 8 and absi(diff) >= 60:
		var strong := 0 if diff > 0 else 1
		var ss := Rules.sign_of(strong)
		var near := 0
		for a in DARK:
			if board[a] * ss > 0 and absi(board[a]) == Rules.KING:
				for b in DARK:
					if board[b] * ss < 0:
						near += 7 - maxi(absi((a & 7) - (b & 7)), absi((a >> 3) - (b >> 3)))
		s += (near * 3) * (1 if strong == 0 else -1)
	return s if g.turn == Rules.LIGHT else -s
