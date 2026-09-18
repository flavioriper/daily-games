extends "res://ui/faces/face.gd"

## The flower, the seventh friend, which joins on the hard difficulty: six
## petals in FLOWER about a pale centre carrying the face. `spin` turns the
## petals, at about a third of the rate the sun's rays take, and the centre
## and the face stay put.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#codebreak, flowerP).
## Spec: docs/superpowers/specs/2026-09-18-codebreak-flat-design.md, section 3.

## R as a fraction of the seat, the mock's `r`.
const RATIO := 0.33
## How much of `spin` the petals take.
const SPIN_SHARE := 0.35
## One revolution of `spin` at idle, in seconds; the sun's rate.
const SPIN_PERIOD := 40.0

func _kind() -> String:
	return "flower"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["petals", false], ["body", true]]

func _layer_angle(name: String) -> float:
	return spin * SPIN_SHARE if name == "petals" else 0.0

func _idle_motion() -> Tween:
	var from := spin
	var tw := create_tween().set_loops()
	tw.tween_property(self, "spin", from + TAU, SPIN_PERIOD).from(from)
	return tw

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 1.0 * 0.15 * R), 1.2 * R, 1.0 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"petals":
			for i in 6:
				var xf := Transform2D(i * PI / 3.0, Vector2.ZERO)
				b.fan(xf * Builder.ring(Vector2(0.0, -0.86 * R), 0.36 * R, 0.5 * R), Pal.FLOWER)
		"body":
			b.disc(Vector2.ZERO, 0.78 * R, Pal.FLOWER_EYE)
			_face_parts(b, 0.72 * R, Vector2(0.0, 0.02 * R), Pal.TEXT, eye)
