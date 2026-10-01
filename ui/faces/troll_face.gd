extends "res://ui/faces/face.gd"

## Trestle's bridge troll: a small, friendly, mossy one who lives under the
## near bank by the water and watches the builder work. A round sage head
## with a tuft of moss and a daisy on top, little round ears, a big round
## nose, freckles and two blunt baby tusks over his smile, on mossy brown
## shoulders. He is code like every other character here; the board raises
## him out of the reeds, hides him from a snap and has him hold up a score
## card after a crossing.
## Spec: docs/superpowers/specs/2026-10-01-trestle-polish-design.md, section 3.

const SKIN := Color("9fbf8a")
const SKIN_DEEP := Color("7fa06c")
const SKIN_HI := Color("bcd6a6")
const NOSE := Color("d79a7c")
const NOSE_DEEP := Color("b8775c")
const MOSS := Color("6f9a48")
const MOSS_HI := Color("8cb85c")
const COAT := Color("8a6a4a")
const COAT_DEEP := Color("6e5238")
const TUSK := Color("fbf3dc")
const DAISY := Color("fffaf0")
const RATIO := 0.4

func _kind() -> String:
	return "troll"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _face_frame(R: float) -> Array:
	return [Vector2(0.0, -0.05 * R), 0.8 * R]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 1.0 * R), 1.05 * R, 0.2 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			# the shoulders, a mossy coat with a collar of moss
			b.ellipse(Vector2(0.0, 0.98 * R), 1.0 * R, 0.6 * R, COAT_DEEP)
			b.ellipse(Vector2(0.0, 0.92 * R), 0.94 * R, 0.55 * R, COAT)
			for k in 5:
				b.disc(Vector2((k - 2) * 0.3 * R, 0.56 * R + absf(k - 2) * 0.04 * R), 0.17 * R, MOSS if k % 2 else MOSS_HI)
			# round ears, set low
			for sx in [-1.0, 1.0]:
				b.ellipse(Vector2(sx * 0.98, 0.0) * R, 0.24 * R, 0.3 * R, SKIN_DEEP)
				b.ellipse(Vector2(sx * 0.98, 0.0) * R, 0.13 * R, 0.18 * R, NOSE_DEEP)
			b.ellipse(Vector2.ZERO, 1.0 * R, 0.92 * R, SKIN_DEEP)
			b.ellipse(Vector2(0.0, -0.03 * R), 0.95 * R, 0.86 * R, SKIN)
			b.ellipse(Vector2(-0.35, -0.42) * R, 0.26 * R, 0.14 * R, Color(SKIN_HI, 0.8))
			# the tuft of moss on top, and a daisy in it
			for k in 4:
				b.disc(Vector2((k - 1.5) * 0.22, -0.84 + absf(k - 1.5) * 0.06) * R, 0.2 * R, MOSS if k % 2 == 0 else MOSS_HI)
			var flower := Vector2(0.3, -0.98) * R
			for p in 5:
				b.disc(flower + Vector2.from_angle(TAU * p / 5.0) * 0.09 * R, 0.07 * R, DAISY)
			b.disc(flower, 0.06 * R, Pal.SUN)
			# freckles
			for sx in [-1.0, 1.0]:
				for k in 3:
					b.disc(Vector2(sx * (0.48 + 0.08 * k), 0.14 + 0.06 * (k % 2)) * R, 0.03 * R, Color(NOSE_DEEP, 0.55))
			_face_parts(b, 0.8 * R, Vector2(0.0, -0.05 * R), Pal.TEXT, eye)
			# two blunt baby tusks either side of the smile
			for sx in [-1.0, 1.0]:
				b.polygon(PackedVector2Array([Vector2(sx * 0.3, 0.42) * R, Vector2(sx * 0.18, 0.42) * R,
					Vector2(sx * 0.25, 0.28) * R]), TUSK)
			# the big round nose over it all
			b.ellipse(Vector2(0.0, 0.16 * R), 0.24 * R, 0.19 * R, NOSE_DEEP)
			b.ellipse(Vector2(0.0, 0.13 * R), 0.22 * R, 0.17 * R, NOSE)
			b.ellipse(Vector2(-0.07, 0.07) * R, 0.07 * R, 0.04 * R, Color(1, 1, 1, 0.45))
