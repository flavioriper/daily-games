extends "res://ui/faces/face.gd"

## The pear, one of Balance's five camp fruit: a waisted body in PEAR under a
## short bark stalk with one leaf, a soft highlight low on its left, and the
## face sitting low where the body is widest. Still, like the berry.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#balance, pearP).
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.37

func _kind() -> String:
	return "pear"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.85 * 0.15 * R), 0.95 * R, 0.85 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			b.stroke(PackedVector2Array([Vector2(0.0, -1.0) * R, Vector2(0.06, -1.26) * R]), 0.1 * R, Pal.BARK)
			_sprig(b, Vector2(0.06, -1.24) * R, 0.44 * R, -2.4)
			# Four curves round the waist and back to the stalk. Each drops
			# its end point, so the outline closes on the first without a
			# doubled vertex; the body is concave at the waist, so it is a
			# polygon and not a fan.
			var body := PackedVector2Array()
			body.append_array(Builder.bezier3(Vector2(0.0, -1.02) * R, Vector2(0.42, -0.92) * R,
				Vector2(0.36, -0.2) * R, Vector2(0.7, 0.24) * R))
			body.append_array(Builder.bezier3(Vector2(0.7, 0.24) * R, Vector2(0.98, 0.72) * R,
				Vector2(0.46, 1.1) * R, Vector2(0.0, 1.1) * R))
			body.append_array(Builder.bezier3(Vector2(0.0, 1.1) * R, Vector2(-0.46, 1.1) * R,
				Vector2(-0.98, 0.72) * R, Vector2(-0.7, 0.24) * R))
			body.append_array(Builder.bezier3(Vector2(-0.7, 0.24) * R, Vector2(-0.36, -0.2) * R,
				Vector2(-0.42, -0.92) * R, Vector2(0.0, -1.02) * R))
			b.polygon(body, Pal.PEAR)
			b.ellipse(Vector2(-0.3, 0.34) * R, 0.16 * R, 0.26 * R, Color(1.0, 1.0, 1.0, 0.22))
			_face_parts(b, 0.82 * R, Vector2(0.0, 0.3 * R), Pal.TEXT, eye)

## One small leaf of `length` from `base` along `angle`: two quadratic curves
## out and back, the mock's leaf() helper.
func _sprig(b: Builder, base: Vector2, length: float, angle: float) -> void:
	var xf := Transform2D(angle, base)
	var pts: PackedVector2Array = Builder.bezier2(Vector2.ZERO, Vector2(0.55, -0.42) * length, Vector2(1.0, 0.0) * length)
	pts.append_array(Builder.bezier2(Vector2(1.0, 0.0) * length, Vector2(0.55, 0.42) * length, Vector2.ZERO))
	b.polygon(xf * pts, Pal.LEAF)
