extends Control

## Balance's world: the meadow the seesaw stands in, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/balance.gd) at the size of
## the screen: a pale morning sky with one far cloud in the gap of the tools
## row, three far hills with their trees on the horizon, and the meadow from
## there down to the foot, its flowers along the horizon and across the open
## grass under the basket.
##
## The sky keeps the top of the screen because of what lies over it: the
## wordmark, the motto and the win's "Well done!" are ink with no scrim.
##
## The board says where the grass begins (`set_ground`), the same line for
## every level, so a change of level leaves the world as it is. Nothing here
## is measured in the board's cups for the same reason.
##
## Two meshes, each built when the rect or the ground changes and kept until
## the next replaces it: the sky, drawn here, and the land, on a child. The
## board's own sky (its sun, the evening, the stars, the rainbow) is a layer
## it hands over (`add_sky`) to lie between the two, so the sun still goes
## down behind the far hill. They are the two the board drew for itself
## before (its sky and the land of its `still`), not two more.
##
## Both run well past the rect, above and below: on the win the board slides
## the world up or down with the seesaw (the grass stays under its feet).

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## How far past the rect the sky and the meadow run, in rect heights.
const OVER := 0.7
const SKY_HIGH := Color("e3f0f4")
const SKY_LOW := Color("f4f1df")
const CLOUD := Color("fbf8ef")
## A cloud in the gap of the tools row: [x, y as shares, radius at W].
const CLOUDS := [[0.560, 0.232, 34.0]]
## The far hills: [x as a share, how far under the grass line its middle
## lies at W, half width as a share, height at W, how far to the sky's
## colour]. The first is the one the board's sun goes down behind.
const HILLS := [
	[0.50, 30.0, 0.40, 96.0, 0.62],
	[0.18, 26.0, 0.42, 165.0, 0.45],
	[0.86, 33.0, 0.40, 132.0, 0.30],
]
## The top of the near-left hill over the grass at x 0.11, at W: where the
## board hides its sun.
const FAR_HILL_TOP := 137.0
## The trees on the hills: [x as a share, crown radius at W].
const TREES := [[0.09, 76.0], [0.93, 63.0], [0.74, 46.0]]
## Tufts along the grass line, as shares of the width.
const TUFTS := [0.06, 0.30, 0.64, 0.93]
## Flowers: [x as a share, y as a share of the meadow from the grass line to
## the foot, colour index]. A band under the horizon and a band at the foot;
## the basket and its blanket stand between.
const FLOWERS := [
	[0.10, 0.035, 0], [0.22, 0.075, 1], [0.36, 0.045, 2], [0.62, 0.060, 1],
	[0.83, 0.040, 2], [0.90, 0.090, 0], [0.47, 0.100, 0],
	[0.07, 0.900, 1], [0.19, 0.955, 0], [0.33, 0.915, 2], [0.52, 0.960, 1],
	[0.66, 0.905, 0], [0.80, 0.950, 2], [0.93, 0.910, 1],
]
## Tufts in the open grass: [x, y as the flowers', height at W].
const GRASS := [[0.04, 0.50, 30.0], [0.96, 0.45, 30.0], [0.26, 0.935, 28.0],
	[0.59, 0.925, 26.0], [0.87, 0.965, 28.0], [0.43, 0.890, 24.0]]

## Where the grass begins, in this rect's pixels.
var ground := 0.0

var _shown: ArrayMesh
var _land: Control
var _land_shown: ArrayMesh
var _built_for := Vector3.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_land = Control.new()
	_land.name = "Land"
	_land.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_land.draw.connect(func() -> void:
		if _land_shown != null:
			_land.draw_mesh(_land_shown, null))
	add_child(_land)
	resized.connect(_build)
	_build()

## The board's own sky, laid between this sky and the land.
func add_sky(layer: Control) -> void:
	add_child(layer)
	move_child(layer, 0)

func set_ground(y: float) -> void:
	if absf(y - ground) < 0.5:
		return
	ground = y
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or ground <= 0.0:
		return
	var key := Vector3(size.x, size.y, ground)
	if key == _built_for and _shown != null:
		return
	_built_for = key
	var u := size.x / W
	var w := size.x
	var over := size.y * OVER
	var b := Face.Builder.new()
	# The sky: flat above the rect, paling down to the grass line.
	_grad(b, -8.0, w + 8.0, -over, 0.0, SKY_HIGH, SKY_HIGH)
	_grad(b, -8.0, w + 8.0, 0.0, ground + 4.0, SKY_HIGH, SKY_LOW)
	for c: Array in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	_shown = b.mesh()
	queue_redraw()
	var lb := Face.Builder.new()
	for h: Array in HILLS:
		lb.ellipse(Vector2(w * h[0], ground + h[1] * u), w * h[2], h[3] * u, Pal.LAWN.lerp(SKY_LOW, h[4]))
	for t: Array in TREES:
		var foot := Vector2(w * t[0], ground - 6.0 * u)
		var r: float = t[1] * u
		lb.fan(Face.Builder.round_rect(foot + Vector2(-r * 0.12, -r * 1.6), Vector2(r * 0.24, r * 1.6), r * 0.1),
			Pal.BARK.lerp(SKY_LOW, 0.35))
		var leaf := Pal.LEAF_DEEP.lerp(SKY_LOW, 0.4)
		lb.disc(foot + Vector2(0.0, -r * 2.0), r, leaf)
		lb.disc(foot + Vector2(-r * 0.6, -r * 1.5), r * 0.7, leaf)
		lb.disc(foot + Vector2(r * 0.62, -r * 1.55), r * 0.66, leaf)
	# The meadow, deepening to the foot and flat past it.
	_grad(lb, -8.0, w + 8.0, ground, size.y, Pal.LAWN, Pal.LAWN_DEEP)
	_grad(lb, -8.0, w + 8.0, size.y, size.y + over, Pal.LAWN_DEEP, Pal.LAWN_DEEP)
	lb.fan(Face.Builder.round_rect(Vector2(-8.0, ground - 3.0), Vector2(w + 16.0, 7.0), 3.0), Pal.LAWN_DEEP.lerp(Pal.LAWN, 0.4))
	for x: float in TUFTS:
		Scenery.tuft(lb, Vector2(w * x, ground + 16.0 * u), 40.0 * u)
	var lawn := size.y - ground
	for g: Array in GRASS:
		Scenery.tuft(lb, Vector2(w * g[0], ground + lawn * g[1]), g[2] * u)
	for f: Array in FLOWERS:
		_flower(lb, Vector2(w * f[0], ground + lawn * f[1]), 13.0 * u, [Pal.FLOWER, Pal.PAPER, Pal.SUN][int(f[2])])
	_land_shown = lb.mesh()
	_land.size = size
	_land.queue_redraw()

## A band from `y0` to `y1` whose colour runs from `top` to `bottom`.
static func _grad(b: Face.Builder, x0: float, x1: float, y0: float, y1: float, top: Color, bottom: Color) -> void:
	var i0 := b.vertex(Vector2(x0, y0), top)
	var i1 := b.vertex(Vector2(x1, y0), top)
	var i2 := b.vertex(Vector2(x1, y1), bottom)
	var i3 := b.vertex(Vector2(x0, y1), bottom)
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)

## A meadow flower on its stem (the board's own).
static func _flower(b: Face.Builder, at: Vector2, r: float, petal: Color) -> void:
	b.stroke(PackedVector2Array([at, at + Vector2(0.0, r * 2.2)]), maxf(2.0, r * 0.3), Pal.LEAF_DEEP)
	for k in 5:
		var ang := TAU * k / 5.0 - PI * 0.5
		b.disc(at + Vector2(cos(ang), sin(ang)) * r * 0.8, r * 0.55, petal)
	b.disc(at, r * 0.45, Pal.SUN_DEEP)
