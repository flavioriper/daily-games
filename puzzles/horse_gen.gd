extends RefCounted

## Enclose the Horse. A meadow of grass with a few ponds in it, a horse
## standing somewhere on it and a couple of apples lying about. The player
## builds fences on grass cells, from a limited stock, until the horse --
## which walks up, down, left and right, never through a fence or a pond --
## can no longer reach the edge of the meadow. Every grass cell it can still
## reach is penned and scores a point; an apple in the pen scores three more.
##
## The daily framing: the generator searches for a pen it can close within the
## fence budget and sets that pen's score as the target. The player must pen
## at least that much using no more fences than the budget. Beating the target
## is allowed and is the whole sport.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const APPLE_POINTS := 3
## Pen searches per meadow; more finds tighter targets but costs start-up time.
const SEARCHES := 80

## A meadow with a pen the budget can close. `ponds` is how many pools of
## water to lay, `apples` how many apples to drop. `ok` is false when no
## meadow with a worthwhile pen turned up.
static func generate(rng: RandomNumberGenerator, w: int, h: int, budget: int,
		ponds: int, apples: int) -> Dictionary:
	for _attempt in 40:
		var out := _lay_meadow(rng, w, h, ponds, apples)
		if out.is_empty():
			continue
		var best := _best_pen(rng, out, budget)
		if best.is_empty() or int(best.score) < 4:
			continue
		out["budget"] = budget
		out["target"] = int(best.score)
		out["solution_walls"] = best.walls
		out["solution_pen"] = best.pen
		out["ok"] = true
		return out
	return {"w": w, "h": h, "water": [], "horse": Vector2i(-1, -1), "apples": [],
		"budget": budget, "target": 0, "solution_walls": [], "solution_pen": [], "ok": false}

static func in_bounds(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

static func on_border(c: Vector2i, w: int, h: int) -> bool:
	return c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == h - 1

## Ponds, a horse and apples on a bare meadow. Empty when the horse found no
## room to stand.
static func _lay_meadow(rng: RandomNumberGenerator, w: int, h: int, ponds: int, apples: int) -> Dictionary:
	var water: Dictionary = {}
	for _p in ponds:
		var seed := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var size := rng.randi_range(2, 4)
		var pool: Array = [seed]
		water[seed] = true
		var guard := 0
		while pool.size() < size and guard < 20:
			guard += 1
			var from: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
			var n: Vector2i = from + DIRS[rng.randi_range(0, 3)]
			if in_bounds(n, w, h) and not water.has(n):
				water[n] = true
				pool.append(n)
	# The horse stands inside, on grass, with room to wander: at least two
	# grass neighbours, or a pen of one cell closes for nothing.
	var horse := Vector2i(-1, -1)
	for _try in 60:
		var c := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if water.has(c):
			continue
		var open := 0
		for d in DIRS:
			if not water.has(c + d):
				open += 1
		if open >= 2:
			horse = c
			break
	if horse.x < 0:
		return {}
	var apple_set: Dictionary = {}
	var guard := 0
	while apple_set.size() < apples and guard < 80:
		guard += 1
		var c := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if water.has(c) or c == horse or apple_set.has(c):
			continue
		apple_set[c] = true
	return {"w": w, "h": h, "water": water.keys(), "horse": horse, "apples": apple_set.keys()}

## The fences that close `pen`: every cell beside it that is neither in it
## nor water. Border cells count -- a fence may stand on the edge.
static func walls_for(pen: Dictionary, water: Dictionary, w: int, h: int) -> Dictionary:
	var walls: Dictionary = {}
	for c in pen:
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_bounds(n, w, h) or pen.has(n) or water.has(n):
				continue
			walls[n] = true
	return walls

static func score_of(pen: Dictionary, apples: Dictionary) -> int:
	var s := pen.size()
	for c in pen:
		if apples.has(c):
			s += APPLE_POINTS
	return s

## Grows pens out from the horse, many times over, and keeps the best one the
## budget can close. Each growth step takes the frontier cell that adds the
## fewest new fences (ties broken at random), which is what makes the pens
## lean on ponds and on each other rather than sprawl.
static func _best_pen(rng: RandomNumberGenerator, meadow: Dictionary, budget: int) -> Dictionary:
	var w: int = meadow.w
	var h: int = meadow.h
	var water: Dictionary = {}
	for c in meadow.water:
		water[c] = true
	var apples: Dictionary = {}
	for c in meadow.apples:
		apples[c] = true
	var horse: Vector2i = meadow.horse
	var best: Dictionary = {}
	var max_steps: int = (w * h) / 2
	for _s in SEARCHES:
		var pen: Dictionary = {horse: true}
		var walls := walls_for(pen, water, w, h)
		_consider(best, pen, walls, apples, budget)
		for _step in max_steps:
			var frontier: Array = []
			for c in pen:
				for d in DIRS:
					var n: Vector2i = c + d
					if not in_bounds(n, w, h) or pen.has(n) or water.has(n) or on_border(n, w, h):
						continue
					if not frontier.has(n):
						frontier.append(n)
			if frontier.is_empty():
				break
			# A handful of random candidates, the cheapest of them taken.
			var pick := Vector2i(-1, -1)
			var pick_cost := 1 << 30
			for _k in mini(3, frontier.size()):
				var cand: Vector2i = frontier[rng.randi_range(0, frontier.size() - 1)]
				var cost := 0
				for d in DIRS:
					var n: Vector2i = cand + d
					if in_bounds(n, w, h) and not pen.has(n) and not water.has(n) and not walls.has(n):
						cost += 1
				if walls.has(cand):
					cost -= 1
				if cost < pick_cost or (cost == pick_cost and rng.randf() < 0.5):
					pick = cand
					pick_cost = cost
			pen[pick] = true
			walls = walls_for(pen, water, w, h)
			_consider(best, pen, walls, apples, budget)
	return best

static func _consider(best: Dictionary, pen: Dictionary, walls: Dictionary, apples: Dictionary, budget: int) -> void:
	if walls.size() > budget:
		return
	var s := score_of(pen, apples)
	if best.is_empty() or s > int(best.score) or (s == int(best.score) and walls.size() < (best.walls as Array).size()):
		best["score"] = s
		best["pen"] = pen.keys()
		best["walls"] = walls.keys()

## Where the horse can get to from `horse`, walking orthogonally over cells
## that are neither water nor fenced. `escaped` is whether that includes a
## border cell; `gaps` lists the border cells it reaches, which is where the
## pen is open.
static func reach(horse: Vector2i, w: int, h: int, water: Dictionary, walls: Dictionary) -> Dictionary:
	var seen: Dictionary = {horse: true}
	var queue: Array = [horse]
	var gaps: Array = []
	var i := 0
	while i < queue.size():
		var c: Vector2i = queue[i]
		i += 1
		if on_border(c, w, h):
			gaps.append(c)
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_bounds(n, w, h) or seen.has(n) or water.has(n) or walls.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return {"cells": seen, "escaped": not gaps.is_empty(), "gaps": gaps}

## Whether `walls` pens the horse within the budget and scores the target.
static func is_valid_solution(horse: Vector2i, w: int, h: int, water: Dictionary,
		walls: Dictionary, apples: Dictionary, budget: int, target: int) -> bool:
	if walls.size() > budget:
		return false
	var r := reach(horse, w, h, water, walls)
	if r.escaped:
		return false
	return score_of(r.cells, apples) >= target
