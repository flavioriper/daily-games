extends "res://ui/faces/face.gd"

## The moon: a crescent in MOON_INK open to the upper right, a MOON_DEEP
## shade along its lower edge and the shadow under both, with the face on
## the lower-left body. `rock` tilts the whole drawing about the centre, and
## a moon with `rocks` set does so on its own at idle. R is the outer circle
## and fills the rect.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4
## and the amendments.
##
## Each layer is one closed polygon from horn to horn -- the outer arc the
## long way round, the bite's arc back -- never a clip: a clipped fill leaves
## its antialiased edge faintly across the bite. The bite stays where it is
## for every layer, so the shade and the shadow show only along the outer
## rim, and the two lower layers are bitten a touch deeper so their edges sit
## under the body's opaque fill.

## The bite's radius, and how far its centre sits toward the upper right, in R.
const BITE_R := 0.78
const BITE_OFF := 0.62
## How much deeper the shade and the shadow are bitten, in R.
const UNDERBITE := 0.04
## The idle tilt, plus and minus, and its period.
const ROCK_ANGLE := 3.0 * PI / 180.0
const ROCK_PERIOD := 4.0

func radius() -> float:
	return minf(size.x, size.y) * 0.5

func _idle_motion() -> Tween:
	if not rocks:
		return null
	# Each moon its own phase, so a board sways rather than nodding in step.
	var phase := randf() * TAU
	var tw := create_tween().set_loops()
	tw.tween_method(func(t: float) -> void: rock = ROCK_ANGLE * sin(TAU * t + phase),
		0.0, 1.0, ROCK_PERIOD)
	return tw

func _draw() -> void:
	_begin(rock)
	var R := radius()
	_crescent(R, Vector2(0.04, 0.16) * R, Color(Pal.TEXT, SHADOW_ALPHA), UNDERBITE * R)
	_crescent(R, Vector2(0.0, 0.07) * R, Pal.MOON_DEEP, UNDERBITE * R)
	_crescent(R, Vector2.ZERO, Pal.MOON_INK, 0.0)
	_face_parts(0.62 * R, Vector2(-0.34, 0.3) * R, Pal.TEXT)

## One layer: the circle of R about `at`, less the bite (its radius widened
## by `extra`), as a single closed polygon.
func _crescent(R: float, at: Vector2, colour: Color, extra: float) -> void:
	var bite := Vector2(BITE_OFF * 0.707, -BITE_OFF * 0.707) * R
	var r2 := BITE_R * R + extra
	var v := bite - at
	var d := v.length()
	var ang := v.angle()
	# The circles meet at ang +- a seen from the body's centre and at
	# ang + PI -+ b seen from the bite's (the law of cosines in each).
	var a := acos((d * d + R * R - r2 * r2) / (2.0 * d * R))
	var b := acos((d * d + r2 * r2 - R * R) / (2.0 * d * r2))
	var outer := _arc_points(at, R, ang + a, ang - a + TAU)
	var back := _arc_points(bite, r2, ang + PI + b, ang + PI - b)
	# Each arc ends where the other begins; the shared points go in once.
	var pts := outer.slice(0, outer.size() - 1)
	pts.append_array(back.slice(0, back.size() - 1))
	_fill(pts, colour)
