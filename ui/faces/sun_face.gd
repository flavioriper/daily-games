extends "res://ui/faces/face.gd"

## The sun: a disc in SUN with eight rounded rays in SUN_RAY, a highlight arc
## over the upper left and the face on the disc. `spin` turns the rays, and
## at idle they make one revolution in SPIN_PERIOD. R is sized so the rays
## reach the rect's edge.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4.
##
## Three layers, because the rays turn between the other two: the shadow
## and the body are shared by every sun of a size, the rays too, and only
## the body carries the expression.

## How far the rays reach, in R; radius() divides the rect by it.
const REACH := 1.55
## One revolution of the rays at idle, in seconds.
const SPIN_PERIOD := 40.0

func _kind() -> String:
	return "sun"

func _radius_for(px: float) -> float:
	return px * 0.5 / REACH

func _layers() -> Array:
	return [["shadow", false], ["rays", false], ["body", true]]

func _layer_angle(name: String) -> float:
	return spin if name == "rays" else 0.0

func _idle_motion() -> Tween:
	var from := spin
	var tw := create_tween().set_loops()
	# A full turn lands on the same picture, so the loop's seam is invisible.
	tw.tween_property(self, "spin", from + TAU, SPIN_PERIOD).from(from)
	return tw

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 1.3 * 0.15 * R), 1.35 * R, 1.3 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"rays":
			# Eight capsules 0.26 R wide from 1.05 R to 1.55 R out: a stroke
			# of that width between the two cap centres, with its round caps.
			for i in 8:
				var dir := Vector2.from_angle(-PI * 0.5 + i * PI * 0.25)
				b.stroke(PackedVector2Array([dir * (1.05 + 0.13) * R, dir * (1.55 - 0.13) * R]), 0.26 * R, Pal.SUN_RAY)
		"body":
			b.disc(Vector2.ZERO, R, Pal.SUN)
			# The highlight is the ring between 0.62 R and 0.86 R over the
			# upper left: an arc at the mean radius stroked to the difference,
			# with flat ends, the radial cuts the mock's two arcs make.
			b.stroke(Builder.arc_points(Vector2.ZERO, 0.74 * R, PI * 1.02, PI * 1.6), 0.24 * R, Color(1.0, 1.0, 1.0, 0.22), false, false)
			_face_parts(b, R, Vector2(0.0, 0.02 * R), Pal.TEXT, eye)
