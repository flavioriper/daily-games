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
## the eyes on the stalk tips with the mouth and cheek on the head, which
## carry the expression. So a board draws two
## cached meshes a frame however the walker is turned -- the turn and the rock
## are the Control's own transform, never a rebuild.
##
## The drawing faces right. The board mirrors it with a negative scale.x when
## the stroke heads the other way, which is why the face sits on the head and
## not on the shell: a mirrored shell is still a shell, and a mirrored face
## would read as a second animal.
## First ported from the canvas mock (docs/brainstorm/concepts.html#oneline,
## `snail`) and redrawn in the second polish (2026-09-25): the pale foot sank
## into the parchment and an eye on the head beside two eyed stalks read as a
## second face.
## Spec: docs/superpowers/specs/2026-09-18-oneline-flat-design.md, section 4.

## The seat, in units of R: the drawing runs from the tail at -1.1 R to the
## front eye at 1.1 R across, and from the eyes' tops at -0.9 R to the foot's
## shadow at 0.94 R.
const SEAT := 2.3
const RATIO := 1.0 / SEAT
## The shadow the foot casts on the plank it is standing on.
const SHADOW_A := 0.16
## The shell's spiral: three and a bit turns out from the eye of it.
const SPIRAL_TURNS := 3.1
const SPIRAL_STEPS := 40
const SPIRAL_FROM := 0.1
const SPIRAL_TO := 0.5
## The two eyestalks, foot on the head and eye at the tip, far one first so
## the near one is drawn over it.
const STALKS := [[Vector2(0.62, 0.0), Vector2(0.52, -0.62)], [Vector2(0.82, 0.02), Vector2(0.92, -0.64)]]
const EYE_R := 0.15
## The blush on the cheek, a shade of the family's rose.
const CHEEK_A := 0.45

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
## foot it slides on with its head raised at the front, the shell over it
## with its spiral and its shine, and the two stalks. The foot has a deep
## rim under it, because the pale flesh alone sank into the parchment.
func _build_body(R: float, b: Builder) -> void:
	b.ellipse(Vector2(0.0, 0.74) * R, 1.02 * R, 0.2 * R, Color(Pal.TEXT, SHADOW_A))
	for s in STALKS:
		_stalk(b, s[0] * R, s[1] * R, 0.13 * R, Pal.SNAIL_DEEP)
	b.fan(Builder.round_rect(Vector2(-1.1, 0.26) * R, Vector2(1.96, 0.48) * R, 0.24 * R),
		Pal.SNAIL_DEEP)
	b.disc(Vector2(0.7, 0.2) * R, 0.36 * R, Pal.SNAIL_DEEP)
	b.fan(Builder.round_rect(Vector2(-1.05, 0.3) * R, Vector2(1.86, 0.38) * R, 0.19 * R),
		Pal.SNAIL_FOOT)
	b.disc(Vector2(0.7, 0.2) * R, 0.3 * R, Pal.SNAIL_FOOT)
	for s in STALKS:
		_stalk(b, s[0] * R, s[1] * R, 0.07 * R, Pal.SNAIL_FOOT)
	# The sole's soft light along its top, a fan and never a stroke: a stroke's
	# caps would double its alpha at both ends.
	b.fan(Builder.round_rect(Vector2(-0.98, 0.34) * R, Vector2(1.5, 0.08) * R, 0.04 * R),
		Color(1.0, 1.0, 1.0, 0.3))
	b.disc(Vector2(-0.28, -0.12) * R, 0.74 * R, Pal.SHELL_DEEP)
	b.disc(Vector2(-0.28, -0.18) * R, 0.68 * R, Pal.SHELL)
	var eye_of := Vector2(-0.26, -0.2) * R
	var spiral := PackedVector2Array()
	spiral.resize(SPIRAL_STEPS + 1)
	for i in SPIRAL_STEPS + 1:
		var u := float(i) / SPIRAL_STEPS
		var a := u * PI * SPIRAL_TURNS
		spiral[i] = eye_of + Vector2.from_angle(a) * R * (SPIRAL_FROM + SPIRAL_TO * u)
	b.stroke(spiral, 0.11 * R, Color(Pal.SHELL_DEEP, 0.85))
	b.ellipse(Vector2(-0.56, -0.5) * R, 0.2 * R, 0.12 * R, Color(1.0, 1.0, 1.0, 0.32))

func _stalk(b: Builder, foot: Vector2, tip: Vector2, width: float, colour: Color) -> void:
	var line := Builder.bezier2(foot, foot.lerp(tip, 0.5) + Vector2(0.1 * (tip - foot).length(), 0.0), tip)
	line.append(tip)
	b.stroke(line, width, colour)

## The face: the eyes ride the stalk tips, as a snail's do, so there is no eye
## on the head to make a second face of it; the head keeps the mouth and the
## cheek. The pupils look ahead. STRAIN flattens the mouth and lowers the
## lids, which is what the walker wears the moment a step strands part of the
## figure behind it.
func _build_head(R: float, eye: float, b: Builder) -> void:
	var open := 1.0 if expression == Expr.JOY else eye
	var strain := expression == Expr.STRAIN or expression == Expr.WORRIED
	if strain:
		open = minf(open, 0.55)
	for s in STALKS:
		var at: Vector2 = s[1] * R
		b.disc(at, (EYE_R + 0.04) * R, Pal.SNAIL_DEEP)
		b.disc(at, EYE_R * R, Pal.PAPER)
		if plain:
			continue
		b.ellipse(at + Vector2(0.04, 0.02) * R, 0.08 * R, maxf(0.012 * R, 0.09 * R * open), Pal.TEXT)
		if open > 0.3:
			b.disc(at + Vector2(0.07, -0.03) * R, 0.028 * R, Color(1.0, 1.0, 1.0, 0.9))
	if plain:
		return
	b.ellipse(Vector2(0.66, 0.32) * R, 0.09 * R, 0.055 * R, Color(Pal.BAD, CHEEK_A))
	if strain:
		b.stroke(PackedVector2Array([Vector2(0.78, 0.3) * R, Vector2(0.96, 0.3) * R]),
			0.06 * R, Pal.TEXT)
		return
	b.stroke(Builder.arc_points(Vector2(0.86, 0.2) * R, 0.12 * R, PI * 0.1, PI * 0.7),
		0.06 * R, Pal.TEXT)
