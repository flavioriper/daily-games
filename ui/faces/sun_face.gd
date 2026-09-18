extends "res://ui/faces/face.gd"

## The sun: a disc in SUN with eight rounded rays in SUN_RAY, a highlight arc
## over the upper left and the face on the disc. `spin` turns the rays, and
## at idle they make one revolution in SPIN_PERIOD. R is sized so the rays
## reach the rect's edge.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4.

## How far the rays reach, in R; radius() divides the rect by it.
const REACH := 1.55
## One revolution of the rays at idle, in seconds.
const SPIN_PERIOD := 40.0

func radius() -> float:
	return minf(size.x, size.y) * 0.5 / REACH

func _idle_motion() -> Tween:
	var from := spin
	var tw := create_tween().set_loops()
	# A full turn lands on the same picture, so the loop's seam is invisible.
	tw.tween_property(self, "spin", from + TAU, SPIN_PERIOD).from(from)
	return tw

func _draw() -> void:
	_begin()
	var R := radius()
	_ellipse(Vector2(0.0, 1.3 * 0.15 * R), 1.35 * R, 1.3 * R, Color(Pal.TEXT, SHADOW_ALPHA))
	# Eight capsules 0.26 R wide from 1.05 R to 1.55 R out: a line of that
	# width between the two cap centres, and the caps.
	for i in 8:
		var dir := Vector2.from_angle(spin - PI * 0.5 + i * PI * 0.25)
		_line(dir * (1.05 + 0.13) * R, dir * (1.55 - 0.13) * R, Pal.SUN_RAY, 0.26 * R)
	_disc(Vector2.ZERO, R, Pal.SUN)
	# The highlight is the ring between 0.62 R and 0.86 R over the upper
	# left: an arc at the mean radius stroked to the difference, whose flat
	# ends are the same radial cuts the mock's two arcs make.
	draw_arc(Vector2.ZERO, 0.74 * R, PI * 1.02, PI * 1.6, _arc_n(0.74 * R, PI * 0.58) + 1,
		Color(1.0, 1.0, 1.0, 0.22), 0.24 * R, true)
	_face_parts(R, Vector2(0.0, 0.02 * R), Pal.TEXT)
