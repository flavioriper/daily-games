extends Control

## Hidden Word's world: the board's meadow, edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## menu card's parchment and turf at the size of the screen, and the band the
## board used to draw at the foot of its card grown into a place: a pale
## morning air with a soft light behind the wordmark and three clouds (one in
## the gap of the tools row, one in each of the side airs the grid leaves),
## two far hills, and the meadow from the grid's foot down to the bottom of
## the screen, with the band's own blades, bushes and flowers along its
## crown. A letter box stands on the crown in the left air, where the Peeplet
## comes up with the word, and a sealed letter and a loose paper tile drift
## in the same air (the right one is Insane's snail's).
##
## The keyboard is the host's and lies over the meadow: the grass under it is
## pale and plain so the keys read, and only the strip under the last row of
## keys has flowers in it.
##
## The board says where its grid ends (`set_ground`), since the crown stands
## a fixed way under the last row and the rows are fitted to the span. On the
## win the board slides the world up or down with it (it is over-drawn half a
## screen past the top and the foot for that) so the crown stays under the
## grid.
##
## One mesh, built when the rect or the ground changes and kept (`_shown`)
## until the next replaces it; the pollen is a second, on a child whose alpha
## breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## How far past the top and the foot the air and the grass run, as a share
## of the height: the world rides up and down with the board on the win.
const OVER := 0.5
const AIR_TOP := Color("fdf7e8")
const AIR_LOW := Color("f1edcf")
const HILL_FAR := Color("dfe8c2")
const HILL_NEAR := Color("d3e2b2")
## Opaque: a cloud is four shapes one over another.
const CLOUD := Color("fffaee")
## The board's own washes of the turf (hidden_word2d.gd's band).
const TURF_WASH := 0.52
const CROWN_WASH := 0.3
const BLADE_WASH := 0.24
const BUSH_DEEP_WASH := 0.3
const BUSH_LIT_WASH := 0.12
## How pale the grass is at the very foot, under the keys.
const FOOT_WASH := 0.66
const CROWN_H := 24.0
## The light behind the wordmark: its middle as shares, its rings [radius at
## W, alpha].
const GLOW_AT := Vector2(0.08, 0.02)
const GLOW := [[640.0, 0.08], [440.0, 0.09], [270.0, 0.12]]
## The clouds: [x, y as shares, radius at W]. The first is in the gap of the
## tools row; the others are in the side airs.
const CLOUDS := [[0.560, 0.232, 30.0], [0.072, 0.415, 19.0], [0.940, 0.455, 17.0]]
## Things on the crown: [x as a share, radius at W].
const BUSHES := [[0.175, 34.0], [0.47, 25.0], [0.905, 31.0]]
## Flowers on the grass under the crown: [x as a share, drop under the
## ground line at W].
const FLOWERS := [[0.245, 30.0], [0.375, 44.0], [0.67, 36.0], [0.80, 28.0], [0.965, 46.0]]
const BLADES := 27
## The letter box in the left air: its post's x as a share, the post's
## height and the box's size at W.
const BOX_X := 0.058
const BOX_POST := 118.0
const BOX_SIZE := Vector2(96.0, 62.0)
const BOX_PAPER := Color("e6e8f7")
const BOX_DEEP := Color("c3c7e2")
const BOX_FLAG := Color("e8836b")
## A sealed letter and a loose tile adrift in the left air (Insane's snail
## rides in the right one): [x, y as shares, size at W, tilt].
const LETTER := [0.070, 0.305, 62.0, 0.20]
const TILE := [0.074, 0.545, 50.0, -0.16]
const WAX := Color("e8836b")
## The strip under the keyboard: flowers and tufts, [x as a share, rise from
## the bottom edge at W].
const FOOT_FLOWERS := [[0.06, 20.0], [0.31, 14.0], [0.58, 22.0], [0.86, 16.0]]
const FOOT_TUFTS := [0.17, 0.44, 0.72, 0.95]
## The pollen that breathes, in the side airs and the gap of the tools row:
## [x, y as shares, radius at W].
const POLLEN := [[0.120, 0.350, 5.0], [0.118, 0.640, 4.0], [0.955, 0.380, 4.5],
	[0.900, 0.610, 4.0], [0.320, 0.226, 4.0], [0.790, 0.240, 4.5]]
const BREATH := 3.6
const BREATH_LOW := 0.3

## The ground line, in this rect's own pixels; the board sets it.
var _ground := -1.0
var _shown: ArrayMesh
var _pollen: Control
var _pollen_shown: ArrayMesh
var _breath: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pollen = Control.new()
	_pollen.name = "Pollen"
	_pollen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pollen.draw.connect(func() -> void:
		if _pollen_shown != null:
			_pollen.draw_mesh(_pollen_shown, null))
	add_child(_pollen)
	resized.connect(_build)
	_build()
	_breath = Motion.pulse(_pollen, "modulate:a", 1.0, BREATH_LOW, BREATH)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the meadow's crown stands. A new mesh only when it has moved.
func set_ground(y: float) -> void:
	if absf(y - _ground) < 0.5:
		return
	_ground = y
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var over := size.y * OVER
	var ground := _ground if _ground > 0.0 else size.y * 0.78
	var b := Face.Builder.new()
	# The air, lightest at the top where the wordmark is.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -over), Vector2(size.x + 8.0, -over),
		Vector2(size.x + 8.0, ground + 8.0), Vector2(-8.0, ground + 8.0)]), Color.WHITE)
	CardFace.shade(b, first, AIR_TOP, AIR_LOW, 0.0, ground)
	var glow := GLOW_AT * size
	for ring in GLOW:
		b.disc(glow, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(c[0], c[1]) * size, c[2] * u, CLOUD)
	_letter(b, Vector2(LETTER[0], LETTER[1]) * size, LETTER[2] * u, LETTER[3])
	_tile(b, Vector2(TILE[0], TILE[1]) * size, TILE[2] * u, TILE[3])
	# Two far hills, low enough to leave the last row alone.
	b.ellipse(Vector2(size.x * 0.10, ground + 24.0 * u), size.x * 0.40, 86.0 * u, HILL_FAR)
	b.ellipse(Vector2(size.x * 0.93, ground + 30.0 * u), size.x * 0.36, 78.0 * u, HILL_NEAR)
	_box(b, Vector2(size.x * BOX_X, ground), u)
	# The meadow, paler toward the foot, and its lit crown.
	var turf: Color = Pal.LEAF.lerp(Pal.PARCHMENT, TURF_WASH)
	var crown: Color = Pal.LEAF_LIGHT.lerp(Pal.PARCHMENT, CROWN_WASH)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, ground), Vector2(size.x + 8.0, ground),
		Vector2(size.x + 8.0, size.y + over), Vector2(-8.0, size.y + over)]), Color.WHITE)
	CardFace.shade(b, first, turf, Pal.LEAF.lerp(Pal.PARCHMENT, FOOT_WASH), ground, size.y)
	b.polygon(PackedVector2Array([Vector2(-8.0, ground), Vector2(size.x + 8.0, ground),
		Vector2(size.x + 8.0, ground + CROWN_H * u), Vector2(-8.0, ground + CROWN_H * u)]), crown)
	var blade: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BLADE_WASH)
	var step := size.x / float(BLADES - 1)
	for i in BLADES:
		var x := float(i) * step + (_hash(i, 3) - 0.5) * step * 0.5
		var h := (9.0 + _hash(i, 5) * 15.0) * u
		var lean := (_hash(i, 9) - 0.5) * 7.0 * u
		var foot := Vector2(x - 5.0 * u, ground + 3.0 * u)
		var tip := Vector2(x + 5.0 * u, ground + 3.0 * u)
		var pts := Face.Builder.bezier2(foot, Vector2(x + lean, ground - h), tip, 8)
		pts.append(tip)
		b.polygon(pts, blade)
	var deep: Color = Pal.LEAF_DEEP.lerp(Pal.PARCHMENT, BUSH_DEEP_WASH)
	var lit: Color = Pal.LEAF.lerp(Pal.PARCHMENT, BUSH_LIT_WASH)
	for bush in BUSHES:
		_bush(b, size.x * bush[0], ground, bush[1] * u, deep, lit)
	for f in FLOWERS:
		_flower(b, Vector2(size.x * f[0], ground + f[1] * u), u)
	# The strip under the keys.
	for x in FOOT_TUFTS:
		Scenery.tuft(b, Vector2(size.x * x, size.y - 8.0 * u), 22.0 * u)
	for f in FOOT_FLOWERS:
		_flower(b, Vector2(size.x * f[0], size.y - f[1] * u), u)
	_shown = b.mesh()
	queue_redraw()
	var pb := Face.Builder.new()
	for p in POLLEN:
		var at := Vector2(p[0], p[1]) * size
		pb.disc(at, p[2] * u * 2.2, Color(Pal.SUN_RAY, 0.16))
		pb.disc(at, p[2] * u, Color(Pal.SURFACE, 0.9))
	_pollen_shown = pb.mesh()
	_pollen.size = size
	_pollen.queue_redraw()

## Three deep puffs with a lit one on the shoulder, seated on the ground line
## (the board's band's).
func _bush(b: Face.Builder, x: float, ground: float, r: float, deep: Color, lit: Color) -> void:
	b.disc(Vector2(x, ground - r * 0.58), r, deep)
	b.disc(Vector2(x - r * 0.82, ground - r * 0.24), r * 0.64, deep)
	b.disc(Vector2(x + r * 0.84, ground - r * 0.26), r * 0.6, deep)
	b.disc(Vector2(x - r * 0.24, ground - r * 0.9), r * 0.4, lit)

## Five petals round a sun-coloured eye (the board's band's).
func _flower(b: Face.Builder, at: Vector2, u: float) -> void:
	for k in 5:
		var a := float(k) / 5.0 * TAU
		b.disc(at + Vector2(cos(a), sin(a)) * 7.0 * u, 5.5 * u, Pal.SURFACE)
	b.disc(at, 4.0 * u, Pal.SUN)

## The letter box on its post, a letter showing in its mouth and its flag up.
func _box(b: Face.Builder, foot: Vector2, u: float) -> void:
	var post := BOX_POST * u
	var sz := BOX_SIZE * u
	b.fan(Face.Builder.round_rect(foot + Vector2(-7.0 * u, -post), Vector2(14.0 * u, post + 10.0 * u),
		5.0 * u), Pal.WOOD_DEEP)
	var at := foot + Vector2(-sz.x * 0.42, -post - sz.y * 0.9)
	# The flag behind the box, on its side.
	b.fan(Face.Builder.round_rect(at + Vector2(sz.x - 4.0 * u, -sz.y * 0.34),
		Vector2(8.0 * u, sz.y * 0.8), 3.0 * u), Pal.WOOD_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(sz.x, -sz.y * 0.34),
		Vector2(26.0 * u, 18.0 * u), 4.0 * u), BOX_FLAG)
	b.fan(Face.Builder.round_rect(at, sz, sz.y * 0.46), BOX_DEEP)
	b.fan(Face.Builder.round_rect(at, sz - Vector2(0.0, 6.0 * u), sz.y * 0.46), BOX_PAPER)
	# Its mouth and the letter in it.
	b.fan(Face.Builder.round_rect(at + Vector2(sz.x * 0.20, sz.y * 0.34),
		Vector2(sz.x * 0.60, 9.0 * u), 4.5 * u), BOX_DEEP)
	b.fan(Face.Builder.round_rect(at + Vector2(sz.x * 0.30, sz.y * 0.22),
		Vector2(sz.x * 0.40, 12.0 * u), 3.0 * u), Pal.SURFACE)

## A sealed letter of `s` across, tilted: the board's envelope, small.
func _letter(b: Face.Builder, at: Vector2, s: float, tilt: float) -> void:
	var xf := Transform2D(tilt, at)
	var h := s * 0.68
	b.fan(xf * Face.Builder.round_rect(Vector2(-s, -h) * 0.5 + Vector2(0.0, s * 0.05), Vector2(s, h), s * 0.10),
		BOX_DEEP)
	b.fan(xf * Face.Builder.round_rect(Vector2(-s, -h) * 0.5, Vector2(s, h), s * 0.10), BOX_PAPER)
	b.polygon(xf * PackedVector2Array([Vector2(-s * 0.46, -h * 0.44), Vector2(s * 0.46, -h * 0.44),
		Vector2(0.0, h * 0.10)]), Color(BOX_DEEP, 0.55))
	b.disc(xf * Vector2(0.0, h * 0.06), s * 0.10, WAX)

## A loose paper tile of `s`, tilted, with nothing on it.
func _tile(b: Face.Builder, at: Vector2, s: float, tilt: float) -> void:
	var xf := Transform2D(tilt, at)
	b.fan(xf * Face.Builder.round_rect(Vector2(-s, -s) * 0.5 + Vector2(0.0, s * 0.07), Vector2(s, s), s * 0.19),
		Pal.SURFACE_HI)
	b.fan(xf * Face.Builder.round_rect(Vector2(-s, -s) * 0.5, Vector2(s, s), s * 0.19), Pal.SURFACE)

## A fixed pseudo-random number per blade, so the grass is uneven in the same
## way on every launch.
static func _hash(a: int, c: int) -> float:
	return float(posmod(hash(Vector2i(a, c)), 1000)) / 1000.0
