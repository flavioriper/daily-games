extends Control

## How Big?'s world: the measuring field, edge to edge under the board and
## the host's rows (CLAUDE.md: a game's world fills the screen). It is the
## sky and the grass the board drew inside its card (puzzles/how_big2d.gd),
## let out to the screen: pale morning air at the top, behind the wordmark,
## turning into the board's own sky by the tools row; two far hills washed
## into it along the ground line; and the meadow from the ground line to the
## foot, where the things stand and their captions are written in ink.
##
## The game's own things are a measurer's: a cloud and a little size bracket
## in the gap of the tools row, and in the foot's left, clear of the Lock
## button on its right, a folding rule left open on the grass, a tape reel
## with its tongue run out, daisies and tufts. Nothing in it is a silhouette,
## so nothing reads as a thing to size, and nothing lies under the stage or
## the captions but sky and grass.
##
## The board tells it where the ground line stands (`set_ground`). The mesh
## runs most of a screen past the top and the foot, because on the win the
## world rides up and down with the board so the grass stays under the
## things. One mesh, built when the rect or the line changes and kept
## (`_shown`); four pollen motes are a second, on a child whose alpha
## breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
## How far past the top and the foot the sky and the grass run, as a share
## of the height.
const OVER := 0.7
const AIR := Color("fdf8ec")
## The board's own sky (Pal.SKY_HORIZON), which its white answer is read on.
const SKY := Color("e8f2f7")
const SKY_LOW := Color("dcecf2")
const HILL_FAR := Color("d3e6dc")
const HILL_NEAR := Color("c9e0cb")
## The board's meadow (Pal.MEADOW), a little deeper toward the foot.
const GRASS := Color("cfdda6")
const GRASS_LOW := Color("bdd08f")
const LIP := Color("6ba845")
const CLOUD := Color("ffffff")
const RULE := Color("e9c27a")
const RULE_EDGE := Color("c99a52")
const RULE_INK := Color("7a5a34")
const BRASS := Color("d9a441")
const REEL := Color("e7745f")
const REEL_DEEP := Color("c4553f")
const TAPE := Color("f7dd7a")
const TAPE_INK := Color("8a6a2c")
const PETAL := Color("fffdf8")
const POLLEN := Color("f5a623")
## Where the air has become the sky, as a share of the height.
const AIR_TO := 0.27
## The sun's soft rings behind the wordmark: its middle as shares, then
## [radius at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.07], [420.0, 0.08], [250.0, 0.10]]
## The sky's clouds, where the card's stood: [x as a share, y as a share of
## the way from the tools row to the ground line, radius at W].
const CLOUDS := [[0.22, 0.13, 34.0], [0.53, 0.20, 40.0], [0.83, 0.10, 30.0]]
## The gap of the tools row: a small cloud, and a size bracket beside it.
const GAP_CLOUD := [0.455, 0.232, 26.0]
const GAP_BRACKET := [0.640, 0.232, 96.0]
## The foot's things stand in a band this tall over the bottom edge, and
## left of this share of the width (the Lock button is at its right).
const FOOT_BAND := 170.0
const FOOT_RIGHT := 0.60
## The motes: [x as a share, y over the bottom edge at W (negative: as a
## share of the height from the top), radius at W].
const MOTES := [[0.12, 150.0, 5.0], [0.31, 96.0, 4.0], [0.50, 138.0, 4.5], [0.66, -0.222, 4.0]]
const BREATHE := 3.6
const BREATHE_LOW := 0.3

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
	_breath = Motion.pulse(_motes, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

## Where the things stand, in this world's own pixels. Rebuilt only when the
## line moves.
func set_ground(y: float) -> void:
	if is_equal_approx(y, _ground):
		return
	_ground = y
	_build()

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var g := _ground if _ground > 0.0 else size.y * 0.81
	var over := size.y * OVER
	var b := Face.Builder.new()
	# The air and the sky, from well over the top down to the ground line.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -over), Vector2(size.x + 8.0, -over),
		Vector2(size.x + 8.0, g), Vector2(-8.0, g)]), Color.WHITE)
	CardFace.shade(b, first, AIR, SKY, size.y * 0.13, size.y * AIR_TO)
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, g - 260.0 * u), Vector2(size.x + 8.0, g - 260.0 * u),
		Vector2(size.x + 8.0, g), Vector2(-8.0, g)]), Color.WHITE)
	CardFace.shade(b, first, Color(SKY_LOW, 0.0), SKY_LOW, g - 260.0 * u, g)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The clouds the card had, in the sky over the things.
	var top := size.y * AIR_TO
	for c in CLOUDS:
		Scenery.cloud(b, Vector2(size.x * c[0], lerpf(top, g, c[1])), c[2] * u, Color(CLOUD, 0.7))
	# The gap of the tools row: a cloud, and the board's bracket lying flat.
	Scenery.cloud(b, Vector2(GAP_CLOUD[0], GAP_CLOUD[1]) * size, GAP_CLOUD[2] * u, Color(CLOUD, 0.85))
	var mid := Vector2(GAP_BRACKET[0], GAP_BRACKET[1]) * size
	var half: float = GAP_BRACKET[2] * u * 0.5
	var ink := Color(Pal.TEXT, 0.22)
	b.stroke(PackedVector2Array([mid - Vector2(half, 0.0), mid + Vector2(half, 0.0)]), 3.5 * u, ink)
	for s in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([mid + Vector2(half * s, -9.0 * u), mid + Vector2(half * s, 9.0 * u)]), 3.5 * u, ink)
	for k in range(-2, 3):
		b.stroke(PackedVector2Array([mid + Vector2(half * 0.33 * k, 0.0), mid + Vector2(half * 0.33 * k, 6.0 * u)]), 2.5 * u, ink)
	# Two far hills on the ground line, washed into the sky.
	b.ellipse(Vector2(size.x * 0.24, g + 40.0 * u), size.x * 0.46, 104.0 * u, Color(HILL_FAR, 0.75))
	b.ellipse(Vector2(size.x * 0.80, g + 46.0 * u), size.x * 0.40, 96.0 * u, Color(HILL_NEAR, 0.7))
	# The meadow, from the line to well past the foot, and its lip.
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, g), Vector2(size.x + 8.0, g),
		Vector2(size.x + 8.0, size.y + over), Vector2(-8.0, size.y + over)]), Color.WHITE)
	CardFace.shade(b, first, GRASS, GRASS_LOW, g + 150.0 * u, size.y)
	b.stroke(PackedVector2Array([Vector2(-8.0, g), Vector2(size.x + 8.0, g)]), 5.0 * u, LIP, false, false)
	_foot(b, u, g)
	_shown = b.mesh()
	queue_redraw()
	var mb := Face.Builder.new()
	for m in MOTES:
		var y: float = size.y * -float(m[1]) if float(m[1]) < 0.0 else size.y - float(m[1]) * u
		mb.disc(Vector2(size.x * m[0], y), m[2] * u * 2.2, Color(Pal.SUN_RAY, 0.12))
		mb.disc(Vector2(size.x * m[0], y), m[2] * u, Color(PETAL, 0.85))
	_motes_shown = mb.mesh()
	_motes.size = size
	_motes.queue_redraw()

## The measurer's things in the grass under the captions, left of the Lock
## button. They fit the band the ground line leaves and are left out when it
## leaves too little.
func _foot(b: Face.Builder, u: float, g: float) -> void:
	var base := size.y - 34.0 * u
	var room := base - (g + 190.0 * u)
	var k := clampf(room / (FOOT_BAND * u - 34.0 * u), 0.0, 1.0)
	# Tufts along the very foot, sparse, the right kept bare for the button.
	for t in [[0.035, 20.0, 26.0], [0.205, 14.0, 20.0], [0.435, 18.0, 22.0], [0.575, 12.0, 18.0]]:
		Scenery.tuft(b, Vector2(size.x * t[0], size.y - t[1] * u), t[2] * u)
	if k < 0.55:
		return
	var s := u * k
	# A folding rule, three leaves open in a zigzag, brass at the joints.
	var a := Vector2(size.x * 0.060, base - 18.0 * s)
	var joints := [a, a + Vector2(150.0, -62.0) * s, a + Vector2(300.0, -6.0) * s, a + Vector2(446.0, -58.0) * s]
	if joints[3].x > size.x * FOOT_RIGHT:
		return
	for i in 3:
		var p: Vector2 = joints[i]
		var q: Vector2 = joints[i + 1]
		b.stroke(PackedVector2Array([p + Vector2(0.0, 5.0 * s), q + Vector2(0.0, 5.0 * s)]), 26.0 * s, Color(Pal.TEXT, 0.10))
		b.stroke(PackedVector2Array([p, q]), 26.0 * s, RULE_EDGE)
		b.stroke(PackedVector2Array([p, q]), 20.0 * s, RULE)
		var along := (q - p).normalized()
		var side := along.orthogonal()
		var n := 9
		for t in range(1, n):
			var at := p.lerp(q, float(t) / float(n))
			var tall := (8.0 if t % 3 == 0 else 5.0) * s
			b.stroke(PackedVector2Array([at + side * 10.0 * s, at + side * (10.0 * s - tall)]), 2.0 * s, Color(RULE_INK, 0.7), false, false)
	for j in joints:
		b.disc(j, 8.0 * s, RULE_EDGE)
		b.disc(j, 5.0 * s, BRASS)
	# A tape reel a little way off, its tongue run out toward the rule.
	var reel := Vector2(size.x * 0.515, base - 44.0 * s)
	if reel.x + 50.0 * s < size.x * FOOT_RIGHT:
		var tongue := PackedVector2Array([reel + Vector2(-34.0, 30.0) * s, reel + Vector2(-150.0, 36.0) * s])
		b.stroke(tongue, 18.0 * s, TAPE_INK, false, false)
		b.stroke(tongue, 14.0 * s, TAPE, false, false)
		for t in 6:
			var at := tongue[0].lerp(tongue[1], (float(t) + 0.5) / 6.0)
			b.stroke(PackedVector2Array([at + Vector2(0.0, -7.0 * s), at + Vector2(0.0, -1.0 * s)]), 2.0 * s, Color(TAPE_INK, 0.8), false, false)
		b.fan(Face.Builder.round_rect(tongue[1] + Vector2(-7.0, -11.0) * s, Vector2(9.0, 22.0) * s, 3.0 * s), BRASS)
		Scenery.soft_disc(b, reel + Vector2(0.0, 44.0 * s), 50.0 * s, 10.0 * s, Color(Pal.TEXT, 0.12))
		b.disc(reel + Vector2(0.0, 4.0 * s), 44.0 * s, REEL_DEEP)
		b.disc(reel, 44.0 * s, REEL)
		b.disc(reel, 24.0 * s, Color(PETAL, 0.9))
		b.disc(reel, 8.0 * s, REEL_DEEP)
		b.disc(reel + Vector2(-16.0, -20.0) * s, 9.0 * s, Color(PETAL, 0.25))
	# Daisies between them.
	for d in [[0.045, 92.0, 11.0], [0.395, 26.0, 12.0], [0.335, 104.0, 9.0]]:
		_daisy(b, Vector2(size.x * d[0], base - (d[1] - 34.0) * s), d[2] * s)

func _daisy(b: Face.Builder, at: Vector2, r: float) -> void:
	for i in 6:
		b.disc(at + Vector2.from_angle(i * TAU / 6.0) * r * 0.8, r * 0.55, PETAL)
	b.disc(at, r * 0.5, POLLEN)
