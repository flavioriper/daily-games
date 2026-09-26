extends RefCounted

## Knight's rules as the board plays them, scene-free, as every flat board's
## are. The board (puzzles/knight2d.gd) draws this and nothing else.
##
## One move: hop your knight in an L. Landing on the king wins at once; land
## on a rose knight and it is taken; then the rose knights answer
## (knight_gen.gd's `step`). **A catch is never kept**: the position stays
## where it was and the board shows the catch and slides back. So nothing
## wrong can sit on the board and there is no Check -- only Undo, Reset and
## Hint. Insane alone has a budget, the shortest line plus two; Undo gives a
## move back.
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 6.

const Gen = preload("res://puzzles/knight_gen.gd")

## The generated board (knight_gen.gd's dictionary), read by the board.
var g := {}
var w := 0
var king := -1
var you := -1
## Each rose knight's square; -1 once taken.
var foes := PackedInt32Array()
## Every position before a kept move, for Undo: {"you", "foes"}.
var history: Array[Dictionary] = []
var won := false

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	g = Gen.generate(rng, difficulty)
	w = g.w
	king = g.king
	reset_board()

func size() -> int:
	return w * w

func opt() -> int:
	return int(g.get("opt", 0))

func budget() -> int:
	return int(g.get("budget", 0))

## Insane's moves left, or -1 on a level with no budget.
func moves_left() -> int:
	if budget() <= 0:
		return -1
	return maxi(0, budget() - history.size())

func legal() -> PackedInt32Array:
	return Gen.hops(w, you)

## Every square a rose knight reaches right now: land on one and it takes you.
func reach() -> Dictionary:
	var out := {}
	for f in foes:
		if f >= 0:
			for m in Gen.hops(w, f):
				out[m] = true
	return out

## The squares you have stood on, the opening first.
func route() -> PackedInt32Array:
	var out := PackedInt32Array()
	for h: Dictionary in history:
		out.append(int(h.you))
	out.append(you)
	return out

## Plays one hop and returns Gen.step's result, or {} when the hop is not
## legal or the budget is spent. A catch is returned but not kept.
func play(to: int) -> Dictionary:
	if won or not legal().has(to) or moves_left() == 0:
		return {}
	var r := Gen.step(g, you, foes, to)
	if int(r.caught) >= 0:
		return r
	history.append({"you": you, "foes": foes.duplicate()})
	you = r.you
	foes = r.foes
	won = r.won
	return r

func can_undo() -> bool:
	return not history.is_empty() and not won

func undo() -> bool:
	if not can_undo():
		return false
	var h: Dictionary = history.pop_back()
	you = h.you
	foes = h.foes
	return true

## Back to the opening: every rose knight back, taken ones too.
func reset_board() -> void:
	you = g.you
	foes = (g.foes as PackedInt32Array).duplicate()
	history.clear()
	won = false

## The next hop of the shortest line from here, or -1 when there is none
## (or, on Insane, none inside the moves left).
func hint_move() -> int:
	if won or moves_left() == 0:
		return -1
	var cap := moves_left() if moves_left() > 0 else 64
	var line := Gen.solve(g, you, foes, cap)
	return -1 if line.is_empty() else line[0]

func is_solved() -> bool:
	return won
