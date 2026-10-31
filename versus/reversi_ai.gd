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
##   0  any square more often than not; otherwise one ply and a heavy blur
##   1  one ply, a person's blur, now and then any square
##   2  as deep as the budget allows, up to DEPTH_MAX, no blur, the last
##      SOLVE_AT squares played out exactly
##
## Tricks (`plan_turn`): it reads what each it holds would leave, a few plies
## deep from the squares that matter, and plays one if that beats its best disc
## by a bar that falls as the board fills. Easy takes a corner it is handed.
##
## `plan` is safe on a worker thread: it touches nothing but the copy it is
## given (versus/reversi_screen.gd's _think).

const Rules = preload("res://versus/reversi_rules.gd")

const W := Rules.W
const CELLS := Rules.CELLS
const WIN := 50000
const DEPTH := [1, 1, 8]
const BLUR := [90.0, 60.0, 0.0]
## How often a level sets its disc on any square it may. A beginner (a corner,
## else the most discs) went 3-9 against Easy at 0.3 and 0-12 against Medium at
## three plies: the game was lost before anyone had learnt it.
const WILD := [0.85, 0.35, 0.0]
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
## The moon's tricks by level, how deep it reads one, and the bar: what a trick
## must gain over the best disc early and late (empties LATE_AT or fewer).
const STOCK := [0, Rules.SWIPE, Rules.ALL_TRICKS]
const TRICK_DEPTH := [2, 3, 4]
const TRICK_MS := 220
const GAIN_EARLY := 150
const GAIN_LATE := 40
const LATE_AT := 14
## A judged move: how deep, how long.
const JUDGE_DEPTH := 4
const JUDGE_MS := 140

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
	if level == 0:
		for c in moves:
			if c in Rules.CORNERS:
				return c
	if rng.randf() < WILD[level]:
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

## What the side to move does: {"trick": 0, "cell": c} a disc, or a trick with
## its square (-1 for an encore). A trick is only looked at with a disc to play.
func plan_turn(rules: RefCounted, level: int, rng_seed: int, budget_ms := -1) -> Dictionary:
	var side: int = rules.turn
	var cell := plan(rules, level, rng_seed, budget_ms)
	var left: int = rules.tricks[side]
	if left == 0 or cell < 0 or not rules.tricks_open():
		return {"trick": 0, "cell": cell}
	_b = rules.cells.duplicate()
	var empties := _b.count(Rules.EMPTY)
	var depth: int = TRICK_DEPTH[level]
	_stop_at = Time.get_ticks_msec() + TRICK_MS
	_stopped = false
	var turned := _flips(cell, side)
	_put(cell, turned, side)
	var plain := -_search(1 - side, depth - 1, -WIN * 2, WIN * 2, false)
	_take(cell, turned, side)
	var best := {"trick": 0, "cell": cell}
	var bar := float(GAIN_LATE if empties <= LATE_AT else GAIN_EARLY)
	var top := float(plain) + bar
	if left & Rules.STONE != 0:
		for c: int in rules.legal_for(1 - side):
			if WEIGHT[c] < 15:
				continue
			_b[c] = Rules.ROCK
			var s := -_search(1 - side, depth - 1, -WIN * 2, WIN * 2, false)
			_b[c] = Rules.EMPTY
			if float(s) > top and not _stopped:
				top = float(s)
				best = {"trick": Rules.STONE, "cell": c}
	if left & Rules.SWIPE != 0:
		for c in CELLS:
			if _b[c] != 2 - side or c in Rules.CORNERS or WEIGHT[c] < 3:
				continue
			_b[c] = side + 1
			var s := -_search(1 - side, depth - 1, -WIN * 2, WIN * 2, false)
			_b[c] = 2 - side
			if float(s) > top and not _stopped:
				top = float(s)
				best = {"trick": Rules.SWIPE, "cell": c}
	if left & Rules.ENCORE != 0:
		_put(cell, turned, side)
		var s := _search(side, depth - 1, -WIN * 2, WIN * 2, false)
		_take(cell, turned, side)
		if float(s) > top and not _stopped:
			best = {"trick": Rules.ENCORE, "cell": -1}
	return best

## How the side to move's `cell` stands in `rules`: {best, best_score, score,
## gap}, gap what the best beat the next best by. Empty if time ran out.
func judge(rules: RefCounted, cell: int, budget_ms := JUDGE_MS) -> Dictionary:
	var moves: PackedInt32Array = rules.legal_moves()
	if moves.size() < 2:
		return {}
	_b = rules.cells.duplicate()
	_stop_at = Time.get_ticks_msec() + budget_ms
	_stopped = false
	var side: int = rules.turn
	var scores := {}
	for c in moves:
		var turned := _flips(c, side)
		_put(c, turned, side)
		var s := -_search(1 - side, JUDGE_DEPTH - 1, -WIN * 2, WIN * 2, false)
		_take(c, turned, side)
		if _stopped:
			return {}
		scores[c] = s
	var best := moves[0]
	for c in moves:
		if scores[c] > scores[best]:
			best = c
	var next := -WIN * 2
	for c in moves:
		if c != best:
			next = maxi(next, scores[c])
	return {"best": best, "best_score": scores[best], "score": scores[cell], "gap": scores[best] - next}

## What a square does, read for a finger on it: "corner" it takes one, "shut"
## the other side has no answer, "gives" it hands over `corner`, "" nothing to
## say. Main thread, a copy of the rules.
static func read(rules: RefCounted, cell: int) -> Dictionary:
	if cell in Rules.CORNERS:
		return {"kind": "corner", "corner": cell}
	var next: RefCounted = rules.copy()
	var side: int = next.turn
	if next.make(cell).is_empty():
		return {"kind": "", "corner": -1}
	if next.turn == side:
		return {"kind": "shut", "corner": -1}
	for c: int in Rules.CORNERS:
		if not next.flips(c, next.turn).is_empty():
			return {"kind": "gives", "corner": c}
	return {"kind": "", "corner": -1}

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
		if v == Rules.EMPTY or v == Rules.ROCK:
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
		if v == Rules.EMPTY or v == Rules.ROCK:
			continue
		# The squares beside a corner held are safe, and good for its holder.
		for i in range(1, 4):
			var q := _b[k[i]]
			if q == Rules.EMPTY or q == Rules.ROCK:
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
