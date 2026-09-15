extends RefCounted

## Enclose the Horse. A meadow cut up by streams and pools of water, with a
## few boulders lying on it, a horse standing somewhere and some apples about.
## The player builds fences on grass cells, from a limited stock, until the
## horse -- which walks up, down, left and right, never through a fence, a
## boulder or water -- can no longer reach the edge of the meadow. Every cell
## it can still reach is penned and scores a point; an apple in the pen scores
## three more. The water and the boulders do most of the enclosing; the
## fences close the gaps. That is the whole sport: the fewer gaps you need to
## close, the more meadow you keep.
##
## The daily framing: the generator searches for a pen it can close within the
## fence budget and sets that pen's score as the target. The player must pen
## at least that much using no more fences than the budget, then submit.
## Beating the target is allowed and is the point.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const APPLE_POINTS := 3
## Pen searches per meadow; more finds tighter targets but costs start-up time.
const SEARCHES := 80
## A day is not worth playing under this target.
const MIN_TARGET := 8

## A meadow with a pen the budget can close. `streams` is how many water
## courses to run across it, `pools` how many still pools to lay, `stones` how
## many boulders, `apples` how many apples. `ok` is false when no meadow with a
## worthwhile pen turned up.
static func generate(rng: RandomNumberGenerator, w: int, h: int, budget: int,
		streams: int, pools: int, stones: int, apples: int) -> Dictionary:
	for _attempt in 40:
		var out := _lay_meadow(rng, w, h, streams, pools, stones)
		if out.is_empty():
			continue
		var best := _best_pen(rng, out, budget)
		if best.is_empty() or int(best.score) < MIN_TARGET:
			continue
		# Apples lie inside the pen the search found, never beside it: a cell
		# beside the pen is one of its fences, and a fence cannot stand on an
		# apple, so an apple there would leave the reference pen unbuildable.
		# Inside, they are the bait the target is counted with.
		var apple_set: Dictionary = {}
		var spots: Array = []
		for c in best.pen:
			if c != out.horse:
				spots.append(c)
		var guard := 0
		while apple_set.size() < apples and not spots.is_empty() and guard < 80:
			guard += 1
			apple_set[spots[rng.randi_range(0, spots.size() - 1)]] = true
		var pen: Dictionary = {}
		for c in best.pen:
			pen[c] = true
		out["apples"] = apple_set.keys()
		out["budget"] = budget
		out["target"] = score_of(pen, apple_set)
		out["solution_walls"] = best.walls
		out["solution_pen"] = best.pen
		out["ok"] = true
		return out
	return {"w": w, "h": h, "water": [], "stones": [], "horse": Vector2i(-1, -1), "apples": [],
		"budget": budget, "target": 0, "solution_walls": [], "solution_pen": [], "ok": false}

static func in_bounds(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

static func on_border(c: Vector2i, w: int, h: int) -> bool:
	return c.x == 0 or c.y == 0 or c.x == w - 1 or c.y == h - 1

## Water, boulders and a horse on a bare meadow; the apples come once the pen
## is known. Empty when the horse found nowhere worth standing.
static func _lay_meadow(rng: RandomNumberGenerator, w: int, h: int,
		streams: int, pools: int, stones: int) -> Dictionary:
	var water: Dictionary = {}
	# Streams: random walks that mostly keep going straight, so they read as
	# channels and corridors rather than as scattered puddles.
	for _s in streams:
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var run := rng.randi_range(int(mini(w, h) * 0.5), int(maxi(w, h) * 0.7))
		for _i in run:
			water[c] = true
			if rng.randf() > 0.72:
				var turn: Vector2i = DIRS[rng.randi_range(0, 3)]
				if turn != -d:
					d = turn
			var n := c + d
			if not in_bounds(n, w, h):
				d = Vector2i(-d.y, d.x)
				n = c + d
				if not in_bounds(n, w, h):
					break
			c = n
	for _p in pools:
		var seed := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var size := rng.randi_range(3, 5)
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
	# Boulders lie on grass and block the horse the way water does.
	var stone_set: Dictionary = {}
	var guard := 0
	while stone_set.size() < stones and guard < 80:
		guard += 1
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		if water.has(c) or stone_set.has(c):
			continue
		stone_set[c] = true
	var blocked: Dictionary = water.duplicate()
	for c in stone_set:
		blocked[c] = true
	# The horse: of a few dozen interior grass cells, the one that can wander
	# furthest -- and it must be able to reach the edge, or there is nothing
	# to do. A meadow that pens it for free is thrown away.
	var horse := Vector2i(-1, -1)
	var best_reach := 0
	var reach_cells: Dictionary = {}
	for _try in 40:
		var c := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(1, h - 2))
		if blocked.has(c):
			continue
		var r := reach(c, w, h, blocked, {})
		if not r.escaped:
			continue
		if r.cells.size() > best_reach:
			best_reach = r.cells.size()
			horse = c
			reach_cells = r.cells
	if horse.x < 0 or best_reach < (w * h) / 4:
		return {}
	return {"w": w, "h": h, "water": water.keys(), "stones": stone_set.keys(),
		"horse": horse, "apples": []}

## The fences that close `pen`: every cell beside it that is neither in it
## nor blocked. Border cells count -- a fence may stand on the edge.
static func walls_for(pen: Dictionary, blocked: Dictionary, w: int, h: int) -> Dictionary:
	var walls: Dictionary = {}
	for c in pen:
		for d in DIRS:
			var n: Vector2i = c + d
			if not in_bounds(n, w, h) or pen.has(n) or blocked.has(n):
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
## budget can close. Each growth step takes the cheapest of a few random
## frontier cells -- the one that adds the fewest new fences -- which is what
## makes the pens follow the water rather than sprawl across open grass.
static func _best_pen(rng: RandomNumberGenerator, meadow: Dictionary, budget: int) -> Dictionary:
	var w: int = meadow.w
	var h: int = meadow.h
	var blocked: Dictionary = {}
	for c in meadow.water:
		blocked[c] = true
	for c in meadow.stones:
		blocked[c] = true
	var apples: Dictionary = {}
	var horse: Vector2i = meadow.horse
	var best: Dictionary = {}
	var max_steps: int = (w * h) * 2 / 3
	for _s in SEARCHES:
		var pen: Dictionary = {}
		var walls: Dictionary = {}
		var frontier: Dictionary = {}
		_absorb(horse, pen, walls, frontier, blocked, w, h)
		_consider(best, pen, walls, apples, budget)
		for _step in max_steps:
			if frontier.is_empty():
				break
			var keys := frontier.keys()
			var pick := Vector2i(-1, -1)
			var pick_cost := 1 << 30
			for _k in mini(3, keys.size()):
				var cand: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
				var cost := -1 if walls.has(cand) else 0
				for d in DIRS:
					var n: Vector2i = cand + d
					if in_bounds(n, w, h) and not pen.has(n) and not blocked.has(n) and not walls.has(n):
						cost += 1
				if cost < pick_cost or (cost == pick_cost and rng.randf() < 0.5):
					pick = cand
					pick_cost = cost
			_absorb(pick, pen, walls, frontier, blocked, w, h)
			_consider(best, pen, walls, apples, budget)
	return best

## Takes `c` into the pen, keeping the fence set and the frontier current.
static func _absorb(c: Vector2i, pen: Dictionary, walls: Dictionary, frontier: Dictionary,
		blocked: Dictionary, w: int, h: int) -> void:
	pen[c] = true
	walls.erase(c)
	frontier.erase(c)
	for d in DIRS:
		var n: Vector2i = c + d
		if not in_bounds(n, w, h) or pen.has(n) or blocked.has(n):
			continue
		walls[n] = true
		if not on_border(n, w, h):
			frontier[n] = true

static func _consider(best: Dictionary, pen: Dictionary, walls: Dictionary, apples: Dictionary, budget: int) -> void:
	if walls.size() > budget:
		return
	var s := score_of(pen, apples)
	if best.is_empty() or s > int(best.score) or (s == int(best.score) and walls.size() < (best.walls as Array).size()):
		best["score"] = s
		best["pen"] = pen.keys()
		best["walls"] = walls.keys()

## Where the horse can get to from `horse`, walking orthogonally over cells
## that are neither blocked nor fenced. `escaped` is whether that includes a
## border cell; `gaps` lists the border cells it reaches, which is where the
## pen is open.
static func reach(horse: Vector2i, w: int, h: int, blocked: Dictionary, walls: Dictionary) -> Dictionary:
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
			if not in_bounds(n, w, h) or seen.has(n) or blocked.has(n) or walls.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return {"cells": seen, "escaped": not gaps.is_empty(), "gaps": gaps}

## Whether `walls` pens the horse within the budget and scores the target.
static func is_valid_solution(horse: Vector2i, w: int, h: int, blocked: Dictionary,
		walls: Dictionary, apples: Dictionary, budget: int, target: int) -> bool:
	if walls.size() > budget:
		return false
	var r := reach(horse, w, h, blocked, walls)
	if r.escaped:
		return false
	return score_of(r.cells, apples) >= target
