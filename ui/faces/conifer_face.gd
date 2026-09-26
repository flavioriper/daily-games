extends "res://ui/faces/face.gd"

## The meadow's tree: a trunk under three tiers of drooping needles, each lit
## on its left and shaded on its right, with the face on the lowest one. It
## blinks and it sways and it does nothing else -- which tree a tent belongs to is the player's problem, not the board's, and a
## tree that answered that would give away the whole difficulty of Tents
## (see the spec's section 4).
##
## The sway is `rock` through `_layer_angle`, the leaf's own idiom: a
## transform on the draw, so a swaying tree never rebuilds a mesh and the
## board it stands on can sit still.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#tents, `tree`).
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, section 4.

## R is the mock's `s`, which is 0.94 of a cell; every measure below is in it.
const RATIO := 1.0
## The sway: a slow lean either side, each tree on its own phase.
const SWAY := 0.022
const SWAY_PERIOD := 7.0
## The face is drawn at 52 units in the mock and scaled by s * 0.0055.
const FACE_R := 52.0 * 0.0055
const FACE_AT := Vector2(0.0, 10.0 * 0.0055)
## How far each tier's hem bows up between its tips, in R: the droop.
const HEM_BOW := 0.05
## A lower tier's shaded right half: LEAF_DEEP this far toward LEAF.
const TIER_SHADE := 0.35
const BARK_SHADE := 0.22

## Whether the tree casts its own shadow layer. The flat board draws every
## shadow on its own ground (one mesh of the family's soft discs, so a
## hopping tree leaves its shadow where it stood) and turns this off.
var casts: bool = true:
	set(v):
		casts = v
		queue_redraw()

func _kind() -> String:
	return "conifer"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	var layers: Array = []
	if casts:
		layers.append(["shadow", false])
	layers.append(["body", true])
	return layers

## The shadow stays on the ground; only the tree leans over it.
func _layer_angle(name: String) -> float:
	return rock if name == "body" else 0.0

func _idle_motion() -> Tween:
	var phase := randf() * TAU
	var tw := create_tween().set_loops()
	tw.tween_method(func(t: float) -> void: rock = SWAY * sin(TAU * t + phase),
		0.0, 1.0, SWAY_PERIOD)
	return tw

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.46) * R, 0.34 * R, 0.09 * R, Color(Pal.TEXT, 0.1))
		"body":
			# The trunk, its right side in shade.
			b.fan(Builder.round_rect(Vector2(-0.06, 0.2) * R, Vector2(0.12, 0.26) * R, 0.04 * R),
				Pal.BARK)
			b.fan(Builder.round_rect(Vector2(0.0, 0.2) * R, Vector2(0.06, 0.26) * R, 0.03 * R),
				Pal.BARK.darkened(BARK_SHADE))
			for i in 3:
				var y := (0.22 - i * 0.21) * R
				var wide := (0.38 - i * 0.09) * R
				var top := Vector2(0.0, y - 0.34 * R)
				var lit: Color = Pal.LEAF_LIGHT if i == 2 else Pal.LEAF
				var shade: Color = Pal.LEAF if i == 2 else Pal.LEAF_DEEP.lerp(Pal.LEAF, TIER_SHADE)
				b.polygon(_tier(top, y, wide, -1.0, 1.0, R), shade)
				b.polygon(_tier(top, y, wide, -1.0, 0.0, R), lit)
			_face_parts(b, FACE_R * R, FACE_AT * R, Pal.TEXT, eye)

## One tier of needles from `top` down to its tips at `y`, `wide` either side,
## over the part of the hem between `from` and `to` (-1 the left tip, 1 the
## right). The hem is bowed up between the tips, so they droop the way a
## bough does; the lit half is the same outline cut at the trunk's line.
static func _tier(top: Vector2, y: float, wide: float, from: float, to: float, R: float) -> PackedVector2Array:
	var pts := PackedVector2Array([top])
	var n := 10
	for k in n + 1:
		var u := lerpf(to, from, float(k) / n)
		pts.append(Vector2(u * wide, y - HEM_BOW * R * (1.0 - u * u)))
	return pts
