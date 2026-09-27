extends Control

## The ink skin's page (ui/flat/ink.gd): warm stone paper under diagonal
## shafts of window light, the soft shadows of leaves in three corners, and
## behind the top bar a line drawing of arches strung with beads, standing
## in low hills beside a pale sun. The whole picture is one mesh, rebuilt only
## when the screen's size or the top inset changes.

const Ink = preload("res://ui/flat/ink.gd")
const Face = preload("res://ui/faces/face.gd")

## Where the top bar starts, in this Control's space (the host's margin plus
## the safe area's top inset). The header drawing hangs from it.
var header_top := 40.0:
	set(v):
		header_top = v
		_mesh = null
		queue_redraw()

var _mesh: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void:
		_mesh = null
		queue_redraw())

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Ink.PAGE)
	if size.x <= 0.0:
		return
	if _mesh == null:
		var b := Face.Builder.new()
		_beams(b)
		_leaves(b)
		_header(b)
		_mesh = b.mesh()
	draw_mesh(_mesh, null)

# --- light ---

## Shafts of light falling from the upper right, with a darker lane between
## some of them: bands soft across their width, laid along one direction.
func _beams(b: Face.Builder) -> void:
	var dir := Vector2(-0.58, 1.0).normalized()
	var nrm := Vector2(dir.y, -dir.x)
	var reach := size.length() * 1.2
	var origin := Vector2(size.x * 1.05, -size.y * 0.05)
	# [offset along the normal, width, colour]
	var bands := [
		[-120.0, 170.0, Color(1, 1, 1, 0.40)],
		[80.0, 120.0, Color(Ink.PAGE_DEEP, 0.75)],
		[260.0, 230.0, Color(1, 1, 1, 0.45)],
		[470.0, 90.0, Color(Ink.PAGE_DEEP, 0.65)],
		[640.0, 200.0, Color(1, 1, 1, 0.36)],
		[900.0, 150.0, Color(Ink.PAGE_DEEP, 0.40)],
		[1080.0, 180.0, Color(1, 1, 1, 0.24)],
		[1400.0, 260.0, Color(1, 1, 1, 0.20)],
	]
	for band in bands:
		var mid: Vector2 = origin - nrm * float(band[0])
		_soft_band(b, mid - dir * reach * 0.2, mid + dir * reach, nrm, float(band[1]), band[2])

## A straight band from `a` to `b` of `width` across `nrm`, full in its
## middle half and fading to nothing at both edges.
func _soft_band(b: Face.Builder, a: Vector2, z: Vector2, nrm: Vector2, width: float, colour: Color) -> void:
	var clear := Color(colour, 0.0)
	var steps := [[-0.5, clear], [-0.22, colour], [0.22, colour], [0.5, clear]]
	var first := b.verts.size()
	for s in steps:
		b.vertex(a + nrm * width * float(s[0]), s[1])
		b.vertex(z + nrm * width * float(s[0]), s[1])
	for i in 3:
		var k := first + i * 2
		b.tri(k, k + 1, k + 3)
		b.tri(k, k + 3, k + 2)

# --- leaves ---

func _leaves(b: Face.Builder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# [root, direction the sprig grows, length, leaf size]
	_sprig(b, rng, Vector2(-40, -30), Vector2(0.9, 0.7), 420.0, 70.0)
	_sprig(b, rng, Vector2(-30, 160), Vector2(1.0, 0.1), 260.0, 55.0)
	_sprig(b, rng, Vector2(-40, size.y - 520), Vector2(0.9, 0.25), 360.0, 68.0)
	_sprig(b, rng, Vector2(-30, size.y + 20), Vector2(0.7, -0.7), 420.0, 75.0)
	_sprig(b, rng, Vector2(size.x + 30, size.y - 60), Vector2(-0.8, -0.6), 320.0, 62.0)
	_sprig(b, rng, Vector2(size.x + 40, size.y - 330), Vector2(-1.0, 0.15), 200.0, 50.0)

## A stem from `root` along `dir`, leaves alternating off it, all in a pale
## shadow of the ink: the shade a plant on the sill casts, not the plant.
func _sprig(b: Face.Builder, rng: RandomNumberGenerator, root: Vector2, dir: Vector2, length: float, leaf: float) -> void:
	var shade := Color(Ink.INK, 0.09)
	var d := dir.normalized()
	var side := Vector2(-d.y, d.x)
	var bend := rng.randf_range(-0.25, 0.25)
	var pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		pts.append(root + d * length * t + side * sin(t * PI) * length * bend * 0.4)
	b.stroke(pts, 5.0, shade)
	var n := int(length / (leaf * 0.55))
	for i in n:
		var t := 0.15 + 0.85 * float(i) / maxf(1.0, n - 1)
		var at := root + d * length * t + side * sin(t * PI) * length * bend * 0.4
		var flip := 1.0 if i % 2 == 0 else -1.0
		var ang := d.angle() + flip * rng.randf_range(0.6, 1.1)
		var s := leaf * rng.randf_range(0.75, 1.15) * (1.0 - 0.35 * t)
		_leaf(b, at, ang, s, shade)
	_leaf(b, pts[pts.size() - 1], d.angle(), leaf * 0.8, shade)

## A pointed leaf from `at`, `length` long along `ang`.
func _leaf(b: Face.Builder, at: Vector2, ang: float, length: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var w := length * 0.32
	for i in 11:
		var t := i / 10.0
		pts.append(Vector2(t * length, -sin(t * PI) * w * (1.0 - 0.25 * t)))
	for i in range(9, 0, -1):
		var t := i / 10.0
		pts.append(Vector2(t * length, sin(t * PI) * w * (1.0 - 0.25 * t)))
	var xf := Transform2D(ang, at)
	b.polygon(xf * pts, colour)

# --- the header ---

## Hills and a sun low behind the top bar, and the arches: a line drawing
## taken from the mock at 1080 across, hung from `header_top`.
func _header(b: Face.Builder) -> void:
	var k := size.x / 1080.0
	var top := header_top
	# The arches, drawn from the mock (x 579-755, y 40-312 there) and fitted
	# into the gap between the flush-left title and the buttons.
	var at := func(x: float, y: float) -> Vector2:
		return Vector2((528.0 + (x - 579.0) * 0.8) * k, top + (y - 40.0) * 0.8)
	# The sun, pale, under the settings button and half behind the hills.
	b.disc(Vector2(905.0 * k, top + 222.0), 50.0 * k, Color(Ink.HAZE, 0.6))
	_hill(b, top + 236.0, 34.0, 0.004, 1.3, Color(Ink.HAZE, 0.5), k)
	_hill(b, top + 252.0, 40.0, 0.0065, 4.0, Color(Ink.HAZE, 0.6), k)
	_hill(b, top + 268.0, 26.0, 0.009, 2.2, Color(Ink.PAGE_DEEP, 0.95), k)
	var line := Color(Ink.INK, 0.62)
	var w := 3.0
	var foot := 312.0
	# [left leg x, right leg x, apex y, left leg foot, right leg foot]
	var arches := [
		[641.0, 703.0, 40.0, foot, foot],
		[606.0, 666.0, 95.0, foot, foot],
		[579.0, 638.0, 174.0, foot - 8.0, foot],
		[706.0, 755.0, 206.0, foot, foot],
	]
	for a in arches:
		var lx: float = a[0]
		var rx: float = a[1]
		var r := (rx - lx) * 0.5
		var cy: float = a[2] + r
		var pts := PackedVector2Array()
		pts.append(at.call(lx, a[3]))
		for p in Face.Builder.arc_points(Vector2(lx + r, cy), r, PI, TAU):
			pts.append(at.call(p.x, p.y))
		pts.append(at.call(rx, a[4]))
		b.stroke(pts, w, line)
	# The thread the arches stand on, trailing off to the left.
	var tail := PackedVector2Array()
	for p in Face.Builder.bezier3(Vector2(579.0, foot - 8.0), Vector2(575.0, foot + 12.0),
			Vector2(540.0, foot - 2.0), Vector2(490.0, foot + 6.0)):
		tail.append(at.call(p.x, p.y))
	b.stroke(tail, w, line)
	var bead := Color(Ink.INK, 0.7)
	for p: Vector2 in [Vector2(703, 151), Vector2(606, 135), Vector2(579, 257),
			Vector2(638, 274), Vector2(755, 291), Vector2(606, 283)]:
		b.disc(at.call(p.x, p.y), 7.0 * k, bead)

## A band of rolling hills whose crest wanders about `y` by `amp`, fading to
## nothing a little below it.
func _hill(b: Face.Builder, y: float, amp: float, freq: float, phase: float, colour: Color, k: float) -> void:
	var clear := Color(colour, 0.0)
	var steps := 48
	var first := b.verts.size()
	for i in steps + 1:
		var x := size.x * i / steps
		var u := x / k
		var crest := y - amp * (0.6 * sin(u * freq + phase) + 0.4 * sin(u * freq * 2.3 + phase * 1.7))
		b.vertex(Vector2(x, crest), colour)
		b.vertex(Vector2(x, y + 70.0), colour)
		b.vertex(Vector2(x, y + 150.0), clear)
	for i in steps:
		var a := first + i * 3
		var c := a + 3
		b.tri(a, c, c + 1)
		b.tri(a, c + 1, a + 1)
		b.tri(a + 1, c + 1, c + 2)
		b.tri(a + 1, c + 2, a + 2)
