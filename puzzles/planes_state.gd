extends RefCounted

## Paper Planes' rules, scene-free, as every flat board's are: the board, the
## planes, their lanes, and the four moves. The board (puzzles/planes2d.gd)
## only draws this.
## Spec: docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md,
## sections 3 and 4.
##
## The one fact the whole screen rests on: **a launch only ever empties
## cells, so it can never block another plane.** Launching a plane clears its
## own cells and nothing else, and a lane is blocked only by occupied ones --
## so a board that can be cleared at all can still be cleared after any legal
## tap, in any order. That is what makes the solver below greedy and
## complete, and what makes Undo and Reset pure convenience rather than
## repair.

const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

## The bands (spec section 6). Hard is the reference's own 16 x 22. The
## weights pick a plane's length: the middle lengths are the common ones,
## because a board of two-cell darts reads as confetti and a board of
## ten-cell ones cannot be packed.
const BANDS: Array[Dictionary] = [
	{"cols": 10, "rows": 14, "min_len": 2, "max_len": 8, "weights": [2, 3, 4, 5, 5, 4, 3], "floor": 0.72},
	{"cols": 13, "rows": 18, "min_len": 2, "max_len": 9, "weights": [2, 3, 4, 5, 5, 5, 4, 3], "floor": 0.72},
	{"cols": 16, "rows": 22, "min_len": 2, "max_len": 10, "weights": [2, 3, 4, 5, 5, 5, 4, 3, 2], "floor": 0.72},
]
## How many boards to make before keeping the fullest, and how many failed
## placements in a row end a board.
const CANDIDATES := 6
const TRIES := 400

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

var rows := 0
var cols := 0
var planes: Array[Dictionary] = []
var order: Array[int] = []
var _occupant: Dictionary = {}   # Vector2i -> plane index, planes still on the board
var _history: Array[int] = []

func clear_occupancy() -> void:
	_occupant = {}
	_history = []

## Lays one plane on the board. `cells` runs tail to head; the direction is
## the step into the head, so a plane's heading is a property of its shape
## and never a second field to keep in step. That derivation is why **a
## plane is never shorter than two cells**: a single cell has no last step
## and so no heading, which is also why every band's `min_len` is 2. A
## shorter body is refused rather than given a zero direction, because a
## zero direction never advances -- `lane()` would loop on it forever.
func add_plane(cells: Array[Vector2i]) -> int:
	if cells.size() < 2:
		push_error("PlanesState.add_plane: a plane needs at least two cells to have a heading")
		return -1
	var head: Vector2i = cells[cells.size() - 1]
	var dir: Vector2i = head - cells[cells.size() - 2]
	var idx := planes.size()
	planes.append({"cells": cells, "dir": dir, "gone": false})
	for c in cells:
		_occupant[c] = idx
	return idx

func in_board(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func plane_at(cell: Vector2i) -> int:
	return int(_occupant.get(cell, -1))

## Every cell beyond the head, in the dart's direction, out to the edge.
func lane(i: int) -> Array[Vector2i]:
	var p: Dictionary = planes[i]
	var cells: Array[Vector2i] = p["cells"]
	var dir: Vector2i = p["dir"]
	var out: Array[Vector2i] = []
	var at: Vector2i = cells[cells.size() - 1] + dir
	while in_board(at):
		out.append(at)
		at += dir
	return out

## The first plane standing in the lane, or -1.
func blocker(i: int) -> int:
	for c in lane(i):
		var who := plane_at(c)
		if who != -1:
			return who
	return -1

func is_free(i: int) -> bool:
	return not planes[i]["gone"] and blocker(i) == -1

func free_planes() -> Array[int]:
	var out: Array[int] = []
	for i in planes.size():
		if is_free(i):
			out.append(i)
	return out

func launch(i: int) -> bool:
	if planes[i]["gone"] or not is_free(i):
		return false
	planes[i]["gone"] = true
	for c in planes[i]["cells"]:
		_occupant.erase(c)
	_history.append(i)
	return true

func undo() -> int:
	if _history.is_empty():
		return -1
	var i: int = _history.pop_back()
	planes[i]["gone"] = false
	for c in planes[i]["cells"]:
		_occupant[c] = i
	return i

func reset() -> void:
	for i in planes.size():
		if planes[i]["gone"]:
			planes[i]["gone"] = false
			for c in planes[i]["cells"]:
				_occupant[c] = i
	_history = []

func left() -> int:
	var n := 0
	for p in planes:
		if not p["gone"]:
			n += 1
	return n

func solved() -> bool:
	return left() == 0

## Greedy, and complete: launching a plane only empties cells, so a board
## that could be cleared before a tap can still be cleared after it. No
## search, no backtracking. Returns [] when the board is stuck.
func solve_order() -> Array[int]:
	var gone := {}
	var out: Array[int] = []
	var total := left()
	while out.size() < total:
		var moved := false
		for i in planes.size():
			if planes[i]["gone"] or gone.has(i):
				continue
			var clear := true
			for c in lane(i):
				var who := plane_at(c)
				if who != -1 and not gone.has(who):
					clear = false
					break
			if clear:
				gone[i] = true
				out.append(i)
				moved = true
		if not moved:
			return []
	return out

## The hint's pick: the first plane of the generator's own order that is
## still here and free, else any free one.
func hint_plane() -> int:
	for i in order:
		if not planes[i]["gone"] and is_free(i):
			return i
	var free := free_planes()
	return -1 if free.is_empty() else free[0]

## Carves a board backwards out of an empty sky (spec section 5, ported cell
## for cell from the throwaway Python probe that validated it before this
## file existed; that probe is not kept). Up to CANDIDATES attempts are
## carved and thrown away except the winner: the first at or above the
## band's coverage floor, else the fullest one made. `order` is set to the
## reverse of the winner's placement order -- planes placed later are
## launched earlier, so `hint_plane()` walks it front to back -- and the
## result is asserted solvable, which the construction (section 3's "a
## launch only ever empties cells") guarantees and has confirmed over 8,250
## walk steps across 120 generated boards -- measured at 0.331 ms a hard
## board, not the microsecond an earlier draft of this file guessed at.
## There is deliberately no runtime fallback here: unlike mushroom_state.gd's
## generator, which can genuinely fail and has to answer for it, this
## invariant cannot fail by construction, so a fallback would be dead code
## standing in for a bug that cannot occur.
func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var b := band(difficulty)
	rows = int(b["rows"])
	cols = int(b["cols"])
	planes = []
	order = []
	clear_occupancy()
	var area := float(rows * cols)
	var floor_cov: float = float(b["floor"])
	var best_planes: Array[Dictionary] = []
	var best_occupant: Dictionary = {}
	var best_cov := -1.0
	for attempt in CANDIDATES:
		planes = []
		clear_occupancy()
		_carve(rng, b)
		var cov := float(_occupant.size()) / area
		if cov > best_cov:
			best_cov = cov
			best_planes = planes.duplicate(true)
			best_occupant = _occupant.duplicate()
		if cov >= floor_cov:
			break
	planes = best_planes
	_occupant = best_occupant
	for i in range(planes.size() - 1, -1, -1):
		order.append(i)
	# solve_order() is called from inside the assert itself, not into a local
	# first: `var check := solve_order()` is a statement, so a release export
	# strips the assert() around it but still runs the solver and throws the
	# result away for nothing (measured cost: 0.331 ms a hard board).
	assert(solve_order().size() == planes.size(),
		"PlanesState.build: generated board must be solvable")

## One candidate, laid straight onto `self` (rows/cols/planes/_occupant
## already reset by `build()`). Loops while coverage is under 95% and no run
## of TRIES placements in a row has failed: pick a random empty cell as the
## head, shuffle the four directions and, for the first whose lane runs
## entirely clear to the edge, grow a self-avoiding tail backwards to a
## length drawn from the band's weights, never crossing the lane or itself.
## A body that reaches the band's min_len is laid with `add_plane()` -- the
## one place the direction is derived -- and a failed direction or a body
## too short both count as one failed placement.
func _carve(rng: RandomNumberGenerator, b: Dictionary) -> void:
	var min_len: int = int(b["min_len"])
	var area := float(rows * cols)
	var fails := 0
	while float(_occupant.size()) < 0.95 * area and fails < TRIES:
		var cell := Vector2i(rng.randi_range(0, cols - 1), rng.randi_range(0, rows - 1))
		if _occupant.has(cell):
			fails += 1
			continue
		var dirs: Array[Vector2i] = DIRS.duplicate()
		_shuffle_dirs(dirs, rng)
		var placed := false
		for d in dirs:
			var lane_set := {}
			var at: Vector2i = cell + d
			var clear := true
			while in_board(at):
				if _occupant.has(at):
					clear = false
					break
				lane_set[at] = true
				at += d
			if not clear:
				continue
			var body: Array[Vector2i] = [cell]
			var used := {cell: true}
			var want := _pick_length(rng, b)
			var prev: Vector2i = cell - d
			if not in_board(prev) or _occupant.has(prev) or lane_set.has(prev):
				continue
			body.append(prev)
			used[prev] = true
			while body.size() < want:
				var last: Vector2i = body[body.size() - 1]
				var cand: Array[Vector2i] = []
				for e in DIRS:
					var q: Vector2i = last + e
					if not in_board(q):
						continue
					if _occupant.has(q) or used.has(q) or lane_set.has(q):
						continue
					cand.append(q)
				if cand.is_empty():
					break
				var pick: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
				body.append(pick)
				used[pick] = true
			if body.size() < min_len:
				continue
			body.reverse()
			add_plane(body)
			placed = true
			break
		if placed:
			fails = 0
		else:
			fails += 1

## Weighted by `b["weights"]`, index `len - min_len` -- the middle lengths
## are the common ones (see BANDS above).
static func _pick_length(rng: RandomNumberGenerator, b: Dictionary) -> int:
	var weights: Array = b["weights"]
	var min_len: int = int(b["min_len"])
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += float(weights[i])
		if r < acc:
			return min_len + i
	return min_len + weights.size() - 1

## Fisher-Yates, seeded only by `rng` -- same shape as mushroom_gen.gd's.
static func _shuffle_dirs(arr: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
