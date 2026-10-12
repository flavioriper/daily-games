extends RefCounted

## Trivet as pure data (spec
## docs/superpowers/specs/2026-10-12-arcade-trivet-design.md): stacks of felt
## mats set down on a tray of six-sided places. No clock: the screen
## (arcade/trivet_board.gd) calls `place`, `sweep` and `redeal` and drains
## `events`, which say one after another what a move did, so each hop and
## each stack put away is shown in its turn.
##
## The rules. A hand of three stacks is offered; one is set on any empty
## place, and the next three come when all are down. Stacks that touch and
## wear the same colour on top gather: the mats of that colour leave every
## one of them for a single stack (`_pick`: the one of the fewest colours,
## so a stack of one colour takes the rest and what is uncovered is in the
## stacks that had more under it). A stack with CLEAR mats of one colour on
## top has them put away, a point a mat, and what a stack uncovers gathers
## in its turn: the second stack put away by one move counts double, the
## third three times. The score opens levels; a level brings a colour or a
## place and a tool. The tray full with no brush left ends the run.

enum Phase { PLAY, OVER }

## The tray: every place within R of the middle, 19 of them.
const R := 2
## Mats of one colour on a stack's top that are put away.
const CLEAR := 10
const HAND := 3
## The six ways off a place, in axial steps.
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
## The six corners start under a lid; one opens at each of these levels.
const OPENS_AT := [2, 3, 5, 6, 8, 9]
## The colours in play at a level: three, and one more at each of these.
const COLOURS_FROM := 3
const COLOUR_AT := [2, 4, 7]
const COLOURS_MOST := 6
## A stack offered is this tall at most, in runs of this many colours.
const TALL_MOST := 6
## The tools a run starts with, and the most held.
const SWEEPS := 1
const DEALS := 1
const TOOLS_MOST := 9
## A Second chance takes this many stacks off, the tallest.
const REVIVE_TAKES := 4
## Places left empty at which the tray is called tight.
const TIGHT := 2

var rng := RandomNumberGenerator.new()
var phase := Phase.PLAY
var score := 0
var level := 1
## Mats put away, stacks set down, and the most stacks one move put away.
var cleared := 0
var placed := 0
var best_chain := 0
var sweeps := SWEEPS
var deals := DEALS
var events: Array = []
## The places, in axial coordinates, and each one's neighbours by index.
var cells: Array[Vector2i] = []
var near: Array = []
## A place's stack, bottom to top, each mat a colour's index; [] is empty.
var stacks: Array = []
## A place still under its lid.
var closed: Array = []
## The hand: HAND stacks, [] where one has been set down.
var hand: Array = []
var radius := R
var _index := {}
var _tight := false

## `across` is the tray's reach from its middle: R, or less for a tutorial
## page's small tray, which has no lids.
func _init(seed_value := -1, across := R) -> void:
	radius = across
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for q in range(-across, across + 1):
		for r in range(-across, across + 1):
			if absi(q + r) <= across:
				_index[Vector2i(q, r)] = cells.size()
				cells.append(Vector2i(q, r))
	for c: Vector2i in cells:
		var list: Array[int] = []
		for d: Vector2i in DIRS:
			if _index.has(c + d):
				list.append(int(_index[c + d]))
		near.append(list)
		stacks.append([])
		# a corner has three neighbours and lies R from the middle on two axes
		closed.append(list.size() == 3 and across >= R)
	_deal()
	events.append({"type": "ready"})

# --- reading ---

func is_over() -> bool:
	return phase == Phase.OVER

## The colours offered at `lv`.
static func colours_at(lv: int) -> int:
	var n := COLOURS_FROM
	for at: int in COLOUR_AT:
		if lv >= at:
			n += 1
	return mini(n, COLOURS_MOST)

## The score that ends level `lv`.
static func goal(lv: int) -> int:
	return 10 * lv * (lv + 3)

## The score level `lv` began at.
static func floor_of(lv: int) -> int:
	return 0 if lv <= 1 else goal(lv - 1)

## The mats of one colour on top of `stack`.
static func run_of(stack: Array) -> int:
	var n := 0
	for i in range(stack.size() - 1, -1, -1):
		if stack[i] != stack[stack.size() - 1]:
			break
		n += 1
	return n

## How many colours a stack changes through, bottom to top.
static func runs_of(stack: Array) -> int:
	var n := 0
	for i in stack.size():
		if i == 0 or stack[i] != stack[i - 1]:
			n += 1
	return n

func can_place(cell: int) -> bool:
	return phase == Phase.PLAY and cell >= 0 and cell < cells.size() and not closed[cell] and (stacks[cell] as Array).is_empty()

func empties() -> int:
	var n := 0
	for i in cells.size():
		if not closed[i] and (stacks[i] as Array).is_empty():
			n += 1
	return n

func is_full() -> bool:
	return empties() == 0

func mats() -> int:
	var n := 0
	for s: Array in stacks:
		n += s.size()
	return n

# --- playing ---

## The hand's stack `slot` set on `cell`, and everything that follows.
func place(slot: int, cell: int) -> bool:
	if slot < 0 or slot >= HAND or (hand[slot] as Array).is_empty() or not can_place(cell):
		return false
	stacks[cell] = (hand[slot] as Array).duplicate()
	hand[slot] = []
	placed += 1
	events.append({"type": "place", "slot": slot, "cell": cell, "stack": (stacks[cell] as Array).duplicate()})
	var chain := _settle([cell])
	best_chain = maxi(best_chain, chain)
	_levels()
	if _hand_empty():
		_deal()
	_check()
	return true

## The brush: a stack taken off the tray. Nothing is scored.
func sweep(cell: int) -> bool:
	if phase != Phase.PLAY or sweeps <= 0 or cell < 0 or cell >= cells.size() or (stacks[cell] as Array).is_empty():
		return false
	sweeps -= 1
	events.append({"type": "sweep", "cell": cell, "n": (stacks[cell] as Array).size()})
	stacks[cell] = []
	_check()
	return true

## A fresh hand for the one held.
func redeal() -> bool:
	if phase != Phase.PLAY or deals <= 0:
		return false
	deals -= 1
	_deal(true)
	return true

## The Second chance (arcade/boosters.gd): the tallest stacks are taken off
## and the run goes on.
func revive() -> void:
	var order := range(cells.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var sa: int = (stacks[a] as Array).size()
		var sb: int = (stacks[b] as Array).size()
		return sa > sb if sa != sb else a < b)
	var took: Array[int] = []
	for i: int in order:
		if took.size() >= REVIVE_TAKES or (stacks[i] as Array).is_empty():
			break
		took.append(i)
		stacks[i] = []
	phase = Phase.PLAY
	_tight = false
	events.append({"type": "revive", "cells": took})

# --- the rules ---

## Gathers and puts away from the places in `dirty` until nothing moves.
## Returns how many stacks were put away.
func _settle(dirty: Array) -> int:
	var chain := 0
	while not dirty.is_empty():
		var c: int = dirty.pop_front()
		var here: Array = stacks[c]
		if here.is_empty():
			continue
		var col: int = here[here.size() - 1]
		var group := _group(c, col)
		var target := c
		if group.size() > 1:
			target = _pick(group, c)
			# each stack hands its mats to the one a step nearer the target,
			# the furthest first, so a line of three gathers end to end
			var parent := {target: -1}
			var order: Array[int] = [target]
			var k := 0
			while k < order.size():
				for n: int in near[order[k]]:
					if group.has(n) and not parent.has(n):
						parent[n] = order[k]
						order.append(n)
				k += 1
			for i in range(order.size() - 1, 0, -1):
				var from: int = order[i]
				var to: int = parent[from]
				var s: Array = stacks[from]
				var n := run_of(s)
				s.resize(s.size() - n)
				for j in n:
					(stacks[to] as Array).append(col)
				events.append({"type": "move", "from": from, "to": to, "col": col, "n": n})
				if not s.is_empty() and not dirty.has(from):
					dirty.append(from)
		var t: Array = stacks[target]
		var run := run_of(t)
		if run >= CLEAR:
			chain += 1
			t.resize(t.size() - run)
			var pts := run * chain
			score += pts
			cleared += run
			events.append({"type": "clear", "cell": target, "col": col, "n": run, "chain": chain, "pts": pts})
			if not t.is_empty() and not dirty.has(target):
				dirty.append(target)
	return chain

## The stacks that touch `c`, one after another, with `col` on top.
func _group(c: int, col: int) -> Array[int]:
	var out: Array[int] = [c]
	var k := 0
	while k < out.size():
		for n: int in near[out[k]]:
			var s: Array = stacks[n]
			if not s.is_empty() and s[s.size() - 1] == col and not out.has(n):
				out.append(n)
		k += 1
	return out

## Which stack of a group takes the others' mats: the one of the fewest
## colours, then the one with the most of this colour on top, then the one
## that was just touched.
func _pick(group: Array[int], touched: int) -> int:
	var best := -1
	var best_key := Vector3i.ZERO
	for g: int in group:
		var key := Vector3i(-runs_of(stacks[g]), run_of(stacks[g]), 1 if g == touched else 0)
		if best < 0 or key > best_key:
			best = g
			best_key = key
	return best

func _levels() -> void:
	while score >= goal(level):
		level += 1
		var ev := {"type": "level", "n": level, "open": -1, "colour": -1, "tool": ""}
		if OPENS_AT.has(level):
			var shut: Array[int] = []
			for i in cells.size():
				if closed[i]:
					shut.append(i)
			if not shut.is_empty():
				var pick: int = shut[rng.randi_range(0, shut.size() - 1)]
				closed[pick] = false
				ev.open = pick
		if colours_at(level) > colours_at(level - 1):
			ev.colour = colours_at(level) - 1
		if level % 2 == 0 and sweeps < TOOLS_MOST:
			sweeps += 1
			ev.tool = "sweep"
		elif level % 2 == 1 and deals < TOOLS_MOST:
			deals += 1
			ev.tool = "deal"
		events.append(ev)

func _hand_empty() -> bool:
	for s: Array in hand:
		if not s.is_empty():
			return false
	return true

func _deal(fresh := false) -> void:
	hand.clear()
	for i in HAND:
		hand.append(_stack())
	events.append({"type": "deal", "fresh": fresh, "hand": hand.duplicate(true)})

## One stack for the hand: two to TALL_MOST mats in one, two or three runs,
## more of the mixed ones as the levels go.
func _stack() -> Array:
	var colours := colours_at(level)
	var mixed := minf(0.5 + 0.04 * level, 0.8)
	var runs := 1
	if rng.randf() < mixed:
		runs = 3 if rng.randf() < minf(0.1 + 0.03 * level, 0.4) else 2
	var out: Array = []
	var last := -1
	for k in runs:
		var col := rng.randi_range(0, colours - 1)
		while col == last:
			col = rng.randi_range(0, colours - 1)
		last = col
		var room := TALL_MOST - out.size() - (runs - k - 1)
		var n := rng.randi_range(1, mini(3 if runs > 1 else 4, room))
		if runs == 1:
			n = maxi(n, 2)
		for j in n:
			out.append(col)
	return out

## The tray's room after a move: tight with few places left, full with a
## brush still held (a stack must be taken off), over without one.
func _check() -> void:
	var left := empties()
	if left == 0:
		if sweeps > 0:
			events.append({"type": "full"})
		else:
			phase = Phase.OVER
			events.append({"type": "over"})
		return
	var tight := left <= TIGHT
	if tight and not _tight:
		events.append({"type": "tight"})
	_tight = tight
