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
## and never a second field to keep in step.
func add_plane(cells: Array[Vector2i]) -> int:
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
