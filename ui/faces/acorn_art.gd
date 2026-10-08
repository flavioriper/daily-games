extends RefCounted

## Golden Acorn's own shapes, as builder calls rather than a Control: the
## board bakes them into its meshes and the menu card into its own
## (puzzles/acorn2d.gd, ui/menu/card_art.gd). The nut is the Code Break
## friend's (ui/faces/acorn_face.gd), number for number, without the face: on
## this board it is a prize and a mark, not a character.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## An acorn of radius `r` about `at`: brown, or the golden one.
static func acorn(b: Face.Builder, at: Vector2, r: float, gold := false, alpha := 1.0) -> void:
	var nut_c := Color(Pal.SUN if gold else Pal.ACORN, alpha)
	var cap_c := Color(Pal.SUN_DEEP if gold else Pal.ACORN_DEEP, alpha)
	var nut := PackedVector2Array([at + Vector2(-0.76, -0.26) * r])
	nut.append_array(Face.Builder.bezier3(at + Vector2(0.76, -0.26) * r, at + Vector2(0.76, 0.74) * r,
		at + Vector2(0.42, 1.06) * r, at + Vector2(0.0, 1.06) * r))
	nut.append_array(Face.Builder.bezier3(at + Vector2(0.0, 1.06) * r, at + Vector2(-0.42, 1.06) * r,
		at + Vector2(-0.76, 0.74) * r, at + Vector2(-0.76, -0.26) * r))
	b.polygon(nut, nut_c)
	if gold:
		# The one light on it: a short stroke down the nut's left shoulder.
		b.stroke(PackedVector2Array([at + Vector2(-0.42, 0.0) * r, at + Vector2(-0.38, 0.42) * r]),
			0.14 * r, Color(Pal.SUN_SPARK, alpha))
	b.stroke(PackedVector2Array([at + Vector2(0.0, -0.7) * r, at + Vector2(0.0, -1.04) * r]), 0.13 * r, cap_c)
	b.fan(Face.Builder.round_rect(at + Vector2(-0.9, -0.72) * r, Vector2(1.8, 0.5) * r, 0.25 * r), cap_c)

## A tick, for the answer that was right.
static func tick(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	b.stroke(PackedVector2Array([at + Vector2(-0.5, 0.02) * r, at + Vector2(-0.12, 0.4) * r,
		at + Vector2(0.52, -0.38) * r]), 0.24 * r, colour)

## A cross, for the answer that was not.
static func cross(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	for s: float in [-1.0, 1.0]:
		b.stroke(PackedVector2Array([at + Vector2(-0.4, -0.4 * s) * r, at + Vector2(0.4, 0.4 * s) * r]),
			0.24 * r, colour)

static func heart(b: Face.Builder, at: Vector2, r: float, colour: Color) -> void:
	var pts := PackedVector2Array()
	var lobe := r * 0.52
	var left := Face.Builder.arc_points(at + Vector2(-lobe, -r * 0.2), lobe, PI * 0.82, PI * 2.0)
	pts.append_array(left.slice(0, left.size() - 1))
	pts.append_array(Face.Builder.arc_points(at + Vector2(lobe, -r * 0.2), lobe, PI, PI * 2.18))
	pts.append(at + Vector2(0.0, r * 0.95))
	b.polygon(pts, colour)
