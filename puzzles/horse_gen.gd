extends RefCounted

## Horse Pen's meadows: a field cut up by streams and pools, a few boulders on
## it, a horse standing somewhere, and things lying about that are worth
## having in the pen or worth keeping out of it. The player drops hay bales
## on bare grass, from a limited stock, until the horse -- which walks up,
## down, left and right, never through a bale, a boulder or water -- can no
## longer reach the edge of the field. Every cell it can still reach is
## penned and scores one; an apple in the pen scores three more, the golden
## apple ten more, and a beehive takes five away. A tunnel's two mouths are
## one step apart for the horse, wherever they lie.
##
## A cell is its index, `y * w + x`. A meadow is plain data (`prepare` adds
## the neighbour lists), so the miner (tools/mine_horse.gd), the bank's
## reader, the state class and the tutorial all share it.
##
## The daily framing: `search` looks for the best pen the stock can close --
## pens grown out from the horse along the water, then a long local search
## over the bales -- and the bank keeps that score as `best`. The day's
## target is a share of it by band (`BANDS[band].share`), so the target is
## always reachable and beating it is the point.

const NONE := 0
const WATER := 1
const STONE := 2

const APPLE := 1
const GOLD := 2
const BEE := 3
## What a thing in the pen adds to the cell's own point.
const POINTS := [0, 3, 10, -5]

## Per band: the field, the stock of bales, what lies on it, the share of the
## best pen found that the day asks for, and the fewest cells that pen may
## hold (`pen`): a small pen is a dull day.
const BANDS := [
	{"w": 7, "h": 8, "budget": 7, "streams": 2, "pools": 1, "stones": 4,
		"apples": 0, "gold": 0, "bees": 0, "tunnels": 0, "share": 0.8, "pen": 14},
	{"w": 8, "h": 10, "budget": 8, "streams": 3, "pools": 1, "stones": 5,
		"apples": 3, "gold": 0, "bees": 0, "tunnels": 0, "share": 0.85, "pen": 20},
	{"w": 9, "h": 11, "budget": 10, "streams": 3, "pools": 2, "stones": 6,
		"apples": 3, "gold": 1, "bees": 2, "tunnels": 0, "share": 0.9, "pen": 26},
	{"w": 10, "h": 12, "budget": 11, "streams": 4, "pools": 2, "stones": 7,
		"apples": 3, "gold": 1, "bees": 3, "tunnels": 1, "share": 0.9, "pen": 30},
]
## Pens grown per meadow, and the local search's steps after them: the phone's
## own (a fallback when the bank is missing) and the miner's.
const GROWS_LIVE := 40
const STEPS_LIVE := 400
const GROWS_MINE := 200
const STEPS_MINE := 120000
## A pen over this share of the field was nearly closed already.
const MAX_PEN := 0.62

static func band_of(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## The day's target for a pen whose best known score is `best`.
static func target_for(best: int, band: int) -> int:
	return maxi(1, int(floor(best * float(band_of(band).share))))

## A meadow with its best pen, or {} when none worth playing turned up.
static func generate(rng: RandomNumberGenerator, band: int,
		grows := GROWS_LIVE, steps := STEPS_LIVE) -> Dictionary:
	var spec := band_of(band)
	for _attempt in 400:
		var m := _lay(rng, spec)
		if m.is_empty():
			continue
		prepare(m)
		var found := search(rng, m, int(spec.budget), grows, steps)
		if found.is_empty():
			continue
		var walls: Array = found.walls
		# The stock has to matter: a pen closed with bales to spare is a day
		# with nothing to weigh.
		if walls.size() < int(spec.budget) - 1 or int(found.pen) < int(spec.pen) \
				or int(found.pen) > int(MAX_PEN * int(spec.w) * int(spec.h)):
			continue
		m["budget"] = int(spec.budget)
		m["best"] = int(found.score)
		m["sol"] = walls
		return m
	return {}

## The meadow as the bank keeps it: plain lists.
static func pack(m: Dictionary) -> Dictionary:
	var water: Array = []
	var stones: Array = []
	var apples: Array = []
	var gold: Array = []
	var bees: Array = []
	var block: PackedByteArray = m.block
	var item: PackedByteArray = m.item
	for i in block.size():
		if block[i] == WATER:
			water.append(i)
		elif block[i] == STONE:
			stones.append(i)
		match item[i]:
			APPLE: apples.append(i)
			GOLD: gold.append(i)
			BEE: bees.append(i)
	return {"w": m.w, "h": m.h, "horse": m.horse, "water": water, "stones": stones,
		"apples": apples, "gold": gold, "bees": bees, "tunnels": m.tunnels,
		"budget": m.budget, "best": m.best, "sol": m.sol}

## The bank's lists back into a meadow, prepared. {} when `d` is not one.
static func unpack(d: Dictionary) -> Dictionary:
	if not (d.has("w") and d.has("h") and d.has("horse")):
		return {}
	var w := int(d.w)
	var h := int(d.h)
	var block := PackedByteArray()
	block.resize(w * h)
	var item := PackedByteArray()
	item.resize(w * h)
	for i in d.get("water", []):
		block[int(i)] = WATER
	for i in d.get("stones", []):
		block[int(i)] = STONE
	for i in d.get("apples", []):
		item[int(i)] = APPLE
	for i in d.get("gold", []):
		item[int(i)] = GOLD
	for i in d.get("bees", []):
		item[int(i)] = BEE
	var tunnels: Array = []
	for pair in d.get("tunnels", []):
		tunnels.append([int(pair[0]), int(pair[1])])
	var sol: Array = []
	for i in d.get("sol", []):
		sol.append(int(i))
	var m := {"w": w, "h": h, "horse": int(d.horse), "block": block, "item": item,
		"tunnels": tunnels, "budget": int(d.get("budget", 0)), "best": int(d.get("best", 0)),
		"sol": sol}
	prepare(m)
	return m

## Adds what every walk needs: each cell's neighbours (`nb`, a tunnel's twin
## among them), the edge cells (`edge`), the twins (`twin`, -1 for none) and
## the cells a bale may stand on (`bare`).
static func prepare(m: Dictionary) -> void:
	var w: int = m.w
	var h: int = m.h
	var n := w * h
	var twin := PackedInt32Array()
	twin.resize(n)
	twin.fill(-1)
	for pair in m.tunnels:
		twin[int(pair[0])] = int(pair[1])
		twin[int(pair[1])] = int(pair[0])
	var nb: Array = []
	var edge := PackedByteArray()
	edge.resize(n)
	var bare := PackedByteArray()
	bare.resize(n)
	var block: PackedByteArray = m.block
	var item: PackedByteArray = m.item
	for i in n:
		var x := i % w
		var y := i / w
		var list := PackedInt32Array()
		if y > 0: list.append(i - w)
		if x < w - 1: list.append(i + 1)
		if y < h - 1: list.append(i + w)
		if x > 0: list.append(i - 1)
		if twin[i] >= 0: list.append(twin[i])
		nb.append(list)
		edge[i] = 1 if x == 0 or y == 0 or x == w - 1 or y == h - 1 else 0
		bare[i] = 1 if block[i] == NONE and item[i] == NONE and twin[i] < 0 and i != int(m.horse) else 0
	m["nb"] = nb
	m["edge"] = edge
	m["twin"] = twin
	m["bare"] = bare

## Where the horse can get to with `walls` standing (a byte a cell). `seen`
## marks the cells, `order` lists them as the walk found them (so the nearest
## come first), `dist` is each one's steps from the horse, `gaps` the edge
## cells among them -- where the pen is open -- and `score` what the pen is
## worth (meaningful once `gaps` is empty).
static func reach(m: Dictionary, walls: PackedByteArray) -> Dictionary:
	var n: int = int(m.w) * int(m.h)
	var seen := PackedByteArray()
	seen.resize(n)
	var dist := PackedInt32Array()
	dist.resize(n)
	var order := PackedInt32Array()
	var gaps := PackedInt32Array()
	var block: PackedByteArray = m.block
	var item: PackedByteArray = m.item
	var edge: PackedByteArray = m.edge
	var nb: Array = m.nb
	var horse: int = m.horse
	seen[horse] = 1
	order.append(horse)
	var head := 0
	var score := 0
	while head < order.size():
		var c := order[head]
		head += 1
		score += 1 + POINTS[item[c]]
		if edge[c] == 1:
			gaps.append(c)
		for k: int in nb[c]:
			if seen[k] == 1 or block[k] != NONE or walls[k] == 1:
				continue
			seen[k] = 1
			dist[k] = dist[c] + 1
			order.append(k)
	return {"seen": seen, "order": order, "dist": dist, "gaps": gaps, "score": score}

## The pen's score with `walls` standing, or minus the number of edge cells
## the horse still reaches when it is open. The search's inner loop: the
## scratch arrays are the caller's.
static func _eval(m: Dictionary, walls: PackedByteArray, seen: PackedByteArray,
		queue: PackedInt32Array) -> int:
	seen.fill(0)
	var block: PackedByteArray = m.block
	var item: PackedByteArray = m.item
	var edge: PackedByteArray = m.edge
	var nb: Array = m.nb
	var horse: int = m.horse
	seen[horse] = 1
	queue[0] = horse
	var head := 0
	var tail := 1
	var score := 0
	var gaps := 0
	while head < tail:
		var c := queue[head]
		head += 1
		score += 1 + POINTS[item[c]]
		gaps += edge[c]
		for k: int in nb[c]:
			if seen[k] == 1 or block[k] != NONE or walls[k] == 1:
				continue
			seen[k] = 1
			queue[tail] = k
			tail += 1
	return score if gaps == 0 else -gaps

## The best pen `budget` bales can close: {"score", "walls" (a list, pruned
## to the ones that matter), "pen" (cells penned)}, or {} when the horse
## cannot be penned at all.
static func search(rng: RandomNumberGenerator, m: Dictionary, budget: int,
		grows: int, steps: int) -> Dictionary:
	var n: int = int(m.w) * int(m.h)
	var seen := PackedByteArray()
	seen.resize(n)
	var queue := PackedInt32Array()
	queue.resize(n)
	var best_score := -(1 << 30)
	var best: PackedByteArray
	# Pens grown from the horse; the few best seed the local search.
	var seeds: Array = []
	for _g in grows:
		var grown := _grow(rng, m, budget)
		if grown.is_empty():
			continue
		var walls: PackedByteArray = grown.walls
		var s := _eval(m, walls, seen, queue)
		if s <= 0:
			continue
		seeds.append([s, walls])
		if s > best_score:
			best_score = s
			best = walls.duplicate()
	if seeds.is_empty():
		return {}
	seeds.sort_custom(func(a, b) -> bool: return a[0] > b[0])
	var starts := mini(4, seeds.size())
	var bare: PackedByteArray = m.bare
	var w: int = m.w
	var h: int = m.h
	for si in starts:
		var cur: PackedByteArray = (seeds[si][1] as PackedByteArray).duplicate()
		var cur_s: int = seeds[si][0]
		var list := PackedInt32Array()
		for i in n:
			if cur[i] == 1:
				list.append(i)
		var per := steps / starts
		for step in per:
			var temp := lerpf(1.6, 0.05, float(step) / per)
			# One or two bales moved: a step along the fence, a jump anywhere,
			# a bale added while there is stock, or one taken away.
			var undo: Array = []
			var moves := 1 if rng.randf() < 0.65 else 2
			for _mv in moves:
				var kind := rng.randf()
				if kind < 0.12 and list.size() < budget:
					var to := rng.randi_range(0, n - 1)
					if bare[to] == 1 and cur[to] == 0:
						cur[to] = 1
						list.append(to)
						undo.append([-1, to])
				elif kind < 0.2 and list.size() > 1:
					var k := rng.randi_range(0, list.size() - 1)
					var from := list[k]
					cur[from] = 0
					list.remove_at(k)
					undo.append([from, -1])
				elif not list.is_empty():
					var k := rng.randi_range(0, list.size() - 1)
					var from := list[k]
					var to := -1
					if kind < 0.85:
						var x := from % w + rng.randi_range(-1, 1)
						var y := from / w + rng.randi_range(-1, 1)
						if x >= 0 and y >= 0 and x < w and y < h:
							to = y * w + x
					else:
						to = rng.randi_range(0, n - 1)
					if to >= 0 and bare[to] == 1 and cur[to] == 0:
						cur[from] = 0
						cur[to] = 1
						list[k] = to
						undo.append([from, to])
			if undo.is_empty():
				continue
			var s := _eval(m, cur, seen, queue)
			var keep := s > 0 and (s >= cur_s or rng.randf() < exp(float(s - cur_s) / temp))
			if keep:
				cur_s = s
				if s > best_score:
					best_score = s
					best = cur.duplicate()
			else:
				for u in range(undo.size() - 1, -1, -1):
					var from: int = undo[u][0]
					var to: int = undo[u][1]
					if to >= 0:
						cur[to] = 0
						list.remove_at(list.find(to))
					if from >= 0:
						cur[from] = 1
						list.append(from)
	if best_score <= 0:
		return {}
	# Only the bales the pen leans on: one whose removal changes nothing was
	# never part of the answer.
	for i in n:
		if best[i] == 0:
			continue
		best[i] = 0
		if _eval(m, best, seen, queue) != best_score:
			best[i] = 1
	var out: Array = []
	for i in n:
		if best[i] == 1:
			out.append(i)
	_eval(m, best, seen, queue)
	var pen := 0
	for i in n:
		pen += seen[i]
	return {"score": best_score, "walls": out, "pen": pen}

## One pen grown out from the horse: each step takes in the cheapest of a
## few of the cells along its fence -- the one that asks for the fewest new
## bales -- which is what makes a pen follow the water instead of sprawling
## over open grass. A cell no bale may stand on (an apple, a hive, a tunnel's
## mouth) is taken in with whatever took in its neighbour. Returns the widest
## fence within `budget` it passed through, or {} when it never had one.
static func _grow(rng: RandomNumberGenerator, m: Dictionary, budget: int) -> Dictionary:
	var n: int = int(m.w) * int(m.h)
	var pen := PackedByteArray()
	pen.resize(n)
	var fence := PackedByteArray()
	fence.resize(n)
	var count := [0]
	var best := {}
	var best_size := 0
	var size := [0]
	if not _absorb(m, int(m.horse), pen, fence, count, size):
		return {}
	var edge: PackedByteArray = m.edge
	var block: PackedByteArray = m.block
	var nb: Array = m.nb
	var max_steps := n * 2 / 3
	for _step in max_steps:
		if count[0] <= budget and size[0] > best_size:
			best_size = size[0]
			best = {"walls": fence.duplicate()}
		var cands := PackedInt32Array()
		for i in n:
			if fence[i] == 1 and edge[i] == 0:
				cands.append(i)
		if cands.is_empty():
			break
		var pick := -1
		var pick_cost := 1 << 30
		for _k in mini(3, cands.size()):
			var cand := cands[rng.randi_range(0, cands.size() - 1)]
			var cost := -1
			for k: int in nb[cand]:
				if pen[k] == 0 and block[k] == NONE and fence[k] == 0:
					cost += 1
			if cost < pick_cost or (cost == pick_cost and rng.randf() < 0.5):
				pick = cand
				pick_cost = cost
		if not _absorb(m, pick, pen, fence, count, size):
			break
	if count[0] <= budget and size[0] > best_size:
		best = {"walls": fence.duplicate()}
	return best

## Takes `c` into the pen, and with it every neighbour no bale may stand on.
## False when that reaches the edge: the pen cannot be closed this way.
static func _absorb(m: Dictionary, c: int, pen: PackedByteArray, fence: PackedByteArray,
		count: Array, size: Array) -> bool:
	var edge: PackedByteArray = m.edge
	var block: PackedByteArray = m.block
	var bare: PackedByteArray = m.bare
	var nb: Array = m.nb
	var stack := PackedInt32Array([c])
	while not stack.is_empty():
		var at := stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		if pen[at] == 1:
			continue
		if edge[at] == 1:
			return false
		pen[at] = 1
		size[0] += 1
		if fence[at] == 1:
			fence[at] = 0
			count[0] -= 1
		for k: int in nb[at]:
			if pen[k] == 1 or block[k] != NONE:
				continue
			if bare[k] == 1:
				if fence[k] == 0:
					fence[k] = 1
					count[0] += 1
			else:
				stack.append(k)
	return true

## Water, boulders, a horse and the things lying about. {} when the horse
## found nowhere worth standing.
static func _lay(rng: RandomNumberGenerator, spec: Dictionary) -> Dictionary:
	var w: int = spec.w
	var h: int = spec.h
	var n := w * h
	var block := PackedByteArray()
	block.resize(n)
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	# Streams: walks that mostly keep going straight, so they read as channels
	# and not as scattered puddles, and run off the field rather than turning
	# along its edge -- a channel that leaves is a wall the pen can lean on.
	for _s in int(spec.streams):
		var c := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		var d: Vector2i = dirs[rng.randi_range(0, 3)]
		var run := rng.randi_range(int(mini(w, h) * 0.5), int(maxi(w, h) * 0.7))
		for _i in run:
			block[c.y * w + c.x] = WATER
			if rng.randf() > 0.72:
				var turn: Vector2i = dirs[rng.randi_range(0, 3)]
				if turn != -d:
					d = turn
			var nx := c + d
			if nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h:
				break
			c = nx
	for _p in int(spec.pools):
		var pool: Array = [Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))]
		block[pool[0].y * w + pool[0].x] = WATER
		var size := rng.randi_range(3, 5)
		var guard := 0
		while pool.size() < size and guard < 20:
			guard += 1
			var nx: Vector2i = pool[rng.randi_range(0, pool.size() - 1)] + dirs[rng.randi_range(0, 3)]
			if nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h or block[nx.y * w + nx.x] != NONE:
				continue
			block[nx.y * w + nx.x] = WATER
			pool.append(nx)
	var placed := 0
	var guard := 0
	while placed < int(spec.stones) and guard < 80:
		guard += 1
		var i := rng.randi_range(0, n - 1)
		if block[i] == NONE:
			block[i] = STONE
			placed += 1
	var m := {"w": w, "h": h, "block": block, "tunnels": [], "horse": 0}
	var item := PackedByteArray()
	item.resize(n)
	m["item"] = item
	prepare(m)
	# The horse: of a few dozen inner grass cells, the one that can wander
	# furthest -- and it has to reach the edge, or there is nothing to do.
	var none := PackedByteArray()
	none.resize(n)
	var horse := -1
	var widest := 0
	for _try in 40:
		var i := rng.randi_range(1, h - 2) * w + rng.randi_range(1, w - 2)
		if block[i] != NONE:
			continue
		m.horse = i
		var r := reach(m, none)
		if (r.gaps as PackedInt32Array).is_empty():
			continue
		if (r.order as PackedInt32Array).size() > widest:
			widest = (r.order as PackedInt32Array).size()
			horse = i
	if horse < 0 or widest < n / 3:
		return {}
	m.horse = horse
	var walk := reach(m, none)
	var grass: Array = []
	for i: int in walk.order:
		if i != horse:
			grass.append(i)
	# The things lie where the horse can walk, never under it. A tunnel's
	# mouths are inner cells some way apart, so the tunnel is a short cut and
	# not a doorstep.
	for kind in [[APPLE, int(spec.apples)], [GOLD, int(spec.gold)], [BEE, int(spec.bees)]]:
		for _k in int(kind[1]):
			if grass.is_empty():
				break
			var at := rng.randi_range(0, grass.size() - 1)
			item[int(grass[at])] = int(kind[0])
			grass.remove_at(at)
	var edge: PackedByteArray = m.edge
	var tunnels: Array = []
	for _t in int(spec.tunnels):
		for _try in 60:
			if grass.size() < 2:
				break
			var a: int = grass[rng.randi_range(0, grass.size() - 1)]
			var b: int = grass[rng.randi_range(0, grass.size() - 1)]
			var apart := absi(a % w - b % w) + absi(a / w - b / w)
			if a == b or edge[a] == 1 or edge[b] == 1 or apart < 5:
				continue
			tunnels.append([a, b])
			grass.erase(a)
			grass.erase(b)
			break
	m["tunnels"] = tunnels
	return m
