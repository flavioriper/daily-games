extends RefCounted

## A Gumdrop jelly as pure data (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md): clear jelly
## cast as a real thing, a chunk for each part of it, and the flavour each
## chunk is wanted in. The sim (puzzles/gumdrop_sim.gd) lays its grid over
## it and the art (puzzles/gumdrop_art.gd) draws it, both from the same
## polygons.
##
## Since 2026-10-11 there is no wall in it (the user, over the reference's
## screen: "the jelly on the game should not have borders, it should be a
## real jelly with different colors ... also we want to show real images to
## the user not random simple forms"; and, of a first build where the
## whole jelly was one piece and the tint ran through it: "it's wrong, the
## jelly need individual chunks to hold the colors"). The chunks lie side
## by side, touching, and each holds its own tint: the seam between two is
## a fence for the dye and a thin line on the screen, never a wall. It was
## an outline cut by walls into sectors, a core or bands until then.
##
## Everything is in mould units: a field SIDE by SIDE, y down. A picture
## is its parts from the one underneath to the one on top, each a flavour
## and the shapes it is made of; `cells` keeps that order, so the chunk a
## point belongs to is the last one that holds it (`cell_at`), and a
## drawing of them in order is the picture. `seams` is what of each
## chunk's edge shows, for the line between chunks.

## The six flavours. The even ones are the three pigments themselves, the
## odd ones the two beside them half and half.
enum Flavour { CHERRY, ORANGE, LEMON, LIME, BLUEBERRY, GRAPE }

const SIDE := 100.0
## How far the jelly's clear edge stands out past its outline.
const RIM := 1.6
## Each flavour as red, yellow and blue pigment, summing to one.
const PIGMENT := [Vector3(1, 0, 0), Vector3(0.5, 0.5, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0.5), Vector3(0, 0, 1), Vector3(0.5, 0, 0.5)]
## The most parts a picture comes to (the judge's shader has this many).
const CELLS_TOP := 16

const C := Flavour.CHERRY
const O := Flavour.ORANGE
const LE := Flavour.LEMON
const LI := Flavour.LIME
const B := Flavour.BLUEBERRY
const G := Flavour.GRAPE

## The pictures, easiest first: two flavours, then three, then four and
## more. A band's day draws from a run of them (`BANDS`, `day`).
const PICTURES := [
	"mushroom", "watermelon", "carrot", "strawberry", "pineapple", "tulip", "fish", "grapes",
	"lolly", "cone", "house", "boat", "flower", "duck", "tree", "car", "butterfly", "cupcake", "bee",
	"rocket", "balloon", "umbrella", "crown", "kite", "lights", "pencil", "cake", "ball", "rainbow",
]
## A day's jellies by band (docs/superpowers/specs/
## 2026-10-11-gumdrop-daily-design.md, section 1): how many, the rows of
## PICTURES they are drawn from and how the pots are stood (`Stood`). (The
## mark each had to be served at went on 2026-10-26: a serve never fails.)
enum Stood { PLAIN, ONE_MIXED, THREE_POTS }
const BANDS := [
	{"moulds": 2, "rows": [0, 7], "stood": Stood.PLAIN},
	# Medium mixes one flavour from two pots since 2026-10-29 (made fun:
	# Easy and Medium had no choice to make, the pot was the card's)
	{"moulds": 3, "rows": [8, 18], "stood": Stood.ONE_MIXED},
	{"moulds": 4, "rows": [11, 26], "stood": Stood.ONE_MIXED},
	{"moulds": 5, "rows": [19, 28], "stood": Stood.THREE_POTS},
]
## The three pots Insane stands by every tray: the pigments themselves.
const PRIMARIES := [0, 2, 4]
## A themed jelly (core/themed_pictures.gd's `jelly`), written each night
## by server/functions/src/jelly.ts, is held to its band's row here: how
## many flavours, how many of them mixed, how many chunks; every chunk
## shows LEAST_SQUARES of the sim's grid, the jelly covers COVER of it, one
## piece, every point inside EDGE. jelly.ts's RULES are the same numbers:
## the two change together.
const THEMED := [
	{"flavours": [2, 2], "mixed": 0, "chunks": [2, 5]},
	{"flavours": [3, 3], "mixed": 0, "chunks": [3, 7]},
	{"flavours": [3, 4], "mixed": 1, "chunks": [3, 10]},
	{"flavours": [4, 6], "mixed": 2, "chunks": [4, 14]},
]
const LEAST_SQUARES := 9
## Mould units squared (about three of the sim's squares) under which a
## piece a later chunk cuts off an earlier one is a sliver, given to the
## chunk that cut it rather than stood as a chunk too small to pour in.
const SLIVER := 24.0
const COVER := [0.2, 0.75]
const EDGE := [4.0, 96.0]
## The sim's grid (gumdrop_sim.gd N), counted here without a sim.
const GRID := 36

# --- shapes ---

static func _ccw(p: PackedVector2Array) -> PackedVector2Array:
	if Geometry2D.is_polygon_clockwise(p):
		p.reverse()
	return p

static func area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5

## An ellipse about (x, y), turned `rot`.
static func ell(x: float, y: float, rx: float, ry: float, rot := 0.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		p.append(Vector2(x, y) + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return _ccw(p)

## A box with its corners rounded by `r`.
static func box(x: float, y: float, w: float, h: float, r := 0.0) -> PackedVector2Array:
	r = minf(r, minf(w, h) * 0.5)
	if r <= 0.0:
		return _ccw(PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)]))
	var p := PackedVector2Array()
	var mids := [Vector2(x + w - r, y + r), Vector2(x + w - r, y + h - r), Vector2(x + r, y + h - r), Vector2(x + r, y + r)]
	for k in 4:
		for i in 7:
			p.append(mids[k] + Vector2.from_angle(-PI * 0.5 + PI * 0.5 * k + PI * 0.5 * i / 6.0) * r)
	return _ccw(p)

## Points joined and their corners cut `times` over, so a drawn corner is a
## soft one.
static func soft(flat: Array, times := 2) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		p.append(Vector2(flat[i], flat[i + 1]))
	for t in times:
		var q := PackedVector2Array()
		for i in p.size():
			var a := p[i]
			var b := p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return _ccw(p)

## What of a shape lies inside a box.
static func within(p: PackedVector2Array, x: float, y: float, w: float, h: float) -> PackedVector2Array:
	var best := PackedVector2Array()
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(p, box(x, y, w, h)):
		if not Geometry2D.is_polygon_clockwise(piece) and area(piece) > area(best):
			best = piece
	return best

## Shapes joined into as few pieces as they come to, holes dropped.
static func joined(shapes: Array) -> Array:
	var out: Array = []
	for s: PackedVector2Array in shapes:
		var now := s
		var again := true
		while again:
			again = false
			for k in out.size():
				var both := _outer(Geometry2D.merge_polygons(now, out[k]))
				if both.size() == 1:
					now = both[0]
					out.remove_at(k)
					again = true
					break
		out.append(now)
	return out

static func _outer(pieces: Array) -> Array:
	var out: Array = []
	for p: PackedVector2Array in pieces:
		if not Geometry2D.is_polygon_clockwise(p) and area(p) > 1.0:
			out.append(p)
	return out

# --- the pictures ---

## A picture's parts, the one underneath first: [flavour, shapes].
static func parts(id: String) -> Array:
	match id:
		"mushroom":
			return [[LE, [box(39, 46, 22, 44, 9)]],
				[C, [within(ell(50, 50, 37, 36), 0, 0, 100, 54)]]]
		"watermelon":
			var rind := within(ell(50, 30, 42, 52), 0, 30, 100, 70)
			return [[LI, [rind]], [C, [within(ell(50, 30, 32, 41), 0, 30, 100, 70)]]]
		"carrot":
			return [[LI, [ell(50, 22, 6, 15), ell(39, 26, 5, 13, -0.6), ell(61, 26, 5, 13, 0.6)]],
				[O, [soft([32, 34, 50, 30, 68, 34, 57, 82, 50, 94, 43, 82])]]]
		"strawberry":
			return [[C, [soft([24, 34, 50, 28, 76, 34, 72, 62, 50, 94, 28, 62])]],
				[LI, [ell(50, 30, 23, 8), ell(50, 19, 5, 10), ell(36, 34, 9, 6, 0.5), ell(64, 34, 9, 6, -0.5)]]]
		"pineapple":
			return [[LI, [ell(50, 22, 6, 17), ell(38, 27, 5, 14, -0.6), ell(62, 27, 5, 14, 0.6)]],
				[LE, [ell(50, 62, 25, 30)]]]
		"tulip":
			return [[LI, [box(46, 46, 8, 46, 4), ell(62, 74, 13, 6, -0.6), ell(38, 74, 13, 6, 0.6)]],
				[C, [ell(50, 32, 15, 22), ell(37, 30, 9, 17, -0.25), ell(63, 30, 9, 17, 0.25)]]]
		"fish":
			return [[B, [soft([70, 50, 92, 28, 88, 50, 92, 72], 1), ell(44, 30, 13, 9), ell(44, 70, 10, 7)]],
				[O, [ell(44, 50, 32, 21)]]]
		"grapes":
			return [[G, [ell(30, 42, 12, 12), ell(50, 42, 12, 12), ell(70, 42, 12, 12), ell(40, 60, 12, 12),
					ell(60, 60, 12, 12), ell(50, 78, 12, 12)]],
				[LI, [box(47, 12, 6, 22, 3), ell(62, 24, 15, 9, -0.35)]]]
		"lolly":
			var ice := box(28, 8, 44, 64, 20)
			return [[O, [box(44, 66, 12, 28, 5)]], [C, [ice]], [LE, [within(ice, 0, 42, 100, 60)]]]
		"cone":
			return [[O, [soft([32, 52, 68, 52, 50, 96], 1)]],
				[C, [ell(50, 44, 22, 17)]], [LE, [ell(50, 23, 16, 14)]]]
		"house":
			return [[LE, [box(24, 44, 52, 46, 5)]], [B, [box(42, 62, 16, 28, 5)]],
				[C, [soft([12, 50, 50, 10, 88, 50], 1)]]]
		"boat":
			return [[B, [soft([10, 64, 90, 64, 76, 88, 24, 88], 1), box(47, 10, 6, 60, 2)]],
				[C, [soft([53, 12, 53, 62, 88, 62], 1)]], [LE, [soft([47, 24, 47, 62, 16, 62], 1)]]]
		"flower":
			var petals: Array = []
			for k in 6:
				var d := Vector2.from_angle(TAU * k / 6.0 + 0.5) * 17.0
				petals.append(ell(50 + d.x, 34 + d.y, 12, 12))
			return [[LI, [box(46, 46, 8, 48, 4), ell(63, 78, 13, 6, -0.55)]], [G, petals], [LE, [ell(50, 34, 10, 10)]]]
		"duck":
			return [[O, [ell(86, 34, 9, 5)]], [LE, [ell(44, 64, 31, 23), ell(66, 34, 16, 16), ell(14, 54, 9, 7, 0.5)]],
				[B, [ell(40, 66, 16, 11, 0.2)]]]
		"tree":
			return [[O, [box(43, 56, 14, 38, 4)]],
				[LI, [ell(50, 38, 30, 24), ell(32, 44, 14, 13), ell(68, 44, 14, 13), ell(50, 22, 18, 13)]],
				[C, [ell(36, 38, 7, 7), ell(60, 28, 7, 7), ell(58, 50, 7, 7)]]]
		"car":
			return [[C, [box(8, 46, 84, 26, 9), soft([26, 50, 36, 26, 66, 26, 78, 50], 1)]],
				[B, [box(38, 31, 11, 14, 3), box(53, 31, 11, 14, 3)]],
				[G, [ell(28, 74, 11, 11), ell(72, 74, 11, 11)]]]
		"butterfly":
			return [[B, [ell(33, 66, 16, 15), ell(67, 66, 16, 15)]], [G, [ell(29, 36, 21, 19), ell(71, 36, 21, 19)]],
				[O, [box(44, 22, 12, 58, 6)]]]
		"cupcake":
			return [[B, [soft([26, 54, 74, 54, 65, 92, 35, 92], 1)]],
				[G, [ell(50, 50, 30, 13), ell(50, 36, 22, 12), ell(50, 24, 13, 10)]], [C, [ell(50, 13, 8, 8)]]]
		"bee":
			var body := ell(50, 60, 30, 24)
			return [[B, [ell(36, 30, 14, 16, -0.3), ell(64, 30, 14, 16, 0.3)]], [LE, [body]],
				[G, [within(body, 34, 0, 10, 100), within(body, 56, 0, 10, 100)]]]
		"rocket":
			var hull := ell(50, 46, 17, 34)
			return [[O, [ell(50, 86, 8, 11)]], [C, [soft([36, 56, 18, 82, 38, 78], 1), soft([64, 56, 82, 82, 62, 78], 1)]],
				[B, [hull]], [C, [within(hull, 0, 0, 100, 28)]], [LE, [ell(50, 46, 8, 8)]]]
		"balloon":
			var bag := ell(50, 38, 32, 32)
			return [[O, [soft([39, 62, 61, 62, 57, 80, 43, 80], 1), box(40, 78, 20, 14, 4)]],
				[C, [bag]], [LE, [within(bag, 39, 0, 22, 100)]], [B, [within(bag, 61, 0, 40, 100)]]]
		"umbrella":
			var top := within(ell(50, 50, 42, 38), 0, 0, 100, 50)
			return [[G, [box(47, 46, 6, 42, 3), box(47, 82, 18, 7, 3)]],
				[C, [top]], [LE, [within(top, 36, 0, 28, 100)]], [B, [within(top, 64, 0, 40, 100)]]]
		"crown":
			return [[LE, [soft([12, 30, 30, 52, 50, 20, 70, 52, 88, 30, 80, 86, 20, 86], 1)]],
				[C, [ell(31, 70, 7, 7)]], [B, [ell(50, 70, 7, 7)]], [LI, [ell(69, 70, 7, 7)]]]
		"kite":
			var cloth := soft([50, 6, 84, 42, 50, 92, 16, 42], 1)
			return [[C, [cloth]], [LE, [within(cloth, 50, 0, 50, 42)]], [B, [within(cloth, 0, 42, 50, 58)]],
				[LI, [within(cloth, 50, 42, 50, 58)]]]
		"lights":
			return [[B, [box(31, 6, 38, 88, 12)]], [C, [ell(50, 24, 10, 10)]], [LE, [ell(50, 50, 10, 10)]],
				[LI, [ell(50, 76, 10, 10)]]]
		"pencil":
			return [[LE, [box(38, 28, 24, 44)]], [C, [box(38, 6, 24, 16, 6)]], [B, [box(38, 18, 24, 11)]],
				[O, [soft([38, 71, 62, 71, 50, 96], 1)]]]
		"cake":
			return [[G, [box(14, 62, 72, 28, 7)]], [LE, [box(24, 42, 52, 24, 7)]], [C, [box(34, 24, 32, 22, 7)]],
				[LI, [ell(50, 19, 8, 8)]]]
		"ball":
			var disc := ell(50, 50, 40, 40)
			var out: Array = []
			var order := [C, LE, B, O, LI, G]
			for k in 6:
				var a0 := TAU * k / 6.0
				var a1 := TAU * (k + 1) / 6.0
				var wedge := _ccw(PackedVector2Array([Vector2(50, 50), Vector2(50, 50) + Vector2.from_angle(a0) * 80.0,
					Vector2(50, 50) + Vector2.from_angle((a0 + a1) * 0.5) * 80.0, Vector2(50, 50) + Vector2.from_angle(a1) * 80.0]))
				for piece: PackedVector2Array in _outer(Geometry2D.intersect_polygons(disc, wedge)):
					out.append([order[k], [piece]])
			return out
		"rainbow":
			var bows: Array = []
			var order := [C, O, LE, LI, B]
			for k in 5:
				bows.append([order[k], [within(ell(50, 74, 45.0 - 9.0 * k, 58.0 - 11.5 * k), 0, 0, 100, 74)]])
			return bows
	return []

# --- a jelly ---

## A picture built: its parts as `cells` (the one underneath first, a part
## in two pieces is two cells), the flavour each is wanted in, and the
## whole jelly's outline. Empty when the id is no picture's.
static func build(id: String) -> Dictionary:
	return build_parts(id, parts(id))

## A jelly built from parts as `parts()` gives them, under `id`.
##
## The parts' pieces are the chunks as the night counts them (`laid`,
## `source`); every piece a later chunk leaves of an earlier one is then
## a cell of its own (the user, 2026-10-14, of a cup two stripes of one
## part either side of a stripe laid over it: "every part of the picture
## should have its own 0-100% even within the same chunk, not share it"),
## so each has its own tank, fence and meter. A chunk left in one piece
## keeps its whole polygon: what lies over it covers the rest, as it
## always did, so a hole in it is nothing to draw.
static func build_parts(id: String, given: Array) -> Dictionary:
	var laid: Array = []
	var laid_want: Array = []
	for part: Array in given:
		for piece: PackedVector2Array in joined(part[1]):
			laid.append(piece)
			laid_want.append(int(part[0]))
	if laid.is_empty():
		return {}
	var cells: Array = []
	var want: Array = []
	var source := PackedInt32Array()
	for c in laid.size():
		var left: Array = [laid[c]]
		for d in range(c + 1, laid.size()):
			var next: Array = []
			for piece: PackedVector2Array in left:
				next.append_array(_outer(Geometry2D.clip_polygons(piece, laid[d])))
			left = next
		if left.size() <= 1:
			left = [laid[c]]
		else:
			# a sliver goes to the first later chunk it touches (the cut's
			# own), which takes it into its polygon; one that touches none
			# stands
			var kept: Array = []
			for piece: PackedVector2Array in left:
				var taken := false
				if area(piece) < SLIVER:
					for d in range(c + 1, laid.size()):
						var both: Array = _outer(Geometry2D.merge_polygons(piece, laid[d]))
						if both.size() == 1:
							laid[d] = both[0]
							taken = true
							break
				if not taken:
					kept.append(piece)
			left = kept if not kept.is_empty() else [laid[c]]
		for piece: PackedVector2Array in left:
			cells.append(piece)
			want.append(laid_want[c])
			source.append(c)
	var whole := joined(cells)
	var outline: PackedVector2Array = whole[0]
	for piece: PackedVector2Array in whole:
		if area(piece) > area(outline):
			outline = piece
	var rims: Array = _outer(Geometry2D.offset_polygon(outline, RIM, Geometry2D.JOIN_ROUND))
	var seams: Array = []
	for c in cells.size():
		var loop: PackedVector2Array = cells[c].duplicate()
		loop.append(loop[0])
		var shown: Array = [loop]
		for d in range(c + 1, cells.size()):
			var left: Array = []
			for line: PackedVector2Array in shown:
				left.append_array(Geometry2D.clip_polyline_with_polygon(line, cells[d]))
			shown = left
		seams.append_array(shown)
	return {"id": id, "seams": seams, "outline": outline, "rim": rims[0] if not rims.is_empty() else outline, "pieces": whole.size(),
		"cells": cells, "want": want, "laid": laid.size(), "source": source, "pots": [], "mixed": -1}

## The chunk of a jelly a point belongs to: the last that holds it, -1
## the tray.
static func cell_at(m: Dictionary, p: Vector2) -> int:
	var cells: Array = m.cells
	for c in range(cells.size() - 1, -1, -1):
		if Geometry2D.is_point_in_polygon(p, cells[c]):
			return c
	return -1

## The flavours a jelly is wanted in, each once, in the flavours' order.
static func flavours(m: Dictionary) -> Array:
	var out: Array = []
	for f: int in m.want:
		if not out.has(f):
			out.append(f)
	out.sort()
	return out

## A band's jellies for a day, easiest first: distinct pictures from the
## band's rows, each with its pots stood by the band's rule. The day's
## themed jellies (core/themed_pictures.gd `jellies`, built) come first, in
## the theme's order, and take as many of the band's places as they fill;
## a picture of the same name as one of them is not drawn beside it.
static func day(band: int, rng: RandomNumberGenerator, themed: Array = []) -> Array:
	var spec: Dictionary = BANDS[clampi(band, 0, BANDS.size() - 1)]
	var names: Array = themed.map(func(m: Dictionary) -> String: return String(m.id))
	var rows: Array = []
	for r in range(int(spec.rows[0]), int(spec.rows[1]) + 1):
		if not names.has("themed_" + String(PICTURES[r])):
			rows.append(r)
	var picked: Array = []
	var first: Array = []
	for m: Dictionary in themed.slice(0, int(spec.moulds)):
		dress(m, int(spec.stood), rng)
		first.append(m)
	while first.size() + picked.size() < int(spec.moulds) and not rows.is_empty():
		var r: int = rows[rng.randi_range(0, rows.size() - 1)]
		rows.erase(r)
		picked.append(r)
	picked.sort()
	var out: Array = first
	for r: int in picked:
		var m := build(PICTURES[r])
		dress(m, int(spec.stood), rng)
		out.append(m)
	return out

## Stands a built jelly's pots by it, as `stood` says: every flavour it
## is wanted in; or one of its mixed flavours left out and the two
## pigments beside it stood instead; or the three pigments and no more.
static func dress(m: Dictionary, stood: int, rng: RandomNumberGenerator) -> void:
	var has := flavours(m)
	var pots: Array = has.duplicate()
	var mixed := -1
	if stood == Stood.THREE_POTS:
		pots = PRIMARIES.duplicate()
	elif stood == Stood.ONE_MIXED:
		var odd: Array = has.filter(func(f: int) -> bool: return f % 2 == 1)
		if not odd.is_empty():
			mixed = odd[rng.randi_range(0, odd.size() - 1)]
			pots.erase(mixed)
			for f: int in [(mixed + 5) % 6, (mixed + 1) % 6]:
				if not pots.has(f):
					pots.append(f)
			pots.sort()
	m.pots = pots
	m.mixed = mixed

## The pots a flavour is made from, of those stood by the tray, and how
## much of each: itself, or the two pigments beside it half and half.
static func recipe(flavour: int, pots: Array) -> Dictionary:
	if pots.has(flavour):
		return {flavour: 1.0}
	return {(flavour + 5) % 6: 0.5, (flavour + 1) % 6: 0.5}

# --- a themed jelly ---

## Parts as the night writes them ([{flavour, shapes: [{kind, n}]}],
## server/functions/src/jelly.ts) in `parts()`'s shape, or [] when any of
## it is not a part, a flavour or a shape.
static func from_doc(doc) -> Array:
	if not doc is Array or (doc as Array).is_empty() or (doc as Array).size() > 8:
		return []
	var names: Array = Flavour.keys().map(func(k: String) -> String: return k.to_lower())
	var out: Array = []
	for part in doc:
		if not part is Dictionary or not part.get("shapes") is Array:
			return []
		var f := names.find(String(part.get("flavour", "")))
		var list: Array = part.shapes
		if f < 0 or list.is_empty() or list.size() > 8:
			return []
		var shapes: Array = []
		for sh in list:
			if not sh is Dictionary or not sh.get("n") is Array:
				return []
			var n: Array = sh.n
			if not n.all(func(v) -> bool: return (v is float or v is int) and is_finite(float(v))):
				return []
			match String(sh.get("kind", "")):
				"ell":
					if n.size() < 4 or n.size() > 5 or n[2] < 2 or n[3] < 2:
						return []
					shapes.append(ell(n[0], n[1], n[2], n[3], n[4] if n.size() > 4 else 0.0))
				"box":
					if n.size() < 4 or n.size() > 5 or n[2] < 2 or n[3] < 2:
						return []
					shapes.append(box(n[0], n[1], n[2], n[3], n[4] if n.size() > 4 else 0.0))
				"soft", "sharp":
					if n.size() < 6 or n.size() > 32 or n.size() % 2 == 1:
						return []
					shapes.append(soft(n, 2 if sh.kind == "soft" else 1))
				_:
					return []
		out.append([f, shapes])
	return out

## Whether a built themed jelly keeps its band's row of THEMED; "" when it
## does, else what it breaks (the probe prints it).
static func unfit(m: Dictionary, band: int) -> String:
	if m.is_empty():
		return "nothing built"
	var rule: Dictionary = THEMED[clampi(band, 0, THEMED.size() - 1)]
	for c: PackedVector2Array in m.cells:
		for q: Vector2 in c:
			if q.x < EDGE[0] or q.y < EDGE[0] or q.x > EDGE[1] or q.y > EDGE[1]:
				return "off the field"
	var has := flavours(m)
	if has.size() < int(rule.flavours[0]) or has.size() > int(rule.flavours[1]):
		return "%d flavours" % has.size()
	if has.filter(func(f: int) -> bool: return f % 2 == 1).size() < int(rule.mixed):
		return "too few mixed flavours"
	# the chunks and their size as the night counts them (a part's pieces,
	# before a later one cuts them), so a jelly the night kept is kept here
	var n: int = int(m.laid)
	if n < int(rule.chunks[0]) or n > int(rule.chunks[1]):
		return "%d chunks" % n
	if (m.cells as Array).size() > CELLS_TOP:
		return "%d cells" % (m.cells as Array).size()
	if int(m.pieces) != 1:
		return "%d pieces" % int(m.pieces)
	var shows := PackedInt32Array()
	shows.resize(n)
	var covered := 0
	for i in GRID * GRID:
		var c := cell_at(m, Vector2((i % GRID) + 0.5, (i / GRID) + 0.5) * (SIDE / GRID))
		if c >= 0:
			shows[m.source[c]] += 1
			covered += 1
	for k in shows:
		if k < LEAST_SQUARES:
			return "a chunk too small"
	var share := float(covered) / float(GRID * GRID)
	if share < float(COVER[0]) or share > float(COVER[1]):
		return "covers %d%%" % roundi(share * 100.0)
	return ""
