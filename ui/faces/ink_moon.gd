extends "res://ui/faces/moon_face.gd"

## The ink skin's moon (ui/flat/ink.gd): the same crescent in charcoal, flat,
## with two small dot eyes low on its body -- the mock's quiet face. JOY
## closes them to arches; nothing else changes it.

const Ink = preload("res://ui/flat/ink.gd")

const EYE_INK := Color("9d968d")

## A paper rim round the crescent, where it overlaps another ink shape (the
## win's pair).
var rim := false

func _kind() -> String:
	return "ink_moon_rim" if rim else "ink_moon"

func _layers() -> Array:
	return [["body", true]]

func _build_layer(_name: String, R: float, eye: float, b: Builder) -> void:
	if rim:
		# The crescent grown by a band of paper on every side, under it.
		var band := 0.12 * R
		var outer := Builder.arc_points(Vector2.ZERO, R + band, 0.0, TAU)
		var bite_at := Vector2(BITE_OFF * 0.707, -BITE_OFF * 0.707) * R
		var bite := Builder.arc_points(bite_at, BITE_R * R - band, 0.0, TAU)
		for piece in Geometry2D.clip_polygons(outer.slice(0, outer.size() - 1), bite.slice(0, bite.size() - 1)):
			b.polygon(piece, Ink.PAGE)
	_crescent(b, R, Vector2.ZERO, Ink.INK, 0.0)
	if plain:
		return
	for dx: float in [-0.46, -0.22]:
		var at := Vector2(dx, 0.46) * R
		if expression == Expr.JOY:
			b.stroke(Builder.arc_points(at + Vector2(0.0, 0.03 * R), 0.06 * R, PI * 1.1, PI * 1.9), 0.035 * R, EYE_INK)
		else:
			b.ellipse(at, 0.055 * R, maxf(0.012 * R, 0.055 * R * eye), EYE_INK)
