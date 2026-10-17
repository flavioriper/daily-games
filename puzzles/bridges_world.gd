extends Control

## Bridges' world: the sea, edge to edge under the board and the host's rows
## (CLAUDE.md: a game's world fills the screen), seen straight from above
## like the islets on it. A morning mist over the top, where the wordmark
## and the motto are ink; then calm water deepening toward the foot, a few
## broad patches of light breathing on it, and two or three lily pads tucked
## at the screen's edges, never in the board.
##
## Until 2026-10-17 the foot was a beach -- a jetty and its lantern, spare
## planks, a dinghy and an oar, rocks, tufts and a starfish -- with ripples,
## glints and a buoy over the water. The user: "it looks like a old flash
## game made in canvas ... nothing elegant". All of it went; git has it.
##
## Lantern Night (`set_night`) lays the board's dusk over all of it but the
## top, which stays light for the ink.
##
## One mesh, built when the rect or the night changes and kept (`_shown`)
## until the next replaces it; the patches of light are a second, on a child
## whose alpha breathes (still under Motion.reduce). The colours are written
## here: the board preloads this file, so this file cannot preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The air and the water, top to foot, as [share of the height, colour]:
## the mist, the shallows under the tools row, then the open water easing
## from a clear blue to a deeper teal at the foot.
const MIST_TOP := Color("fdf7ea")
const SEA_PALE := Color("a3d4e4")
const SEA := Color("74bcdc")
const SEA_LOW := Color("4f9dc4")
const STOPS := [
	[0.0, MIST_TOP], [0.09, Color("f1f4ea")], [0.17, Color("cfe8ec")],
	[0.235, SEA_PALE], [0.32, SEA], [0.62, Color("66b1d6")], [1.0, SEA_LOW],
]
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.30], [400.0, 0.35], [230.0, 0.45]]
const SUN := Color("fff1c9")
const FOAM := Color("fffdf8")
const SHADE := Color("336e99")
const PAD := Color("7fb86a")
const PAD_DEEP := Color("5f9a52")
## The night's veil (the board's NIGHT_ALPHA of MOON_DEEP) and where it
## starts and is whole, as shares of the height.
const NIGHT := Color("6273c0")
const NIGHT_ALPHA := 0.42
const NIGHT_FROM := 0.17
const NIGHT_FULL := 0.285
## The patches of light on the water: [x share, y share, radius at W].
const LIGHTS := [[0.18, 0.40, 300.0], [0.82, 0.58, 340.0], [0.30, 0.86, 380.0]]
const LIGHT_ALPHA := 0.10
## The lily pads at the edges: [x share, height over the foot at W, radius
## at W, notch turn, bloom].
const PADS := [[0.035, 120.0, 46.0, 0.7, true], [0.115, 52.0, 28.0, 2.6, false],
	[0.985, 250.0, 34.0, 3.6, false]]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _night := false
var _shown: ArrayMesh
var _glints: Control
var _glints_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glints = Control.new()
	_glints.name = "Glints"
	_glints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glints.draw.connect(func() -> void:
		if _glints_shown != null:
			_glints.draw_mesh(_glints_shown, null))
	add_child(_glints)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_glints, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Lantern Night's dusk over the water, or the day back.
func set_night(on: bool) -> void:
	if on == _night:
		return
	_night = on
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var foot := size.y
	var b := Face.Builder.new()
	_bands(b, STOPS, 1.0)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		Scenery.soft_disc(b, sun, ring[0] * u, ring[0] * u, Color(SUN, ring[1]))
	for p in PADS:
		_pad(b, Vector2(p[0] * size.x, foot - p[1] * u), p[2] * u, p[3], p[4])
	if _night:
		_bands(b, [[NIGHT_FROM, Color(NIGHT, 0.0)], [NIGHT_FULL, Color(NIGHT, NIGHT_ALPHA)],
			[1.0, Color(NIGHT, NIGHT_ALPHA)]], 0.0)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for l in LIGHTS:
		var r: float = l[2] * u
		Scenery.soft_disc(gb, Vector2(l[0] * size.x, l[1] * size.y), r, r * 0.7,
			Color(FOAM, LIGHT_ALPHA * (0.6 if _night else 1.0)))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

## Bands across the whole rect between `stops` ([share of the height,
## colour]), each shaded from its own colour to the next; `over` is how far
## the first and last run past the rect's top and foot, in rects.
func _bands(b: Face.Builder, stops: Array, over: float) -> void:
	var x0 := -8.0
	var x1 := size.x + 8.0
	for i in stops.size() - 1:
		var y0: float = float(stops[i][0]) * size.y
		var y1: float = float(stops[i + 1][0]) * size.y
		if i == 0:
			y0 -= over * size.y
		if i == stops.size() - 2:
			y1 += over * size.y + 8.0
		var c0: Color = stops[i][1]
		var c1: Color = stops[i + 1][1]
		var first := b.vertex(Vector2(x0, y0), c0)
		b.vertex(Vector2(x1, y0), c0)
		b.vertex(Vector2(x1, y1), c1)
		b.vertex(Vector2(x0, y1), c1)
		b.tri(first, first + 1, first + 2)
		b.tri(first, first + 2, first + 3)

## A lily pad with its notch at `turn`, and a white bloom on it or not.
func _pad(b: Face.Builder, at: Vector2, r: float, turn: float, bloom: bool) -> void:
	Scenery.soft_disc(b, at + Vector2(r * 0.16, r * 0.24), r * 1.18, r * 1.18, Color(SHADE, 0.2))
	var pts := PackedVector2Array([at])
	for i in 23:
		var a := turn + 0.3 + (TAU - 0.6) * float(i) / 22.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	b.polygon(pts, PAD_DEEP)
	var top := PackedVector2Array([at])
	for i in 23:
		var a := turn + 0.3 + (TAU - 0.6) * float(i) / 22.0
		top.append(at - Vector2(r, r) * 0.04 + Vector2(cos(a), sin(a)) * r * 0.9)
	b.polygon(top, PAD)
	if bloom:
		var c := at + Vector2(r * 0.2, -r * 0.2)
		for i in 5:
			b.ellipse(c + Vector2.from_angle(TAU * i / 5.0 + 0.3) * r * 0.24, r * 0.2, r * 0.2, FOAM)
		b.disc(c, r * 0.13, Pal.SUN_RAY)
