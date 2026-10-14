extends RefCounted
## Yarn Hoop's rules, scene-free (puzzles/hoop2d.gd draws them;
## docs/agents/boards/hoop.md).
##
## A picture lies hidden on the linen of an embroidery hoop, cut into
## panels: triangles and four-sided pieces, each one colour. Only their
## corners show, as pins, and a small mark in each panel says how many
## corners it has. The player drags a thread from pin to pin; a thread is
## taken only along a panel's side, and a panel whose every side is threaded
## fills with knitting in its colour. Every panel filled is the picture.
##
## The panels are cut from the day's bead picture (the biggest the bank
## Pixel Garden, Button Box and Toy Cannons deal from holds, or the day's
## themed one), the way low-poly art is cut (2026-10-14, after the user set
## a low-poly fox beside our lattice cut): the picture's thin outline and
## speckles are dissolved into what they touch, the edges between its
## colours are traced and simplified to the band's tolerance, pins are set
## along them no nearer than the band's spacing, and the pins are joined
## into triangles (Delaunay), each one the colour most of its beads are,
## one mostly bare linen left out; the biggest triangles are split about
## their middles until the band has its count. Two neighbours of one colour
## are sometimes one four-sided panel. So the same seed always cuts the
## same picture, and its sides follow the picture's own edges.

const ThemedPictures = preload("res://core/themed_pictures.gd")
const BANK := "res://content/pixel_garden.json"
## The bank's bands every difficulty deals from (its 32- and 24-side
## pictures: the cut sets the coarseness, so the biggest source reads best
## on every band), and the sides of the day's themed picture tried in turn.
const BANDS := [3, 2]
const THEMED_SIDES := [48, 32, 24, 12, 10]
const INSANE := 3
## About how many panels a band cuts its picture into.
const PANELS := [26, 50, 90, 330]
## The cut's tolerance and the least distance between two pins, as shares of
## the picture's side; both grow while the picture cuts too fine.
const TOLERANCE := [0.1, 0.07, 0.05, 0.024]
const SPACING := [0.1, 0.075, 0.06, 0.034]
## Triangles the split aims for, over the band's panels: the quads that
## follow take about that many back.
const OVER := 1.18
## How often two neighbouring triangles of one colour are one four-sided
## panel.
const QUADS := [0.5, 0.4, 0.35, 0.3]
## A triangle is kept when bare linen is under this share of its beads.
const BARE_MAX := 0.5
## Beads read a side of a triangle, to colour it.
const SAMPLES := 6
## A triangle narrower than this at a corner is a sliver and left out.
const MIN_ANGLE := 0.07
## A region of the picture is dissolved into its neighbours when it is
## smaller than this share of the squares, or when under half its squares
## sit in a 2x2 block of their own colour (the one-square outline, a stem).
const SPECK := 0.004
## The background carved off is at least this share (percent) of the
## picture's drawn squares.
const BACKDROP := 15
const HINTS_BY := [3, 3, 2, 3]

static var _bank := {}
static var _bank_read := false

var band := 0
var name_key := ""
## The bead picture the panels were cut from, a colour index a square.
var w := 0
var h := 0
var colours: Array[String] = []
var picture := PackedInt32Array()

## The pins, in the picture's squares.
var pins := PackedVector2Array()
## A panel: its corners, round its outline; its colour index; its sides.
var panels: Array = []
var colour := PackedInt32Array()
var panel_sides: Array = []
## A side: its two pins (the lower first) and the one or two panels it bounds.
var sides: Array[Vector2i] = []
var side_panels: Array = []
## A pin's sides.
var pin_sides: Array = []
var _side_of := {}

## What is threaded and filled.
var laid := PackedByteArray()
var filled := PackedByteArray()
## The sides of a panel not threaded yet, and of a pin.
var open_sides := PackedInt32Array()
var pin_open := PackedInt32Array()
var done := 0
var threads := 0
## Threads asked for that are no panel's side.
var refused := 0

static func bank() -> Dictionary:
	if not _bank_read:
		_bank_read = true
		var f := FileAccess.open(BANK, FileAccess.READ)
		if f != null:
			var doc = JSON.parse_string(f.get_as_text())
			if doc is Dictionary:
				_bank = doc
	return _bank

## The bank's pictures every band deals from, the biggest bands' first.
static func pictures() -> Array:
	var doc := bank()
	var out: Array = []
	if doc.get("bands") is Array:
		for k: int in BANDS:
			if k < (doc.bands as Array).size():
				out.append_array(doc.bands[k])
	return out

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank, cut. `daily_key` is
## PuzzleBase.daily_key: a daily takes the day's themed picture, the biggest
## side this phone holds (core/themed_pictures.gd).
func setup(rng: RandomNumberGenerator, difficulty: int, daily_key := 0) -> void:
	band = clampi(difficulty, 0, PANELS.size() - 1)
	var doc := bank()
	var pics := pictures()
	if pics.is_empty():
		adopt({"name": "", "rows": ["..rr..", ".rrrr.", "rrggrr", "rggggr", ".gggg.", "..gg.."]},
			{"r": "red", "g": "green"}, rng)
		return
	# The bank's pick is drawn either way, so the cut that follows is the same
	# on a phone with the day and one without.
	var pic: Dictionary = pics[rng.randi_range(0, pics.size() - 1)]
	var themed := {}
	for side: int in THEMED_SIDES:
		themed = ThemedPictures.picture(daily_key, side)
		if not themed.is_empty():
			break
	adopt(themed if not themed.is_empty() else pic, doc.get("palette", {}), rng)
	# a picture the cut makes nothing of (none of the bank's or the themed
	# ones seen does; one wholly carved or wholly thin would) is dealt the
	# heart above instead
	if panels.is_empty():
		adopt({"name": "", "rows": ["..rr..", ".rrrr.", "rrggrr", "rggggr", ".gggg.", "..gg.."]},
			{"r": "red", "g": "green"}, rng)

## Cuts `pic` ({name, rows}, its letters read through `legend`).
func adopt(pic: Dictionary, legend: Dictionary, rng: RandomNumberGenerator) -> void:
	_read(pic, legend)
	_carve()
	_dissolve()
	_cut(rng, PANELS[band])
	reset()

func _read(pic: Dictionary, legend: Dictionary) -> void:
	var rows: Array = pic.rows
	h = rows.size()
	w = String(rows[0]).length()
	name_key = String(pic.get("name", ""))
	colours = []
	picture = PackedInt32Array()
	picture.resize(w * h)
	picture.fill(-1)
	for y in h:
		var row := String(rows[y])
		for x in mini(w, row.length()):
			var ch := row[x]
			if ch == ".":
				continue
			var named := String(legend.get(ch, "grey"))
			var k := colours.find(named)
			if k < 0:
				k = colours.size()
				colours.append(named)
			picture[y * w + x] = k

## The bead under a point of the picture, -1 bare or off it.
func bead(p: Vector2) -> int:
	var x := int(floor(p.x))
	var y := int(floor(p.y))
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return picture[y * w + x]

## The picture's background made bare linen, so the thing drawn stands on
## the hoop alone: a themed picture sits on a white board and the bank's
## scenes under a sky, and either would knit as a square. The one region
## carved is the thick one that fronts the outside (the picture's edge, or
## the bare linen reached from it) along most of its contact and is a fair
## share of the picture; a whale's body touching the edge at a few squares
## fronts far less of it than its outline does, and stays.
func _carve() -> void:
	var n := w * h
	var got := _components()
	var comp: PackedInt32Array = got[0]
	var cells: Array = got[1]
	# the outside: every bare square reached from the edge
	var outside := PackedByteArray()
	outside.resize(n)
	var queue := PackedInt32Array()
	for c in n:
		var x := c % w
		var y := c / w
		if picture[c] < 0 and (x == 0 or y == 0 or x == w - 1 or y == h - 1):
			outside[c] = 1
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in _around(c):
			if picture[d] < 0 and not outside[d]:
				outside[d] = 1
				queue.append(d)
	# the squares that front it, by region
	var contact := {}
	var contacts := 0
	var filled := 0
	for c in n:
		if picture[c] < 0:
			continue
		filled += 1
		var x := c % w
		var y := c / w
		var fronts := x == 0 or y == 0 or x == w - 1 or y == h - 1
		for d in _around(c):
			fronts = fronts or outside[d] == 1
		if fronts:
			contact[comp[c]] = int(contact.get(comp[c], 0)) + 1
			contacts += 1
	for id in contact:
		var mine: PackedInt32Array = cells[id]
		if int(contact[id]) * 2 < contacts or mine.size() * 100 < filled * BACKDROP:
			continue
		var thick := 0
		for c in mine:
			if _in_block(c, comp):
				thick += 1
		if thick * 2 < mine.size():
			continue
		for c in mine:
			picture[c] = -1
		return

## The picture's regions: a square's region, and each region's squares.
func _components() -> Array:
	var n := w * h
	var comp := PackedInt32Array()
	comp.resize(n)
	comp.fill(-1)
	var cells: Array = []
	var queue := PackedInt32Array()
	for start in n:
		if picture[start] < 0 or comp[start] >= 0:
			continue
		var id := cells.size()
		var mine := PackedInt32Array()
		queue = PackedInt32Array([start])
		comp[start] = id
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			mine.append(c)
			for d in _around(c):
				if comp[d] < 0 and picture[d] == picture[c]:
					comp[d] = id
					queue.append(d)
		cells.append(mine)
	return [comp, cells]

## Dissolves what would cut badly: the one-square outline round the drawn
## thing and any other thin run (a stem, a whisker), and specks too small
## to be a panel, each square of them taking the colour of the nearest
## region that stays. The outline's beads are the darkest and they bound
## every shape, so left in they would be a ring of slivers.
func _dissolve() -> void:
	var n := w * h
	var got := _components()
	var comp: PackedInt32Array = got[0]
	var cells: Array = got[1]
	var queue := PackedInt32Array()
	var small := maxi(3, int(round(n * SPECK)))
	var keep := PackedByteArray()
	keep.resize(cells.size())
	for id in cells.size():
		var mine: PackedInt32Array = cells[id]
		var thick := 0
		for c in mine:
			if _in_block(c, comp):
				thick += 1
		keep[id] = 1 if mine.size() >= small and thick * 2 >= mine.size() else 0
	# the squares of what goes take the colour of the nearest kept square,
	# spreading out from every kept square at once
	var out := PackedInt32Array()
	out.resize(n)
	out.fill(-1)
	queue = PackedInt32Array()
	for c in n:
		if comp[c] >= 0 and keep[comp[c]]:
			out[c] = picture[c]
			queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in _around(c):
			if out[d] < 0 and comp[d] >= 0 and not keep[comp[d]]:
				out[d] = out[c]
				queue.append(d)
	picture = out

## The squares beside square `c`.
func _around(c: int) -> PackedInt32Array:
	var x := c % w
	var y := c / w
	var out := PackedInt32Array()
	if x > 0:
		out.append(c - 1)
	if x < w - 1:
		out.append(c + 1)
	if y > 0:
		out.append(c - w)
	if y < h - 1:
		out.append(c + w)
	return out

## Whether square `c` sits in a 2x2 block of its own region.
func _in_block(c: int, comp: PackedInt32Array) -> bool:
	var x := c % w
	var y := c / w
	var id := comp[c]
	for dy in [-1, 0]:
		for dx in [-1, 0]:
			var ok := true
			for yy in [y + dy, y + dy + 1]:
				for xx in [x + dx, x + dx + 1]:
					if xx < 0 or yy < 0 or xx >= w or yy >= h or comp[yy * w + xx] != id:
						ok = false
			if ok:
				return true
	return false

## The colour of the square at (x, y) of the picture, -1 bare or off it.
func _label(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	return picture[y * w + x]

## The cut: the picture's edges traced and simplified, pins set along them,
## the pins joined into triangles, and the triangles split until there are
## about `want`. The tolerance and the spacing both grow a step while the
## picture comes out too fine.
func _cut(rng: RandomNumberGenerator, want: int) -> void:
	# the side of a square the drawn thing would half fill: what the band's
	# shares are of, so a small thing on a big board cuts as fine as a scene
	var filled := 0
	for c in picture:
		if c >= 0:
			filled += 1
	var side := clampf(sqrt(filled / 0.5), 8.0, float(maxi(w, h)) * 1.5)
	var chains := _trace()
	var tol: float = TOLERANCE[band] * side
	var gap: float = SPACING[band] * side
	var aim := int(round(want * OVER))
	var points := PackedVector2Array()
	var mesh: Array = []
	for attempt in 8:
		points = _place(chains, tol, gap)
		mesh = _mesh(points)
		if (mesh[0] as Array).size() <= int(aim * 1.1) or points.size() <= 4:
			break
		tol *= 1.2
		gap *= 1.2
	# the biggest triangle whose middle is the spacing clear of every pin is
	# split about it, until there are enough
	var guard := 0
	var read := {}
	while (mesh[0] as Array).size() < aim and guard < 400:
		guard += 1
		var tris: Array = mesh[0]
		var order: Array = []
		for t in tris.size():
			var tri: PackedInt32Array = tris[t]
			order.append([absf(_area(points[tri[0]], points[tri[1]], points[tri[2]])), t])
		order.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		var mid := Vector2.INF
		for o: Array in order:
			var tri: PackedInt32Array = tris[int(o[1])]
			var m := (points[tri[0]] + points[tri[1]] + points[tri[2]]) / 3.0
			var clear := true
			for q in points:
				if q.distance_squared_to(m) < gap * gap:
					clear = false
					break
			if clear:
				mid = m
				break
		if mid == Vector2.INF:
			break
		points.append(mid)
		mesh = _mesh(points, read)
	_quads(rng, points, mesh[0], mesh[1])

## The picture's edges, as chains of points on the squares' corners: every
## edge between two colours (or a colour and bare linen) walked from one
## corner where three or more meet to the next, and loops with no such
## corner from any point of theirs. Each chain is [points, junction_first,
## junction_last].
func _trace() -> Array:
	var W := w + 1
	# edges off a corner: east and south, as bits
	var east := PackedByteArray()
	var south := PackedByteArray()
	east.resize(W * (h + 1))
	south.resize(W * (h + 1))
	var degree := PackedByteArray()
	degree.resize(W * (h + 1))
	for y in h + 1:
		for x in w + 1:
			var k := y * W + x
			if x < w and _label(x, y - 1) != _label(x, y):
				east[k] = 1
				degree[k] += 1
				degree[k + 1] += 1
			if y < h and _label(x - 1, y) != _label(x, y):
				south[k] = 1
				degree[k] += 1
				degree[k + W] += 1
	var out: Array = []
	var seen_e := PackedByteArray()
	var seen_s := PackedByteArray()
	seen_e.resize(east.size())
	seen_s.resize(south.size())
	for sweep in 2:
		for k in degree.size():
			if degree[k] == 0 or (sweep == 0 and degree[k] == 2):
				continue
			for dir in 4:
				var chain := _walk(k, dir, east, south, seen_e, seen_s, degree, W)
				if not chain.is_empty():
					out.append(chain)
	return out

## One chain from corner `k` leaving in `dir` (0 east, 1 south, 2 west, 3
## north), on to the next junction or back to the start.
func _walk(k: int, dir: int, east: PackedByteArray, south: PackedByteArray, seen_e: PackedByteArray,
		seen_s: PackedByteArray, degree: PackedByteArray, W: int) -> Array:
	var pts := PackedVector2Array()
	var at := k
	var d := dir
	var first_junction := degree[k] != 2
	while true:
		# the edge out of `at` in `d`, if there is one unseen
		var e := -1
		match d:
			0: e = at if east[at] and not seen_e[at] else -1
			1: e = at if south[at] and not seen_s[at] else -1
			2: e = at - 1 if at % W > 0 and east[at - 1] and not seen_e[at - 1] else -1
			3: e = at - W if at >= W and south[at - W] and not seen_s[at - W] else -1
		if e < 0:
			break
		if d == 0 or d == 2:
			seen_e[e] = 1
		else:
			seen_s[e] = 1
		if pts.is_empty():
			pts.append(Vector2(at % W, at / W))
		at = [at + 1, at + W, at - 1, at - W][d]
		pts.append(Vector2(at % W, at / W))
		if degree[at] != 2 or at == k:
			break
		# the one other edge out of a corner of two
		for nd in 4:
			if nd == (d + 2) % 4:
				continue
			var has := false
			match nd:
				0: has = east[at] == 1
				1: has = south[at] == 1
				2: has = at % W > 0 and east[at - 1] == 1
				3: has = at >= W and south[at - W] == 1
			if has:
				d = nd
				break
	if pts.size() < 2:
		return []
	return [pts, first_junction, degree[at] != 2]

## The pins: every chain simplified to the tolerance `tol`, its corners where
## three colours meet kept first, and no pin nearer another than `gap`.
func _place(chains: Array, tol: float, gap: float) -> PackedVector2Array:
	var wanted: Array = []
	var later: Array = []
	for chain: Array in chains:
		var pts: PackedVector2Array = chain[0]
		var kept := _simplify(pts, tol)
		for i in kept.size():
			var junction: bool = (i == 0 and bool(chain[1])) or (i == kept.size() - 1 and bool(chain[2]))
			if junction:
				wanted.append(kept[i])
			else:
				later.append(kept[i])
	wanted.append_array(later)
	var out := PackedVector2Array()
	for p: Vector2 in wanted:
		var near := false
		for q in out:
			if q.distance_squared_to(p) < gap * gap:
				near = true
				break
		if not near:
			out.append(p)
	return out

## Douglas-Peucker: the chain's ends, and every point farther than `tol` off
## the line between the points kept either side of it.
func _simplify(pts: PackedVector2Array, tol: float) -> PackedVector2Array:
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack: Array = [[0, pts.size() - 1]]
	while not stack.is_empty():
		var span: Array = stack.pop_back()
		var i0: int = span[0]
		var i1: int = span[1]
		if i1 - i0 < 2:
			continue
		var a := pts[i0]
		var b := pts[i1]
		var far := -1
		var far_d := tol
		for i in range(i0 + 1, i1):
			var d: float
			if a == b:
				d = pts[i].distance_to(a)
			else:
				d = Geometry2D.get_closest_point_to_segment(pts[i], a, b).distance_to(pts[i])
			if d > far_d:
				far_d = d
				far = i
		if far >= 0:
			keep[far] = 1
			stack.append([i0, far])
			stack.append([far, i1])
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i]:
			out.append(pts[i])
	return out

## The pins joined into triangles, each one the colour most of its beads
## are: [the triangles kept (corner indices, wound the same way), their
## colours]. A triangle mostly over bare linen, or a sliver, is left out.
## `read` remembers what a triangle's beads said across the splits.
func _mesh(points: PackedVector2Array, read := {}) -> Array:
	var tris: Array = []
	var cols: Array = []
	if points.size() < 3:
		return [tris, cols]
	var idx := Geometry2D.triangulate_delaunay(points)
	for t in idx.size() / 3:
		var tri := PackedInt32Array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		if _area(points[tri[0]], points[tri[1]], points[tri[2]]) < 0.0:
			tri = PackedInt32Array([tri[0], tri[2], tri[1]])
		if _min_angle(points[tri[0]], points[tri[1]], points[tri[2]]) < MIN_ANGLE:
			continue
		var key := Vector3i(tri[0], tri[1], tri[2])
		if not read.has(key):
			read[key] = _read_half(points, [tri[0], tri[1], tri[2]])
		var got: Array = read[key]
		if int(got[0]) < 0:
			continue
		tris.append(tri)
		cols.append(int(got[0]))
	return [tris, cols]

## Twice the signed area of a triangle, positive when wound clockwise on
## the screen (y down), as every panel is.
func _area(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b - a).cross(c - a)

func _min_angle(a: Vector2, b: Vector2, c: Vector2) -> float:
	var out := PI
	for corner in [[a, b, c], [b, c, a], [c, a, b]]:
		var u: Vector2 = corner[1] - corner[0]
		var v: Vector2 = corner[2] - corner[0]
		if u.length_squared() < 1.0e-9 or v.length_squared() < 1.0e-9:
			return 0.0
		out = minf(out, absf(u.angle_to(v)))
	return out

## Two neighbouring triangles of one colour that make a convex four-sided
## shape are sometimes one panel. Then the panels are indexed.
func _quads(rng: RandomNumberGenerator, points: PackedVector2Array, tris: Array, cols: Array) -> void:
	var by_side := {}
	for t in tris.size():
		var tri: PackedInt32Array = tris[t]
		for m in 3:
			var key := _key(tri[m], tri[(m + 1) % 3])
			if not by_side.has(key):
				by_side[key] = PackedInt32Array()
			var lst: PackedInt32Array = by_side[key]
			lst.append(t)
			by_side[key] = lst
	var used := PackedByteArray()
	used.resize(tris.size())
	var raw_panels: Array = []
	var raw_colour: Array = []
	for t in tris.size():
		if used[t]:
			continue
		var tri: PackedInt32Array = tris[t]
		var merged := false
		for m in 3:
			var a := tri[m]
			var b := tri[(m + 1) % 3]
			var c := tri[(m + 2) % 3]
			var lst: PackedInt32Array = by_side[_key(a, b)]
			for u in lst:
				if u == t or used[u] or cols[u] != cols[t] or merged:
					continue
				var other: PackedInt32Array = tris[u]
				var d := -1
				for v in other:
					if v != a and v != b:
						d = v
				# the shape a, d, b, c must turn the same way at every corner
				var quad := PackedVector2Array([points[a], points[d], points[b], points[c]])
				var convex := true
				for q in 4:
					if _area(quad[q], quad[(q + 1) % 4], quad[(q + 2) % 4]) <= 1.0e-6:
						convex = false
				if convex and rng.randf() < float(QUADS[band]):
					raw_panels.append([a, d, b, c])
					raw_colour.append(cols[t])
					used[t] = 1
					used[u] = 1
					merged = true
			if merged:
				break
		if not merged:
			raw_panels.append([tri[0], tri[1], tri[2]])
			raw_colour.append(cols[t])
			used[t] = 1
	_index(points, raw_panels, raw_colour)

## What a half's beads say: [its colour or -1, how many beads agree].
func _read_half(lattice: PackedVector2Array, tri: Array) -> Array:
	var p0: Vector2 = lattice[tri[0]]
	var p1: Vector2 = lattice[tri[1]]
	var p2: Vector2 = lattice[tri[2]]
	var count := {}
	var n := 0
	for u in SAMPLES:
		for v in SAMPLES - u:
			# barycentric points spread over the half, its corners left out
			var a := (u + 0.5) / (SAMPLES + 0.5)
			var b := (v + 0.5) / (SAMPLES + 0.5)
			if a + b >= 1.0:
				continue
			var p := p0 + (p1 - p0) * a + (p2 - p0) * b
			var c := bead(p)
			count[c] = int(count.get(c, 0)) + 1
			n += 1
	var best := -1
	var best_n := 0
	for c: int in count:
		if c >= 0 and int(count[c]) > best_n:
			best = c
			best_n = count[c]
	if n == 0 or float(count.get(-1, 0)) / n >= BARE_MAX:
		return [-1, int(count.get(-1, 0))]
	return [best, best_n]

## Pins kept are the panels' corners only, numbered afresh; sides are every
## panel's outline, shared where two panels meet.
func _index(lattice: PackedVector2Array, raw_panels: Array, raw_colour: Array) -> void:
	var renum := {}
	pins = PackedVector2Array()
	panels = []
	colour = PackedInt32Array()
	for k in raw_panels.size():
		var corners := PackedInt32Array()
		for v: int in raw_panels[k]:
			if not renum.has(v):
				renum[v] = pins.size()
				pins.append(lattice[v])
			corners.append(renum[v])
		panels.append(corners)
		colour.append(raw_colour[k])
	_link()

## The sides, from the panels.
func _link() -> void:
	sides = []
	side_panels = []
	panel_sides = []
	_side_of = {}
	pin_sides = []
	for p in pins.size():
		pin_sides.append(PackedInt32Array())
	for k in panels.size():
		var corners: PackedInt32Array = panels[k]
		var own := PackedInt32Array()
		for m in corners.size():
			var a := corners[m]
			var b := corners[(m + 1) % corners.size()]
			var key := _key(a, b)
			var s: int = _side_of.get(key, -1)
			if s < 0:
				s = sides.size()
				_side_of[key] = s
				sides.append(Vector2i(mini(a, b), maxi(a, b)))
				side_panels.append(PackedInt32Array())
				# packed arrays are values: written back, not appended in place
				var pa: PackedInt32Array = pin_sides[a]
				pa.append(s)
				pin_sides[a] = pa
				var pb: PackedInt32Array = pin_sides[b]
				pb.append(s)
				pin_sides[b] = pb
			var sp: PackedInt32Array = side_panels[s]
			sp.append(k)
			side_panels[s] = sp
			own.append(s)
		panel_sides.append(own)

func _key(a: int, b: int) -> int:
	return mini(a, b) * 65536 + maxi(a, b)

## A hand-made picture (the tutorial's): pins and panels as given, colours
## named.
func adopt_laid(pin_list: Array, panel_list: Array, named: Array) -> void:
	w = 1
	h = 1
	name_key = ""
	picture = PackedInt32Array()
	colours = []
	pins = PackedVector2Array(pin_list)
	panels = []
	colour = PackedInt32Array()
	for k in panel_list.size():
		panels.append(PackedInt32Array(panel_list[k]))
		var c := colours.find(String(named[k]))
		if c < 0:
			c = colours.size()
			colours.append(String(named[k]))
		colour.append(c)
	_link()
	reset()

## Everything unthreaded.
func reset() -> void:
	laid = PackedByteArray()
	laid.resize(sides.size())
	filled = PackedByteArray()
	filled.resize(panels.size())
	open_sides = PackedInt32Array()
	for k in panels.size():
		open_sides.append((panel_sides[k] as PackedInt32Array).size())
	pin_open = PackedInt32Array()
	for p in pins.size():
		pin_open.append((pin_sides[p] as PackedInt32Array).size())
	done = 0
	threads = 0
	refused = 0

## The side between pins `a` and `b`, -1 for none.
func side_between(a: int, b: int) -> int:
	return _side_of.get(_key(a, b), -1)

## A thread from `a` to `b`: -1 when it is no panel's side (it is refused
## and counted), else the panels it closed (none, one or two). A side
## already threaded closes nothing.
const REFUSED := -1
func lay(a: int, b: int) -> Variant:
	var s := side_between(a, b)
	if s < 0:
		refused += 1
		return REFUSED
	return lay_side(s)

func lay_side(s: int) -> PackedInt32Array:
	var closed := PackedInt32Array()
	if laid[s]:
		return closed
	laid[s] = 1
	threads += 1
	pin_open[sides[s].x] -= 1
	pin_open[sides[s].y] -= 1
	for k in side_panels[s]:
		open_sides[k] -= 1
		if open_sides[k] == 0 and not filled[k]:
			filled[k] = 1
			done += 1
			closed.append(k)
	return closed

## The side the bulb threads: one of the panel nearest done (fewest sides
## open, the first such panel), so the hint closes something soon.
func hint() -> int:
	var best := -1
	var best_open := 1 << 20
	for k in panels.size():
		if filled[k]:
			continue
		if open_sides[k] < best_open:
			best_open = open_sides[k]
			best = k
	if best < 0:
		return -1
	for s in panel_sides[best]:
		if not laid[s]:
			return s
	return -1

func is_solved() -> bool:
	return not panels.is_empty() and done >= panels.size()

## Every side threaded: a completed day put back.
func finish() -> void:
	reset()
	for s in sides.size():
		lay_side(s)

## A panel's middle, in the picture's squares.
func centre(k: int) -> Vector2:
	var c := Vector2.ZERO
	var corners: PackedInt32Array = panels[k]
	for v in corners:
		c += pins[v]
	return c / corners.size()

func outline(k: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in panels[k]:
		out.append(pins[v])
	return out

func share_glyphs() -> String:
	return "🧶 %d" % panels.size()
