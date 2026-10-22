extends Control

## Market Sums' world: a garden market stall, edge to edge under the board
## and the host's rows (CLAUDE.md: a game's world fills the screen). A pale
## sky across the top, where the wordmark, the motto and the win's "Well
## done!" are ink with no scrim, with green hills far off; then
## the stall: a striped awning with a scalloped hem, the plank wall behind
## the shelves the crates stand on, the posts at either side, and the
## counter the sign tokens lie on, its front boards down to a cobbled
## ground past the foot.
##
## The board says where its lines stand (`set_lines`): the awning's hem, the
## shelves' tops and the counter's. One mesh, built when the rect or a line
## changes and kept (`_shown`) until the next replaces it, drawn past the top
## of the rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("e4f1f4")
const SKY_LOW := Color("f8f1e2")
const SUN := Color("fff1c8")
const HILL := Color("bcd79a")
const HILL_DEEP := Color("a3c784")
const STRIPE := Color("ee9a8e")
const STRIPE_DEEP := Color("d97f73")
const CREAM := Color("fbf3e4")
const CREAM_DEEP := Color("eadcc4")
const WALL := Color("e6c9a0")
const WALL_LOW := Color("d9b98c")
const WALL_SEAM := Color("caa577")
const POST := Color("b4835a")
const POST_DEEP := Color("926541")
const SHELF := Color("c8955f")
const SHELF_DEEP := Color("9c6f46")
const COUNTER := Color("cf9d66")
const COUNTER_TOP := Color("ddb07c")
const COUNTER_DEEP := Color("a8784c")
const BOARD := Color("c38f5c")
const BOARD_SEAM := Color("a67648")
const GROUND := Color("d9cdb5")
const GROUND_LOW := Color("cbbd9f")
const COBBLE := Color("e6dcc7")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6
## The awning's depth over its hem and a stripe's width, at W.
const AWNING := 120.0
const STRIPE_W := 90.0

var _awn := 0.0
var _shelves: Array = []
var _counter := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the awning's hem, each shelf's top and the
## counter's. The picture is built again only when one moved.
func set_lines(awning: float, shelves: Array, counter: float) -> void:
	_awn = awning
	_shelves = shelves
	_counter = counter
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _counter <= 0.0:
		return
	var key := "%d:%d:%d:%d:%s" % [roundi(size.x), roundi(size.y), roundi(_awn), roundi(_counter), str(_shelves)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	var top := _awn - AWNING * u
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, top + 40.0 * u), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.04, top)
	var sun := Vector2(w * 0.82, top * 0.45)
	for ring: Array in [[230.0, 0.12], [150.0, 0.16], [96.0, 0.22]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	# far hills behind the stall
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	b.ellipse(Vector2(w * 0.2, top + 30.0 * u), w * 0.5, 90.0 * u, HILL_DEEP)
	b.ellipse(Vector2(w * 0.8, top + 40.0 * u), w * 0.55, 80.0 * u, HILL)
	# the plank wall behind the shelves, from the awning to the counter
	first = b.verts.size()
	b.polygon(_rect(-8.0, top + 20.0 * u, w + 8.0, _counter + 4.0 * u), Color.WHITE)
	CardFace.shade(b, first, WALL, WALL_LOW, top, _counter)
	var px := 0.0
	while px < w:
		b.polygon(_rect(px - 1.5 * u, top + 20.0 * u, px + 1.5 * u, _counter), Color(WALL_SEAM, 0.6))
		px += 120.0 * u
	# the shelves the crates stand on
	for y: float in _shelves:
		Scenery.soft_disc(b, Vector2(w * 0.5, y + 22.0 * u), w * 0.46, 14.0 * u, Color(SHELF_DEEP, 0.35))
		b.polygon(_rect(30.0 * u, y, w - 30.0 * u, y + 26.0 * u), SHELF_DEEP)
		b.polygon(_rect(30.0 * u, y, w - 30.0 * u, y + 17.0 * u), SHELF)
	# the posts at either side
	for x: float in [24.0 * u, w - 24.0 * u]:
		b.polygon(_rect(x - 22.0 * u, top, x + 22.0 * u, _counter), POST_DEEP)
		b.polygon(_rect(x - 22.0 * u, top, x + 14.0 * u, _counter), POST)
	_awning(b, w, top, u)
	# the counter and its front boards down past the foot
	b.polygon(_rect(-8.0, _counter, w + 8.0, _counter + 28.0 * u), COUNTER_TOP)
	b.polygon(_rect(-8.0, _counter + 22.0 * u, w + 8.0, _counter + 34.0 * u), COUNTER_DEEP)
	var front := _counter + 34.0 * u
	var foot := maxf(front + 120.0 * u, h - 150.0 * u)
	b.polygon(_rect(-8.0, front, w + 8.0, foot), COUNTER)
	var bx := 0.0
	while bx < w:
		b.polygon(_rect(bx, front, bx + 3.0 * u, foot), BOARD_SEAM)
		bx += 135.0 * u
	b.polygon(_rect(-8.0, foot - 10.0 * u, w + 8.0, foot), COUNTER_DEEP)
	# the cobbles
	first = b.verts.size()
	b.polygon(_rect(-8.0, foot, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, GROUND, GROUND_LOW, foot, h)
	var cy := foot + 26.0 * u
	var row := 0
	while cy < h + 40.0 * u:
		var cx := -40.0 * u + (row % 2) * 45.0 * u
		while cx < w + 40.0 * u:
			b.ellipse(Vector2(cx + rng.randf_range(-6.0, 6.0) * u, cy), 36.0 * u, 16.0 * u, Color(COBBLE, 0.7))
			cx += 90.0 * u
		cy += 40.0 * u
		row += 1
	_shown = b.mesh()
	queue_redraw()

## The awning from `top` down to its hem, striped rose and cream, each
## stripe ending in a scallop.
func _awning(b: Face.Builder, w: float, top: float, u: float) -> void:
	var sw := STRIPE_W * u
	b.polygon(_rect(-8.0, top - 16.0 * u, w + 8.0, top + 4.0 * u), POST_DEEP)
	var x := -sw * 0.5
	var i := 0
	while x < w + sw:
		var colour := STRIPE if i % 2 == 0 else CREAM
		var deep := STRIPE_DEEP if i % 2 == 0 else CREAM_DEEP
		b.polygon(_rect(x, top, x + sw, _awn), colour)
		b.polygon(_rect(x, top, x + sw, top + 14.0 * u), deep)
		var arc := Face.Builder.arc_points(Vector2(x + sw * 0.5, _awn), sw * 0.5, 0.0, PI)
		b.fan(arc, colour)
		x += sw
		i += 1
	Scenery.soft_disc(b, Vector2(w * 0.5, _awn + sw * 0.55), w * 0.55, 16.0 * u, Color(POST_DEEP, 0.25))

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
