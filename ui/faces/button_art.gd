extends RefCounted

## Button Box's drawings: the linen the table is laid with, a dyed patch of
## cloth, the button that sits on it (loose, or sewn on with a cross of
## thread), and the tin. Builder shapes and not Controls, as Quilt's cloth
## and Lattice's tiles are: the board bakes its buttons into meshes (a
## thousand of them on Insane's 32-square picture), and the menu card and
## the tutorial draw the same pieces. A big picture's are `button_lite`:
## plain while a square is under SMALL across (its holes would be a pixel,
## and its cross of thread has to stay a shape), and with their holes once
## the picture is seen close -- both a third of the vertices of `button`,
## whose every disc is feathered and round to three pixels.
##
## A button is coloured by index, so nothing about it is said by a shade of
## its colour: loose is a round button with a shadow on a patch of another
## colour, a bare patch is a small washed square with linen round it, and
## sewn is the whole square in the colour, edge to edge, so the sewn ones
## run together into the picture (`sewn`; the user, 2026-10-11: "it's hard
## to see when button is on right place, can we make the button blend to
## the ground and become just the color?"). The cross of thread `button`
## and `button_lite` can still draw is no longer asked for.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Sizes as a share of the cell.
const PATCH := 0.94
const PATCH_RADIUS := 0.14
## The button is two thirds of its square across (0.8 until 2026-10-12; the
## user: "the buttons are too big, let's make it bit smaller so user can see
## better the color below it"). RIM stays over `_seat`'s 0.3: the ring is
## what says bare, and a button must hide it.
const RIM := 0.335
const FACE_R := 0.3
const DISH := 0.2
const HOLE := 0.038
const HOLE_AT := 0.071
const RISE := 0.03
const LINEN := Color("e9dcc3")
const LINEN_WARP := Color("dfd0b3")
const LINEN_WEFT := Color("f1e6d0")
const THREAD := Color("fbf7ee")
const THREAD_DARK := Color("4a3226")
const WEAVE := 16.0
## Under this a cell the plain button is drawn. The looks `units` builds.
const SMALL := 44.0
enum { FULL, PLAIN, CLOSE }

static func colour(named: String) -> Color:
	return Pal.PG_BEADS.get(named, Pal.LINE)

## The cloth a patch is cut from: the button's colour, washed out.
static func dyed(col: Color) -> Color:
	return col.lerp(LINEN, 0.42)

## The thread a button of `col` is sewn on with: pale, or dark on a pale one.
static func thread_for(col: Color) -> Color:
	return THREAD_DARK if col.get_luminance() > 0.72 else THREAD

## The table's linen over `size`: one flat cloth with the weave drawn in.
static func linen(b, size: Vector2) -> void:
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]), LINEN)
	var y := WEAVE * 0.5
	while y < size.y:
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 1.5, LINEN_WARP, false, false)
		y += WEAVE
	var x := WEAVE * 0.5
	while x < size.x:
		b.stroke(PackedVector2Array([Vector2(x, 0.0), Vector2(x, size.y)]), 1.5, LINEN_WEFT, false, false)
		x += WEAVE

## A running stitch round `rect`, a dash every `step`.
static func stitches(b, rect: Rect2, step: float, colour_: Color) -> void:
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var z: Vector2 = corners[(k + 1) % 4]
		var n := maxi(1, int(round(a.distance_to(z) / step)))
		for i in n:
			var p := a.lerp(z, (i + 0.2) / n)
			var q := a.lerp(z, (i + 0.8) / n)
			b.stroke(PackedVector2Array([p, q]), maxf(2.0, step * 0.16), colour_)

## A patch of dyed cloth centred on `at`. `lite` cuts its corners straight
## and leaves its edge hard: a thousand of them are one mesh.
static func patch(b, at: Vector2, cell: float, col: Color, lite := false) -> void:
	var s := cell * PATCH
	var corner := at - Vector2.ONE * s * 0.5
	if lite:
		_raw(b, _cut(at, s * 0.5, cell * PATCH_RADIUS * 0.6), dyed(col).darkened(0.1))
		_raw(b, _cut(at, s * 0.5 - cell * 0.03, cell * PATCH_RADIUS * 0.5), dyed(col))
		_seat(b, at, cell, col, 12)
		return
	b.fan(Face.Builder.round_rect(corner, Vector2.ONE * s, cell * PATCH_RADIUS), dyed(col).darkened(0.1))
	b.fan(Face.Builder.round_rect(corner + Vector2.ONE * cell * 0.03, Vector2.ONE * (s - cell * 0.06), cell * PATCH_RADIUS * 0.8), dyed(col))
	_seat(b, at, cell, col, 20)

## The mark a button leaves to be sat on: a ring on the patch, hidden under
## any button and seen on a bare one, so that bare and sewn differ by a
## shape on the palest colours too (white cloth washed out is nearly white).
static func _seat(b, at: Vector2, cell: float, col: Color, sides: int) -> void:
	_raw(b, _gon(at, cell * 0.3, sides), dyed(col).darkened(0.16))
	_raw(b, _gon(at, cell * 0.3 - maxf(1.5, cell * 0.045), sides), dyed(col))

## A button sewn on: it has gone into the cloth, and its square is the
## colour whole, a hair over the cell so that neighbours leave no seam.
static func sewn(b, at: Vector2, cell: float, col: Color) -> void:
	var half := cell * 0.5 + 0.4
	_raw(b, PackedVector2Array([at + Vector2(-half, -half), at + Vector2(half, -half),
			at + Vector2(half, half), at + Vector2(-half, half)]), col)

## A button centred on `at`: its rim, its face a little above it, the dish
## and the four holes; `sewn` crosses them with thread.
static func button(b, at: Vector2, cell: float, col: Color, sewn: bool) -> void:
	var up := at - Vector2(0.0, cell * RISE)
	b.disc(at + Vector2(0.0, cell * RISE), cell * RIM, col.darkened(0.3))
	b.disc(up, cell * RIM, col.darkened(0.12))
	b.disc(up, cell * FACE_R, col)
	b.disc(up, cell * DISH, col.darkened(0.1))
	b.disc(up - Vector2(0.0, cell * 0.012), cell * (DISH - 0.025), col.lightened(0.05))
	var d := cell * HOLE_AT
	var ink := col.darkened(0.6)
	for o: Vector2 in [Vector2(-d, -d), Vector2(d, -d), Vector2(d, d), Vector2(-d, d)]:
		b.disc(up + o, cell * HOLE, ink)
	if sewn:
		var thread := thread_for(col)
		var wide := maxf(1.6, cell * 0.05)
		b.stroke(PackedVector2Array([up + Vector2(-d, -d), up + Vector2(d, d)]), wide, thread)
		b.stroke(PackedVector2Array([up + Vector2(d, -d), up + Vector2(-d, d)]), wide, thread)

static func _gon(at: Vector2, r: float, sides: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(sides)
	for i in sides:
		pts[i] = at + Vector2.from_angle(TAU * i / sides) * r
	return pts

## A square of half-side `half` about `at` with its corners cut by `c`.
static func _cut(at: Vector2, half: float, c: float) -> PackedVector2Array:
	var a := half - c
	return PackedVector2Array([at + Vector2(-a, -half), at + Vector2(a, -half), at + Vector2(half, -a),
		at + Vector2(half, a), at + Vector2(a, half), at + Vector2(-a, half), at + Vector2(-half, a), at + Vector2(-half, -a)])

## A convex outline as a fan with no feather: for what lies inside another
## shape, or is small, where the feather is two triangles a side unseen.
static func _raw(b, points: PackedVector2Array, col: Color) -> void:
	var first: int = b.verts.size()
	for p in points:
		b.verts.append(p)
		b.cols.append(col)
	for i in range(1, points.size() - 1):
		b.idx.append(first)
		b.idx.append(first + i)
		b.idx.append(first + i + 1)

## The button of a big picture. Seen whole (20 to 40 px across) it is a rim,
## a face and a dish and no holes, and `sewn` is a bold cross of thread from
## edge to edge of the dish, which reads at that size where four holes do
## not. `close` (the picture zoomed) is the whole button, holes and all, cut
## in polygons with only its outline feathered.
static func button_lite(b, at: Vector2, cell: float, col: Color, sewn: bool, close: bool) -> void:
	var up := at - Vector2(0.0, cell * RISE)
	var sides := 22 if close else 14
	_raw(b, _gon(at + Vector2(0.0, cell * RISE), cell * RIM, sides), col.darkened(0.32))
	var thread := thread_for(col)
	if not close:
		b.fan(_gon(up, cell * RIM, sides), col)
		if sewn:
			var d := cell * 0.17
			var wide := maxf(2.6, cell * 0.11)
			b.stroke(PackedVector2Array([up + Vector2(-d, -d), up + Vector2(d, d)]), wide, thread, false, false)
			b.stroke(PackedVector2Array([up + Vector2(d, -d), up + Vector2(-d, d)]), wide, thread, false, false)
		else:
			_raw(b, _gon(up, cell * DISH, 12), col.darkened(0.14))
		return
	b.fan(_gon(up, cell * RIM, sides), col.darkened(0.12))
	_raw(b, _gon(up, cell * FACE_R, sides), col)
	_raw(b, _gon(up, cell * DISH, 16), col.darkened(0.1))
	_raw(b, _gon(up - Vector2(0.0, cell * 0.012), cell * (DISH - 0.025), 16), col.lightened(0.05))
	var d := cell * HOLE_AT
	var ink := col.darkened(0.6)
	for o: Vector2 in [Vector2(-d, -d), Vector2(d, -d), Vector2(d, d), Vector2(-d, d)]:
		_raw(b, _gon(up + o, cell * HOLE, 8), ink)
	if sewn:
		var wide := maxf(1.6, cell * 0.05)
		var e := d * 1.25
		b.stroke(PackedVector2Array([up + Vector2(-e, -e), up + Vector2(e, e)]), wide, thread, false, false)
		b.stroke(PackedVector2Array([up + Vector2(e, -e), up + Vector2(-e, e)]), wide, thread, false, false)

## The pieces drawn many times over, each once about the origin at `cell`:
## {shade, ring, loose: [a colour], sewn: [a colour]}. `look` is FULL, or
## a big picture's PLAIN and CLOSE.
static func units(cell: float, colours: Array, look := FULL) -> Dictionary:
	var out := {"loose": [], "sewn": []}
	var b := Face.Builder.new()
	if look != FULL:
		_raw(b, _gon(Vector2(0.0, cell * 0.11), cell * 0.36, 12), Color(Pal.TEXT, 0.2))
	else:
		Scenery.soft_disc(b, Vector2(0.0, cell * 0.1), cell * 0.37, cell * 0.12, Color(Pal.TEXT, 0.22))
	out.shade = b.mesh()
	b = Face.Builder.new()
	b.disc(Vector2.ZERO, cell * 0.5, Pal.SUN)
	b.disc(Vector2.ZERO, cell * 0.43, Color(Pal.SUN_TILE, 0.9))
	out.ring = b.mesh()
	for named in colours:
		var col := colour(String(named))
		b = Face.Builder.new()
		if look != FULL:
			button_lite(b, Vector2.ZERO, cell, col, false, look == CLOSE)
		else:
			button(b, Vector2.ZERO, cell, col, false)
		out.loose.append(b.mesh())
		b = Face.Builder.new()
		sewn(b, Vector2.ZERO, cell, col)
		out.sewn.append(b.mesh())
	return out

## The tin: a shallow wooden tray over `rect` with `places` hollows in rows
## of `per_row`, the first `open` of them worn smooth and the rest only
## marked out in stitches of chalk.
static func tin(b, rect: Rect2, places: int, open: int, per_row: int, step: float) -> void:
	var r := step * 0.34
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 6.0), rect.size, r), Pal.PLAQUE_DEEP)
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Pal.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(rect.position + Vector2.ONE * 5.0, rect.size - Vector2.ONE * 10.0, r * 0.8), Pal.WOOD)
	for p in places:
		var at := tin_place(rect, p, per_row, step, places)
		if p < open:
			b.disc(at + Vector2(0.0, 2.0), step * 0.4, Pal.WOOD.lightened(0.18))
			b.disc(at, step * 0.4, Pal.WOOD_DEEP)
			b.disc(at + Vector2(0.0, 2.0), step * 0.37, Pal.WOOD_DEEP.darkened(0.12))
		else:
			b.stroke(Face.Builder.ring(at, step * 0.33, step * 0.33), 2.0, Color(Pal.WOOD_DEEP, 0.55), true)

## The middle of place `p` of a tin over `rect`.
static func tin_place(rect: Rect2, p: int, per_row: int, step: float, places := 12) -> Vector2:
	var rows := ceili(float(places) / per_row)
	var origin := rect.get_center() - Vector2(per_row * step, rows * step) * 0.5
	# a short last row stands in the middle
	var short := rows * per_row - places if p / per_row == rows - 1 else 0
	return origin + Vector2((p % per_row) + 0.5 + short * 0.5, (p / per_row) + 0.5) * step
