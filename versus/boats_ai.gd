extends RefCounted

## The computer at Toy Boats (versus/boats_rules.gd). It sees what a player
## sees: the slate, with its misses, its hits and the boats said sunk. The
## three levels are three ways people play.
##
## 0 throws anywhere, and after a hit usually remembers to try beside it.
## 1 hunts on every other square (no boat is shorter than two) and, once two
##   hits lie in a line, follows the line before trying its sides.
## 2 counts, for every square, the ways the boats still afloat could lie
##   across it given everything on the slate, and throws where there are
##   most; a way that passes through a hit not yet explained counts for far
##   more, which is what makes it finish a boat it has found.
##
## Nothing here takes long (a few hundred placements), so it runs where it is
## called, no thread.

const Rules = preload("res://versus/boats_rules.gd")

## How often level 0 follows a hit up rather than throwing anywhere.
const FOLLOW := 0.7
## What a placement through `k` open hits is worth to level 2: WEIGHT ** k.
const WEIGHT := 24.0
## Level 2's scores are blurred by up to this share, so two games are not one.
const BLUR := 0.08

## The square to throw at, given the slate `chart`. -1 when none is left.
static func plan(chart: RefCounted, level: int, rng: RandomNumberGenerator) -> int:
	var free := PackedInt32Array()
	for c in Rules.CELLS:
		if chart.marks[c] == Rules.UNKNOWN:
			free.append(c)
	if free.is_empty():
		return -1
	match level:
		0:
			var beside := _beside(chart, chart.open_hits())
			if not beside.is_empty() and rng.randf() < FOLLOW:
				return beside[rng.randi() % beside.size()]
			return free[rng.randi() % free.size()]
		1:
			var open: PackedInt32Array = chart.open_hits()
			var along := _along(chart, open)
			if not along.is_empty():
				return along[rng.randi() % along.size()]
			var beside := _beside(chart, open)
			if not beside.is_empty():
				return beside[rng.randi() % beside.size()]
			var even := PackedInt32Array()
			for c in free:
				var at := Rules.xy(c)
				if (at.x + at.y) % 2 == 0:
					even.append(c)
			if even.is_empty():
				even = free
			return even[rng.randi() % even.size()]
	var score := density(chart)
	var best := -1
	var top := -1.0
	for c in free:
		var s: float = score[c] * (1.0 + rng.randf() * BLUR)
		if s > top:
			top = s
			best = c
	return best

## For every square, the weighted count of ways a boat still afloat could
## lie across it: no square of it a miss or a sunk boat's, and when there are
## hits not yet explained, only the ways through one of them (if any are).
static func density(chart: RefCounted) -> PackedFloat32Array:
	var score := PackedFloat32Array()
	score.resize(Rules.CELLS)
	var blocked := PackedByteArray()
	blocked.resize(Rules.CELLS)
	var open := PackedByteArray()
	open.resize(Rules.CELLS)
	var any_open := false
	for c in Rules.CELLS:
		if chart.marks[c] == Rules.MISS:
			blocked[c] = 1
		elif chart.marks[c] == Rules.HIT:
			if chart.boat_at(c) >= 0:
				blocked[c] = 1
			else:
				open[c] = 1
				any_open = true
	for pass_n in 2:
		# The first pass asks for a way through an open hit; if no boat afloat
		# has one (it cannot happen on an honest slate), any way counts.
		var needs_hit := any_open and pass_n == 0
		var found := false
		for i in Rules.FLEET.size():
			if chart.sunk[i]:
				continue
			var n: int = Rules.FLEET[i]
			for dir in 2:
				var d := Rules.step(dir)
				for y in Rules.N - (n - 1) * d.y:
					for x in Rules.N - (n - 1) * d.x:
						var through := 0
						var ok := true
						for k in n:
							var c := Rules.cell(x + d.x * k, y + d.y * k)
							if blocked[c] == 1:
								ok = false
								break
							through += open[c]
						if not ok or (needs_hit and through == 0) or through == n:
							continue
						found = true
						var w := pow(WEIGHT, through)
						for k in n:
							var c := Rules.cell(x + d.x * k, y + d.y * k)
							if open[c] == 0:
								score[c] += w
		if found:
			break
	return score

## The untried squares at either end of a run of two or more open hits.
static func _along(chart: RefCounted, open: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in open:
		var at := Rules.xy(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var next := at + d
			if next.x >= Rules.N or next.y >= Rules.N or not open.has(Rules.cell(next.x, next.y)):
				continue
			# c and the square after it are both hits: walk to each end.
			for way: int in [-1, 1]:
				var q := at if way < 0 else next
				while q.x >= 0 and q.y >= 0 and q.x < Rules.N and q.y < Rules.N and open.has(Rules.cell(q.x, q.y)):
					q += d * way
				if q.x >= 0 and q.y >= 0 and q.x < Rules.N and q.y < Rules.N:
					var e := Rules.cell(q.x, q.y)
					if chart.marks[e] == Rules.UNKNOWN and not out.has(e):
						out.append(e)
	return out

## The untried squares beside an open hit.
static func _beside(chart: RefCounted, open: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in open:
		var at := Rules.xy(c)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := at + d
			if q.x < 0 or q.y < 0 or q.x >= Rules.N or q.y >= Rules.N:
				continue
			var e := Rules.cell(q.x, q.y)
			if chart.marks[e] == Rules.UNKNOWN and not out.has(e):
				out.append(e)
	return out

## The computer's own fleet: by chance, and from level 1 up with its boats
## kept apart, so one found boat does not give another away.
static func fleet(level: int, rng: RandomNumberGenerator) -> Array[Vector3i]:
	return Rules.random_fleet(rng, level >= 1)
