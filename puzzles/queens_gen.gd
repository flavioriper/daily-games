extends RefCounted

## Queens. Seat one queen in every row, every column and every coloured
## region, and never let two queens touch, not even at a corner -- the
## no-touch rule of the game most players know, chosen over chess diagonals
## because the regions carry the deductions.
##
## The board is generated in the easy direction and proved in the hard one:
## the queens are placed first (a permutation with the no-touch rule, found
## row by row with backtracking), then a region is grown from each queen's
## own cell, one unclaimed cell at a time, favouring whichever region is
## still under three cells and, within it, the free candidate touching the
## most cells it already owns (a candidate that is not the best is still let
## through a quarter of the time, so the shapes stay blobby rather than
## reading as a maze). Uniform growth like that almost never lands on a
## unique board by itself -- measured at 0 unique boards in 200 attempts on
## both 8x8 and 9x9, and 12 in 200 on 7x7, because a blobby partition rarely
## rules out enough of the hundreds to tens of thousands of legal no-touch
## seatings a bare board still allows. So a repair pass follows every grown
## court: while more than one seating remains, it takes a cell where some
## other seating disagrees with the answer, and if handing that cell to a
## neighbouring region keeps the loser's region connected, tries the move
## and keeps it only when the seating count does not rise. A board is kept
## only when repair drives that count to exactly one. Repair runs in two
## phases: a quick pass that gives up on a stalled board early, across
## ATTEMPTS boards, and then, only for the rare seed none of those crack, a
## slower, patient pass across PATIENT_ATTEMPTS more, each one spending its
## full REPAIRS budget rather than giving up early when the count stalls.
##
## Seeded only by the `rng` handed in, so a day is the same court on every
## phone. Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md,
## section 4.

const Logic = preload("res://puzzles/queens_logic.gd")

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
## How many courts to try before giving the last one back unproved. Raised
## from 30 once repair could give up on a board early (see STALE) rather
## than always spending its full REPAIRS budget.
const ATTEMPTS := 60
## How many repair moves to attempt on one court before giving up on it.
const REPAIRS := 400
## A board whose answer count has not fallen in this many moves is not
## going to; a fresh board is cheaper than the remaining REPAIRS.
const STALE := 40
## The quick attempts give up on a slow board early; a seed none of them
## crack gets the patient repair that round 1 measured at 0 fails in 20,
## so the floor is the old floor and only the rare seed pays for it.
const PATIENT_ATTEMPTS := 30
## A region below this many cells is grown before any region at or above it.
const MIN_REGION := 3
## How many seatings the repair pass looks for; only their count matters.
const SOLUTIONS_SEEN := 6
## Chance a candidate that is not the best-scoring one is grown anyway.
const STRAY := 0.25
## From SMALL_FROM on (the 9 by 9 hard court), SMALL_REGIONS regions stop
## growing at 2 to SMALL_CAP cells. With every region grown alike, a 9 by 9
## was too loose for repair to pin down in time: a median 164 ms and a worst
## of 950 ms, 130 seeds in 300 past the 194 ms gate, all spent on courts
## thrown away unproved. A few small regions are what a made-by-hand court
## has anyway, and never a single cell, which would hand out a queen. Below
## 9 nothing changes: 7 by 7 and 8 by 8 hand out the same courts as before.
const SMALL_FROM := 9
const SMALL_REGIONS := 3
const SMALL_CAP := 4
## Growth gives up rather than loop forever if the board never fills.
const GROW_GUARD := 20000

static func generate(rng: RandomNumberGenerator, n: int, keep := 1) -> Dictionary:
	var last: Dictionary = {}
	for _attempt in ATTEMPTS:
		var queens := _place_queens(rng, n)
		if queens.is_empty():
			continue
		var region := _grow_regions(rng, n, queens)
		if region.is_empty():
			continue
		last = {"region": region, "solution": queens, "n": n, "ok": false}
		if _repair(rng, region, n, queens, REPAIRS, false, keep):
			last.ok = true
			return last
	# The quick pass above gives up on a slow board early; for the rare seed
	# it never cracks, try again without that cap.
	for _attempt in PATIENT_ATTEMPTS:
		var queens := _place_queens(rng, n)
		if queens.is_empty():
			continue
		var region := _grow_regions(rng, n, queens)
		if region.is_empty():
			continue
		last = {"region": region, "solution": queens, "n": n, "ok": false}
		if _repair(rng, region, n, queens, REPAIRS, true, keep):
			last.ok = true
			return last
	if last.is_empty():
		return {"region": [], "solution": PackedInt32Array(), "n": n, "ok": false}
	return last

## How many seatings `region` allows, up to `limit`.
static func solve_count(region: Array, n: int, limit: int, quota := PackedInt32Array()) -> int:
	return _solutions(_flatten(region, n), n, limit, quota).size()

## Whether `cols` (row -> column) is a full legal seating on `region`.
static func legal(region: Array, n: int, cols: PackedInt32Array, quota := PackedInt32Array()) -> bool:
	if cols.size() != n:
		return false
	var flat := _flatten(region, n)
	var used_col: Dictionary = {}
	var used_reg: Dictionary = {}
	for r in n:
		var c := int(cols[r])
		if c < 0 or c >= n or used_col.has(c):
			return false
		if r > 0 and absi(int(cols[r - 1]) - c) <= 1:
			return false
		var g := flat[r * n + c]
		var cap := int(quota[g]) if g < quota.size() else 1
		if int(used_reg.get(g, 0)) >= cap:
			return false
		used_col[c] = true
		used_reg[g] = int(used_reg.get(g, 0)) + 1
	return true

## `region` ([r][c]) packed into one row-major array, `r * n + c` -> region.
## The hot paths (`_search`, `_connected_without`, `_repair`'s whole loop)
## index this instead of the nested `Array` of `Array`, which boxes every
## cell read as a Variant through two levels of dynamic dispatch.
static func _flatten(region: Array, n: int) -> PackedInt32Array:
	var flat := PackedInt32Array()
	flat.resize(n * n)
	for r in n:
		var row: Array = region[r]
		for c in n:
			flat[r * n + c] = int(row[c])
	return flat

## The inverse of `_flatten`, writing into an existing nested `region` (so a
## caller holding that reference, such as `generate`'s `last`, sees it).
static func _unflatten_into(flat: PackedInt32Array, n: int, region: Array) -> void:
	for r in n:
		var row: Array = region[r]
		for c in n:
			row[c] = flat[r * n + c]

## Every full legal seating on flattened `region`, up to `limit` of them.
## `quota` is how many queens each patch takes (Insane's misty patches take
## two); empty means one each.
static func _solutions(region: PackedInt32Array, n: int, limit: int, quota := PackedInt32Array()) -> Array:
	var out: Array = []
	# How many more queens each patch takes: the room left in it.
	var used_reg := PackedByteArray()
	used_reg.resize(n)
	used_reg.fill(1)
	for g in quota.size():
		used_reg[g] = quota[g]
	if not quota.is_empty():
		for g in range(quota.size(), n):
			used_reg[g] = 0
	var cur := PackedInt32Array()
	cur.resize(n)
	var reach := _reach(region, n)
	_search(region, n, 0, -1, cur, 0, used_reg, reach, limit, out)
	return out

## Per row `r` and region id `g`, at `r * n + g`, the columns (a bitmask)
## where `g` has a cell in row `r` or any row below it -- precomputed once a
## call so `_search` can kill a branch the moment a region it has not seated
## yet has no cell left in a free column, without changing which seatings it
## finds or the order it finds them in. It used to wait until the region had
## no *rows* left, which let a 9 by 9 court (the hard band) run a median
## 164 ms and a worst of 950 ms, 130 seeds in 300 past the 194 ms gate.
static func _reach(region: PackedInt32Array, n: int) -> PackedInt32Array:
	var reach := PackedInt32Array()
	reach.resize(n * n)
	for r in range(n - 1, -1, -1):
		var base := r * n
		if r < n - 1:
			for g in n:
				reach[base + g] = reach[base + n + g]
		for c in n:
			reach[base + region[base + c]] |= 1 << c
	return reach

static func _search(region: PackedInt32Array, n: int, r: int, prev: int, cur: PackedInt32Array,
		cols: int, used_reg: PackedByteArray, reach: PackedInt32Array,
		limit: int, out: Array) -> bool:
	if r == n:
		out.append(cur.duplicate())
		return out.size() >= limit
	var base := r * n
	for g in n:
		if used_reg[g] and reach[base + g] & ~cols == 0:
			return false
	for c in n:
		if cols & (1 << c):
			continue
		var g := region[base + c]
		if not used_reg[g]:
			continue
		if prev >= 0 and absi(c - prev) <= 1:
			continue
		used_reg[g] -= 1
		cur[r] = c
		var stop := _search(region, n, r + 1, c, cur, cols | (1 << c), used_reg, reach, limit, out)
		used_reg[g] += 1
		if stop:
			return true
	return false

## Whether region `g` stays connected with `cell` taken out of it, flooding
## flattened `region` with a bitmask rather than a `Dictionary` of `Vector2i`
## keys.
static func _connected_without(region: PackedInt32Array, n: int, g: int, cell: Vector2i) -> bool:
	var cell_idx := cell.y * n + cell.x
	var start := -1
	var total := 0
	for idx in n * n:
		if region[idx] == g and idx != cell_idx:
			total += 1
			if start < 0:
				start = idx
	if start < 0:
		return false
	var visited := PackedByteArray()
	visited.resize(n * n)
	visited[start] = 1
	var reached := 1
	var stack: Array = [start]
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		var r := idx / n
		var c := idx % n
		for d in DIRS:
			var qx: int = c + d.x
			var qy: int = r + d.y
			if qx < 0 or qy < 0 or qx >= n or qy >= n:
				continue
			var qidx: int = qy * n + qx
			if qidx == cell_idx or visited[qidx] or region[qidx] != g:
				continue
			visited[qidx] = 1
			reached += 1
			stack.append(qidx)
	return reached == total

## Drives a grown court to a unique seating by moving cells across region
## seams that a second seating uses, keeping a move only when the number of
## seatings does not rise. Works on one flattened copy of `region` for the
## whole loop and writes it back into `region` in place before returning
## (`region` itself is only ever read or replaced wholesale, never
## re-flattened mid-loop); true if it ends unique. Gives up on this court
## once STALE moves in a row have failed to lower the seating count -- see
## STALE's own line -- unless `patient` is true, in which case it runs the
## full `iters` regardless.
static func _repair(rng: RandomNumberGenerator, region: Array, n: int, sol: PackedInt32Array,
		iters: int, patient: bool = false, keep := 1, quota := PackedInt32Array()) -> bool:
	var flat := _flatten(region, n)
	var sols: Array = _solutions(flat, n, SOLUTIONS_SEEN, quota)
	var count := sols.size()
	var stale := 0
	for _it in iters:
		if count <= 1:
			break
		stale += 1
		if not patient and stale >= STALE:
			break
		var others: Array = []
		for s in sols:
			if not _same_seating(s, sol):
				others.append(s)
		if others.is_empty():
			break
		var s2: PackedInt32Array = others[rng.randi_range(0, others.size() - 1)]
		var rows: Array = []
		for r in n:
			if int(s2[r]) != int(sol[r]):
				rows.append(r)
		var r: int = rows[rng.randi_range(0, rows.size() - 1)]
		var c := int(s2[r])
		var idx := r * n + c
		var g := flat[idx]
		var cell := Vector2i(c, r)
		var neighbour_regions: Array = []
		for d in DIRS:
			var q: Vector2i = cell + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n:
				continue
			var g2 := flat[q.y * n + q.x]
			if g2 != g and not neighbour_regions.has(g2):
				neighbour_regions.append(g2)
		if neighbour_regions.is_empty() or not _connected_without(flat, n, g, cell):
			continue
		if keep > 1 and _size_of(flat, g) <= keep:
			continue
		var g2: int = neighbour_regions[rng.randi_range(0, neighbour_regions.size() - 1)]
		flat[idx] = g2
		var s3: Array = _solutions(flat, n, SOLUTIONS_SEEN, quota)
		if s3.size() <= count:
			sols = s3
			if s3.size() < count:
				stale = 0
			count = s3.size()
		else:
			flat[idx] = g
	_unflatten_into(flat, n, region)
	return count == 1

static func _size_of(flat: PackedInt32Array, g: int) -> int:
	var k := 0
	for v in flat:
		if v == g:
			k += 1
	return k

static func _same_seating(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true

## A random legal permutation: row by row in a shuffled column order,
## backtracking when a column repeats or the queen touches the one above.
static func _place_queens(rng: RandomNumberGenerator, n: int) -> PackedInt32Array:
	var cols := PackedInt32Array()
	cols.resize(n)
	if _fill_row(rng, n, 0, cols, {}):
		return cols
	return PackedInt32Array()

static func _fill_row(rng: RandomNumberGenerator, n: int, r: int, cols: PackedInt32Array,
		used: Dictionary) -> bool:
	if r == n:
		return true
	var order: Array = range(n)
	_shuffle(order, rng)
	for c in order:
		if used.has(c):
			continue
		if r > 0 and absi(int(cols[r - 1]) - int(c)) <= 1:
			continue
		cols[r] = c
		used[c] = true
		if _fill_row(rng, n, r + 1, cols, used):
			return true
		used.erase(c)
	return false

## Region i starts on queen i's cell. Until every cell is claimed, a region
## under MIN_REGION cells is grown first (any live region once none are
## that small), taking the free cell touching it that already borders the
## most of its own cells -- ties, and a STRAY chance of an also-ran, break
## the pattern up so the shapes are not all the same silhouette.
static func _grow_regions(rng: RandomNumberGenerator, n: int, queens: PackedInt32Array) -> Array:
	var region: Array = []
	for r in n:
		var row: Array = []
		row.resize(n)
		row.fill(-1)
		region.append(row)
	for r in n:
		region[r][int(queens[r])] = r
	var size := PackedInt32Array()
	size.resize(n)
	size.fill(1)
	var alive: Array = []
	for _i in n:
		alive.append(true)
	var cap := PackedInt32Array()
	cap.resize(n)
	cap.fill(n * n)
	if n >= SMALL_FROM:
		var order: Array = range(n)
		_shuffle(order, rng)
		for j in SMALL_REGIONS:
			cap[int(order[j])] = rng.randi_range(2, SMALL_CAP)
	var claimed := n
	var guard := 0
	while claimed < n * n and guard < GROW_GUARD:
		guard += 1
		var small: Array = []
		var any: Array = []
		for j in n:
			if alive[j]:
				any.append(j)
				if int(size[j]) < MIN_REGION:
					small.append(j)
		if any.is_empty():
			break
		var pool: Array = small if not small.is_empty() else any
		var i: int = pool[rng.randi_range(0, pool.size() - 1)]
		var cand := _candidates(region, n, i) if int(size[i]) < int(cap[i]) else []
		if cand.is_empty():
			alive[i] = false
			continue
		var best := 0
		for c in cand:
			best = maxi(best, int(c[1]))
		var top: Array = []
		for c in cand:
			if int(c[1]) == best or rng.randf() < STRAY:
				top.append(c)
		var p: Array = top[rng.randi_range(0, top.size() - 1)]
		var pos: Vector2i = p[0]
		region[pos.y][pos.x] = i
		size[i] += 1
		claimed += 1
	if claimed != n * n:
		return []
	return region

## The free cells touching region `i`, each paired with how many of its own
## four neighbours already belong to `i`.
static func _candidates(region: Array, n: int, i: int) -> Array:
	var cand: Array = []
	var seen: Dictionary = {}
	for r in n:
		for c in n:
			if int(region[r][c]) != i:
				continue
			for d in DIRS:
				var p: Vector2i = Vector2i(c, r) + d
				if p.x < 0 or p.y < 0 or p.x >= n or p.y >= n or int(region[p.y][p.x]) >= 0:
					continue
				if seen.has(p):
					continue
				seen[p] = true
				var nb := 0
				for d2 in DIRS:
					var q: Vector2i = p + d2
					if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n and int(region[q.y][q.x]) == i:
						nb += 1
				cand.append([p, nb])
	return cand

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

# --- the bands, graded ---

## No patch is ever a single cell: a one-cell patch is a queen handed out
## before the first thought, and seating her crosses enough to hand out the
## next -- the chain players wrote in about ("too many starting single cells,
## and filling them creates new single cells"). Measured 2026-09-30 before
## this: 0.53, 0.45 and 0.93 free queens on the opening court of 7, 8 and 9.
const KEEP := 2
## How many courts a band draws, at most, looking for one that asks for the
## thinking the band promises (`fits`); past that the first proved one is
## dealt.
const GRADED_TRIES := [6, 10, 14]

## A court for `band` (0 Easy, 1 Medium, 2 Hard), graded by the logic solver
## (puzzles/queens_logic.gd):
## - Easy finishes on singles, one-line bands and reach, never a band over
##   several lines or a supposition;
## - Medium needs thinking at least five times, or a band over several lines;
## - Hard needs two bands over several lines, or a supposition -- and every
##   Hard court still finishes without a guess.
static func graded(rng: RandomNumberGenerator, band: int, n: int) -> Dictionary:
	var first: Dictionary = {}
	var ones := PackedInt32Array()
	ones.resize(n)
	ones.fill(1)
	for _t in GRADED_TRIES[clampi(band, 0, GRADED_TRIES.size() - 1)]:
		var out := generate(rng, n, KEEP)
		if not out.ok:
			if first.is_empty():
				first = out
			continue
		var g := Logic.grade(_flatten(out.region, n), n, ones, band >= 2)
		out["grade"] = g
		if first.is_empty() or not first.ok:
			first = out
		if fits(band, g):
			return out
	return first

static func fits(band: int, g: Dictionary) -> bool:
	match band:
		0:
			return bool(g.solved2) and int(g.wide) == 0
		1:
			return bool(g.solved2) and (int(g.wide) >= 1 or int(g.thinks) >= 5)
		_:
			return bool(g.solved) and (not bool(g.solved2) or int(g.wide) >= 2)

# --- Insane: Morning Mist ---

## A court where mist has faded the seam between `mists` pairs of
## neighbouring patches: each such patch takes two queens, every row and
## column still one. Grown as an ordinary unique court, then merged, then
## repaired again (counting a misty patch as two) until one seating is left.
## Returns the `generate` shape plus "quota" (patch -> queens) and "mist"
## (the misty patches' ids); "ok" is false when repair never got it unique.
static func mist(rng: RandomNumberGenerator, n: int, mists: int, keep := 2) -> Dictionary:
	var base := generate(rng, n, keep)
	if not base.ok:
		return {}
	var flat := _flatten(base.region, n)
	# Which patches touch which, then `mists` disjoint touching pairs.
	var touch: Dictionary = {}
	for i in n * n:
		var r := i / n
		var c := i % n
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var x: int = c + d.x
			var y: int = r + d.y
			if x >= n or y >= n:
				continue
			var a := flat[i]
			var b := flat[y * n + x]
			if a != b:
				touch[Vector2i(mini(a, b), maxi(a, b))] = true
	var pairs: Array = touch.keys()
	_shuffle(pairs, rng)
	var used: Dictionary = {}
	var merged: Array = []
	for p in pairs:
		if merged.size() >= mists:
			break
		if used.has(p.x) or used.has(p.y):
			continue
		used[p.x] = true
		used[p.y] = true
		merged.append(p)
	if merged.size() < mists:
		return {}
	# Fold each pair's second patch into its first, then number the patches
	# 0..m-1 again.
	for p in merged:
		for i in n * n:
			if flat[i] == p.y:
				flat[i] = p.x
	var ids: Dictionary = {}
	for i in n * n:
		if not ids.has(flat[i]):
			ids[flat[i]] = ids.size()
		flat[i] = ids[flat[i]]
	var quota := PackedInt32Array()
	quota.resize(ids.size())
	quota.fill(1)
	var misty: Array = []
	for p in merged:
		quota[ids[p.x]] = 2
		misty.append(ids[p.x])
	var region: Array = []
	for r in n:
		var row: Array = []
		row.resize(n)
		region.append(row)
	_unflatten_into(flat, n, region)
	var ok := _repair(rng, region, n, base.solution, REPAIRS * 2, true, keep, quota)
	return {"region": region, "solution": base.solution, "n": n, "ok": ok, "quota": quota,
		"mist": misty}

# --- the banks ---

## The banks' encoding (content/insane/queens.json for Insane,
## content/insane/queens_hard.json for Hard): the court row by row, one digit
## a cell for its patch; the patches' quotas; the answer, row by row.
static func to_bank(out: Dictionary) -> Dictionary:
	var n: int = out.n
	var cells := ""
	for r in n:
		for c in n:
			cells += str(int(out.region[r][c]))
	var quota := PackedInt32Array()
	if out.has("quota"):
		quota = out.quota
	else:
		quota.resize(n)
		quota.fill(1)
	var answer := ""
	for r in n:
		answer += str(int(out.solution[r]))
	return {"n": n, "cells": cells, "quota": Array(quota), "answer": answer}

## A bank entry back in `generate`'s shape, re-proved: "ok" only when the
## logic solver finishes it without a guess and lands on the stored answer.
static func from_bank(board: Dictionary) -> Dictionary:
	if board.is_empty() or not board.has("cells"):
		return {}
	var n := int(board.n)
	var cells: String = board.cells
	var answer: String = board.answer
	if cells.length() != n * n or answer.length() != n:
		return {}
	var region: Array = []
	for r in n:
		var row: Array = []
		for c in n:
			row.append(int(cells[r * n + c]))
		region.append(row)
	var quota := PackedInt32Array()
	for q in board.quota:
		quota.append(int(q))
	var solution := PackedInt32Array()
	for r in n:
		solution.append(int(answer[r]))
	var misty: Array = []
	for g in quota.size():
		if quota[g] > 1:
			misty.append(g)
	var proved := Logic.answer(_flatten(region, n), n, quota) == solution
	return {"region": region, "solution": solution, "n": n, "ok": proved, "quota": quota,
		"mist": misty}
