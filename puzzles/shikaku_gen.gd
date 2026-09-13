extends RefCounted

## Shikaku. Divide the grid into rectangles, each holding exactly one number
## equal to its area.
##
## Generation runs the easy direction: recursively partition the grid into
## rectangles, then drop one number into each. Every instance is valid by
## construction, so the only work is proving the answer is unique.

static func generate(rng: RandomNumberGenerator, w: int, h: int, max_area: int, min_area: int = 3) -> Dictionary:
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
				clues.append({"pos": Vector2i(cx, cy), "area": r.size.x * r.size.y})
			if solve_count(clues, w, h, 2) == 1:
				return {"clues": clues, "rects": rects, "w": w, "h": h, "ok": true}
	return {"clues": [], "rects": [], "w": w, "h": h, "ok": false}

static func solve_count(clues: Array, w: int, h: int, limit: int) -> int:
	if clues.is_empty():
		return 0
	var total := 0
	for c in clues:
		total += int(c.area)
	if total != w * h:
		return 0  # areas must tile the board exactly

	var cands: Array = []
	for i in clues.size():
		var list: Array = candidates(clues, i, w, h)
		if list.is_empty():
			return 0
		cands.append(list)

	# Most-constrained first: a clue with two options prunes far harder
	# than one with twenty.
	var order: Array = []
	for i in clues.size():
		order.append(i)
	order.sort_custom(func(a, b): return cands[a].size() < cands[b].size())

	var owner: Array = []
	for i in w * h:
		owner.append(-1)
	return _search(cands, order, 0, owner, w, limit)

static func candidates(clues: Array, idx: int, w: int, h: int) -> Array:
	var clue: Dictionary = clues[idx]
	var pos: Vector2i = clue.pos
	var area: int = clue.area
	var out: Array = []
	for rw in range(1, area + 1):
		if area % rw != 0:
			continue
		var rh: int = area / rw
		if rw > w or rh > h:
			continue
		for x in range(maxi(0, pos.x - rw + 1), mini(pos.x, w - rw) + 1):
			for y in range(maxi(0, pos.y - rh + 1), mini(pos.y, h - rh) + 1):
				var r := Rect2i(x, y, rw, rh)
				# A rectangle may contain its own number and no other.
				var count := 0
				for j in clues.size():
					if r.has_point(clues[j].pos):
						count += 1
				if count == 1:
					out.append(r)
	return out

static func _search(cands: Array, order: Array, idx: int, owner: Array, w: int, limit: int) -> int:
	if idx == order.size():
		return 1
	var ci: int = order[idx]
	var found := 0
	for r in cands[ci]:
		var clash := false
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				if owner[y * w + x] != -1:
					clash = true
					break
			if clash:
				break
		if clash:
			continue
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
				owner[y * w + x] = ci
		found += _search(cands, order, idx + 1, owner, w, limit - found)
		for x in range(r.position.x, r.position.x + r.size.x):
			for y in range(r.position.y, r.position.y + r.size.y):
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
