extends Control

## Quilt's world: the builder's table, seen from above, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). Pale birch boards with the window's light lying across the top
## of them, behind the wordmark; a few small bricks stood in the gap of the
## tools row; and along the foot, under the rack, loose bricks left out of
## the tray, turned every which way. Under the quilt and its rack there is
## only the wood's faint grain. (Until 2026-10-17 it was a sewing table:
## spools, a thimble, a tape, a needle and a pincushion.)
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
const Cloth = preload("res://ui/faces/brick_piece.gd")

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
## The small bricks in the gap of the tools row: [x, y as shares, cell at
## W, colour index, turn, cells].
const TOOLS := [
	[0.392, 0.2330, 22.0, 2, 0.0, [Vector2i(0, 0)]],
	[0.455, 0.2335, 22.0, 1, 0.0, [Vector2i(0, 0), Vector2i(1, 0)]],
	[0.548, 0.2330, 22.0, 3, 0.0, [Vector2i(0, 0)]],
]
## The loose bricks along the foot: [x, y, cell at W, colour index, turn,
## cells]. Their heights are shares of a 1080 x 1920 screen measured up from
## the bottom edge (`_foot`), so a taller screen keeps them under the rack.
const LOOSE := [
	[0.035, 0.9640, 30.0, 2, -0.22, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]],
	[0.215, 0.9710, 30.0, 0, 0.35, [Vector2i(0, 0), Vector2i(1, 0)]],
	[0.330, 0.9640, 30.0, 6, -0.12, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]],
	[0.475, 0.9740, 30.0, 4, 0.5, [Vector2i(0, 0)]],
	[0.560, 0.9650, 30.0, 1, 0.18, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]],
	[0.735, 0.9620, 30.0, 7, -0.3, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]],
	[0.865, 0.9700, 30.0, 5, 0.1, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1),
		Vector2i(1, 1), Vector2i(2, 1)]],
]
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
	# The small bricks in the gap of the tools row, and the loose ones along
	# the foot.
	for t in TOOLS:
		_brick(b, Vector2(t[0], t[1]) * size, float(t[2]) * u, int(t[3]), float(t[4]), t[5])
	for t in LOOSE:
		_brick(b, _foot(t[0], t[1]), float(t[2]) * u, int(t[3]), float(t[4]), t[5])
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

## A loose brick of `cells` at `at` (its top-left before the turn): its
## shadow on the wood, then the brick and its studs, turned by `rot` about
## its middle.
func _brick(b: Face.Builder, at: Vector2, cell: float, ci: int, rot: float, cells: Array) -> void:
	var span := Vector2i.ZERO
	for c: Vector2i in cells:
		span = Vector2i(maxi(span.x, c.x + 1), maxi(span.y, c.y + 1))
	var shape := Cloth.loops(cells)
	Cloth.shadow(b, shape, at, cell, span, Vector2(0.10, 0.22) * cell, SHADOW / Cloth.SHADOW_ALPHA,
		Vector2.ONE, rot)
	Cloth.patch(b, shape, at, cell, span, Cloth.cloth(ci), Cloth.cloth_deep(ci), Vector2.ONE, 1.0, rot)
	Cloth.print_cloth(b, cells, ci, at, cell, span, Vector2.ONE, 1.0, rot)
