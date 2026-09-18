extends "res://ui/faces/face.gd"

## The leaf, one of Code Break's six friends: a pointed blade in LEAF with a
## lighter midrib and two side veins, and the face on the blade. `rock` tilts
## it, a little less than the moon does, so a row of friends does not all
## sway by the same amount.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#codebreak, leafP).
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`; the owner may override it.
const RATIO := 0.40
## How much of `rock` the blade takes.
const ROCK_SHARE := 0.6
## The idle tilt, plus and minus, and its period -- the mock's every-piece sway.
const ROCK_ANGLE := 0.05
const ROCK_PERIOD := 4.0

func _kind() -> String:
	return "leaf"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

## The shadow is laid before the tilt, as the mock has it, so only the blade
## leans.
func _layer_angle(name: String) -> float:
	return rock * ROCK_SHARE if name == "body" else 0.0

func _idle_motion() -> Tween:
	var phase := randf() * TAU
	var tw := create_tween().set_loops()
	tw.tween_method(func(t: float) -> void: rock = ROCK_ANGLE * sin(TAU * t + phase),
		0.0, 1.0, ROCK_PERIOD)
	return tw

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.85 * 0.15 * R), 0.95 * R, 0.85 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			var pts := Builder.bezier3(Vector2(0.0, -1.12) * R, Vector2(0.92, -0.58) * R,
				Vector2(0.84, 0.62) * R, Vector2(0.0, 1.04) * R)
			pts.append_array(Builder.bezier3(Vector2(0.0, 1.04) * R, Vector2(-0.84, 0.62) * R,
				Vector2(-0.92, -0.58) * R, Vector2(0.0, -1.12) * R))
			b.polygon(pts, Pal.LEAF)
			# The veins always sit on the blade, so their alpha is baked into
			# one colour rather than laid over it: a feathered translucent
			# stroke would show its own band.
			var rib: PackedVector2Array = Builder.bezier2(Vector2(0.0, 0.92) * R, Vector2(0.05, 0.0) * R, Vector2(0.0, -1.0) * R)
			rib.append(Vector2(0.0, -1.0) * R)
			b.stroke(rib, 0.1 * R, Pal.LEAF.lerp(Pal.LEAF_LIGHT, 0.95))
			for sx: float in [-1.0, 1.0]:
				var side: PackedVector2Array = Builder.bezier2(Vector2(0.0, 0.34) * R,
					Vector2(sx * 0.3, 0.24) * R, Vector2(sx * 0.5, 0.4) * R)
				side.append(Vector2(sx * 0.5, 0.4) * R)
				b.stroke(side, 0.06 * R, Pal.LEAF.lerp(Pal.LEAF_LIGHT, 0.7))
			_face_parts(b, 0.76 * R, Vector2(0.0, -0.04 * R), Pal.TEXT, eye)
