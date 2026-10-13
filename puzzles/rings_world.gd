extends Control

## Rings' world: the sunny terrace the planks stand on, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). It is the ground the board used to draw inside its card
## (rings2d.gd's old terrace: pale flagstones in a sandy grout, dappled leaf
## shade) at the size of the screen, with the morning's light laid over the
## top of it, where the wordmark, the motto and the win's "Well done!" are
## ink: the stones come up out of that light just over the tools row.
##
## The board's own things on it -- the bushes along the foot, a spare plank
## with a peg half filled, a ring that rolled off, fallen leaves -- are
## painted by the board into this one mesh (`painter`): the board loads this
## file, so this file cannot load the board for its rings.
##
## One mesh, built when the rect changes and kept (`_shown`) until the next
## replaces it; the pollen motes are a second, on a child whose alpha
## breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## The morning over the top of the screen, and the terrace's grout and
## stones (the board's old tones).
const LIGHT_TOP := Color("fef6ea")
const LIGHT_LOW := Color("f9e9d6")
const GROUT := Color("e2cdb0")
const STONE := Color("ecdcc4")
const STONE_LIT := Color("f7efe0")
const STONE_UNDER := Color("d8bf9c")
const SHADE := Color("5b4a3c")
## The light is whole down to LIGHT_FROM and gone by LIGHT_TO, as shares of
## the height: the stones show from just over the tools row.
const LIGHT_FROM := 0.150
const LIGHT_TO := 0.300
## The sun's middle, as shares of the rect, and its rings: [radius at W,
## alpha].
const SUN_AT := Vector2(0.09, 0.02)
const SUN_RINGS := [[640.0, 0.10], [440.0, 0.12], [270.0, 0.16]]
## A flagstone's cell at W.
const CELL := Vector2(262.0, 192.0)
## Leaf shade on the stones: [x, y as shares, radius at W]. None under the
## pegs' middle; they gather at the sides and the foot.
const DAPPLES := [
	[0.02, 0.36, 150.0], [0.99, 0.47, 160.0], [0.03, 0.66, 130.0],
	[0.97, 0.76, 150.0], [0.20, 0.93, 170.0], [0.74, 0.90, 150.0],
]
## The motes in the light: [x, y as shares, radius at W].
const MOTES := [
	[0.33, 0.218, 5.0], [0.47, 0.246, 4.0], [0.77, 0.238, 4.5],
	[0.12, 0.905, 5.0], [0.62, 0.885, 4.0], [0.90, 0.872, 4.5], [0.36, 0.948, 4.0],
]
const BREATH := 3.6
const BREATH_LOW := 0.3

## The board's own things, painted into the mesh after the ground:
## `painter.call(builder, size, size.x / W)`.
var painter := Callable()

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
	var all := PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)])
	# The grout under everything, a little deeper toward the foot.
	var first := b.verts.size()
	b.polygon(all, Color.WHITE)
	CardFace.shade(b, first, GROUT.lerp(STONE, 0.35), GROUT, size.y * LIGHT_FROM, size.y)
	# Flagstones: a jittered grid, rows offset, every stone rounded and toned.
	# None is laid where the light is whole.
	var cell := CELL * u
	var cols := int(ceil(size.x / cell.x)) + 2
	var from_row := int(floor(size.y * LIGHT_FROM / cell.y))
	var rows := int(ceil(size.y / cell.y)) + 1
	for r in range(from_row, rows):
		for c in cols:
			var quad := PackedVector2Array([_corner(c, r, cell, u), _corner(c + 1, r, cell, u),
				_corner(c + 1, r + 1, cell, u), _corner(c, r + 1, cell, u)])
			var shrunk := Geometry2D.offset_polygon(quad, -14.0 * u, Geometry2D.JOIN_ROUND)
			if shrunk.is_empty():
				continue
			var stone: PackedVector2Array = Geometry2D.offset_polygon(shrunk[0], 10.0 * u, Geometry2D.JOIN_ROUND)[0]
			var under := PackedVector2Array()
			for p in stone:
				under.append(p + Vector2(0.0, 3.0 * u))
			b.polygon(under, STONE_UNDER)
			b.polygon(stone, STONE.lerp(STONE_LIT, 0.15 + 0.55 * _h(r * 101 + 7, c * 37)))
	# Leaf shade at the sides and the foot.
	for d in DAPPLES:
		var at := Vector2(d[0], d[1]) * size
		var r := float(d[2]) * u
		for q in 5:
			var off := Vector2((_h(q + 1, int(r)) - 0.5) * r * 1.5, (_h(q + 7, int(r)) - 0.5) * r * 0.9)
			var rr := r * (0.38 + 0.3 * _h(q + 13, int(r)))
			Scenery.soft_disc(b, at + off, rr, rr * 0.62, Color(SHADE, 0.06))
	# The morning over the top: whole behind the wordmark and the levels,
	# gone by the pegs.
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y * LIGHT_FROM), Vector2(-8.0, size.y * LIGHT_FROM)]), Color.WHITE)
	CardFace.shade(b, first, LIGHT_TOP, LIGHT_LOW, 0.0, size.y * LIGHT_FROM)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, size.y * LIGHT_FROM - 1.0), Vector2(size.x + 8.0, size.y * LIGHT_FROM - 1.0),
		Vector2(size.x + 8.0, size.y * LIGHT_TO), Vector2(-8.0, size.y * LIGHT_TO)]), Color.WHITE)
	_fade(b, first, LIGHT_LOW, size.y * LIGHT_FROM, size.y * LIGHT_TO)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	if not painter.is_null():
		painter.call(b, size, u)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var at := Vector2(m[0], m[1]) * size
		Scenery.soft_disc(mb, at, float(m[2]) * u * 2.4, float(m[2]) * u * 2.4, Color(Pal.SUN_RAY, 0.35))
		mb.disc(at, float(m[2]) * u, Color(Pal.SURFACE, 0.85))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## The vertices from `first` are a band of `col`, whole at `y0` and clear
## at `y1`.
func _fade(b: Face.Builder, first: int, col: Color, y0: float, y1: float) -> void:
	for i in range(first, b.verts.size()):
		var k := clampf(inverse_lerp(y0, y1, b.verts[i].y), 0.0, 1.0)
		b.cols[i] = Color(col, 1.0 - k)

## A flagstone's corner: the grid's, jittered, every other row half a cell
## aside.
func _corner(c: int, r: int, cell: Vector2, u: float) -> Vector2:
	var jx := (_h(c * 7 + 5, r * 13) - 0.5) * 60.0 * u
	var jy := (_h(c * 11 + 5, r * 17 + 3) - 0.5) * 40.0 * u
	var shift := cell.x * 0.5 if r % 2 == 1 else 0.0
	return Vector2(float(c) * cell.x - shift - cell.x * 0.5 + jx, float(r) * cell.y - 20.0 * u + jy)

## A stable 0..1 off two integers.
static func _h(a: int, b: int) -> float:
	return float(absi(hash(Vector2i(a, b))) % 10007) / 10006.0
