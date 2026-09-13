extends RefCounted

## Nonogram / Picross.
##
## The clues ARE the image, so there is no clue-stripping step. What matters is
## fairness: we run a line-solver to fixpoint, and only ship the puzzle if pure
## line logic completes the grid. That single check doubles as the uniqueness
## proof -- if every cell is forced, no second solution can exist -- and as the
## guarantee that the player never has to guess.

static var _line_cache: Dictionary = {}

static func generate(rng: RandomNumberGenerator, w: int, h: int) -> Dictionary:
	for _attempt in 300:
		var bmp := _blobby(rng, w, h)
		var filled := 0
		for y in h:
			for x in w:
				filled += int(bmp[y][x])
		# All-empty or near-solid images make dull puzzles.
		var ratio := float(filled) / float(w * h)
		if ratio < 0.3 or ratio > 0.68:
			continue

		var rows: Array = []
		var cols: Array = []
		for y in h:
			rows.append(clue_for(bmp[y]))
		for x in w:
			var col: Array = []
			for y in h:
				col.append(bmp[y][x])
			cols.append(clue_for(col))

		var solved := solve(rows, cols, w, h)
		if solved.is_empty() or not is_complete(solved):
			continue
		return {"bitmap": bmp, "rows": rows, "cols": cols, "w": w, "h": h, "ok": true}
	return {"bitmap": [], "rows": [], "cols": [], "w": w, "h": h, "ok": false}

static func clue_for(line: Array) -> Array:
	var out: Array = []
	var run := 0
	for v in line:
		if int(v) == 1:
			run += 1
		elif run > 0:
			out.append(run)
			run = 0
	if run > 0:
		out.append(run)
	return out

## Repeatedly intersect all clue-satisfying placements per line until nothing
## changes. Returns [] on contradiction.
static func solve(rows: Array, cols: Array, w: int, h: int) -> Array:
	var grid: Array = []
	for y in h:
		var r: Array = []
		for x in w:
			r.append(-1)
		grid.append(r)

	var guard := 0
	while guard < 200:
		guard += 1
		var changed := false
		for y in h:
			var refined: Array = refine(rows[y], grid[y])
			if refined.is_empty():
				return []
			for x in w:
				if grid[y][x] != refined[x]:
					grid[y][x] = refined[x]
					changed = true
		for x in w:
			var col: Array = []
			for y in h:
				col.append(grid[y][x])
			var refined2: Array = refine(cols[x], col)
			if refined2.is_empty():
				return []
			for y in h:
				if grid[y][x] != refined2[y]:
					grid[y][x] = refined2[y]
					changed = true
		if not changed:
			break
	return grid

## Narrow one line: cells that every legal placement agrees on become known.
static func refine(clue: Array, known: Array) -> Array:
	var n: int = known.size()
	var options: Array = _placements(clue, n)
	var and_mask: Array = []
	var or_mask: Array = []
	var any := false
	for line in options:
		var ok := true
		for i in n:
			if int(known[i]) != -1 and int(known[i]) != int(line[i]):
				ok = false
				break
		if not ok:
			continue
		if not any:
			and_mask = (line as Array).duplicate()
			or_mask = (line as Array).duplicate()
			any = true
		else:
			for i in n:
				and_mask[i] = int(and_mask[i]) & int(line[i])
				or_mask[i] = int(or_mask[i]) | int(line[i])
	if not any:
		return []  # contradiction
	var out: Array = []
	for i in n:
		if int(and_mask[i]) == 1:
			out.append(1)
		elif int(or_mask[i]) == 0:
			out.append(0)
		else:
			out.append(-1)
	return out

static func is_complete(grid: Array) -> bool:
	for row in grid:
		for v in row:
			if int(v) == -1:
				return false
	return true

static func _placements(clue: Array, n: int) -> Array:
	var key := "%s|%d" % [clue, n]
	if _line_cache.has(key):
		return _line_cache[key]
	var out: Array = []
	_emit(clue, 0, [], n, out)
	_line_cache[key] = out
	return out

static func _emit(clue: Array, ci: int, prefix: Array, n: int, out: Array) -> void:
	if ci == clue.size():
		var line: Array = prefix.duplicate()
		while line.size() < n:
			line.append(0)
		if line.size() == n:
			out.append(line)
		return
	# Space still needed for this run and every run after it, plus separators.
	var need := 0
	for i in range(ci, clue.size()):
		need += int(clue[i])
	need += clue.size() - ci - 1
	for start in range(prefix.size(), n - need + 1):
		var line: Array = prefix.duplicate()
		while line.size() < start:
			line.append(0)
		for k in int(clue[ci]):
			line.append(1)
		if ci < clue.size() - 1:
			line.append(0)  # mandatory gap between runs
		if line.size() <= n:
			_emit(clue, ci + 1, line, n, out)
static func _blobby(rng: RandomNumberGenerator, w: int, h: int) -> Array:
	# Pure noise almost never line-solves. One smoothing pass clumps it into
	# shapes, which both look like something and solve far more often.
	var g: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(1 if rng.randf() < 0.5 else 0)
		g.append(row)
	var out: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			var n := 0
			var total := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					total += 1
					n += int(g[ny][nx])
			row.append(1 if float(n) / float(total) >= 0.5 else 0)
		out.append(row)
	return out
