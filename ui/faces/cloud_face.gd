extends "res://ui/faces/face.gd"

## The cloud, one of Code Break's six friends: three puffs over a flat-
## bottomed capsule in CLOUD, one pale highlight, and the face across the
## middle. Still, like the berry.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#codebreak, cloudP).
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.40

func _kind() -> String:
	return "cloud"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.62 * 0.15 * R), 1.05 * R, 0.62 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			# Four overlapping fills in one colour: where they meet, a
			# feather at alpha 0 to CLOUD over CLOUD is still CLOUD, so the
			# puffs join without a seam.
			b.disc(Vector2(-0.56, 0.1) * R, 0.48 * R, Pal.CLOUD)
			b.disc(Vector2(0.56, 0.1) * R, 0.42 * R, Pal.CLOUD)
			b.disc(Vector2(0.0, -0.3) * R, 0.6 * R, Pal.CLOUD)
			b.fan(Builder.round_rect(Vector2(-1.0, 0.0) * R, Vector2(2.0, 0.58) * R, 0.29 * R), Pal.CLOUD)
			b.disc(Vector2(-0.22, -0.46) * R, 0.2 * R, Color(1.0, 1.0, 1.0, 0.4))
			_face_parts(b, 0.8 * R, Vector2(0.0, 0.02 * R), Pal.TEXT, eye)
