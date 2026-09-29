extends "res://ui/faces/face.gd"

## The kitten, Untangle's Insane rival: a ginger tabby's head and shoulders,
## two pricked ears, three stripes on the brow, a pale muzzle and whiskers,
## sitting on the cloth beside the ring. She is code like every other
## character here; the board turns her toward the peg she means to bat and
## stretches her for a pounce.
## Spec: docs/superpowers/specs/2026-09-29-untangle-ring-design.md, section 3.

const FUR := Color("f0b073")
const FUR_DEEP := Color("d98a4a")
const MUZZLE := Color("fbe6c8")
const EAR_IN := Color("f2a7a0")
const NOSE := Color("e58a86")
const RATIO := 0.42

func _kind() -> String:
	return "kitten"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.98 * R), 1.05 * R, 0.22 * R, Color(Pal.TEXT, SHADOW_ALPHA))
		"body":
			# The shoulders, a soft mound under the head.
			b.ellipse(Vector2(0.0, 0.9 * R), 0.95 * R, 0.62 * R, FUR)
			b.ellipse(Vector2(0.0, 1.02 * R), 0.5 * R, 0.4 * R, MUZZLE)
			# The ears sit behind the head, so the head's edge covers their roots.
			for sx in [-1.0, 1.0]:
				var ear := PackedVector2Array([Vector2(sx * 0.98, -0.34) * R,
					Vector2(sx * 0.72, -1.22) * R, Vector2(sx * 0.14, -0.86) * R])
				b.polygon(ear, FUR_DEEP)
				b.polygon(PackedVector2Array([Vector2(sx * 0.84, -0.42) * R,
					Vector2(sx * 0.7, -1.0) * R, Vector2(sx * 0.3, -0.78) * R]), EAR_IN)
			b.ellipse(Vector2.ZERO, 1.0 * R, 0.9 * R, FUR)
			# Three brow stripes.
			for k in [-1.0, 0.0, 1.0]:
				var top := Vector2(k * 0.24, -0.86) * R
				var len := 0.3 if k == 0.0 else 0.22
				b.stroke(PackedVector2Array([top, top + Vector2(k * 0.03, len) * R]), 0.09 * R, FUR_DEEP)
			b.ellipse(Vector2(0.0, 0.38 * R), 0.46 * R, 0.32 * R, MUZZLE)
			_face_parts(b, 0.86 * R, Vector2(0.0, 0.06 * R), Pal.TEXT, eye)
			b.polygon(PackedVector2Array([Vector2(-0.09, 0.22) * R, Vector2(0.09, 0.22) * R, Vector2(0.0, 0.32) * R]), NOSE)
			for sx in [-1.0, 1.0]:
				for dy in [-0.05, 0.08]:
					b.stroke(PackedVector2Array([Vector2(sx * 0.4, 0.34 + dy) * R,
						Vector2(sx * 0.98, 0.26 + dy * 2.4) * R]), 0.03 * R, Color(Pal.TEXT, 0.55))
