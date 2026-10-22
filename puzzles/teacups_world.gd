extends Control

## Teacups' world: a garden tea table, edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). The sky is cream
## across the top, where the wordmark, the motto and the win's "Well done!"
## are ink with no scrim; a string of paper bunting crosses it. Under the
## sky, a hedge with roses in it, then the table's far edge and a gingham
## cloth in rose and cream from there past the foot of the screen, its checks
## widening toward the player.
##
## The board says where its lines stand (`set_lines`): the cloth's far edge
## and the foot of the cups. One mesh, built when the rect or a line changes
## and kept (`_shown`) until the next replaces it, drawn past the top of the
## rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("fdf6e8")
const SKY_LOW := Color("f6ecdc")
const SUN := Color("fff1c8")
const HEDGE := Color("86b166")
const HEDGE_DEEP := Color("6a9a4f")
const ROSE := Color("ee9aa6")
const ROSE_DEEP := Color("d97786")
const STRING := Color("b49a7c")
const FLAGS := [Color("f2b6bf"), Color("a9d3e8"), Color("f7d98a"), Color("bfdca0")]
const EDGE := Color("e7cfc3")
const CLOTH := Color("fbf3ea")
const CLOTH_LOW := Color("f4e6d8")
const CHECK := Color("f2c9cc")
const HEM := Color("e8b3b8")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6
## A check of the cloth at its far edge, at W.
const CHECK_W := 90.0

var _edge := 0.0
var _foot := 0.0
var _built := Vector2(-1, -1)
var _built_size := Vector2.ZERO
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the cloth's far edge and the cups' foot.
## The picture is built again only when one moved.
func set_lines(edge: float, foot: float) -> void:
	_edge = edge
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _edge <= 0.0:
		return
	var lines := Vector2(_edge, _foot)
	if lines == _built and size == _built_size:
		return
	_built = lines
	_built_size = size
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _edge + 2.0), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.05, _edge)
	var sun := Vector2(w * 0.18, _edge * 0.4)
	for ring: Array in [[260.0, 0.10], [170.0, 0.14], [110.0, 0.2]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	# the hedge behind the table, roses in it
	var top := _edge - 110.0 * u
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	var x := -30.0 * u
	while x < w + 40.0 * u:
		var r := rng.randf_range(44.0, 66.0) * u
		b.disc(Vector2(x, top + 14.0 * u), r, HEDGE_DEEP)
		b.disc(Vector2(x - r * 0.15, top + 6.0 * u), r * 0.86, HEDGE)
		x += r * 1.1
	b.polygon(_rect(-8.0, top + 20.0 * u, w + 8.0, _edge + 2.0), HEDGE_DEEP)
	for k in 9:
		var at := Vector2(w * (0.05 + k * 0.115) + rng.randf_range(-16.0, 16.0) * u, top + rng.randf_range(-10.0, 50.0) * u)
		_rose(b, at, rng.randf_range(10.0, 14.0) * u)
	# the bunting across the sky
	_bunting(b, w, maxf(_edge - 230.0 * u, 40.0 * u), u)
	# the table's far edge, then the cloth to past the foot
	b.polygon(_rect(-8.0, _edge - 6.0 * u, w + 8.0, _edge + 14.0 * u), EDGE)
	first = b.verts.size()
	b.polygon(_rect(-8.0, _edge + 8.0 * u, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, CLOTH, CLOTH_LOW, _edge, h)
	_checks(b, w, h, u)
	# a lace hem at the far edge
	var hem := 26.0 * u
	var hx := -hem * 0.5
	while hx < w + hem:
		b.disc(Vector2(hx, _edge + 10.0 * u), hem * 0.42, Color(HEM, 0.75))
		b.disc(Vector2(hx, _edge + 10.0 * u), hem * 0.16, CLOTH)
		hx += hem
	Scenery.soft_disc(b, Vector2(w * 0.5, _edge + 20.0 * u), w * 0.6, 22.0 * u, Color(EDGE, 0.5))
	_shown = b.mesh()
	queue_redraw()

## The gingham: bands of rose across and down, laid at half strength so
## where two cross reads the deeper check.
func _checks(b: Face.Builder, w: float, h: float, u: float) -> void:
	var y := _edge + 22.0 * u
	var row := 0
	while y < h + 60.0 * u:
		var k := 1.0 + (y - _edge) / maxf(h - _edge, 1.0) * 0.35
		var ch := CHECK_W * u * k * 0.72
		if row % 2 == 0:
			b.polygon(_rect(-8.0, y, w + 8.0, y + ch), Color(CHECK, 0.5))
		y += ch
		row += 1
	var cw := CHECK_W * u
	var col := 0
	var cx := w * 0.5 - cw * 0.5 - cw * 6.0
	while cx < w + cw:
		if col % 2 == 0:
			# each band fans out a little toward the player
			var spread := (cx + cw * 0.5 - w * 0.5) / (w * 0.5) * 0.12
			b.polygon(PackedVector2Array([Vector2(cx, _edge + 22.0 * u), Vector2(cx + cw, _edge + 22.0 * u),
				Vector2(cx + cw + spread * (h - _edge), h + 60.0 * u + 0.0), Vector2(cx + spread * (h - _edge), h + 60.0 * u)]),
				Color(CHECK, 0.5))
		cx += cw
		col += 1

func _bunting(b: Face.Builder, w: float, y: float, u: float) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		pts.append(Vector2(lerpf(-10.0, w + 10.0, t), y + sin(t * PI) * 30.0 * u))
	b.stroke(pts, 3.0 * u, STRING)
	for i in range(1, 24, 2):
		var a := pts[i]
		var c := pts[i + 1]
		var mid := (a + c) * 0.5 + Vector2(0.0, 44.0 * u)
		b.polygon(PackedVector2Array([a, c, mid]), FLAGS[(i / 2) % FLAGS.size()])

func _rose(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at, r, ROSE_DEEP)
	b.disc(at - Vector2(r * 0.12, r * 0.12), r * 0.78, ROSE)
	b.stroke(Face.Builder.arc_points(at, r * 0.42, 0.0, PI * 1.4), r * 0.16, Color(ROSE_DEEP, 0.8), false, false)

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
