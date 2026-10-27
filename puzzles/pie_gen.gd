extends RefCounted

## Who Ate the Pie?'s logic (spec docs/superpowers/specs/2026-10-22-pie-design.md):
## the clues, the solver and the day's deal. Bakers stand in a grid, some of
## them ate the pie; each baker, once marked, says one true thing. The board
## (puzzles/pie2d.gd) accepts a mark only when the clues already showing
## prove it, through `forced` here, so the deal and the board judge with one
## solver.
##
## Every clue is one of three sums over the grid, a bit a baker: so many of
## a set ate pie (SUM), more of one set than another (MORE), an odd or even
## number of a set (ODD). The solver looks for a way the bakers could have
## eaten that every clue allows; a baker is proven when no such way gives
## them the other verdict. Two ways that differ prove nobody they differ on,
## so a whole grid costs a handful of searches.
##
## The deal draws who ate and then hands out the clues as a player would
## meet them: the opening baker's clue, then the clues of everyone it proves,
## and so on, choosing each clue so that the chain never stalls. Since a
## mark proven stays proven as more clues show, any order of play gets
## through a day the deal got through.

enum Op { SUM, MORE, ODD }

## Clue kinds: what the sentence says (pie2d.gd writes it from locale rows).
## NB: so many of `a`'s neighbours (all eight around). ROW / COL: so many in
## row or column `a`. DIR: so many of the bakers in direction `d` from `a`.
## EDGE: so many on the grid's edge. CORNER: so many of the four corners.
## PAIR: so many of `a` and `b` (0 neither, 1 exactly one, 2 both). ONE:
## `a` ate (n 1) or didn't (n 0). MORE_ROW / MORE_COL: more in row or
## column `a` than in `b`. ODD_ROW / ODD_COL: an odd (n 1) or even (n 0)
## number in row or column `a`.
enum Kind { NB, ROW, COL, DIR, EDGE, CORNER, PAIR, ONE, MORE_ROW, MORE_COL, ODD_ROW, ODD_COL }
enum Dir { ABOVE, BELOW, LEFT, RIGHT }

## The bands: the grid, how many ate, which clues are spoken, whether the
## dish shows how many slices are gone (Insane's own rule, Empty Dish, is
## that it does not), and how many bakers a clue should prove on its own
## (`want`: fewer is harder). Weights are per kind, in Kind's order.
const BANDS := [
	{"cols": 3, "rows": 3, "eaters": [3, 3], "dish": true, "want": 3,
		"w": [5, 3, 3, 0, 0, 0, 3, 1, 0, 0, 0, 0]},
	{"cols": 3, "rows": 4, "eaters": [4, 5], "dish": true, "want": 2,
		"w": [5, 2, 2, 3, 1, 1, 3, 0, 0, 0, 0, 0]},
	{"cols": 4, "rows": 4, "eaters": [5, 7], "dish": true, "want": 1,
		"w": [5, 2, 2, 3, 1, 1, 2, 0, 1, 1, 1, 1]},
	{"cols": 4, "rows": 5, "eaters": [6, 9], "dish": false, "want": 1,
		"w": [5, 2, 2, 3, 1, 1, 2, 0, 1, 1, 1, 1]},
]

## The bakers are Peeplets (peeplet/peeplet_personas.gd): a day deals n of
## the fifty and lays them in their names' order, so a name in a clue is easy
## to find on the grid.
const Personas = preload("res://peeplet/peeplet_personas.gd")

static var _pc := PackedInt32Array()

static func popcount(m: int) -> int:
	if _pc.is_empty():
		_pc.resize(1024)
		for i in 1024:
			var n := 0
			var v := i
			while v:
				n += v & 1
				v >>= 1
			_pc[i] = n
	return _pc[m & 1023] + _pc[(m >> 10) & 1023] + _pc[(m >> 20) & 1023]

# --- the grid ---

static func row_mask(cols: int, r: int) -> int:
	return ((1 << cols) - 1) << (r * cols)

static func col_mask(cols: int, rows: int, c: int) -> int:
	var m := 0
	for r in rows:
		m |= 1 << (r * cols + c)
	return m

## The eight around baker `i`.
static func nb_mask(cols: int, rows: int, i: int) -> int:
	var x := i % cols
	var y := i / cols
	var m := 0
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows:
				m |= 1 << (ny * cols + nx)
	return m

## Every baker in a straight line from `i` toward `d`, not `i`.
static func dir_mask(cols: int, rows: int, i: int, d: int) -> int:
	var x := i % cols
	var y := i / cols
	var m := 0
	match d:
		Dir.ABOVE:
			for ny in y:
				m |= 1 << (ny * cols + x)
		Dir.BELOW:
			for ny in range(y + 1, rows):
				m |= 1 << (ny * cols + x)
		Dir.LEFT:
			for nx in x:
				m |= 1 << (y * cols + nx)
		_:
			for nx in range(x + 1, cols):
				m |= 1 << (y * cols + nx)
	return m

static func edge_mask(cols: int, rows: int) -> int:
	var m := 0
	for i in cols * rows:
		var x := i % cols
		var y := i / cols
		if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
			m |= 1 << i
	return m

static func corner_mask(cols: int, rows: int) -> int:
	return 1 | (1 << (cols - 1)) | (1 << ((rows - 1) * cols)) | (1 << (rows * cols - 1))

## The sum a clue is, [op, mask, n or second mask], on a cols x rows grid.
static func constraint(clue: Dictionary, cols: int, rows: int) -> Array:
	var a := int(clue.get("a", 0))
	var n := int(clue.get("n", 0))
	match int(clue.k):
		Kind.NB: return [Op.SUM, nb_mask(cols, rows, a), n]
		Kind.ROW: return [Op.SUM, row_mask(cols, a), n]
		Kind.COL: return [Op.SUM, col_mask(cols, rows, a), n]
		Kind.DIR: return [Op.SUM, dir_mask(cols, rows, a, int(clue.d)), n]
		Kind.EDGE: return [Op.SUM, edge_mask(cols, rows), n]
		Kind.CORNER: return [Op.SUM, corner_mask(cols, rows), n]
		Kind.PAIR: return [Op.SUM, (1 << a) | (1 << int(clue.b)), n]
		Kind.ONE: return [Op.SUM, 1 << a, n]
		Kind.MORE_ROW: return [Op.MORE, row_mask(cols, a), row_mask(cols, int(clue.b))]
		Kind.MORE_COL: return [Op.MORE, col_mask(cols, rows, a), col_mask(cols, rows, int(clue.b))]
		Kind.ODD_ROW: return [Op.ODD, row_mask(cols, a), n]
		_: return [Op.ODD, col_mask(cols, rows, a), n]

## The bakers a clue speaks of, for the board's halo.
static func about(clue: Dictionary, cols: int, rows: int) -> int:
	var c := constraint(clue, cols, rows)
	return int(c[1]) | (int(c[2]) if int(c[0]) == Op.MORE else 0)

# --- the solver ---

## Whether a way where `set` are decided and `ate` of them ate can still
## meet every constraint.
static func _fits(cons: Array, set: int, ate: int) -> bool:
	for c: Array in cons:
		var m: int = c[1]
		var lo := popcount(ate & m)
		var free := popcount(m & ~set)
		match int(c[0]):
			Op.SUM:
				var n: int = c[2]
				if n < lo or n > lo + free:
					return false
			Op.MORE:
				var b: int = c[2]
				if lo + free <= popcount(ate & b):
					return false
			_:
				if free == 0 and (lo & 1) != int(c[2]):
					return false
	return true

## A way every constraint allows that agrees with `set`/`ate`, as the mask
## of who ate; -1 when there is none. `order` is the bakers to decide.
static func _find(cons: Array, order: PackedInt32Array, k: int, set: int, ate: int) -> int:
	if not _fits(cons, set, ate):
		return -1
	if k >= order.size():
		return ate
	var bit := 1 << order[k]
	# a baker already decided (or fixed by the caller) keeps their verdict
	if set & bit:
		return _find(cons, order, k + 1, set, ate)
	# try the cheaper verdict first: most bakers did not eat
	var w := _find(cons, order, k + 1, set | bit, ate)
	if w >= 0:
		return w
	return _find(cons, order, k + 1, set | bit, ate | bit)

## The order the search decides bakers in: the most spoken-of first.
static func _order(cons: Array, n: int, set: int) -> PackedInt32Array:
	var score := []
	for i in n:
		if set & (1 << i):
			continue
		var s := 0
		for c: Array in cons:
			if int(c[1]) & (1 << i):
				s += 1
			if int(c[0]) == Op.MORE and int(c[2]) & (1 << i):
				s += 1
		score.append([-s, i])
	score.sort()
	var out := PackedInt32Array()
	for p in score:
		out.append(int(p[1]))
	return out

## Who the constraints prove, given `set` decided with `ate` of them eating:
## {"set": mask proven (not counting `set`), "ate": who of them ate}, or
## {} when no way fits at all.
static func forced(cons: Array, n: int, set: int, ate: int) -> Dictionary:
	var order := _order(cons, n, set)
	var w := _find(cons, order, 0, set, ate)
	if w < 0:
		return {}
	var open := 0
	var proven := 0
	var proven_ate := 0
	for i in order:
		var bit := 1 << i
		if open & bit:
			continue
		var other := _find(cons, order, 0, set | bit, (ate | (w & bit)) ^ bit)
		if other >= 0:
			open |= (w ^ other) & ~set
		else:
			proven |= bit
			proven_ate |= w & bit
	return {"set": proven, "ate": proven_ate}

## Whether the constraints prove baker `i` (no way gives them the other
## verdict), `set`/`ate` decided as in `forced`; `eat` is their verdict.
static func proves(cons: Array, n: int, set: int, ate: int, i: int, eat: bool) -> bool:
	var bit := 1 << i
	var order := _order(cons, n, set | bit)
	return _find(cons, order, 0, set | bit, (ate | bit) if not eat else ate) < 0

## The bulb's first press: a few of the `heard` bakers whose clues alone
## (with the dish and the marks) still prove baker `i`, as a mask. Each
## speaker is dropped in turn while `i` stays proven, so what is left is a
## handful a player can read together.
static func reasons(clues: Array, heard: int, cols: int, rows: int, dish: int, ate: int, i: int) -> int:
	var n := cols * rows
	var keep := 0
	for j in n:
		if heard & (1 << j) and not (clues[j] as Dictionary).is_empty():
			keep |= 1 << j
	var eat := ate & (1 << i) != 0
	for j in n:
		if not keep & (1 << j):
			continue
		var cons := constraints(clues, keep & ~(1 << j), cols, rows, dish)
		if proves(cons, n, heard, ate & heard, i, eat):
			keep &= ~(1 << j)
	return keep

## The constraints of the clues spoken by `heard` bakers, and the dish's.
static func constraints(clues: Array, heard: int, cols: int, rows: int, dish: int) -> Array:
	var cons := []
	if dish >= 0:
		cons.append([Op.SUM, (1 << (cols * rows)) - 1, dish])
	for i in clues.size():
		if heard & (1 << i) and not (clues[i] as Dictionary).is_empty():
			cons.append(constraint(clues[i], cols, rows))
	return cons

# --- the deal ---

## Every true clue baker `i` could say about `ate`, by kind: {kind: [clue]}
## for every kind with a weight in `w` (weight 0 is never said). A baker's
## own neighbours and lines come first in NB and DIR, `own` long.
static func _sayable(i: int, ate: int, cols: int, rows: int, w: Array) -> Dictionary:
	var n := cols * rows
	var out := {}
	var add := func(clue: Dictionary) -> void:
		var kd := int(clue.k)
		if int(w[kd]) > 0:
			if not out.has(kd):
				out[kd] = []
			out[kd].append(clue)
	var cnt := func(m: int) -> int: return popcount(ate & m)
	for j in n:
		add.call({"k": Kind.NB, "a": j, "n": cnt.call(nb_mask(cols, rows, j))})
		for d in 4:
			var dm := dir_mask(cols, rows, j, d)
			if popcount(dm) >= 2:
				add.call({"k": Kind.DIR, "a": j, "d": d, "n": cnt.call(dm)})
	for r in rows:
		var rc: int = cnt.call(row_mask(cols, r))
		add.call({"k": Kind.ROW, "a": r, "n": rc})
		add.call({"k": Kind.ODD_ROW, "a": r, "n": rc & 1})
		for r2 in rows:
			if r2 != r and rc > cnt.call(row_mask(cols, r2)):
				add.call({"k": Kind.MORE_ROW, "a": r, "b": r2})
	for c in cols:
		var cc: int = cnt.call(col_mask(cols, rows, c))
		add.call({"k": Kind.COL, "a": c, "n": cc})
		add.call({"k": Kind.ODD_COL, "a": c, "n": cc & 1})
		for c2 in cols:
			if c2 != c and cc > cnt.call(col_mask(cols, rows, c2)):
				add.call({"k": Kind.MORE_COL, "a": c, "b": c2})
	add.call({"k": Kind.EDGE, "n": cnt.call(edge_mask(cols, rows))})
	add.call({"k": Kind.CORNER, "n": cnt.call(corner_mask(cols, rows))})
	for j in n:
		if j == i:
			continue
		add.call({"k": Kind.ONE, "a": j, "n": 1 if ate & (1 << j) else 0})
		for j2 in range(j + 1, n):
			if j2 != i:
				add.call({"k": Kind.PAIR, "a": j, "b": j2, "n": cnt.call((1 << j) | (1 << j2))})
	return out

## One clue from `said`: a kind by its weight, then any clue of it; a
## baker speaks of their own neighbours or line half the time NB or DIR
## comes up.
static func _pick(rng: RandomNumberGenerator, said: Dictionary, w: Array, i: int) -> Dictionary:
	var total := 0
	for kd in said:
		total += int(w[kd])
	var r := rng.randi_range(0, maxi(0, total - 1))
	var kind: int = said.keys()[0]
	for kd in said:
		r -= int(w[kd])
		if r < 0:
			kind = kd
			break
	var pool: Array = said[kind]
	if (kind == Kind.NB or kind == Kind.DIR) and rng.randf() < 0.5:
		var own := pool.filter(func(c: Dictionary) -> bool: return int(c.a) == i)
		if not own.is_empty():
			pool = own
	return pool[rng.randi_range(0, pool.size() - 1)]

## The day for `band`: {cols, rows, ate (mask), names, faces, clues, start,
## dish (slices gone, -1 on Insane)}. Returns {} only if every try failed.
static func deal(rng: RandomNumberGenerator, band: int) -> Dictionary:
	var b: Dictionary = BANDS[clampi(band, 0, 3)]
	for _try in 40:
		var day := _try_deal(rng, b)
		if not day.is_empty():
			return day
	return {}

static func _try_deal(rng: RandomNumberGenerator, b: Dictionary) -> Dictionary:
	var cols: int = b.cols
	var rows: int = b.rows
	var n := cols * rows
	var k := rng.randi_range(int(b.eaters[0]), int(b.eaters[1]))
	var cells := range(n)
	_shuffle(rng, cells)
	var ate := 0
	for j in k:
		ate |= 1 << int(cells[j])
	var dish: int = k if b.dish else -1
	# the opening baker did not eat, and stands away from the corners
	var opens := []
	for i in n:
		if not ate & (1 << i):
			opens.append(i)
	var start: int = opens[rng.randi_range(0, opens.size() - 1)]
	var clues := []
	clues.resize(n)
	for i in n:
		clues[i] = {}
	var heard := 0
	var fresh: Array = [start]
	var want: int = b.want
	var guard := 0
	while popcount(heard) < n:
		guard += 1
		if guard > n * 3:
			return {}
		# the newly proven speak; the last of them is chosen to move the chain
		for idx in fresh.size():
			var i: int = fresh[idx]
			heard |= 1 << i
			var said := _sayable(i, ate, cols, rows, b.w)
			clues[i] = _choose(rng, said, b.w, clues, heard, i, ate, cols, rows, dish, want, idx == fresh.size() - 1)
			if clues[i].is_empty():
				return {}
		var cons := constraints(clues, heard, cols, rows, dish)
		var f := forced(cons, n, heard, ate & heard)
		if f.is_empty():
			return {}
		if int(f.set) != 0 and int(f.ate) != ate & int(f.set):
			return {}
		fresh.clear()
		for i in n:
			if int(f.set) & (1 << i):
				fresh.append(i)
		if fresh.is_empty():
			if popcount(heard) >= n:
				break
			return {}
		_shuffle(rng, fresh)
	var cast := range(Personas.count())
	_shuffle(rng, cast)
	cast = cast.slice(0, n)
	cast.sort_custom(func(a: int, b: int) -> bool:
		return String(Personas.get_persona(a).name) < String(Personas.get_persona(b).name))
	var names := []
	for who: int in cast:
		names.append(Personas.get_persona(who).name)
	return {"cols": cols, "rows": rows, "ate": ate, "names": names, "faces": cast,
		"clues": clues, "start": start, "dish": dish}

## A clue for baker `i` that proves someone new with the clues heard so
## far, `want` or fewer beyond what was already proven, so a round leaves
## several bakers open at once (one at a time made every step a hunt for
## the only one, 2026-10-26). When none of ten tries does, the one proving
## fewest past one; `move` (the last speaker of a round) never settles for
## a clue that proves nobody, so the chain never stalls.
static func _choose(rng: RandomNumberGenerator, said: Dictionary, w: Array, clues: Array, heard: int, i: int,
		ate: int, cols: int, rows: int, dish: int, want: int, move: bool) -> Dictionary:
	var n := cols * rows
	if popcount(heard) >= n:
		# the last to speak: nobody is left to prove
		var last := _pick(rng, said, w, i)
		for _t in 8:
			if not clues.has(last):
				break
			last = _pick(rng, said, w, i)
		return last
	var base := popcount(int(forced(constraints(clues, heard, cols, rows, dish), n, heard, ate & heard).get("set", 0)))
	var best := {}
	var best_score := 999
	for _t in 10:
		if said.is_empty():
			break
		var clue := _pick(rng, said, w, i)
		if clues.has(clue):
			# never the same sentence twice in a day
			continue
		clues[i] = clue
		var cons := constraints(clues, heard, cols, rows, dish)
		var f := forced(cons, n, heard, ate & heard)
		clues[i] = {}
		if f.is_empty():
			continue
		var got := popcount(int(f.set))
		var extra := got - base
		if extra >= 1 and extra <= want:
			return clue
		if move and got == 0:
			continue
		# past the want is better than nothing new; nothing new is last
		var score := extra - want if extra > want else 100 - got
		if score < best_score:
			best = clue
			best_score = score
	return best

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
