extends RefCounted

## Sunbeam's generator: grow the answer, then prove it.
##
## A greenhouse floor of `cols * rows` cells. The lamp is an edge cell that
## throws the beam straight in; the bud is a cell the beam must end in;
## dewdrops are cells it must cross first; pots stop it. Every bender rides a
## straight rail of anchor cells (its pegs). A mirror is one cell ("/" or "\",
## both faces reflect); a cup is two side-by-side cells whose mouth faces `f`:
## light going into the mouth (moving opposite `f`) comes out of the other
## cell moving `f`, and light that meets its back stops.
##
## The answer is grown first -- the beam walked out of the lamp, a bender
## dropped at every turn, the bud at the end -- so a solution exists before
## anything else does. Then the drops go on the beam's free cells, one from
## each stretch, every bender gets a rail through its answer cell, pots go
## where the answer's beam never passes, and the opening puts every piece
## somewhere other than home. Then the board is **proved**: `count()` follows
## the beam out of the lamp and branches only where it reaches a peg -- a
## piece stands here, or none does -- so every arrangement is counted
## without ever enumerating them. Exactly one, or the board is thrown away.
##
## The proof is exhaustive, never capped: the search is bounded by the rails
## (a handful of pegs a piece) and not by a node count, so there is nothing
## to cut short, and a day is the same floor on every phone. Spec:
## docs/superpowers/specs/2026-09-26-sunbeam-flat-design.md, section 5.
## Ported from the concept page (docs/brainstorm/concepts.html#sunbeam).

## Right, down, left, up -- and what "/" and "\" turn each of them into.
const DX: Array[int] = [1, 0, -1, 0]
const DY: Array[int] = [0, 1, 0, -1]
const SLASH: Array[int] = [3, 2, 1, 0]
const BACK: Array[int] = [1, 0, 3, 2]

## cols, rows, pieces, cups, rail pegs, drops and pots, each a [lo, hi]
## range, whether two rails may share a cell, and how many snails sleep on
## the floor (Hard's: the light must never be let go on one). Insane's row
## is the floor Shy Dew is mined from (generate_shy): Hard's floor with a
## seventh piece and crossing rails, and no snails -- the drops themselves
## are the sleepers there.
const BANDS := [
	{"cols": 5, "rows": 6, "pieces": [3, 3], "cups": [0, 1], "rail": [3, 4], "drops": [2, 3], "pots": [0, 1], "cross": false, "snails": 0},
	{"cols": 6, "rows": 7, "pieces": [4, 5], "cups": [1, 1], "rail": [3, 5], "drops": [3, 4], "pots": [1, 2], "cross": false, "snails": 0},
	{"cols": 7, "rows": 8, "pieces": [6, 6], "cups": [1, 2], "rail": [4, 5], "drops": [4, 5], "pots": [1, 3], "cross": false, "snails": 3},
	{"cols": 7, "rows": 8, "pieces": [7, 7], "cups": [1, 2], "rail": [4, 6], "drops": [4, 6], "pots": [1, 3], "cross": true, "snails": 0},
]
## Whole grows before giving up and handing back the last one, unproved.
## Never reached on the 160 seeds measured (Hard's worst took 982).
const ATTEMPTS := 20000
## Tries at one run of the beam, at one rail, and at an opening.
const RUN_TRIES := 24
const RAIL_TRIES := 48
const OPENING_TRIES := 40

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## {cols, rows, lamp, dir, bud, pieces: Array of {kind "m"|"u", t "/"|"\\"
##  (a mirror), f and s (a cup's mouth and the side its second cell is on),
##  rail: PackedInt32Array (anchor cells), home: int (the answer's peg)},
##  drops: PackedInt32Array, pots: PackedInt32Array, start: PackedInt32Array
##  (each piece's opening peg), unique: bool, attempts: int}
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var bd := band(difficulty)
	var last := {}
	var attempts := 0
	while attempts < ATTEMPTS:
		attempts += 1
		var g := _grow(rng, bd)
		if g.is_empty():
			continue
		last = g
		if count(g, 2) == 1:
			if int(bd.snails) > 0:
				g["snails"] = lay_snails(rng, g, int(bd.snails))
				if g.snails.size() < int(bd.snails):
					continue
			g["unique"] = true
			g["attempts"] = attempts
			return g
	last["unique"] = false
	last["attempts"] = attempts
	return last

# --- the rules every search shares ---

## The cells piece `p` covers standing on peg `q`.
static func cells_of(g: Dictionary, p: int, q: int) -> PackedInt32Array:
	var pc: Dictionary = g.pieces[p]
	var a: int = pc.rail[q]
	if pc.kind == "m":
		return PackedInt32Array([a])
	return PackedInt32Array([a, a + DX[pc.s] + DY[pc.s] * int(g.cols)])

## Where light entering cell `c` moving `d` goes when piece `p` stands on peg
## `q` over it: [next cell, next direction, the other cell it lit or -1], or
## an empty array when it is stopped (the back of a cup).
static func bend(g: Dictionary, p: int, q: int, c: int, d: int) -> Array:
	var pc: Dictionary = g.pieces[p]
	if pc.kind == "m":
		return [c, SLASH[d] if pc.t == "/" else BACK[d], -1]
	if d != (int(pc.f) + 2) % 4:
		return []
	var cs := cells_of(g, p, q)
	var o: int = cs[1] if cs[0] == c else cs[0]
	return [o, int(pc.f), o]

## The whole beam for one arrangement (`pos[p]` is each piece's peg): the
## steps in order, each {c, d, k, p, o, nd} -- `k` "" for a free cell, "m" a
## mirror, "u" a cup, "bud", "pot", "lamp" or "back" (a cup's back) -- how it
## ended ("bud", "out", "pot", "lamp", "cup", "loop"), the cells it lit and
## how many drops, and whether that is the solve.
static func trace(g: Dictionary, pos: PackedInt32Array) -> Dictionary:
	var w: int = g.cols
	var h: int = g.rows
	var n := w * h
	var occ := PackedInt32Array()
	occ.resize(n)
	occ.fill(-1)
	for p in pos.size():
		for c in cells_of(g, p, pos[p]):
			occ[c] = p
	var seen := PackedByteArray()
	seen.resize(n * 4)
	var lit := {}
	var steps: Array = []
	var x: int = int(g.lamp) % w
	var y: int = int(g.lamp) / w
	var d: int = g.dir
	var end := "loop"
	var pots := {}
	for c in g.pots:
		pots[c] = true
	for k in n * 4 + 8:
		x += DX[d]
		y += DY[d]
		if x < 0 or y < 0 or x >= w or y >= h:
			end = "out"
			break
		var c := y * w + x
		if seen[c * 4 + d]:
			end = "loop"
			break
		seen[c * 4 + d] = 1
		if c == int(g.bud):
			steps.append({"c": c, "d": d, "k": "bud"})
			end = "bud"
			break
		if pots.has(c):
			steps.append({"c": c, "d": d, "k": "pot"})
			end = "pot"
			break
		if c == int(g.lamp):
			steps.append({"c": c, "d": d, "k": "lamp"})
			end = "lamp"
			break
		var p := occ[c]
		if p < 0:
			lit[c] = true
			steps.append({"c": c, "d": d, "k": ""})
			continue
		var r := bend(g, p, pos[p], c, d)
		if r.is_empty():
			steps.append({"c": c, "d": d, "k": "back", "p": p})
			end = "cup"
			break
		lit[c] = true
		if g.pieces[p].kind == "m":
			steps.append({"c": c, "d": d, "k": "m", "p": p, "nd": r[1]})
		else:
			steps.append({"c": c, "d": d, "k": "u", "p": p, "o": r[0], "nd": r[1]})
			lit[r[0]] = true
			x = int(r[0]) % w
			y = int(r[0]) / w
		d = r[1]
	var lit_drops := 0
	for c in g.drops:
		if lit.has(c):
			lit_drops += 1
	return {"steps": steps, "end": end, "lit": lit, "lit_drops": lit_drops,
		"won": end == "bud" and lit_drops == g.drops.size()}

# --- the proof ---

## How many arrangements light every drop and end in the bud, up to `cap`.
## Follows the beam and branches only on a peg it reaches; a piece the beam
## never meets is counted over every peg left to it (none the beam crossed,
## none overlapping another piece).
static func count(g: Dictionary, cap: int) -> int:
	var s := _Search.new(g, cap)
	s.walk(int(g.lamp) % int(g.cols), int(g.lamp) / int(g.cols), int(g.dir))
	return s.found

class _Search:
	var g: Dictionary
	var cap := 2
	var found := 0
	var w := 0
	var h := 0
	var occ := PackedInt32Array()
	var pos := PackedInt32Array()
	## Pegs ruled out by the beam passing over them with no piece there.
	var excl: Array = []
	## Every [piece, peg] that covers a cell, by cell.
	var cover: Array = []
	var cells: Array = []   ## cells[p][q], cached
	var is_drop := PackedByteArray()
	var is_pot := PackedByteArray()
	var lit_n := PackedInt32Array()
	var seen := PackedByteArray()
	var lit_drops := 0
	var drops := 0

	func _init(the_g: Dictionary, the_cap: int) -> void:
		g = the_g
		cap = the_cap
		w = g.cols
		h = g.rows
		var n := w * h
		occ.resize(n)
		occ.fill(-1)
		var np: int = g.pieces.size()
		pos.resize(np)
		pos.fill(-1)
		cover.resize(n)
		for c in n:
			cover[c] = []
		for p in np:
			var ex := PackedByteArray()
			ex.resize(g.pieces[p].rail.size())
			excl.append(ex)
			var per: Array = []
			var pc: Dictionary = g.pieces[p]
			for q in pc.rail.size():
				var a: int = pc.rail[q]
				var cs := PackedInt32Array([a]) if pc.kind == "m" \
					else PackedInt32Array([a, a + DX[pc.s] + DY[pc.s] * w])
				per.append(cs)
				for c in cs:
					cover[c].append(Vector2i(p, q))
			cells.append(per)
		is_drop.resize(n)
		for c in g.drops:
			is_drop[c] = 1
		drops = g.drops.size()
		is_pot.resize(n)
		for c in g.pots:
			is_pot[c] = 1
		lit_n.resize(n)
		seen.resize(n * 4)

	func fits(p: int, q: int) -> bool:
		for c in cells[p][q]:
			if occ[c] >= 0:
				return false
		return true

	func place(p: int, q: int) -> void:
		pos[p] = q
		for c in cells[p][q]:
			occ[c] = p

	func unplace(p: int) -> void:
		for c in cells[p][pos[p]]:
			occ[c] = -1
		pos[p] = -1

	func light_on(c: int) -> void:
		lit_n[c] += 1
		if lit_n[c] == 1 and is_drop[c]:
			lit_drops += 1

	func light_off(c: int) -> void:
		lit_n[c] -= 1
		if lit_n[c] == 0 and is_drop[c]:
			lit_drops -= 1

	## The pieces the beam never reached, over every peg left to them.
	func completions(i: int) -> int:
		var np := pos.size()
		while i < np and pos[i] >= 0:
			i += 1
		if i >= np:
			return 1
		var s := 0
		for q in cells[i].size():
			if found + s >= cap:
				break
			if excl[i][q] or not fits(i, q):
				continue
			place(i, q)
			s += completions(i + 1)
			unplace(i)
		return s

	## Light leaves (x, y) moving d.
	func walk(x: int, y: int, d: int) -> void:
		if found >= cap:
			return
		x += DX[d]
		y += DY[d]
		if x < 0 or y < 0 or x >= w or y >= h:
			return
		var c := y * w + x
		if seen[c * 4 + d]:
			return
		if c == int(g.bud):
			if lit_drops == drops:
				found += completions(0)
			return
		if is_pot[c] or c == int(g.lamp):
			return
		seen[c * 4 + d] = 1
		if occ[c] >= 0:
			follow(occ[c], c, d)
		else:
			var opts: Array = []
			for pq: Vector2i in cover[c]:
				if pos[pq.x] < 0 and not excl[pq.x][pq.y]:
					opts.append(pq)
			for pq: Vector2i in opts:
				if found >= cap:
					break
				if not fits(pq.x, pq.y):
					continue
				place(pq.x, pq.y)
				follow(pq.x, c, d)
				unplace(pq.x)
			if found < cap:
				for pq: Vector2i in opts:
					excl[pq.x][pq.y] = 1
				light_on(c)
				walk(x, y, d)
				light_off(c)
				for pq: Vector2i in opts:
					excl[pq.x][pq.y] = 0
		seen[c * 4 + d] = 0

	## The outer script's bend(), on the cached cells: an inner class cannot
	## call its outer script's static functions.
	func follow(p: int, c: int, d: int) -> void:
		var pc: Dictionary = g.pieces[p]
		var r: Array
		if pc.kind == "m":
			r = [c, SLASH[d] if pc.t == "/" else BACK[d], -1]
		elif d != (int(pc.f) + 2) % 4:
			return
		else:
			var cs: PackedInt32Array = cells[p][pos[p]]
			var o: int = cs[1] if cs[0] == c else cs[0]
			r = [o, int(pc.f), o]
		light_on(c)
		if r[2] >= 0:
			light_on(r[2])
		walk(int(r[0]) % w, int(r[0]) / w, r[1])
		if r[2] >= 0:
			light_off(r[2])
		light_off(c)

# --- the grow ---

static func _shuffle(rng: RandomNumberGenerator, a: Array) -> Array:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
	return a

## One whole board, or {} when a stage could not be laid.
static func _grow(rng: RandomNumberGenerator, bd: Dictionary) -> Dictionary:
	var w: int = bd.cols
	var h: int = bd.rows
	var n := w * h
	var k_n := rng.randi_range(bd.pieces[0], bd.pieces[1])
	var u_n := rng.randi_range(bd.cups[0], bd.cups[1])
	var kinds: Array = []
	for i in k_n:
		kinds.append("m")
	var order: Array = _shuffle(rng, range(k_n))
	for i in mini(u_n, k_n):
		kinds[order[i]] = "u"
	# The lamp: an edge cell, never a corner, throwing the beam inward.
	var side := rng.randi_range(0, 3)
	var lx := 0
	var ly := 0
	match side:
		0: ly = rng.randi_range(1, h - 2)
		1: lx = rng.randi_range(1, w - 2)
		2:
			lx = w - 1
			ly = rng.randi_range(1, h - 2)
		_:
			ly = h - 1
			lx = rng.randi_range(1, w - 2)
	var dir0 := side
	var lamp := ly * w + lx
	var reserved := PackedByteArray()
	reserved.resize(n)
	## The axes the answer's beam already runs along in each cell, 1 across
	## and 2 down: a later run may cross an earlier one but never lie along it.
	var axis := PackedByteArray()
	axis.resize(n)
	reserved[lamp] = 1
	var pieces: Array = []
	var x := lx
	var y := ly
	var dir := dir0
	var long := maxi(w, h) - 1
	for k in k_n:
		var ok := false
		for tries in RUN_TRIES:
			var r := rng.randi_range(1, long)
			if not _run_ok(x, y, dir, r, w, h, reserved, axis):
				continue
			var ax := x + DX[dir] * r
			var ay := y + DY[dir] * r
			var a := ay * w + ax
			if kinds[k] == "m":
				var nd := (dir + 1) % 4 if rng.randf() < 0.5 else (dir + 3) % 4
				if not _inb(ax + DX[nd], ay + DY[nd], w, h):
					continue
				_commit(x, y, dir, r, w, axis)
				reserved[a] = 1
				pieces.append({"kind": "m", "t": "/" if SLASH[dir] == nd else "\\", "sol": a})
				x = ax
				y = ay
				dir = nd
				ok = true
			else:
				var s := (dir + 1) % 4 if rng.randf() < 0.5 else (dir + 3) % 4
				var bx := ax + DX[s]
				var by := ay + DY[s]
				if not _inb(bx, by, w, h):
					continue
				var bc := by * w + bx
				if reserved[bc] or axis[bc]:
					continue
				var f := (dir + 2) % 4
				if not _inb(bx + DX[f], by + DY[f], w, h):
					continue
				_commit(x, y, dir, r, w, axis)
				reserved[a] = 1
				reserved[bc] = 1
				pieces.append({"kind": "u", "f": f, "s": s, "sol": a})
				x = bx
				y = by
				dir = f
				ok = true
			if ok:
				break
		if not ok:
			return {}
	var bud := -1
	for tries in RUN_TRIES:
		var r := rng.randi_range(2, long)
		if not _run_ok(x, y, dir, r, w, h, reserved, axis):
			continue
		_commit(x, y, dir, r, w, axis)
		bud = (y + DY[dir] * r) * w + x + DX[dir] * r
		break
	if bud < 0:
		return {}
	for pc: Dictionary in pieces:
		pc["rail"] = PackedInt32Array([pc.sol])
	var g := {"cols": w, "rows": h, "lamp": lamp, "dir": dir0, "bud": bud, "pieces": pieces,
		"drops": PackedInt32Array(), "pots": PackedInt32Array(), "snails": PackedInt32Array(), "shy": false}
	var home := PackedInt32Array()
	home.resize(pieces.size())
	var sol := trace(g, home)
	if sol.end != "bud":
		return {}
	# Dewdrops: one from each stretch of the answer beam's free cells.
	var free: Array = []
	var had := {}
	for st: Dictionary in sol.steps:
		if st.k == "" and not had.has(st.c):
			had[st.c] = true
			free.append(st.c)
	var d_n := rng.randi_range(bd.drops[0], bd.drops[1])
	if free.size() < d_n:
		return {}
	var drops := PackedInt32Array()
	for i in d_n:
		var lo := int(floor(float(i) * free.size() / d_n))
		var hi := int(floor(float(i + 1) * free.size() / d_n)) - 1
		drops.append(free[rng.randi_range(lo, hi)])
	g["drops"] = drops
	var is_drop := {}
	for c in drops:
		is_drop[c] = true
	# Rails: a straight run of pegs through each answer cell. One that will
	# not fit at its drawn length is tried shorter, never below three: two
	# pegs is a switch, not a slide.
	var rail_cell := PackedInt32Array()
	rail_cell.resize(n)
	rail_cell.fill(-1)
	var crossings := 0
	for p: int in _shuffle(rng, range(pieces.size())):
		var pc: Dictionary = pieces[p]
		var done := false
		for tries in RAIL_TRIES:
			var down := rng.randi_range(0, 1) == 1
			var ln := maxi(3, rng.randi_range(bd.rail[0], bd.rail[1]) - (tries >> 4))
			var off := rng.randi_range(0, ln - 1)
			var dd := 1 if down else 0
			var sx: int = int(pc.sol) % w
			var sy: int = int(pc.sol) / w
			var rail := PackedInt32Array()
			var covered: Array = []
			var ok := true
			var cr := 0
			for j in ln:
				var px := sx + DX[dd] * (j - off)
				var py := sy + DY[dd] * (j - off)
				if not _inb(px, py, w, h):
					ok = false
					break
				var a := py * w + px
				var cs := [a]
				if pc.kind == "u":
					if not _inb(px + DX[pc.s], py + DY[pc.s], w, h):
						ok = false
						break
					cs.append(a + DX[pc.s] + DY[pc.s] * w)
				for c: int in cs:
					if c == lamp or c == bud or is_drop.has(c):
						ok = false
						break
					if rail_cell[c] >= 0 and rail_cell[c] != p:
						if not bd.cross:
							ok = false
							break
						cr += 1
				if not ok:
					break
				rail.append(a)
				covered.append_array(cs)
			if not ok:
				continue
			pc["rail"] = rail
			pc["home"] = off
			for c: int in covered:
				if rail_cell[c] < 0:
					rail_cell[c] = p
			crossings += cr
			done = true
			break
		if not done:
			return {}
	if bd.cross and crossings == 0:
		return {}
	# Pots: off the answer's beam and off every rail.
	var cand: Array = []
	for c in n:
		if not sol.lit.has(c) and rail_cell[c] < 0 and c != lamp and c != bud:
			cand.append(c)
	var pots := PackedInt32Array()
	for c in _shuffle(rng, cand).slice(0, rng.randi_range(bd.pots[0], bd.pots[1])):
		pots.append(c)
	g["pots"] = pots
	# The opening: every piece somewhere other than home, no overlaps, and
	# not already solved.
	for tries in OPENING_TRIES:
		var occ := {}
		var start := PackedInt32Array()
		var ok := true
		for p in pieces.size():
			var opts: Array = []
			for q in pieces[p].rail.size():
				if q == int(pieces[p].home):
					continue
				var free_q := true
				for c in cells_of(g, p, q):
					if occ.has(c):
						free_q = false
				if free_q:
					opts.append(q)
			if opts.is_empty():
				ok = false
				break
			var q: int = opts[rng.randi_range(0, opts.size() - 1)]
			start.append(q)
			for c in cells_of(g, p, q):
				occ[c] = true
		if not ok or trace(g, start).won:
			continue
		g["start"] = start
		return g
	return {}

static func _inb(x: int, y: int, w: int, h: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

## A run of `r` cells from (x, y) along `dir`: every cell but the last may
## cross the answer beam so far (never along it); the last, where the next
## thing stands, must be clear of it.
static func _run_ok(x: int, y: int, dir: int, r: int, w: int, h: int, reserved: PackedByteArray, axis: PackedByteArray) -> bool:
	var ax := 2 if dir % 2 == 1 else 1
	for i in range(1, r + 1):
		var px := x + DX[dir] * i
		var py := y + DY[dir] * i
		if not _inb(px, py, w, h):
			return false
		var c := py * w + px
		if reserved[c]:
			return false
		if i < r and (axis[c] & ax):
			return false
		if i == r and axis[c]:
			return false
	return true

static func _commit(x: int, y: int, dir: int, r: int, w: int, axis: PackedByteArray) -> void:
	var ax := 2 if dir % 2 == 1 else 1
	for i in range(1, r):
		var c := (y + DY[dir] * i) * w + x + DX[dir] * i
		axis[c] |= ax

# --- sleepers: Hard's snails and Insane's shy dew ---

## A lean tracer for searches that walk thousands of arrangements: what one
## arrangement lights of a set of marked cells (the sleepers), and whether
## it is the solve. No dictionaries, no allocation a call.
class Fast:
	var w := 0
	var h := 0
	var np := 0
	var lamp := 0
	var dir0 := 0
	var bud := 0
	var drops := 0
	var cells: Array = []      ## cells[p][q]
	var kind := PackedByteArray()   ## 0 mirror "/", 1 mirror "\", 2 cup
	var face := PackedInt32Array()
	var is_drop := PackedByteArray()
	var is_pot := PackedByteArray()
	var mark := PackedByteArray()
	var occ_at := PackedInt32Array()
	var occ_p := PackedInt32Array()
	var lit_at := PackedInt32Array()
	var seen := PackedInt32Array()
	var stamp := 0
	var rails := PackedInt32Array()
	## When `tally` is set, probe() adds one to hits[c] for every cell it lights.
	var tally := false
	var hits := PackedInt32Array()

	func _init(g: Dictionary, marked: PackedInt32Array) -> void:
		w = g.cols
		h = g.rows
		var n := w * h
		np = g.pieces.size()
		lamp = g.lamp
		dir0 = g.dir
		bud = g.bud
		drops = g.drops.size()
		for p in np:
			var pc: Dictionary = g.pieces[p]
			var per: Array = []
			for q in pc.rail.size():
				var a: int = pc.rail[q]
				per.append(PackedInt32Array([a]) if pc.kind == "m" \
					else PackedInt32Array([a, a + DX[pc.s] + DY[pc.s] * w]))
			cells.append(per)
			rails.append(pc.rail.size())
			if pc.kind == "m":
				kind.append(0 if pc.t == "/" else 1)
				face.append(0)
			else:
				kind.append(2)
				face.append(int(pc.f))
		is_drop.resize(n)
		for c in g.drops:
			is_drop[c] = 1
		is_pot.resize(n)
		for c in g.pots:
			is_pot[c] = 1
		mark.resize(n)
		for c in marked:
			mark[c] = 1
		occ_at.resize(n)
		occ_p.resize(n)
		lit_at.resize(n)
		seen.resize(n * 4)
		hits.resize(n)

	## Whether piece `p` on peg `q` overlaps another piece of `pos`.
	func fits(pos: PackedInt32Array, p: int, q: int) -> bool:
		var mine: PackedInt32Array = cells[p][q]
		for o in np:
			if o == p:
				continue
			for c in cells[o][pos[o]]:
				if mine.has(c):
					return false
		return true

	## Vector2i(marked cells lit, 1 if solved).
	func probe(pos: PackedInt32Array) -> Vector2i:
		stamp += 1
		for p in np:
			for c in cells[p][pos[p]]:
				occ_at[c] = stamp
				occ_p[c] = p
		var marked := 0
		var lit_drops := 0
		var x := lamp % w
		var y := lamp / w
		var d := dir0
		for k in w * h * 4 + 8:
			x += DX[d]
			y += DY[d]
			if x < 0 or y < 0 or x >= w or y >= h:
				break
			var c := y * w + x
			if seen[c * 4 + d] == stamp:
				break
			seen[c * 4 + d] = stamp
			if c == bud:
				return Vector2i(marked, 1 if lit_drops == drops else 0)
			if is_pot[c] or c == lamp:
				break
			if occ_at[c] == stamp:
				var p := occ_p[c]
				var kd := kind[p]
				if kd == 2:
					if d != (face[p] + 2) % 4:
						break
					var cs: PackedInt32Array = cells[p][pos[p]]
					var o: int = cs[1] if cs[0] == c else cs[0]
					for e: int in [c, o]:
						if lit_at[e] != stamp:
							lit_at[e] = stamp
							marked += mark[e]
							lit_drops += is_drop[e]
							if tally:
								hits[e] += 1
					x = o % w
					y = o / w
					d = face[p]
					continue
				d = SLASH[d] if kd == 0 else BACK[d]
			if lit_at[c] != stamp:
				lit_at[c] = stamp
				marked += mark[c]
				lit_drops += is_drop[c]
				if tally:
					hits[c] += 1
		return Vector2i(marked, 0)

## The fewest moves from `start` to the answer that never let go with the
## light on a sleeper (`marked`), the last move excepted -- it is the solve --
## or -1 when there is none. Breadth first over every arrangement, so exact;
## gives up past `cap` arrangements seen (-2).
static func dark_path(g: Dictionary, marked: PackedInt32Array, start: PackedInt32Array, cap := 400000) -> int:
	var f := Fast.new(g, marked)
	var np: int = f.np
	var mul := PackedInt32Array()
	var total := 1
	for p in np:
		mul.append(total)
		total *= f.rails[p]
	var home := 0
	var at := 0
	for p in np:
		home += int(g.pieces[p].home) * mul[p]
		at += start[p] * mul[p]
	if f.probe(start).x > 0:
		return -1
	var visited := PackedByteArray()
	visited.resize(total)
	visited[at] = 1
	var queue := PackedInt32Array([at])
	var dist := PackedInt32Array([0])
	var head := 0
	var pos := PackedInt32Array()
	pos.resize(np)
	while head < queue.size():
		var s := queue[head]
		var dd := dist[head]
		head += 1
		for p in np:
			pos[p] = (s / mul[p]) % f.rails[p]
		for p in np:
			var was := pos[p]
			for q in f.rails[p]:
				if q == was or not f.fits(pos, p, q):
					continue
				var t := s + (q - was) * mul[p]
				if t == home:
					return dd + 1
				if visited[t]:
					continue
				visited[t] = 1
				pos[p] = q
				var r := f.probe(pos)
				pos[p] = was
				if r.x == 0 and r.y == 0:
					queue.append(t)
					dist.append(dd + 1)
					if queue.size() > cap:
						return -2
	return -1

## Hard's snails: `want` cells the light must never be let go on. They sleep
## off the answer's beam and off every rail, never where the light falls on
## the way home -- every piece slid straight home, in one of a few orders,
## from the opening -- so the floor can always be finished without waking
## one; and among those, where the most near misses would put the light (one
## piece a peg off, at any point along that way). Empty when none tempts.
static func lay_snails(rng: RandomNumberGenerator, g: Dictionary, want: int) -> PackedInt32Array:
	var f := Fast.new(g, PackedInt32Array())
	var n: int = f.w * f.h
	var bad := PackedByteArray()
	bad.resize(n)
	bad[int(g.lamp)] = 1
	bad[int(g.bud)] = 1
	for c in g.drops:
		bad[c] = 1
	for c in g.pots:
		bad[c] = 1
	for p in f.np:
		for cs: PackedInt32Array in f.cells[p]:
			for c in cs:
				bad[c] = 1
	var start: PackedInt32Array = g.start
	var off: Array = []
	for p in f.np:
		if start[p] != int(g.pieces[p].home):
			off.append(p)
	var best := PackedInt32Array()
	var best_score := 0
	for attempt in 6:
		var order: Array = off.duplicate()
		if attempt > 0:
			order = _shuffle(rng, order)
		var states: Array = [start.duplicate()]
		var pos := start.duplicate()
		for p: int in order:
			pos[p] = int(g.pieces[p].home)
			states.append(pos.duplicate())
		# Where the light falls on the way home: never a snail.
		f.hits.fill(0)
		f.tally = true
		for st: PackedInt32Array in states:
			f.probe(st)
		var on_way := f.hits.duplicate()
		# Where a near miss puts it: one piece a peg off, anywhere on the way.
		f.hits.fill(0)
		for i in states.size() - 1:
			var st: PackedInt32Array = states[i].duplicate()
			for p in f.np:
				var was := st[p]
				for q in f.rails[p]:
					if q == was or not f.fits(st, p, q):
						continue
					st[p] = q
					f.probe(st)
				st[p] = was
		f.tally = false
		var cand: Array = []
		for c in n:
			if not bad[c] and on_way[c] == 0 and f.hits[c] > 0:
				cand.append(c)
		cand = _shuffle(rng, cand)
		cand.sort_custom(func(a, b): return f.hits[a] > f.hits[b])
		var pick := PackedInt32Array()
		var score := 0
		for c: int in cand:
			if pick.size() >= want:
				break
			# not two snails side by side
			var near := false
			for o in pick:
				if absi(o % f.w - c % f.w) + absi(o / f.w - c / f.w) <= 1:
					near = true
			if near:
				continue
			pick.append(c)
			score += f.hits[c]
		if pick.size() == want and score > best_score:
			best = pick
			best_score = score
	return best

# --- Insane: Shy Dew ---

## Openings tried for a dark one, and dark ones searched, a floor.
const SHY_OPENINGS := 120
const SHY_SEARCHES := 3

## One Shy Dew floor: Insane's band, proved to have one answer, with an
## opening that lights no drop and a way home that never lets go with the
## light on one -- every drop catches the light at once, on the last move.
## `dark` is that way's length in moves, `par` how many pieces start off
## home. {} when this grow found none (the miner simply tries again).
static func generate_shy(rng: RandomNumberGenerator) -> Dictionary:
	var bd := band(3)
	for grows in 400:
		var g := _grow(rng, bd)
		if g.is_empty() or count(g, 2) != 1:
			continue
		var f := Fast.new(g, g.drops)
		var searched := 0
		for tries in SHY_OPENINGS:
			var start := _opening(rng, g)
			if start.is_empty() or f.probe(start).x > 0:
				continue
			searched += 1
			var d := dark_path(g, g.drops, start)
			if d > 0:
				g["start"] = start
				g["shy"] = true
				g["unique"] = true
				g["dark"] = d
				var par := 0
				for p in g.pieces.size():
					if start[p] != int(g.pieces[p].home):
						par += 1
				g["par"] = par
				return g
			if searched >= SHY_SEARCHES:
				break
	return {}

## A random opening: every piece off home, nothing overlapping. Empty when
## the draw boxed a piece in.
static func _opening(rng: RandomNumberGenerator, g: Dictionary) -> PackedInt32Array:
	var occ := {}
	var start := PackedInt32Array()
	for p in g.pieces.size():
		var opts: Array = []
		for q in g.pieces[p].rail.size():
			if q == int(g.pieces[p].home):
				continue
			var ok := true
			for c in cells_of(g, p, q):
				if occ.has(c):
					ok = false
			if ok:
				opts.append(q)
		if opts.is_empty():
			return PackedInt32Array()
		var q: int = opts[rng.randi_range(0, opts.size() - 1)]
		start.append(q)
		for c in cells_of(g, p, q):
			occ[c] = true
	return start

# --- the bank ---

static func to_bank(g: Dictionary) -> Dictionary:
	var pieces: Array = []
	for pc: Dictionary in g.pieces:
		var row := {"kind": pc.kind, "rail": Array(pc.rail), "home": int(pc.home)}
		if pc.kind == "m":
			row["t"] = pc.t
		else:
			row["f"] = int(pc.f)
			row["s"] = int(pc.s)
		pieces.append(row)
	return {"cols": g.cols, "rows": g.rows, "lamp": g.lamp, "dir": g.dir, "bud": g.bud,
		"pieces": pieces, "drops": Array(g.drops), "pots": Array(g.pots), "start": Array(g.start),
		"snails": Array(g.get("snails", [])), "shy": bool(g.get("shy", false)),
		"dark": int(g.get("dark", 0)), "par": int(g.get("par", 0))}

static func from_bank(row: Dictionary) -> Dictionary:
	if row.is_empty() or not row.has("pieces"):
		return {}
	var pieces: Array = []
	for r: Dictionary in row.pieces:
		var pc := {"kind": String(r.kind), "rail": _ints(r.rail), "home": int(r.home)}
		if pc.kind == "m":
			pc["t"] = String(r.t)
		else:
			pc["f"] = int(r.f)
			pc["s"] = int(r.s)
		pc["sol"] = int(pc.rail[pc.home])
		pieces.append(pc)
	return {"cols": int(row.cols), "rows": int(row.rows), "lamp": int(row.lamp), "dir": int(row.dir),
		"bud": int(row.bud), "pieces": pieces, "drops": _ints(row.drops), "pots": _ints(row.pots),
		"start": _ints(row.start), "snails": _ints(row.get("snails", [])), "shy": bool(row.get("shy", false)),
		"dark": int(row.get("dark", 0)), "par": int(row.get("par", 0)), "unique": true, "attempts": 0}

static func _ints(a: Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for v in a:
		out.append(int(v))
	return out
