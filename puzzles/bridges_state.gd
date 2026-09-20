extends RefCounted

## Bridges' rules, with no scene under them: the lattice, the islets and their
## numbers, the answer's runs, the player's runs, and every move that can
## change them. The flat board (puzzles/bridges2d.gd) draws this and nothing
## else.
##
## Two things decide how this board feels and are worth stating plainly.
## **An islet's degree and the network's groups are derived every time they
## are asked and never stored**: summing the runs is cheap, a second truth is
## not, and undo would have to unwind a stored one -- which is the rule
## Queens' crosses established. **And only two gestures are refused**: a lane
## nothing faces, and a lane a laid run crosses. An islet pushed *over* its
## number is not refused, because that is a mistake the player can see; the
## board draws it wrong and the finger fixes it.
##
## `is_solved()` is every rule at once and never a subset of them: every
## islet's degree equals its number, no two laid runs cross, **and** one
## flood reaches every islet. The last is the puzzle -- see the spec's
## section 1.
## Spec: docs/superpowers/specs/2026-09-20-bridges-flat-design.md, section 3.

const Gen = preload("res://puzzles/bridges_gen.gd")

## The cycle's top: a fourth drag wraps a full run back to nothing.
const MAX_PLANKS := 3
## Neither end of a lane, for a walk that met the edge instead of an islet.
const NOWHERE := Vector2i(-1, -1)

var n: int = 7
var islets: Array[Vector2i] = []
## Vector2i -> the number on that islet.
var need: Dictionary = {}
## lane key -> the planks the answer lays there. Lanes it does not name carry
## nothing.
var answer: Dictionary = {}
## lane key -> the planks the player has laid. A lane at 0 is erased rather
## than stored, so `runs.size()` is the count of runs on the board.
var runs: Dictionary = {}
## lane key -> {"a": Vector2i, "b": Vector2i, "cells": Array[Vector2i]}, every
## facing pair on the lattice. Taken once from the generator.
var lanes: Dictionary = {}
## lane key -> the lane keys whose water it shares. Taken once as well.
var crossing: Dictionary = {}
## One entry per move, newest last: {"key": String, "was": int}.
var history: Array[Dictionary] = []
## Whether the generator proved the clues admit only this answer, and whether
## propagation alone finishes it. Both come from the generator's own proof --
## `unique` is false only for the last-resort board `generate()` hands back
## when 200 attempts found none, which is playable but not a puzzle.
var unique := true
var guess_free := false
## Vector2i -> true for every islet, so a walk can ask what it met.
var _seat: Dictionary = {}

func build(rng: RandomNumberGenerator, difficulty: int) -> void:
	var g: Dictionary = Gen.generate(rng, difficulty)
	var b: Dictionary = Gen.band(difficulty)
	n = int(g.get("n", b.n))
	var grown: Array = g.get("islets", [])
	islets = []
	for cell in grown:
		islets.append(cell)
	need = g.get("need", {})
	answer = g.get("answer", {})
	guess_free = bool(g.get("guess_free", false))
	unique = bool(g.get("unique", false))
	if islets.is_empty():
		push_warning("Bridges: no board could be grown for this seed")
	lanes = Gen.lanes_for(n, islets)
	crossing = Gen.crossings(lanes)
	_seat = {}
	for cell in islets:
		_seat[cell] = true
	runs = {}
	history = []

# --- reading the water ---

func is_islet(cell: Vector2i) -> bool:
	return _seat.has(cell)

## The lane key when the two islets face each other across open water, else
## "". A cell never faces itself, and a pair with an islet between them is
## not a lane at all: `lanes_for` ends every lane at the first islet it meets.
func lane_at(a: Vector2i, b: Vector2i) -> String:
	if a == b:
		return ""
	var key := Gen.lane_key(a, b)
	return key if lanes.has(key) else ""

## The islet `cell` faces along `dir`, or NOWHERE when the walk met the edge
## first. `dir` is one of the four orthogonals; anything else faces nothing.
func facing(cell: Vector2i, dir: Vector2i) -> Vector2i:
	if dir == Vector2i.ZERO or (dir.x != 0 and dir.y != 0):
		return NOWHERE
	var step := Vector2i(signi(dir.x), signi(dir.y))
	var p: Vector2i = cell + step
	while p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
		if _seat.has(p):
			return p
		p += step
	return NOWHERE

## The laid run crossing this lane, or "" when the lane is clear. This is the
## board's second refusal and the only one the state can answer on its own.
func blocked_by(key: String) -> String:
	for other in crossing.get(key, []):
		if int(runs.get(other, 0)) > 0:
			return String(other)
	return ""

func planks(key: String) -> int:
	return int(runs.get(key, 0))

# --- moves ---

## Advances the run 0-1-2-3-0 and returns the new count. Refused, unchanged
## and unrecorded when a laid run crosses the lane, or when the key is not a
## lane at all. It is **not** refused when it pushes an islet over its number:
## that is drawn wrong, not blocked, which is the house rule that feedback
## beats a mode.
func cycle(key: String) -> int:
	var before := planks(key)
	if not lanes.has(key):
		return before
	if blocked_by(key) != "":
		return before
	var after := (before + 1) % (MAX_PLANKS + 1)
	history.append({"key": key, "was": before})
	_lay(key, after)
	return after

## Wipes a run to nothing in one go -- the tap's shortcut past three drags.
## True when there was something to wipe.
func clear_run(key: String) -> bool:
	var before := planks(key)
	if before <= 0:
		return false
	history.append({"key": key, "was": before})
	_lay(key, 0)
	return true

## Takes back the last move. True when there was one.
func undo() -> bool:
	if history.is_empty():
		return false
	var entry: Dictionary = history.pop_back()
	_lay(String(entry.key), int(entry.was))
	return true

## Lifts every plank and forgets the moves that laid them.
func reset_board() -> void:
	runs = {}
	history = []

func can_undo() -> bool:
	return not history.is_empty()

## A lane at nothing is erased rather than stored at 0, so every reader can
## treat a key's absence and a key at 0 as the same thing.
func _lay(key: String, count: int) -> void:
	if count <= 0:
		runs.erase(key)
	else:
		runs[key] = count

# --- derived, and never stored ---

## Summed from the runs every time it is asked. Storing it would be a second
## truth to keep in step, and undo would have to unwind it -- which is the
## rule Queens' crosses established.
func degree(cell: Vector2i) -> int:
	var total := 0
	for key in runs:
		var k := int(runs[key])
		if k <= 0:
			continue
		var lane: Dictionary = lanes[key]
		if lane.a == cell or lane.b == cell:
			total += k
	return total

## The islets flooded over the laid runs, one array per connected group.
## Also derived, for the same reason.
func groups() -> Array[Array]:
	var seen := {}
	var out: Array[Array] = []
	for start in islets:
		if seen.has(start):
			continue
		var group: Array = []
		var stack := [start]
		seen[start] = true
		while not stack.is_empty():
			var cell = stack.pop_back()
			group.append(cell)
			for key in runs:
				if int(runs[key]) <= 0:
					continue
				var lane: Dictionary = lanes[key]
				var other = null
				if lane.a == cell:
					other = lane.b
				elif lane.b == cell:
					other = lane.a
				if other != null and not seen.has(other):
					seen[other] = true
					stack.append(other)
		out.append(group)
	return out

## Every rule at once and never a subset: every islet's number met, no two
## runs crossing, AND one single network. The last is the puzzle -- see the
## spec's section 1.
##
## The crossing clause is a backstop rather than the rule's enforcement:
## `cycle()` refuses a crossed lane, so ordinary play can never reach a
## crossed position. It is here because it once *was* reachable -- `hint()`
## lifted only the first blocker of a lane that had two -- and because a win
## predicate that does not cover a rule the board states is a bug waiting for
## the next way in.
func is_solved() -> bool:
	for cell in islets:
		if degree(cell) != int(need[cell]):
			return false
	for key in runs:
		if int(runs[key]) <= 0:
			continue
		if blocked_by(String(key)) != "":
			return false
	return groups().size() == 1

# --- the hint and the check ---

## Every lane carrying more planks than the answer lays there, which is what
## Check marks. A lane the player has *under*-laid is unfinished and not
## wrong: marking it would hand over the deduction the player is there to
## make, which is the rule Code Break's screen is built on. This follows
## Nonogram's `wrong_tiles` and Light Up's `wrong_lamps`: only what is on the
## board, and only where the answer does not want it.
func wrong_runs() -> Array[String]:
	var out: Array[String] = []
	for key in runs:
		if int(runs[key]) > int(answer.get(key, 0)):
			out.append(String(key))
	return out

## Lays one plank on a lane the answer has and the board lacks, and returns
## its key -- or "" when the board already carries every plank the answer
## does. Never an overshoot, so a hint can never itself be the thing that
## pushes an islet over its number.
##
## The order is the answer's keys sorted, not their insertion order, so the
## same board always hands out the same hint however the answer was grown.
## A lane a wrong run crosses cannot take a plank, so it is passed over; if
## every lane left is crossed, **every** blocker is lifted first -- the
## answer's runs never cross each other, so a blocker is always a plank the
## player laid wrong. It has to be every one and not the first: a lane with
## *k* water cells can be crossed by *k* lanes, and two lanes crossing the
## same lane are perpendicular to it and so parallel to each other, which
## means both may legally be laid. Lifting one and writing the hint through
## the private `_lay` would leave two runs crossing -- a position `rules()`
## calls impossible, with both lanes frozen, each `blocked_by` the other.
## Each lift is its own history entry, so in that case a hint costs one undo
## per blocker plus one, rather than one.
func hint() -> String:
	var want: Array = answer.keys()
	want.sort()
	var first := ""
	for key in want:
		if planks(String(key)) >= int(answer[key]):
			continue
		if first == "":
			first = String(key)
		if blocked_by(String(key)) == "":
			_lay_hint(String(key))
			return String(key)
	if first == "":
		return ""
	var b := blocked_by(first)
	while b != "":
		clear_run(b)
		b = blocked_by(first)
	_lay_hint(first)
	return first

func _lay_hint(key: String) -> void:
	var before := planks(key)
	history.append({"key": key, "was": before})
	_lay(key, before + 1)

# --- the share ---

## One line, not a lattice: an 11x11 grid of emoji would be mostly blank
## water, so this takes Shikaku's one-line form rather than Light Up's grid.
func share_glyphs() -> String:
	var planked := 0
	for key in runs:
		planked += int(runs[key])
	return "🌉 %dx%d · %d islets · %d planks" % [n, n, islets.size(), planked]
