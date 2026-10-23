extends Control

## Picket Sums' world: the allotment the raised bed stands in, edge to edge
## under the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). A soft morning light in the wordmark's corner, a lawn mown in
## faint stripes, a white picket fence across the gap of the tools row with
## daisies at its foot, clover dotted over the lawn, and the bed's wooden
## rail under everything. The digit pad is the host's and stands over the
## foot, so nothing but lawn lies there.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the dew is a second, on a child whose alpha breathes (still
## under Motion.reduce), as Sudoku's desk's glints do.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const LAWN_TOP := Color("f3f6e6")
const LAWN_LOW := Color("d5e4bd")
const STRIPE := Color("8fb36a")
const STRIPE_A := 0.07
const STRIPE_W := 120.0
## The fence behind the tools row is a far one, low and pale, so the
## buttons stand clear of it rather than on its posts.
const PICKET := Color("fbfaf1")
const PICKET_SHADE := Color("ebe8da")
const PICKET_EDGE := Color("d6cfbd")
const WOOD := Color("c9a57c")
const WOOD_DEEP := Color("9c7350")
const PETAL := Color("fffdf8")
const POLLEN := Color("f5b63c")
const CLOVER := Color("7fae5a")
## The light, as shares of the rect, and its rings [radius at W, alpha].
const LIGHT_AT := Vector2(0.09, 0.02)
const LIGHT := [[720.0, 0.22], [480.0, 0.22], [280.0, 0.28]]
## The fence: its foot as a share of the height, its pickets at W.
const FENCE_FOOT := 0.262
const FENCE_H := 44.0
const PICKET_W := 26.0
const PICKET_STEP := 44.0
## Daisies at the fence's foot: [x share, radius at W].
const DAISIES := [[0.07, 15.0], [0.21, 11.0], [0.46, 13.0], [0.71, 12.0], [0.9, 16.0]]
## Clover over the lawn: [x, y shares, radius at W].
const CLOVERS := [[0.06, 0.40, 9.0], [0.95, 0.47, 8.0], [0.04, 0.69, 10.0], [0.96, 0.78, 9.0],
	[0.08, 0.86, 7.0], [0.93, 0.33, 7.0]]
## The dew that breathes: [x, y as shares, radius at W].
const DEW := [[0.18, 0.205, 8.0], [0.62, 0.21, 7.0], [0.84, 0.215, 6.0]]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _dew: Control
var _dew_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dew = Control.new()
	_dew.name = "Dew"
	_dew.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dew.draw.connect(func() -> void:
		if _dew_shown != null:
			_dew.draw_mesh(_dew_shown, null))
	add_child(_dew)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_dew, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_box(Vector2(-8.0, -8.0), size + Vector2(16.0, 16.0)), Color.WHITE)
	CardFace.shade(b, first, LAWN_TOP, LAWN_LOW, 0.0, size.y)
	for ring in LIGHT:
		b.disc(LIGHT_AT * size, ring[0] * u, Color(PETAL, ring[1]))
	# The lawn's mown stripes, below the fence.
	var foot := size.y * FENCE_FOOT
	var sw := STRIPE_W * u
	var x := size.x * 0.5 - sw * 0.5
	while x > -sw:
		x -= 2.0 * sw
	while x < size.x + sw:
		b.polygon(_box(Vector2(x, foot), Vector2(sw, size.y - foot)), Color(STRIPE, STRIPE_A))
		x += 2.0 * sw
	# The fence: two rails behind a row of pointed pickets, their shadow on
	# the lawn.
	var h := FENCE_H * u
	b.polygon(_box(Vector2(-8.0, foot), Vector2(size.x + 16.0, 10.0 * u)), Color(Pal.TEXT, 0.06))
	for rail in [0.3, 0.72]:
		var ry: float = foot - h * rail
		b.polygon(_box(Vector2(-8.0, ry - 5.0 * u), Vector2(size.x + 16.0, 10.0 * u)), PICKET_SHADE)
		b.polygon(_box(Vector2(-8.0, ry - 5.0 * u), Vector2(size.x + 16.0, 2.5 * u)), Color(PICKET_EDGE, 0.5))
	var pw := PICKET_W * u
	var px := fmod(size.x * 0.5, PICKET_STEP * u) - PICKET_STEP * u
	while px < size.x + pw:
		var tip := Vector2(px + pw * 0.5, foot - h)
		var pts := PackedVector2Array([Vector2(px, foot), Vector2(px, tip.y + pw * 0.5), tip,
			Vector2(px + pw, tip.y + pw * 0.5), Vector2(px + pw, foot)])
		b.polygon(pts, PICKET_EDGE)
		var inner := PackedVector2Array()
		for p in pts:
			inner.append(p + (Vector2(px + pw * 0.5, foot - h * 0.4) - p).normalized() * 2.2 * u)
		b.polygon(inner, PICKET)
		b.polygon(_box(Vector2(px + pw * 0.62, tip.y + pw * 0.6), Vector2(pw * 0.22, h - pw * 0.7)),
			Color(PICKET_SHADE, 0.8))
		px += PICKET_STEP * u
	for d in DAISIES:
		_daisy(b, Vector2(d[0] * size.x, foot + 4.0 * u), d[1] * u)
	for c in CLOVERS:
		_clover(b, Vector2(c[0], c[1]) * size, c[2] * u)
	# The raised bed's rail under everything.
	var rail := 26.0 * u
	b.polygon(_box(Vector2(-8.0, size.y - rail), Vector2(size.x + 16.0, rail + 8.0)), WOOD)
	b.polygon(_box(Vector2(-8.0, size.y - rail), Vector2(size.x + 16.0, 5.0 * u)), Color(PETAL, 0.35))
	b.polygon(_box(Vector2(-8.0, size.y - 7.0 * u), Vector2(size.x + 16.0, 15.0 * u)), WOOD_DEEP)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g in DEW:
		_sparkle(gb, Vector2(g[0], g[1]) * size, g[2] * u, Color(PETAL, 0.95))
	_dew_shown = gb.mesh()
	_dew.size = size
	_dew.queue_redraw()

func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

## A daisy: eight petals round a gold middle, over its shadow.
func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.18), r * 1.02, Color(Pal.TEXT, 0.08))
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		b.disc(at + dir * r * 0.58, r * 0.42, PETAL)
	b.disc(at, r * 0.36, POLLEN)

## Three round leaves of clover.
func _clover(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 3:
		var dir := Vector2.from_angle(-PI * 0.5 + i * TAU / 3.0)
		b.disc(at + dir * r * 0.55, r * 0.55, Color(CLOVER, 0.55))

## A four-pointed star of `r`, its waist pinched.
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
