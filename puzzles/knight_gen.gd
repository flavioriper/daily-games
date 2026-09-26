extends RefCounted

## Knight's day, scene-free: the deal, the rose side's rule and the proof.
##
## A w by w board. You are one cream knight; the rose side is a king that
## never moves and one to three rose knights that answer every move of yours.
## The rose rule is fixed (`step`), so a position is only where everyone
## stands, and a breadth-first search over positions (`solve`) is the whole
## proof: every board handed out has a winning line. No uniqueness is asked:
## it is a route puzzle, like Rings.
##
## Ported line for line from the concept page's mock
## (docs/brainstorm/concepts.html#knight, `knightBoard`).
## Spec: docs/superpowers/specs/2026-09-26-knight-flat-design.md, section 5.

## The eight Ls, clockwise from up-right. Their order is the rose side's
## tie-break, so it is part of the rules.
const DX := [1, 2, 2, 1, -1, -2, -2, -1]
const DY := [-2, -1, 1, 2, 2, 1, -1, -2]
const ATTEMPTS := 600
## How far the naive line is walked before it is called a failure.
const NAIVE_CAP := 40
## Per level: board size, rose knights (least, most), the shortest line's
## range, how many Ls from the king you start at least, and Insane's slack
## (the move budget is the shortest line plus this; 0 means no budget).
const BANDS := [
	{"w": 5, "foes": Vector2i(1, 1), "min": 4, "max": 6, "far": 3, "slack": 0},
	{"w": 6, "foes": Vector2i(2, 2), "min": 6, "max": 9, "far": 3, "slack": 0},
	{"w": 7, "foes": Vector2i(2, 3), "min": 8, "max": 12, "far": 4, "slack": 0},
	{"w": 8, "foes": Vector2i(3, 3), "min": 10, "max": 16, "far": 4, "slack": 2},
]

## Positions the last `solve` expanded, for the probe.
static var last_nodes := 0
static var _dists := {}

static func band(difficulty: int) -> Dictionary:
	return BANDS[clampi(difficulty, 0, BANDS.size() - 1)]

## The squares a knight on `c` reaches, in L order.
static func hops(w: int, c: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x := c % w
	var y := c / w
	for i in 8:
		var nx: int = x + DX[i]
		var ny: int = y + DY[i]
		if nx >= 0 and ny >= 0 and nx < w and ny < w:
			out.append(ny * w + nx)
	return out

## Knight-move distance between every pair of squares on the empty board,
## built once a size: dist(w)[a][b].
static func dist(w: int) -> Array:
	if _dists.has(w):
		return _dists[w]
	var n := w * w
	var all: Array = []
	for s in n:
		var d := PackedInt32Array()
		d.resize(n)
		d.fill(99)
		d[s] = 0
		var q := PackedInt32Array([s])
		var h := 0
		while h < q.size():
			var c := q[h]
			h += 1
			for m in hops(w, c):
				if d[m] == 99:
					d[m] = d[c] + 1
					q.append(m)
		all.append(d)
	_dists[w] = all
	return all

## One whole turn: you hop to `to`, then the rose side answers. `took` and
## `caught` are a rose knight's index or -1, and `moved[i]` is
## Vector2i(from, to) for each rose knight (to -1 once taken). Landing on the
## king wins at once, before anything answers. Otherwise the rose knights
## answer in order: take you if they can; else jump to the square nearest you
## in knight moves (ties: the first L), never onto their king or each other;
## with nowhere to go, stand. A later knight sees the earlier ones' new
## squares.
static func step(g: Dictionary, you: int, foes: PackedInt32Array, to: int) -> Dictionary:
	var w: int = g.w
	var king: int = g.king
	var d: Array = dist(w)
	var fs := foes.duplicate()
	var moved: Array[Vector2i] = []
	for f in fs:
		moved.append(Vector2i(f, f))
	if to == king:
		return {"you": to, "foes": fs, "won": true, "took": -1, "caught": -1, "moved": moved}
	var took := fs.find(to)
	if took >= 0:
		fs[took] = -1
		moved[took] = Vector2i(to, -1)
	for i in fs.size():
		var f: int = fs[i]
		if f < 0:
			continue
		var ms := hops(w, f)
		if ms.has(to):
			fs[i] = to
			moved[i] = Vector2i(f, to)
			return {"you": to, "foes": fs, "won": false, "took": took, "caught": i, "moved": moved}
		var best := -1
		var bd := 99
		for m in ms:
			if m == king or fs.has(m):
				continue
			var dm: int = d[m][to]
			if dm < bd:
				bd = dm
				best = m
		if best >= 0:
			fs[i] = best
			moved[i] = Vector2i(f, best)
	return {"you": to, "foes": fs, "won": false, "took": took, "caught": -1, "moved": moved}

## A position as one int: you, then each rose knight plus one (0 = taken),
## base w*w+1. Four pieces on 8x8 stay under 65^4, inside 32 bits.
static func _key(you: int, foes: PackedInt32Array, base: int) -> int:
	var k := you
	for f in foes:
		k = k * base + f + 1
	return k

## The shortest winning line from a position, as the squares you land on;
## empty when there is none within `cap` moves. A move that gets you caught
## is never part of a line.
static func solve(g: Dictionary, you: int, foes: PackedInt32Array, cap: int) -> PackedInt32Array:
	var w: int = g.w
	var base := w * w + 1
	var root := _key(you, foes, base)
	# key -> Vector2i(parent key, the square landed on to get here)
	var parent := {root: Vector2i(-1, -1)}
	var qy := PackedInt32Array([you])
	var qf: Array = [foes]
	var qd := PackedInt32Array([0])
	var qk := PackedInt32Array([root])
	var h := 0
	while h < qy.size():
		var y := qy[h]
		var fs: PackedInt32Array = qf[h]
		var depth := qd[h]
		var k := qk[h]
		h += 1
		if depth >= cap:
			continue
		for m in hops(w, y):
			var r := step(g, y, fs, m)
			if r.won:
				var line := PackedInt32Array([m])
				var kk := k
				while kk != root:
					var p: Vector2i = parent[kk]
					line.insert(0, p.y)
					kk = p.x
				last_nodes = h
				return line
			if int(r.caught) >= 0:
				continue
			var nk := _key(r.you, r.foes, base)
			if parent.has(nk):
				continue
			parent[nk] = Vector2i(k, m)
			qy.append(r.you)
			qf.append(r.foes)
			qd.append(depth + 1)
			qk.append(nk)
	last_nodes = h
	return PackedInt32Array()

## The naive line: always hop to the square nearest the king (ties: the
## first L). A deal is kept only if this fails -- caught, or going round in
## circles, or not there within NAIVE_CAP.
static func naive_wins(g: Dictionary) -> bool:
	var w: int = g.w
	var d: Array = dist(w)
	var you: int = g.you
	var foes: PackedInt32Array = g.foes
	var seen := {}
	for s in NAIVE_CAP:
		var k := _key(you, foes, w * w + 1)
		if seen.has(k):
			return false
		seen[k] = true
		var best := -1
		var bd := 99
		for m in hops(w, you):
			var dm: int = d[m][int(g.king)]
			if dm < bd:
				bd = dm
				best = m
		var r := step(g, you, foes, best)
		if r.won:
			return true
		if int(r.caught) >= 0:
			return false
		you = r.you
		foes = r.foes
	return false

## The day's board. The king first; the rose knights stand guard within two
## Ls of him and you start at least `far` Ls away, clear of every rose
## knight's reach. Kept only if the naive line fails and the shortest line
## falls in the level's range; after ATTEMPTS, the longest line found.
static func generate(rng: RandomNumberGenerator, difficulty: int) -> Dictionary:
	var bd := band(difficulty)
	var w: int = bd.w
	var n := w * w
	var d: Array = dist(w)
	var best := {}
	var attempts := 0
	while attempts < ATTEMPTS:
		attempts += 1
		var foes_range: Vector2i = bd.foes
		var nf := rng.randi_range(foes_range.x, foes_range.y)
		var cells: Array = range(n)
		for i in range(n - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = cells[i]
			cells[i] = cells[j]
			cells[j] = tmp
		var king: int = cells[0]
		var foes := PackedInt32Array()
		for c: int in cells:
			if foes.size() < nf and c != king and d[king][c] <= 2:
				foes.append(c)
		var you := -1
		for c: int in cells:
			if c != king and not foes.has(c) and d[c][king] >= int(bd.far):
				you = c
				break
		if foes.size() < nf or you < 0:
			continue
		var clear := true
		for f in foes:
			if hops(w, f).has(you):
				clear = false
		if not clear:
			continue
		var g := {"w": w, "king": king, "you": you, "foes": foes}
		if naive_wins(g):
			continue
		var line := solve(g, you, foes, int(bd.max))
		if line.is_empty():
			continue
		g["line"] = line
		g["opt"] = line.size()
		g["nodes"] = last_nodes
		g["budget"] = line.size() + int(bd.slack) if int(bd.slack) > 0 else 0
		if line.size() >= int(bd.min):
			g["attempts"] = attempts
			return g
		if best.is_empty() or line.size() > int(best.opt):
			best = g
	best["attempts"] = attempts
	return best
