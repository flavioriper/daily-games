extends "res://ui/faces/face.gd"

## The sprout, the tip card's mascot: a white blob in SURFACE with a LINE
## outline, a stem and two leaves on its head, and the face. It knows HAPPY,
## WORRIED and JOY. R is the blob's half width, sized so the leaves fit the
## rect.
## Spec: docs/superpowers/specs/2026-09-18-binairo-flat-design.md, section 4.

## How far the leaves reach above the centre, in R; radius() divides by it.
const REACH := 1.3
## Points per curve of a leaf's edge.
const LEAF_STEPS := 16

func _kind() -> String:
	return "sprout"

func _radius_for(px: float) -> float:
	return px * 0.5 / REACH

func _build_layer(_name: String, R: float, eye: float, b: Builder) -> void:
	b.ellipse(Vector2(0.0, 0.95 * 0.15 * R), 1.05 * R, 0.95 * R, Color(Pal.TEXT, SHADOW_ALPHA))
	b.stroke(PackedVector2Array([Vector2(0.0, -0.8 * R), Vector2(0.0, -1.15 * R)]), 0.09 * R, Pal.LEAF)
	_leaf(b, Vector2(0.0, -1.12 * R), 0.62 * R, -2.6)
	_leaf(b, Vector2(0.0, -1.12 * R), 0.55 * R, -0.55)
	b.ellipse(Vector2.ZERO, R, 0.9 * R, Pal.SURFACE)
	b.stroke(Builder.ring(Vector2.ZERO, R, 0.9 * R), 0.07 * R, Pal.LINE, true)
	_face_parts(b, 0.9 * R, Vector2(0.0, 0.12 * R), Pal.TEXT, eye)

## A leaf of `length` from `base` along `angle`: two quadratic curves out and
## back, and a lighter vein. The vein's colour is LEAF_LIGHT laid at nine
## tenths over LEAF, baked to one colour since it always sits on the leaf.
func _leaf(b: Builder, base: Vector2, length: float, angle: float) -> void:
	var xf := Transform2D(angle, base)
	var pts := PackedVector2Array()
	_bezier(pts, Vector2.ZERO, Vector2(0.55, -0.42) * length, Vector2(1.0, -0.05) * length)
	_bezier(pts, Vector2(1.0, -0.05) * length, Vector2(0.5, 0.28) * length, Vector2.ZERO)
	b.polygon(xf * pts, Pal.LEAF)
	b.stroke(xf * PackedVector2Array([Vector2(0.08, -0.02) * length, Vector2(0.85, -0.08) * length]),
		0.05 * length, Pal.LEAF.lerp(Pal.LEAF_LIGHT, 0.9))

## Appends a quadratic curve from `p0` through control `c` to `p1`, without
## the end point, so curves chain without a doubled vertex.
func _bezier(into: PackedVector2Array, p0: Vector2, c: Vector2, p1: Vector2) -> void:
	for i in LEAF_STEPS:
		var t := float(i) / LEAF_STEPS
		var u := 1.0 - t
		into.append(p0 * (u * u) + c * (2.0 * u * t) + p1 * (t * t))
