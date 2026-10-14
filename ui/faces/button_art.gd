extends RefCounted

## Button Box's drawings: the linen the table is laid with, a patch of cloth
## in a button's colour with a socket in it, the button that sits on it
## (loose, or sewn on with a cross of thread), and the tin. Builder shapes
## and not Controls, as Quilt's cloth and Lattice's tiles are: the board
## bakes its buttons into meshes (a thousand of them on Insane's 32-square
## picture), and the menu card and the tutorial draw the same pieces. A big
## picture's are `button_lite`: plain while a square is under SMALL across
## (its holes would be a pixel, and its cross of thread has to stay a
## shape), and with their holes once the picture is seen close -- both a
## third of the vertices of `button`, whose every disc is feathered and
## round to three pixels.
##
## A patch is its whole square in the button's own colour, edge to edge, so
## that the patches of one colour join into one flat area and the picture
## reads as the picture from afar (the user, 2026-10-14: "join the same
## color slots to make it look more like a image ... make sure the slot has
## the same color of the respective button"; until then a patch was a
## rounded square a gap from its neighbour, washed 0.42 toward the linen).
## A button is coloured by index, so nothing about it is said by a shade of
## its colour alone: a bare patch has a socket in its middle (`socket`, a
## ring the button goes into), loose is a round button with a shadow,
## smaller than its square so the patch shows round it, and sewn is the
## square filled whole (`sewn`; the user, 2026-10-11: "can we make the
## button blend to the ground and become just the color?"), the socket gone
## under it. The cross of thread `button` and `button_lite` can still draw
## is no longer asked for.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Sizes as a share of the cell. **A loose button is a gem tile** (since
## 2026-10-14, the user: "make the button in a more diamond shape rather
## than plain rounded so it can fill a bit more of the square, and make it
## bit bigger, to not let user guess so easy what is the picture early",
## then, over a rhombus, a picture of faceted square gems: "a shape like
## this, not a triangle"): a rounded square RIM out from the middle to
## each side, 0.8 of its square across and covering 0.64 of it (the user,
## over 0.92: "smaller, it's too big, keep it like 80% of the cell"; a round
## button 0.56 across, 0.25 of its square, from the morning; two thirds
## before, 0.8 before that), so the patch's colour shows as a thin border
## only. Four bevel facets slope from its edge to a flat centre face FACE
## out, lit from the top; the holes sit in the face. TIP rounds the
## corners. RIM stays over SOCKET: the socket is what says bare, and a
## button must hide it.
const RIM := 0.4
const TIP := 0.1
const FACE := 0.22
const HOLE := 0.032
const HOLE_AT := 0.085
const RISE := 0.03
## The socket's outer radius, and the shadow a loose button throws.
const SOCKET := 0.235
const SHADOW_R := 0.41
const SHADOW_DOWN := 0.06
## The facets' light: the top one lifted, the sides a little, the bottom
## sunk.
const FACET := [0.2, 0.06, -0.06, -0.22]
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

## A patch of cloth centred on `at`: its whole square in `col`, edge to
## edge (a hair over, as `sewn` is, so neighbours of one colour leave no
## seam and join into one area), with the socket its button goes into.
## `lite` cuts the socket in fewer sides: a thousand of them are one mesh.
static func patch(b, at: Vector2, cell: float, col: Color, lite := false) -> void:
	sewn(b, at, cell, col)
	socket(b, at, cell, col, 12 if lite else 20)

## The socket a button sits in: a ring sunk into the patch, hidden under
## any button and seen on a bare one, so that bare and sewn differ by a
## shape and not a shade (a white patch's socket is a grey ring). Its floor
## is set a hair low, so the ring is thicker along the top: a recess, lit
## from above. Readable at 14 px a square: a ring of 3.3 px, 2 px wide.
static func socket(b, at: Vector2, cell: float, col: Color, sides: int) -> void:
	# the button's own shape, as the tin's hollows are (the user,
	# 2026-10-14: "same for the slot of empty cells on the picture")
	var r := cell * SOCKET
	var rim := maxf(2.0, cell * 0.06)
	var tip := cell * TIP * 0.5
	_raw(b, tile(at, r, tip, sides > 12), col.darkened(0.34))
	_raw(b, tile(at + Vector2(0.0, cell * 0.018), r - rim, maxf(1.0, tip - rim * 0.5), sides > 12), col.darkened(0.1))

## A button sewn on: it has gone into the cloth, and its square is the
## colour whole, a hair over the cell so that neighbours leave no seam.
static func sewn(b, at: Vector2, cell: float, col: Color) -> void:
	var half := cell * 0.5 + 0.4
	_raw(b, PackedVector2Array([at + Vector2(-half, -half), at + Vector2(half, -half),
			at + Vector2(half, half), at + Vector2(-half, half)]), col)

## A rounded square about `at`, `r` from its middle to each side, its
## corners rounded by `tip`; `fine` false cuts each corner in two points.
## The cut tile is laid about `at` as the round one is (until 2026-10-14 it
## forgot `at`: a bare patch's socket on a big picture, the one tile built
## in place rather than about the origin, lay at the cloth's corner, and
## every bared patch read as a flat square, "filled"), and its eight points
## run round in one direction (they zigzagged at each corner before, a
## bow-tie the fan still mostly covered).
static func tile(at: Vector2, r: float, tip: float, fine := true) -> PackedVector2Array:
	if fine:
		return Face.Builder.round_rect(at - Vector2(r, r), Vector2(r, r) * 2.0, tip)
	var k := tip * 0.5
	return PackedVector2Array([
		at + Vector2(-r, -r + k), at + Vector2(-r + k, -r),
		at + Vector2(r - k, -r), at + Vector2(r, -r + k),
		at + Vector2(r, r - k), at + Vector2(r - k, r),
		at + Vector2(-r + k, r), at + Vector2(-r, r - k)])

## The gem's four facets between its edge (`r` out, corners in by `tip`)
## and its centre face (`face` out): top, left, right, bottom, each a
## trapezoid in the colour lifted or sunk by FACET.
static func facets(b, at: Vector2, r: float, tip: float, face: float, col: Color) -> void:
	var o := r - tip * 0.55
	var outer := [Vector2(-o, -r), Vector2(o, -r), Vector2(r, -o), Vector2(r, o), Vector2(o, r), Vector2(-o, r), Vector2(-r, o), Vector2(-r, -o)]
	var inner := [Vector2(-face, -face), Vector2(face, -face), Vector2(face, face), Vector2(-face, face)]
	var sides := [[outer[0], outer[1], inner[1], inner[0]], [outer[7], inner[0], inner[3], outer[6]],
		[outer[2], outer[3], inner[2], inner[1]], [outer[5], outer[4], inner[2], inner[3]]]
	var order := [0, 1, 2, 3]
	for k in 4:
		var quad: Array = sides[order[k]]
		var pts := PackedVector2Array()
		for q: Vector2 in quad:
			pts.append(at + q)
		var lift: float = FACET[k]
		_raw(b, pts, col.lightened(lift) if lift >= 0.0 else col.darkened(-lift))

## A button centred on `at`: its rim, its body a little above it, the four
## facets, the centre face, its gloss and the four holes; `sewn` crosses
## them with thread.
static func button(b, at: Vector2, cell: float, col: Color, sewn: bool) -> void:
	var up := at - Vector2(0.0, cell * RISE)
	var r := cell * RIM
	var tip := cell * TIP
	var face := cell * FACE
	b.polygon(tile(at + Vector2(0.0, cell * RISE), r, tip), col.darkened(0.3))
	b.polygon(tile(up, r, tip), col.darkened(0.12))
	facets(b, up, r, tip, face, col)
	_raw(b, tile(up, face, tip * 0.35, false), col)
	# the gloss: a pale sliver along the face's top left
	_raw(b, PackedVector2Array([up + Vector2(-face, -face), up + Vector2(face * 0.2, -face), up + Vector2(-face, face * 0.2)]), Color(1, 1, 1, 0.18))
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

## The button of a big picture. Seen whole (20 to 40 px across) it is the
## tile with its top and bottom facets and no holes, and `sewn` is a bold
## cross of thread, which reads at that size where four holes do not.
## `close` (the picture zoomed) is the whole gem, holes and all, cut in
## polygons with only its outline feathered.
static func button_lite(b, at: Vector2, cell: float, col: Color, sewn: bool, close: bool) -> void:
	var up := at - Vector2(0.0, cell * RISE)
	var r := cell * RIM
	var tip := cell * TIP
	var face := cell * FACE
	_raw(b, tile(at + Vector2(0.0, cell * RISE), r, tip, close), col.darkened(0.32))
	var thread := thread_for(col)
	if not close:
		b.fan(tile(up, r, tip, false), col.darkened(0.12))
		facets(b, up, r, tip, face, col)
		_raw(b, tile(up, face, tip * 0.35, false), col)
		if sewn:
			var d := cell * 0.17
			var wide := maxf(2.6, cell * 0.11)
			b.stroke(PackedVector2Array([up + Vector2(-d, -d), up + Vector2(d, d)]), wide, thread, false, false)
			b.stroke(PackedVector2Array([up + Vector2(d, -d), up + Vector2(-d, d)]), wide, thread, false, false)
		return
	b.fan(tile(up, r, tip), col.darkened(0.12))
	facets(b, up, r, tip, face, col)
	_raw(b, tile(up, face, tip * 0.35, false), col)
	_raw(b, PackedVector2Array([up + Vector2(-face, -face), up + Vector2(face * 0.2, -face), up + Vector2(-face, face * 0.2)]), Color(1, 1, 1, 0.18))
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
		_raw(b, tile(Vector2(0.0, cell * SHADOW_DOWN), cell * (SHADOW_R - 0.01), cell * TIP, false), Color(Pal.TEXT, 0.2))
	else:
		b.polygon(tile(Vector2(0.0, cell * SHADOW_DOWN + 2.0), cell * (SHADOW_R + 0.03), cell * TIP * 1.3), Color(Pal.TEXT, 0.1))
		b.polygon(tile(Vector2(0.0, cell * SHADOW_DOWN), cell * SHADOW_R, cell * TIP * 1.1), Color(Pal.TEXT, 0.18))
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
	# a hollow is the button's own shape (the user, 2026-10-14: "make the
	# case slots follow the same button shape, not circle")
	var tip := step * 0.09
	for p in places:
		var at := tin_place(rect, p, per_row, step, places)
		if p < open:
			b.polygon(tile(at + Vector2(0.0, 2.0), step * 0.4, tip), Pal.WOOD.lightened(0.18))
			b.polygon(tile(at, step * 0.4, tip), Pal.WOOD_DEEP)
			b.polygon(tile(at + Vector2(0.0, 2.0), step * 0.37, tip), Pal.WOOD_DEEP.darkened(0.12))
		else:
			b.stroke(tile(at, step * 0.33, tip * 0.8), 2.0, Color(Pal.WOOD_DEEP, 0.55), true)

## The middle of place `p` of a tin over `rect`.
static func tin_place(rect: Rect2, p: int, per_row: int, step: float, places := 12) -> Vector2:
	var rows := ceili(float(places) / per_row)
	var origin := rect.get_center() - Vector2(per_row * step, rows * step) * 0.5
	# a short last row stands in the middle
	var short := rows * per_row - places if p / per_row == rows - 1 else 0
	return origin + Vector2((p % per_row) + 0.5 + short * 0.5, (p / per_row) + 0.5) * step
