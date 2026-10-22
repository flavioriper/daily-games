extends Control

## Hosepipes' world: a back garden, edge to edge under the board and the
## host's rows (CLAUDE.md: a game's world fills the screen). A pale sky
## across the top, where the wordmark, the motto and the win's "Well done!"
## are ink with no scrim, with soft hills far off and a white picket fence
## along the lawn's back; then the lawn the raised bed stands on, a few
## tufts and daisies about it, and stepping stones running off past the
## foot.
##
## The board says where the bed stands (`set_bed`, the frame's outer rect);
## the lawn's mown stripes and the bed's cast shadow follow it. One mesh,
## built when the rect or the bed moves and kept (`_shown`) until the next
## replaces it, drawn past the top of the rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("e2f0f3")
const SKY_LOW := Color("f6f1e3")
const SUN := Color("fff1c8")
const HILL := Color("c4dca2")
const HILL_DEEP := Color("aacb8c")
const LAWN := Color("a9cf84")
const LAWN_LOW := Color("94c070")
const STRIPE := Color("b4d78f")
const FENCE := Color("fbf6ea")
const FENCE_DEEP := Color("ded5c2")
const STONE := Color("ddd5c4")
const STONE_DEEP := Color("bfb5a2")
const DAISY := Color("fffaf0")
const DAISY_EYE := Color("f2c94c")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6

var _bed := Rect2()
var _horizon := 0.0
var _built := ""
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the bed's frame stands and where the lawn begins (under the host's
## top rows). The picture is built again only when one moved.
func set_bed(bed: Rect2, horizon: float) -> void:
	_bed = bed
	_horizon = horizon
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _bed.size.x <= 0.0:
		return
	var key := "%d:%d:%s:%d" % [roundi(size.x), roundi(size.y), str(_bed), roundi(_horizon)]
	if key == _built:
		return
	_built = key
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var top := minf(_horizon, _bed.position.y - 60.0 * u)
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, top + 40.0 * u), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.02, top)
	var sun := Vector2(w * 0.84, top * 0.42)
	for ring: Array in [[220.0, 0.12], [140.0, 0.16], [90.0, 0.22]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	b.ellipse(Vector2(w * 0.18, top + 10.0 * u), w * 0.48, 80.0 * u, HILL_DEEP)
	b.ellipse(Vector2(w * 0.78, top + 18.0 * u), w * 0.56, 72.0 * u, HILL)
	# the lawn, mown in broad stripes
	first = b.verts.size()
	b.polygon(_rect(-8.0, top, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, LAWN, LAWN_LOW, top, h)
	var sx := -60.0 * u
	while sx < w + 60.0 * u:
		b.polygon(PackedVector2Array([Vector2(sx, top), Vector2(sx + 70.0 * u, top),
			Vector2(sx + 130.0 * u, h + 240.0 * u), Vector2(sx + 60.0 * u, h + 240.0 * u)]), Color(STRIPE, 0.45))
		sx += 200.0 * u
	# the picket fence along the lawn's back
	var fy := top
	b.polygon(_rect(-8.0, fy - 34.0 * u, w + 8.0, fy - 24.0 * u), FENCE_DEEP)
	b.polygon(_rect(-8.0, fy - 62.0 * u, w + 8.0, fy - 52.0 * u), FENCE_DEEP)
	var px := 10.0 * u
	while px < w:
		var pw := 26.0 * u
		var pts := PackedVector2Array([Vector2(px, fy + 4.0 * u), Vector2(px, fy - 80.0 * u),
			Vector2(px + pw * 0.5, fy - 94.0 * u), Vector2(px + pw, fy - 80.0 * u), Vector2(px + pw, fy + 4.0 * u)])
		b.polygon(pts, FENCE)
		b.polygon(_rect(px + pw * 0.7, fy - 82.0 * u, px + pw, fy + 4.0 * u), FENCE_DEEP)
		px += 52.0 * u
	Scenery.soft_disc(b, Vector2(w * 0.5, fy + 8.0 * u), w * 0.6, 14.0 * u, Color(LAWN_LOW, 0.6))
	# the bed's shadow on the lawn
	Scenery.soft_disc(b, _bed.get_center() + Vector2(0.0, _bed.size.y * 0.06), _bed.size.x * 0.58, _bed.size.y * 0.56, Color(0.25, 0.3, 0.15, 0.14))
	# tufts and daisies about the bed, never on it
	var rng := RandomNumberGenerator.new()
	rng.seed = 1022
	var placed := 0
	var tries := 0
	while placed < 16 and tries < 200:
		tries += 1
		var p := Vector2(rng.randf_range(30.0, w - 30.0), rng.randf_range(top + 30.0 * u, h - 20.0 * u))
		if _bed.grow(40.0 * u).has_point(p):
			continue
		placed += 1
		if rng.randf() < 0.55:
			Scenery.tuft(b, p, rng.randf_range(18.0, 30.0) * u)
		else:
			_daisy(b, p, rng.randf_range(9.0, 13.0) * u)
	# stepping stones from under the bed off past the foot
	var sy := _bed.end.y + 50.0 * u
	var k := 0
	while sy < h + 60.0 * u:
		var c := Vector2(w * 0.5 + (60.0 if k % 2 == 0 else -50.0) * u, sy)
		b.ellipse(c + Vector2(0.0, 6.0 * u), 70.0 * u, 30.0 * u, STONE_DEEP)
		b.ellipse(c, 68.0 * u, 28.0 * u, STONE)
		sy += 92.0 * u
		k += 1
	_shown = b.mesh()
	queue_redraw()

func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for k in 6:
		b.disc(at + Vector2.RIGHT.rotated(k * TAU / 6.0) * r * 0.75, r * 0.5, DAISY)
	b.disc(at, r * 0.45, DAISY_EYE)

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
