extends Control

## Word Trail's world: the peach morning of its menu card
## (ui/menu/cards/wordtrail.gd) at the size of the screen, edge to edge under
## the board and the host's rows (CLAUDE.md: a game's world fills the
## screen). The sky is light across the top, where the wordmark and the
## win's "Well done!" are ink, with the sun coming up behind the wordmark;
## one pale cloud and two leaves on the breeze lie in the gap of the tools
## row; nothing but sky lies under the field and its slots. The foot is the
## meadow the board's band used to be, grown to the screen's edges: two far
## hills, a trail of paper stepping tiles winding up between them, the turf
## with its lit crown, grass, three bushes, a few flowers and fallen leaves,
## and two spare tiles left lying in the grass.
##
## The board says where its ground line is (`set_ground`), since the
## dandelion and the lantern stand on it; it is the same on every level.
##
## One mesh, built when the rect or the ground changes and kept (`_shown`)
## until the next replaces it; the pollen motes are a second, on a child
## whose alpha breathes (still under Motion.reduce). The colours are written
## here: the board preloads this file, so this file cannot preload the board.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_TOP := Color("fdeee0")
const SKY_LOW := Color("f6d6c2")
const CLOUD := Color("fff5ea")
## The sun's middle, as shares of the rect, and its glow's rings: [radius at
## W, alpha].
const SUN_AT := Vector2(0.08, 0.02)
const SUN_RINGS := [[720.0, 0.10], [500.0, 0.10], [300.0, 0.14]]
## The cloud in the gap of the tools row: [x, y as shares, radius at W], and
## the leaves beside it: [x, y as shares, length at W, angle, colour].
const CLOUDS := [[0.56, 0.234, 30.0]]
const AIR_LEAVES := [
	[0.405, 0.240, 26.0, -0.5, Pal.LEAF],
	[0.705, 0.226, 22.0, 0.4, Pal.ACORN],
]
const AIR_WASH := 0.62
## The ground line when the board has not said: a share of the height.
const GROUND := 0.949
## The far hills: [x as a share, how far its middle lies under the ground
## line, half width as a share, half height, how far it is washed into the
## sky], heights at W.
const HILLS := [
	[0.80, 76.0, 0.56, 196.0, 0.70],
	[0.18, 64.0, 0.50, 150.0, 0.60],
]
## The trail of stepping tiles winding up between the hills: its ends and
## its bend as [x share, px over the ground at W], how many tiles, and the
## first and last tile's side at W.
const TRAIL_FROM := Vector2(0.455, 6.0)
const TRAIL_BEND := Vector2(0.60, 34.0)
const TRAIL_TO := Vector2(0.50, 84.0)
const TRAIL_TILES := 6
const TRAIL_SIDE := Vector2(34.0, 13.0)
## The turf: the board's own washes of the palette's greens.
const TURF_WASH := 0.52
const CROWN_WASH := 0.3
const BLADE_WASH := 0.24
const BUSH_DEEP_WASH := 0.3
const BUSH_LIT_WASH := 0.12
const CROWN_H := 22.0
const BLADES := 34
const BLADE_W := 5.0
const BLADE_ROOT := 4.0
const BLADE_MIN := 14.0
const BLADE_SPREAD := 20.0
const BLADE_LEAN := 8.0
## Bushes on the ground line: [x as a share, radius at W]. None stands where
## the dandelion (0.70) or the lantern (0.14) does.
const BUSHES := [[0.045, 36.0], [0.33, 25.0], [0.945, 33.0]]
## Flowers in the turf: [x as a share, px under the ground line at W, radius
## at W, colour].
const FLOWERS := [
	[0.26, 46.0, 9.0, Pal.FLOWER], [0.40, 70.0, 8.0, Pal.SUN],
	[0.585, 44.0, 9.0, Pal.BERRY], [0.80, 66.0, 8.0, Pal.FLOWER],
	[0.89, 40.0, 7.0, Pal.SUN], [0.50, 78.0, 7.0, Pal.MOON_INK],
]
## Fallen leaves in the turf: [x as a share, px under the ground line,
## length, angle, colour], at W.
const LEAVES := [
	[0.31, 72.0, 26.0, 0.35, Pal.ACORN],
	[0.665, 58.0, 24.0, -0.6, Pal.SUN],
	[0.955, 74.0, 22.0, 2.6, Pal.ACORN],
]
const LEAF_WASH := 0.3
## Two spare tiles left lying in the grass: [x as a share, px under the
## ground line, side, angle], at W.
const SPARES := [[0.085, 36.0, 50.0, -0.16], [0.158, 50.0, 44.0, 0.2]]
## The pollen motes that breathe: [x, y as shares, radius at W].
const MOTES := [
	[0.30, 0.222, 5.0], [0.64, 0.246, 4.0], [0.78, 0.214, 4.5],
	[0.12, 0.925, 5.0], [0.37, 0.915, 4.0], [0.62, 0.928, 5.0], [0.86, 0.918, 4.0],
]
const BREATH := 3.4
const BREATH_LOW := 0.3

var _ground := -1.0
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

## The board's ground line, in this rect's pixels: the turf starts there.
func set_ground(y: float) -> void:
	if is_equal_approx(y, _ground):
		return
	_ground = y
	_build()

func _ground_y() -> float:
	return _ground if _ground > 0.0 else size.y * GROUND

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var ground := _ground_y()
	var b := Face.Builder.new()
	# The morning under everything.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -8.0), Vector2(size.x + 8.0, -8.0),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, SKY_TOP, SKY_LOW, 0.0, ground)
	# The sun coming up in the corner, behind the wordmark.
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The air of the tools row: a cloud, and two leaves on the breeze.
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	for leaf in AIR_LEAVES:
		_leaf(b, Vector2(leaf[0], leaf[1]) * size, leaf[2] * u, leaf[3],
			(leaf[4] as Color).lerp(SKY_LOW, AIR_WASH))
	# The far hills, washed into the sky.
	for hill in HILLS:
		b.ellipse(Vector2(size.x * hill[0], ground + hill[1] * u), size.x * hill[2], hill[3] * u,
			Pal.LEAF.lerp(SKY_LOW, hill[4]))
	# The trail between them: paper stepping tiles, smaller as they go.
	var from := Vector2(size.x * TRAIL_FROM.x, ground - TRAIL_FROM.y * u)
	var bend := Vector2(size.x * TRAIL_BEND.x, ground - TRAIL_BEND.y * u)
	var to := Vector2(size.x * TRAIL_TO.x, ground - TRAIL_TO.y * u)
	var path := Face.Builder.bezier2(from, bend, to, TRAIL_TILES - 1)
	path.append(to)
	for i in range(mini(TRAIL_TILES, path.size()) - 1, -1, -1):
		var k := float(i) / float(TRAIL_TILES - 1)
		var side := lerpf(TRAIL_SIDE.x, TRAIL_SIDE.y, k) * u
		var box := Vector2(side, side * 0.56)
		var at: Vector2 = path[i] - box * 0.5
		var wash := lerpf(0.0, 0.45, k)
		b.polygon(Face.Builder.round_rect(at + Vector2(0.0, side * 0.1), box, box.y * 0.4),
			Pal.LINE.lerp(SKY_LOW, wash))
		b.polygon(Face.Builder.round_rect(at, box, box.y * 0.4), Pal.SURFACE.lerp(SKY_LOW, wash))
	# The turf, edge to edge, and its lit crown.
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, CROWN_WASH)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, ground), Vector2(size.x + 8.0, ground),
		Vector2(size.x + 8.0, size.y + 8.0), Vector2(-8.0, size.y + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, turf, turf.darkened(0.08), ground, size.y)
	b.polygon(PackedVector2Array([Vector2(-8.0, ground), Vector2(size.x + 8.0, ground),
		Vector2(size.x + 8.0, ground + CROWN_H * u), Vector2(-8.0, ground + CROWN_H * u)]), crown)
	# Grass along the line.
	var blade: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BLADE_WASH)
	var step := size.x / float(BLADES - 1)
	for i in BLADES:
		var x := float(i) * step + (_hash(i, 3) - 0.5) * step * 0.5
		var h := (BLADE_MIN + _hash(i, 5) * BLADE_SPREAD) * u
		var lean := (_hash(i, 9) - 0.5) * BLADE_LEAN * u
		var foot := Vector2(x - BLADE_W * u, ground + BLADE_ROOT * u)
		var tip := Vector2(x + BLADE_W * u, ground + BLADE_ROOT * u)
		var pts := Face.Builder.bezier2(foot, Vector2(x + lean, ground - h), tip, 8)
		pts.append(tip)
		b.polygon(pts, blade)
	var deep: Color = Pal.LEAF_DEEP.lerp(Pal.PARCHMENT, BUSH_DEEP_WASH)
	var lit: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BUSH_LIT_WASH)
	for bush in BUSHES:
		_bush(b, size.x * bush[0], ground, bush[1] * u, deep, lit)
	# What lies in the grass: fallen leaves, the spare tiles, flowers.
	for leaf in LEAVES:
		_leaf(b, Vector2(size.x * leaf[0], ground + leaf[1] * u), leaf[2] * u, leaf[3],
			(leaf[4] as Color).lerp(turf, LEAF_WASH))
	for spare in SPARES:
		_spare(b, Vector2(size.x * spare[0], ground + spare[1] * u), spare[2] * u, spare[3])
	for f in FLOWERS:
		_flower(b, Vector2(size.x * f[0], ground + f[1] * u), f[2] * u, f[3])
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var at := Vector2(m[0], m[1]) * size
		mb.disc(at, m[2] * u * 2.2, Color(Pal.SUN_RAY, 0.25))
		mb.disc(at, m[2] * u, Color(Pal.SURFACE, 0.9))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## A leaf of `length` from its stalk at `at`, with its rib.
func _leaf(b: Face.Builder, at: Vector2, length: float, angle: float, colour: Color) -> void:
	var xf := Transform2D(angle, at)
	var tip := Vector2(length, 0.0)
	var pts := Face.Builder.bezier2(Vector2.ZERO, Vector2(length * 0.5, -length * 0.42), tip, 8)
	pts.append(tip)
	var back := Face.Builder.bezier2(tip, Vector2(length * 0.5, length * 0.42), Vector2.ZERO, 8)
	pts.append_array(back)
	b.polygon(xf * pts, colour)
	b.stroke(PackedVector2Array([xf * Vector2(length * 0.12, 0.0), xf * Vector2(length * 0.86, 0.0)]),
		maxf(1.5, length * 0.06), colour.darkened(0.16))

## Three deep puffs with a lit one on the shoulder, seated on the ground
## line (the board's bush).
func _bush(b: Face.Builder, x: float, ground: float, r: float, deep: Color, lit: Color) -> void:
	b.disc(Vector2(x, ground - r * 0.58), r, deep)
	b.disc(Vector2(x - r * 0.86, ground - r * 0.3), r * 0.7, deep)
	b.disc(Vector2(x + r * 0.9, ground - r * 0.26), r * 0.66, deep)
	b.disc(Vector2(x - r * 0.24, ground - r * 0.84), r * 0.5, lit)

## A blank paper tile lying in the grass: its shadow, its lip, its face.
func _spare(b: Face.Builder, at: Vector2, side: float, angle: float) -> void:
	var xf := Transform2D(angle, at)
	var half := Vector2(side, side) * 0.5
	var r := side * 0.22
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(0.0, side * 0.16), Vector2(side, side), r),
		Color(Pal.TEXT, 0.10))
	b.polygon(xf * Face.Builder.round_rect(-half + Vector2(0.0, side * 0.08), Vector2(side, side), r),
		Pal.SURFACE_HI.lerp(Pal.LINE, 0.5))
	b.polygon(xf * Face.Builder.round_rect(-half, Vector2(side, side), r), Pal.SURFACE)

## Five petals round a middle.
func _flower(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 5.0) * r * 0.85, r * 0.62,
			colour.lerp(Pal.SURFACE, 0.35))
	b.disc(at, r * 0.45, Pal.SUN)

static func _hash(a: int, b: int) -> float:
	var h := (a * 73856093) ^ (b * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float(posmod(h, 1000)) / 1000.0
