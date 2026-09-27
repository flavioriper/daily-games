extends RefCounted

## Stackwood's drawings (spec
## docs/superpowers/specs/2026-09-27-arcade-stackwood-design.md): painted
## wooden toy blocks, one colour a number, the rainbow block, the bomb, the
## zap and the acorn. Each is built once per look and size, its origin at
## the block's centre, and moved by the draw transform; shared with the
## Arcade tab's banner. The number is lettered over the mesh by the caller
## (`number()`), because a glyph is not a mesh.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const INK := Color("3b3028")
const WOOD := Color("c89664")
const WOOD_DEEP := Color("9c6b45")
const WOOD_HI := Color("e0b98a")
const ACORN := Color("b8793f")
const ACORN_CAP := Color("7a5232")
const BOMB := Color("4a4250")
const BOMB_HI := Color("6e6478")
const FUSE := Color("d9b27a")
const SPARK := Color("ffd65c")
const ZAP := Color("7fd6e8")
const ZAP_DEEP := Color("3f9fb8")
const GOLD := Color("f2c14e")

## A number's paint, by its power of two: 2 is butter, 4 apricot, 8 coral,
## up the wheel to 1024's olive, 2048's gold and the dark woods past it.
const PAINT := [
	Color("f0e6d2"),  # 1 (unused)
	Color("f7dc9c"),  # 2
	Color("f5b77e"),  # 4
	Color("ee8d6e"),  # 8
	Color("e7707c"),  # 16
	Color("c985c6"),  # 32
	Color("9391dc"),  # 64
	Color("6fb0de"),  # 128
	Color("5fc1ad"),  # 256
	Color("8cc36b"),  # 512
	Color("c9c052"),  # 1024
	Color("f2b632"),  # 2048
	Color("d9774a"),  # 4096
	Color("8a5a9e"),  # 8192
	Color("3f7f8c"),  # 16384
	Color("4a4250"),  # 32768
]

static var _cache := {}

static func exp_of(v: int) -> int:
	var e := 0
	while (1 << (e + 1)) <= v:
		e += 1
	return e

static func paint(v: int) -> Color:
	return PAINT[clampi(exp_of(v), 1, PAINT.size() - 1)]

## Ink or paper, whichever reads on the block's paint.
static func number_colour(v: int) -> Color:
	var c := paint(v)
	return Color("fffaf0") if c.get_luminance() < 0.52 else INK

## A block of number `v` (0 is the rainbow block, -1 the bomb) `s` pixels
## square, centred on the origin: a bevelled face over a lip of darker wood,
## a lit top edge, grain lines and end-grain rings in the corner. A bigger
## number is dressed up: from 128 a painted frame, from 1024 a gilt one with
## brass studs in the corners.
static func block(v: int, s: float) -> ArrayMesh:
	var key := "b%d_%d" % [v, roundi(s)]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 400:
		_cache.clear()
	var b := Face.Builder.new()
	var half := s * 0.5
	var lip := s * 0.09
	var r := s * 0.16
	var base := paint(v) if v > 0 else (BOMB if v < 0 else Color("f6efe4"))
	var deep := base.darkened(0.28)
	var e := exp_of(v) if v > 0 else 0
	# the shadow it casts on what is under it
	b.fan(Face.Builder.round_rect(Vector2(-half + s * 0.04, -half + s * 0.1), Vector2(s - s * 0.02, s - s * 0.04), r), Color(0.2, 0.12, 0.05, 0.18))
	# the lip: the block's side, seen under its face, shaded at its foot
	b.fan(Face.Builder.round_rect(Vector2(-half, -half + lip), Vector2(s, s - lip), r), deep)
	b.fan(Face.Builder.round_rect(Vector2(-half + s * 0.06, half - s * 0.05), Vector2(s * 0.88, s * 0.03), s * 0.015), Color(deep.darkened(0.25), 0.5))
	var face_at := Vector2(-half, -half)
	var face := Vector2(s, s - lip)
	# the bevel: a shaded rim round the face, lit up and to the left
	b.fan(Face.Builder.round_rect(face_at, face, r), base.darkened(0.1))
	b.fan(Face.Builder.round_rect(face_at, face - Vector2(s * 0.035, s * 0.035), r), base.lightened(0.12))
	b.fan(Face.Builder.round_rect(face_at + Vector2(s * 0.03, s * 0.03), face - Vector2(s * 0.06, s * 0.06), r * 0.9), base)
	# a softer panel inset in the face, and the lit top edge
	b.fan(Face.Builder.round_rect(face_at + Vector2(s * 0.09, s * 0.09), face - Vector2(s * 0.18, s * 0.18), r * 0.7), base.lightened(0.06))
	b.fan(Face.Builder.round_rect(face_at + Vector2(s * 0.16, s * 0.04), Vector2(s * 0.62, s * 0.045), s * 0.022), Color(1, 1, 1, 0.42))
	b.disc(face_at + Vector2(s * 0.84, s * 0.062), s * 0.022, Color(1, 1, 1, 0.35))
	# grain: two lines curling across the face
	for k in 2:
		var g := PackedVector2Array()
		var y0 := half - lip - s * (0.15 + 0.5 * k)
		for i in 9:
			var t := i / 8.0
			g.append(Vector2(lerpf(-half + s * (0.14 + 0.3 * k), half - s * (0.2 + 0.26 * (1 - k)), t), y0 + sin(t * PI * (1.6 + k * 0.7) + k) * s * 0.028))
		b.stroke(g, maxf(1.2, s * 0.016), Color(deep, 0.28 - 0.08 * k))
	# end grain: rings round the lower left corner
	var eg := face_at + Vector2(0, face.y)
	for k in 2:
		var rr := s * (0.11 + 0.08 * k)
		b.stroke(Face.Builder.arc_points(eg + Vector2(s * 0.03, -s * 0.03), rr, -PI * 0.42, -PI * 0.08), maxf(1.0, s * 0.012), Color(deep, 0.16))
	if v == 0:
		_rainbow(b, face_at, face, r, s)
	elif v < 0:
		_bomb_face(b, s)
	elif e >= 10:
		# gilt: a gold frame, brass studs, and a sparkle in the corner
		b.stroke(Face.Builder.round_rect(face_at + Vector2(s * 0.07, s * 0.07), face - Vector2(s * 0.14, s * 0.14), r * 0.7), maxf(2.0, s * 0.03), Color(GOLD.lightened(0.25) if e != 11 else Color("fffaf0"), 0.85), true)
		for q in 4:
			var at := face_at + Vector2(s * (0.1 if q % 2 == 0 else 0.9), face.y * (0.12 if q < 2 else 0.88))
			b.disc(at, s * 0.03, GOLD.darkened(0.2))
			b.disc(at - Vector2(s * 0.008, s * 0.008), s * 0.017, GOLD.lightened(0.4))
		_twinkle(b, Vector2(half - s * 0.2, -half + s * 0.2), s * 0.08, Color("fffaf0"))
	elif e >= 7:
		# a painted frame, lighter than the face
		b.stroke(Face.Builder.round_rect(face_at + Vector2(s * 0.08, s * 0.08), face - Vector2(s * 0.16, s * 0.16), r * 0.7), maxf(1.5, s * 0.022), Color(base.lightened(0.35), 0.8), true)
	var m := b.mesh()
	_cache[key] = m
	return m

## A four-point star, `r` across, for a twinkle drawn by the transform.
static func sparkle(r: float) -> ArrayMesh:
	var key := "s%d" % roundi(r)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, r * 0.5, Color(1, 1, 0.9, 0.25))
	_twinkle(b, Vector2.ZERO, r, Color("fffaf0"))
	_twinkle(b, Vector2.ZERO, r * 0.45, Color(1, 1, 1))
	var m := b.mesh()
	_cache[key] = m
	return m

## The rainbow block: four painted quarters under a white star.
static func _rainbow(b: Face.Builder, at: Vector2, size: Vector2, r: float, s: float) -> void:
	var cols := [PAINT[4], PAINT[2], PAINT[8], PAINT[6]]
	var inset := s * 0.1
	var inner := size - Vector2(inset, inset) * 2.0
	var o := at + Vector2(inset, inset)
	var half := inner * 0.5
	for q in 4:
		var qa := o + Vector2((q % 2) * half.x, (q / 2) * half.y)
		b.fan(Face.Builder.round_rect(qa + Vector2(1, 1), half - Vector2(2, 2), r * 0.35), cols[q])
	var c := at + size * 0.5
	_twinkle(b, c, s * 0.2, Color("fffaf0"))
	_twinkle(b, c, s * 0.1, Color(1, 1, 1, 1))

## The bomb crate: a round black bomb with a lit fuse on a dark block.
static func _bomb_face(b: Face.Builder, s: float) -> void:
	var c := Vector2(0, s * 0.02)
	b.disc(c, s * 0.26, Color("2f2934"))
	b.disc(c + Vector2(-s * 0.08, -s * 0.08), s * 0.08, Color(1, 1, 1, 0.22))
	b.fan(Face.Builder.round_rect(c + Vector2(-s * 0.07, -s * 0.33), Vector2(s * 0.14, s * 0.1), s * 0.02), BOMB_HI)
	var fuse := Face.Builder.bezier2(c + Vector2(0, -s * 0.32), c + Vector2(s * 0.08, -s * 0.44), c + Vector2(s * 0.18, -s * 0.38), 8)
	b.stroke(fuse, s * 0.035, FUSE)
	_twinkle(b, c + Vector2(s * 0.2, -s * 0.38), s * 0.09, SPARK)

static func _twinkle(b: Face.Builder, c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var rr := r if k % 2 == 0 else r * 0.32
		pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * k / 8.0) * rr)
	b.polygon(pts, col)

## The zap: a cyan bolt, `s` tall, centred.
static func zap(s: float) -> ArrayMesh:
	var key := "z%d" % roundi(s)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var k := s / 100.0
	var bolt := PackedVector2Array([Vector2(8, -50), Vector2(-26, 6), Vector2(-2, 6), Vector2(-12, 50), Vector2(28, -10), Vector2(4, -10), Vector2(18, -50)])
	var shade := PackedVector2Array()
	var fill := PackedVector2Array()
	for p in bolt:
		shade.append(p * k + Vector2(3, 4) * k)
		fill.append(p * k)
	b.polygon(shade, ZAP_DEEP)
	b.polygon(fill, ZAP)
	b.stroke(PackedVector2Array([Vector2(6, -44) * k, Vector2(-14, 0) * k]), 3.0 * k, Color(1, 1, 1, 0.6))
	var m := b.mesh()
	_cache[key] = m
	return m

## An acorn, `s` tall, centred.
static func acorn(s: float) -> ArrayMesh:
	var key := "a%d" % roundi(s)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var k := s / 100.0
	b.ellipse(Vector2(0, 12) * k, 30 * k, 36 * k, ACORN)
	b.ellipse(Vector2(-10, 8) * k, 8 * k, 16 * k, Color(1, 1, 1, 0.2))
	b.disc(Vector2(0, 46) * k, 5 * k, ACORN.darkened(0.2))
	b.ellipse(Vector2(0, -16) * k, 38 * k, 20 * k, ACORN_CAP)
	for j in 5:
		b.disc(Vector2(-24 + j * 12, -18 + (j % 2) * 4) * k, 5 * k, ACORN_CAP.lightened(0.15))
	b.stroke(PackedVector2Array([Vector2(0, -32) * k, Vector2(6, -46) * k]), 6 * k, ACORN_CAP)
	var m := b.mesh()
	_cache[key] = m
	return m

## The number on a block, lettered centred on `c` with a soft drop.
static func number(ci: CanvasItem, font: Font, c: Vector2, v: int, s: float, alpha := 1.0) -> void:
	var text := str(v)
	var fs := int(s * [0.5, 0.5, 0.46, 0.38, 0.31, 0.26][mini(text.length(), 5)])
	var col := number_colour(v)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-size.x * 0.5, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - s * 0.035)
	var drop := Color(0.2, 0.12, 0.05, 0.25 * alpha) if col == INK else Color(0.15, 0.08, 0.05, 0.4 * alpha)
	ci.draw_string(font, at + Vector2(0, s * 0.025), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, drop)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, alpha))

## The display face every number is lettered in.
static func font() -> Font:
	return CozyTheme.display(700)
