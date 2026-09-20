extends RefCounted

## Rings' rules, scene-free, as every flat board's are: the dealt pegs, the
## log of moves played, and the one thing in the player's hand at a time. The
## board (puzzles/rings2d.gd) only draws this.
##
## **`pegs` is the one truth.** Which peg is locked, which colours are already
## home, whether anything can still move -- none of that is stored anywhere;
## every read walks `pegs` fresh (`locked()`, `home_count()`, `is_solved()`,
## `is_stuck()`). That is what keeps an undo honest: taking a move back can
## never leave a stale highlight behind, because there was never a highlight
## to begin with, only a wash the board recomputes every frame off the pegs
## as they now stand.
##
## **A lift plus its drop is one move, and a put-back is not a move at all.**
## The ring in the hand (`held`, `held_from`) is exactly like a tile lifted
## off a Sudoku cell before it is placed: nothing is logged, nothing is
## undoable, and nothing about `pegs` has changed yet. `log` only grows when
## a drop actually lands the ring on another peg -- which is also the only
## thing `undo()` ever has to walk back, one `Vector2i(from, to)` at a time,
## exactly as it was played.
##
## `hint()` never invents a move: it asks Gen.solve() for the same path a
## full solve would take and plays its first step through drop()'s own path,
## so a hinted move is logged and undoable exactly like a tapped one.
## Spec: docs/superpowers/specs/2026-09-20-rings-flat-design.md.
## Concept page: docs/brainstorm/concepts.html#rings.

const Gen = preload("res://puzzles/rings_gen.gd")

const HINTS := 3

var pegs: Array = []
var deal: Array = []
var log: Array[Vector2i] = []
var held := -1
var held_from := -1
var colours := 6
var hints_used := 0

## The day's deal, proved solvable by Gen. Keeps a duplicate of it in `deal`
## so reset_board() can go back to exactly what was dealt, not to one undo
## at a time.
func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	pegs = Gen.deal(rng, difficulty)
	deal = []
	for s in pegs:
		deal.append((s as Array).duplicate())
	colours = int(Gen.BANDS[clampi(difficulty, 0, Gen.BANDS.size() - 1)]["colours"])
	log = []
	held = -1
	held_from = -1
	hints_used = 0

## A peg nothing comes off again: full and all one colour.
func locked(i: int) -> bool:
	return Gen.locked(pegs[i])

## A ring may be lifted off a peg that has one, is not locked, and only when
## the hand is empty.
func can_lift(i: int) -> bool:
	return held == -1 and not (pegs[i] as Array).is_empty() and not locked(i)

## Takes the top ring off peg `i` into the hand. Refused (and `false`) on an
## empty peg, a locked peg, or with a ring already in hand.
func lift(i: int) -> bool:
	if not can_lift(i):
		return false
	held_from = i
	held = (pegs[i] as Array).pop_back()
	return true

## Puts the ring in hand back where it came from. Not a move: the log never
## sees it.
func put_back() -> void:
	if held == -1:
		return
	(pegs[held_from] as Array).append(held)
	held = -1
	held_from = -1

## A drop is legal onto an empty peg or onto its own colour top, and refused
## on a full peg of another colour. Dropping back onto `held_from` is not a
## drop at all -- the board calls put_back() for that.
func can_drop(j: int) -> bool:
	if held == -1:
		return false
	var dst: Array = pegs[j]
	if dst.size() >= Gen.CAP:
		return false
	return dst.is_empty() or int(dst.back()) == held

## Why a drop on `j` would be refused right now, or "" when it would not be.
## Exactly these two strings; the board puts them on the tip card verbatim.
func refusal(j: int) -> String:
	if can_drop(j):
		return ""
	var dst: Array = pegs[j]
	if dst.size() >= Gen.CAP:
		return "That peg is full."
	return "A ring only lands on its own colour."

## Lands the held ring on peg `j`. Refused (returns -1) when nothing is held
## or can_drop(j) is false. On success, logs the move, clears the hand, and
## returns the slot index the ring landed in.
func drop(j: int) -> int:
	if not can_drop(j):
		return -1
	var dst: Array = pegs[j]
	var slot := dst.size()
	dst.append(held)
	log.append(Vector2i(held_from, j))
	held = -1
	held_from = -1
	return slot

## Walks the last move back exactly, including one that finished a peg. No
## legality check: it was legal on the way out.
func undo() -> Vector2i:
	put_back()
	if log.is_empty():
		return Vector2i(-1, -1)
	var m: Vector2i = log.pop_back()
	var ring = (pegs[m.y] as Array).pop_back()
	(pegs[m.x] as Array).append(ring)
	return m

## Locked pegs, counted fresh every time -- the colours already home.
func home_count() -> int:
	var n := 0
	for s in pegs:
		if Gen.locked(s):
			n += 1
	return n

func is_solved() -> bool:
	return Gen.solved(pegs)

## Not solved, and nothing legal to play. Two loops (is_solved, moves_from)
## and no solver -- that is the point: a stuck board is cheap to notice, a
## solvable one is not free to prove.
func is_stuck() -> bool:
	return not is_solved() and Gen.moves_from(pegs).is_empty()

## Back to the dealt position in one step, not one undo at a time.
func reset_board() -> void:
	pegs = []
	for s in deal:
		pegs.append((s as Array).duplicate())
	log = []
	held = -1
	held_from = -1

## Plays the solver's own next move, spending one of HINTS. Returns (-1, -1)
## when hints are spent, the board is already solved, or Gen.solve() finds
## nothing (a stuck board, or one past the search budget). Otherwise the move
## goes through lift()/drop() so it is logged and undoable exactly like a tap.
func hint() -> Vector2i:
	if hints_used >= HINTS or is_solved():
		return Vector2i(-1, -1)
	var path: Array = Gen.solve(pegs)
	if path.is_empty():
		return Vector2i(-1, -1)
	var m: Vector2i = path[0]
	lift(m.x)
	drop(m.y)
	hints_used += 1
	return m
