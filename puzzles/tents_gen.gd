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

# --- Insane: Old Oaks ---
#
# Tents' Insane is a rule, not a bigger meadow: a few of the trees are old
# oaks, and an oak takes **two** tents. The no-touching rule does the rest --
# two tents on neighbouring sides of a tree touch at a corner, so an oak's
# pair always stands on opposite sides, which is the first thing a player has
# to see for themselves. On top of that as many line counts as can go are
# taken off while the answer stays unique, and a board is kept only when the
# oaks carry the day: read as trees that take one tent *or* two, it has more
# than one answer. No Tents we could find has a tree that takes two (the
# known variants are Odd Tents, two-cell tents and Forest Walk).
# A hidden count is -1 in `row_counts` / `col_counts`.
# Spec: docs/superpowers/specs/2026-09-30-tents-polish-design.md, section 2.

const HIDDEN := -1

## An oak board: `pines` ordinary trees and `oaks` two-tent oaks on a `w` by
## `h` meadow, every count shown. {} when the meadow would not take them.
static func place_oaks(rng: RandomNumberGenerator, w: int, h: int, pines: int, oaks: int) -> Dictionary:
	var occupied: Dictionary = {}
	var tents: Array = []
	var trees: Array = []
	var oak_list: Array = []
	var guard := 0
	while oak_list.size() < oaks and guard < 400:
		guard += 1
		var o := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		if occupied.has(o):
			continue
		var axes: Array = [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)]]
		if rng.randi() % 2 == 1:
			axes.reverse()
		for axis in axes:
			var a: Vector2i = o + axis[0]
			var b: Vector2i = o + axis[1]
			if not _inside(a, w, h) or not _inside(b, w, h):
				continue
			if occupied.has(a) or occupied.has(b) or _touches_tent(a, tents) or _touches_tent(b, tents):
				continue
			occupied[o] = true
			occupied[a] = true
			occupied[b] = true
			tents.append(a)
			tents.append(b)
			trees.append(o)
			oak_list.append(o)
			break
	if oak_list.size() < oaks:
		return {}
	var placed := 0
	guard = 0
	while placed < pines and guard < 600:
		guard += 1
		var t := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
		if occupied.has(t) or _touches_tent(t, tents):
			continue
		var options: Array = []
		for d in DIRS:
			var n: Vector2i = t + d
			if _inside(n, w, h) and not occupied.has(n):
				options.append(n)
		if options.is_empty():
			continue
		var tree: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		occupied[t] = true
		occupied[tree] = true
		tents.append(t)
		trees.append(tree)
		placed += 1
	if placed < pines:
		return {}
	var row_counts: Array = []
	var col_counts: Array = []
	row_counts.resize(h)
	row_counts.fill(0)
	col_counts.resize(w)
	col_counts.fill(0)
	for t in tents:
		row_counts[t.y] += 1
		col_counts[t.x] += 1
	return {"trees": trees, "oaks": oak_list, "tents": tents, "row_counts": row_counts,
		"col_counts": col_counts, "w": w, "h": h}

static func _inside(c: Vector2i, w: int, h: int) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

## A whole Insane board: oaks placed, unique with every count shown, then the
## counts taken off one by one in a random order wherever the answer stays
## unique, and kept only if the oaks are what makes it unique. {} on a miss.
static func generate_oaks(rng: RandomNumberGenerator, w: int, h: int, pines: int, oaks: int,
		budget := 400000) -> Dictionary:
	for _attempt in 40:
		var out := place_oaks(rng, w, h, pines, oaks)
		if out.is_empty():
			continue
		if count_layouts(out.trees, out.oaks, out.row_counts, out.col_counts, w, h, 2, false, budget) != 1:
			continue
		var lines: Array = []
		for y in h:
			lines.append([0, y])
		for x in w:
			lines.append([1, x])
		for i in range(lines.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = lines[i]; lines[i] = lines[j]; lines[j] = t
		for ln in lines:
			var arr: Array = out.row_counts if ln[0] == 0 else out.col_counts
			var keep: int = arr[ln[1]]
			arr[ln[1]] = HIDDEN
			if count_layouts(out.trees, out.oaks, out.row_counts, out.col_counts, w, h, 2, false, budget) != 1:
				arr[ln[1]] = keep
		if count_layouts(out.trees, out.oaks, out.row_counts, out.col_counts, w, h, 2, true, budget) < 2:
			continue
		out["ok"] = true
		return out
	return {}

## The distinct tent layouts the board allows, up to `limit`. Each tree picks
## its own tents -- one, or for an oak an opposite pair (`relax` lets an oak
## take one or two) -- the most constrained tree first, with the known counts
## bounding each line from above and below. Layouts are counted by the tents
## they pitch, not by which tree took which, so two trees swapping a pair of
## tents is one answer. `budget` caps the nodes; running out returns -1, which
## every caller reads as "unproved" (neither unique nor ambiguous).
static func count_layouts(trees: Array, oaks: Array, row_counts: Array, col_counts: Array,
		w: int, h: int, limit: int, relax := false, budget := 400000) -> int:
	var tree_set: Dictionary = {}
	for t in trees:
		tree_set[t] = true
	var oak_set: Dictionary = {}
	for o in oaks:
		oak_set[o] = true
	var opts: Array = []
	for t in trees:
		var singles: Array = []
		for d in DIRS:
			var n: Vector2i = t + d
			if _inside(n, w, h) and not tree_set.has(n):
				singles.append(n)
		var list: Array = []
		if oak_set.has(t):
			for axis in [[Vector2i(0, -1), Vector2i(0, 1)], [Vector2i(-1, 0), Vector2i(1, 0)]]:
				var a: Vector2i = t + axis[0]
				var b: Vector2i = t + axis[1]
				if singles.has(a) and singles.has(b):
					list.append([a, b])
			if relax:
				for s in singles:
					list.append([s])
		else:
			for s in singles:
				list.append([s])
		if list.is_empty():
			return 0
		opts.append(list)
	var ctx := {
		"opts": opts, "w": w, "h": h, "rc": row_counts, "cc": col_counts,
		"rows": _zeros(h), "cols": _zeros(w), "block": _zeros(w * h),
		"done": _falses(trees.size()), "seen": {}, "limit": limit, "nodes": 0,
		"budget": budget, "blown": false, "left": trees.size(),
		"rem_r": _zeros(h), "rem_c": _zeros(w),
	}
	# What the trees still to place could add to each line at most.
	for i in opts.size():
		var mr := {}
		var mc := {}
		for o in opts[i]:
			var r := {}
			var c := {}
			for cell in o:
				r[cell.y] = int(r.get(cell.y, 0)) + 1
				c[cell.x] = int(c.get(cell.x, 0)) + 1
			for k in r:
				mr[k] = maxi(int(mr.get(k, 0)), int(r[k]))
			for k in c:
				mc[k] = maxi(int(mc.get(k, 0)), int(c[k]))
		ctx["mr_%d" % i] = mr
		ctx["mc_%d" % i] = mc
		for k in mr:
			ctx.rem_r[k] += int(mr[k])
		for k in mc:
			ctx.rem_c[k] += int(mc[k])
	_layouts(ctx)
	if ctx.blown:
		return -1
	return mini(ctx.seen.size(), limit)

static func _zeros(n: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(n)
	a.fill(0)
	return a

static func _falses(n: int) -> Array:
	var a: Array = []
	a.resize(n)
	a.fill(false)
	return a

static func _fits(ctx: Dictionary, o: Array) -> bool:
	var w: int = ctx.w
	var rows: PackedInt32Array = ctx.rows
	var cols: PackedInt32Array = ctx.cols
	var add_r := {}
	var add_c := {}
	for cell in o:
		if ctx.block[cell.y * w + cell.x] > 0:
			return false
		add_r[cell.y] = int(add_r.get(cell.y, 0)) + 1
		add_c[cell.x] = int(add_c.get(cell.x, 0)) + 1
	for r in add_r:
		var want: int = ctx.rc[r]
		if want >= 0 and rows[r] + int(add_r[r]) > want:
			return false
	for c in add_c:
		var want: int = ctx.cc[c]
		if want >= 0 and cols[c] + int(add_c[c]) > want:
			return false
	return true

static func _mark(ctx: Dictionary, o: Array, by: int) -> void:
	var w: int = ctx.w
	var h: int = ctx.h
	for cell in o:
		ctx.rows[cell.y] += by
		ctx.cols[cell.x] += by
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := Vector2i(cell.x + dx, cell.y + dy)
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
					ctx.block[n.y * w + n.x] += by

## Whether every known line can still reach its count with what is left.
static func _reachable(ctx: Dictionary) -> bool:
	for r in ctx.h:
		var want: int = ctx.rc[r]
		if want >= 0 and ctx.rows[r] + ctx.rem_r[r] < want:
			return false
	for c in ctx.w:
		var want: int = ctx.cc[c]
		if want >= 0 and ctx.cols[c] + ctx.rem_c[c] < want:
			return false
	return true

static func _layouts(ctx: Dictionary) -> void:
	if ctx.seen.size() >= ctx.limit or ctx.blown:
		return
	ctx.nodes += 1
	if ctx.nodes > ctx.budget:
		ctx.blown = true
		return
	if ctx.left == 0:
		for r in ctx.h:
			if ctx.rc[r] >= 0 and ctx.rows[r] != ctx.rc[r]:
				return
		for c in ctx.w:
			if ctx.cc[c] >= 0 and ctx.cols[c] != ctx.cc[c]:
				return
		ctx.seen[_layout_key(ctx)] = true
		return
	# The tree with the fewest options that still fit goes next.
	var best := -1
	var best_fit: Array = []
	for i in ctx.opts.size():
		if ctx.done[i]:
			continue
		var fit: Array = []
		for o in ctx.opts[i]:
			if _fits(ctx, o):
				fit.append(o)
		if fit.is_empty():
			return
		if best < 0 or fit.size() < best_fit.size():
			best = i
			best_fit = fit
			if fit.size() == 1:
				break
	var mr: Dictionary = ctx["mr_%d" % best]
	var mc: Dictionary = ctx["mc_%d" % best]
	ctx.done[best] = true
	ctx.left -= 1
	for k in mr:
		ctx.rem_r[k] -= int(mr[k])
	for k in mc:
		ctx.rem_c[k] -= int(mc[k])
	for o in best_fit:
		_mark(ctx, o, 1)
		ctx["pick_%d" % best] = o
		if _reachable(ctx):
			_layouts(ctx)
		_mark(ctx, o, -1)
		if ctx.seen.size() >= ctx.limit or ctx.blown:
			break
	for k in mr:
		ctx.rem_r[k] += int(mr[k])
	for k in mc:
		ctx.rem_c[k] += int(mc[k])
	ctx.done[best] = false
	ctx.left += 1

static func _layout_key(ctx: Dictionary) -> String:
	var cells: Array = []
	for i in ctx.opts.size():
		for cell in ctx["pick_%d" % i]:
			cells.append(cell.y * ctx.w + cell.x)
	cells.sort()
	return str(cells)

## An oak board as a bank entry, and back (JSON numbers arrive as floats).
static func to_bank(out: Dictionary) -> Dictionary:
	var pts := func(list: Array) -> Array:
		var a: Array = []
		for c in list:
			a.append([c.x, c.y])
		return a
	return {"w": out.w, "h": out.h, "trees": pts.call(out.trees), "oaks": pts.call(out.oaks),
		"tents": pts.call(out.tents), "rows": out.row_counts, "cols": out.col_counts}

static func from_bank(b: Dictionary) -> Dictionary:
	if not (b.get("trees") is Array and b.get("tents") is Array and b.get("rows") is Array
			and b.get("cols") is Array):
		return {}
	var cells := func(list: Array) -> Array:
		var a: Array = []
		for c in list:
			a.append(Vector2i(int(c[0]), int(c[1])))
		return a
	var ints := func(list: Array) -> Array:
		var a: Array = []
		for n in list:
			a.append(int(n))
		return a
	return {"w": int(b.w), "h": int(b.h), "trees": cells.call(b.trees),
		"oaks": cells.call(b.get("oaks", [])), "tents": cells.call(b.tents),
		"row_counts": ints.call(b.rows), "col_counts": ints.call(b.cols), "ok": true}

## The win test with oaks and hidden counts: every known count met, no tent
## on a tree or touching another, and a matching that gives each tree its own
## adjacent tent and each oak two (an oak stands in the list twice).
static func is_valid_oak_solution(tents: Array, trees: Array, oaks: Array, row_counts: Array,
		col_counts: Array, w: int, h: int) -> bool:
	var slots: Array = trees.duplicate()
	slots.append_array(oaks)
	if tents.size() != slots.size():
		return false
	var rows := _zeros(h)
	var cols := _zeros(w)
	var seen: Dictionary = {}
	for t in tents:
		if seen.has(t):
			return false
		seen[t] = true
		rows[t.y] += 1
		cols[t.x] += 1
	for y in h:
		if int(row_counts[y]) >= 0 and rows[y] != int(row_counts[y]):
			return false
	for x in w:
		if int(col_counts[x]) >= 0 and cols[x] != int(col_counts[x]):
			return false
	for t in trees:
		if seen.has(t):
			return false
	for a in tents.size():
		for b in range(a + 1, tents.size()):
			var p: Vector2i = tents[a]
			var q: Vector2i = tents[b]
			if absi(p.x - q.x) <= 1 and absi(p.y - q.y) <= 1:
				return false
	var match_of: Dictionary = {}
	for i in slots.size():
		if not _augment(i, slots, tents, {}, match_of):
			return false
	return true
