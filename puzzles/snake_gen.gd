extends RefCounted

## Snake Apple. A snake lies in a walled meadow with a few apples about and a
## burrow somewhere. One tap moves it one cell: the head goes forward, the
## tail follows, and it may not cross a boulder, its own body, or turn back on
## itself. Eating an apple makes it a cell longer. Once every apple is eaten
## the burrow opens, and slipping the head into it finishes the day. The
## trouble is the room: the snake is long for the space, and a careless route
## leaves it coiled with nowhere to go.
##
## Generation walks a snake at random through the meadow, dropping apples on
## cells the head is about to enter for the first time, and ends at a fresh
## cell, which becomes the burrow. Cells the walk never touched become
## boulders, most of them, so the walk is a route through the puzzle -- and a
## breadth-first solver over snake states then finds the shortest one, which
## is also what hints and Check use in play.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## Snake states the solver will expand before giving up.
const SOLVE_LIMIT := 60000

## A meadow with a snake of `length`, `apples` apples, a burrow at the end of
## a walk of `min_steps` to `max_steps` moves, and boulders on a `fill` share
## of the cells the walk never used. `ok` is false when nothing worthwhile
## turned up.
static func generate(rng: RandomNumberGenerator, w: int, h: int, length: int, apples: int,
		min_steps: int, max_steps: int, fill: float) -> Dictionary:
	for _attempt in 200:
		var snake := _random_snake(rng, w, h, length)
		if snake.is_empty():
			continue
		var initial: Dictionary = {}
		for c in snake:
			initial[c] = true
		var body: Array = snake.duplicate()
		var visited: Dictionary = {}
		var apple_set: Dictionary = {}
		var hole := Vector2i(-1, -1)
		var target_steps := rng.randi_range(min_steps, max_steps)
		var steps := 0
		while steps < max_steps:
			var head: Vector2i = body[0]
			var options: Array = []
			var fresh_options: Array = []
			for d in DIRS:
				var n: Vector2i = head + d
				if not _fits(n, body, {}, w, h, false):
					continue
				options.append(d)
				if not visited.has(n) and not initial.has(n):
					fresh_options.append(d)
			if options.is_empty():
				break
			# Fresh ground most of the time, so the walk sprawls instead of
			# circling in the room it already has.
			var pool: Array = fresh_options if (not fresh_options.is_empty() and rng.randf() < 0.75) else options
			var d: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
			var n: Vector2i = head + d
			steps += 1
			var fresh := not visited.has(n) and not initial.has(n)
			visited[n] = true
			var grow := false
			if fresh and apple_set.size() < apples and steps >= 2:
				# Spread the apples over the first three quarters of the walk.
				var need := apples - apple_set.size()
				var remaining := maxi(1, int(target_steps * 0.75) - steps)
				if rng.randf() < float(need) / float(remaining):
					apple_set[n] = true
					grow = true
			body.insert(0, n)
			if not grow:
				body.pop_back()
			if not grow and fresh and steps >= target_steps and apple_set.size() == apples:
				hole = n
				break
		if hole.x < 0:
			continue
		var walls: Dictionary = {}
		for y in h:
			for x in w:
				var c := Vector2i(x, y)
				if initial.has(c) or visited.has(c):
					continue
				if rng.randf() < fill:
					walls[c] = true
		var solution := solve(w, h, walls, apple_set, hole, snake, {})
		if solution.is_empty() or solution.size() < int(min_steps * 0.6):
			continue
		return {"w": w, "h": h, "walls": walls.keys(), "apples": apple_set.keys(), "hole": hole,
			"snake": snake, "solution": solution, "ok": true}
	return {"w": w, "h": h, "walls": [], "apples": [], "hole": Vector2i(-1, -1),
		"snake": [], "solution": [], "ok": false}

static func in_bounds(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

## A self-avoiding walk of `length` cells, head first, or [] when it boxed
## itself in.
static func _random_snake(rng: RandomNumberGenerator, w: int, h: int, length: int) -> Array:
	var cells: Array = [Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))]
	var guard := 0
	while cells.size() < length and guard < 40:
		guard += 1
		var tail: Vector2i = cells[cells.size() - 1]
		var options: Array = []
		for d in DIRS:
			var n: Vector2i = tail + d
			if in_bounds(n, w, h) and not cells.has(n):
				options.append(n)
		if options.is_empty():
			return []
		cells.append(options[rng.randi_range(0, options.size() - 1)])
	return cells if cells.size() == length else []

## Whether the head may step onto `n`: inside the meadow, not a boulder, not
## the snake's own body -- except the tail, which moves out of the way, and
## except that the neck is never allowed, since that is turning back on
## itself. `growing` is whether this step eats an apple, in which case the tail
## stays put and is not free either.
static func _fits(n: Vector2i, snake: Array, walls: Dictionary, w: int, h: int, growing: bool) -> bool:
	if not in_bounds(n, w, h) or walls.has(n):
		return false
	var last := snake.size() - 1
	for i in snake.size():
		if snake[i] != n:
			continue
		if i == last and last >= 2 and not growing:
			continue
		return false
	return true

## Whether the snake may move by `d` from `snake` with `eaten` apples so far.
## The burrow is a boulder until every apple is eaten.
static func can_move(d: Vector2i, snake: Array, walls: Dictionary, apples: Dictionary,
		eaten: Dictionary, hole: Vector2i, w: int, h: int) -> bool:
	var n: Vector2i = snake[0] + d
	if n == hole and eaten.size() < apples.size():
		return false
	var growing := apples.has(n) and not eaten.has(n)
	return _fits(n, snake, walls, w, h, growing)

## The snake after moving by `d`; the caller has checked can_move.
static func moved(d: Vector2i, snake: Array, apples: Dictionary, eaten: Dictionary) -> Array:
	var n: Vector2i = snake[0] + d
	var out: Array = snake.duplicate()
	out.insert(0, n)
	if not (apples.has(n) and not eaten.has(n)):
		out.pop_back()
	return out

## The shortest run of moves from this state to the burrow with every apple
## eaten, as direction vectors, or [] when there is none (or the search ran
## out of patience). Breadth-first over (snake, apples eaten) states, each
## packed into one integer: six bits per body cell, then the length, then the
## apple mask -- which is why a meadow has at most 64 cells and a snake at
## most nine.
static func solve(w: int, h: int, walls: Dictionary, apples: Dictionary, hole: Vector2i,
		snake: Array, eaten: Dictionary, limit: int = SOLVE_LIMIT) -> Array:
	var apple_list: Array = apples.keys()
	apple_list.sort_custom(func(a, b): return a.y * w + a.x < b.y * w + b.x)
	var bit_of: Dictionary = {}
	for i in apple_list.size():
		bit_of[apple_list[i]] = 1 << i
	var full := (1 << apple_list.size()) - 1
	var mask0 := 0
	for c in eaten:
		mask0 |= int(bit_of.get(c, 0))
	if snake[0] == hole and mask0 == full:
		return []
	var start_key := _key(snake, mask0, w)
	var queue: Array = [[snake, mask0]]
	var parent: Dictionary = {start_key: null}
	var i := 0
	var expanded := 0
	while i < queue.size() and expanded < limit:
		var cur: Array = queue[i]
		i += 1
		expanded += 1
		var body: Array = cur[0]
		var mask: int = cur[1]
		var cur_key := _key(body, mask, w)
		for di in DIRS.size():
			var d: Vector2i = DIRS[di]
			var n: Vector2i = body[0] + d
			if n == hole and mask != full:
				continue
			var growing := bit_of.has(n) and (mask & int(bit_of[n])) == 0
			if not _fits(n, body, walls, w, h, growing):
				continue
			var next: Array = body.duplicate()
			next.insert(0, n)
			if not growing:
				next.pop_back()
			var next_mask := mask | (int(bit_of[n]) if growing else 0)
			var key := _key(next, next_mask, w)
			if parent.has(key):
				continue
			parent[key] = [cur_key, di]
			if n == hole and next_mask == full:
				return _unwind(parent, key, start_key)
			queue.append([next, next_mask])
	return []

static func _key(snake: Array, mask: int, w: int) -> int:
	var key := 0
	for i in snake.size():
		var c: Vector2i = snake[i]
		key |= (c.y * w + c.x) << (6 * i)
	key |= snake.size() << 54
	key |= mask << 58
	return key

static func _unwind(parent: Dictionary, key: int, start_key: int) -> Array:
	var out: Array = []
	while key != start_key:
		var link = parent[key]
		out.append(DIRS[int(link[1])])
		key = int(link[0])
	out.reverse()
	return out
