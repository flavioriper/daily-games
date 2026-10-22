extends Control

## Who Ate the Pie?'s world: the village fête, edge to edge under the board
## and the host's rows (CLAUDE.md: a game's world fills the screen). A pale
## sky across the top, where the wordmark, the motto and the win's "Well
## done!" are ink with no scrim, a far hedge and a string of bunting; then
## the long bake-sale table the bakers' cards lie on, a berry gingham cloth
## hanging over its front edge, and the lawn past the foot.
##
## The board says where its lines stand (`set_lines`): the cloth's far edge
## and its hem. One mesh, built when the rect or a line changes and kept
## (`_shown`) until the next replaces it, drawn past the top of the rect for
## the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("e2f0f6")
const SKY_LOW := Color("f9f2e3")
const SUN := Color("fff1c8")
const HEDGE := Color("a9cc8c")
const HEDGE_DEEP := Color("8fb874")
const CLOTH := Color("fbf3e8")
const CHECK := Color("f0c2bb")
const CHECK_DEEP := Color("e39d94")
const HEM := Color("d98378")
const LAWN := Color("bcd89a")
const LAWN_LOW := Color("a7ca86")
const STRING := Color("9a7b5a")
const FLAGS := [Color("ee9a8e"), Color("f5c96b"), Color("8fc6de"), Color("a9cc8c"), Color("e58fb5")]
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6
## A gingham square, at W.
const SQUARE := 54.0

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

## Where the board's lines stand: the cloth's far edge and its hem. The
## picture is built again only when one moved.
func set_lines(edge: float, foot: float) -> void:
	_edge = edge
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _foot <= 0.0:
		return
	var key := "%d:%d:%d:%d" % [roundi(size.x), roundi(size.y), roundi(_edge), roundi(_foot)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _edge + 10.0 * u), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.04, _edge)
	var sun := Vector2(w * 0.16, _edge * 0.4)
	for ring: Array in [[220.0, 0.12], [140.0, 0.16], [90.0, 0.22]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	# the far hedge, its top a row of soft bumps
	var hx := -40.0 * u
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	while hx < w + 60.0 * u:
		b.disc(Vector2(hx, _edge - 24.0 * u), rng.randf_range(46.0, 64.0) * u, HEDGE_DEEP)
		hx += 70.0 * u
	hx = -10.0 * u
	while hx < w + 60.0 * u:
		b.disc(Vector2(hx, _edge - 8.0 * u), rng.randf_range(40.0, 56.0) * u, HEDGE)
		hx += 76.0 * u
	_bunting(b, w, maxf(30.0 * u, _edge - 150.0 * u), u)
	# the cloth: gingham from the far edge to the hem
	first = b.verts.size()
	b.polygon(_rect(-8.0, _edge, w + 8.0, _foot), CLOTH)
	var sq := SQUARE * u
	var x := 0.0
	var i := 0
	while x < w:
		if i % 2 == 0:
			b.polygon(_rect(x, _edge, x + sq, _foot), Color(CHECK, 0.55))
		x += sq
		i += 1
	var y := _edge
	i = 0
	while y < _foot:
		if i % 2 == 0:
			b.polygon(_rect(-8.0, y, w + 8.0, minf(y + sq, _foot)), Color(CHECK, 0.55))
		y += sq
		i += 1
	# the shade under the far edge
	Scenery.soft_disc(b, Vector2(w * 0.5, _edge + 6.0 * u), w * 0.7, 16.0 * u, Color(CHECK_DEEP, 0.3))
	# the hem: the cloth hanging over the table's front edge, scalloped
	b.polygon(_rect(-8.0, _foot, w + 8.0, _foot + 36.0 * u), HEM)
	var sw := 60.0 * u
	var sx := 0.0
	while sx < w + sw:
		b.fan(Face.Builder.arc_points(Vector2(sx, _foot + 36.0 * u), sw * 0.5, 0.0, PI), HEM)
		sx += sw
	# the lawn past the foot
	first = b.verts.size()
	var lawn := _foot + 36.0 * u
	b.polygon(_rect(-8.0, lawn + sw * 0.4, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, LAWN, LAWN_LOW, lawn, h)
	# a few tufts on the lawn
	var tx := 50.0 * u
	while tx < w:
		var ty := lawn + sw * 0.6 + rng.randf_range(20.0, 120.0) * u
		if ty < h - 10.0 * u:
			Scenery.tuft(b, Vector2(tx, ty), 22.0 * u)
		tx += rng.randf_range(140.0, 220.0) * u
	_shown = b.mesh()
	queue_redraw()

## A string of flags across the sky, sagging between two posts off screen.
func _bunting(b: Face.Builder, w: float, y: float, u: float) -> void:
	var pts := Face.Builder.bezier2(Vector2(-20.0 * u, y), Vector2(w * 0.5, y + 70.0 * u), Vector2(w + 20.0 * u, y))
	b.stroke(pts, 3.0 * u, STRING)
	var n := 13
	for k in n:
		var t := (k + 0.5) / n
		var p := pts[int(t * (pts.size() - 1))]
		var fw := 26.0 * u
		var c: Color = FLAGS[k % FLAGS.size()]
		b.polygon(PackedVector2Array([p + Vector2(-fw, 0.0), p + Vector2(fw, 0.0), p + Vector2(0.0, fw * 1.6)]), c)

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
