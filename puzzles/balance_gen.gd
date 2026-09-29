extends RefCounted

## Balance's seesaw: the day's weights, basket and pinned fruit.
##
## A cup is a signed distance from the pivot, -D..-1 on the left and 1..D on
## the right; a fruit of kind k in cup x pulls with weights[k] * x, and the
## beam is level when those sum to zero. Every kind's weight is hidden from
## the player, who learns them by weighing on the beam itself.
##
## The answer is grown first (fruit scattered into cups until the torque is
## zero), refused if it would balance whatever the weights were (each kind's
## own signed distances summing to zero teaches nothing), and then pinned one
## fruit at a time -- always the pin that leaves the fewest completions under
## the true weights -- until exactly one completion is left. So the level the
## player finds is the level, and it depends on what things weigh.
## Spec: docs/superpowers/specs/2026-09-27-balance-seesaw-design.md, section 4.

## Per band: kinds, fruit, reach (cups a side), top weight, and how many of
## the answer's fruit are pinned at random before the greedy pins begin --
## the first counts on a wide board are the expensive ones, and those bands
## end with more pins than that anyway.
##
## Hard and Insane can be lost (spec 2026-09-29-balance-sunset-design.md):
## `sun` is the day's moves beyond one per loose fruit before the sun sets,
## `hour` what One more hour gives back. Insane's bales are springs
## (`boing`): a beam that bottoms out bounces every loose fruit on its low
## side home, so an Insane answer must also be placeable in some order that
## never reads past the glass.
const BANDS := [
	{"kinds": 3, "fruit": 6, "reach": 3, "max_w": 5},
	{"kinds": 4, "fruit": 8, "reach": 4, "max_w": 7},
	{"kinds": 5, "fruit": 8, "reach": 4, "max_w": 9, "seed_pins": 1, "sun": 10, "hour": 4},
	{"kinds": 5, "fruit": 9, "reach": 5, "max_w": 12, "seed_pins": 2, "sun": 8, "hour": 3, "boing": true, "min_loose": 4},
]
## The most the glass reads either way; a heavier lean is the bale.
const GLASS := 5
const ATTEMPTS := 400
const SCATTERS := 300
## The greedy pin only needs to rank candidates, so a count stops once it
## has seen this many completions.
const COUNT_CAP := 60

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

static func cups(reach: int) -> Array[int]:
	var out: Array[int] = []
	for x in range(-reach, reach + 1):
		if x != 0:
			out.append(x)
	return out

## {weights: [w per kind], fruit: [kind per fruit], answer: [cup per fruit],
## pinned: [bool per fruit], reach, unique}. Fruit are listed kind by kind,
## which is the basket's order.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var bd := band(difficulty)
	var kinds: int = bd.kinds
	var n: int = bd.fruit
	var reach: int = bd.reach
	var all := cups(reach)
	for _attempt in ATTEMPTS:
		var weights := _weights(rng, kinds, int(bd.max_w))
		var fruit: Array[int] = []
		for k in kinds:
			fruit.append(k)
		for _i in n - kinds:
			fruit.append(rng.randi_range(0, kinds - 1))
		fruit.sort()
		var answer := _scatter(rng, fruit, weights, all)
		if answer.is_empty() or _structural(fruit, answer, kinds):
			continue
		var pinned: Array[bool] = []
		pinned.resize(n)
		pinned.fill(false)
		var seeds: Array = range(n)
		_shuffle(rng, seeds)
		for i in int(bd.get("seed_pins", 0)):
			pinned[int(seeds[i])] = true
		var left := count(reach, weights, fruit, answer, pinned)
		while left > 1:
			var best := -1
			var best_n := 1 << 30
			var order: Array = range(n)
			_shuffle(rng, order)
			for f: int in order:
				if pinned[f]:
					continue
				pinned[f] = true
				var m := count(reach, weights, fruit, answer, pinned)
				pinned[f] = false
				if m >= 1 and m < best_n:
					best = f
					best_n = m
			if best < 0:
				break
			pinned[best] = true
			left = best_n
		if left != 1:
			continue
		# a board with nothing left to place is not a board
		if pinned.count(false) < int(bd.get("min_loose", 2)):
			continue
		if bool(bd.get("boing", false)) and safe_order(weights, fruit, answer, pinned).is_empty():
			# A unique board with no bale-safe order is usually one pin away
			# from one, and a pin more never makes the answer less unique.
			var fixed := false
			for f in n:
				if pinned[f] or pinned.count(false) <= int(bd.get("min_loose", 2)):
					continue
				pinned[f] = true
				if not safe_order(weights, fruit, answer, pinned).is_empty():
					fixed = true
					break
				pinned[f] = false
			if not fixed:
				continue
		var sun: int = bd.get("sun", -1)
		return {"weights": weights, "fruit": fruit, "answer": answer, "pinned": pinned,
			"reach": reach, "unique": true,
			"budget": pinned.count(false) + sun if sun >= 0 else 0,
			"hour": int(bd.get("hour", 0)), "boing": bool(bd.get("boing", false))}
	# unreachable in practice; a pinned-to-the-end board is still solvable
	return {}

## An order to put the loose fruit into their answer cups, one at a time
## from an empty plank (the pinned ones already on it), such that no step
## would bounce a placed fruit off a springy bale: after each step the beam
## reads within GLASS, or nothing loose sits on its low side. [] if there is
## none. `fixed` is pinned (or hinted) per fruit.
static func safe_order(weights: Array[int], fruit: Array[int], answer: Array[int], fixed: Array[bool]) -> Array[int]:
	var loose: Array[int] = []
	var t0 := 0
	for f in fruit.size():
		if fixed[f]:
			t0 += weights[fruit[f]] * answer[f]
		else:
			loose.append(f)
	var dead := {}
	var path: Array[int] = []
	if _safe_walk(0, t0, loose, weights, fruit, answer, dead, path):
		return path
	return []

static func _safe_walk(mask: int, tq: int, loose: Array[int], weights: Array[int], fruit: Array[int], answer: Array[int], dead: Dictionary, path: Array[int]) -> bool:
	if mask == (1 << loose.size()) - 1:
		return true
	if dead.has(mask):
		return false
	for i in loose.size():
		if mask & (1 << i):
			continue
		var f := loose[i]
		var t2 := tq + weights[fruit[f]] * answer[f]
		if absi(t2) > GLASS:
			# a bale: safe only if no placed loose fruit is on the low side
			var hit := false
			var m2 := mask | (1 << i)
			for j in loose.size():
				if m2 & (1 << j) and answer[loose[j]] * t2 > 0:
					hit = true
					break
			if hit:
				continue
		path.append(f)
		if _safe_walk(mask | (1 << i), t2, loose, weights, fruit, answer, dead, path):
			return true
		path.pop_back()
	dead[mask] = true
	return false

static func _weights(rng: RandomNumberGenerator, kinds: int, top: int) -> Array[int]:
	var pool: Array = range(1, top + 1)
	_shuffle(rng, pool)
	var out: Array[int] = []
	for k in kinds:
		out.append(int(pool[k]))
	return out

## Fruit into distinct cups until the torque comes to zero; [] if the
## scatters run out.
static func _scatter(rng: RandomNumberGenerator, fruit: Array[int], weights: Array[int], all: Array[int]) -> Array[int]:
	var spots: Array = all.duplicate()
	for _s in SCATTERS:
		_shuffle(rng, spots)
		var tq := 0
		for f in fruit.size():
			tq += weights[fruit[f]] * int(spots[f])
		if tq == 0:
			var out: Array[int] = []
			for f in fruit.size():
				out.append(int(spots[f]))
			return out
	return []

## True when the answer levels the beam whatever the weights: every kind's
## own signed distances sum to zero.
static func _structural(fruit: Array[int], answer: Array[int], kinds: int) -> bool:
	var per: Array[int] = []
	per.resize(kinds)
	per.fill(0)
	for f in fruit.size():
		per[fruit[f]] += answer[f]
	for v in per:
		if v != 0:
			return false
	return true

## How many ways the unpinned fruit can fill the free cups so the beam is
## level under `weights`, identical fruit counted once, up to COUNT_CAP.
static func count(reach: int, weights: Array[int], fruit: Array[int], answer: Array[int], pinned: Array[bool]) -> int:
	var taken := {}
	var tq := 0
	var kinds := weights.size()
	var rem: Array[int] = []
	rem.resize(kinds)
	rem.fill(0)
	for f in fruit.size():
		if pinned[f]:
			taken[answer[f]] = true
			tq += weights[fruit[f]] * answer[f]
		else:
			rem[fruit[f]] += 1
	var free: Array[int] = []
	for x in cups(reach):
		if not taken.has(x):
			free.append(x)
	var loose := 0
	for r in rem:
		loose += r
	var memo := {}
	return _walk(free, 0, rem, free.size() - loose, tq, weights, memo)

static func _walk(free: Array[int], i: int, rem: Array[int], empties: int, tq: int, weights: Array[int], memo: Dictionary) -> int:
	if i == free.size():
		return 1 if tq == 0 else 0
	var key := ((i * 16 + empties) * 4096 + (tq + 2048))
	for r in rem:
		key = key * 16 + r
	if memo.has(key):
		return memo[key]
	var n := 0
	if empties > 0:
		n += _walk(free, i + 1, rem, empties - 1, tq, weights, memo)
	for k in rem.size():
		if n >= COUNT_CAP:
			break
		if rem[k] > 0:
			rem[k] -= 1
			n += _walk(free, i + 1, rem, empties, tq + weights[k] * free[i], weights, memo)
			rem[k] += 1
	n = mini(n, COUNT_CAP)
	memo[key] = n
	return n

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
