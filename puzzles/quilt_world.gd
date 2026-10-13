extends Control

## Quilt's world: the sewing table, seen from above, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## Pale birch boards with the window's light lying across the top of them,
## behind the wordmark; three spools and a thimble stood in the gap of the
## tools row; and along the foot, under the rack, the things a quilt is made
## with: a tape measure run out from the left, loose buttons, the menu
## card's needle with its thread, a spool that rolled, and a pincushion in
## the right corner. Under the quilt and its rack there is only the wood's
## faint grain.
##
## The top is light because of what lies over it: the wordmark, the motto
## and the win's "Well done!" are ink with no scrim.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the dust in the window's light is a second, on a child whose
## alpha breathes (still under Motion.reduce). The colours are written here:
## the board preloads this file, so reading them from the board is a cycle.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")
const Cloth = preload("res://ui/faces/patch_cloth.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const BIRCH_TOP := Color("fbf5ea")
const BIRCH_LOW := Color("eadcc6")
const GRAIN := Color("b99a70")
const SEAM := Color("c9ad86")
const LIGHT := Color("fffaf0")
## The boards' seams, as shares of the width, and the grain between them:
## [x share, y from, y to as shares, sway at W].
const SEAMS := [0.26, 0.52, 0.77]
const GRAINS := [
	[0.07, 0.30, 0.52, 10.0], [0.15, 0.58, 0.83, -8.0], [0.34, 0.27, 0.44, 7.0],
	[0.43, 0.63, 0.90, 9.0], [0.61, 0.33, 0.58, -9.0], [0.69, 0.70, 0.88, 6.0],
	[0.86, 0.29, 0.49, 8.0], [0.93, 0.56, 0.80, -7.0],
]
## The window's light: four panes leaning across the top left, as a share of
## the rect each [x, y, w, h], sheared by LIGHT_LEAN of their height.
const PANES := [
	[-0.04, -0.01, 0.30, 0.085], [0.28, -0.01, 0.30, 0.085],
	[-0.04, 0.082, 0.30, 0.085], [0.28, 0.082, 0.30, 0.085],
]
const LIGHT_LEAN := 0.55
const LIGHT_ALPHA := 0.34
## The spools in the gap of the tools row: [x, y as shares, radius at W,
## cloth index], seen from above, and the thimble after them.
const SPOOLS := [[0.385, 0.2335, 24.0, 2], [0.455, 0.2365, 21.0, 1], [0.522, 0.2330, 23.0, 3]]
const THIMBLE := [0.600, 0.2360, 15.0]
## The foot, under the rack; its heights are shares of a 1080 x 1920 screen
## measured up from the bottom edge (`_foot`), so a taller screen keeps them
## under the rack. The tape runs out from the left edge.
const TAPE := Color("f3cf73")
const TAPE_DEEP := Color("d9ad4c")
const TAPE_Y := 0.9685
const TAPE_TO := 0.36
const TAPE_W := 34.0
## Loose buttons: [x, y, radius at W, cloth index].
const BUTTONS := [[0.415, 0.9735, 17.0, 4], [0.462, 0.9610, 13.0, 0], [0.716, 0.9760, 14.0, 6]]
const NEEDLE_AT := Vector2(0.575, 0.9690)
const NEEDLE_DIR := Vector2(0.95, -0.30)
const NEEDLE_CELL := 190.0
const ROLLED := [0.660, 0.9600, 22.0, 5]
const CUSHION_AT := Vector2(0.895, 0.9655)
const CUSHION_R := 46.0
const CUSHION := Color("ef938c")
const CUSHION_DEEP := Color("d6756f")
const PIN := Color("b9bfc6")
const SHADOW := 0.10
## The dust in the window's light: [x, y, radius at W, alpha].
const MOTES := [
	[0.10, 0.030, 7.0, 0.8], [0.24, 0.085, 5.0, 0.7], [0.36, 0.045, 6.0, 0.75],
	[0.47, 0.120, 5.0, 0.6], [0.19, 0.150, 4.0, 0.6],
]
const BREATHE := 4.2
const BREATHE_LOW := 0.3

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
	_breath = Motion.pulse(_motes, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var b := Face.Builder.new()
	# The table, past every edge: the board slides the world against itself.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-size.x, -size.y), Vector2(size.x * 2.0, -size.y),
		Vector2(size.x * 2.0, size.y * 2.0), Vector2(-size.x, size.y * 2.0)]), Color.WHITE)
	CardFace.shade(b, first, BIRCH_TOP, BIRCH_LOW, 0.0, size.y)
	# The boards' seams and a little grain, from under the top rows down.
	for s in SEAMS:
		var x: float = s * size.x
		b.stroke(PackedVector2Array([Vector2(x, size.y * 0.265), Vector2(x, size.y + 8.0)]),
			2.5 * u, Color(SEAM, 0.22), false, false)
	for g in GRAINS:
		var from := Vector2(g[0] * size.x, g[1] * size.y)
		var to := Vector2(g[0] * size.x, g[2] * size.y)
		var bend := Vector2(float(g[3]) * u, 0.0)
		b.stroke(Face.Builder.bezier3(from, from.lerp(to, 0.33) + bend, from.lerp(to, 0.66) - bend, to, 12),
			2.0 * u, Color(GRAIN, 0.10), false, true)
	# The window's light across the top, behind the wordmark.
	Scenery.soft_disc(b, Vector2(size.x * 0.12, size.y * 0.03), size.x * 0.62, size.y * 0.20,
		Color(LIGHT, 0.55))
	for p in PANES:
		var at := Vector2(p[0], p[1]) * size
		var sz := Vector2(p[2], p[3]) * size - Vector2(10.0, 10.0) * u
		var lean := sz.y * LIGHT_LEAN
		first = b.verts.size()
		b.polygon(PackedVector2Array([at, at + Vector2(sz.x, 0.0),
			at + Vector2(sz.x + lean, sz.y), at + Vector2(lean, sz.y)]), Color.WHITE)
		CardFace.shade(b, first, Color(LIGHT, LIGHT_ALPHA), Color(LIGHT, LIGHT_ALPHA * 0.35),
			0.0, size.y * 0.17)
	# The spools and the thimble in the gap of the tools row.
	for s in SPOOLS:
		_spool(b, Vector2(s[0], s[1]) * size, float(s[2]) * u, Cloth.cloth(int(s[3])))
	_thimble(b, Vector2(THIMBLE[0], THIMBLE[1]) * size, float(THIMBLE[2]) * u)
	# The foot: the tape, the buttons, the needle and its thread, the spool
	# that rolled, the pincushion.
	_tape(b, u)
	for bt in BUTTONS:
		_button(b, _foot(bt[0], bt[1]), float(bt[2]) * u, Cloth.cloth(int(bt[3])))
	var rolled := _foot(ROLLED[0], ROLLED[1])
	var thread := Cloth.cloth(int(ROLLED[3])).lerp(Pal.TEXT, 0.12)
	var needle := _foot(NEEDLE_AT.x, NEEDLE_AT.y)
	var eye := needle - NEEDLE_DIR.normalized() * 0.14 * NEEDLE_CELL * u
	b.stroke(Face.Builder.bezier3(rolled, rolled + Vector2(-26.0, 44.0) * u,
		eye + Vector2(30.0, 34.0) * u, eye, 16), 4.0 * u, thread, false, true)
	_spool(b, rolled, float(ROLLED[2]) * u, Cloth.cloth(int(ROLLED[3])))
	Cloth.needle(b, needle, NEEDLE_DIR, NEEDLE_CELL * u, thread)
	_cushion(b, _foot(CUSHION_AT.x, CUSHION_AT.y), CUSHION_R * u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		Scenery.soft_disc(mb, Vector2(m[0], m[1]) * size, float(m[2]) * u, float(m[2]) * u,
			Color(LIGHT, m[3]))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A point of the foot: `x` a share of the width, `y` a share of a 1920-tall
## screen at W, kept that far above the bottom edge.
func _foot(x: float, y: float) -> Vector2:
	return Vector2(x * size.x, size.y - (1.0 - y) * 1920.0 * size.x / W)

## A spool stood on its end, seen from above: its shadow, the wooden flange,
## the wound thread and the hole.
func _spool(b: Face.Builder, at: Vector2, r: float, thread: Color) -> void:
	b.ellipse(at + Vector2(r * 0.16, r * 0.26), r * 1.04, r * 1.0, Color(Pal.TEXT, SHADOW))
	b.disc(at, r, Color("d9b98a"))
	b.disc(at, r * 0.86, Color("efd9b4"))
	b.disc(at, r * 0.68, thread.lerp(Pal.TEXT, 0.14))
	b.disc(at, r * 0.60, thread)
	b.stroke(Face.Builder.arc_points(at, r * 0.47, -2.5, -1.2), r * 0.09,
		Color(Color.WHITE, 0.45), false, true)
	b.disc(at, r * 0.22, Color("c9a876"))
	b.disc(at, r * 0.12, Color("8a6a45"))

## A thimble on its side of the row, from above: a dimpled steel cap.
func _thimble(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(r * 0.16, r * 0.26), r * 1.04, r * 1.0, Color(Pal.TEXT, SHADOW))
	b.disc(at, r, Color("aab1b9"))
	b.disc(at, r * 0.80, Color("d5dadf"))
	for i in 6:
		b.disc(at + Vector2.from_angle(i * TAU / 6.0) * r * 0.46, r * 0.10, Color("aab1b9"))
	b.disc(at, r * 0.10, Color("aab1b9"))

## The tape measure run out from the left edge along the foot, its end
## turned up a little, a tick a centimetre and a longer one every fifth.
func _tape(b: Face.Builder, u: float) -> void:
	var y := _foot(0.0, TAPE_Y).y
	var from := Vector2(-size.x, y + 6.0 * u)
	var bend := Vector2(size.x * (TAPE_TO - 0.12), y + 6.0 * u)
	var to := Vector2(size.x * TAPE_TO, y - 12.0 * u)
	var line := PackedVector2Array([from, Vector2(0.0, y + 6.0 * u)])
	line.append_array(Face.Builder.bezier2(Vector2(0.0, y + 6.0 * u), bend, to, 14))
	var shade := PackedVector2Array()
	for p in line:
		shade.append(p + Vector2(3.0, 6.0) * u)
	b.stroke(shade, TAPE_W * u, Color(Pal.TEXT, SHADOW), false, false)
	b.stroke(line, TAPE_W * u, TAPE_DEEP, false, false)
	b.stroke(line, (TAPE_W - 6.0) * u, TAPE, false, false)
	var step := 22.0 * u
	var n := int(size.x * (TAPE_TO - 0.14) / step)
	for i in n:
		var x := 14.0 * u + i * step
		var tall := (0.5 if i % 5 == 0 else 0.28) * TAPE_W * u
		var top := y + 6.0 * u - (TAPE_W - 6.0) * u * 0.5
		b.stroke(PackedVector2Array([Vector2(x, top), Vector2(x, top + tall)]), 2.4 * u,
			Color(Pal.TEXT, 0.5), false, false)
	# The brass end.
	var dir := (to - bend).normalized()
	b.stroke(PackedVector2Array([to - dir * 4.0 * u, to + dir * 10.0 * u]), (TAPE_W + 2.0) * u,
		Color("c9a04e"), false, false)

## A loose button: its shadow, the rim, the well and two holes.
func _button(b: Face.Builder, at: Vector2, r: float, cloth: Color) -> void:
	b.ellipse(at + Vector2(r * 0.14, r * 0.26), r * 1.04, r, Color(Pal.TEXT, SHADOW))
	b.disc(at, r, cloth.lerp(Pal.TEXT, 0.16))
	b.disc(at - Vector2(0.0, r * 0.08), r * 0.92, cloth)
	b.disc(at, r * 0.62, cloth.lerp(Pal.TEXT, 0.08))
	for sx in [-1.0, 1.0]:
		b.disc(at + Vector2(sx * r * 0.22, 0.0), r * 0.13, cloth.lerp(Pal.TEXT, 0.5))

## The pincushion from above: a tufted coral round, six pins stuck in it.
func _cushion(b: Face.Builder, at: Vector2, r: float) -> void:
	b.ellipse(at + Vector2(r * 0.10, r * 0.20), r * 1.05, r, Color(Pal.TEXT, SHADOW))
	b.disc(at, r, CUSHION_DEEP)
	b.disc(at - Vector2(0.0, r * 0.06), r * 0.94, CUSHION)
	for i in 6:
		var d := Vector2.from_angle(i * TAU / 6.0 + 0.3)
		b.stroke(PackedVector2Array([at + d * r * 0.16, at + d * r * 0.90]), r * 0.035,
			Color(CUSHION_DEEP, 0.7), false, true)
	b.disc(at, r * 0.10, CUSHION_DEEP)
	var pins := [[-0.9, 0.55, 0], [-0.25, 0.70, 1], [0.5, 0.52, 3], [1.5, 0.62, 4], [2.6, 0.48, 6], [3.6, 0.66, 0]]
	for p in pins:
		var d := Vector2.from_angle(float(p[0]))
		var foot := at + d * r * float(p[1]) * 0.55
		var head := at + d * r * (float(p[1]) + 0.42)
		b.stroke(PackedVector2Array([foot, head]), r * 0.05, PIN, false, true)
		b.disc(head, r * 0.11, Cloth.cloth(int(p[2])).lerp(Pal.TEXT, 0.1))
		b.disc(head - Vector2(r * 0.03, r * 0.03), r * 0.045, Color(Color.WHITE, 0.6))
