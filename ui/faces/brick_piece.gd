extends RefCounted

## A building brick seen from above, as builder shapes: Quilt's piece since
## 2026-10-17 (the user: "redesign quilt to have a design closer to a brick
## ... builder pieces"). It stands in for `ui/faces/patch_cloth.gd` on Quilt's
## board, its world, its card and its tutorial, and answers every name they
## call on that file, so the board's motion, looks and timing are untouched;
## Pinwheel keeps the cloth.
##
## **A brick is still one silhouette**, traced, rounded and lipped by the
## cloth file's own code (`loops`, `laid`, `round_loop` are handed straight
## through): the corner is tighter, the side under it is tall enough to read
## as a block, and the face carries a soft top bevel. On each cell a **stud**
## stands -- the cloth's print slot (`print_cloth`) draws them -- so the cells
## are counted by eye without a rule between them.
##
## What the cloth's thread became: the seam between two bricks is a dark
## groove, solid where the stitch was dashed (the board's `STITCH_ON`), and
## the quilting stitch a sewn patch wears just inside its edge is a pale
## bevel line run round once as the brick presses home (`QUILT_ON` long,
## `QUILT_OFF` all but nothing). There is no needle.
##
## **Studs are form, never state**: they look the same on the rack, in the
## hand and on the plate, and the colour of a brick is never shaded to say
## anything (the halo, the chalk and the cross still do that).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Patch = preload("res://ui/faces/patch_cloth.gd")

## A brick's rounded corner and its side under it, in cells.
const RADIUS := 0.07
const EDGE := 0.13
## How far a brick's colour is taken toward the ink for its side and for the
## groove of a seam.
const DEEP := 0.26
const STITCH := 0.45
## The bevel line a pressed-home brick wears inside its edge: how far in, its
## width, and its "dashes" -- one run the length of any brick, so the cloth's
## dash walker strokes it whole.
const QUILT_INSET := 0.06
const QUILT_W := 0.03
const QUILT_ON := 1000.0
const QUILT_OFF := 0.0001
const QUILT_THREAD := 0.42
const SHADOW_ALPHA := 0.2
## How wide the light along a brick's upper edges is, in cells.
const BEVEL := 0.035
## A stud: its radius in cells, how far its side shows under its top, the
## shadow it throws down the face, and the shine on its top left.
const STUD_R := 0.27
const STUD_SIDE := 0.05
const STUD_SHADE := 0.18
const STUD_TOP := 0.12
const STUD_SHINE := 0.6
## The plate the bricks press onto: a pale grey with low studs, the faintest
## thing on the board so every brick stays its strongest surface.
const PLATE := Color("dfe3e8")
const PLATE_DEEP := Color("b8bfc9")
const PLATE_STUD := 0.06
const PLATE_STUD_R := 0.25

## Eight toy-plastic colours, by cloth index (`cloth_of[p]` on the board):
## red, yellow, blue, green, orange, purple, teal and pink, bright enough to
## be bricks and kept apart in hue the way `Pal.CLOTH`'s are.
const BRICK := [
	Color("f2c945"),   # yellow
	Color("5b9be6"),   # blue
	Color("e9584c"),   # red
	Color("6cbf5c"),   # green
	Color("9b7fe0"),   # purple
	Color("f3933b"),   # orange
	Color("3fbcb6"),   # teal
	Color("ef7fb4"),   # pink
]

static func cloth(i: int) -> Color:
	return BRICK[i % BRICK.size()]

static func cloth_deep(i: int) -> Color:
	return cloth(i).lerp(Pal.TEXT, DEEP)

static func cloth_stitch(i: int) -> Color:
	return cloth(i).lerp(Pal.TEXT, STITCH)

## The bevel's pale line on brick `i`.
static func cloth_thread(i: int) -> Color:
	return cloth(i).lerp(Color.WHITE, QUILT_THREAD)

# --- the cloth's geometry, handed straight through ---

static func loops(cells: Array) -> Array:
	return Patch.loops(cells)

static func round_loop(loop: PackedVector2Array, r: float) -> PackedVector2Array:
	return Patch.round_loop(loop, r)

static func place(v: Vector2, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, rot := 0.0) -> Vector2:
	return Patch.place(v, pos, cell, span, sc, rot)

static func laid(loop: PackedVector2Array, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, rot := 0.0, radius := RADIUS) -> PackedVector2Array:
	return Patch.laid(loop, pos, cell, span, sc, rot, radius)

static func stitch(b, a: Vector2, to: Vector2, width: float, on: float, off: float,
		ink: Color, reach := 1.0) -> void:
	Patch.stitch(b, a, to, width, on, off, ink, reach)

static func dash_loop(b, pts: PackedVector2Array, width: float, on: float, off: float,
		ink: Color, limit := INF) -> void:
	Patch.dash_loop(b, pts, width, on, off, ink, limit)

static func along(pts: PackedVector2Array, dist: float) -> Array:
	return Patch.along(pts, dist)

static func perimeter(pts: PackedVector2Array) -> float:
	return Patch.perimeter(pts)

static func inset_loops(cells: Array, inset := QUILT_INSET) -> Array:
	return Patch.inset_loops(cells, inset)

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	return Patch._moved(pts, by)

static func _area(loop: PackedVector2Array) -> float:
	return Patch._area(loop)

# --- the brick ---

## One brick: its side `EDGE` under it in `deep`, its face, and the face's
## bevel -- a lighter copy of the face drawn a hair up and in, so the top
## catches the light along its upper edges.
static func patch(b, shape_loops: Array, pos: Vector2, cell: float, span: Vector2i,
		face: Color, deep: Color, sc := Vector2.ONE, alpha := 1.0, rot := 0.0) -> void:
	if alpha <= 0.0 or sc.x <= 0.0 or sc.y <= 0.0:
		return
	var px := cell * minf(sc.x, sc.y)
	for loop: PackedVector2Array in shape_loops:
		if _area(loop) <= 0.0:
			continue
		var pts := laid(loop, pos, cell, span, sc, rot)
		b.polygon(_moved(pts, Vector2(0.0, EDGE * cell * sc.y)), Color(deep, alpha))
		b.polygon(pts, Color(face.lerp(Color.WHITE, 0.22), alpha))
		for inner: PackedVector2Array in Geometry2D.offset_polygon(pts, -BEVEL * px):
			b.polygon(_moved(inner, Vector2(0.4, 0.6) * BEVEL * px), Color(face, alpha))

## The soft shadow a lifted brick casts, as the cloth's.
static func shadow(b, shape_loops: Array, pos: Vector2, cell: float, span: Vector2i,
		by: Vector2, level: float, sc := Vector2.ONE, rot := 0.0) -> void:
	if level <= 0.0 or by == Vector2.ZERO:
		return
	for loop: PackedVector2Array in shape_loops:
		if _area(loop) <= 0.0:
			continue
		b.polygon(_moved(laid(loop, pos, cell, span, sc, rot), by),
			Color(Pal.TEXT, SHADOW_ALPHA * level))

## The studs of brick `i` over its `cells`, one a cell, laid through the same
## `place` as its silhouette so a brick that pops, leans or lands carries
## them. (The cloth's print slot: the board calls it after every patch.)
static func print_cloth(b, cells: Array, i: int, pos: Vector2, cell: float, span: Vector2i,
		sc := Vector2.ONE, alpha := 1.0, rot := 0.0) -> void:
	if alpha <= 0.0 or sc.x <= 0.0 or sc.y <= 0.0 or cell <= 0.0:
		return
	var px := cell * minf(sc.x, sc.y)
	for c: Vector2i in cells:
		stud(b, place(Vector2(c) + Vector2(0.5, 0.5), pos, cell, span, sc, rot), px, cloth(i), alpha)

## One stud of colour `face` at `at`, for a cell of `px`: the shade it throws
## down and right, its side, its top and the shine on it.
static func stud(b, at: Vector2, px: float, face: Color, alpha := 1.0) -> void:
	var r := STUD_R * px
	var side := STUD_SIDE * px
	b.disc(at + Vector2(0.4, 1.0) * side * 1.4, r * 1.02, Color(Pal.TEXT, STUD_SHADE * alpha))
	b.disc(at + Vector2(0.0, side), r, Color(face.lerp(Pal.TEXT, DEEP * 0.8), alpha))
	b.disc(at, r, Color(face.lerp(Color.WHITE, STUD_TOP), alpha))
	b.disc(at + Vector2(0.03, 0.04) * px, r * 0.78, Color(face, alpha))
	b.stroke(Face.Builder.arc_points(at, r * 0.72, PI * 1.05, PI * 1.45), r * 0.16,
		Color(Color.WHITE, STUD_SHINE * alpha), false, true)

## The plate a quilt's backing became: its silhouette over its side, and a
## low stud on every cell of it.
static func plate(b, shape_loops: Array, cells: Array, pos: Vector2, cell: float) -> void:
	for loop: PackedVector2Array in shape_loops:
		if _area(loop) <= 0.0:
			continue
		var pts := laid(loop, pos, cell, Vector2i.ZERO)
		b.polygon(_moved(pts, Vector2(0.0, PLATE_STUD * cell * 1.4)), PLATE_DEEP)
		b.polygon(pts, PLATE)
	var r := PLATE_STUD_R * cell
	for c: Vector2i in cells:
		var at := pos + (Vector2(c) + Vector2(0.5, 0.5)) * cell
		b.disc(at + Vector2(0.0, PLATE_STUD * cell), r, Color(PLATE_DEEP, 0.9))
		b.disc(at, r, PLATE.lerp(Color.WHITE, 0.35))
		b.disc(at + Vector2(0.02, 0.03) * cell, r * 0.8, PLATE)

## A brick has no needle: the bevel simply runs round.
static func needle(_b, _at: Vector2, _dir: Vector2, _cell: float, _thread: Color) -> void:
	pass
