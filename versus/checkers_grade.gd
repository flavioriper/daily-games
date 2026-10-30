extends "res://versus/chess_grade.gd"

## How good a checkers move was: chess's verdicts and accuracy on checkers'
## rules. Its own parts: a man is far more of the game than a pawn, so the
## chance of winning climbs faster; a move with no choice is not judged; and
## a brilliancy is a shot, a move that hands over pieces the other side must
## take, for more coming back. Pure: runs on the worker thread, on copies.
##
## Also what the trap preview reads, on the main thread: `exposed`.
##
##     Grade.judge(before.copy(), move, seed)

const CRules = preload("res://versus/checkers_rules.gd")
const CAI = preload("res://versus/checkers_ai.gd")

## A man up reads about 68 percent.
const CHANCE_K := 0.0075
const CDEPTH := 6
## How many captures the exchange reads ahead.
const EXCHANGE := 4

static func chance(cp: int) -> float:
	var clamped := clampi(cp, -CP_CAP, CP_CAP)
	return 50.0 + 50.0 * (2.0 / (1.0 + exp(-CHANCE_K * clamped)) - 1.0)

## "c3-d4", or "c3xe5xg3" with every landing of a capture.
static func notation(m: PackedInt32Array) -> String:
	var mark := "x" if CRules.mv_ncaps(m) > 0 else "-"
	var text := _sq(m[0])
	for sq in CRules.mv_path(m):
		text += mark + _sq(sq)
	return text

static func _sq(sq: int) -> String:
	return "abcdefgh"[sq & 7] + str((sq >> 3) + 1)

## The verdict on `m` in the position `g` (searched in place, returned as it
## was): {grade, best, reply, score, cost, chance}. `best` is the stronger
## move, `reply` the other side's best answer to `m`, empty when it has none.
## A move with no choice is BOOK: no badge, and not counted in the accuracy.
static func judge_move(g: RefCounted, m: PackedInt32Array, seed: int, budget_ms := BUDGET_MS) -> Dictionary:
	if g.legal_moves().size() < 2:
		return {"grade": BOOK, "best": m, "reply": PackedInt32Array(), "score": 0, "cost": 0.0, "chance": 50.0}
	var before: Dictionary = CAI.new().analyse(g, budget_ms, CDEPTH, seed)
	var is_shot := shot(g, m)
	g.make(m)
	var after_cp := 0
	var reply := PackedInt32Array()
	var status: int = g.status()
	if status == CRules.NO_MOVES:
		after_cp = CAI.WIN
	elif status == CRules.PLAYING:
		var a: Dictionary = CAI.new().analyse(g, budget_ms, CDEPTH, seed)
		after_cp = -int(a.score)
		reply = a.best
	g.unmake()
	var was := chance(int(before.score))
	var now := chance(after_cp)
	# A search cut short can read the played move above the best: no credit.
	var best: PackedInt32Array = before.best
	var cost := 0.0 if m == best else maxf(was - now, 0.0)
	var played_best := cost <= COST_BEST
	var grade := BLUNDER
	if played_best:
		grade = BEST
	elif cost <= COST_GOOD:
		grade = GOOD
	elif cost <= COST_INACCURACY:
		grade = INACCURACY
	elif cost <= COST_MISTAKE:
		grade = MISTAKE
	if played_best:
		if is_shot and was < BRILLIANT_BELOW:
			grade = BRILLIANT
		elif now - _second(g, best, seed) >= ONLY_MOVE:
			grade = GREAT
	return {"grade": grade, "best": best, "reply": reply, "score": after_cp, "cost": cost, "chance": now}

static func _second(g: RefCounted, best: PackedInt32Array, seed: int) -> float:
	var ai: RefCounted = CAI.new()
	ai.skip = best
	return chance(int(ai.analyse(g, SECOND_MS, CDEPTH - 2, seed).score))

## Whether `m` is a shot: a quiet move after which the other side must take,
## and whatever it takes, the mover takes back more. `g` comes back as it was.
static func shot(g: RefCounted, m: PackedInt32Array) -> bool:
	if CRules.mv_ncaps(m) > 0:
		return false
	g.make(m)
	var replies: Array = g.legal_moves()
	var found: bool = not replies.is_empty() and CRules.mv_ncaps(replies[0]) > 0
	if found:
		for r: PackedInt32Array in replies:
			g.make(r)
			var back := 0
			var answers: Array = g.legal_moves()
			if not answers.is_empty():
				back = CRules.mv_ncaps(answers[0])
			g.unmake()
			if back <= CRules.mv_ncaps(r):
				found = false
				break
	g.unmake()
	return found

## What `m` gives away: the pieces the other side comes out ahead by, once the
## captures it sets off have run out, 0 when none. `g` comes back as it was.
static func exposed(g: RefCounted, m: PackedInt32Array) -> int:
	g.make(m)
	var net := _exchange(g, EXCHANGE)
	g.unmake()
	return maxi(net, 0)

## The pieces the side to move comes out ahead by if it plays on while
## captures last. Under Brazilian rules every capture is forced, so this is
## a line, not a guess; the far end of it is simply not read.
static func _exchange(g: RefCounted, depth: int) -> int:
	if depth <= 0:
		return 0
	var moves: Array = g.legal_moves()
	if moves.is_empty() or CRules.mv_ncaps(moves[0]) == 0:
		return 0
	var best := -99
	for m: PackedInt32Array in moves:
		g.make(m)
		best = maxi(best, CRules.mv_ncaps(m) - _exchange(g, depth - 1))
		g.unmake()
	return best

## Who could take what if it were the other side's move now: [from, piece]
## for each of the mover's pieces under attack, three at most. `g` is left as
## it was.
static func threats(g: RefCounted) -> Array:
	var flip: RefCounted = g.copy()
	flip.turn = 1 - flip.turn
	flip.rehash()
	var out: Array = []
	var seen := {}
	var moves: Array = flip.legal_moves()
	if moves.is_empty() or CRules.mv_ncaps(moves[0]) == 0:
		return out
	for m: PackedInt32Array in moves:
		for cap in CRules.mv_caps(m):
			if not seen.has(cap) and out.size() < 3:
				seen[cap] = true
				out.append([m[0], cap])
	return out
