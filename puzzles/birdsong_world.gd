extends Control

## Birdsong's world: a spring morning in the garden, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## Since the woodpecker (2026-10-22 evening) the old tree is a broad trunk
## at the left, its right side straight from the leaves to the lawn so the
## woodpecker clings to it (`trunk_edge`), with a knot hole in its bark.
## The sky is cream across the top, where the wordmark, the motto and the
## win's "Well done!" are ink with no scrim, and clears to a pale morning
## blue at the hills; a low sun, a cloud in the gap of the tools row. The
## old tree stands at the left edge, its trunk to the lawn and its leaves
## over the top. The lawn runs from the hills past the foot, with daisies
## and tufts where the drum does not stand.
##
## The board says where its lines stand (`set_lines`): the horizon and the
## lawn where the drums' feet are. One mesh, built when the rect or a line
## changes and kept (`_shown`) until the next replaces it, drawn past the top
## of the rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("fdf6e8")
const SKY_LOW := Color("dcedf6")
const SUN := Color("fff1c8")
const CLOUD := Color("ffffff")
const HILL_FAR := Color("c9dfb4")
const HILL_NEAR := Color("b3d39a")
const LAWN := Color("a9cf8a")
const LAWN_LOW := Color("93bf74")
const TRUNK := Color("8a5c3a")
const TRUNK_DEEP := Color("6f4a31")
const BARK := Color("a4744d")
const CROWN := Color("7fb35a")
const CROWN_DEEP := Color("5f9442")
const CROWN_HI := Color("a5cf74")
const DAISY := Color("fffaf0")
const DAISY_EYE := Color("f5c242")
const BLOSSOM := Color("f6c6d0")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6
## The trunk's middle, as a share of the width, and its half width at W.
const TRUNK_X := 0.1
const TRUNK_W := 120.0
## A cloud: [x as a share, y as a share of the horizon, radius at W].
const CLOUDS := [[0.62, 0.30, 30.0], [0.88, 0.52, 22.0]]

var _horizon := 0.0
var _lawn := 0.0
var _built := Vector2(-1, -1)
var _built_size := Vector2.ZERO
var _shown: ArrayMesh

## The trunk's right side, where the woodpecker clings, at width `w`.
static func trunk_edge(w: float) -> float:
	return w * TRUNK_X + TRUNK_W * w / W

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the hills' foot and the lawn under the
## drums. The picture is built again only when one moved.
func set_lines(horizon: float, lawn: float) -> void:
	_horizon = horizon
	_lawn = lawn
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _horizon <= 0.0:
		return
	var lines := Vector2(_horizon, _lawn)
	if lines == _built and size == _built_size:
		return
	_built = lines
	_built_size = size
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _horizon + 2.0), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.08, _horizon)
	# A low morning sun over the far hills, a soft glow round it.
	var sun := Vector2(w * 0.78, _horizon - 150.0 * u)
	for ring: Array in [[300.0, 0.10], [200.0, 0.14], [130.0, 0.2]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	b.disc(sun, 72.0 * u, Color(SUN, 0.9))
	for c: Array in CLOUDS:
		Scenery.cloud(b, Vector2(w * float(c[0]), _horizon * float(c[1])), float(c[2]) * u, Color(CLOUD, 0.85))
	# The hills, far and near.
	b.polygon(_hill(_horizon - 70.0 * u, 90.0 * u, 0.7, w, h), HILL_FAR)
	b.polygon(_hill(_horizon - 18.0 * u, 70.0 * u, 2.1, w, h), HILL_NEAR)
	# The lawn, from the hills past the foot.
	first = b.verts.size()
	b.polygon(_rect(-8.0, _horizon, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, LAWN, LAWN_LOW, _horizon, h)
	# The old tree at the left edge: its trunk, its bark, and its leaves over
	# the top of the screen (the branch is the board's).
	var tx := w * TRUNK_X
	var tw := TRUNK_W * u
	var foot := _horizon + 40.0 * u
	var trunk := PackedVector2Array([Vector2(tx - tw, -h * OVER), Vector2(tx + tw, -h * OVER),
		Vector2(tx + tw, foot - 70.0 * u), Vector2(tx + tw * 1.45, foot + 26.0 * u),
		Vector2(tx - tw * 1.5, foot + 26.0 * u), Vector2(tx - tw * 1.05, foot - 70.0 * u)])
	Scenery.soft_disc(b, Vector2(tx + 30.0 * u, foot + 26.0 * u), 260.0 * u, 26.0 * u, Color(TRUNK_DEEP, 0.25))
	b.polygon(trunk, TRUNK_DEEP)
	b.polygon(_inset(trunk, 8.0 * u), TRUNK)
	# the light down its middle, the bark's long grain
	b.polygon(PackedVector2Array([Vector2(tx - tw * 0.2, -h * OVER), Vector2(tx + tw * 0.35, -h * OVER),
		Vector2(tx + tw * 0.35, foot - 40.0 * u), Vector2(tx - tw * 0.2, foot - 40.0 * u)]), Color(BARK, 0.45))
	for k in 7:
		var x0 := tx + lerpf(-0.75, 0.75, k / 6.0) * tw
		var pts := PackedVector2Array()
		for i in 15:
			var y := lerpf(-h * 0.1, foot - 50.0 * u, i / 14.0)
			pts.append(Vector2(x0 + sin(y / (90.0 * u) + k) * 9.0 * u, y))
		b.stroke(pts, 5.0 * u, Color(TRUNK_DEEP, 0.4))
	# a knot hole, high on the trunk
	var knot := Vector2(tx - tw * 0.25, _horizon * 0.33)
	b.ellipse(knot, 34.0 * u, 52.0 * u, Color("5a3a24"))
	b.ellipse(knot + Vector2(4.0, 6.0) * u, 17.0 * u, 31.0 * u, Color("3e2818"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for k in 9:
		var at := Vector2(tx + rng.randf_range(-120.0, 420.0) * u, rng.randf_range(-h * 0.2, h * 0.05))
		var r := rng.randf_range(80.0, 130.0) * u
		b.disc(at + Vector2(0, 10.0 * u), r, CROWN_DEEP)
		b.disc(at, r * 0.94, CROWN)
		b.disc(at + Vector2(-r * 0.3, -r * 0.3), r * 0.4, Color(CROWN_HI, 0.7))
	for k in 7:
		var at := Vector2(tx + rng.randf_range(20.0, 420.0) * u, rng.randf_range(0.0, h * 0.07))
		_blossom(b, at, rng.randf_range(9.0, 13.0) * u)
	# Daisies and tufts on the lawn, round the drum and never on it.
	for k in 26:
		var at := Vector2(rng.randf_range(0.04, 0.98) * w, rng.randf_range(_horizon + 50.0 * u, h - 20.0 * u))
		if absf(at.x - w * 0.5) < 320.0 * u and at.y > _lawn - 330.0 * u and at.y < _lawn + 60.0 * u:
			continue
		if at.x < tx + tw * 1.6 and at.y < foot + 40.0 * u:
			continue
		if k % 3 == 0:
			Scenery.tuft(b, at, rng.randf_range(16.0, 24.0) * u)
		else:
			_daisy(b, at, rng.randf_range(7.0, 10.0) * u)
	_shown = b.mesh()
	queue_redraw()

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

## A rolling line of hills whose top rests about `y`, down to past the foot.
func _hill(y: float, rise: float, phase: float, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	for i in n + 1:
		var x := -8.0 + (w + 16.0) * i / n
		var t := float(i) / n
		pts.append(Vector2(x, y - rise * (0.5 + 0.5 * sin(t * TAU * 1.3 + phase)) * (0.6 + 0.4 * sin(t * 5.0 + phase))))
	pts.append(Vector2(w + 8.0, h + 60.0))
	pts.append(Vector2(-8.0, h + 60.0))
	return pts

## A polygon pulled `by` toward its middle.
func _inset(pts: PackedVector2Array, by: float) -> PackedVector2Array:
	var mid := Vector2.ZERO
	for p in pts:
		mid += p
	mid /= pts.size()
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + (mid - p).normalized() * by)
	return out

func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 6:
		b.ellipse(at + Vector2.from_angle(i * TAU / 6.0) * r * 0.9, r * 0.55, r * 0.55, DAISY)
	b.disc(at, r * 0.5, DAISY_EYE)

func _blossom(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(i * TAU / 5.0 - PI * 0.5) * r * 0.7, r * 0.6, BLOSSOM)
	b.disc(at, r * 0.35, DAISY_EYE)
