extends Control

## Light Up's world: the court's evening, edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## menu card's picture (ui/menu/cards/lightup.gd) at the size of the screen:
## the last of the day's light across the top, behind the wordmark; the dusk
## coming down the screen under the court; and at the foot the evening the
## card is painted in, a walk of flagstones along the edge with a string of
## paper lanterns over it, the stones under them warm and the rest cold.
##
## The light keeps the top and the dusk the foot because of what lies over
## them: the wordmark, the motto and the win's "Well done!" are ink, and the
## win's buttons carry their own paper. A second, shorter string hangs in
## the gap of the tools row. The lanterns are the garland's (the board's
## party), which have no faces: the lanterns with faces are the pieces.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the motes in the lanterns' light are a second, on a child
## whose alpha breathes (still under Motion.reduce). The colours are the
## palette's and this file's own: the board preloads this, so this does not
## preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The air, top to foot: [share of the height, colour]. Pale down past the
## tools row, a peach under the court, and the card's dusk at the foot.
const AIR := [
	[0.0, Color("fdf1dc")],
	[0.26, Color("f8dfc0")],
	[0.62, Color("e3b59b")],
	[0.80, Color("a37a7c")],
	[0.90, Color("6a5168")],
	[1.0, Color("46384f")],
]
## The last of the sun in the corner, behind the wordmark: its middle as
## shares, and its rings as [radius at W, alpha].
const GLOW_AT := Vector2(0.08, 0.02)
const GLOW_RINGS := [[720.0, 0.08], [480.0, 0.09], [300.0, 0.12]]
## The string in the gap of the tools row, between the bin and Hint: its
## ends as shares, its sag and a lantern's size at W, and how many hang.
const HIGH_FROM := Vector2(0.300, 0.2080)
const HIGH_TO := Vector2(0.820, 0.2080)
const HIGH_SAG := 22.0
const HIGH_SIZE := 44.0
const HIGH_N := 4
## The string over the walk at the foot, from edge to edge.
const LOW_FROM := Vector2(-0.02, 0.842)
const LOW_TO := Vector2(1.02, 0.842)
const LOW_SAG := 46.0
const LOW_SIZE := 78.0
const LOW_N := 5
## The walk along the foot: stones across, and how far the foot of a stone
## stands from the foot of the screen, at W.
const STONES := 7
const WALK_FOOT := 22.0
## The board's own stone (puzzles/lightup2d.gd's GAP, STONE_RADIUS,
## STONE_EDGE and CREST_ALPHA), copied.
const STONE_GAP := 0.035
const STONE_RADIUS := 0.13
const STONE_EDGE := 0.05
const CREST_ALPHA := 0.13
## A lantern's pool of light on the evening air and on the walk under it.
const POOL_ALPHA := 0.20
const HIGH_POOL_ALPHA := 0.16
## The first stars, in the dusk between the low string's lanterns: [x, y as shares,
## radius at W, alpha].
const STARS := [
	[0.188, 0.874, 3.0, 0.5], [0.396, 0.886, 2.5, 0.4], [0.604, 0.870, 2.5, 0.35],
	[0.812, 0.882, 3.0, 0.45], [0.985, 0.868, 2.5, 0.4],
]
## The motes that breathe in the lanterns' light: [x, y as shares, radius
## at W, alpha].
const MOTES := [
	[0.135, 0.882, 5.0, 0.6], [0.262, 0.905, 4.0, 0.5], [0.352, 0.868, 3.5, 0.45],
	[0.548, 0.908, 5.0, 0.6], [0.662, 0.876, 4.0, 0.5], [0.748, 0.912, 3.5, 0.45],
	[0.905, 0.872, 4.5, 0.55], [0.462, 0.243, 3.0, 0.45], [0.672, 0.250, 3.0, 0.4],
]
const BREATH := 3.6
const BREATH_LOW := 0.3

var _shown: ArrayMesh
var _motes: Control
var _motes_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes = Control.new()
	_motes.name = "Motes"
	_motes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motes.draw.connect(func() -> void:
		if _motes_shown != null:
			_motes.draw_mesh(_motes_shown, null))
	add_child(_motes)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_motes, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The air, a band a pair of stops, each shaded from the one to the other.
	for i in AIR.size() - 1:
		var y0: float = float(AIR[i][0]) * size.y - (8.0 if i == 0 else 0.0)
		var y1: float = float(AIR[i + 1][0]) * size.y + (8.0 if i == AIR.size() - 2 else 0.0)
		var first := b.verts.size()
		b.polygon(PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
			Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)]), Color.WHITE)
		CardFace.shade(b, first, AIR[i][1], AIR[i + 1][1], float(AIR[i][0]) * size.y, float(AIR[i + 1][0]) * size.y)
	# The last of the sun, behind the wordmark.
	var glow := GLOW_AT * size
	for ring in GLOW_RINGS:
		b.disc(glow, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	for s in STARS:
		b.disc(Vector2(s[0], s[1]) * size, s[2] * u, Color(Pal.MOON, s[3]))
	# The walk along the foot: cold stones, and warm ones under the lanterns.
	var c := size.x / STONES
	var top := size.y - WALK_FOOT * u - c
	var low := _hang(LOW_FROM * size, LOW_TO * size, LOW_SAG * u, LOW_N)
	for p in low:
		Scenery.soft_disc(b, Vector2(p.x, top + c * 0.5), c * 1.25, c * 0.6, Color(Pal.SUN, POOL_ALPHA * 0.8))
	for k in STONES:
		var mid := Vector2((k + 0.5) * c, top + c * 0.5)
		var warm := 0.0
		for p in low:
			warm = maxf(warm, 1.0 - absf(p.x - mid.x) / (c * 0.75))
		warm = clampf(warm, 0.0, 1.0)
		_stone(b, mid, c, Pal.FLAGSTONE.lerp(Pal.LAMPLIT_FLOOR, warm),
			Pal.FLAGSTONE_DEEP.lerp(Pal.LAMPLIT_DEEP, warm))
	# The two strings, each lantern in its own soft light.
	for p in low:
		var mid: Vector2 = p + Vector2(0.0, 0.62 * LOW_SIZE * u)
		Scenery.soft_disc(b, mid, LOW_SIZE * u * 1.9, LOW_SIZE * u * 1.9, Color(Pal.SUN, POOL_ALPHA))
	_string(b, LOW_FROM * size, LOW_TO * size, LOW_SAG * u, LOW_N, LOW_SIZE * u, 0)
	for p in _hang(HIGH_FROM * size, HIGH_TO * size, HIGH_SAG * u, HIGH_N):
		var mid: Vector2 = p + Vector2(0.0, 0.62 * HIGH_SIZE * u)
		Scenery.soft_disc(b, mid, HIGH_SIZE * u * 1.5, HIGH_SIZE * u * 1.5, Color(Pal.SUN_RAY, HIGH_POOL_ALPHA))
	_string(b, HIGH_FROM * size, HIGH_TO * size, HIGH_SAG * u, HIGH_N, HIGH_SIZE * u, 1)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		mb.disc(Vector2(m[0], m[1]) * size, m[2] * u, Color(Pal.LANTERN_LIT, m[3]))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A point of the cord from `from` to `to`, `sag` low at its middle.
func _cord(from: Vector2, to: Vector2, sag: float, t: float) -> Vector2:
	return from.lerp(to, t) + Vector2(0.0, sag * 4.0 * t * (1.0 - t))

## Where the `n` lanterns of a cord hang from.
func _hang(from: Vector2, to: Vector2, sag: float, n: int) -> Array:
	var out: Array = []
	for k in n:
		out.append(_cord(from, to, sag, (k + 0.5) / n))
	return out

## A cord and its `n` paper lanterns of `s`, their papers taken from the
## palette's in turn from `skip` (the board's garland, standing still).
func _string(b: Face.Builder, from: Vector2, to: Vector2, sag: float, n: int, s: float, skip: int) -> void:
	var pts := PackedVector2Array()
	const STEPS := 28
	for i in STEPS + 1:
		pts.append(_cord(from, to, sag, float(i) / STEPS))
	b.stroke(pts, maxf(2.0, s * 0.07), Pal.CORD_DEEP)
	for p in [from, to]:
		b.disc(p, s * 0.10, Pal.CORD_DEEP)
	var k := 0
	for p in _hang(from, to, sag, n):
		var paper: Array = Pal.LANTERN_PAPER[(k * 2 + skip) % Pal.LANTERN_PAPER.size()]
		_lantern(b, p, s, paper[0], paper[1])
		k += 1

## One paper lantern of `s` hanging from `at`: its thread, its paper over
## the deeper edge, the light in it, two ribs, its iron cap and foot, and a
## glint on its shoulder.
func _lantern(b: Face.Builder, at: Vector2, s: float, paper: Color, edge: Color) -> void:
	var skin := paper.lerp(Pal.LANTERN_LIT, 0.3)
	var mid := at + Vector2(0.0, 0.62 * s)
	b.polygon(PackedVector2Array([at + Vector2(-0.02 * s, 0.0), at + Vector2(0.02 * s, 0.0),
		at + Vector2(0.02 * s, 0.2 * s), at + Vector2(-0.02 * s, 0.2 * s)]), Pal.CORD_DEEP)
	b.polygon(Face.Builder.ring(mid + Vector2(0.0, 0.03 * s), 0.42 * s, 0.4 * s), edge)
	b.polygon(Face.Builder.ring(mid, 0.42 * s, 0.37 * s), skin)
	b.polygon(Face.Builder.ring(mid + Vector2(0.0, 0.04 * s), 0.18 * s, 0.2 * s), Color(Pal.LANTERN_LIT, 0.85))
	for sx: float in [-1.0, 1.0]:
		var rib := PackedVector2Array()
		for j in 7:
			var a := lerpf(-1.2, 1.2, j / 6.0)
			rib.append(mid + Vector2(sx * 0.22 * s * cos(a * 0.9), 0.37 * s * sin(a)))
		b.stroke(rib, maxf(1.0, s * 0.04), Color(edge, 0.55))
	b.polygon(Face.Builder.round_rect(at + Vector2(-0.17, 0.17) * s, Vector2(0.34, 0.1) * s, 0.04 * s), Pal.LANTERN)
	b.polygon(Face.Builder.round_rect(at + Vector2(-0.14, 0.99) * s, Vector2(0.28, 0.09) * s, 0.04 * s), Pal.LANTERN)
	b.polygon(Face.Builder.ring(mid + Vector2(-0.18, -0.14) * s, 0.07 * s, 0.1 * s), Color(1.0, 1.0, 1.0, 0.4))

## One flagstone of `c` about `mid`: its deep edge, its face and the light
## along its crest (the board's).
func _stone(b: Face.Builder, mid: Vector2, c: float, face: Color, deep: Color) -> void:
	var span := c * (1.0 - 2.0 * STONE_GAP)
	var at := mid - Vector2(span, span) * 0.5
	b.polygon(Face.Builder.round_rect(at, Vector2(span, span), c * STONE_RADIUS), deep)
	b.polygon(Face.Builder.round_rect(at, Vector2(span, span - c * STONE_EDGE), c * STONE_RADIUS), face)
	var wide := c * (1.0 - 2.0 * STONE_GAP - 2.0 * STONE_RADIUS)
	b.polygon(Face.Builder.round_rect(Vector2(mid.x - wide * 0.5, mid.y - c * (0.5 - STONE_GAP) + c * 0.04),
		Vector2(wide, c * 0.06), c * 0.03), Color(1.0, 1.0, 1.0, CREST_ALPHA))
