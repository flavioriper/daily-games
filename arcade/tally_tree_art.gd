extends RefCounted

## The upgrades tree's drawings (arcade/tally_shop.gd lays them): squared
## paper with the trunk and six boughs on it, one mesh, and a track's plate,
## one mesh a state. Everything is built in the tree's own pixels about the
## counting box's middle (y up negative) and in Tally's materials
## (arcade/tally_art.gd): the paper's rule, pencil for what is not yet open,
## ink for what is, brass for a rank's chip, the box at the root.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Icons = preload("res://ui/icons.gd")
const Pal = preload("res://core/palette.gd")

const PLATE := 128.0
const PLATE_R := 28.0
## The ring of asks lies RING_GAP off the plate; the chosen mark inside it.
const RING_GAP := 11.0
const RING_W := 5.0
## The picture's room on a plate.
const PIC := 84.0
## The rank's chip on the top-right corner, and where the sun dot or the
## crown go, top-left.
const CHIP_H := 32.0
const CHIP_FS := 21
const CORNER := Vector2(PLATE * 0.5 - 8.0, -PLATE * 0.5 + 8.0)
## The "Lv n" tag under a plate that is not open yet: its middle's y.
const TAG_Y := PLATE * 0.5 + 30.0
const TAG_FS := 24
## The paper's squares.
const SQUARE := 40.0
## The box at the root: Sim.HUB squares of Art.U, drawn small.
const ROOT_S := 0.3
const ROOT_HALF := Sim.HUB * Art.U * ROOT_S * 0.5
## The trunk and the boughs: a joint's radius, the ink's width, the pencil's,
## a dash and the gap after it.
const JOINT := 9.0
const INK_W := 7.0
const PENCIL_W := 4.5
const DASH := 14.0
const GAP := 9.0

const MET := Color("4f8f45")
const UNMET := Color("d9ceb5")
const PLATE_SHADE := Color(0.35, 0.23, 0.12, 0.14)
const LOCKED_FILL := Color("efe7d6")

static var _plates := {}
static var _mark: ArrayMesh

## Where a track's plate stands, in cells: x -1 or 1, y the row from the root.
static func cell(id: String) -> Vector2i:
	match id:
		"belt":
			return Vector2i(-1, 1)
		"dig":
			return Vector2i(1, 1)
		"add":
			return Vector2i(-1, 2)
		"mul":
			return Vector2i(1, 3)
		"sub":
			return Vector2i(-1, 4)
	return Vector2i(1, 5)

## A row's y: the first clears the box by `gap`, each next `cell_y` higher.
static func row_y(row: int, gap: float, cell_y: float) -> float:
	return -gap - (row - 1) * cell_y

static func spot(id: String, cell_x: float, gap: float, cell_y: float) -> Vector2:
	var c := cell(id)
	return Vector2(c.x * cell_x, row_y(c.y, gap, cell_y))

## The paper, the box and the tree, one mesh in the tree's pixels: the
## squares ruled over `cover` (y from and to), the margin line, the box at
## the root, the trunk in ink up to the highest open row and in dashed
## pencil on, a bough to each plate, in ink once its track is open. `open`
## is the tracks open, by id.
static func back(width: float, cover: Vector2, cell_x: float, gap: float, cell_y: float, open: Dictionary) -> ArrayMesh:
	var b := Face.Builder.new()
	var w := width * 0.5 + 4.0
	b.polygon(PackedVector2Array([Vector2(-w, cover.x), Vector2(w, cover.x), Vector2(w, cover.y), Vector2(-w, cover.y)]), Art.PAPER)
	# the rule: a line every square, a firmer one every fifth, from the middle out
	var k := 0
	var x := 0.0
	while x <= w:
		var col := Art.GRID_FIVE if k % 5 == 0 else Art.GRID
		_rule(b, Vector2(x, cover.x), Vector2(x, cover.y), col)
		if x > 0.0:
			_rule(b, Vector2(-x, cover.x), Vector2(-x, cover.y), col)
		x += SQUARE
		k += 1
	k = 0
	var y := 0.0
	while y <= maxf(absf(cover.x), absf(cover.y)):
		var col := Art.GRID_FIVE if k % 5 == 0 else Art.GRID
		if y <= absf(cover.y):
			_rule(b, Vector2(-w, y), Vector2(w, y), col)
		if y > 0.0 and y <= absf(cover.x):
			_rule(b, Vector2(-w, -y), Vector2(w, -y), col)
		y += SQUARE
		k += 1
	_rule(b, Vector2(-w + 58.0, cover.x), Vector2(-w + 58.0, cover.y), Art.MARGIN_LINE)
	# the trunk: ink to the highest open row, pencil on to the fifth
	var highest := 1
	for id: String in Sim.TRACKS:
		if open.get(id, false):
			highest = maxi(highest, cell(id).y)
	var foot := Vector2(0.0, -ROOT_HALF + 6.0)
	var ink_to := Vector2(0.0, row_y(highest, gap, cell_y))
	b.stroke(PackedVector2Array([foot, ink_to]), INK_W, Art.INK)
	if highest < 5:
		_dashed(b, PackedVector2Array([ink_to, Vector2(0.0, row_y(5, gap, cell_y))]), PENCIL_W, Art.PENCIL)
	# the boughs, each from a round joint on the trunk out to its plate
	for id: String in Sim.TRACKS:
		var c := cell(id)
		var at := spot(id, cell_x, gap, cell_y)
		var joint := Vector2(0.0, at.y + 26.0)
		var to := at + Vector2(-c.x * (PLATE * 0.5 + RING_GAP + 6.0), 0.0)
		var path := Face.Builder.bezier2(joint, Vector2(to.x * 0.45, at.y + 22.0), to, 16)
		path.append(to)
		var on: bool = open.get(id, false)
		if on:
			b.stroke(path, INK_W, Art.INK)
			b.disc(joint, JOINT, Art.INK)
		else:
			_dashed(b, path, PENCIL_W, Art.PENCIL)
			b.disc(joint, JOINT, Art.PENCIL)
			b.disc(joint, JOINT - PENCIL_W, Art.PAPER)
	# the box at the root, drawn from its corner
	append(b, Art.box(), Transform2D(0.0, Vector2.ONE * ROOT_S, 0.0, Vector2.ONE * -ROOT_HALF))
	return b.mesh()

## A line of the rule, two pixels wide, as two triangles.
static func _rule(b: Face.Builder, a: Vector2, c: Vector2, col: Color) -> void:
	var d := (c - a).normalized()
	var n := Vector2(-d.y, d.x) * 1.0
	var v0 := b.vertex(a + n, col)
	var v1 := b.vertex(c + n, col)
	var v2 := b.vertex(c - n, col)
	var v3 := b.vertex(a - n, col)
	b.tri(v0, v1, v2)
	b.tri(v0, v2, v3)

## A pencil line in dashes along `pts`.
static func _dashed(b: Face.Builder, pts: PackedVector2Array, w: float, col: Color) -> void:
	var total := _length(pts)
	var s := 0.0
	while s < total:
		var e := minf(total, s + DASH)
		b.stroke(slice(pts, s / total, e / total), w, col)
		s += DASH + GAP

static func _length(pts: PackedVector2Array) -> float:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	return total

## The part of the polyline `pts` from `t0` to `t1` of its length.
static func slice(pts: PackedVector2Array, t0: float, t1: float) -> PackedVector2Array:
	var total := _length(pts)
	var from := t0 * total
	var to := t1 * total
	var out := PackedVector2Array()
	var run := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if seg <= 0.0:
			continue
		var a := run
		var e := run + seg
		if e >= from and a <= to:
			var ta := clampf((from - a) / seg, 0.0, 1.0)
			var tb := clampf((to - a) / seg, 0.0, 1.0)
			if out.is_empty():
				out.append(pts[i].lerp(pts[i + 1], ta))
			out.append(pts[i].lerp(pts[i + 1], tb))
		run = e
	return out

## The ring's path round a plate, closed, starting at the top's middle and
## running clockwise, so the first segment is the first number asked.
static func ring_path() -> PackedVector2Array:
	var h := PLATE * 0.5 + RING_GAP
	var rr := Face.Builder.round_rect(Vector2(-h, -h), Vector2.ONE * h * 2.0, PLATE_R + RING_GAP)
	# round_rect starts on the top-right corner's arc: turn it to start at the top's middle
	var out := PackedVector2Array([Vector2(0.0, -h)])
	out.append_array(rr)
	out.append(Vector2(0.0, -h))
	return out

## A track's plate, one mesh a state: lifted paper, its piece on it, the
## rank's brass chip top-right (`chip_w` wide, its text drawn after), the
## ring of the next rank's asks in `n` segments with `met` of them green, the
## sun dot when the rank can be bought, a crown at the top; not open, a dim
## plate with a lock and no chip. `chosen` adds the ink mark.
static func plate(kind: int, open: bool, top: bool, can: bool, n: int, met: Array, chip_w: float, chosen: bool) -> ArrayMesh:
	var key := "%d|%d%d%d|%d|%s|%d|%d" % [kind, int(open), int(top), int(can), n, str(met), int(chip_w), int(chosen)]
	if _plates.has(key):
		return _plates[key]
	var b := Face.Builder.new()
	var h := PLATE * 0.5
	var box := func(grow: float, down := 0.0) -> PackedVector2Array:
		return Face.Builder.round_rect(Vector2(-h - grow, -h - grow + down), Vector2.ONE * (PLATE + grow * 2.0), PLATE_R + grow)
	if open:
		b.polygon(box.call(3.0, 8.0), Color(PLATE_SHADE, 0.08))
		b.polygon(box.call(0.0, 6.0), PLATE_SHADE)
		b.polygon(box.call(0.0), Pal.SURFACE)
	else:
		b.polygon(box.call(0.0), LOCKED_FILL)
		b.stroke(box.call(0.0), 2.0, Art.PENCIL_SHUT, true)
	if chosen:
		b.stroke(box.call(0.0), 4.0, Art.INK, true)
	# the piece, fitted to the plate
	var mesh := Art.icon(kind)
	var bounds := mesh.get_aabb()
	var fit := minf(1.0, PIC / maxf(1.0, maxf(bounds.size.x, bounds.size.y)))
	var mid := Vector2(bounds.get_center().x, bounds.get_center().y)
	append(b, mesh, Transform2D(0.0, Vector2(fit, fit), 0.0, -mid * fit), Color.WHITE if open else Color(1, 1, 1, 0.3))
	if not open:
		Art.lock_into(b, Vector2(0.0, 2.0), 26.0, Art.PENCIL)
	# the ring of asks: one segment a number, a gap between
	if open and not top and n > 0:
		var path := ring_path()
		var gap := 10.0 / _length(path)
		for i in n:
			var t0 := float(i) / n + (gap * 0.5 if n > 1 else 0.0)
			var t1 := float(i + 1) / n - (gap * 0.5 if n > 1 else 0.0)
			var seg := path.slice(0, path.size() - 1) if n == 1 else slice(path, t0, t1)
			var done: bool = i < met.size() and bool(met[i])
			b.stroke(seg, RING_W, MET if done else UNMET, n == 1, n > 1)
	# the chip, the sun dot, the crown
	if open:
		var chip_at := CORNER + Vector2(-chip_w * 0.5, 0.0)
		b.polygon(Face.Builder.round_rect(chip_at - Vector2(0.0, CHIP_H * 0.5) + Vector2(0.0, 3.0), Vector2(chip_w, CHIP_H), CHIP_H * 0.5), Art.BRASS.darkened(0.3))
		b.polygon(Face.Builder.round_rect(chip_at - Vector2(0.0, CHIP_H * 0.5), Vector2(chip_w, CHIP_H), CHIP_H * 0.5), Art.BRASS)
		var corner := Vector2(-CORNER.x, CORNER.y)
		if top:
			b.disc(corner, 20.0, Pal.SURFACE)
			b.disc(corner, 17.0, Art.BRASS)
			var xf := Transform2D(0.0, Vector2.ONE * 24.0, 0.0, corner - Vector2.ONE * 12.0)
			for poly: PackedVector2Array in Icons.shape("crown").polys:
				b.polygon(xf * poly, Art.INK)
		elif can:
			b.disc(corner, 15.0, Art.CREAM)
			b.disc(corner, 11.0, Pal.SUN)
	_plates[key] = b.mesh()
	return _plates[key]

## Another kept mesh into `b` under `xf`, moving the points whole (the Grove's
## tree had this: Builder.append walks every vertex in script).
static func append(b: Face.Builder, m: ArrayMesh, xf: Transform2D, tint := Color.WHITE) -> void:
	var a := m.surface_get_arrays(0)
	var base := b.verts.size()
	b.verts.append_array(xf * (a[Mesh.ARRAY_VERTEX] as PackedVector2Array))
	var cols: PackedColorArray = a[Mesh.ARRAY_COLOR]
	if tint != Color.WHITE:
		var tinted := PackedColorArray()
		tinted.resize(cols.size())
		for i in cols.size():
			tinted[i] = cols[i] * tint
		cols = tinted
	b.cols.append_array(cols)
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var out := PackedInt32Array()
	out.resize(ix.size())
	for i in ix.size():
		out[i] = base + ix[i]
	b.idx.append_array(out)

## What lies over the tree, in the field's pixels: the card's paper on the
## field's four corners so it is rounded as the card is, a hairline round it,
## and a little shade under its top and over its foot.
static func frame(view: Vector2, r: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var ink := Color(0.3, 0.2, 0.1)
	for edge: Array in [[0.0, 22.0], [view.y, -22.0]]:
		var v0 := b.vertex(Vector2(0.0, edge[0]), Color(ink, 0.08))
		var v1 := b.vertex(Vector2(view.x, edge[0]), Color(ink, 0.08))
		var v2 := b.vertex(Vector2(view.x, float(edge[0]) + float(edge[1])), Color(ink, 0.0))
		var v3 := b.vertex(Vector2(0.0, float(edge[0]) + float(edge[1])), Color(ink, 0.0))
		b.tri(v0, v1, v2)
		b.tri(v0, v2, v3)
	for corner: Array in [[Vector2.ZERO, Vector2(r, r), PI], [Vector2(view.x, 0.0), Vector2(view.x - r, r), PI * 1.5],
			[view, view - Vector2(r, r), 0.0], [Vector2(0.0, view.y), Vector2(r, view.y - r), PI * 0.5]]:
		var pts := PackedVector2Array([corner[0]])
		pts.append_array(Face.Builder.arc_points(corner[1], r, corner[2], float(corner[2]) + PI * 0.5))
		b.polygon(pts, Pal.PAPER)
	b.stroke(Face.Builder.round_rect(Vector2(1.0, 1.0), view - Vector2(2.0, 2.0), r - 1.0), 2.0, Color(Pal.LINE, 0.55), true)
	return b.mesh()
