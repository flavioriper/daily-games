extends Control

## Binairo's world: a day and a night on one sky, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/binairo.gd) at the size of
## the screen: the day above with the sun coming up in its corner, behind
## the wordmark; the night below with its stars, a crescent and two dark
## hills at the foot, where nothing lies over them while the board is
## played; and the lit line between them running down across the grid, so the tiles lie
## over both.
##
## The day keeps the top of the screen and the night the foot of it because
## of what lies over them: the wordmark and the motto are ink, and the
## win's buttons carry their own paper.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the three sparkles are a second, on a child whose alpha
## breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const DAY_TOP := Color("ffeccb")
const DAY_LOW := Color("fbd3a0")
const NIGHT_HIGH := Color("7c89d2")
const NIGHT_LOW := Color("3a4587")
const HILL_FAR := Color("333d7c")
const HILL_NEAR := Color("2b346d")
const DUSK := Color("f6a58e")
## Opaque: a cloud is four shapes one over another, and a veil would show
## every overlap.
const CLOUD := Color("fff4de")
## The line between the day and the night, as shares of the rect: it leaves
## the right edge under the tools row and reaches the left edge low on the grid.
const DIVIDE_FROM := Vector2(1.0, 0.300)
const DIVIDE_C0 := Vector2(0.60, 0.34)
const DIVIDE_C1 := Vector2(0.42, 0.71)
const DIVIDE_TO := Vector2(0.0, 0.74)
## The sun's middle, as shares of the rect, and its glow's rings: [radius at
## W, alpha], drawn one over the other.
const SUN_AT := Vector2(0.07, 0.025)
const SUN_RINGS := [[700.0, 0.10], [500.0, 0.10], [320.0, 0.16]]
## The crescent, in the night under the grid: its middle as shares, its
## radius at W.
const MOON_AT := Vector2(0.840, 0.868)
const MOON_R := 58.0
## A cloud in the gap of the tools row, between Reset and Hint: [x, y as
## shares, radius at W].
const CLOUDS := [[0.560, 0.232, 34.0]]
## The night's stars, as shares of the rect: [x, y, radius at W, alpha].
## They stand in the open night under the grid, down to the hills.
const STARS := [
	[0.060, 0.822, 5.0, 0.85], [0.150, 0.868, 3.5, 0.6], [0.300, 0.830, 4.0, 0.7],
	[0.045, 0.905, 4.5, 0.8], [0.235, 0.915, 3.0, 0.55], [0.395, 0.880, 3.0, 0.55],
	[0.490, 0.822, 4.5, 0.8], [0.612, 0.862, 3.5, 0.6], [0.700, 0.818, 3.0, 0.5],
	[0.670, 0.925, 3.0, 0.5], [0.965, 0.820, 3.5, 0.6], [0.440, 0.935, 3.5, 0.6],
	[0.330, 0.950, 4.0, 0.7], [0.560, 0.905, 3.0, 0.5], [0.960, 0.935, 3.0, 0.5],
	[0.120, 0.950, 3.0, 0.5], [0.790, 0.945, 3.5, 0.6],
]
## The sparkles that twinkle: [x, y, radius at W].
const SPARKS := [[0.205, 0.846, 22.0], [0.700, 0.880, 18.0], [0.500, 0.870, 17.0]]
const TWINKLE := 3.2
const TWINKLE_LOW := 0.35

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

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The day under everything.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, DAY_TOP, DAY_LOW, 0.0, size.y * DIVIDE_TO.y)
	# The sun coming up in the corner, behind the wordmark.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	# The dusk the day ends in, then the night over it.
	var divide := _divide()
	b.stroke(divide, 260.0 * u, Color(DUSK, 0.10), false, false)
	b.stroke(divide, 120.0 * u, Color(DUSK, 0.14), false, false)
	var night := divide.duplicate()
	night.append(Vector2(-8.0, size.y + 8.0))
	night.append(Vector2(size.x + 8.0, size.y + 8.0))
	first = b.verts.size()
	b.polygon(night, Color.WHITE)
	CardFace.shade(b, first, NIGHT_HIGH, NIGHT_LOW, size.y * DIVIDE_FROM.y, size.y)
	# The day's edge, lit.
	b.stroke(divide, 56.0 * u, Color(Pal.SUN_RAY, 0.20), false, false)
	b.stroke(divide, 9.0 * u, Color(Pal.SURFACE, 0.85), false, false)
	for s in STARS:
		b.disc(Vector2(s[0], s[1]) * size, s[2] * u, Color(Pal.MOON, s[3]))
	# The crescent in its own soft light.
	var moon := MOON_AT * size
	var r := MOON_R * u
	b.disc(moon, r * 2.7, Color(Pal.MOON, 0.05))
	b.disc(moon, r * 1.8, Color(Pal.MOON, 0.07))
	for part in Geometry2D.clip_polygons(Face.Builder.ring(moon, r, r),
			Face.Builder.ring(moon + Vector2(r * 0.42, -r * 0.20), r * 0.86, r * 0.86)):
		b.polygon(part, Color(Pal.MOON, 0.92))
	# Two hills at the foot of the night.
	b.ellipse(Vector2(size.x * 0.80, size.y + 110.0 * u), size.x * 0.66, 200.0 * u, HILL_FAR)
	b.ellipse(Vector2(size.x * 0.20, size.y + 130.0 * u), size.x * 0.62, 200.0 * u, HILL_NEAR)
	_shown = b.mesh()
	queue_redraw()
	var sb := Face.Builder.new()
	for s in SPARKS:
		_sparkle(sb, Vector2(s[0], s[1]) * size, s[2] * u, Color(Pal.SUN_TILE, 0.95))
	_sparks_shown = sb.mesh()
	_sparks.size = size
	_sparks.queue_redraw()

func _divide() -> PackedVector2Array:
	var from := DIVIDE_FROM * size + Vector2(8.0, 0.0)
	var to := DIVIDE_TO * size - Vector2(8.0, 0.0)
	var pts := Face.Builder.bezier3(from, DIVIDE_C0 * size, DIVIDE_C1 * size, to, 40)
	pts.append(to)
	return pts

## A four-pointed star of `r`, its waist pinched (the menu card's).
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
