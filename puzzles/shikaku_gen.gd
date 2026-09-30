extends RefCounted

## Shikaku. Divide the grid into rectangles, each holding exactly one clue.
## A clue carries a number, the plot's area, and on the harder levels a
## shape as well -- square, tall or wide -- and past Medium some clues carry
## the shape alone, with no number: the plot may then be any size, so long
## as it is that shape.
##
## Generation runs the easy direction: recursively partition the grid into
## rectangles, then drop one number into each. Every instance is valid by
## construction, so the only work is proving the answer is unique. Shapes
## are laid on afterwards (a shape only ever removes answers, so a unique
## board stays unique) and then numbers are taken off shaped clues one at a
## time, each removal kept only if the board is still unique.

## What a clue asks of its plot's proportions. ANY is the plain number.
enum Shape { ANY, SQUARE, TALL, WIDE }

static func generate(rng: RandomNumberGenerator, w: int, h: int, max_area: int, min_area: int = 3,
		shaped := 0.0, blank := 0.0) -> Dictionary:
	for _attempt in 80:
		var rects: Array = []
		_partition(rng, Rect2i(0, 0, w, h), rects, max_area, min_area)
		if rects.size() < 3:
			continue
		# Where the number sits inside its rectangle changes uniqueness, so
		# try several placements before discarding the partition.
		for _place in 8:
			var clues: Array = []
			for r in rects:
				var cx: int = r.position.x + rng.randi_range(0, r.size.x - 1)
				var cy: int = r.position.y + rng.randi_range(0, r.size.y - 1)
				clues.append({"pos": Vector2i(cx, cy), "area": r.size.x * r.size.y, "shape": Shape.ANY})
			if solve_count(clues, w, h, 2) == 1:
				_dress(rng, clues, rects, w, h, shaped, blank)
				return {"clues": clues, "rects": rects, "w": w, "h": h, "ok": true}
	return {"clues": [], "rects": [], "w": w, "h": h, "ok": false}

## Insane's board: a unique board of `w` x `h` whose `crows` signs become
## scarecrows (no size, no shape: the number is how many plots share a fence
## with theirs), then shapes on every other sign it can and the numbers
## taken off as many of those as stay unique. Kept only when the scarecrows
## are load-bearing -- read as plain blank signs the board has more than one
## answer -- so the rule is what the day turns on. {} when no try came good.
static func generate_crows(rng: RandomNumberGenerator, w: int, h: int, max_area: int,
		crows: int, tries := 6) -> Dictionary:
	for _t in tries:
		var out := generate(rng, w, h, max_area, 3)
		if not out.ok:
			continue
		var clues: Array = out.clues
		var rects: Array = out.rects
		var order: Array = range(clues.size())
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]; order[i] = order[j]; order[j] = t
		var owner := PackedInt32Array()
		owner.resize(w * h)
		for k in rects.size():
			var r: Rect2i = rects[k]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					owner[y * w + x] = k
		var made := 0
		for i in order:
			if made >= crows:
				break
			var was: Dictionary = clues[i].duplicate()
			var count: int = fence_neighbours(rects[i], owner, w, h)[0]
			clues[i].area = 0
			clues[i].shape = Shape.ANY
			clues[i].crow = count
			if solve_count(clues, w, h, 2) == 1:
				made += 1
			else:
				clues[i] = was
		if made < crows:
			continue
		# Shape every plain sign, then take numbers off every one that can go.
		var plain: Array = []
		for i in order:
			if crow_of(clues[i]) < 0:
				clues[i].shape = shape_of(rects[i].size.x, rects[i].size.y)
				plain.append(i)
		for i in plain:
			var area: int = clues[i].area
			clues[i].area = 0
			if solve_count(clues, w, h, 2) != 1:
				clues[i].area = area
		if solve_count(clues, w, h, 2, false) < 2:
			continue
		return {"clues": clues, "rects": rects, "w": w, "h": h, "ok": true}
	return {}

## A board in the bank's JSON encoding: clues as [x, y, area, shape, crow],
## plots as [x, y, w, h].
static func to_bank(out: Dictionary) -> Dictionary:
	var clues: Array = []
	for c in out.clues:
		clues.append([c.pos.x, c.pos.y, int(c.area), int(c.shape), crow_of(c)])
	var rects: Array = []
	for r: Rect2i in out.rects:
		rects.append([r.position.x, r.position.y, r.size.x, r.size.y])
	return {"w": out.w, "h": out.h, "clues": clues, "rects": rects}

## A bank entry back as generate()'s dict (JSON numbers arrive as floats), or
## {} when it is not one.
static func from_bank(b: Dictionary) -> Dictionary:
	if not (b.get("clues") is Array and b.get("rects") is Array):
		return {}
	var clues: Array = []
	for c in b.clues:
		var clue := {"pos": Vector2i(int(c[0]), int(c[1])), "area": int(c[2]), "shape": int(c[3])}
		if int(c[4]) >= 0:
			clue.crow = int(c[4])
		clues.append(clue)
	var rects: Array = []
	for r in b.rects:
		rects.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	return {"clues": clues, "rects": rects, "w": int(b.w), "h": int(b.h), "ok": true}

## Lays shapes on a `shaped` share of a unique board's clues, then takes the
## number off up to a `blank` share of the shaped ones, keeping only the
## removals that leave the answer unique.
static func _dress(rng: RandomNumberGenerator, clues: Array, rects: Array, w: int, h: int,
		shaped: float, blank: float) -> void:
	if shaped <= 0.0:
		return
	var dressed: Array = []
	for i in clues.size():
		if rng.randf() < shaped:
			clues[i].shape = shape_of(rects[i].size.x, rects[i].size.y)
			dressed.append(i)
	var want := int(roundf(dressed.size() * blank))
	# Shuffled with the board's own generator, so a day stays a day.
	for i in range(dressed.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = dressed[i]
		dressed[i] = dressed[j]
		dressed[j] = t
	for i in dressed:
		if want <= 0:
			break
		var area: int = clues[i].area
		clues[i].area = 0
		if solve_count(clues, w, h, 2) == 1:
			want -= 1
		else:
			clues[i].area = area

## The shape a rw x rh plot is.
static func shape_of(rw: int, rh: int) -> int:
	if rw == rh:
		return Shape.SQUARE
	return Shape.TALL if rh > rw else Shape.WIDE

## Whether a rw x rh plot answers `clue`: its area when it has a number, its
## shape when it has one. The one rule every check on the board goes through.
static func fits(clue: Dictionary, rw: int, rh: int) -> bool:
	var area := int(clue.area)
	if area > 0 and rw * rh != area:
		return false
	var shape := int(clue.get("shape", Shape.ANY))
	return shape == Shape.ANY or shape == shape_of(rw, rh)

## Answers up to `limit`. An exact cover run cell by cell: the first cell
## nothing covers yet has to be the top-left corner of some clue's plot, so
## the plots are indexed by their corner. Covering every cell uses every
## clue, since a plot is only a candidate when its own clue is the one
## inside it.
##
## A scarecrow (a clue with "crow" >= 0, Insane's own) asks for no size or
## shape; its number is how many other plots share a fence with its plot. The
## search checks every scarecrow each time a plot goes down: more distinct
## neighbours than its number, or its whole ring decided and the count not
## met, and the branch is dropped. `crows` false reads every scarecrow as a
## plain sign with no number, which is how the miner proves the rule is what
## makes a board unique. `work`, when given, is bumped once per plot tried.
static func solve_count(clues: Array, w: int, h: int, limit: int, crows := true, work: Array = []) -> int:
	if clues.is_empty():
		return 0
	var total := 0
	var open := false
	for c in clues:
		if int(c.area) > 0:
			total += int(c.area)
		else:
			open = true
	if total > w * h or (not open and total != w * h):
		return 0  # areas must tile the board exactly
	var by_corner: Array = []
	by_corner.resize(w * h)
	for i in w * h:
		by_corner[i] = []
	for i in clues.size():
		var list: Array = candidates(clues, i, w, h)
		if list.is_empty():
			return 0
		for r: Rect2i in list:
			by_corner[r.position.y * w + r.position.x].append([i, r])
	var s := Search.new()
	s.by_corner = by_corner
	s.w = w
	s.h = h
	s.owner.resize(w * h)
	s.owner.fill(-1)
	s.used.resize(clues.size())
	s.placed.resize(clues.size())
	if crows:
		for i in clues.size():
			if crow_of(clues[i]) >= 0:
				s.crows.append(i)
				s.counts.append(crow_of(clues[i]))
	var found := s.cover(0, limit)
	if not work.is_empty():
		work[0] += s.work
	return found

## A scarecrow's number, or -1 for any other sign.
static func crow_of(clue: Dictionary) -> int:
	return int(clue.get("crow", -1))

## The distinct plots sharing a fence with `rect`, read off `owner` (a plot
## index per cell, -1 where nothing is yet), and whether any cell round it is
## still undecided: [count, open].
static func fence_neighbours(rect: Rect2i, owner: PackedInt32Array, w: int, h: int) -> Array:
	return Search.neighbours(rect, owner, w, h)

## The search behind solve_count, so its state is not threaded through every
## call.
class Search:
	var by_corner: Array
	var w: int
	var h: int
	var owner := PackedInt32Array()
	var used := PackedByteArray()
	var placed: Array = []
	var crows: Array[int] = []
	var counts: Array[int] = []
	var work := 0

	func cover(from: int, limit: int) -> int:
		var cell := from
		while cell < owner.size() and owner[cell] != -1:
			cell += 1
		if cell == owner.size():
			return 1
		var found := 0
		for pick in by_corner[cell]:
			var ci: int = pick[0]
			if used[ci] != 0:
				continue
			var r: Rect2i = pick[1]
			var clash := false
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if owner[y * w + x] != -1:
						clash = true
						break
				if clash:
					break
			if clash:
				continue
			work += 1
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					owner[y * w + x] = ci
			used[ci] = 1
			placed[ci] = r
			if _crows_hold():
				found += cover(cell + 1, limit - found)
			used[ci] = 0
			placed[ci] = null
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					owner[y * w + x] = -1
			if found >= limit:
				return found
		return found

	static func neighbours(rect: Rect2i, owner: PackedInt32Array, w: int, h: int) -> Array:
		var seen: Dictionary = {}
		var open := false
		var ring: Array[Vector2i] = []
		for x in range(rect.position.x, rect.end.x):
			ring.append(Vector2i(x, rect.position.y - 1))
			ring.append(Vector2i(x, rect.end.y))
		for y in range(rect.position.y, rect.end.y):
			ring.append(Vector2i(rect.position.x - 1, y))
			ring.append(Vector2i(rect.end.x, y))
		for p in ring:
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
				continue
			var o := owner[p.y * w + p.x]
			if o < 0:
				open = true
			else:
				seen[o] = true
		return [seen.size(), open]

	## Whether every scarecrow placed so far can still have its count.
	func _crows_hold() -> bool:
		for k in crows.size():
			var at = placed[crows[k]]
			if at == null:
				continue
			var n: Array = neighbours(at, owner, w, h)
			if int(n[0]) > counts[k] or (not n[1] and int(n[0]) != counts[k]):
				return false
		return true

static func candidates(clues: Array, idx: int, w: int, h: int) -> Array:
	var clue: Dictionary = clues[idx]
	var pos: Vector2i = clue.pos
	var out: Array = []
	for rw in range(1, w + 1):
		for rh in range(1, h + 1):
			if not fits(clue, rw, rh):
				continue
			for x in range(maxi(0, pos.x - rw + 1), mini(pos.x, w - rw) + 1):
				for y in range(maxi(0, pos.y - rh + 1), mini(pos.y, h - rh) + 1):
					var r := Rect2i(x, y, rw, rh)
					# A rectangle may contain its own clue and no other.
					var count := 0
					for j in clues.size():
						if r.has_point(clues[j].pos):
							count += 1
					if count == 1:
						out.append(r)
	return out

static func _partition(rng: RandomNumberGenerator, r: Rect2i, out: Array,
		max_area: int, min_area: int) -> void:
	var area: int = r.size.x * r.size.y
	# Only consider cuts that leave BOTH sides at or above the minimum. Without
	# this the recursion shaves off width-1 slivers and the board fills with
	# 1x1 clues, which are forced on sight and make the puzzle read as noise.
	var cuts: Array = []
	for cut in range(1, r.size.x):
		if cut * r.size.y >= min_area and (r.size.x - cut) * r.size.y >= min_area:
			cuts.append([true, cut])
	for cut in range(1, r.size.y):
		if cut * r.size.x >= min_area and (r.size.y - cut) * r.size.x >= min_area:
			cuts.append([false, cut])

	if cuts.is_empty() or (area <= max_area and rng.randf() < 0.45):
		out.append(r)
		return

	var pick: Array = cuts[rng.randi_range(0, cuts.size() - 1)]
	if pick[0]:
		var c: int = pick[1]
		_partition(rng, Rect2i(r.position.x, r.position.y, c, r.size.y), out, max_area, min_area)
		_partition(rng, Rect2i(r.position.x + c, r.position.y, r.size.x - c, r.size.y), out, max_area, min_area)
	else:
		var c2: int = pick[1]
		_partition(rng, Rect2i(r.position.x, r.position.y, r.size.x, c2), out, max_area, min_area)
		_partition(rng, Rect2i(r.position.x, r.position.y + c2, r.size.x, r.size.y - c2), out, max_area, min_area)
