extends RefCounted

## A Gumdrop mould as pure data (spec
## docs/superpowers/specs/2026-10-10-arcade-gumdrop-design.md): an outline
## cut into cells by walls, and the flavour each cell is wanted in. The sim
## (arcade/gumdrop_sim.gd) lays its grid over it and the art
## (arcade/gumdrop_art.gd) draws it, both from the same polygons.
##
## Everything is in mould units: a field SIDE by SIDE, y down, the mould
## about its middle. An outline is one closed curve seen whole from a point
## inside it (`mid`), so it can be cut three ways with no drawing by hand:
## into sectors about that point, into a core and sectors round it, or into
## bands straight across.

enum Shape { ROUND, EGG, HEART, DROP, FLOWER5, FLOWER6, CLOVER, STAR }
enum Cut { SECTORS, CORE, BANDS }
## The six flavours. The even ones are the three pigments themselves, the
## odd ones the two beside them half and half.
enum Flavour { CHERRY, ORANGE, LEMON, LIME, BLUEBERRY, GRAPE }

const SIDE := 100.0
## A wall's width, and the rim's beyond the outline.
const WALL := 5.0
const RIM := 2.6
## The core's reach, as a part of the outline's.
const CORE_PART := 0.44
## Each flavour as red, yellow and blue pigment, summing to one.
const PIGMENT := [Vector3(1, 0, 0), Vector3(0.5, 0.5, 0), Vector3(0, 1, 0), Vector3(0, 0.5, 0.5), Vector3(0, 0, 1), Vector3(0.5, 0, 0.5)]

## The moulds, easiest first: each row is a shape, a cut and how many cells
## the cut makes (a core is one more). A level draws from the rows about it
## (`pick`).
const DESIGNS := [
	[Shape.ROUND, Cut.SECTORS, 2], [Shape.EGG, Cut.BANDS, 2], [Shape.HEART, Cut.SECTORS, 2],
	[Shape.ROUND, Cut.SECTORS, 3], [Shape.EGG, Cut.BANDS, 3], [Shape.DROP, Cut.BANDS, 3],
	[Shape.ROUND, Cut.SECTORS, 4], [Shape.CLOVER, Cut.SECTORS, 4], [Shape.ROUND, Cut.CORE, 2],
	[Shape.FLOWER5, Cut.SECTORS, 5], [Shape.HEART, Cut.BANDS, 3], [Shape.ROUND, Cut.CORE, 3],
	[Shape.STAR, Cut.SECTORS, 5], [Shape.EGG, Cut.BANDS, 4], [Shape.CLOVER, Cut.CORE, 4],
	[Shape.FLOWER6, Cut.SECTORS, 6], [Shape.ROUND, Cut.CORE, 4], [Shape.ROUND, Cut.SECTORS, 6],
	[Shape.FLOWER5, Cut.CORE, 5], [Shape.STAR, Cut.CORE, 5], [Shape.EGG, Cut.BANDS, 5],
	[Shape.FLOWER6, Cut.CORE, 6], [Shape.ROUND, Cut.CORE, 6], [Shape.ROUND, Cut.SECTORS, 8],
]
## How many rows a level may draw from, and how far the first of them moves
## on with each level.
const SPREAD := 3
const ADVANCE := 1.4

## The outline's points, the point it is cut about, and the angle its first
## wall leaves that point at.
static func outline(shape: int) -> Dictionary:
	var pts := PackedVector2Array()
	var mid := Vector2(SIDE, SIDE) * 0.5
	var first := -PI * 0.5
	var n := 120
	for i in n:
		var a := TAU * i / n
		var p := Vector2.ZERO
		match shape:
			Shape.ROUND:
				p = Vector2.from_angle(a) * 40.0
			Shape.EGG:
				p = Vector2(33.0 * cos(a) * (1.0 + 0.16 * sin(a)), 42.0 * sin(a))
			Shape.HEART:
				p = Vector2(16.0 * pow(sin(a), 3.0), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * 2.45 + Vector2(0, -6.0)
			Shape.DROP:
				p = Vector2(46.0 * sin(a) * sin(a * 0.5), -41.0 * cos(a))
			Shape.FLOWER5:
				p = Vector2.from_angle(a) * (34.0 + 7.5 * cos(5.0 * (a + PI * 0.5)))
			Shape.FLOWER6:
				p = Vector2.from_angle(a) * (35.0 + 6.5 * cos(6.0 * (a + PI * 0.5)))
			Shape.CLOVER:
				p = Vector2.from_angle(a) * (32.0 + 10.0 * cos(4.0 * (a + PI * 0.5)))
			Shape.STAR:
				p = Vector2.from_angle(a) * (25.0 + 17.0 * pow(0.5 + 0.5 * cos(5.0 * (a + PI * 0.5)), 1.4))
		pts.append(mid + p)
	match shape:
		Shape.HEART:
			mid += Vector2(0, 4.0)
		Shape.DROP:
			mid += Vector2(0, 9.0)
		# a petal or a point each: the walls leave by the dips between
		Shape.FLOWER5, Shape.STAR:
			first += PI / 5.0
		Shape.FLOWER6:
			first += PI / 6.0
		Shape.CLOVER:
			first += PI / 4.0
	return {"points": _ccw(pts), "mid": mid, "first": first}

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

## How far the outline lies from `mid` along each of `steps` directions.
static func _reach(points: PackedVector2Array, mid: Vector2, steps: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(steps)
	for k in steps:
		var d := Vector2.from_angle(TAU * k / steps)
		var far := 0.0
		for i in points.size():
			var hit = Geometry2D.segment_intersects_segment(mid, mid + d * SIDE * 2.0, points[i], points[(i + 1) % points.size()])
			if hit != null:
				far = maxf(far, (hit as Vector2).distance_to(mid))
		out[k] = far
	return out

## The cells of a mould, before the walls are taken out of them.
static func cut(shape: int, how: int, n: int) -> Array:
	var o := outline(shape)
	var pts: PackedVector2Array = o.points
	var mid: Vector2 = o.mid
	var cells: Array = []
	if how == Cut.BANDS:
		var box := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			box = box.expand(p)
		for k in n:
			var y0 := box.position.y + box.size.y * k / n
			var y1 := box.position.y + box.size.y * (k + 1) / n
			var slab := PackedVector2Array([Vector2(-10, y0), Vector2(SIDE + 10, y0), Vector2(SIDE + 10, y1), Vector2(-10, y1)])
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(pts, _ccw(slab)):
				if not Geometry2D.is_polygon_clockwise(piece):
					cells.append(piece)
		return cells
	var steps := 360
	var reach := _reach(pts, mid, steps)
	var inner := CORE_PART if how == Cut.CORE else 0.0
	var first := int(round(rad_to_deg(float(o.first)))) + 720
	for k in n:
		var a0 := first + steps * k / n
		var a1 := first + steps * (k + 1) / n
		var cell := PackedVector2Array()
		for a in range(a0, a1 + 1, 3):
			cell.append(mid + Vector2.from_angle(deg_to_rad(a)) * reach[a % steps])
		if inner > 0.0:
			for a in range(a1, a0 - 1, -3):
				cell.append(mid + Vector2.from_angle(deg_to_rad(a)) * reach[a % steps] * inner)
		else:
			cell.append(mid)
		cells.append(_ccw(cell))
	if how == Cut.CORE:
		var core := PackedVector2Array()
		for a in range(0, steps, 3):
			core.append(mid + Vector2.from_angle(deg_to_rad(a)) * reach[a] * inner)
		cells.append(_ccw(core))
	return cells

## Which design a level is given.
static func pick(level: int, rng: RandomNumberGenerator) -> Array:
	var from := mini(int((level - 1) * ADVANCE), DESIGNS.size() - SPREAD)
	return DESIGNS[from + rng.randi_range(0, SPREAD - 1)]

## How many flavours a level's mould is wanted in, and whether one of them
## has to be mixed from two pots.
static func flavours_at(level: int) -> int:
	return 2 if level <= 2 else (3 if level <= 6 else 4)

static func mixes_at(level: int) -> bool:
	return level >= 5

## A whole mould for a level: its polygons, each cell's flavour and the
## pots stood by it. A cell the walls leave too little of is not kept, and
## a design that loses one is drawn again.
static func deal(level: int, rng: RandomNumberGenerator) -> Dictionary:
	for attempt in 8:
		var row := pick(level, rng)
		var m := build(row[0], row[1], row[2])
		if m.is_empty():
			continue
		dress(m, level, rng)
		return m
	var plain := build(Shape.ROUND, Cut.SECTORS, 2)
	dress(plain, level, rng)
	return plain

static func build(shape: int, how: int, n: int) -> Dictionary:
	var o := outline(shape)
	var cells := cut(shape, how, n)
	var inner: Array = []
	for cell: PackedVector2Array in cells:
		var best := PackedVector2Array()
		for piece: PackedVector2Array in Geometry2D.offset_polygon(cell, -WALL * 0.5, Geometry2D.JOIN_ROUND):
			if not Geometry2D.is_polygon_clockwise(piece) and area(piece) > area(best):
				best = piece
		if best.size() < 3 or area(best) < 60.0:
			return {}
		inner.append(best)
	var rim: PackedVector2Array = Geometry2D.offset_polygon(o.points, RIM, Geometry2D.JOIN_ROUND)[0]
	return {"shape": shape, "cut": how, "n": n, "outline": o.points, "rim": rim, "mid": o.mid,
		"cells": cells, "inner": inner, "want": [], "pots": []}

## Gives a built mould its flavours and its pots.
static func dress(m: Dictionary, level: int, rng: RandomNumberGenerator) -> void:
	var count: int = m.cells.size()
	var k := mini(flavours_at(level), count)
	var all := [0, 1, 2, 3, 4, 5]
	var chosen: Array = []
	var mixed := -1
	if mixes_at(level) and k >= 3:
		# an odd flavour and the two pigments beside it: it is wanted, and
		# only they are stood by the tray
		mixed = [1, 3, 5][rng.randi_range(0, 2)]
		chosen = [mixed, (mixed + 5) % 6, (mixed + 1) % 6]
		all.erase(chosen[0])
		all.erase(chosen[1])
		all.erase(chosen[2])
	while chosen.size() < k:
		var f: int = all[rng.randi_range(0, all.size() - 1)]
		all.erase(f)
		chosen.append(f)
	var want: Array = []
	var turn := rng.randi_range(0, k - 1)
	var ring: int = count - 1 if int(m.cut) == Cut.CORE else count
	for i in count:
		if i >= ring:
			# the core is the mixed one when there is one, else its own
			want.append(chosen[0] if mixed >= 0 else chosen[(turn + ring) % k])
		else:
			want.append(chosen[(turn + i) % k])
	# every chosen flavour is somewhere in the mould
	for j in k:
		if not want.has(chosen[j]):
			want[j % count] = chosen[j]
	var pots: Array = []
	for f: int in chosen:
		if f != mixed:
			pots.append(f)
	pots.sort()
	m.want = want
	m.pots = pots
	m.mixed = mixed

## The pots a flavour is made from, of those stood by the tray, and how
## much of each: itself, or the two pigments beside it half and half.
static func recipe(flavour: int, pots: Array) -> Dictionary:
	if pots.has(flavour):
		return {flavour: 1.0}
	return {(flavour + 5) % 6: 0.5, (flavour + 1) % 6: 0.5}
