extends RefCounted

## Domino Patio's day (spec docs/superpowers/specs/2026-10-22-domino-patio-design.md).
## Built from its answer: a patio grown a domino at a time inside the band's
## box, so it always has a tiling; the house's dominoes dealt onto that
## tiling, each a different one of the double-six set; the patio's squares
## parted into beds; and a rule for each bed read off the answer's spots
## (a sum, under or over a number, all the same, all different, or none).
## Then the rules are tightened until the answer is the only way to lay the
## tiles: a solver counts, to two, the different spot patterns that keep every
## bed's rule, and each time it finds a second, a bed that differs between
## the two is given a stricter rule or split. A day whose search runs past
## `CAP` steps is thrown away and dealt again.
##
## Insane, **The Spare**: one tile more than the patio holds, and it goes
## nowhere. The solver deals with it as with any tile: a way to lay the day
## that leaves a different tile over counts as a second answer.

enum Rule { NONE, SUM, LESS, MORE, SAME, APART }

## Per band, Easy to Insane: the tiles laid, the spare tiles, the box the
## patio grows in, the chance a bed has no rule, and the rules a bed may
## take beyond a sum and all the same.
const TILES := [4, 6, 8, 8]
const SPARE := [0, 0, 0, 1]
const BOX := [Vector2i(4, 4), Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 6)]
const NONE_P := [0.12, 0.18, 0.2, 0.2]
const BOUNDS := [false, true, true, true]
const APART := [false, false, true, true]
## Bed sizes, with their weights.
const SIZES := [1, 2, 3, 4]
const SIZE_W := [[0.15, 0.5, 0.35, 0.0], [0.1, 0.4, 0.35, 0.15], [0.1, 0.3, 0.35, 0.25], [0.08, 0.3, 0.35, 0.27]]
const SAME_PULL := 0.75
const TRIES := 40
const PARTS := 3
const VALUES := 3
const TIGHTEN := 24
## How many steps the solver may take on one count before the day is thrown.
const CAP := 4000
## Right, down, left, up.
const DIRS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

var cols := 0
var rows := 0
## Per cell (row * cols + col): its bed, -1 off the patio.
var bed_of := PackedInt32Array()
## Each bed: {rule, n, cells}.
var beds: Array = []
## Each tile's two numbers (x is the half laid at the anchor).
var tiles: Array[Vector2i] = []
## Each tile's place in the answer: (anchor cell, direction); -1 for a spare.
var answer: Array[Vector2i] = []
## The answer's spots per cell, -1 off the patio.
var spots := PackedInt32Array()
## The last count's steps, and whether the day came out unique.
var steps := 0
var unique := false
var tries := 0

var _rng: RandomNumberGenerator
var _band := 0
# the solver's state
var _cover := PackedInt32Array()
var _val := PackedInt32Array()
var _used := PackedByteArray()
var _order := PackedInt32Array()
var _cnt := PackedInt32Array()
var _sum := PackedInt32Array()
var _mask := PackedInt32Array()
var _first := PackedInt32Array()
var _rule := PackedInt32Array()
var _n := PackedInt32Array()
var _size := PackedInt32Array()
var _found := 0
var _sol1 := PackedInt32Array()
var _sol2 := PackedInt32Array()
var _aborted := false
var _sig1 := PackedInt32Array()

func deal(rng: RandomNumberGenerator, band: int) -> void:
	_rng = rng
	_band = clampi(band, 0, TILES.size() - 1)
	for t in TRIES:
		tries = t + 1
		if not _grow():
			continue
		# a few partings of the same patio, and a few deals of numbers on
		# each, before a bed is ever split: a split leaves a lone square,
		# and a patio of lone squares is a sum table, not a puzzle
		for p in PARTS:
			_part()
			for v in VALUES:
				if v > 0:
					_revalue()
				if _tighten(p == PARTS - 1 and v == VALUES - 1):
					unique = true
					return
	# The last deal stands even if a second way was found: the board judges
	# by the beds' rules, never by the answer, so it is still a fair day.
	unique = false

# --- the patio and its answer ---

func _grow() -> bool:
	var box: Vector2i = BOX[_band]
	cols = box.x
	rows = box.y
	var n: int = int(TILES[_band])
	var taken := PackedByteArray()
	taken.resize(cols * rows)
	var pairs: Array[Vector2i] = []
	var start := Vector2i(cols / 2 - 1, rows / 2)
	pairs.append(Vector2i(_idx(start), _idx(start + Vector2i(1, 0))))
	taken[pairs[0].x] = 1
	taken[pairs[0].y] = 1
	while pairs.size() < n:
		var best: Array = []
		var best_w := -1.0
		for i in cols * rows:
			if taken[i] == 1:
				continue
			var c := _cell(i)
			var near := 0
			for d: Vector2i in DIRS:
				var o := c + d
				if _inside(o) and taken[_idx(o)] == 1:
					near += 1
			if near == 0:
				continue
			for d: Vector2i in DIRS:
				var o := c + d
				if not _inside(o) or taken[_idx(o)] == 1:
					continue
				var near2 := 0
				for d2: Vector2i in DIRS:
					var o2 := o + d2
					if _inside(o2) and taken[_idx(o2)] == 1:
						near2 += 1
				# snug pairs are likelier, so the patio grows round, not in arms
				var w := float(near + near2) + _rng.randf() * 2.2
				if w > best_w:
					best_w = w
					best = [i, _idx(o)]
		if best.is_empty():
			return false
		pairs.append(Vector2i(best[0], best[1]))
		taken[best[0]] = 1
		taken[best[1]] = 1
	# trim the box to the patio
	var lo := Vector2i(cols, rows)
	var hi := Vector2i(-1, -1)
	for i in cols * rows:
		if taken[i] == 1:
			var c := _cell(i)
			lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	var old_cols := cols
	cols = hi.x - lo.x + 1
	rows = hi.y - lo.y + 1
	var moved := func(i: int) -> int:
		var c := Vector2i(i % old_cols, i / old_cols) - lo
		return c.y * cols + c.x
	# the dominoes: different ones of the double-six set
	var set: Array[Vector2i] = []
	for a in 7:
		for b in range(a, 7):
			set.append(Vector2i(a, b))
	_shuffle(set)
	tiles.clear()
	answer.clear()
	spots = PackedInt32Array()
	spots.resize(cols * rows)
	spots.fill(-1)
	bed_of = PackedInt32Array()
	bed_of.resize(cols * rows)
	bed_of.fill(-1)
	for k in pairs.size():
		var a: int = moved.call(pairs[k].x)
		var b: int = moved.call(pairs[k].y)
		var t: Vector2i = set[k]
		if _rng.randf() < 0.5:
			t = Vector2i(t.y, t.x)
		var dir := DIRS.find(_cell(b) - _cell(a))
		tiles.append(t)
		answer.append(Vector2i(a, dir))
		spots[a] = t.x
		spots[b] = t.y
		bed_of[a] = 0
		bed_of[b] = 0
	for k in int(SPARE[_band]):
		tiles.append(set[pairs.size() + k])
		answer.append(Vector2i(-1, 0))
	# the tray's order is not the patio's
	var order: Array[int] = []
	for k in tiles.size():
		order.append(k)
	_shuffle_int(order)
	var t2: Array[Vector2i] = []
	var a2: Array[Vector2i] = []
	for k in order:
		t2.append(tiles[k])
		a2.append(answer[k])
	tiles = t2
	answer = a2
	return true

## New numbers on the same tiling (the tiles keep their squares and their
## bays), and every bed's rule read again off them.
func _revalue() -> void:
	var set: Array[Vector2i] = []
	for a in 7:
		for b in range(a, 7):
			set.append(Vector2i(a, b))
	_shuffle(set)
	for k in tiles.size():
		var t: Vector2i = set[k]
		if _rng.randf() < 0.5:
			t = Vector2i(t.y, t.x)
		tiles[k] = t
		var a: Vector2i = answer[k]
		if a.x >= 0:
			spots[a.x] = t.x
			spots[_idx(_cell(a.x) + (DIRS[a.y] as Vector2i))] = t.y
	for b in beds.size():
		_rule_for(b, false)

## The patio's squares parted into beds, each grown from a square at random.
func _part() -> void:
	beds.clear()
	var free: Array[int] = []
	for i in cols * rows:
		if bed_of[i] >= 0:
			bed_of[i] = -2
			free.append(i)
	_shuffle_int(free)
	for seed_cell in free:
		if bed_of[seed_cell] != -2:
			continue
		var want := _pick_size()
		var cells: Array[int] = [seed_cell]
		bed_of[seed_cell] = beds.size()
		while cells.size() < want:
			var grow: Array[int] = []
			for c in cells:
				for d: Vector2i in DIRS:
					var o := _cell(c) + d
					if _inside(o) and bed_of[_idx(o)] == -2:
						grow.append(_idx(o))
			if grow.is_empty():
				break
			var pick: int = grow[_rng.randi_range(0, grow.size() - 1)]
			# a bed likes to spread over its seed's number: all-the-same beds
			# are strong rules, and they read apart from the sums
			var same: Array[int] = []
			for g in grow:
				if spots[g] == spots[seed_cell]:
					same.append(g)
			if not same.is_empty() and _rng.randf() < SAME_PULL:
				pick = same[_rng.randi_range(0, same.size() - 1)]
			bed_of[pick] = beds.size()
			cells.append(pick)
		beds.append({"cells": cells, "rule": Rule.NONE, "n": 0})
		_rule_for(beds.size() - 1, false)

func _pick_size() -> int:
	var w: Array = SIZE_W[_band]
	var r := _rng.randf()
	for k in w.size():
		r -= float(w[k])
		if r <= 0.0:
			return int(SIZES[k])
	return 2

## A rule for bed `b` read off the answer; `exact` takes the strictest the
## bed allows (a sum, or all the same).
func _rule_for(b: int, exact: bool) -> void:
	var bed: Dictionary = beds[b]
	var vs: Array[int] = []
	var total := 0
	for c: int in bed.cells:
		vs.append(spots[c])
		total += spots[c]
	var same := true
	var apart := true
	var seen := {}
	for v in vs:
		same = same and v == vs[0]
		apart = apart and not seen.has(v)
		seen[v] = true
	var size := vs.size()
	if same and size >= 2 and (exact or _rng.randf() < 0.8):
		bed.rule = Rule.SAME
		bed.n = 0
		return
	if not exact:
		if _rng.randf() < float(NONE_P[_band]):
			bed.rule = Rule.NONE
			bed.n = 0
			return
		if apart and size >= 3 and APART[_band] and _rng.randf() < 0.35:
			bed.rule = Rule.APART
			bed.n = 0
			return
		if BOUNDS[_band] and _rng.randf() < (0.45 if size == 1 else 0.2):
			if _rng.randf() < 0.5 and total + 1 <= 6 * size:
				bed.rule = Rule.LESS
				bed.n = total + _rng.randi_range(1, 2)
				return
			if total >= 1:
				bed.rule = Rule.MORE
				bed.n = maxi(0, total - _rng.randi_range(1, 2))
				return
	bed.rule = Rule.SUM
	bed.n = total

# --- the count ---

## Tightens the rules until the answer's spots are the only ones that keep
## them. False when a count ran past CAP or tightening could not settle it.
func _tighten(split: bool) -> bool:
	for k in TIGHTEN:
		var n := count(2)
		if _aborted:
			return false
		if n <= 1:
			return true
		if not _stricter(split):
			return false
	return false

## A bed that differs between the two answers found is made stricter:
## a looser rule becomes exact, an exact one is split.
func _stricter(split: bool) -> bool:
	var diff: Array[int] = []
	for i in cols * rows:
		if bed_of[i] >= 0 and _sol1[i] != _sol2[i] and _bed_differs(bed_of[i]):
			diff.append(i)
	_shuffle_int(diff)
	for i in diff:
		var b := bed_of[i]
		var bed: Dictionary = beds[b]
		if bed.rule == Rule.NONE or bed.rule == Rule.LESS or bed.rule == Rule.MORE or bed.rule == Rule.APART:
			_rule_for(b, true)
			return true
	if not split:
		return false
	for i in diff:
		var b := bed_of[i]
		var bed: Dictionary = beds[b]
		if (bed.cells as Array).size() >= 2:
			_split(b, i)
			return true
	return false

## True when bed `b` holds different spots in the two answers found.
func _bed_differs(b: int) -> bool:
	var a := PackedInt32Array()
	a.resize(7)
	for c: int in beds[b].cells:
		a[_sol1[c]] += 1
		a[_sol2[c]] -= 1
	for v in a:
		if v != 0:
			return true
	return false

## Bed `b` loses square `i` to a bed of its own; what is left is parted into
## its connected pieces, each with an exact rule.
func _split(b: int, i: int) -> void:
	var rest: Array[int] = []
	for c: int in beds[b].cells:
		if c != i:
			rest.append(c)
	beds[b].cells = [i] as Array[int]
	_rule_for(b, true)
	var left := {}
	for c in rest:
		left[c] = true
	while not left.is_empty():
		var from: int = left.keys()[0]
		var piece: Array[int] = [from]
		left.erase(from)
		var k := 0
		while k < piece.size():
			for d: Vector2i in DIRS:
				var o := _cell(piece[k]) + d
				if _inside(o) and left.has(_idx(o)):
					piece.append(_idx(o))
					left.erase(_idx(o))
			k += 1
		for c in piece:
			bed_of[c] = beds.size()
		beds.append({"cells": piece, "rule": Rule.NONE, "n": 0})
		_rule_for(beds.size() - 1, true)

## How many different spot patterns keep every rule, counted up to `limit`.
func count(limit := 2) -> int:
	var cells := cols * rows
	_cover = PackedInt32Array()
	_cover.resize(cells)
	_val = PackedInt32Array()
	_val.resize(cells)
	_order = PackedInt32Array()
	for i in cells:
		_cover[i] = 0 if bed_of[i] >= 0 else 1
		_val[i] = -1
		if bed_of[i] >= 0:
			_order.append(i)
	_used = PackedByteArray()
	_used.resize(tiles.size())
	var nb := beds.size()
	_cnt.resize(nb)
	_sum.resize(nb)
	_mask.resize(nb)
	_first.resize(nb)
	_rule.resize(nb)
	_n.resize(nb)
	_size.resize(nb)
	for b in nb:
		_cnt[b] = 0
		_sum[b] = 0
		_mask[b] = 0
		_first[b] = -1
		_rule[b] = int(beds[b].rule)
		_n[b] = int(beds[b].n)
		_size[b] = (beds[b].cells as Array).size()
	_found = 0
	_aborted = false
	steps = 0
	_limit = limit
	_go(0)
	return _found

var _limit := 2

func _go(from: int) -> void:
	steps += 1
	if steps > CAP:
		_aborted = true
		return
	var k := from
	while k < _order.size() and _cover[_order[k]] == 1:
		k += 1
	if k >= _order.size():
		# two layings are one answer when every bed holds the same spots:
		# a bed sees nothing else
		var sig := _signature()
		if _found == 0:
			_sol1 = _val.duplicate()
			_sig1 = sig
			_found = 1
		elif sig != _sig1:
			_sol2 = _val.duplicate()
			_found += 1
		return
	# the first open square in reading order: its left and upper
	# neighbours are covered already, so a tile goes right or down
	var i := _order[k]
	var c := _cell(i)
	for dk in 2:
		var o: Vector2i = c + DIRS[dk]
		if not _inside(o):
			continue
		var j := _idx(o)
		if _cover[j] == 1:
			continue
		for t in tiles.size():
			if _used[t] == 1:
				continue
			var tv: Vector2i = tiles[t]
			for flip in 2:
				# a tile turned end for end inside one bed leaves the bed as
				# it was
				if flip == 1 and (tv.x == tv.y or bed_of[i] == bed_of[j]):
					break
				var a := tv.x if flip == 0 else tv.y
				var z := tv.y if flip == 0 else tv.x
				if not _add(bed_of[i], a):
					continue
				if _add(bed_of[j], z):
					_used[t] = 1
					_cover[i] = 1
					_cover[j] = 1
					_val[i] = a
					_val[j] = z
					_go(k + 1)
					_cover[i] = 0
					_cover[j] = 0
					_val[i] = -1
					_val[j] = -1
					_used[t] = 0
					_take(bed_of[j], z)
				_take(bed_of[i], a)
				if _found >= _limit or _aborted:
					return

## Each bed's spots, counted by number: seven counts a bed.
func _signature() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(beds.size() * 7)
	for i in _order:
		out[bed_of[i] * 7 + _val[i]] += 1
	return out

## Puts spot `v` in bed `b`; false (and nothing changed) when no way of
## filling the rest could keep its rule.
func _add(b: int, v: int) -> bool:
	var r := _rule[b]
	if r == Rule.SAME and _cnt[b] > 0 and v != _first[b]:
		return false
	if r == Rule.APART and (_mask[b] >> v) & 1 == 1:
		return false
	var cnt := _cnt[b] + 1
	var sum := _sum[b] + v
	var rem := _size[b] - cnt
	match r:
		Rule.SUM:
			if sum > _n[b] or sum + 6 * rem < _n[b]:
				return false
		Rule.LESS:
			if sum >= _n[b]:
				return false
		Rule.MORE:
			if sum + 6 * rem <= _n[b]:
				return false
	_cnt[b] = cnt
	_sum[b] = sum
	if r == Rule.APART:
		_mask[b] |= 1 << v
	if cnt == 1:
		_first[b] = v
	return true

func _take(b: int, v: int) -> void:
	_cnt[b] -= 1
	_sum[b] -= v
	if _rule[b] == Rule.APART:
		_mask[b] &= ~(1 << v)

# --- helpers ---

func _idx(c: Vector2i) -> int:
	return c.y * cols + c.x

func _cell(i: int) -> Vector2i:
	return Vector2i(i % cols, i / cols)

func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x

func _shuffle_int(a: Array[int]) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var x := a[i]
		a[i] = a[j]
		a[j] = x
