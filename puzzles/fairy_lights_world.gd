extends Control

## Fairy Lights' world: a garden as the evening comes down, edge to edge
## under the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's garden (ui/menu/cards/fairylights.gd) at
## the size of the screen, turned so the last light is at the top: cream
## air behind the wordmark, a sage mist under the paved plot, and the
## card's night lawn at the foot, where nothing lies over it while the
## board is played. There the power post stands at the left with its lamp
## lit, and two strands of bulbs are strung from it to a second post over
## the hedge; a moth and a few fireflies are out in the gap of the tools
## row.
##
## The day keeps the top because of what lies over it: the wordmark, the
## motto and the win's "Well done!" are ink with no scrim.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the bulbs' halos and the fireflies are a second, on a child
## whose alpha breathes (still under Motion.reduce). Nothing here has a
## face: only the board's lanterns do. The colours are written here; the
## board preloads this file, so it does not preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width,
## and the foot's things are measured up from the bottom edge.
const W := 1080.0
## The air, top to foot: [share of the height, colour].
const AIR := [
	[0.0, Color("fdf3df")], [0.26, Color("f4ecd3")], [0.52, Color("d3e2cf")],
	[0.78, Color("86ad9f")], [0.875, Color("37655f")], [1.0, Color("21403f")],
]
const HEDGE_FAR := Color("244a49")
const HEDGE := Color("1a3639")
const BLOOM := Color("f3e7c9")
const POST := Color("7b5539")
const POST_DEEP := Color("563a26")
const POST_LIT := Color("a87a52")
## The wire the light runs in, its shade and its lit back (the board's).
const WIRE := Color("f5a623")
const WIRE_DEEP := Color("d88a12")
const WIRE_LIT := Color("ffe2a8")
const GLOW := Color("f9c04a")
const SPARK := Color("fff4c2")
const MOTH_WING := Color("f1e6cd")
const MOTH_WING_DEEP := Color("c4aa80")
## The last light, behind the wordmark: its middle as shares, its rings as
## [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[640.0, 0.10], [430.0, 0.10], [250.0, 0.14]]
## The posts: x as a share, how far their tops stand over the bottom edge
## and how wide they are, at W.
const POST_X := [0.075, 0.925]
const POST_TOP := 318.0
const POST_W := 26.0
## The strands, each [swags, how far its hooks are over the bottom edge,
## sag, bulbs a swag], at W. The high one runs post to post; the low one
## hangs from the posts' middles.
const STRANDS := [[3, 300.0, 54.0, 4], [2, 232.0, 66.0, 5]]
const WIRE_W := 7.0
const BULB_R := 9.0
const HALO := 4.6
## The hedge's rows along the foot: [step, rx, ry, how far the middles are
## under the bottom edge], at W.
const HEDGE_ROWS := [[150.0, 104.0, 78.0, -6.0], [128.0, 96.0, 60.0, 14.0]]
## The fireflies, as [x share, y share or -(px over the bottom at W), r at W].
const FLIES := [
	[0.385, 0.236, 5.0], [0.640, 0.222, 4.0], [0.735, 0.243, 4.5],
	[0.20, -150.0, 5.0], [0.47, -120.0, 4.5], [0.70, -168.0, 5.0], [0.86, -96.0, 4.0],
]
## The moth in the gap of the tools row: its middle as shares, its span at W.
const MOTH_AT := Vector2(0.545, 0.232)
const MOTH_SPAN := 40.0
const BREATHE := 3.4
const BREATHE_LOW := 0.55

var _shown: ArrayMesh
var _glow: Control
var _glow_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow = Control.new()
	_glow.name = "Glow"
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.draw.connect(func() -> void:
		if _glow_shown != null:
			_glow.draw_mesh(_glow_shown, null))
	add_child(_glow)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_glow, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	var g := Face.Builder.new()
	# The air, a band a pair of stops, each shaded top to bottom.
	for i in AIR.size() - 1:
		var y0: float = float(AIR[i][0]) * size.y - (8.0 if i == 0 else 0.0)
		var y1: float = float(AIR[i + 1][0]) * size.y + (8.0 if i == AIR.size() - 2 else 0.5)
		var first := b.verts.size()
		b.polygon(PackedVector2Array([Vector2(-8.0, y0), Vector2(size.x + 8.0, y0),
			Vector2(size.x + 8.0, y1), Vector2(-8.0, y1)]), Color.WHITE)
		CardFace.shade(b, first, AIR[i][1], AIR[i + 1][1], float(AIR[i][0]) * size.y, float(AIR[i + 1][0]) * size.y)
	# The last light, behind the wordmark.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		Scenery.soft_disc(b, sun, ring[0] * u, ring[0] * u, Color(GLOW, ring[1]))
	# The moth in the gap of the tools row.
	_moth(b, MOTH_AT * size, MOTH_SPAN * u)
	# The hedge along the foot, a far row and a near one, a bloom on some.
	for row_i in HEDGE_ROWS.size():
		var row: Array = HEDGE_ROWS[row_i]
		var step: float = row[0] * u
		var x := -step * (0.3 if row_i == 0 else 0.7)
		var n := 0
		while x < size.x + step:
			var mid := Vector2(x + step * 0.5, size.y + float(row[3]) * u)
			b.ellipse(mid, row[1] * u, row[2] * u, HEDGE_FAR if row_i == 0 else HEDGE)
			if row_i == 1 and n % 2 == 0:
				_bloom(b, mid + Vector2(step * 0.12, -float(row[2]) * u * 0.62), 7.0 * u)
			x += step
			n += 1
	# The posts, the power's own at the left with its lamp.
	var tops := PackedVector2Array()
	for px in POST_X:
		var top := Vector2(float(px) * size.x, size.y - POST_TOP * u)
		tops.append(top)
		_post(b, top, u)
	_lamp(b, g, tops[0] + Vector2(0.0, -20.0 * u), 22.0 * u)
	# The strands, the low one first so the high one's bulbs lie over it.
	for s_i in range(STRANDS.size() - 1, -1, -1):
		var strand: Array = STRANDS[s_i]
		var y: float = size.y - float(strand[1]) * u
		var from := Vector2(tops[0].x, y)
		var to := Vector2(tops[1].x, y)
		var swags: int = strand[0]
		for i in swags:
			var a := from.lerp(to, float(i) / float(swags))
			var c := from.lerp(to, float(i + 1) / float(swags))
			var low := (a + c) * 0.5 + Vector2(0.0, float(strand[2]) * 2.0 * u)
			var pts := Face.Builder.bezier2(a, low, c, 22)
			pts.append(c)
			_wire(b, g, pts, u)
			var bulbs: int = strand[3]
			for j in bulbs:
				var t := (float(j) + 0.5) / float(bulbs)
				var at := a.lerp(low, t).lerp(low.lerp(c, t), t)
				_bulb(b, g, at + Vector2(0.0, BULB_R * u * 1.15), BULB_R * u)
	# The fireflies: a soft light and its point.
	for f in FLIES:
		var fy: float = float(f[1]) * size.y if float(f[1]) >= 0.0 else size.y + float(f[1]) * u
		var at := Vector2(float(f[0]) * size.x, fy)
		var r: float = float(f[2]) * u
		Scenery.soft_disc(g, at, r * 3.6, r * 3.6, Color(GLOW, 0.34))
		g.disc(at, r * 0.55, Color(SPARK, 0.95))
	_shown = b.mesh()
	queue_redraw()
	_glow_shown = g.mesh()
	_glow.size = size
	_glow.queue_redraw()

## A run of the lit wire as the board lays one, in small: its shade, its
## face and its lit back, and the glow under it on the breathing layer.
func _wire(b: Face.Builder, g: Face.Builder, pts: PackedVector2Array, u: float) -> void:
	var w := WIRE_W * u
	g.stroke(pts, w * 3.2, Color(GLOW, 0.10), false, false)
	b.stroke(Transform2D(0.0, Vector2(0.0, w * 0.4)) * pts, w, WIRE_DEEP, false, false)
	b.stroke(pts, w, WIRE, false, false)
	b.stroke(pts, w * 0.36, Color(WIRE_LIT, 0.8), false, false)

## A bulb hung under the wire at `at`: its cap, its glass, and its halo on
## the breathing layer.
func _bulb(b: Face.Builder, g: Face.Builder, at: Vector2, r: float) -> void:
	Scenery.soft_disc(g, at, r * HALO, r * HALO, Color(WIRE_LIT, 0.42))
	b.polygon(Face.Builder.round_rect(at + Vector2(-r * 0.45, -r * 1.3), Vector2(r * 0.9, r * 0.7), r * 0.2), POST_DEEP)
	b.ellipse(at, r * 0.9, r, WIRE_LIT)
	b.disc(at + Vector2(-r * 0.25, -r * 0.3), r * 0.32, Color.WHITE.lerp(WIRE_LIT, 0.3))

## A garden post, its top at `top`, running off the bottom edge.
func _post(b: Face.Builder, top: Vector2, u: float) -> void:
	var w := POST_W * u
	var tall := size.y - top.y + 8.0
	b.polygon(Face.Builder.round_rect(top + Vector2(-w * 0.5, 0.0), Vector2(w, tall), w * 0.3), POST_DEEP)
	b.polygon(Face.Builder.round_rect(top + Vector2(-w * 0.5, 0.0), Vector2(w * 0.72, tall), w * 0.3), POST)
	b.polygon(Face.Builder.round_rect(top + Vector2(-w * 0.32, w * 0.3), Vector2(w * 0.16, tall), w * 0.08),
		Color(POST_LIT, 0.55))
	b.polygon(Face.Builder.round_rect(top + Vector2(-w * 0.8, -w * 0.3), Vector2(w * 1.6, w * 0.5), w * 0.2), POST_DEEP)

## The power's lamp on its post: a warm glass in a dark collar, in its own
## light (the board's post, seen from the lawn).
func _lamp(b: Face.Builder, g: Face.Builder, at: Vector2, r: float) -> void:
	Scenery.soft_disc(g, at, r * 4.2, r * 4.2, Color(GLOW, 0.30))
	b.polygon(Face.Builder.round_rect(at + Vector2(-r * 0.7, r * 0.55), Vector2(r * 1.4, r * 0.5), r * 0.2), POST_DEEP)
	b.disc(at, r, WIRE)
	b.disc(at, r * 0.74, WIRE_LIT)
	b.disc(at + Vector2(-r * 0.26, -r * 0.3), r * 0.24, Color.WHITE.lerp(WIRE_LIT, 0.3))
	b.polygon(Face.Builder.round_rect(at + Vector2(-r * 0.5, -r * 1.3), Vector2(r, r * 0.4), r * 0.2), POST_DEEP)

## A hedge's bloom: five pale petals round a warm middle.
func _bloom(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0) * r * 0.8, r * 0.62, Color(BLOOM, 0.9))
	b.disc(at, r * 0.46, GLOW)

## The moth, wings open, `span` across: pale, so it is only a mark on the
## win, where "Well done!" lies near it.
func _moth(b: Face.Builder, at: Vector2, span: float) -> void:
	var h := span * 0.5
	for side in [-1.0, 1.0]:
		b.polygon(PackedVector2Array([at, at + Vector2(side * h, -h * 0.72), at + Vector2(side * h * 0.92, h * 0.06),
			at + Vector2(side * h * 0.3, h * 0.2)]), Color(MOTH_WING, 0.85))
		b.polygon(PackedVector2Array([at, at + Vector2(side * h * 0.66, h * 0.16), at + Vector2(side * h * 0.5, h * 0.62),
			at + Vector2(side * h * 0.1, h * 0.36)]), Color(MOTH_WING_DEEP, 0.7))
	b.ellipse(at + Vector2(0.0, h * 0.08), h * 0.11, h * 0.42, Color(MOTH_WING_DEEP, 0.95))
