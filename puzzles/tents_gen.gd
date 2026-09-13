extends RefCounted

## Tents & Trees. Pitch one tent orthogonally beside each tree. Tents never
## touch, not even diagonally. The numbers beside each row and column count
## the tents there.
##
## Generation places tent/tree pairs directly, so every instance is valid by
## construction. Uniqueness is a bipartite matching search with the adjacency
## and count constraints layered on.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

static func generate(rng: RandomNumberGenerator, w: int, h: int, pairs: int) -> Dictionary:
	for _attempt in 60:
		var out := _place(rng, w, h, pairs)
		if out.trees.size() < 3:
			continue
		if solve_count(out.trees, out.row_counts, out.col_counts, w, h, 2) == 1:
			out["ok"] = true
			return out
	return {"trees": [], "tents": [], "row_counts": [], "col_counts": [], "w": w, "h": h, "ok": false}

static func _place(rng: RandomNumberGenerator, w: int, h: int, pairs: int) -> Dictionary:
	var occupied: Dictionary = {}
	var tents: Array = []
	var trees: Array = []
	var guard := 0
	while tents.size() < pairs and guard < 400:
		guard += 1
		var t := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		if occupied.has(t) or _touches_tent(t, tents):
			continue
		# The tree goes in a free orthogonal neighbour.
		var options: Array = []
		for d in DIRS:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if not occupied.has(n):
				options.append(n)
		if options.is_empty():
			continue
		var tree: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		occupied[t] = true
		occupied[tree] = true
		tents.append(t)
		trees.append(tree)

	var row_counts: Array = []
	var col_counts: Array = []
	for y in h:
		row_counts.append(0)
	for x in w:
		col_counts.append(0)
	for t in tents:
		row_counts[t.y] += 1
		col_counts[t.x] += 1
	return {"trees": trees, "tents": tents, "row_counts": row_counts,
		"col_counts": col_counts, "w": w, "h": h}

static func _touches_tent(c: Vector2i, tents: Array) -> bool:
	for t in tents:
		if absi(t.x - c.x) <= 1 and absi(t.y - c.y) <= 1:
			return true
	return false

static func solve_count(trees: Array, row_counts: Array, col_counts: Array,
		w: int, h: int, limit: int) -> int:
	if trees.is_empty():
		return 0
	var tree_set: Dictionary = {}
	for t in trees:
		tree_set[t] = true

	var cands: Array = []
	for t in trees:
		var list: Array = []
		for d in DIRS:
			var n: Vector2i = t + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			if tree_set.has(n):
				continue
			list.append(n)
		if list.is_empty():
			return 0
		cands.append(list)

	var order: Array = []
	for i in trees.size():
		order.append(i)
	order.sort_custom(func(a, b): return cands[a].size() < cands[b].size())

	var used: Dictionary = {}
	var rows: Array = []
	var cols: Array = []
	for y in h:
		rows.append(0)
	for x in w:
		cols.append(0)
	return _search(cands, order, 0, used, rows, cols, row_counts, col_counts, limit)

static func _search(cands: Array, order: Array, idx: int, used: Dictionary,
		rows: Array, cols: Array, row_counts: Array, col_counts: Array, limit: int) -> int:
	if idx == order.size():
		return 1
	var ti: int = order[idx]
	var found := 0
	for cell in cands[ti]:
		if used.has(cell):
			continue
		if int(rows[cell.y]) + 1 > int(row_counts[cell.y]):
			continue
		if int(cols[cell.x]) + 1 > int(col_counts[cell.x]):
			continue
		if _adjacent_to_used(cell, used):
			continue
		used[cell] = true
		rows[cell.y] += 1
		cols[cell.x] += 1
		found += _search(cands, order, idx + 1, used, rows, cols, row_counts, col_counts, limit - found)
		used.erase(cell)
		rows[cell.y] -= 1
		cols[cell.x] -= 1
		if found >= limit:
			return found
	return found

static func _adjacent_to_used(c: Vector2i, used: Dictionary) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if used.has(Vector2i(c.x + dx, c.y + dy)):
				return true
	return false

## Validate a player's tent layout against the rules directly, rather than
## comparing to the stored answer. Needs a perfect matching between trees and
## adjacent tents -- greedy pairing is not enough, so this is Kuhn's algorithm.
static func is_valid_solution(tents: Array, trees: Array, row_counts: Array,
		col_counts: Array, w: int, h: int) -> bool:
	if tents.size() != trees.size():
		return false
	var rows: Array = []
	var cols: Array = []
	for y in h:
		rows.append(0)
	for x in w:
		cols.append(0)
	var seen: Dictionary = {}
	for t in tents:
		if seen.has(t):
			return false
		seen[t] = true
		rows[t.y] += 1
		cols[t.x] += 1
	for y in h:
		if int(rows[y]) != int(row_counts[y]):
			return false
	for x in w:
		if int(cols[x]) != int(col_counts[x]):
			return false
	# A tent may not sit on a tree, nor touch another tent even diagonally.
	for t in trees:
		if seen.has(t):
			return false
	for a in tents.size():
		for b in range(a + 1, tents.size()):
			var p: Vector2i = tents[a]
			var q: Vector2i = tents[b]
			if absi(p.x - q.x) <= 1 and absi(p.y - q.y) <= 1:
				return false
	# Perfect matching, trees to orthogonally adjacent tents.
	var match_of: Dictionary = {}
	for i in trees.size():
		var visited: Dictionary = {}
		if not _augment(i, trees, tents, visited, match_of):
			return false
	return true

static func _augment(tree_idx: int, trees: Array, tents: Array,
		visited: Dictionary, match_of: Dictionary) -> bool:
	for j in tents.size():
		var d: Vector2i = trees[tree_idx] - tents[j]
		if absi(d.x) + absi(d.y) != 1:
			continue
		if visited.has(j):
			continue
		visited[j] = true
		if not match_of.has(j) or _augment(int(match_of[j]), trees, tents, visited, match_of):
			match_of[j] = tree_idx
			return true
	return false
