extends RefCounted

## The computer's chess: alpha-beta over versus/chess_rules.gd with a
## capture-only quiescence search, a transposition table for move order,
## killer moves, a check extension and iterative deepening inside a time
## budget. The evaluation is material and the simplified piece-square tables
## (Michniewski's), a king table that turns central in the endgame, a bishop
## pair, and a mop-up term so a won ending is actually won.
##
## The levels differ in how far it looks and how much it wobbles: Easy looks
## one move ahead (plus the captures after it) and blurs every score by about
## a pawn, Medium two with a third of a pawn, Hard as deep as the budget
## allows with none. The hint is Hard for the player on a shorter budget.
##
## Runs on a worker thread against a copy of the game (the screen's
## _think); nothing here touches the scene tree.
##
##     AI.new().plan(game.copy(), level, seed)

const Rules = preload("res://versus/chess_rules.gd")

const MATE := 100000
const INF := 1000000
const VALUE := [0, 100, 320, 330, 500, 900, 0]
const DEPTH := [1, 2, 6]
const NOISE := [110.0, 35.0, 0.0]
const BUDGET_MS := [500, 900, 1600]
const HINT_BUDGET_MS := 1100

const EXACT := 0
const LOWER := 1
const UPPER := 2

# The tables as printed, rank 8 first, from white's side.
const _P := [
	0, 0, 0, 0, 0, 0, 0, 0,
	50, 50, 50, 50, 50, 50, 50, 50,
	10, 10, 20, 30, 30, 20, 10, 10,
	5, 5, 10, 25, 25, 10, 5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, -5, -10, 0, 0, -10, -5, 5,
	5, 10, 10, -20, -20, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0]
const _N := [
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50]
const _B := [
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-20, -10, -10, -10, -10, -10, -10, -20]
const _R := [
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, 10, 10, 10, 10, 5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	0, 0, 0, 5, 5, 0, 0, 0]
const _Q := [
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-5, 0, 5, 5, 5, 5, 0, -5,
	0, 0, 5, 5, 5, 5, 0, -5,
	-10, 5, 5, 5, 5, 5, 0, -10,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20]
const _K_MID := [
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	20, 20, 0, 0, 0, 0, 20, 20,
	20, 30, 10, 0, 0, 10, 30, 20]
const _K_END := [
	-50, -40, -30, -20, -20, -30, -40, -50,
	-30, -20, -10, 0, 0, -10, -20, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 30, 40, 40, 30, -10, -30,
	-30, -10, 20, 30, 30, 20, -10, -30,
	-30, -30, 0, 0, 0, 0, -30, -30,
	-50, -30, -30, -30, -30, -30, -30, -50]

## PST[type][sq] for a white piece, material included; a black piece reads
## sq ^ 56 (the same square seen from its own side).
static var PST: Array = []
static var K_MID := PackedInt32Array()
static var K_END := PackedInt32Array()

static func _static_init() -> void:
	PST = [PackedInt32Array()]
	var tables := [_P, _N, _B, _R, _Q]
	for t in 5:
		PST.append(_by_square(tables[t], VALUE[t + 1]))
	K_MID = _by_square(_K_MID, 0)
	K_END = _by_square(_K_END, 0)
	PST.append(K_MID)

static func _by_square(table: Array, worth: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(64)
	for sq in 64:
		out[sq] = worth + int(table[(7 - (sq >> 3)) * 8 + (sq & 7)])
	return out

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
## in place). -1 when there is none.
func plan(game: RefCounted, level: int, seed: int, budget_ms := -1) -> int:
	g = game
	rng.seed = seed
	killers.resize(128)
	killers.fill(0)
	var moves: PackedInt32Array = g.legal_moves()
	if moves.is_empty():
		return -1
	if moves.size() == 1:
		return moves[0]
	var lv := clampi(level, 0, 2)
	deadline = Time.get_ticks_msec() + (budget_ms if budget_ms > 0 else BUDGET_MS[lv])
	if NOISE[lv] > 0.0:
		return _blurred(moves, DEPTH[lv], NOISE[lv])
	return _deepening(moves, DEPTH[lv])

## Easy and Medium: every root move scored exactly at a fixed depth, each
## blurred, the best blurred score played. A mate is never blurred away.
func _blurred(moves: PackedInt32Array, depth: int, noise: float) -> int:
	var best := moves[0]
	var best_score := -INF * 1.0
	for m in moves:
		g.make(m)
		var sc := -_search(depth - 1, -INF, INF, 1)
		g.unmake()
		var blurred := float(sc)
		if absi(sc) < MATE - 1000:
			blurred += rng.randfn(0.0, noise)
		if blurred > best_score:
			best_score = blurred
			best = m
	return best

## Hard: iterative deepening, the root re-ordered by the last full depth,
## ties broken by a shuffle so it does not play one opening for ever.
func _deepening(moves: PackedInt32Array, max_depth: int) -> int:
	var order: Array = Array(moves)
	order.shuffle()
	var best: int = order[0]
	for depth in range(1, max_depth + 1):
		var alpha := -INF
		var scores := {}
		var round_best := -1
		for m: int in order:
			g.make(m)
			var sc := -_search(depth - 1, -INF, -alpha, 1)
			g.unmake()
			if stopped:
				break
			scores[m] = sc
			if sc > alpha:
				alpha = sc
				round_best = m
		if round_best != -1 and (not stopped or scores.has(order[0])):
			# A move that beat the old best inside an unfinished round has
			# been searched to this depth, so it stands.
			best = round_best
		if stopped:
			break
		reached = depth
		score = alpha
		order.sort_custom(func(a: int, b: int) -> bool: return scores.get(a, -INF) > scores.get(b, -INF))
		# A move that failed low can tie the best on its bound; the best goes
		# first regardless, since an unfinished round trusts only what beat it.
		order.erase(best)
		order.push_front(best)
		if alpha >= MATE - 100:
			break
	return best

func _clock() -> void:
	nodes += 1
	if (nodes & 511) == 0 and Time.get_ticks_msec() > deadline:
		stopped = true

func _search(depth: int, alpha: int, beta: int, ply: int) -> int:
	if g.halfmove >= 100 or g.repeats(2):
		return 0
	var check: bool = g.in_check()
	if check and ply < 24:
		depth += 1
	if depth <= 0:
		return _quiesce(alpha, beta, ply)
	_clock()
	if stopped:
		return 0
	var key: int = g.hash
	var tt_move := 0
	var entry = tt.get(key)
	if entry != null:
		tt_move = entry[3]
		var sc: int = entry[1]
		if entry[0] >= depth and absi(sc) < MATE - 1000:
			match int(entry[2]):
				EXACT:
					return sc
				LOWER:
					if sc >= beta:
						return sc
				UPPER:
					if sc <= alpha:
						return sc
	var moves: PackedInt32Array = g.pseudo()
	var keys := _order_keys(moves, tt_move, ply)
	var best := -INF
	var best_move := 0
	var legal := 0
	var a0 := alpha
	var mover: int = g.turn
	for i in moves.size():
		var m := _pick(moves, keys, i)
		g.make(m)
		if g.attacked(g.kings[mover], g.turn):
			g.unmake()
			continue
		legal += 1
		var sc := -_search(depth - 1, -beta, -alpha, ply + 1)
		g.unmake()
		if stopped:
			return 0
		if sc > best:
			best = sc
			best_move = m
		if sc > alpha:
			alpha = sc
		if alpha >= beta:
			if not (Rules.mv_flags(m) & Rules.F_CAPTURE) and ply < 128:
				killers[ply] = m
			break
	if legal == 0:
		return -MATE + ply if check else 0
	var flag := EXACT
	if best <= a0:
		flag = UPPER
	elif best >= beta:
		flag = LOWER
	tt[key] = [depth, best, flag, best_move]
	return best

func _quiesce(alpha: int, beta: int, ply: int) -> int:
	_clock()
	if stopped:
		return 0
	var stand := evaluate()
	if stand >= beta:
		return stand
	if stand > alpha:
		alpha = stand
	if ply > 40:
		return stand
	var moves: PackedInt32Array = g.pseudo(true)
	var keys := _order_keys(moves, 0, ply)
	var mover: int = g.turn
	for i in moves.size():
		var m := _pick(moves, keys, i)
		g.make(m)
		if g.attacked(g.kings[mover], g.turn):
			g.unmake()
			continue
		var sc := -_quiesce(-beta, -alpha, ply + 1)
		g.unmake()
		if stopped:
			return 0
		if sc >= beta:
			return sc
		if sc > alpha:
			alpha = sc
	return alpha

## Move order: the table's move, then captures most valuable victim first
## by least valuable attacker, promotions, the killer, the rest.
func _order_keys(moves: PackedInt32Array, tt_move: int, ply: int) -> PackedInt32Array:
	var keys := PackedInt32Array()
	keys.resize(moves.size())
	var killer := killers[ply] if ply < 128 else 0
	var b: PackedInt32Array = g.board
	for i in moves.size():
		var m := moves[i]
		var k := 0
		if m == tt_move:
			k = 1000000
		else:
			var flags := m >> 16
			if flags & Rules.F_CAPTURE:
				var victim := absi(b[(m >> 6) & 63])
				if victim == 0:
					victim = Rules.PAWN
				k = 10000 + victim * 100 - absi(b[m & 63])
			if flags & Rules.F_PROMO:
				k += 9000 + ((m >> 12) & 7)
			if k == 0 and m == killer:
				k = 5000
		keys[i] = k
	return keys

## Selection sort, lazily: most cutoffs come early, so most of the list is
## never sorted at all.
static func _pick(moves: PackedInt32Array, keys: PackedInt32Array, i: int) -> int:
	var best := i
	for j in range(i + 1, moves.size()):
		if keys[j] > keys[best]:
			best = j
	if best != i:
		var m := moves[i]
		moves[i] = moves[best]
		moves[best] = m
		var k := keys[i]
		keys[i] = keys[best]
		keys[best] = k
	return moves[i]

## The position from the side to move's point of view, in centipawns.
func evaluate() -> int:
	var b: PackedInt32Array = g.board
	var score := 0
	var heavy := 0
	var mat := [0, 0]
	var bishops := [0, 0]
	for sq in 64:
		var p := b[sq]
		if p == 0:
			continue
		if p > 0:
			if p != Rules.KING:
				score += PST[p][sq]
				mat[0] += VALUE[p]
				if p != Rules.PAWN:
					heavy += VALUE[p]
				if p == Rules.BISHOP:
					bishops[0] += 1
		else:
			var t := -p
			if t != Rules.KING:
				score -= PST[t][sq ^ 56]
				mat[1] += VALUE[t]
				if t != Rules.PAWN:
					heavy += VALUE[t]
				if t == Rules.BISHOP:
					bishops[1] += 1
	var kw: int = g.kings[0]
	var kb: int = g.kings[1]
	var endgame := heavy <= 2600
	if endgame:
		score += K_END[kw] - K_END[kb ^ 56]
	else:
		score += K_MID[kw] - K_MID[kb ^ 56]
	if bishops[0] >= 2:
		score += 30
	if bishops[1] >= 2:
		score -= 30
	# Mop-up: the side well ahead drives the lone king to the edge and walks
	# its own king up to it, or a won ending is shuffled for ever.
	var diff: int = mat[0] - mat[1]
	if endgame and absi(diff) >= 400:
		var loser := kb if diff > 0 else kw
		var lf := loser & 7
		var lr := loser >> 3
		var centre := maxi(3 - lf, lf - 4) + maxi(3 - lr, lr - 4)
		var near := absi((kw & 7) - (kb & 7)) + absi((kw >> 3) - (kb >> 3))
		var mop := centre * 10 + (14 - near) * 4
		score += mop if diff > 0 else -mop
	return score if g.turn == Rules.WHITE else -score
