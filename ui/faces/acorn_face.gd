extends "res://ui/faces/face.gd"

## The acorn, one of Code Break's six friends: a nut in ACORN under a flat
## cap in ACORN_DEEP with a short stalk, and the face low on the nut. Still,
## like the berry and the cloud.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#codebreak, acornP).
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.40

func _kind() -> String:
	return "acorn"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.85 * 0.15 * R), 1.0 * R, 0.85 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			var nut := PackedVector2Array([Vector2(-0.76, -0.26) * R])
			nut.append_array(Builder.bezier3(Vector2(0.76, -0.26) * R, Vector2(0.76, 0.74) * R,
				Vector2(0.42, 1.06) * R, Vector2(0.0, 1.06) * R))
			nut.append_array(Builder.bezier3(Vector2(0.0, 1.06) * R, Vector2(-0.42, 1.06) * R,
				Vector2(-0.76, 0.74) * R, Vector2(-0.76, -0.26) * R))
			b.polygon(nut, Pal.ACORN)
			b.stroke(PackedVector2Array([Vector2(0.0, -0.7) * R, Vector2(0.0, -1.04) * R]), 0.13 * R, Pal.ACORN_DEEP)
			b.fan(Builder.round_rect(Vector2(-0.9, -0.72) * R, Vector2(1.8, 0.5) * R, 0.25 * R), Pal.ACORN_DEEP)
			_face_parts(b, 0.7 * R, Vector2(0.0, 0.32 * R), Pal.TEXT, eye)
