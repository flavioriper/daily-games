extends RefCounted

## Jewel Box's drawings (the board's id is still `buttons`: it was Button Box
## until 2026-10-19, when the user asked for "a jewel box" with a board
## closer to four phone shots of a mosaic of faceted gems): the page the
## table is laid with, a slot in a jewel's colour with a seat in it, the
## jewel that sits on it (loose, or set), the picture's edge and the white
## case. Builder shapes and not Controls, as Quilt's cloth and Lattice's
## tiles are: the board bakes its jewels into meshes (a thousand of them on
## Insane's 32-square picture), and the menu card and the tutorial draw the
## same pieces.
##
## A slot is its whole square in the jewel's own colour, edge to edge, so
## that the slots of one colour join into one flat area and the picture
## reads as the picture from afar (the user, 2026-10-14). A jewel is
## coloured by index, so nothing about it is said by a shade of its colour
## alone: a bare slot has a seat sunk in its middle (`socket`), loose is a
## gem of RIM standing on a shadow with the slot's colour all round it, and
## set is the gem grown to its square (`sewn`), flush with its neighbours
## and no shadow under it. The gem is the reference's cut: a rounded square
## with a dark rim and the two diagonals cutting it into four facets lit
## from the top (`facets`), a sliver of gloss along the top one. It takes
## back the bevel-to-flat-face gem of 2026-10-14 and the flat sewn square
## of 2026-10-11: with the picture a mosaic of gems, as the reference's is,
## a set jewel stays a jewel.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## Sizes as a share of the cell. A loose gem is RIM out from its middle to
## each side, 0.8 of its square across (the user, 2026-10-14: "keep it like
## 80% of the cell"); a set one SET_RIM, so a seam of 0.06 of a square lies
## between neighbours and the mosaic has its grid. TIP rounds the corners,
## EDGE is the dark rim's width. RIM stays over SOCKET: the seat is what
## says bare, and a jewel must hide it.
const RIM := 0.4
const SET_RIM := 0.47
const TIP := 0.12
const EDGE := 0.035
## The seat a card's chevron sits in (ui/menu/cards/buttons.gd), and how
## far a loose gem stands over its base.
const FACE := 0.22
const RISE := 0.03
## The seat's half-width: the gem's footprint, sunk.
const SOCKET := 0.36
## Under this luminance a slot's seat is lipped pale, not dark: dark, navy,
## maroon, brown, forest and purple.
const SOCKET_DARK := 0.42
const SHADOW_R := 0.41
const SHADOW_DOWN := 0.06
## The facets' light: top, left, right, bottom; a set gem at SET_FACET of
## it, calmer in the mosaic.
const FACET := [0.26, 0.07, -0.09, -0.27]
const SET_FACET := 0.72
## The page, the case and its hollows.
const PAGE := Color("f5eee4")
const CASE_RIM := Color("e4dcd0")
const HOLLOW := Color("cfc7bc")
const HOLLOW_FLOOR := Color("ddd6cc")
const THREAD := Color("fbf7ee")
const THREAD_DARK := Color("4a3226")
## Under this a cell the plain gem is drawn. The looks `units` builds.
const SMALL := 44.0
enum { FULL, PLAIN, CLOSE }

static func colour(named: String) -> Color:
	return Pal.PG_BEADS.get(named, Pal.LINE)

## The ring a landing throws, in a colour that shows on `col`: pale, or dark
## on a pale one.
static func thread_for(col: Color) -> Color:
	return THREAD_DARK if col.get_luminance() > 0.72 else THREAD

## The page over `size`: one flat cream, as the reference's is.
static func linen(b, size: Vector2) -> void:
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]), PAGE)

## The picture's edge: a pale hairline round `rect` over a soft shadow, the
## mosaic's own rim being the edge otherwise (the reference's board lies on
## the page with no panel round it).
static func frame(b, rect: Rect2) -> void:
	var r := 10.0
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 7.0), rect.size, r), Color(Pal.TEXT, 0.07))
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 3.0), rect.size, r), Color(Pal.TEXT, 0.06))
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), Pal.SURFACE)

## A slot centred on `at`: its whole square in `col`, edge to edge (a hair
## over, so neighbours of one colour leave no seam and join into one
## area), with the seat its jewel goes into. `lite` cuts the seat in fewer
## points: a thousand of them are one mesh.
static func patch(b, at: Vector2, cell: float, col: Color, lite := false) -> void:
	square(b, at, cell, col)
	socket(b, at, cell, col, 12 if lite else 20)

## The square of a slot, the colour whole, a hair over the cell so that
## neighbours leave no seam.
static func square(b, at: Vector2, cell: float, col: Color) -> void:
	var half := cell * 0.5 + 0.4
	_raw(b, PackedVector2Array([at + Vector2(-half, -half), at + Vector2(half, -half),
			at + Vector2(half, half), at + Vector2(-half, half)]), col)

## The seat a jewel sits in: its footprint sunk into the slot, hidden under
## any jewel and seen on a bare one, so that bare and set differ by a
## shape and not a shade. Its floor is set a hair low, so the lip is
## thicker along the top: a recess, lit from above. `sides` over 12 cuts
## the corners finer.
static func socket(b, at: Vector2, cell: float, col: Color, sides: int) -> void:
	var r := cell * SOCKET
	var rim := maxf(2.0, cell * 0.06)
	var tip := cell * TIP
	# on a dark slot a darker seat is lost (the user, 2026-10-17: "on
	# darker backgrounds colors, it's impossible to see"): its lip is lit
	# instead, a pale lip round a sunk floor
	var dark := col.get_luminance() < SOCKET_DARK
	var edge := col.lightened(0.34) if dark else col.darkened(0.34)
	var floor_ := col.darkened(0.22) if dark else col.darkened(0.1)
	var n := 5 if sides > 12 else 3
	_raw(b, corners(at, r, tip, n), edge)
	_raw(b, corners(at + Vector2(0.0, cell * 0.018), r - rim, maxf(1.0, tip - rim), n), floor_)

## A jewel set in its square: the gem grown to SET_RIM, flush with its
## neighbours, no shadow and no base under it. (The name is the board's
## word for a jewel home.)
static func sewn(b, at: Vector2, cell: float, col: Color) -> void:
	gem(b, at, cell, col, true, 3 if cell < SMALL else 5)

## A rounded square about `at`, `r` from its middle to each side, its
## corners rounded by `tip`, `n` points to a corner (odd, so the corner's
## middle point lies on the diagonal and the facets meet there). The points
## run clockwise from the top-left corner's left end.
static func corners(at: Vector2, r: float, tip: float, n: int) -> PackedVector2Array:
	tip = clampf(tip, 0.0, r)
	var pts := PackedVector2Array()
	pts.resize(4 * n)
	var k := 0
	for c in 4:
		var sx := -1.0 if c == 0 or c == 3 else 1.0
		var sy := -1.0 if c < 2 else 1.0
		var mid := at + Vector2(sx, sy) * (r - tip)
		var a0 := PI + c * PI * 0.5
		for i in n:
			var a := a0 + PI * 0.5 * i / (n - 1)
			pts[k] = mid + Vector2(cos(a), sin(a)) * tip
			k += 1
	return pts

## The rounded square of a gem, for a caller that wants its outline: `fine`
## cuts the corners in five points, else three.
static func tile(at: Vector2, r: float, tip: float, fine := true) -> PackedVector2Array:
	return corners(at, r, tip, 5 if fine else 3)

## The gem's four facets: the rounded square `r` out (corners by `tip`, `n`
## points each) cut by its two diagonals into top, left, right and bottom,
## each a fan from the middle in the colour lifted or sunk by FACET times
## `k`.
static func facets(b, at: Vector2, r: float, tip: float, n: int, col: Color, k := 1.0) -> void:
	var pts := corners(at, r, tip, n)
	var m := n / 2
	# a facet runs from one corner's middle point round to the next's
	var spans := [[0, 1], [3, 0], [1, 2], [2, 3]]
	for f in 4:
		var a: int = spans[f][0]
		var z: int = spans[f][1]
		var poly := PackedVector2Array([at])
		for i in range(m, n):
			poly.append(pts[a * n + i])
		for i in range(0, m + 1):
			poly.append(pts[z * n + i])
		var lift: float = FACET[f] * k
		_raw(b, poly, col.lightened(lift) if lift >= 0.0 else col.darkened(-lift))

## A gem about `at`: its dark rim, the four facets inside it and a sliver
## of gloss along the top one. `set` is the jewel in its square, calmer and
## flush; loose it stands on a darker base, a hair below.
static func gem(b, at: Vector2, cell: float, col: Color, set: bool, n: int) -> void:
	var r := cell * (SET_RIM if set else RIM)
	var tip := cell * TIP
	var edge := maxf(1.2, cell * EDGE)
	var k := SET_FACET if set else 1.0
	var up := at
	if not set:
		up = at - Vector2(0.0, cell * RISE)
		_raw(b, corners(at + Vector2(0.0, cell * RISE), r, tip, n), col.darkened(0.5))
	_raw(b, corners(up, r, tip, n), col.darkened(0.4 if set else 0.36))
	facets(b, up, r - edge, maxf(0.5, tip - edge), n, col, k)
	# the gloss: a sliver under the top edge, most of its width
	var g := r - edge
	var h := maxf(1.0, cell * 0.045)
	var y := -g + edge * 0.3
	_raw(b, PackedVector2Array([up + Vector2(-g * 0.72, y), up + Vector2(g * 0.72, y),
			up + Vector2(g * 0.5, y + h), up + Vector2(-g * 0.5, y + h)]), Color(1.0, 1.0, 1.0, 0.3 * k))

## A jewel centred on `at`, the fine cut; `sewn` is the jewel set.
static func button(b, at: Vector2, cell: float, col: Color, sewn: bool) -> void:
	gem(b, at, cell, col, sewn, 5)

## The jewel of a big picture: seen whole (20 to 40 px across) its corners
## are cut in three points, `close` (the picture zoomed) in five.
static func button_lite(b, at: Vector2, cell: float, col: Color, sewn: bool, close: bool) -> void:
	gem(b, at, cell, col, sewn, 5 if close else 3)

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

## The pieces drawn many times over, each once about the origin at `cell`:
## {shade, ring, loose: [a colour], sewn: [a colour]}. `look` is FULL, or
## a big picture's PLAIN and CLOSE.
static func units(cell: float, colours: Array, look := FULL) -> Dictionary:
	var out := {"loose": [], "sewn": []}
	var b := Face.Builder.new()
	if look != FULL:
		_raw(b, corners(Vector2(0.0, cell * SHADOW_DOWN), cell * (SHADOW_R - 0.01), cell * TIP, 3), Color(Pal.TEXT, 0.2))
	else:
		# soft: a wide faint tile under a smaller one, so a gem in the air
		# does not drag a grey box (feathered by polygon)
		b.polygon(corners(Vector2(0.0, cell * SHADOW_DOWN + 2.0), cell * (SHADOW_R + 0.03), cell * TIP * 1.4, 5), Color(Pal.TEXT, 0.07))
		b.polygon(corners(Vector2(0.0, cell * SHADOW_DOWN), cell * (SHADOW_R - 0.02), cell * TIP * 1.2, 5), Color(Pal.TEXT, 0.13))
	out.shade = b.mesh()
	b = Face.Builder.new()
	b.disc(Vector2.ZERO, cell * 0.5, Pal.SUN)
	b.disc(Vector2.ZERO, cell * 0.43, Color(Pal.SUN_TILE, 0.9))
	out.ring = b.mesh()
	var n := 3 if look == PLAIN else 5
	for named in colours:
		var col := colour(String(named))
		b = Face.Builder.new()
		gem(b, Vector2.ZERO, cell, col, false, n)
		out.loose.append(b.mesh())
		b = Face.Builder.new()
		gem(b, Vector2.ZERO, cell, col, true, n)
		out.sewn.append(b.mesh())
	return out

## The case: a white panel over `rect` on a soft shadow, with `places`
## hollows in rows of `per_row`, the first `open` of them grey seats and
## the rest only outlined. (The name is the board's word for it.)
static func tin(b, rect: Rect2, places: int, open: int, per_row: int, step: float) -> void:
	var r := step * 0.3
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 8.0), rect.size, r), Color(Pal.TEXT, 0.07))
	b.fan(Face.Builder.round_rect(rect.position + Vector2(0.0, 4.0), rect.size, r), Color(Pal.TEXT, 0.06))
	b.fan(Face.Builder.round_rect(rect.position, rect.size, r), CASE_RIM)
	b.fan(Face.Builder.round_rect(rect.position + Vector2.ONE * 4.0, rect.size - Vector2.ONE * 8.0, r * 0.85), Pal.SURFACE)
	# a hollow is the jewel's own footprint (the user, 2026-10-14: "make the
	# case slots follow the same button shape, not circle")
	var tip := step * TIP
	for p in places:
		var at := tin_place(rect, p, per_row, step, places)
		if p < open:
			_raw(b, corners(at, step * 0.4, tip, 5), HOLLOW)
			_raw(b, corners(at + Vector2(0.0, 2.0), step * 0.36, maxf(1.0, tip - step * 0.04), 5), HOLLOW_FLOOR)
		else:
			b.stroke(corners(at, step * 0.34, tip * 0.8, 3), 2.0, Color(HOLLOW, 0.7), true)

## The middle of place `p` of a case over `rect`.
static func tin_place(rect: Rect2, p: int, per_row: int, step: float, places := 12) -> Vector2:
	var rows := ceili(float(places) / per_row)
	var origin := rect.get_center() - Vector2(per_row * step, rows * step) * 0.5
	# a short last row stands in the middle
	var short := rows * per_row - places if p / per_row == rows - 1 else 0
	return origin + Vector2((p % per_row) + 0.5 + short * 0.5, (p / per_row) + 0.5) * step
