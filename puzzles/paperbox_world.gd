extends Control

## Paper Box's world: a craft table by a window, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## A cream wall across the top, where the wordmark, the motto and the win's
## "Well done!" are ink with no scrim, the window's light on it and a
## wooden shelf under it where the folded boxes stand; then the table's far
## edge and its warm planks to past the foot, a green cutting mat laid on
## them with its grid and ruler, where the net lies, and a pencil and a roll
## of tape either side of the count line at the foot.
##
## The board says where its lines stand (`set_lines`): the shelf's top, the
## mat's rect, the table's edge and the foot. One mesh, built when the rect or a line
## changes and kept (`_shown`) until the next replaces it, drawn past the
## top of the rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const WALL_HIGH := Color("fbf4e7")
const WALL_LOW := Color("f3e7d3")
const SUN := Color("fff1c8")
const SHELF := Color("c99863")
const SHELF_TOP := Color("dcb07c")
const SHELF_DEEP := Color("9f7148")
const BRACKET := Color("8d6644")
const EDGE := Color("b98a5c")
const TABLE := Color("e2bd8e")
const TABLE_LOW := Color("d4aa77")
const GRAIN := Color("c99d6a")
const MAT := Color("8fbf9f")
const MAT_DEEP := Color("74a685")
const MAT_RIM := Color("6a987a")
const MAT_LINE := Color("a9d3b6")
const RULER := Color("f3e6c5")
const RULER_TICK := Color("9c8a6a")
const PENCIL := Color("f2c14e")
const PENCIL_DEEP := Color("cf9d2c")
const WOOD_TIP := Color("efd5b0")
const LEAD := Color("4a4038")
const TAPE := Color("f0a6c6")
const TAPE_DEEP := Color("cc7aa0")
## How far past the top the wall is drawn, as a share of the height.
const OVER := 0.6

var _shelf := 0.0
var _mat := Rect2()
var _edge := 0.0
var _foot := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the shelf's top, the mat, the table's far
## edge and the count line at the foot. Built again only when one moved.
func set_lines(shelf: float, mat: Rect2, edge: float, foot := 0.0) -> void:
	_shelf = shelf
	_mat = mat
	_edge = edge
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _edge <= 0.0:
		return
	var key := "%s:%s:%s:%s:%s" % [size, _shelf, _mat, _edge, _foot]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _edge + 2.0), Color.WHITE)
	CardFace.shade(b, first, WALL_HIGH, WALL_LOW, h * 0.05, _edge)
	# the window's light on the wall
	var sun := Vector2(w * 0.82, _edge * 0.35)
	for ring: Array in [[300.0, 0.10], [190.0, 0.14], [120.0, 0.2]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	if _shelf > 0.0:
		_shelf_plank(b, w, u)
	# the table: its far edge, then the planks to past the foot
	b.polygon(_rect(-8.0, _edge - 4.0 * u, w + 8.0, _edge + 16.0 * u), EDGE)
	first = b.verts.size()
	b.polygon(_rect(-8.0, _edge + 14.0 * u, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, TABLE, TABLE_LOW, _edge, h)
	_grain(b, w, h, u)
	Scenery.soft_disc(b, Vector2(w * 0.5, _edge + 24.0 * u), w * 0.6, 22.0 * u, Color(EDGE, 0.4))
	if _mat.size.x > 0.0:
		_cutting_mat(b, u)
	if _foot > 0.0:
		# by the count line, either side of it, clear of the boxes
		_pencil(b, Vector2(w - 150.0 * u, _foot - 6.0 * u), u)
		_tape(b, Vector2(110.0 * u, _foot - 8.0 * u), u)
	_shown = b.mesh()
	queue_redraw()

## The shelf the folded boxes stand on, its two brackets under it.
func _shelf_plank(b: Face.Builder, w: float, u: float) -> void:
	var x0 := w * 0.06
	var x1 := w * 0.94
	for bx in [x0 + 60.0 * u, x1 - 60.0 * u]:
		b.polygon(PackedVector2Array([Vector2(bx - 8.0 * u, _shelf + 20.0 * u), Vector2(bx + 8.0 * u, _shelf + 20.0 * u),
			Vector2(bx + 8.0 * u, _shelf + 70.0 * u), Vector2(bx - 8.0 * u, _shelf + 40.0 * u)]), BRACKET)
	Scenery.soft_disc(b, Vector2(w * 0.5, _shelf + 34.0 * u), (x1 - x0) * 0.5, 16.0 * u, Color(BRACKET, 0.25))
	b.fan(Face.Builder.round_rect(Vector2(x0, _shelf), Vector2(x1 - x0, 24.0 * u), 6.0 * u), SHELF_DEEP)
	b.fan(Face.Builder.round_rect(Vector2(x0, _shelf), Vector2(x1 - x0, 16.0 * u), 6.0 * u), SHELF)
	b.fan(Face.Builder.round_rect(Vector2(x0, _shelf), Vector2(x1 - x0, 6.0 * u), 3.0 * u), SHELF_TOP)

## Long soft streaks of grain along the planks, and their seams.
func _grain(b: Face.Builder, w: float, h: float, u: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	var plank := 150.0 * u
	var y := _edge + 16.0 * u + plank
	while y < h + 60.0 * u:
		b.polygon(_rect(-8.0, y, w + 8.0, y + 3.0 * u), Color(GRAIN, 0.7))
		y += plank
	for i in 26:
		var gy := rng.randf_range(_edge + 30.0 * u, h + 40.0 * u)
		var gx := rng.randf_range(-100.0, w)
		var run := rng.randf_range(160.0, 360.0) * u
		var pts := PackedVector2Array()
		for k in 6:
			var t := float(k) / 5.0
			pts.append(Vector2(gx + run * t, gy + sin(t * PI * 1.5 + i) * 5.0 * u))
		b.stroke(pts, rng.randf_range(2.0, 3.5) * u, Color(GRAIN, 0.45))

## The cutting mat: a green board with a deeper rim, its grid of fine
## lines, every fifth a little bolder, and a ruler of ticks along its top.
func _cutting_mat(b: Face.Builder, u: float) -> void:
	var r := _mat
	Scenery.soft_disc(b, r.get_center() + Vector2(0.0, r.size.y * 0.5 + 6.0 * u), r.size.x * 0.52, 18.0 * u, Color(0.3, 0.2, 0.1, 0.12))
	b.fan(Face.Builder.round_rect(r.position + Vector2(0.0, 6.0 * u), r.size, 22.0 * u), MAT_RIM)
	b.fan(Face.Builder.round_rect(r.position, r.size, 22.0 * u), MAT)
	var inner := r.grow(-26.0 * u)
	b.fan(Face.Builder.round_rect(inner.position, inner.size, 10.0 * u), MAT_DEEP.lerp(MAT, 0.75))
	var step := 36.0 * u
	var i := 0
	var x := inner.position.x + step
	while x < inner.end.x - 2.0:
		b.polygon(_rect(x - 0.8 * u, inner.position.y + 4.0 * u, x + 0.8 * u, inner.end.y - 4.0 * u), Color(MAT_LINE, 0.75 if i % 5 == 4 else 0.4))
		x += step
		i += 1
	i = 0
	var y := inner.position.y + step
	while y < inner.end.y - 2.0:
		b.polygon(_rect(inner.position.x + 4.0 * u, y - 0.8 * u, inner.end.x - 4.0 * u, y + 0.8 * u), Color(MAT_LINE, 0.75 if i % 5 == 4 else 0.4))
		y += step
		i += 1
	# the ruler's ticks along the top rim
	var tx := inner.position.x
	var k := 0
	while tx <= inner.end.x:
		var tall := (14.0 if k % 5 == 0 else 7.0) * u
		b.polygon(_rect(tx - 1.0 * u, r.position.y + 6.0 * u, tx + 1.0 * u, r.position.y + 6.0 * u + tall), Color(RULER, 0.8))
		tx += step * 0.5
		k += 1

## A yellow pencil lying on the table, at a slant.
func _pencil(b: Face.Builder, at: Vector2, u: float) -> void:
	var dir := Vector2(-1.0, 0.18).normalized()
	var side := dir.orthogonal()
	var run := 230.0 * u
	var half := 11.0 * u
	var tail := at - dir * run * 0.5
	var body_end := at + dir * run * 0.32
	Scenery.soft_disc(b, at + Vector2(0.0, 14.0 * u), run * 0.5, 10.0 * u, Color(0.3, 0.2, 0.1, 0.12))
	b.polygon(PackedVector2Array([tail + side * half, body_end + side * half, body_end - side * half, tail - side * half]), PENCIL)
	b.polygon(PackedVector2Array([tail + side * half * 0.25, body_end + side * half * 0.25, body_end - side * half * 0.3, tail - side * half * 0.3]), PENCIL_DEEP)
	var tip := at + dir * run * 0.5
	b.polygon(PackedVector2Array([body_end + side * half, tip, body_end - side * half]), WOOD_TIP)
	b.polygon(PackedVector2Array([tip - dir * 22.0 * u + side * half * 0.35, tip, tip - dir * 22.0 * u - side * half * 0.35]), LEAD)
	b.polygon(PackedVector2Array([tail + side * half, tail - side * half, tail - side * half - dir * 18.0 * u, tail + side * half - dir * 18.0 * u]), TAPE)

## A roll of pink paper tape, seen from above.
func _tape(b: Face.Builder, at: Vector2, u: float) -> void:
	Scenery.soft_disc(b, at + Vector2(0.0, 10.0 * u), 50.0 * u, 14.0 * u, Color(0.3, 0.2, 0.1, 0.12))
	b.ellipse(at + Vector2(0.0, 6.0 * u), 46.0 * u, 30.0 * u, TAPE_DEEP)
	b.ellipse(at, 46.0 * u, 30.0 * u, TAPE)
	b.ellipse(at, 26.0 * u, 16.0 * u, TAPE_DEEP)
	b.ellipse(at + Vector2(0.0, 2.0 * u), 24.0 * u, 14.0 * u, TABLE)

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
