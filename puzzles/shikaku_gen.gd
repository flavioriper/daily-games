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
static func solve_count(clues: Array, w: int, h: int, limit: int) -> int:
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
	var owner := PackedInt32Array()
	owner.resize(w * h)
	owner.fill(-1)
	var used := PackedByteArray()
	used.resize(clues.size())
	return _cover(by_corner, owner, used, w, 0, limit)

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

static func _cover(by_corner: Array, owner: PackedInt32Array, used: PackedByteArray,
		w: int, from: int, limit: int) -> int:
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
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				owner[y * w + x] = ci
		used[ci] = 1
		found += _cover(by_corner, owner, used, w, cell + 1, limit - found)
		used[ci] = 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				owner[y * w + x] = -1
		if found >= limit:
			return found
	return found

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
