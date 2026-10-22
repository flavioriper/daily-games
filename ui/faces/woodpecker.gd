extends RefCounted

## Birdsong's woodpecker (puzzles/birdsong2d.gd, its tutorial and its menu
## card): slate back with white bars on the wing, a cream front, a red cap
## at the back of the crown and a long grey beak. It clings upright to a
## trunk on its left, its feet on the origin (the bark's edge), so a board
## lays it with the origin on the trunk's right side; a transform with a
## negative x scale turns it onto a trunk on its right.
##
## Two meshes, so a peck is a transform and not a new drawing: `body`
## (tail, body, wing, feet, the origin at the feet) and `head` (the origin
## at the head's middle), laid at `head_at` and moved toward the bark by
## `STRIKE` for a peck. Both cached per size, as songbird.gd's are.
##
## `r` is the body's half height; everything is a share of it.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

enum Mood { REST, BLINK, JOY, PUZZLED }

const BACK := Color("3d4256")
const BACK_HI := Color("565c74")
const BACK_DEEP := Color("2f3344")
const FRONT := Color("f4ead6")
const FRONT_DEEP := Color("e6d7b9")
const BAR := Color("f6f1e6")
const CAP := Color("e0503c")
const BEAK := Color("5f584e")
const BEAK_HI := Color("8f8676")
const INK := Color("2a2420")
const FOOT := Color("6c6457")

## The head's middle at rest, from the feet; how far a peck carries it
## toward the bark (left) and down; the beak's length past the head.
const HEAD := Vector2(1.36, -1.87)
const STRIKE := Vector2(-0.32, 0.06)
const HEAD_R := 0.49

static var _cache := {}

static func head_at(r: float) -> Vector2:
	return HEAD * r

## Where the head goes at the bottom of a peck, from its rest.
static func strike(r: float) -> Vector2:
	return STRIKE * r

## The beak's tip, from the head's middle.
static func beak_tip(r: float) -> Vector2:
	return Vector2(-1.02, 0.04) * r

static func body(r: float) -> ArrayMesh:
	var key := "body:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	# the tail, stiff and pressed to the bark
	b.polygon(PackedVector2Array([Vector2(0.15, -0.21) * r, Vector2(-0.04, 1.26) * r, Vector2(0.15, 1.17) * r,
		Vector2(0.28, 1.32) * r, Vector2(0.49, -0.06) * r]), BACK_DEEP)
	# the body: back slate, the front cream toward the trunk
	var c := Vector2(0.74, -0.83) * r
	b.polygon(_oval(c + Vector2(0.03, 0.03) * r, 0.6 * r, 1.02 * r, 0.16), BACK_DEEP)
	b.polygon(_oval(c, 0.57 * r, 1.0 * r, 0.16), BACK)
	b.polygon(_oval(c + Vector2(-0.22, 0.08).rotated(0.16) * r, 0.33 * r, 0.8 * r, 0.21), FRONT_DEEP)
	b.polygon(_oval(c + Vector2(-0.24, 0.06).rotated(0.16) * r, 0.3 * r, 0.77 * r, 0.21), FRONT)
	# the wing, white bars on slate
	var wc := c + Vector2(0.23, 0.08).rotated(0.16) * r
	b.polygon(_oval(wc, 0.32 * r, 0.74 * r, 0.26), BACK_HI)
	for i in 4:
		b.polygon(_oval(wc + Vector2(0.05, -0.36 + i * 0.27).rotated(0.16) * r, 0.15 * r, 0.055 * r, 0.36), BAR)
	# the feet, gripping the bark
	for fy: float in [-0.47, -0.15]:
		b.stroke(PackedVector2Array([Vector2(0.3, fy) * r, Vector2(0.02, fy + 0.04) * r]), 0.065 * r, FOOT)
		b.stroke(PackedVector2Array([Vector2(0.11, fy + 0.02) * r, Vector2(-0.02, fy + 0.15) * r]), 0.06 * r, FOOT)
	var m := b.mesh()
	_cache[key] = m
	return m

static func head(r: float, mood := Mood.REST) -> ArrayMesh:
	var key := "head:%d:%d" % [roundi(r * 2.0), mood]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var hr := HEAD_R * r
	b.disc(Vector2(0.02, 0.03) * r, hr * 1.04, BACK_DEEP)
	b.disc(Vector2.ZERO, hr, BACK)
	# the cream face toward the bark, the red cap at the back of the crown
	b.polygon(_oval(Vector2(-0.13, 0.15) * r, 0.34 * r, 0.28 * r, 0.0), FRONT)
	b.polygon(_oval(Vector2(0.15, -0.32) * r, 0.32 * r, 0.21 * r, 0.5), CAP)
	# the beak, long and straight
	b.polygon(PackedVector2Array([Vector2(-0.36, -0.1) * r, Vector2(-1.02, 0.04) * r, Vector2(-0.36, 0.16) * r]), BEAK)
	b.polygon(PackedVector2Array([Vector2(-0.36, -0.1) * r, Vector2(-1.02, 0.04) * r, Vector2(-0.36, 0.03) * r]), BEAK_HI)
	# the cheek and the eye
	var eye := Vector2(-0.09, -0.04) * r
	b.ellipse(eye + Vector2(0.07, 0.24) * r, 0.11 * r, 0.065 * r, Color(Pal.CHEEK, 0.85))
	match mood:
		Mood.BLINK:
			b.stroke(Face.Builder.arc_points(eye + Vector2(0.0, -0.05) * r, 0.09 * r, PI * 0.15, PI * 0.85), 0.05 * r, INK)
		Mood.JOY:
			b.stroke(Face.Builder.arc_points(eye + Vector2(0.0, 0.05) * r, 0.09 * r, PI * 1.1, PI * 1.9), 0.055 * r, INK)
		_:
			b.disc(eye, 0.088 * r, INK)
			b.disc(eye + Vector2(0.03, -0.035) * r, 0.03 * r, Color(1, 1, 1, 0.9))
			if mood == Mood.PUZZLED:
				b.stroke(PackedVector2Array([eye + Vector2(-0.13, -0.2) * r, eye + Vector2(0.12, -0.25) * r]), 0.05 * r, INK)
	var m := b.mesh()
	_cache[key] = m
	return m

## An ellipse's outline about `c`, turned by `turn`.
static func _oval(c: Vector2, rx: float, ry: float, turn: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var t := float(i) / 28.0 * TAU
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(turn))
	return pts
