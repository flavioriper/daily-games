extends RefCounted

## Balance's rules with no scene in them: the day's hidden weights, the
## fruit, which cup each one is in (0 is the basket), which are pinned, and
## the undo history. The flat board draws the physics of it
## (puzzles/balance_sim.gd), but what counts -- is a fruit on the plank, is
## the beam level -- is only ever asked of this, in whole numbers, so the
## drawing can wobble without the rules wobbling with it.
##
## Nothing in here counts moves or hints: those are the board's tallies on
## PuzzleBase.
## Spec: docs/superpowers/specs/2026-09-27-balance-seesaw-design.md.

const Gen = preload("res://puzzles/balance_gen.gd")

const BASKET := 0

var weights: Array[int] = []
## Kind per fruit, kind by kind (the basket's order).
var fruit: Array[int] = []
## The one arrangement that levels the beam, a cup per fruit.
var answer: Array[int] = []
## Pinned from the start: part of the answer and never moved.
var pinned: Array[bool] = []
## Pinned by a hint: in its answer cup for good.
var hinted: Array[bool] = []
## Where each fruit is: a cup, or BASKET.
var at: Array[int] = []
var reach := 3
## One entry per move, newest last: {"moves": [[f, from], ...]}, every fruit
## the move shifted and where it came from.
var history: Array[Dictionary] = []

func setup(out: Dictionary) -> void:
	weights.assign(out.weights)
	fruit.assign(out.fruit)
	answer.assign(out.answer)
	pinned.assign(out.pinned)
	reach = int(out.reach)
	hinted = []
	at = []
	for f in fruit.size():
		hinted.append(false)
		at.append(answer[f] if pinned[f] else BASKET)
	history = []

func kinds() -> int:
	return weights.size()

func cups() -> Array[int]:
	return Gen.cups(reach)

## A fruit the player may pick up.
func loose(f: int) -> bool:
	return not pinned[f] and not hinted[f]

## The fruit in cup `x`, or -1.
func occupant(x: int) -> int:
	if x == BASKET:
		return -1
	for f in fruit.size():
		if at[f] == x:
			return f
	return -1

## Moves fruit `f` to cup `x` (or the basket). False, and nothing changes,
## for a fixed fruit, a taken cup or no change at all.
func place(f: int, x: int) -> bool:
	if not loose(f) or at[f] == x:
		return false
	if x != BASKET and (occupant(x) >= 0 or absi(x) > reach):
		return false
	history.append({"moves": [[f, at[f]]]})
	at[f] = x
	return true

## The pull of everything on the plank, in whole units: positive leans right.
func torque() -> int:
	var t := 0
	for f in fruit.size():
		if at[f] != BASKET:
			t += weights[fruit[f]] * at[f]
	return t

func in_basket() -> int:
	return at.count(BASKET)

func is_solved() -> bool:
	return in_basket() == 0 and torque() == 0

func can_undo() -> bool:
	return not history.is_empty()

## Takes the last move back. Returns [[f, to], ...] for every fruit it put
## back, [] with nothing to undo.
func undo() -> Array:
	if history.is_empty():
		return []
	var last: Dictionary = history.pop_back()
	var back: Array = []
	var moves: Array = last.moves
	for i in range(moves.size() - 1, -1, -1):
		var f: int = moves[i][0]
		at[f] = int(moves[i][1])
		back.append([f, at[f]])
	return back

## Every loose fruit home to the basket. Returns the fruit that moved.
func reset() -> Array[int]:
	var moved: Array[int] = []
	for f in fruit.size():
		if loose(f) and at[f] != BASKET:
			at[f] = BASKET
			moved.append(f)
	history = []
	return moved

# --- help ---

## The next hint: {"f": the fruit to seat, "cup": its answer cup, "bumped":
## the fruit sitting there now or -1}; {} when there is nothing to give.
## Cups nearest the pivot first, so hints are reproducible. A fruit already
## right (its kind is the answer's kind for its cup) is never moved.
func hint_move() -> Dictionary:
	var want := {}
	for f in fruit.size():
		want[answer[f]] = fruit[f]
	var order := cups()
	order.sort_custom(func(a: int, b: int): return absi(a) < absi(b) or (absi(a) == absi(b) and a < b))
	for x: int in order:
		if not want.has(x):
			continue
		var there := occupant(x)
		if there >= 0 and fruit[there] == int(want[x]):
			continue
		var k: int = want[x]
		# the fruit to bring: one of that kind in the basket, else one of
		# that kind standing in a cup that is not its kind's
		var pick := -1
		for f in fruit.size():
			if loose(f) and fruit[f] == k and at[f] == BASKET:
				pick = f
				break
		if pick < 0:
			for f in fruit.size():
				if loose(f) and fruit[f] == k and not _right(f, want):
					pick = f
					break
		if pick >= 0:
			return {"f": pick, "cup": x, "bumped": there}
	return {}

func _right(f: int, want: Dictionary) -> bool:
	return at[f] != BASKET and want.has(at[f]) and int(want[at[f]]) == fruit[f]

## Plays hint_move(): the bumped fruit goes home, the hinted one takes its
## cup and is fixed there. The history keeps the bump but forgets the hinted
## fruit, which no undo may take back out. Returns the move, {} if none.
func apply_hint() -> Dictionary:
	var m := hint_move()
	if m.is_empty():
		return {}
	var f: int = m.f
	var b: int = m.bumped
	m["from"] = at[f]
	if b >= 0:
		at[b] = BASKET
	at[f] = int(m.cup)
	hinted[f] = true
	var kept: Array[Dictionary] = []
	for h in history:
		var moves: Array = []
		for mv in h.moves:
			if int(mv[0]) != f:
				moves.append(mv)
		if not moves.is_empty():
			kept.append({"moves": moves})
	history = kept
	return m

## Puts the answer on the plank, for a daily reopened after it was solved.
func show_answer() -> void:
	for f in fruit.size():
		at[f] = answer[f]
	history = []
