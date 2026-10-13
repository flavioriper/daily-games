extends Control

## Sudoku's world: the writing desk the tray stands on, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the menu card's sage cloth (ui/menu/cards/sudoku.gd) at
## the size of the screen: a soft window light in the wordmark's corner, the
## cloth ruled very faintly in the grid's own nine squares, a stitched hem
## down both sides and along the foot, a pencil, its eraser's crumbs and one
## of the board's daisies in the gap of the tools row, and the desk's wooden
## edge under everything.
##
## The digit pad is the host's and stands over the foot, so nothing but the
## cloth lies there; between the tray and the pad run a few pencil ticks.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the glints are a second, on a child whose alpha breathes
## (still under Motion.reduce). The colours are written here: the board
## preloads this file.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const CLOTH_TOP := Color("f6f7ee")
const CLOTH_LOW := Color("dde6d2")
const RULE := Color("7f8c6a")
const HEM := Color("a9b592")
const WOOD := Color("c9a57c")
const WOOD_DEEP := Color("9c7350")
const PENCIL := Color("f0c65e")
const PENCIL_DEEP := Color("d9a93f")
const FERRULE := Color("b9bcc0")
const RUBBER := Color("f1a9a0")
const TIP := Color("ecd6b2")
const PETAL := Color("fffdf8")
const POLLEN := Color("f5b63c")
## The window's light, as shares of the rect, and its rings [radius at W, alpha].
const LIGHT_AT := Vector2(0.09, 0.02)
const LIGHT := [[720.0, 0.20], [480.0, 0.22], [280.0, 0.28]]
## The faint ruling: a square every STEP at W, a heavier one every third.
const STEP := 120.0
const RULE_A := 0.045
const RULE_HEAVY_A := 0.085
## The pencil in the gap of the tools row: its two ends as shares.
const PENCIL_FROM := Vector2(0.335, 0.2395)
const PENCIL_TO := Vector2(0.640, 0.2255)
const PENCIL_W := 20.0
## The daisy beside it and the crumbs: [x, y as shares, radius at W].
const DAISY := [0.735, 0.232, 20.0]
const CRUMBS := [[0.300, 0.246, 4.0], [0.285, 0.238, 3.0], [0.312, 0.251, 2.5]]
## The pencil ticks between the tray and the pad, as a share of the height.
const TICKS_Y := 0.853
## The glints that breathe: [x, y as shares, radius at W].
const GLINTS := [[0.655, 0.2205, 9.0], [0.775, 0.222, 7.0], [0.215, 0.232, 6.0]]
const BREATH := 3.4
const BREATH_LOW := 0.3

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

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The cloth under everything.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, CLOTH_TOP, CLOTH_LOW, 0.0, size.y)
	# The window's light, behind the wordmark.
	var light := LIGHT_AT * size
	for ring in LIGHT:
		b.disc(light, ring[0] * u, Color(PETAL, ring[1]))
	# The cloth's ruling, in the grid's own squares; none across the top,
	# where the wordmark is.
	var step := STEP * u
	var top := size.y * 0.27
	var n := 0
	var x := size.x * 0.5 - 4.5 * step
	while x <= size.x + 1.0:
		if x >= 0.0:
			var a := RULE_HEAVY_A if n % 3 == 0 else RULE_A
			b.stroke(PackedVector2Array([Vector2(x, top), Vector2(x, size.y)]), 2.0 * u, Color(RULE, a), false, false)
		x += step
		n += 1
	n = 0
	var y := top
	while y <= size.y:
		var a := RULE_HEAVY_A if n % 3 == 0 else RULE_A
		b.stroke(PackedVector2Array([Vector2(0.0, y), Vector2(size.x, y)]), 2.0 * u, Color(RULE, a), false, false)
		y += step
		n += 1
	# The hem: a running stitch down both sides and along the foot.
	var hem_x := 18.0 * u
	var foot := size.y - 46.0 * u
	_stitch(b, Vector2(hem_x, top), Vector2(hem_x, foot), u)
	_stitch(b, Vector2(size.x - hem_x, top), Vector2(size.x - hem_x, foot), u)
	_stitch(b, Vector2(hem_x, foot), Vector2(size.x - hem_x, foot), u)
	# The desk's edge under the cloth.
	var rail := 26.0 * u
	b.polygon(_box(Vector2(-8.0, size.y - rail), Vector2(size.x + 16.0, rail + 8.0)), WOOD)
	b.polygon(_box(Vector2(-8.0, size.y - rail), Vector2(size.x + 16.0, 5.0 * u)), Color(PETAL, 0.35))
	b.polygon(_box(Vector2(-8.0, size.y - 7.0 * u), Vector2(size.x + 16.0, 15.0 * u)), WOOD_DEEP)
	# A few pencil ticks between the tray and the pad.
	var ty := size.y * TICKS_Y
	for i in 9:
		var tx := size.x * 0.5 + (i - 4) * 34.0 * u
		var tall := (16.0 if i % 3 == 1 else 9.0) * u
		b.stroke(PackedVector2Array([Vector2(tx, ty - tall * 0.5), Vector2(tx + 2.0 * u, ty + tall * 0.5)]),
			3.0 * u, Color(Pal.TEXT, 0.16), false, true)
	# The pencil, its crumbs and a daisy, in the gap of the tools row.
	_pencil(b, PENCIL_FROM * size, PENCIL_TO * size, PENCIL_W * u)
	for c in CRUMBS:
		b.disc(Vector2(c[0], c[1]) * size, c[2] * u, Color(RUBBER, 0.8))
	_daisy(b, Vector2(DAISY[0], DAISY[1]) * size, DAISY[2] * u)
	_shown = b.mesh()
	queue_redraw()
	var gb := Face.Builder.new()
	for g in GLINTS:
		_sparkle(gb, Vector2(g[0], g[1]) * size, g[2] * u, Color(PETAL, 0.95))
	_glints_shown = gb.mesh()
	_glints.size = size
	_glints.queue_redraw()

func _box(at: Vector2, sz: Vector2) -> PackedVector2Array:
	return PackedVector2Array([at, at + Vector2(sz.x, 0.0), at + sz, at + Vector2(0.0, sz.y)])

## A running stitch from `from` to `to`.
func _stitch(b: Face.Builder, from: Vector2, to: Vector2, u: float) -> void:
	var along := to - from
	var length := along.length()
	if length <= 0.0:
		return
	var dir := along / length
	var dash := 18.0 * u
	var gap := 14.0 * u
	var at := 0.0
	while at + dash <= length:
		b.stroke(PackedVector2Array([from + dir * at, from + dir * (at + dash)]), 4.0 * u, Color(HEM, 0.7), false, true)
		at += dash + gap

## A pencil lying from its rubber at `from` to its point at `to`, `w` thick.
func _pencil(b: Face.Builder, from: Vector2, to: Vector2, w: float) -> void:
	var along := to - from
	var length := along.length()
	var d := along / length
	var nrm := Vector2(-d.y, d.x) * w * 0.5
	# Its shadow on the cloth.
	var drop := Vector2(0.0, w * 0.32)
	b.polygon(PackedVector2Array([from - nrm + drop, to - d * w * 1.6 - nrm + drop, to + drop,
		to - d * w * 1.6 + nrm + drop, from + nrm + drop]), Color(Pal.TEXT, 0.10))
	var rubber := w * 0.9
	var ferrule := w * 0.7
	var cone := w * 1.6
	var a := from
	var c := a + d * rubber
	b.polygon(PackedVector2Array([a - nrm, c - nrm, c + nrm, a + nrm]), RUBBER)
	b.disc(a, w * 0.5, RUBBER)
	var e := c + d * ferrule
	b.polygon(PackedVector2Array([c - nrm, e - nrm, e + nrm, c + nrm]), FERRULE)
	var f := to - d * cone
	b.polygon(PackedVector2Array([e - nrm, f - nrm, f + nrm, e + nrm]), PENCIL)
	b.polygon(PackedVector2Array([e + nrm * 0.25, f + nrm * 0.25, f + nrm, e + nrm]), PENCIL_DEEP)
	b.polygon(PackedVector2Array([f - nrm, to, f + nrm]), TIP)
	var lead := to - d * cone * 0.34
	b.polygon(PackedVector2Array([lead - nrm * 0.34, to, lead + nrm * 0.34]), Pal.TEXT)

## One of the board's daisies: eight petals round a gold middle.
func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at + Vector2(0.0, r * 0.18), r * 1.02, Color(Pal.TEXT, 0.08))
	for i in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0)
		b.disc(at + dir * r * 0.58, r * 0.42, PETAL)
	b.disc(at, r * 0.36, POLLEN)

## A four-pointed star of `r`, its waist pinched (the menu card's).
func _sparkle(b: Face.Builder, at: Vector2, r: float, ink: Color) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(-PI * 0.5 + i * PI * 0.25) * (r if i % 2 == 0 else r * 0.30))
	b.polygon(pts, ink)
