extends "res://ui/faces/face.gd"

## The walker: the snail that rides the stroke on the flat One Line, laying
## the plank behind it as it crosses a line. It is the one new species the
## eight flat screens have added since Code Break's friends, and what earns it
## the exception is that its trail *is* the mechanic -- the line you may not
## lift your finger off is the line it leaves behind. (`ui/faces/` already
## holds the five fruit, the seven friends, two lanterns, Shikaku's marker,
## the tent, the tree, the sun and the moon, and not one of them walks
## anywhere.)
##
## Two layers: the shell, foot, spiral and eyestalks, which never change, and
## the head's eye and mouth, which carry the expression. So a board draws two
## cached meshes a frame however the walker is turned -- the turn and the rock
## are the Control's own transform, never a rebuild.
##
## The drawing faces right. The board mirrors it with a negative scale.x when
## the stroke heads the other way, which is why the face sits on the head and
## not on the shell: a mirrored shell is still a shell, and a mirrored face
## would read as a second animal.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#oneline, `snail`).
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, section 4.

## The seat, in units of R: the drawing runs from the tail at -1.08 R to the
## eyestalks at 1.11 R across, and from the stalk tips at -0.94 R to the
## foot's shadow at 0.94 R.
const SEAT := 2.3
const RATIO := 1.0 / SEAT
## The shadow the foot casts on the plank it is standing on.
const SHADOW_A := 0.14
## The shell's spiral: three and a bit turns out from the eye of it.
const SPIRAL_TURNS := 3.1
const SPIRAL_STEPS := 40
const SPIRAL_FROM := 0.12
const SPIRAL_TO := 0.54
## The two eyestalks, by how far forward each one leaves the foot.
const STALKS: Array[float] = [0.66, 0.96]

func _kind() -> String:
	return "snail"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["body", false], ["head", true]]

func _build_layer(layer: String, R: float, eye: float, b: Builder) -> void:
	match layer:
		"body":
			_build_body(R, b)
		"head":
			_build_head(R, eye, b)

## Everything that is the same whatever the walker is feeling: the shadow, the
## foot it slides on, the shell over it with its spiral, and the eyestalks.
func _build_body(R: float, b: Builder) -> void:
	b.ellipse(Vector2(0.0, 0.72) * R, 1.0 * R, 0.22 * R, Color(Pal.TEXT, SHADOW_A))
	b.fan(Builder.round_rect(Vector2(-1.0, 0.16) * R, Vector2(2.0, 0.56) * R, 0.28 * R),
		Pal.SNAIL_DEEP)
	b.fan(Builder.round_rect(Vector2(-1.0, 0.1) * R, Vector2(2.0, 0.5) * R, 0.25 * R),
		Pal.SNAIL_FOOT)
	b.disc(Vector2(-0.3, -0.16) * R, 0.78 * R, Pal.SHELL_DEEP)
	b.disc(Vector2(-0.3, -0.22) * R, 0.72 * R, Pal.SHELL)
	var eye_of := Vector2(-0.3, -0.22) * R
	var spiral := PackedVector2Array()
	spiral.resize(SPIRAL_STEPS + 1)
	for i in SPIRAL_STEPS + 1:
		var u := float(i) / SPIRAL_STEPS
		var a := u * PI * SPIRAL_TURNS
		spiral[i] = eye_of + Vector2.from_angle(a) * R * (SPIRAL_FROM + SPIRAL_TO * u)
	b.stroke(spiral, 0.12 * R, Color(Pal.SHELL_DEEP, 0.85))
	for s in STALKS:
		var stalk := Builder.bezier2(Vector2(s + 0.04, 0.14) * R,
			Vector2(s + 0.22, -0.36) * R, Vector2(s + 0.14, -0.66) * R)
		stalk.append(Vector2(s + 0.14, -0.66) * R)
		b.stroke(stalk, 0.12 * R, Pal.SNAIL_DEEP)
		b.disc(Vector2(s + 0.14, -0.7) * R, 0.11 * R, Pal.TEXT)

## The family's face at a size a snail can carry: one eye and a mouth, no
## cheeks and no brows. STRAIN flattens the mouth, which is what the walker
## wears the moment a step strands part of the figure behind it.
func _build_head(R: float, eye: float, b: Builder) -> void:
	if plain:
		return
	var open := 1.0 if expression == Expr.JOY else eye
	b.ellipse(Vector2(0.82, 0.28) * R, 0.09 * R, maxf(0.012 * R, 0.09 * R * open), Pal.TEXT)
	if expression == Expr.STRAIN or expression == Expr.WORRIED:
		b.stroke(PackedVector2Array([Vector2(0.62, 0.48) * R, Vector2(0.98, 0.48) * R]),
			0.07 * R, Pal.TEXT)
		return
	b.stroke(Builder.arc_points(Vector2(0.76, 0.38) * R, 0.16 * R, PI * 0.05, PI * 0.75),
		0.07 * R, Pal.TEXT)
