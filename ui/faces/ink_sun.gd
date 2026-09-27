extends "res://ui/faces/sun_face.gd"

## The ink skin's sun (ui/flat/ink.gd): a plain charcoal disc with eight
## short rays standing clear of it, no face -- the mock's stamp. The rays
## still turn at idle, on the sun's own clock.

const Ink = preload("res://ui/flat/ink.gd")

## How far the rays reach, in R.
const INK_REACH := 2.0

func _kind() -> String:
	return "ink_sun"

func _radius_for(px: float) -> float:
	return px * 0.5 / INK_REACH

func _layers() -> Array:
	return [["rays", false], ["body", false]]

func _build_layer(name: String, R: float, _eye: float, b: Builder) -> void:
	match name:
		"rays":
			for i in 8:
				var dir := Vector2.from_angle(-PI * 0.5 + i * PI * 0.25)
				b.stroke(PackedVector2Array([dir * 1.42 * R, dir * 1.88 * R]), 0.17 * R, Ink.INK)
		"body":
			b.disc(Vector2.ZERO, R, Ink.INK)
