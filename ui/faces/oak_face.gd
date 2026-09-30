extends "res://ui/faces/conifer_face.gd"

## Tents' old oak (Insane): a broad round crown of four lobes over a short
## thick trunk, lit on its left and shaded on its right, with two acorns
## hanging under the crown -- one for each of the two tents an oak takes. It
## sways like the conifer it extends, with the conifer's face on its crown.
## Spec: docs/superpowers/specs/2026-09-30-tents-polish-design.md, section 2.

const OAK_FACE_R := 0.2
const OAK_FACE_AT := Vector2(0.0, -0.04)
## The lobes of the crown: centre and radius, in R.
const LOBES := [
	[Vector2(-0.22, -0.08), 0.24], [Vector2(0.22, -0.08), 0.24],
	[Vector2(0.0, -0.26), 0.27], [Vector2(0.0, 0.04), 0.26],
]
const ACORNS := [Vector2(-0.27, 0.22), Vector2(0.29, 0.2)]

func _kind() -> String:
	return "oak"

func _face_frame(R: float) -> Array:
	return [OAK_FACE_AT * R, OAK_FACE_R * R]

func _hat_place(R: float) -> Array:
	return [Vector2(0.06, -0.5) * R, 0.15, 0.3 * R]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.46) * R, 0.4 * R, 0.1 * R, Color(Pal.TEXT, 0.1))
		"body":
			# The trunk, flared at its foot, its right side in shade.
			b.polygon(PackedVector2Array([Vector2(-0.08, 0.1) * R, Vector2(0.08, 0.1) * R,
				Vector2(0.13, 0.46) * R, Vector2(-0.13, 0.46) * R]), Pal.BARK)
			b.polygon(PackedVector2Array([Vector2(0.01, 0.1) * R, Vector2(0.08, 0.1) * R,
				Vector2(0.13, 0.46) * R, Vector2(0.03, 0.46) * R]), Pal.BARK.darkened(BARK_SHADE))
			# The crown: the shade first, then its lit left side over it.
			var deep := Pal.LEAF_DEEP.lerp(Pal.LEAF, TIER_SHADE)
			for lobe in LOBES:
				b.disc(lobe[0] * R, lobe[1] * R, deep)
			for lobe in LOBES:
				var c: Vector2 = lobe[0] * R
				var r: float = lobe[1] * R
				b.disc(c + Vector2(-0.05, -0.03) * R, r * 0.86, Pal.LEAF)
			b.disc(Vector2(-0.2, -0.3) * R, 0.1 * R, Pal.LEAF_LIGHT)
			b.disc(Vector2(-0.32, -0.1) * R, 0.07 * R, Pal.LEAF_LIGHT)
			# Two acorns under the crown: an oak takes two tents.
			for a: Vector2 in ACORNS:
				var p := a * R
				b.ellipse(p + Vector2(0.0, 0.06) * R, 0.075 * R, 0.095 * R, Pal.ACORN)
				b.ellipse(p + Vector2(-0.02, 0.04) * R, 0.025 * R, 0.04 * R, Color(1.0, 1.0, 1.0, 0.35))
				b.ellipse(p + Vector2(0.0, -0.02) * R, 0.09 * R, 0.05 * R, Pal.ACORN_DEEP)
				b.stroke(PackedVector2Array([p + Vector2(0.0, -0.06) * R, p + Vector2(0.015, -0.11) * R]),
					0.025 * R, Pal.BARK)
			_face_parts(b, OAK_FACE_R * R, OAK_FACE_AT * R, Pal.TEXT, eye)
