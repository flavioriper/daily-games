extends "res://ui/faces/face.gd"

## The berry, one of Code Break's six friends: a round fruit in BERRY under a
## bent bark stem with one small leaf, a highlight over the upper left, and
## the face on the fruit. It has no motion of its own; it is the still one in
## the row.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#codebreak, berryP).
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.34

func _kind() -> String:
	return "berry"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.98 * 0.15 * R), 1.1 * R, 0.98 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			var stem: PackedVector2Array = Builder.bezier2(Vector2(0.0, -0.86) * R,
				Vector2(0.1, -1.1) * R, Vector2(0.04, -1.3) * R)
			stem.append(Vector2(0.04, -1.3) * R)
			b.stroke(stem, 0.11 * R, Pal.BARK)
			_sprig(b, Vector2(0.04, -1.26) * R, 0.52 * R, -2.5)
			b.disc(Vector2.ZERO, R, Pal.BERRY)
			# The highlight is the ring between 0.58 R and 0.84 R over the
			# upper left: an arc at the mean radius, stroked to the
			# difference with flat ends, as the sun's is.
			b.stroke(Builder.arc_points(Vector2.ZERO, 0.71 * R, PI * 1.05, PI * 1.55),
				0.26 * R, Color(1.0, 1.0, 1.0, 0.24), false, false)
			_face_parts(b, 0.92 * R, Vector2(0.0, 0.04 * R), Pal.TEXT, eye)

## One small leaf of `length` from `base` along `angle`: two quadratic curves
## out and back, the mock's leaf() helper.
func _sprig(b: Builder, base: Vector2, length: float, angle: float) -> void:
	var xf := Transform2D(angle, base)
	var pts: PackedVector2Array = Builder.bezier2(Vector2.ZERO, Vector2(0.55, -0.42) * length, Vector2(1.0, 0.0) * length)
	pts.append_array(Builder.bezier2(Vector2(1.0, 0.0) * length, Vector2(0.55, 0.42) * length, Vector2.ZERO))
	b.polygon(xf * pts, Pal.LEAF)
