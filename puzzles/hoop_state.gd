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
const Pal = preload("res://core/palette.gd")
const BANK := "res://content/pixel_garden.json"
## A band's difficulty is its picture, as Pixel Garden's is (the user,
## 2026-10-15: "just like pixel garden easier level means simpler
## images"): Easy deals the day's 24-side themed picture (or the bank's
## 24-side ones), Medium the 32, Hard the 48 and Insane the 48 again, cut
## twice as fine and played through the zoom (the bank's 32 where no 48
## is cached), each cut as true to its own drawing as the pins' spacing
## allows. Cutting one big picture coarse for Easy left a brown blob round
## a red one where the lantern was; the 10- and 12-side pictures are drawn
## in one-square strokes no pin spacing a finger can take keeps.
const THEMED_SIDE := [24, 32, 48, 48]
const BANK_BAND := [2, 3, 3, 3]
const INSANE := 3
## The least distance between two pins, as a share of the side of the
## square the drawn thing would half fill (so on screen, about 760 px of
## linen across the drawing at the whole: Easy ~80 px, Hard ~50, Insane
## ~32 before the zoom), and never under SPACING_MIN squares of the
## picture. No pin is ever set nearer another than that (the user,
## 2026-10-15, of a Hard board: "a lot of dots together, user can't even
## see what to connect").
const SPACING := [0.09, 0.075, 0.066, 0.042]
const SPACING_MIN := 1.15
## The cut's tolerance, in the picture's squares: how far a traced edge
## may stray from the drawing.
const TOLERANCE := [0.6, 0.7, 0.75, 0.8]
## A triangle bigger than this many spacings squared is split about its
## middle, so a wide region still reads as facets.
const SPLIT_AREA := [3.2, 3.0, 2.8, 2.6]
## A panel has 3 to MAX_CORNERS corners (the user: "we should be able to
## handle up to 7 dots area"): neighbouring triangles of one colour are
## joined while the shape stays convex, each panel growing toward a size
## drawn between CORNERS_AIM's two ends.
const MAX_CORNERS := 7
const CORNERS_AIM := [[4, 7], [4, 7], [5, 7], [5, 7]]
## A triangle is kept when bare linen is under this share of its beads
## (its sides keep the drawing's edges, so one over more is a bridge
## between two parts of it, not a piece of its outline).
const BARE_MAX := 0.7
## Beads read a side of a triangle, to colour it.
const SAMPLES := 6
## A triangle narrower than this at a corner is a sliver: left out when
## bare, kept when it is a piece of the drawing (a hole is worse), unless
## it is flat altogether (FLAT).
const MIN_ANGLE := 0.07
const FLAT := 0.012
## A region of the picture is dissolved into its neighbours when it is
## smaller than this share of the squares, or when under half its squares
## sit in a 2x2 block of their own colour (the one-square outline, a stem).
const SPECK := 0.004
## Before that, a thin region joins the thin neighbours of a near colour
## (two greens shading the grass, a pink and a rose): the two-tone run is
## one shape of the bigger one's colour, thick enough to stay. A small
## picture is drawn in such pairs, and dissolved one by one its grass and
## petals were gone (the Easy ladybird of 2026-10-15, a brown blob).
const FAMILY := 0.3
## The background carved off is at least this share (percent) of the
## picture's drawn squares, and either lies along the picture's own edge
## for EDGE_SHARE of its perimeter (a scene's sky or grass) or fills its
## bounding box to BOARD_FILL (a board drawn behind the thing, inside a
## bare margin). A thing drawn on bare linen does neither, however much of
## it fronts the linen (the lantern of 2026-10-15, whose dark body was
## carved and the flame and leaves left floating).
const BACKDROP := 15
const EDGE_SHARE := 0.3
const BOARD_FILL := 0.95
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

## The bank's pictures band `band_` deals from.
static func pictures(band_ := INSANE) -> Array:
	var doc := bank()
	var out: Array = []
	var k: int = BANK_BAND[clampi(band_, 0, BANK_BAND.size() - 1)]
	if doc.get("bands") is Array and k < (doc.bands as Array).size():
		out.append_array(doc.bands[k])
	return out

static func hints_for(band_: int) -> int:
	return HINTS_BY[clampi(band_, 0, HINTS_BY.size() - 1)]

## The day's picture out of the bank, cut. `daily_key` is
## PuzzleBase.daily_key: a daily takes the day's themed picture of the
## band's side (core/themed_pictures.gd).
func setup(rng: RandomNumberGenerator, difficulty: int, daily_key := 0) -> void:
	band = clampi(difficulty, 0, THEMED_SIDE.size() - 1)
	var doc := bank()
	var pics := pictures(band)
	if pics.is_empty():
		adopt({"name": "", "rows": ["..rr..", ".rrrr.", "rrggrr", "rggggr", ".gggg.", "..gg.."]},
			{"r": "red", "g": "green"}, rng)
		return
	# The bank's pick is drawn either way, so the cut that follows is the same
	# on a phone with the day and one without.
	var pic: Dictionary = pics[rng.randi_range(0, pics.size() - 1)]
	var themed := ThemedPictures.picture(daily_key, THEMED_SIDE[band])
	if themed.is_empty() and band == INSANE:
		themed = ThemedPictures.picture(daily_key, 32)
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
	_cut(rng)
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
	# the squares that front it, by region, and those on the picture's edge
	var contact := {}
	var edge := {}
	var contacts := 0
	var filled := 0
	for c in n:
		if picture[c] < 0:
			continue
		filled += 1
		var x := c % w
		var y := c / w
		var fronts := x == 0 or y == 0 or x == w - 1 or y == h - 1
		if fronts:
			edge[comp[c]] = int(edge.get(comp[c], 0)) + 1
		for d in _around(c):
			fronts = fronts or outside[d] == 1
		if fronts:
			contact[comp[c]] = int(contact.get(comp[c], 0)) + 1
			contacts += 1
	var perimeter := 2 * (w + h)
	for id in contact:
		var mine: PackedInt32Array = cells[id]
		if int(contact[id]) * 2 < contacts or mine.size() * 100 < filled * BACKDROP:
			continue
		if float(edge.get(id, 0)) < EDGE_SHARE * perimeter and _bbox_fill(mine) < BOARD_FILL:
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

## How much of its bounding box a region fills, with what it encloses: 1
## for a board, less for a thing with a shape.
func _bbox_fill(mine: PackedInt32Array) -> float:
	var x0 := w
	var y0 := h
	var x1 := -1
	var y1 := -1
	var inside := {}
	for c in mine:
		var x := c % w
		var y := c / w
		x0 = mini(x0, x)
		y0 = mini(y0, y)
		x1 = maxi(x1, x)
		y1 = maxi(y1, y)
		inside[c] = true
	var bw := x1 - x0 + 1
	var bh := y1 - y0 + 1
	# the squares of the box reached from its border without crossing the
	# region are outside it; the rest is the region and its holes
	var reached := {}
	var queue := PackedInt32Array()
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := y * w + x
			if (x == x0 or y == y0 or x == x1 or y == y1) and not inside.has(c):
				reached[c] = true
				queue.append(c)
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in _around(c):
			var dx := d % w
			var dy := d / w
			if dx < x0 or dx > x1 or dy < y0 or dy > y1 or inside.has(d) or reached.has(d):
				continue
			reached[d] = true
			queue.append(d)
	return float(bw * bh - reached.size()) / float(bw * bh)

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
	_join_families()
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

## Thin regions joined with the touching regions of a near colour, painted
## the colour of the biggest of them (FAMILY).
func _join_families() -> void:
	var got := _components()
	var comp: PackedInt32Array = got[0]
	var cells: Array = got[1]
	var m := cells.size()
	var tone: Array = []
	for named in colours:
		tone.append(Pal.PG_BEADS.get(named, Color.GRAY))
	var thin := PackedByteArray()
	thin.resize(m)
	for id in m:
		var mine: PackedInt32Array = cells[id]
		var thick := 0
		for c in mine:
			if _in_block(c, comp):
				thick += 1
		thin[id] = 1 if thick * 2 < mine.size() else 0
	# union-find over regions touching with a near colour, one of them thin
	var root := PackedInt32Array()
	root.resize(m)
	for id in m:
		root[id] = id
	for c in w * h:
		var a := comp[c]
		if a < 0:
			continue
		for d in _around(c):
			var b := comp[d]
			if b < 0 or b == a or not (thin[a] or thin[b]):
				continue
			var ca: Color = tone[picture[c]]
			var cb: Color = tone[picture[d]]
			if Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() > FAMILY:
				continue
			var ra := _find(root, a)
			var rb := _find(root, b)
			if ra != rb:
				root[ra] = rb
	var biggest := {}
	for id in m:
		var r := _find(root, id)
		if not biggest.has(r) or (cells[id] as PackedInt32Array).size() > (cells[biggest[r]] as PackedInt32Array).size():
			biggest[r] = id
	for id in m:
		var top: int = biggest[_find(root, id)]
		if top == id:
			continue
		var col := picture[(cells[top] as PackedInt32Array)[0]]
		for c in cells[id]:
			picture[c] = col

func _find(root: PackedInt32Array, a: int) -> int:
	while root[a] != a:
		root[a] = root[root[a]]
		a = root[a]
	return a

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

## The cut: the picture's edges traced and simplified to the band's
## tolerance, pins set along them no nearer each other than the band's
## spacing, the pins joined into triangles, the big ones split about their
## middles, and neighbours of one colour joined into panels of up to
## MAX_CORNERS corners. How many panels there are is the picture's own: a
## richer drawing makes more.
func _cut(rng: RandomNumberGenerator) -> void:
	# the side of a square the drawn thing would half fill: what the band's
	# spacing is a share of, so a small thing on a big board is spaced as a
	# scene is on screen
	var filled := 0
	for c in picture:
		if c >= 0:
			filled += 1
	var side := clampf(sqrt(filled / 0.5), 8.0, float(maxi(w, h)) * 1.5)
	var chains := _trace()
	var tol: float = TOLERANCE[band]
	var gap: float = maxf(SPACING[band] * side, SPACING_MIN)
	var placed := _place(chains, tol, gap)
	var points: PackedVector2Array = placed[0]
	var cons: Array = placed[1]
	var read := {}
	var mesh := _mesh(points, cons, gap, read)
	# the triangles over SPLIT_AREA spacings squared whose middles are the
	# spacing clear of every pin are split about them, the biggest first
	var big: float = SPLIT_AREA[band] * gap * gap
	for pass_ in 40:
		var tris: Array = mesh[0]
		var order: Array = []
		for t in tris.size():
			var tri: PackedInt32Array = tris[t]
			var area := absf(_area(points[tri[0]], points[tri[1]], points[tri[2]])) * 0.5
			if area > big:
				order.append([area, t])
		order.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
		var added := 0
		for o: Array in order:
			var tri: PackedInt32Array = tris[int(o[1])]
			var m := (points[tri[0]] + points[tri[1]] + points[tri[2]]) / 3.0
			if _nearest(points, m, gap) < 0:
				points.append(m)
				added += 1
		if added == 0:
			break
		mesh = _mesh(points, cons, gap, read)
	_merge(rng, points, mesh[0], mesh[1])

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
## Returns [the pins, the picture's edges as pairs of pin indices]: each
## chain walked pin to pin (a point dropped for being near a pin hands its
## place to that pin), every step one edge the triangles must keep, so no
## panel straddles two colours or bridges two parts of the drawing.
func _place(chains: Array, tol: float, gap: float) -> Array:
	var wanted: Array = []
	var later: Array = []
	var kept_chains: Array = []
	for chain: Array in chains:
		var pts: PackedVector2Array = chain[0]
		var kept := _simplify(pts, tol)
		kept_chains.append(kept)
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
	var cons: Array = []
	var seen := {}
	for kept: PackedVector2Array in kept_chains:
		var last := -1
		for p in kept:
			var pin := _nearest(out, p, gap)
			if pin < 0 or pin == last:
				continue
			if last >= 0:
				var key := _key(last, pin)
				if not seen.has(key):
					seen[key] = true
					cons.append(Vector2i(last, pin))
			last = pin
	return [out, cons]

## The pin nearest `p` within `reach`, or -1.
func _nearest(pins_: PackedVector2Array, p: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach * reach
	for i in pins_.size():
		var d := pins_[i].distance_squared_to(p)
		if d <= best_d:
			best_d = d
			best = i
	return best

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

## The pins joined into triangles (Delaunay) that keep the picture's edges
## (`cons`, pairs of pin indices): an edge the triangles miss has a pin
## added at its middle, and the pins are joined again, until every edge
## is a triangle's side (CONFORM passes; an edge no pin can be put on is
## let go). Then each triangle is the colour most of its beads are:
## [the triangles kept (corner indices, wound the same way), their colours].
## A triangle mostly over bare linen is left out; since no triangle
## crosses an edge, that is only one bridging two parts of the drawing.
## `read` remembers what a triangle's beads said across the splits.
## `points` and `cons` grow with the pins added.
const CONFORM := 8
func _mesh(points: PackedVector2Array, cons: Array, gap: float, read := {}) -> Array:
	var tris: Array = []
	var cols: Array = []
	if points.size() < 3:
		return [tris, cols]
	var idx := PackedInt32Array()
	for round in CONFORM:
		idx = Geometry2D.triangulate_delaunay(points)
		var edges := {}
		for t in idx.size() / 3:
			for m in 3:
				edges[_key(idx[t * 3 + m], idx[t * 3 + (m + 1) % 3])] = true
		var missing: Array = []
		for c in cons.size():
			var e: Vector2i = cons[c]
			if not edges.has(_key(e.x, e.y)):
				missing.append(c)
		if missing.is_empty() or round == CONFORM - 1:
			break
		var split := 0
		for c: int in missing:
			var e: Vector2i = cons[c]
			var m := (points[e.x] + points[e.y]) * 0.5
			# a pin on the edge's middle, unless it would crowd one: then the
			# edge is let go (a panel a little across two colours reads; a
			# knot of pins does not, the user's Hard board of 2026-10-15)
			if _nearest(points, m, gap * 0.75) >= 0:
				continue
			var p := points.size()
			points.append(m)
			cons[c] = Vector2i(e.x, p)
			cons.append(Vector2i(p, e.y))
			split += 1
		if split == 0:
			break
	for t in idx.size() / 3:
		var tri := PackedInt32Array([idx[t * 3], idx[t * 3 + 1], idx[t * 3 + 2]])
		if _area(points[tri[0]], points[tri[1]], points[tri[2]]) < 0.0:
			tri = PackedInt32Array([tri[0], tri[2], tri[1]])
		var angle := _min_angle(points[tri[0]], points[tri[1]], points[tri[2]])
		if angle < FLAT:
			continue
		var key := Vector3i(tri[0], tri[1], tri[2])
		if not read.has(key):
			read[key] = _read_half(points, [tri[0], tri[1], tri[2]])
		var got: Array = read[key]
		if int(got[0]) < 0:
			continue
		if angle < MIN_ANGLE and float(got[1]) < float(got[2]) * 0.9:
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

## Neighbouring triangles of one colour joined into convex panels of up to
## MAX_CORNERS corners: from each triangle not yet taken, in an order the
## rng draws, a panel grows across its sides toward a corner count drawn
## from the band's CORNERS_AIM, taking a neighbour of its colour whenever
## the shape stays convex with no corner on a straight line. Then the
## panels are indexed.
func _merge(rng: RandomNumberGenerator, points: PackedVector2Array, tris: Array, cols: Array) -> void:
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
	var order := range(tris.size())
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	var aim: Array = CORNERS_AIM[band]
	var raw_panels: Array = []
	var raw_colour: Array = []
	for t: int in order:
		if used[t]:
			continue
		used[t] = 1
		var poly: Array = Array(tris[t])
		var want := rng.randi_range(int(aim[0]), int(aim[1]))
		var grew := true
		while grew and poly.size() < want:
			grew = false
			var n := poly.size()
			for m in n:
				var a: int = poly[m]
				var b: int = poly[(m + 1) % n]
				for u in by_side.get(_key(a, b), PackedInt32Array()):
					if used[u] or cols[u] != cols[t]:
						continue
					var other: PackedInt32Array = tris[u]
					var d := -1
					for v in other:
						if v != a and v != b:
							d = v
					if d < 0 or poly.has(d):
						continue
					var next := poly.duplicate()
					next.insert(m + 1, d)
					if _convex(points, next):
						poly = next
						used[u] = 1
						grew = true
						break
				if grew or poly.size() >= want:
					break
		raw_panels.append(poly)
		raw_colour.append(cols[t])
	_index(points, raw_panels, raw_colour)

## Whether the corners of `poly` (indices into `points`, wound clockwise on
## screen) turn the same way at every one, none on a straight line.
func _convex(points: PackedVector2Array, poly: Array) -> bool:
	var n := poly.size()
	for q in n:
		var a: Vector2 = points[poly[q]]
		var b: Vector2 = points[poly[(q + 1) % n]]
		var c: Vector2 = points[poly[(q + 2) % n]]
		var turn := _area(a, b, c)
		if turn <= 0.02 * (b - a).length() * (c - b).length():
			return false
	return true

## What a half's beads say: [its colour or -1, how many beads agree, how
## many were read].
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
		return [-1, int(count.get(-1, 0)), n]
	return [best, best_n, n]

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
