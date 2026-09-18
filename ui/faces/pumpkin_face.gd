extends "res://ui/faces/face.gd"

## The pumpkin, one of Balance's five camp fruit: a wide squat belly in
## PUMPKIN under a stubby PUMPKIN_STEM stalk, two ribs curving down its
## front, a highlight over the upper left, and the face across the middle.
## It is the widest of the five, which is why its shadow reaches furthest.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#balance, pumpkinP).
## Spec: docs/superpowers/specs/2026-09-18-balance-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.37

func _kind() -> String:
	return "pumpkin"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.92 * 0.15 * R), 1.25 * R, 0.92 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			b.fan(Builder.round_rect(Vector2(-0.1, -1.06) * R, Vector2(0.2, 0.36) * R, 0.09 * R), Pal.PUMPKIN_STEM)
			b.ellipse(Vector2.ZERO, 1.12 * R, 0.9 * R, Pal.PUMPKIN)
			# The two ribs: quadratic curves bowing outward, so the belly
			# reads as ribbed rather than as a plain ellipse.
			for dx: float in [-0.52, 0.52]:
				var rib: PackedVector2Array = Builder.bezier2(Vector2(dx, -0.78) * R,
					Vector2(dx * 1.34, 0.0) * R, Vector2(dx, 0.78) * R)
				rib.append(Vector2(dx, 0.78) * R)
				b.stroke(rib, 0.07 * R, Color(Pal.PUMPKIN_DEEP, 0.5))
			b.ellipse(Vector2(-0.55, -0.34) * R, 0.2 * R, 0.13 * R, Color(1.0, 1.0, 1.0, 0.2))
			_face_parts(b, 0.88 * R, Vector2(0.0, 0.04 * R), Pal.TEXT, eye)
