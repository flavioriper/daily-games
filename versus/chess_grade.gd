extends RefCounted

## How good a move was: the score sheet's verdict on one move, and the game's
## accuracy from those. Grades by what a move cost in chance of winning, not in
## centipawns, so a pawn thrown away in a won game is not a blunder and one
## thrown away in a level game can be. Pure: runs on the worker thread, on
## copies of the game.
##
##     Grade.judge(before.copy(), move, seed)

const Rules = preload("res://versus/chess_rules.gd")
const AI = preload("res://versus/chess_ai.gd")

enum { BOOK, BRILLIANT, GREAT, BEST, GOOD, INACCURACY, MISTAKE, BLUNDER }

## The most a move may cost, in percent of winning, for each band.
const COST_BEST := 1.0
const COST_GOOD := 6.0
const COST_INACCURACY := 12.0
const COST_MISTAKE := 22.0
## Second best has to be this much worse for a best move to be the only one.
const ONLY_MOVE := 20.0
## A sacrifice from a position already this won is no brilliance.
const BRILLIANT_BELOW := 88.0
const BRILLIANT_AFTER := 45.0
## A move's search: the position before it, the one after, and the second best.
const BUDGET_MS := 130
const SECOND_MS := 70
const MAX_DEPTH := 5
const CP_CAP := 1500

const SYMBOL := {BOOK: "", BRILLIANT: "!!", GREAT: "!", BEST: "★", GOOD: "✓", INACCURACY: "?!", MISTAKE: "?", BLUNDER: "??"}
const KEY := {BOOK: "CHS_G_BOOK", BRILLIANT: "CHS_G_BRILLIANT", GREAT: "CHS_G_GREAT", BEST: "CHS_G_BEST",
	GOOD: "CHS_G_GOOD", INACCURACY: "CHS_G_INACCURACY", MISTAKE: "CHS_G_MISTAKE", BLUNDER: "CHS_G_BLUNDER"}
const WORTH := [0, 1, 3, 3, 5, 9, 100]

## Chance of winning, percent, from a score in centipawns.
static func win_chance(cp: int) -> float:
	var clamped := clampi(cp, -CP_CAP, CP_CAP)
	return 50.0 + 50.0 * (2.0 / (1.0 + exp(-0.00368208 * clamped)) - 1.0)

## One move's accuracy from what it cost, percent.
static func move_accuracy(cost: float) -> float:
	return clampf(103.1668 * exp(-0.04354 * maxf(cost, 0.0)) - 3.1669, 0.0, 100.0)

## The verdict on `m` in the position `g` (searched in place, returned as it
## was): {grade, best, score, cost, chance}. `best` is the stronger move, and
## `score` the position after `m`, in centipawns from the mover's side.
static func judge(g: RefCounted, m: int, seed: int, budget_ms := BUDGET_MS) -> Dictionary:
	var before: Dictionary = AI.new().analyse(g, budget_ms, MAX_DEPTH, seed)
	var mine: int = g.turn
	var sac := _sacrifice(g, m)
	g.make(m)
	var after_cp := 0
	var status: int = g.status()
	if status == Rules.MATE:
		after_cp = AI.MATE
	elif status == Rules.PLAYING:
		after_cp = -int(AI.new().analyse(g, budget_ms, MAX_DEPTH, seed).score)
	g.unmake()
	assert(g.turn == mine)
	var was := win_chance(int(before.score))
	var now := win_chance(after_cp)
	# A search cut short can read the played move above the best: no credit.
	var cost := maxf(was - now, 0.0)
	var best: int = before.best
	var played_best := m == best or cost <= COST_BEST
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
		if sac and was < BRILLIANT_BELOW and now >= BRILLIANT_AFTER:
			grade = BRILLIANT
		elif g.legal_moves().size() > 1 and now - _second_best(g, best, seed) >= ONLY_MOVE:
			grade = GREAT
	return {"grade": grade, "best": best, "score": after_cp, "cost": cost, "chance": now}

## The chance left by the strongest move that is not `best`.
static func _second_best(g: RefCounted, best: int, seed: int) -> float:
	var ai: RefCounted = AI.new()
	ai.skip = best
	return win_chance(int(ai.analyse(g, SECOND_MS, MAX_DEPTH - 1, seed).score))

## Whether `m` leaves its piece where it can simply be taken at a loss, a
## knight or more, having taken less than it stands to lose.
static func _sacrifice(g: RefCounted, m: int) -> bool:
	var type := absi(int(g.board[Rules.mv_from(m)]))
	if type <= Rules.PAWN or type == Rules.KING:
		return false
	var taken := absi(int(g.board[Rules.mv_to(m)]))
	var mine: int = g.turn
	g.make(m)
	var to := Rules.mv_to(m)
	var attackers: PackedInt32Array = g.attackers_of(to, 1 - mine)
	var cheapest := 100
	for sq in attackers:
		cheapest = mini(cheapest, WORTH[absi(int(g.board[sq]))])
	var defended: bool = g.attacked(to, mine)
	g.unmake()
	if attackers.is_empty() or WORTH[taken] >= WORTH[type]:
		return false
	return not defended or cheapest < WORTH[type]

## The game's accuracy, percent, from the costs of one side's moves.
static func accuracy(costs: Array) -> int:
	if costs.is_empty():
		return 0
	var sum := 0.0
	for c: float in costs:
		sum += move_accuracy(c)
	return roundi(sum / costs.size())
