extends RefCounted

## Fairy Lights' rules, scene-free: what is on the board now, the moves that
## can change it, and everything derived from it. The board
## (puzzles/fairy_lights2d.gd) only draws this.
##
## **Live is derived, every time, and never stored.** `depths()` is a
## breadth-first walk from the post over edges where both sides carry a
## stub, rebuilt from `grid` on every call. Queens' rule, and it is what
## makes Undo free: there is no highlight to put back.
##
## **Solved is the rule, not the answer.** `is_solved()` checks that every
## stub meets a stub (`loose(i) == 0` everywhere) and that every cell has a
## depth (`depths()` has no -1 left). It never compares `grid` against
## `sol` -- the propagate-only solver already proved `sol` is the one
## arrangement that satisfies that rule, so the two claims agree, but only
## one of them is ever asked.
##
## **A hint is a given.** `hint()` settles the first unsolved cell in
## reading order to its answer, pins it so it can never be turned again,
## counts itself and empties the undo log (Shikaku's rule) -- what it
## settled is not a move to take back. `reset_board()` respects the pin.
## Spec: docs/superpowers/specs/2026-09-20-fairy-lights-flat-design.md,
## sections 3, 3.1 and 8.

const Gen = preload("res://puzzles/fairy_lights_gen.gd")

## Why a turn was turned down.
const OK := 0
const CROSS := 1
const PINNED := 2

var n: int = 0
var post: int = 0
var grid: PackedInt32Array = PackedInt32Array()  # what is on the board now
var deal: PackedInt32Array = PackedInt32Array()  # the scramble, for Reset
var sol: PackedInt32Array = PackedInt32Array()   # the generator's answer
var pinned: PackedByteArray = PackedByteArray()  # 1 where a hint settled a cell
var turns: int = 0
var hints: int = 0
## Newest last: the cell a tap turned. One undo, one entry.
var history: PackedInt32Array = PackedInt32Array()

func start(rng: RandomNumberGenerator, difficulty: int) -> void:
	var out: Dictionary = Gen.build(rng, difficulty)
	n = out.n
	post = out.post
	sol = out.sol
	deal = out.deal
	grid = deal.duplicate()
	pinned = PackedByteArray()
	pinned.resize(n * n)
	pinned.fill(0)
	history = PackedInt32Array()
	turns = 0
	hints = 0

# --- reading the board. None of this is cached. ---

## Whether the stub `i` has facing `side` (one of Gen.N/E/S/W) meets a stub
## coming back. False off the grid, and false when `i` has no stub there to
## begin with -- either way there is no live edge on that side. Symmetric by
## construction: `matched(i, side)` and `matched(j, opposite)` read the same
## two bits (`grid[i] & side` and `grid[j] & opposite`) and the same
## adjacency, whichever cell asks.
func matched(i: int, side: int) -> bool:
	if grid[i] & side == 0:
		return false
	var d := _dir(side)
	var r: int = i / n
	var c: int = i % n
	var a: int = r + Gen.DR[d]
	var b: int = c + Gen.DC[d]
	if a < 0 or b < 0 or a >= n or b >= n:
		return false
	var j: int = a * n + b
	var od := 1 << ((d + 2) % 4)
	return grid[j] & od != 0

## The mask of `i`'s own stubs that do not meet a stub back -- a wall, the
## grid's edge, or a closed neighbour. Zero means every stub of this cell is
## joined.
func loose(i: int) -> int:
	var m: int = grid[i]
	var out := 0
	for side in [Gen.N, Gen.E, Gen.S, Gen.W]:
		if m & side != 0 and not matched(i, side):
			out |= side
	return out

## A breadth-first walk from the post over edges where both sides carry a
## stub -- rebuilt from `grid` every call, never stored. -1 for a cell the
## walk never reaches.
func depths() -> PackedInt32Array:
	var cells := n * n
	var out := PackedInt32Array()
	out.resize(cells)
	out.fill(-1)
	if cells == 0:
		return out
	out[post] = 0
	var queue := PackedInt32Array([post])
	var head := 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		var r: int = i / n
		var c: int = i % n
		for d in range(4):
			var side := 1 << d
			if not matched(i, side):
				continue
			var a: int = r + Gen.DR[d]
			var b: int = c + Gen.DC[d]
			var j: int = a * n + b
			if out[j] != -1:
				continue
			out[j] = out[i] + 1
			queue.append(j)
	return out

## Every stub meets a stub, and every cell has a depth. Never a comparison
## against `sol` -- see the file header.
func is_solved() -> bool:
	var cells := n * n
	for i in cells:
		if loose(i) != 0:
			return false
	var d := depths()
	for i in cells:
		if d[i] == -1:
			return false
	return true

## The degree-1 cells -- a paper lantern on a stub -- in reading order. A
## cell's degree does not change under rotation, so this reads `sol` rather
## than `grid`: it is where a lantern stands, not which way it faces.
func lanterns() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in n * n:
		if Gen.degree(sol[i]) == 1:
			out.append(i)
	return out

# --- the moves ---

## One quarter turn clockwise. A cross has nowhere else to go (CROSS, no
## change); a pinned cell is a given (PINNED, no change).
func turn(i: int) -> int:
	if pinned[i] == 1:
		return PINNED
	var m: int = grid[i]
	if m == Gen.N | Gen.E | Gen.S | Gen.W:
		return CROSS
	grid[i] = Gen.cw(m)
	history.append(i)
	turns += 1
	return OK

## Turns the last tapped cell back a quarter turn. The cell, or -1 on an
## empty log.
func undo() -> int:
	if history.is_empty():
		return -1
	var i: int = history[history.size() - 1]
	history.resize(history.size() - 1)
	grid[i] = Gen.ccw(grid[i])
	return i

## The first unsolved cell in reading order, settled to its answer and
## pinned. Empties the undo log: what a hint gives is not a move to take
## back. The cell, or -1 when the board is already solved.
func hint() -> int:
	for i in n * n:
		if grid[i] == sol[i]:
			continue
		grid[i] = sol[i]
		pinned[i] = 1
		hints += 1
		history = PackedInt32Array()
		return i
	return -1

## Every unpinned cell back to the scramble it was dealt. A pinned cell is a
## given and stays exactly where the hint left it.
func reset_board() -> void:
	for i in n * n:
		if pinned[i] == 0:
			grid[i] = deal[i]
	history = PackedInt32Array()

## The bit position (0..3) of a side mask (Gen.N/E/S/W), matching Gen.DR/DC.
static func _dir(side: int) -> int:
	match side:
		Gen.N: return 0
		Gen.E: return 1
		Gen.S: return 2
		Gen.W: return 3
	return -1
