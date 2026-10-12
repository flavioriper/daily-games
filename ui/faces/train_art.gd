extends RefCounted
## Toy Train's drawings (puzzles/train2d.gd, the menu card and the tutorial):
## the playroom floor, the rug, the wooden track, a toy block, a little
## engine seen from above, the siding and the shed. Builder shapes and not a
## Control, as `button_art.gd` is: the board bakes every block into one mesh
## and every engine into another.
##
## Blocks and engines are coloured by index, so nothing here says a state
## with a shade of the piece's own colour: an engine's room is its number.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

const FLOOR := Color("ecd9b4")
const FLOOR_SEAM := Color("dcc59b")
const FLOOR_GRAIN := Color("e4cfa6")
const PLANK := 96.0
const RUG := Color("cfe0d2")
const RUG_EDGE := Color("a9c7b4")
const RUG_STITCH := Color("f4f7ec")
const MAT := Color("bcd3c2")
const RAIL := Color("b98d5e")
const RAIL_DEEP := Color("8e6a45")
const SLEEPER := Color("d9b98c")
const TRAY := Color("c8a17a")
const TRAY_DEEP := Color("9c7350")
const TRAY_PLACE := Color("b58c63")
const SHED := Color("b8574a")
const SHED_DEEP := Color("8f3f36")
const LANE := Color("e9d7b6")
const LANE_LINE := Color("d3bd95")
const PLATE := Color("fbf7ee")
const IRON := Color("4a3226")
## A block's side of a square, and its corner.
const BLOCK := 0.9
const BLOCK_R := 0.16

static func colour(named: String) -> Color:
	return Pal.PG_BEADS.get(named, Pal.LINE)

## The ink of a number on a plate: always the dark one.
static func ink() -> Color:
	return Pal.TEXT

## The playroom floor over `size`: pale boards with their seams.
static func floor_boards(b, size: Vector2) -> void:
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)]), FLOOR)
	var row := 0
	var y := 0.0
	while y < size.y:
		_bar(b, Rect2(0.0, y + PLANK - 3.0, size.x, 3.0), FLOOR_SEAM)
		_bar(b, Rect2(0.0, y + PLANK * 0.45, size.x, 2.0), FLOOR_GRAIN)
		var x := 140.0 + 210.0 * (row % 3)
		while x < size.x:
			_bar(b, Rect2(x, y, 3.0, PLANK - 3.0), FLOOR_SEAM)
			x += 520.0
		y += PLANK
		row += 1

static func _bar(b, r: Rect2, col: Color) -> void:
	b.fan(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), col)

## The rug the loop lies on, and the mat in the middle the blocks stand on.
static func rug(b, rect: Rect2, mat: Rect2, cell: float) -> void:
	var r := cell * 1.1
	b.polygon(Face.Builder.round_rect(rect.position + Vector2(0.0, cell * 0.1), rect.size, r), Color(Pal.OUTLINE, 0.1))
	b.polygon(Face.Builder.round_rect(rect.position, rect.size, r), RUG_EDGE)
	var inner := rect.grow(-cell * 0.14)
	b.polygon(Face.Builder.round_rect(inner.position, inner.size, r * 0.9), RUG)
	var m := mat.grow(cell * 0.12)
	b.polygon(Face.Builder.round_rect(m.position, m.size, cell * 0.3), MAT)

## A dashed seam along a rounded rectangle: the rug's stitching.
static func stitches(b, rect: Rect2, radius: float, step: float, col: Color) -> void:
	var pts := Face.Builder.round_rect(rect.position, rect.size, radius)
	var n := pts.size()
	var run := 0.0
	var on := true
	var from := pts[0]
	for i in range(1, n + 1):
		var p := pts[i % n]
		run += from.distance_to(p)
		if run >= step:
			run = 0.0
			on = not on
		if on:
			b.stroke(PackedVector2Array([from, p]), 3.0, col, false, false)
		from = p

## The wooden track along `points` (a centreline, `closed` a loop): sleepers
## across it and a rail each side. `wide` is the gauge.
static func track(b, points: PackedVector2Array, wide: float, closed: bool) -> void:
	var n := points.size()
	if n < 2:
		return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var half := wide * 0.5
	var along := 0.0
	var gap := wide * 0.62
	for i in n:
		var prev := points[(i - 1 + n) % n] if (closed or i > 0) else points[i]
		var next := points[(i + 1) % n] if (closed or i < n - 1) else points[i]
		var dir := (next - prev).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		left.append(points[i] + nrm * half)
		right.append(points[i] - nrm * half)
		along += points[i].distance_to(prev)
		if along >= gap:
			along = 0.0
			var a := points[i] + nrm * half * 1.45
			var c := points[i] - nrm * half * 1.45
			b.stroke(PackedVector2Array([a, c]), wide * 0.2, SLEEPER, false, true)
	var rail := maxf(3.0, wide * 0.13)
	for side: PackedVector2Array in [left, right]:
		var under := PackedVector2Array()
		for p in side:
			under.append(p + Vector2(0.0, rail * 0.35))
		b.stroke(under, rail, RAIL_DEEP, closed, true)
		b.stroke(side, rail, RAIL, closed, true)

## One toy block about `at` on a square of `cell`: a deep edge, the face a
## touch up from it, and a soft shine at its top.
static func block(b, at: Vector2, cell: float, col: Color) -> void:
	var s := cell * BLOCK
	var r := cell * BLOCK_R
	var lift := cell * 0.07
	b.polygon(Face.Builder.round_rect(at - Vector2(s, s) * 0.5 + Vector2(0.0, lift * 0.5), Vector2(s, s), r), col.darkened(0.24))
	b.polygon(Face.Builder.round_rect(at - Vector2(s, s) * 0.5 - Vector2(0.0, lift * 0.5), Vector2(s, s - lift), r), col)
	if cell >= 30.0:
		var shine := Vector2(s * 0.56, s * 0.16)
		b.polygon(Face.Builder.round_rect(at + Vector2(-s * 0.36, -s * 0.4), shine, shine.y * 0.5), Color(col.lightened(0.35), 0.75))

## A little engine seen from above, about the origin, its nose up the
## screen, `s` long: wheels, the body, the funnel at the nose, the cab at the
## back and a pale plate for its number.
static func engine(b, s: float, col: Color) -> void:
	b.ellipse(Vector2(0.0, s * 0.06), s * 0.4, s * 0.5, Color(Pal.OUTLINE, 0.13))
	for sx in [-1.0, 1.0]:
		for wy in [-0.27, 0.0, 0.27]:
			var wheel := Vector2(s * 0.13, s * 0.19)
			b.polygon(Face.Builder.round_rect(Vector2(sx * s * 0.33, wy * s) - wheel * 0.5, wheel, s * 0.05), IRON)
	var body := Vector2(s * 0.6, s * 0.92)
	b.polygon(Face.Builder.round_rect(-body * 0.5 + Vector2(0.0, s * 0.035), body, s * 0.17), col.darkened(0.26))
	b.polygon(Face.Builder.round_rect(-body * 0.5 - Vector2(0.0, s * 0.02), body - Vector2(0.0, s * 0.03), s * 0.17), col)
	# the cab, a paler roof at the back
	var cab := Vector2(s * 0.5, s * 0.26)
	b.polygon(Face.Builder.round_rect(Vector2(-cab.x * 0.5, s * 0.16), cab, s * 0.08), col.lightened(0.28))
	# the funnel
	b.disc(Vector2(0.0, -s * 0.33), s * 0.105, IRON)
	b.disc(Vector2(0.0, -s * 0.33), s * 0.06, Color("6b5145"))
	# the buffer bar at the nose
	var bar := Vector2(s * 0.42, s * 0.07)
	b.polygon(Face.Builder.round_rect(Vector2(-bar.x * 0.5, -s * 0.5), bar, bar.y * 0.5), IRON)

## The plate an engine's number is written on, about the origin.
static func plate(b, s: float) -> void:
	b.disc(Vector2(0.0, s * 0.015), s * 0.225, Color(Pal.OUTLINE, 0.25))
	b.disc(Vector2.ZERO, s * 0.21, PLATE)

## The siding: a wooden tray with `places` hollows `step` apart.
static func siding(b, rect: Rect2, places: int, step: float) -> void:
	var r := rect.size.y * 0.3
	b.polygon(Face.Builder.round_rect(rect.position + Vector2(0.0, 6.0), rect.size, r), TRAY_DEEP)
	b.polygon(Face.Builder.round_rect(rect.position, rect.size, r), TRAY)
	for p in places:
		var c := siding_place(rect, p, places, step)
		var hole := Vector2(step * 0.8, rect.size.y * 0.78)
		b.polygon(Face.Builder.round_rect(c - hole * 0.5, hole, hole.x * 0.3), TRAY_PLACE)

static func siding_place(rect: Rect2, p: int, places: int, step: float) -> Vector2:
	return Vector2(rect.get_center().x + (p - (places - 1) * 0.5) * step, rect.get_center().y)

## The shed from above: a red frame and a pale lane a column.
static func shed(b, rect: Rect2, columns: int, step: float) -> void:
	var r := 26.0
	b.polygon(Face.Builder.round_rect(rect.position + Vector2(0.0, 7.0), rect.size, r), SHED_DEEP)
	b.polygon(Face.Builder.round_rect(rect.position, rect.size, r), SHED)
	for k in columns:
		var x := rect.get_center().x + (k - (columns - 1) * 0.5) * step
		var lane := Rect2(x - step * 0.42, rect.position.y + 10.0, step * 0.84, rect.size.y - 20.0)
		b.polygon(Face.Builder.round_rect(lane.position, lane.size, 18.0), LANE)
		var y := lane.position.y + 26.0
		while y < lane.end.y - 12.0:
			_bar(b, Rect2(lane.position.x + 10.0, y, lane.size.x - 20.0, 3.0), LANE_LINE)
			y += 30.0
