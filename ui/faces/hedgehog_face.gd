extends "res://ui/faces/face.gd"

## The hedgehog, Hedgehogs' one character and the cast's first new animal
## since the bee: a brown dome of spines over a cream snout, looking left.
## Nothing else in the cast sleeps under leaves, which is what earns it a
## drawing of its own (CLAUDE.md, "check ui/faces/ before drawing a new
## character").
##
## Its looks are its expressions, so each is keyed into the mesh cache for
## free (the body layer carries the face):
##   SLEEPY -- upright, eyes shut in a downward arc: a sleeper under a pile;
##   STRAIN -- curled into a ball of spines with the snout tucked in and a
##             frown: a hedgehog a wrong rake woke;
##   JOY    -- up on its feet, eyes shut in a smile, mouth open: the win;
##   HAPPY  -- up on its feet, one round eye with a catchlight.
## Ported from the concept page's mock (docs/brainstorm/concepts.html#hedgehogs,
## `hedgehog`). Spec: docs/superpowers/specs/2026-09-26-hedgehogs-flat-design.md,
## section 7.


## R as a fraction of the seat.
const RATIO := 0.36
## The spines round the dome and round the ball.
const DOME_SPINES := 16
const BALL_SPINES := 22

func _kind() -> String:
	return "hedgehog"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(Vector2(0.0, 0.62 * R), 1.05 * R, 0.2 * R, Color(Pal.TEXT, 0.14))
		"body":
			if expression == Expr.STRAIN:
				_curled(b, R)
			else:
				_upright(b, R, eye)

## A ball of spines with the snout tucked in, a cheek and a frown.
func _curled(b: Builder, R: float) -> void:
	var ball := PackedVector2Array()
	for i in BALL_SPINES * 2:
		var a := float(i) / float(BALL_SPINES * 2) * TAU
		var r := (0.78 if i % 2 == 1 else 0.95) * R
		ball.append(Vector2(cos(a) * r, sin(a) * r * 0.92))
	b.polygon(ball, Pal.HOG_SPINE_DEEP)
	b.ellipse(Vector2.ZERO, 0.74 * R, 0.68 * R, Pal.HOG_SPINE)
	b.ellipse(Vector2(-0.2, 0.18) * R, 0.44 * R, 0.36 * R, Pal.HOG_FACE)
	b.disc(Vector2(-0.56, 0.16) * R, 0.09 * R, Pal.TEXT)
	b.ellipse(Vector2(-0.04, 0.3) * R, 0.1 * R, 0.07 * R, Color(Pal.CHEEK, 0.9))
	for ex: float in [-0.34, -0.06]:
		b.stroke(PackedVector2Array([Vector2(ex - 0.07, 0.02) * R, Vector2(ex + 0.07, 0.07) * R]), 0.06 * R, Pal.TEXT)
	b.stroke(Builder.arc_points(Vector2(-0.24, 0.42) * R, 0.1 * R, PI * 1.15, PI * 1.85), 0.05 * R, Pal.TEXT)

## Up on its feet: the spiny back, a paler dome with a few spine strokes, the
## snout to the left with its nose, a cheek, and the eye the expression says.
func _upright(b: Builder, R: float, eye: float) -> void:
	var up := expression == Expr.JOY or expression == Expr.HAPPY
	if up:
		b.ellipse(Vector2(-0.45, 0.55) * R, 0.14 * R, 0.1 * R, Pal.HOG_FACE_DEEP)
		b.ellipse(Vector2(0.35, 0.55) * R, 0.14 * R, 0.1 * R, Pal.HOG_FACE_DEEP)
	var back := PackedVector2Array([Vector2(1.0, 0.45) * R])
	for i in DOME_SPINES * 2 + 1:
		var a := float(i) / float(DOME_SPINES * 2) * PI
		var r := (0.86 if i % 2 == 1 else 1.04) * 1.02 * R
		back.append(Vector2(cos(a) * r, 0.45 * R - sin(a) * r))
	b.polygon(back, Pal.HOG_SPINE_DEEP)
	var dome := Builder.arc_points(Vector2(0.05, 0.45) * R, 0.84 * R, PI, TAU)
	b.polygon(dome, Pal.HOG_SPINE)
	for i in 7:
		var a := PI * (0.2 + float(i) * 0.1)
		var dir := Vector2(cos(a), -sin(a))
		var o := Vector2(0.05, 0.45) * R
		b.stroke(PackedVector2Array([o + dir * 0.4 * R, o + dir * 0.66 * R]), 0.05 * R, Pal.HOG_SPINE_HI)
	var snout := PackedVector2Array()
	snout.append_array(Builder.bezier2(Vector2(-0.35, -0.05) * R, Vector2(-1.05, 0.12) * R, Vector2(-1.08, 0.32) * R, 10))
	snout.append_array(Builder.bezier2(Vector2(-1.08, 0.32) * R, Vector2(-0.9, 0.58) * R, Vector2(-0.2, 0.52) * R, 10))
	snout.append_array(Builder.bezier2(Vector2(-0.2, 0.52) * R, Vector2(-0.1, 0.2) * R, Vector2(-0.35, -0.05) * R, 8))
	b.polygon(snout, Pal.HOG_FACE)
	b.disc(Vector2(-1.06, 0.3) * R, 0.1 * R, Pal.TEXT)
	b.ellipse(Vector2(-0.42, 0.38) * R, 0.11 * R, 0.07 * R, Color(Pal.CHEEK, 0.85))
	var e := Vector2(-0.55, 0.16) * R
	if expression == Expr.HAPPY and eye > 0.5:
		b.disc(e, 0.075 * R, Pal.TEXT)
		b.disc(e + Vector2(-0.025, -0.03) * R, 0.025 * R, Color(1.0, 1.0, 1.0, 0.9))
	elif expression == Expr.JOY:
		b.stroke(Builder.arc_points(e + Vector2(0.0, -0.03 * R), 0.08 * R, PI * 1.1, PI * 1.9), 0.05 * R, Pal.TEXT)
		b.stroke(Builder.arc_points(Vector2(-0.74, 0.4) * R, 0.08 * R, PI * 0.1, PI * 0.9), 0.045 * R, Pal.TEXT)
	else:
		b.stroke(Builder.arc_points(e, 0.08 * R, PI * 0.1, PI * 0.9), 0.05 * R, Pal.TEXT)
