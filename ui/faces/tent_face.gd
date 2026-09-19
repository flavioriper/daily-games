extends "res://ui/faces/face.gd"

## A canvas tent: two slopes over a dark doorway, guy lines pegged out either
## side, and the face low on the lit slope.
##
## It carries the two rules it can be seen breaking on its own -- it touches
## another tent, diagonals included, or it stands beside no tree at all -- as
## a blush over the whole fabric. Nothing else: a tent never says which tree
## it belongs to. The state rides on `expression`, so the fabric's colour and
## the face follow from it together and the base's cache key is enough:
## HAPPY is pitched, STRAIN is in trouble, JOY is the win.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#tents, `tent`).
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, section 4.

## R is the mock's `s`, which is 0.9 of a cell.
const RATIO := 1.0
## How far the fabric goes toward the rose when a rule is broken.
const BAD_MIX := 0.6
## The face is drawn at 52 units in the mock and scaled by s * 0.0034, low on
## the lit slope.
const FACE_R := 52.0 * 0.0034
const FACE_AT := Vector2(-0.06, -0.16)
## The peg-line a hint leaves at the tent's foot: an arc, in R.
const PEG_AT := Vector2(0.0, 0.36)
const PEG_R := 0.3
const PEG_WIDTH := 0.045
const PEG_MIN := 3.0

## A tent a hint pitched, pegged down for good. It is part of the cache key,
## because the arc is drawn into the same mesh as the fabric.
var pegged := false:
	set(v):
		pegged = v
		queue_redraw()
## Whether the tent casts its own shadow layer. The flat board draws every
## shadow on its own ground (one mesh of the family's soft discs, so a
## hopping tent leaves its shadow where it stood) and turns this off; the
## guy lines stay with the tent either way.
var casts: bool = true:
	set(v):
		casts = v
		queue_redraw()

func _kind() -> String:
	return "tent_pegged" if pegged else "tent"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	var layers: Array = []
	if casts:
		layers.append(["shadow", false])
	layers.append(["ground", false])
	layers.append(["body", true])
	return layers

## The fabric's two colours, from the state the expression carries.
func _skin() -> Array:
	if expression == Expr.STRAIN:
		return [Pal.TENT_CANVAS.lerp(Pal.BAD, BAD_MIX), Pal.TENT_DEEP.lerp(Pal.MARKER_DEEP, BAD_MIX)]
	return [Pal.TENT_CANVAS, Pal.TENT_DEEP]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.42) * R, 0.42 * R, 0.1 * R, Color(Pal.TEXT, 0.12))
		"ground":
			for side: float in [-1.0, 1.0]:
				b.stroke(PackedVector2Array([
					Vector2(side * 0.44, 0.4) * R, Vector2(side * 0.16, -0.3) * R]),
					0.035 * R, Color(Pal.TENT_DARK, 0.55))
		"body":
			var skin := _skin()
			b.fan(PackedVector2Array([Vector2(0.0, -0.46) * R,
				Vector2(0.42, 0.4) * R, Vector2(-0.42, 0.4) * R]), skin[1])
			b.fan(PackedVector2Array([Vector2(0.0, -0.46) * R,
				Vector2(0.2, 0.4) * R, Vector2(-0.42, 0.4) * R]), skin[0])
			b.fan(PackedVector2Array([Vector2(0.0, -0.1) * R,
				Vector2(0.15, 0.4) * R, Vector2(-0.15, 0.4) * R]), Pal.TENT_DARK)
			_face_parts(b, FACE_R * R, FACE_AT * R, Pal.TEXT, eye)
			if pegged:
				b.stroke(Builder.arc_points(PEG_AT * R, PEG_R * R, PI * 0.1, PI * 0.9),
					maxf(PEG_MIN, PEG_WIDTH * R), Color(Pal.LEAF, 0.9))
