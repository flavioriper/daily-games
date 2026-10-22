extends Control

## Domino Patio's world: a sunny terrace, edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). The sky is
## cream across the top, where the wordmark, the motto and the win's "Well
## done!" are ink with no scrim; a pergola's beam crosses it with a vine
## hanging from it into the gap of the tools row. Under the sky, a low
## garden wall with a hedge over it, then the terrace's sandstone flags
## from the wall past the foot, two pots of geraniums standing at the foot's
## corners.
##
## The board says where its lines stand (`set_lines`): the wall's foot (the
## terrace's top) and the foot of the rack. One mesh, built when the rect or
## a line changes and kept (`_shown`) until the next replaces it, drawn past
## the top of the rect for the win.

const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const SKY_HIGH := Color("fdf6e8")
const SKY_LOW := Color("f4ead6")
const SUN := Color("fff1c8")
const BEAM := Color("b88a5e")
const BEAM_DEEP := Color("8f6643")
const VINE := Color("6f9e4c")
const VINE_HI := Color("93bf68")
const BLOOM := Color("c9a2de")
const WALL := Color("e8d6b6")
const WALL_DEEP := Color("cdb690")
const HEDGE := Color("86b166")
const HEDGE_DEEP := Color("6a9a4f")
const FLAG := Color("e9d8b9")
const FLAG_LOW := Color("dcc7a2")
const GROUT := Color("cbb38c")
const POT := Color("cf7f57")
const POT_DEEP := Color("a9603f")
const GERANIUM := Color("e2645c")
const LEAF := Color("6f9e4c")
## How far past the top the sky is drawn, as a share of the height.
const OVER := 0.6
## A flag of the terrace, at W.
const FLAG_W := 210.0
const FLAG_H := 120.0

var _wall := 0.0
var _foot := 0.0
var _built := Vector2(-1, -1)
var _built_size := Vector2.ZERO
var _shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## Where the board's lines stand: the wall's foot and the rack's foot. The
## picture is built again only when one moved.
func set_lines(wall: float, foot: float) -> void:
	_wall = wall
	_foot = foot
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0 or _wall <= 0.0:
		return
	var lines := Vector2(_wall, _foot)
	if lines == _built and size == _built_size:
		return
	_built = lines
	_built_size = size
	var u := size.x / W
	var w := size.x
	var h := size.y
	var b := Face.Builder.new()
	var first := b.verts.size()
	b.polygon(_rect(-8.0, -h * OVER, w + 8.0, _wall + 2.0), Color.WHITE)
	CardFace.shade(b, first, SKY_HIGH, SKY_LOW, h * 0.05, _wall)
	# the sun's warmth high on the right
	var sun := Vector2(w * 0.84, _wall * 0.42)
	for ring: Array in [[260.0, 0.10], [170.0, 0.14], [110.0, 0.2]]:
		b.disc(sun, float(ring[0]) * u, Color(SUN, float(ring[1])))
	# the hedge over the wall, then the wall
	var top := _wall - 120.0 * u
	var rng := RandomNumberGenerator.new()
	rng.seed = 2210
	var x := -30.0 * u
	while x < w + 40.0 * u:
		var r := rng.randf_range(46.0, 70.0) * u
		b.disc(Vector2(x, top + 10.0 * u), r, HEDGE_DEEP)
		b.disc(Vector2(x - r * 0.15, top + 2.0 * u), r * 0.86, HEDGE)
		x += r * 1.1
	b.polygon(_rect(-8.0, top + 20.0 * u, w + 8.0, _wall), WALL)
	b.polygon(_rect(-8.0, top + 20.0 * u, w + 8.0, top + 34.0 * u), WALL_DEEP)
	var row := 0
	var y := top + 34.0 * u
	while y < _wall - 4.0 * u:
		var bx := -60.0 * u + (60.0 * u if row % 2 == 1 else 0.0)
		while bx < w:
			b.stroke(PackedVector2Array([Vector2(bx, y), Vector2(bx, minf(y + 30.0 * u, _wall))]), 2.0 * u, Color(WALL_DEEP, 0.6))
			bx += 120.0 * u
		b.stroke(PackedVector2Array([Vector2(-8.0, y), Vector2(w + 8.0, y)]), 2.0 * u, Color(WALL_DEEP, 0.6))
		y += 30.0 * u
		row += 1
	# the terrace from the wall past the foot, its flags in a running bond
	first = b.verts.size()
	b.polygon(_rect(-8.0, _wall, w + 8.0, h + 240.0 * u), Color.WHITE)
	CardFace.shade(b, first, FLAG, FLAG_LOW, _wall, h)
	Scenery.soft_disc(b, Vector2(w * 0.5, _wall), w * 0.6, 26.0 * u, Color(WALL_DEEP, 0.35))
	var fw := FLAG_W * u
	var fh := FLAG_H * u
	row = 0
	y = _wall
	while y < h + fh:
		var k := 1.0 + (y - _wall) / maxf(h - _wall, 1.0) * 0.25
		var shift := fw * k * 0.5 if row % 2 == 1 else 0.0
		var gx := -shift
		while gx < w + 8.0:
			b.stroke(PackedVector2Array([Vector2(gx, y), Vector2(gx, y + fh * k)]), 3.0 * u, Color(GROUT, 0.5))
			gx += fw * k
		b.stroke(PackedVector2Array([Vector2(-8.0, y), Vector2(w + 8.0, y)]), 3.0 * u, Color(GROUT, 0.5))
		y += fh * k
		row += 1
	# the pergola's beam across the sky, the vine hanging from it
	var beam := 34.0 * u
	b.polygon(_rect(-8.0, beam, w + 8.0, beam + 30.0 * u), BEAM_DEEP)
	b.polygon(_rect(-8.0, beam - 4.0 * u, w + 8.0, beam + 22.0 * u), BEAM)
	for k in 6:
		var px := w * (0.08 + k * 0.18)
		b.polygon(_rect(px - 14.0 * u, -h * OVER, px + 14.0 * u, beam + 34.0 * u), BEAM_DEEP)
		b.polygon(_rect(px - 14.0 * u, -h * OVER, px + 8.0 * u, beam + 28.0 * u), BEAM)
	for k in 9:
		var vx := w * (0.04 + k * 0.118) + rng.randf_range(-12.0, 12.0) * u
		var drop := rng.randf_range(60.0, 140.0) * u
		var pts := PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			pts.append(Vector2(vx + sin(t * 4.0 + k) * 10.0 * u, beam + 18.0 * u + drop * t))
		b.stroke(pts, 3.0 * u, VINE)
		for i in range(1, 9, 2):
			_leaf(b, pts[i] + Vector2(10.0 * u * (1 if i % 4 == 1 else -1), 0), 11.0 * u, 0.6 if i % 4 == 1 else -0.6)
		if k % 2 == 0:
			_bloom(b, pts[8], 9.0 * u)
	# pots of geraniums at the foot's corners
	var pot_y := minf(h - 40.0 * u, _foot + 160.0 * u)
	if pot_y > _foot + 60.0 * u:
		_pot(b, Vector2(w * 0.09, pot_y), u)
		_pot(b, Vector2(w * 0.91, pot_y), u)
	_shown = b.mesh()
	queue_redraw()

func _rect(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])

func _leaf(b: Face.Builder, at: Vector2, s: float, turn: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0 * TAU
		pts.append(at + Vector2(cos(t) * s, sin(t) * s * 0.5).rotated(turn))
	b.polygon(pts, VINE_HI if turn > 0.0 else VINE)

func _bloom(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 5:
		b.disc(at + Vector2.from_angle(i * TAU / 5.0 - PI * 0.5) * r * 0.7, r * 0.6, BLOOM)
	b.disc(at, r * 0.35, Color("f5c242"))

## A terracotta pot about `foot` (its base's middle), geraniums over it.
func _pot(b: Face.Builder, foot: Vector2, u: float) -> void:
	Scenery.soft_disc(b, foot + Vector2(0, 4.0 * u), 70.0 * u, 16.0 * u, Color(POT_DEEP, 0.3))
	var top := foot.y - 90.0 * u
	b.polygon(PackedVector2Array([Vector2(foot.x - 52.0 * u, top), Vector2(foot.x + 52.0 * u, top),
		Vector2(foot.x + 38.0 * u, foot.y), Vector2(foot.x - 38.0 * u, foot.y)]), POT)
	b.polygon(_rect(foot.x - 58.0 * u, top - 16.0 * u, foot.x + 58.0 * u, top + 4.0 * u), POT_DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(foot.x)
	for k in 7:
		var at := Vector2(foot.x + rng.randf_range(-50.0, 50.0) * u, top - rng.randf_range(20.0, 60.0) * u)
		b.disc(at, rng.randf_range(20.0, 28.0) * u, LEAF)
	for k in 4:
		var at := Vector2(foot.x + rng.randf_range(-40.0, 40.0) * u, top - rng.randf_range(44.0, 80.0) * u)
		for i in 5:
			b.disc(at + Vector2.from_angle(i * TAU / 5.0) * 8.0 * u, 8.0 * u, GERANIUM)
		b.disc(at, 5.0 * u, Color("f6c6d0"))
