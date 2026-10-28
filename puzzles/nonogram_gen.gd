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

## Which of a line's runs are surely done, one bool a number: those every
## way of laying the clue over `known` (1 a tile, 0 a cross, -1 open) puts
## on the same cells, and those cells all tiles. The player's own board,
## never the picture: a run is pinned by the edge, by crosses, or by the
## runs around it (2026-10-28). Nothing on a line no placement fits.
static func pinned_runs(clue: Array, known: Array) -> Array:
	var n := known.size()
	var m := clue.size()
	var out: Array = []
	out.resize(m)
	out.fill(false)
	if m == 0:
		return out
	# Crosses and tiles before each cell, so a stretch is read in one step.
	var crosses: Array = [0]
	var tiles: Array = [0]
	for i in n:
		crosses.append(int(crosses[i]) + (1 if int(known[i]) == 0 else 0))
		tiles.append(int(tiles[i]) + (1 if int(known[i]) == 1 else 0))
	var seg := func(s: int, l: int) -> bool:
		return s >= 0 and s + l <= n and int(crosses[s + l]) == int(crosses[s])
	# fwd[j][p]: runs 0..j-1 fit in [0, p) covering every tile there.
	var fwd: Array = []
	for j in m + 1:
		var row: Array = []
		row.resize(n + 1)
		row.fill(false)
		fwd.append(row)
	for p in n + 1:
		fwd[0][p] = int(tiles[p]) == 0
	for j in range(1, m + 1):
		var l := int(clue[j - 1])
		for p in range(1, n + 1):
			var v: bool = int(known[p - 1]) != 1 and bool(fwd[j][p - 1])
			if not v:
				var s := p - l
				v = seg.call(s, l) and _left_ok(fwd, known, j - 1, s)
			fwd[j][p] = v
	# bwd[j][p]: runs j..m-1 fit in [p, n) covering every tile there.
	var bwd: Array = []
	for j in m + 1:
		var row: Array = []
		row.resize(n + 1)
		row.fill(false)
		bwd.append(row)
	for p in n + 1:
		bwd[m][p] = int(tiles[n]) - int(tiles[p]) == 0
	for j in range(m - 1, -1, -1):
		var l := int(clue[j])
		for p in range(n, -1, -1):
			var v: bool = p < n and int(known[p]) != 1 and bool(bwd[j][p + 1])
			if not v:
				v = seg.call(p, l) and _right_ok(bwd, known, j, p + l, n, m)
			bwd[j][p] = v
	for i in m:
		var l := int(clue[i])
		var only := -1
		var count := 0
		for s in n - l + 1:
			if seg.call(s, l) and _left_ok(fwd, known, i, s) and _right_ok(bwd, known, i, s + l, n, m):
				count += 1
				only = s
				if count > 1:
					break
		out[i] = count == 1 and int(tiles[only + l]) - int(tiles[only]) == l
	return out

## Run `j` may start at `s`: everything before it holds runs 0..j-1.
static func _left_ok(fwd: Array, known: Array, j: int, s: int) -> bool:
	if s == 0:
		return j == 0
	return int(known[s - 1]) != 1 and bool(fwd[j][s - 1])

## Run `j` may end at `e`: everything after it holds runs j+1..m-1.
static func _right_ok(bwd: Array, known: Array, j: int, e: int, n: int, m: int) -> bool:
	if e == n:
		return j + 1 == m
	return int(known[e]) != 1 and bool(bwd[j + 1][e + 1])

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

# --- the polish pass (docs/superpowers/specs/2026-09-30-nonogram-polish-design.md) ---

## The picture's shape per band, [w, h]: squares, and tall and wide ones
## (the user, 2026-09-30: "some boards with different shapes, like
## rectangles as portrait, landscape, not just squares"). A day draws one.
##
## Widened 2026-10-16 (the user, with a 20 x 20 from the web: "nonogram daily
## challenges should have all sort of sizes, grids, numbers ... based on
## difficulty"): each band a range of squares, portraits and landscapes.
## Insane grows tall rather than wide: the phone is portrait and the cell is
## capped by the width (columns plus the row clues' band), so a 20-wide
## picture would be a 30 px cell, a third of a fingertip; 15 wide with 20
## rows keeps it near 40.
const SHAPES := [
	[[5, 5], [5, 6], [6, 5], [6, 6], [5, 7], [7, 5]],
	[[7, 7], [8, 8], [6, 8], [8, 6], [7, 9], [8, 10]],
	[[10, 10], [12, 12], [10, 12], [12, 10], [10, 14], [12, 15]],
	[[15, 15], [15, 18], [15, 20], [14, 20], [13, 17], [15, 13]],
]

## Insane since 2026-10-16 (the user: "instead of having shuffled numbers,
## keep the same behavior of others levels but make it way harder and
## bigger"): no tumbled lines, a picture of 15 or so a side with some raw
## noise left in it (INSANE_GRAIN, so lines carry more and shorter runs),
## and of INSANE_POOL that line logic fills, the one it fills slowest
## (`Lines.sweeps`): the most sweeps of every line, then the most cells a
## first sweep leaves open. Still line logic alone, so still no guessing.
const INSANE_GRAIN := 0.15
const INSANE_POOL := 12
## The pool shrinks with the picture so a deal stays near a third of a second
## on the Mac: line logic costs about the square of the cells (a 15 x 20 with
## the full pool was 350 ms). INSANE_POOL is for INSANE_CELLS, never fewer
## than INSANE_POOL_MIN.
const INSANE_CELLS := 225
const INSANE_POOL_MIN := 4

static func hardest(rng: RandomNumberGenerator, w: int, h: int) -> Dictionary:
	var straight: Array = []
	for i in w + h:
		straight.append(false)
	var best: Dictionary = {}
	var best_score := -1
	var kept := 0
	var pool := maxi(INSANE_POOL_MIN, INSANE_POOL * INSANE_CELLS * INSANE_CELLS / (w * h * w * h))
	for _attempt in 200:
		if kept >= pool:
			break
		var bmp := picture(rng, w, h, INSANE_GRAIN)
		if bmp.is_empty():
			continue
		var c := clues_of(bmp, w, h)
		var lines := Lines.new(c.rows, c.cols, straight)
		if not lines.matches(lines.line_solve(), bmp):
			continue
		kept += 1
		var sw := lines.sweeps()
		var score: int = sw[0] * 1000 + sw[1]
		if score > best_score:
			best_score = score
			best = {"bitmap": bmp, "rows": c.rows, "cols": c.cols, "w": w, "h": h,
				"ok": true, "sweeps": sw[0], "open": sw[1]}
	return best

static func shape_for(rng: RandomNumberGenerator, band: int) -> Vector2i:
	var set: Array = SHAPES[clampi(band, 0, SHAPES.size() - 1)]
	var s: Array = set[rng.randi_range(0, set.size() - 1)]
	return Vector2i(int(s[0]), int(s[1]))

## Whether a line's runs answer its clue. A tumbled line (Leaf Fall) has its
## numbers in any order, so only the multiset has to agree.
static func reads(line: Array, clue: Array, tumbled: bool) -> bool:
	var got := clue_for(line)
	if not tumbled:
		return got == clue
	if got.size() != clue.size():
		return false
	var a := got.duplicate()
	var b := clue.duplicate()
	a.sort()
	b.sort()
	return a == b

## Whether a tumbled clue says anything its order would not: a clue of one
## number, or of one number repeated, reads the same in any order.
static func can_tumble(clue: Array) -> bool:
	for v in clue:
		if int(v) != int(clue[0]):
			return true
	return false

## The bank's encoding: the picture row by row as "0"/"1", and which lines
## are tumbled, rows then columns.
static func to_bank(bmp: Array, w: int, h: int, tumbled: Array) -> Dictionary:
	var bits := ""
	for y in h:
		for x in w:
			bits += "1" if int(bmp[y][x]) == 1 else "0"
	var leaf := ""
	for f in tumbled:
		leaf += "1" if bool(f) else "0"
	return {"w": w, "h": h, "bits": bits, "leaf": leaf}

static func from_bank(board: Dictionary) -> Dictionary:
	if board.is_empty() or not board.has("bits"):
		return {}
	var w := int(board.get("w", 0))
	var h := int(board.get("h", 0))
	var bits: String = board.bits
	var leaf: String = board.get("leaf", "")
	if w <= 0 or h <= 0 or bits.length() != w * h:
		return {}
	var bmp: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			row.append(1 if bits[y * w + x] == "1" else 0)
		bmp.append(row)
	var tumbled: Array = []
	for i in w + h:
		tumbled.append(i < leaf.length() and leaf[i] == "1")
	var out := clues_of(bmp, w, h)
	out["bitmap"] = bmp
	out["tumbled"] = tumbled
	out["w"] = w
	out["h"] = h
	out["ok"] = true
	return out

static func clues_of(bmp: Array, w: int, h: int) -> Dictionary:
	var rows: Array = []
	var cols: Array = []
	for y in h:
		rows.append(clue_for(bmp[y]))
	for x in w:
		var col: Array = []
		for y in h:
			col.append(bmp[y][x])
		cols.append(clue_for(col))
	return {"rows": rows, "cols": cols}

## A candidate picture for Leaf Fall at `w` x `h`: the ordinary blobby
## noise, kept to the same fill as the other bands.
static func picture(rng: RandomNumberGenerator, w: int, h: int, grain := 0.0) -> Array:
	for _attempt in 300:
		var bmp := _blobby(rng, w, h)
		# Grain: some cells keep their raw noise, so lines carry more runs of
		# more lengths than a smooth blob's one or two.
		if grain > 0.0:
			for y in h:
				for x in w:
					if rng.randf() < grain:
						bmp[y][x] = 1 - int(bmp[y][x])
		var filled := 0
		for y in h:
			for x in w:
				filled += int(bmp[y][x])
		var ratio := float(filled) / float(w * h)
		if ratio >= 0.35 and ratio <= 0.65:
			return bmp
	return []

## Leaf Fall's solver, on bit masks. One instance per thread: its caches are
## its own (the static line cache above is not safe to share across the
## miner's threads).
##
## `line_solve` is plain line logic run to its fixpoint -- every placement of
## a line's runs (in any order, on a tumbled line) that agrees with what is
## known, intersected -- and it is all there is: a board is dealt only when
## that alone fills the picture, so it has exactly one answer and never asks
## for a guess. The supposition this class once added when line logic
## stalled (suppose a cell, follow it to a contradiction) went on 2026-10-04:
## the user wants every board "fully solvable from deduction, no guess".
class Lines:
	var w := 0
	var h := 0
	var rows: Array = []
	var cols: Array = []
	var tumbled: Array = []
	var _opts: Array = []          # line index (rows then cols) -> PackedInt64Array
	var _cache: Dictionary = {}
	## Lines read by the last line_solve: its work.
	var nodes := 0

	func _init(p_rows: Array, p_cols: Array, p_tumbled: Array) -> void:
		rows = p_rows
		cols = p_cols
		h = rows.size()
		w = cols.size()
		tumbled = p_tumbled
		_opts = []
		for y in h:
			_opts.append(_placements(rows[y], w, bool(tumbled[y])))
		for x in w:
			_opts.append(_placements(cols[x], h, bool(tumbled[h + x])))

	func _placements(clue: Array, n: int, tumble: bool) -> PackedInt64Array:
		var key := "%s|%d|%s" % [clue, n, tumble]
		if _cache.has(key):
			return _cache[key]
		var seen: Dictionary = {}
		var perms: Array = [clue]
		if tumble:
			perms = _perms(clue)
		for p in perms:
			_emit(p, 0, 0, n, 0, seen)
		var out := PackedInt64Array(seen.keys())
		_cache[key] = out
		return out

	static func _perms(clue: Array) -> Array:
		if clue.size() <= 1:
			return [clue]
		var out: Array = []
		var used: Dictionary = {}
		for i in clue.size():
			if used.has(int(clue[i])):
				continue
			used[int(clue[i])] = true
			var rest := clue.duplicate()
			rest.remove_at(i)
			for tail in _perms(rest):
				out.append([clue[i]] + tail)
		return out

	## Every placement of `clue` from run `ci` on, starting at `pos`, as bits.
	static func _emit(clue: Array, ci: int, pos: int, n: int, acc: int, out: Dictionary) -> void:
		if ci == clue.size():
			out[acc] = true
			return
		var need := 0
		for i in range(ci, clue.size()):
			need += int(clue[i])
		need += clue.size() - ci - 1
		var run := int(clue[ci])
		for start in range(pos, n - need + 1):
			var bits := ((1 << run) - 1) << start
			_emit(clue, ci + 1, start + run + 1, n, acc | bits, out)

	## A fresh grid: two masks a row, what is known filled and known empty.
	func blank() -> Dictionary:
		var f := PackedInt64Array()
		var e := PackedInt64Array()
		f.resize(h)
		e.resize(h)
		return {"f": f, "e": e}

	## Line logic to its fixpoint on `g` (changed in place). False on a
	## contradiction.
	func propagate(g: Dictionary, dirty: Array = []) -> bool:
		var f: PackedInt64Array = g.f
		var e: PackedInt64Array = g.e
		var queue: Array = dirty if not dirty.is_empty() else range(h + w)
		var queued: Dictionary = {}
		for i in queue:
			queued[i] = true
		var full_w := (1 << w) - 1
		var full_h := (1 << h) - 1
		while not queue.is_empty():
			var li: int = queue.pop_back()
			queued.erase(li)
			nodes += 1
			if li < h:
				var y := li
				var r := _refine(_opts[li], f[y], e[y], full_w)
				if r.is_empty():
					return false
				var nf: int = r[0]
				var ne: int = r[1]
				var gained := (nf & ~f[y]) | (ne & ~e[y])
				if gained == 0:
					continue
				f[y] = nf
				e[y] = ne
				for x in w:
					if gained & (1 << x) and not queued.has(h + x):
						queued[h + x] = true
						queue.append(h + x)
			else:
				var x := li - h
				var cf := 0
				var ce := 0
				for y in h:
					if f[y] & (1 << x):
						cf |= 1 << y
					elif e[y] & (1 << x):
						ce |= 1 << y
				var r := _refine(_opts[li], cf, ce, full_h)
				if r.is_empty():
					return false
				var gained: int = (int(r[0]) & ~cf) | (int(r[1]) & ~ce)
				if gained == 0:
					continue
				for y in h:
					if gained & (1 << y):
						if int(r[0]) & (1 << y):
							f[y] |= 1 << x
						else:
							e[y] |= 1 << x
						if not queued.has(y):
							queued[y] = true
							queue.append(y)
		g.f = f
		g.e = e
		return true

	static func _refine(opts: PackedInt64Array, f: int, e: int, full: int) -> Array:
		var and_m := full
		var or_m := 0
		var any := false
		for p in opts:
			if (p & e) != 0 or (p & f) != f:
				continue
			any = true
			and_m &= p
			or_m |= p
		if not any:
			return []
		return [and_m, full & ~or_m]

	## How slowly line logic fills the picture, as a player reading one line
	## at a time would: [sweeps of every row then every column until nothing
	## more is known, cells still open after the first sweep].
	func sweeps() -> Array:
		var g := blank()
		var f: PackedInt64Array = g.f
		var e: PackedInt64Array = g.e
		var full_w := (1 << w) - 1
		var full_h := (1 << h) - 1
		var first := -1
		var n := 0
		while n < 100:
			n += 1
			var gained := false
			for y in h:
				var r := _refine(_opts[y], f[y], e[y], full_w)
				if r.is_empty():
					return [n, 0]
				if int(r[0]) != f[y] or int(r[1]) != e[y]:
					gained = true
				f[y] = r[0]
				e[y] = r[1]
			for x in w:
				var cf := 0
				var ce := 0
				for y in h:
					if f[y] & (1 << x):
						cf |= 1 << y
					elif e[y] & (1 << x):
						ce |= 1 << y
				var r := _refine(_opts[h + x], cf, ce, full_h)
				if r.is_empty():
					return [n, 0]
				for y in h:
					if int(r[0]) & (1 << y) and not (f[y] & (1 << x)):
						f[y] |= 1 << x
						gained = true
					elif int(r[1]) & (1 << y) and not (e[y] & (1 << x)):
						e[y] |= 1 << x
						gained = true
			if first < 0:
				first = unknown({"f": f, "e": e})
			if not gained:
				break
		return [n, first]

	func unknown(g: Dictionary) -> int:
		var n := 0
		for y in h:
			var known: int = int(g.f[y]) | int(g.e[y])
			for x in w:
				if not (known & (1 << x)):
					n += 1
		return n

	func copy(g: Dictionary) -> Dictionary:
		return {"f": (g.f as PackedInt64Array).duplicate(), "e": (g.e as PackedInt64Array).duplicate()}

	## Line logic to its fixpoint from a blank grid. Returns the grid ({} on a
	## contradiction); `unknown` says what it left open.
	func line_solve() -> Dictionary:
		nodes = 0
		var g := blank()
		if not propagate(g):
			return {}
		return g

	## Whether `g` is fully known and equal to `bmp`.
	func matches(g: Dictionary, bmp: Array) -> bool:
		if g.is_empty():
			return false
		for y in h:
			for x in w:
				var bit := 1 << x
				var want := int(bmp[y][x]) == 1
				if want and not (int(g.f[y]) & bit):
					return false
				if not want and not (int(g.e[y]) & bit):
					return false
		return true
