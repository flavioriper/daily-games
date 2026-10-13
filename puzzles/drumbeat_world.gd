extends Control

## Drumbeat's world: the festival's evening, edge to edge under the board
## and the host's rows (CLAUDE.md: a game's world fills the screen). It is
## what the board's card held, at the size of the screen: the sky the stage
## stands in and the mat the drums stand on.
##
## The sky is light at the top of the screen, where the wordmark, the motto
## and the win's "Well done!" are ink with no scrim, and warms down to the
## stage's own apricot at the horizon, with the sun going down behind the
## hills the board draws. The mat runs from the horizon to the foot of the
## screen (the road and the drums lie over it), woven in faint bands, with a
## stitched hem, a pair of sticks, a tambourine and the party's confetti in
## the strip under the drums' feet.
##
## The board says where its lines stand (`set_lines`), since the stage is as
## tall as the screen leaves it. One mesh, built when the rect or a line
## changes and kept (`_shown`) until the next replaces it; three early
## stars are a second, on a child whose alpha breathes (still under
## Motion.reduce). Both are drawn past the top of the rect: on the win the
## board tilts down and the world rides with it.

const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The evening, top to horizon: cream, the menu card's apricot, the stage's
## own low sky (drumbeat2d.gd's SKY_LOW).
const SKY_HIGH := Color("fdf4e3")
const SKY_MID := Color("f9d3ab")
const SKY_LOW := Color("f2a37a")
const SUN := Color("fff1c8")
const CLOUD := Color("fde9d2")
## The festival mat (the card's ground), and its foot.
const MAT := Color("e8dcc4")
const MAT_LOW := Color("dfcfb1")
const WEAVE := Color("b79a6c")
const INK := Color("4a3426")
const WOOD := Color("8a5c3a")
const STICK := Color("c98f5a")
const CREAM := Color("fff6e6")
const GOLD := Color("f2c14e")
const CONFETTI := [Color("f2c14e"), Color("f08aa6"), Color("8cc8ec"), Color("f59a6a"), Color("b7e07a"), Color("c9a0f0")]
## How far past the top the sky is drawn, as a share of the height: the
## win's tilt brings it into the screen.
const OVER := 0.6
## The setting sun's middle along the horizon, as a share of the width, and
## its glow's rings: [radius at W, alpha].
const SUN_X := 0.70
const SUN_RINGS := [[420.0, 0.10], [290.0, 0.12], [180.0, 0.18]]
## A cloud in the gap of the tools row: [x, y as shares, radius at W].
const CLOUDS := [[0.56, 0.232, 30.0]]
## The early stars that twinkle, in the gap of the tools row and high over
## the stage: [x as a share, y as a share of the way from the top to the
## stage's sky, radius at W].
const SPARKS := [[0.405, 0.86, 13.0], [0.70, 0.81, 10.0], [0.93, 1.16, 11.0]]
const TWINKLE := 3.4
const TWINKLE_LOW := 0.3

## The stage's top, the horizon (the road's top) and the road's foot, in
## this rect's own pixels.
var _sky_y := 0.0
var _horizon := 0.0
var _road_foot := 0.0
var _built := Vector3(-1, -1, -1)
var _built_size := Vector2.ZERO
var _shown: ArrayMesh
var _sparks: Control
var _sparks_shown: ArrayMesh
var _twinkle: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks = Control.new()
	_sparks.name = "Sparks"
	_sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sparks.draw.connect(func() -> void:
		if _sparks_shown != null:
			_sparks.draw_mesh(_sparks_shown, null))
	add_child(_sparks)
	resized.connect(_build)
	_build()
	_twinkle = Motion.pulse(_sparks, "modulate:a", 1.0, TWINKLE_LOW, TWINKLE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand; the picture is built again only when one
## of them moved.
func set_lines(sky_y: float, horizon: float, road_foot: float) -> void:
	_sky_y = sky_y
	_horizon = horizon
	_road_foot = road_foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _horizon <= 0.0:
		return
	var lines := Vector3(_sky_y, _horizon, _road_foot)
	if lines == _built and size == _built_size:
		return
	_built = lines
	_built_size = size
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	# The sky: cream over the host's rows, apricot by the stage's top, the
	# stage's own low sky at the horizon.
	var top := -h * OVER
	var first := b.verts.size()
	b.polygon(_rect(-8.0, top, w + 8.0, _sky_y + 1.0), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_MID, h * 0.10, _sky_y)
	first = b.verts.size()
	b.polygon(_rect(-8.0, _sky_y, w + 8.0, _horizon + 2.0), Color.WHITE)
	CardFace.shade(b, first, SKY_MID, SKY_LOW, _sky_y, _horizon)
	# The sun going down behind the hills.
	var sun := Vector2(w * SUN_X, _horizon - 40.0 * u)
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(SUN, ring[1]))
	b.disc(sun, 86.0 * u, Color(SUN, 0.85))
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	# The mat, from the horizon to past the foot of the screen.
	first = b.verts.size()
	b.polygon(_rect(-8.0, _horizon, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, MAT, MAT_LOW, _road_foot, h)
	# Woven in faint bands under the drums.
	var y := _road_foot + 70.0 * u
	while y < h - 60.0 * u:
		b.polygon(_rect(-8.0, y, w + 8.0, y + 5.0 * u), Color(WEAVE, 0.07))
		y += 96.0 * u
	# The hem: two rows of stitches along the foot.
	_stitches(b, h - 30.0 * u, u, 0.34)
	_stitches(b, h - 46.0 * u, u, 0.18)
	# In the strip under the drums' feet: a pair of sticks, a tambourine and
	# the party's confetti.
	var strip := h - 92.0 * u
	_sticks(b, Vector2(w * 0.105, strip + 6.0 * u), u)
	_tambourine(b, Vector2(w * 0.905, strip), 40.0 * u)
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	for k in 26:
		var at := Vector2(w * rng.randf_range(0.19, 0.83), h - rng.randf_range(58.0, 128.0) * u)
		_confetto(b, at, rng.randf_range(5.0, 8.5) * u, rng.randf() * TAU, CONFETTI[k % CONFETTI.size()], rng.randf_range(0.55, 0.85))
	# and a little of it blown to the mat's edges, beside the drums
	for k in 10:
		var side := 0.012 + 0.03 * rng.randf()
		var x := w * (side if k % 2 == 0 else 1.0 - side)
		var at := Vector2(x, lerpf(_road_foot + 60.0 * u, h - 150.0 * u, rng.randf()))
		_confetto(b, at, rng.randf_range(4.5, 7.0) * u, rng.randf() * TAU, CONFETTI[(k + 2) % CONFETTI.size()], 0.6)
	_shown = b.mesh()
	queue_redraw()
	var sb := Face.Builder.new()
	for s in SPARKS:
		_sparkle(sb, Vector2(w * s[0], _sky_y * s[1]), s[2] * u, Color(CREAM, 0.95))
	_sparks_shown = sb.mesh()
	_sparks.size = size
	_sparks.queue_redraw()

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

## A row of running stitches across the mat at `y`.
func _stitches(b: Face.Builder, y: float, u: float, alpha: float) -> void:
	var x := 14.0 * u
	while x < size.x - 14.0 * u:
		b.stroke(PackedVector2Array([Vector2(x, y), Vector2(x + 22.0 * u, y)]), 4.0 * u, Color(WEAVE, alpha))
		x += 40.0 * u

## Two drumsticks laid across one another, their round heads up.
func _sticks(b: Face.Builder, at: Vector2, u: float) -> void:
	for side: float in [-1.0, 1.0]:
		var foot := at + Vector2(side * 62.0, 30.0) * u
		var head := at + Vector2(-side * 62.0, -30.0) * u
		b.stroke(PackedVector2Array([foot + Vector2(0, 5.0 * u), head + Vector2(0, 5.0 * u)]), 11.0 * u, Color(INK, 0.10))
		b.stroke(PackedVector2Array([foot, head]), 11.0 * u, STICK)
		b.stroke(PackedVector2Array([foot.lerp(head, 0.12), foot.lerp(head, 0.86)]), 3.5 * u, Color(CREAM, 0.35))
		b.disc(head, 11.0 * u, CREAM)
		b.disc(head + Vector2(-3.0, -3.0) * u, 4.0 * u, Color(1, 1, 1, 0.7))

## A tambourine seen from above: a wooden hoop, its skin, five pairs of
## jingles round it.
func _tambourine(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(0, r * 0.16), r * 1.06, r * 1.0, Color(INK, 0.10))
	b.disc(at, r, WOOD)
	b.disc(at, r * 0.80, CREAM)
	b.disc(at + Vector2(-r * 0.22, -r * 0.24), r * 0.34, Color(1, 1, 1, 0.45))
	for k in 5:
		var p := at + Vector2.from_angle(-PI * 0.5 + k * TAU / 5.0) * r * 0.90
		b.disc(p, r * 0.17, GOLD.darkened(0.18))
		b.disc(p, r * 0.11, GOLD)

## One piece of confetti: a small tilted paper.
func _confetto(b: Face.Builder, at: Vector2, r: float, turn: float, colour: Color, alpha: float) -> void:
	var pts := PackedVector2Array()
	for p: Vector2 in [Vector2(-1.0, -0.55), Vector2(1.0, -0.55), Vector2(1.0, 0.55), Vector2(-1.0, 0.55)]:
		pts.append(at + (p * r).rotated(turn))
	b.polygon(pts, Color(colour, alpha))

## A four-pointed star of `r`, its waist pinched (the menu cards').
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
