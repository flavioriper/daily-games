extends Control

## Pearl Dive's world: the water the bell goes down, edge to edge under the
## board and the host's rows (CLAUDE.md: a game's world fills the screen).
## It is the menu card's picture (ui/menu/cards/pearl.gd) at the size of the
## screen, seen from under the surface: pale air over the top, behind the
## wordmark, which is ink; the surface with its shine and the dive's float
## in the gap of the tools row; pale water under it, a little deeper toward
## the floor; and the sea floor's sand from the line the board names
## (`set_ground`) to the foot, where the keyboard stands on it. The floor's
## things (coral, weed, shells, a starfish, pebbles) are in the band the
## board leaves over the keys and along the very foot.
##
## The water stays pale all the way down: the keys and the paper lie over
## it, and the deep is the board's own shaft beside the paper.
##
## One mesh, built when the rect or the ground line changes and kept
## (`_shown`) until the next replaces it; the standing bubbles are a second,
## on a child whose alpha breathes (still under Motion.reduce).

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CardFace = preload("res://ui/menu/cards/card_face.gd")
const Art = preload("res://ui/faces/pearl_art.gd")

## The screen the picture was drawn on; everything scales with the width.
const W := 1080.0
const AIR_TOP := Color("fbf8ee")
const AIR_LOW := Color("eaf5f1")
const SEA_TOP := Color("d9f0f2")
const SEA_LOW := Color("bfe2e6")
const SHINE := Color("f7fdfd")
const SAND_TOP := Color("f4e8c8")
const SAND_LOW := Color("ead8ab")
const SAND_MARK := Color("d9c18c")
const CORAL := Color("f0a79a")
const CORAL_DEEP := Color("dd8679")
const WEED := Color("8fc4a4")
const WEED_DEEP := Color("6fae8c")
const STAR := Color("f3b56a")
const STAR_DEEP := Color("de964a")
const PEBBLE := Color("cfc4b0")
const ROPE := Color("b9a98c")
## The surface, as a share of the height: in the gap of the tools row.
const SURFACE := 0.243
## The light behind the wordmark: its middle as shares, its rings [radius
## at W, alpha].
const SUN_AT := Vector2(0.10, 0.02)
const SUN_RINGS := [[620.0, 0.10], [420.0, 0.12], [250.0, 0.16]]
## The dive's float on the surface, and two small ripples: x as a share.
const FLOAT_X := 0.56
const RIPPLES := [[0.40, 46.0], [0.70, 34.0]]
## Soft motes of light in the water: [x, y as shares, radius at W, alpha].
## None lies under the paper's middle.
const MOTES := [
	[0.022, 0.36, 9.0, 0.5], [0.978, 0.44, 7.0, 0.45], [0.018, 0.58, 6.0, 0.4],
	[0.984, 0.66, 8.0, 0.45], [0.33, 0.262, 6.0, 0.4], [0.80, 0.258, 5.0, 0.35],
]
## The bubbles that breathe: [x, y as shares, radius at W].
const BUBBLES := [
	[0.455, 0.228, 7.0], [0.478, 0.214, 4.5], [0.665, 0.232, 5.5],
	[0.020, 0.50, 5.0], [0.981, 0.56, 6.0], [0.022, 0.70, 4.0],
]
const BREATHE := 3.6
const BREATHE_LOW := 0.4
## How far the sand's line comes up at its crests, at W.
const SWELL := 16.0

var _shown: ArrayMesh
var _bubbles: Control
var _bubbles_shown: ArrayMesh
var _breathe: Tween
## The sand's line, in this control's pixels; under 0 it is not known yet
## and the floor lies at a share of the height.
var _ground := -1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubbles = Control.new()
	_bubbles.name = "Bubbles"
	_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubbles.draw.connect(func() -> void:
		if _bubbles_shown != null:
			_bubbles.draw_mesh(_bubbles_shown, null))
	add_child(_bubbles)
	resized.connect(_build)
	_build()
	_breathe = Motion.pulse(_bubbles, "modulate:a", 1.0, BREATHE_LOW, BREATHE)

func _draw() -> void:
	if _shown != null:
		draw_mesh(_shown, null)

## The board says where the sea floor starts: just under its own foot.
func set_ground(y: float) -> void:
	if is_equal_approx(y, _ground):
		return
	_ground = y
	_build()

func _build() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var u := size.x / W
	var over := size.y * 0.7
	var surface := size.y * SURFACE
	var ground := _ground if _ground > 0.0 else size.y * 0.76
	var b := Face.Builder.new()
	# The air, over-drawn above the top: the world may ride under a win.
	var first := b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, -over), Vector2(size.x + 8.0, -over),
		Vector2(size.x + 8.0, surface + 4.0), Vector2(-8.0, surface + 4.0)]), Color.WHITE)
	CardFace.shade(b, first, AIR_TOP, AIR_LOW, 0.0, surface)
	var sun := SUN_AT * size
	for ring in SUN_RINGS:
		b.disc(sun, ring[0] * u, Color(Pal.SUN_RAY, ring[1]))
	# The water under it, pale all the way down.
	first = b.verts.size()
	b.polygon(PackedVector2Array([Vector2(-8.0, surface), Vector2(size.x + 8.0, surface),
		Vector2(size.x + 8.0, size.y + over), Vector2(-8.0, size.y + over)]), Color.WHITE)
	CardFace.shade(b, first, SEA_TOP, SEA_LOW, surface, ground)
	# The surface: a band of shine, two ripples and the dive's float.
	b.stroke(PackedVector2Array([Vector2(-8.0, surface), Vector2(size.x + 8.0, surface)]), 16.0 * u,
		Color(SHINE, 0.55), false, false)
	b.stroke(PackedVector2Array([Vector2(-8.0, surface), Vector2(size.x + 8.0, surface)]), 4.0 * u,
		Color(SHINE, 0.95), false, false)
	for r in RIPPLES:
		var at := Vector2(size.x * float(r[0]), surface + 15.0 * u)
		b.stroke(PackedVector2Array([at - Vector2(float(r[1]) * u, 0.0), at + Vector2(float(r[1]) * u, 0.0)]),
			3.0 * u, Color(SHINE, 0.7))
	_float(b, Vector2(size.x * FLOAT_X, surface), u)
	for m in MOTES:
		var at := Vector2(m[0], m[1]) * size
		b.disc(at, float(m[2]) * 2.2 * u, Color(SHINE, float(m[3]) * 0.3))
		b.disc(at, float(m[2]) * u, Color(SHINE, float(m[3])))
	# The floor's things that stand behind the sand's line.
	_weed(b, Vector2(size.x * 0.905, ground + 6.0 * u), 86.0 * u, u, 1.0)
	_weed(b, Vector2(size.x * 0.945, ground + 6.0 * u), 60.0 * u, u, -1.0)
	_weed(b, Vector2(size.x * 0.040, ground + 6.0 * u), 70.0 * u, u, -1.0)
	_coral(b, Vector2(size.x * 0.115, ground + 4.0 * u), 66.0 * u, u)
	_coral(b, Vector2(size.x * 0.185, ground + 6.0 * u), 40.0 * u, u)
	# The sand, from its line to past the foot.
	var line := PackedVector2Array()
	var steps := 36
	for i in steps + 1:
		var x := lerpf(-8.0, size.x + 8.0, float(i) / float(steps))
		line.append(Vector2(x, ground - (sin(x / size.x * TAU * 1.5 + 0.6) * 0.5 + 0.5) * SWELL * u))
	var sand := line.duplicate()
	sand.append(Vector2(size.x + 8.0, size.y + over))
	sand.append(Vector2(-8.0, size.y + over))
	first = b.verts.size()
	b.polygon(sand, Color.WHITE)
	CardFace.shade(b, first, SAND_TOP, SAND_LOW, ground - SWELL * u, size.y)
	b.stroke(line, 5.0 * u, Color(SHINE, 0.6), false, false)
	# On the sand, in the band over the keys: the pearl's shell, a starfish,
	# pebbles, the bell's spare rope.
	var on := ground + 34.0 * u
	Art.shell(b, Vector2(size.x * 0.300, on - 6.0 * u), 15.0 * u)
	_starfish(b, Vector2(size.x * 0.790, on + 2.0 * u), 24.0 * u, 0.3)
	_rope(b, Vector2(size.x * 0.560, on + 2.0 * u), u)
	for p in [[0.415, 4.0, 9.0], [0.445, 12.0, 6.0], [0.690, 8.0, 7.0], [0.235, 14.0, 6.0], [0.865, 16.0, 8.0]]:
		b.ellipse(Vector2(size.x * float(p[0]), on + float(p[1]) * u), float(p[2]) * u, float(p[2]) * 0.7 * u, PEBBLE)
	for p in [[0.36, 2.0, 30.0], [0.62, 20.0, 40.0], [0.48, 26.0, 24.0], [0.93, 4.0, 22.0], [0.06, 22.0, 26.0]]:
		var at := Vector2(size.x * float(p[0]), on + float(p[1]) * u)
		b.stroke(PackedVector2Array([at - Vector2(float(p[2]) * u, 0.0), at + Vector2(float(p[2]) * u, 0.0)]),
			3.0 * u, Color(SAND_MARK, 0.5))
	# Along the very foot, under the keys: shells, pebbles, a small starfish.
	var foot := size.y - 20.0 * u
	Art.shell(b, Vector2(size.x * 0.085, foot - 2.0 * u), 11.0 * u)
	_starfish(b, Vector2(size.x * 0.905, foot), 14.0 * u, -0.5)
	for p in [[0.20, 6.0], [0.34, 8.0], [0.52, 5.0], [0.66, 7.0], [0.78, 5.0]]:
		b.ellipse(Vector2(size.x * float(p[0]), foot + 2.0 * u), float(p[1]) * u, float(p[1]) * 0.7 * u, PEBBLE)
	_shown = b.mesh()
	queue_redraw()
	var bb := Face.Builder.new()
	for k in BUBBLES:
		Art.bubble(bb, Vector2(k[0], k[1]) * size, float(k[2]) * u, 0.8)
	_bubbles_shown = bb.mesh()
	_bubbles.size = size
	_bubbles.queue_redraw()

## The float the bell's rope hangs from, half in the water.
func _float(b: Face.Builder, at: Vector2, u: float) -> void:
	var r := 15.0 * u
	b.disc(at, r, CORAL_DEEP)
	b.disc(at + Vector2(0.0, -1.5 * u), r * 0.9, CORAL)
	b.polygon(PackedVector2Array([at + Vector2(-r, 0.0), at + Vector2(r, 0.0), at + Vector2(r * 0.7, r * 0.72),
		at + Vector2(0.0, r), at + Vector2(-r * 0.7, r * 0.72)]), Color(SHINE, 0.75))
	b.disc(at + Vector2(-r * 0.35, -r * 0.4), r * 0.22, Color(SHINE, 0.8))
	b.stroke(PackedVector2Array([at + Vector2(-r * 1.9, 2.0 * u), at + Vector2(r * 1.9, 2.0 * u)]), 3.0 * u,
		Color(SHINE, 0.9))

## A strand of weed `tall` high, leaning to `lean`'s side, rooted at `root`.
func _weed(b: Face.Builder, root: Vector2, tall: float, u: float, lean: float) -> void:
	for k in 3:
		var dx := (float(k) - 1.0) * 13.0 * u
		var h := tall * (1.0 - 0.22 * absf(float(k) - 1.0))
		var pts := Face.Builder.bezier3(root + Vector2(dx, 0.0), root + Vector2(dx + lean * 12.0 * u, -h * 0.35),
			root + Vector2(dx - lean * 12.0 * u, -h * 0.7), root + Vector2(dx + lean * 8.0 * u, -h), 12)
		b.stroke(pts, 9.0 * u, WEED_DEEP if k == 1 else WEED)

## A sprig of coral `tall` high on `root`: a stem and four round-ended arms.
func _coral(b: Face.Builder, root: Vector2, tall: float, u: float) -> void:
	var w := tall * 0.16
	b.stroke(PackedVector2Array([root, root + Vector2(0.0, -tall)]), w, CORAL_DEEP)
	for arm in [[-1.0, 0.30, 0.42], [1.0, 0.45, 0.46], [-1.0, 0.62, 0.30], [1.0, 0.74, 0.26]]:
		var from := root + Vector2(0.0, -tall * float(arm[1]))
		var to := from + Vector2(float(arm[0]) * tall * float(arm[2]), -tall * float(arm[2]) * 0.8)
		b.stroke(PackedVector2Array([from, to]), w * 0.85, CORAL)
	b.stroke(PackedVector2Array([root + Vector2(0.0, -tall * 0.1), root + Vector2(0.0, -tall)]), w * 0.6, CORAL)

## A five-armed starfish of `r`, turned by `turn`.
func _starfish(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	for ink in [[1.0, STAR_DEEP, Vector2(0.0, 2.0)], [0.9, STAR, Vector2.ZERO]]:
		var pts := PackedVector2Array()
		for i in 10:
			var rad: float = r * float(ink[0]) * (1.0 if i % 2 == 0 else 0.45)
			pts.append(at + (ink[2] as Vector2) + Vector2.from_angle(turn - PI * 0.5 + float(i) * PI * 0.2) * rad)
		b.polygon(pts, ink[1])
	b.disc(at, r * 0.14, Color(SHINE, 0.6))

## A coil of the bell's spare rope lying on the sand.
func _rope(b: Face.Builder, at: Vector2, u: float) -> void:
	for k in 3:
		var rx := (30.0 - float(k) * 8.0) * u
		b.stroke(Face.Builder.ring(at + Vector2(0.0, -float(k) * 3.0 * u), rx, rx * 0.42), 5.0 * u, ROPE, true)
	b.stroke(Face.Builder.bezier3(at + Vector2(30.0 * u, 0.0), at + Vector2(58.0 * u, 6.0 * u),
		at + Vector2(66.0 * u, -12.0 * u), at + Vector2(92.0 * u, -2.0 * u), 10), 5.0 * u, ROPE)
