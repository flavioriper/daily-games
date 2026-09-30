extends "res://ui/faces/kitten_face.gd"

## Light Up's cat (Insane's Cat Naps): the kitten (ui/faces/kitten_face.gd),
## the same ginger tabby, curled on a round cushion on her stone with her tail
## wrapped round her and a little bell tag on her collar carrying the number
## of lanterns she wants shining on her -- a "z" instead of 0 for a napping
## cat, who wants the dark. Not a new character: her head is the kitten's own
## (`_head`), and what is new is the pose under it.
##
## Four draws a cat: the base (shadow, cushion, body, the wrapped tail and
## the paws, one mesh shared by every cat of a size), the tail's tip (its own
## mesh, turned about its joint by the swish, so a happy tail never rebuilds
## anything), the head (keyed by expression like every face, the ears laid
## back when she is cross), and the tag's glyph as one draw_string, since a
## digit in the cache key would multiply every head by four. A sleeping cat
## adds one more string for the small "z" drifting off her head.
## Spec: docs/superpowers/specs/2026-09-30-lightup-polish-design.md, section 2.

const CozyTheme = preload("res://ui/theme.gd")

## The cushion: a soft blue against the ginger fur and the warm lit floor.
const CUSHION := Color("9fb6dc")
const CUSHION_DEEP := Color("7b93bf")
const CUSHION_PIPE := Color("dbe5f5")
const COLLAR := Color("e2645c")
## The tail a shade deeper than her back, so it reads where it lies over her.
const TAIL := Color("e89d5c")
const TAG := Color("f9c04a")
const TAG_DEEP := Color("d88a12")
## Where the head sits in the seat and how big it is, in R (the seat's half).
const HEAD_AT := Vector2(-0.26, -0.22)
const HEAD_R := 0.5
## The tag under her chin and the glyph on it, in R.
const TAG_AT := Vector2(-0.26, 0.46)
const TAG_R := 0.28
const TAG_TEXT := 0.48
## The tail's tip turns about its joint by up to SWISH radians, one sway every
## SWISH_PERIOD, while she is happy.
const TAIL_JOINT := Vector2(0.4, 0.6)
const SWISH := 0.38
const SWISH_PERIOD := 1.6
## The sleeping "z": it rises Z_RISE R from over her head and fades out, once
## every Z_PERIOD.
const Z_PERIOD := 2.4
const Z_RISE := 0.5
const Z_TEXT := 0.34

## How many lanterns she wants: 0 (napping), 1 or 2. Her tag shows it.
var need := 1:
	set(v):
		need = v
		queue_redraw()
## The idle clock, 0 to 1, looping: the swish and the "z" read it.
var phase := 0.0:
	set(v):
		phase = v
		queue_redraw()

func _kind() -> String:
	return "napcat"

func _radius_for(px: float) -> float:
	return px * 0.5

func _layers() -> Array:
	return [["base", false], ["tip", false], ["head", true]]

func _idle_motion() -> Tween:
	var tw := create_tween().set_loops()
	phase = randf()
	tw.tween_method(func(t: float) -> void: phase = fposmod(t, 1.0), phase, phase + 1.0, Z_PERIOD)
	return tw

func _layer_transform(name: String, R: float, centre: Vector2) -> Transform2D:
	if name == "tip" and expression == Expr.JOY and not Motion.reduce:
		var turn := SWISH * sin(TAU * phase * Z_PERIOD / SWISH_PERIOD)
		var joint := TAIL_JOINT * R
		return Transform2D(0.0, centre + joint) * Transform2D(turn, Vector2.ZERO) * Transform2D(0.0, -joint)
	return super(name, R, centre)

## The glasses and the hat sit on her head, not the middle of the seat.
func _face_frame(R: float) -> Array:
	return [HEAD_AT * R, HEAD_R * R]

func _hat_place(R: float) -> Array:
	return [(HEAD_AT + Vector2(0.0, -0.4)) * R, -0.15, 0.32 * R]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"base":
			_base(b, R)
		"tip":
			# The last of the tail, from the joint round to a pale tip.
			var pts := Builder.bezier2(TAIL_JOINT * R, Vector2(0.18, 0.72) * R, Vector2(-0.02, 0.6) * R, 10)
			pts.append(Vector2(-0.02, 0.6) * R)
			b.stroke(pts, 0.17 * R, TAIL)
			b.disc(Vector2(-0.02, 0.6) * R, 0.085 * R, MUZZLE)
			b.stroke(PackedVector2Array([Vector2(0.26, 0.6) * R, Vector2(0.24, 0.72) * R]), 0.06 * R, FUR_DEEP)
		"head":
			var at := HEAD_AT * R
			var hr := HEAD_R * R
			_head(b, hr, eye, at, expression == Expr.STRAIN)
			# The collar under her chin, and the bell tag hanging from it.
			b.stroke(Builder.arc_points(at, 0.8 * hr, PI * 0.28, PI * 0.72), 0.1 * R, COLLAR, false, false)
			var tag := TAG_AT * R
			b.stroke(Builder.ring(tag + Vector2(0.0, -TAG_R * R), 0.06 * R, 0.06 * R), 0.035 * R, TAG_DEEP, true)
			b.disc(tag + Vector2(0.0, 0.03 * R), TAG_R * R, TAG_DEEP)
			b.disc(tag, TAG_R * R, TAG)
			b.ellipse(tag + Vector2(-0.1, -0.12) * R, 0.08 * R, 0.05 * R, Color(1.0, 1.0, 1.0, 0.5))

## The cushion, her curled body, the tail wrapped round the front and her
## paws tucked under her chin.
func _base(b: Builder, R: float) -> void:
	b.ellipse(Vector2(0.0, 0.7) * R, 0.9 * R, 0.2 * R, Color(Pal.TEXT, 0.16))
	b.ellipse(Vector2(0.0, 0.46) * R, 0.94 * R, 0.44 * R, CUSHION_DEEP)
	b.ellipse(Vector2(0.0, 0.38) * R, 0.92 * R, 0.4 * R, CUSHION)
	b.stroke(Builder.ring(Vector2(0.0, 0.38) * R, 0.86 * R, 0.35 * R), 0.035 * R, Color(CUSHION_PIPE, 0.8), true)
	for p: Vector2 in [Vector2(-0.62, 0.38), Vector2(0.62, 0.38), Vector2(0.0, 0.64)]:
		b.disc(p * R, 0.04 * R, CUSHION_DEEP)
	# The body, a loaf curled to her right, stripes over its back.
	b.ellipse(Vector2(0.2, 0.2) * R, 0.64 * R, 0.42 * R, FUR)
	b.ellipse(Vector2(0.5, 0.26) * R, 0.3 * R, 0.28 * R, FUR.lerp(FUR_DEEP, 0.35))
	for k in 3:
		var x := 0.18 + 0.2 * k
		b.stroke(Builder.bezier2(Vector2(x - 0.02, -0.18) * R, Vector2(x + 0.06, -0.06) * R,
			Vector2(x + 0.02, 0.04) * R, 8), 0.07 * R, FUR_DEEP)
	# The tail, from her haunch round the front of the cushion to its joint.
	var tail := Builder.bezier2(Vector2(0.76, 0.3) * R, Vector2(0.84, 0.66) * R, TAIL_JOINT * R, 10)
	tail.append(TAIL_JOINT * R)
	b.stroke(tail, 0.17 * R, TAIL)
	b.stroke(PackedVector2Array([Vector2(0.72, 0.52) * R, Vector2(0.62, 0.58) * R]), 0.06 * R, FUR_DEEP)
	# Front paws tucked in under the chin.
	for x in [-0.6, 0.08]:
		b.ellipse(Vector2(x, 0.5) * R, 0.13 * R, 0.09 * R, MUZZLE)

func _draw() -> void:
	super()
	var R := roundf(_R_for(minf(size.x, size.y)) / R_STEP) * R_STEP
	if R <= 0.0 or plain:
		return
	var centre := size * 0.5
	var font: Font = CozyTheme.display(700)
	# The tag: her number, or "z" for a napping cat.
	var text := "z" if need == 0 else str(need)
	var px := int(roundf(TAG_TEXT * R))
	var at := centre + TAG_AT * R
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	draw_string(font, at + Vector2(-wide * 0.5, font.get_ascent(px) * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, Pal.TEXT)
	# A sleeping cat breathes out a small "z" that drifts up and fades.
	if expression == Expr.SLEEPY:
		var u := 0.5 if Motion.reduce else phase
		var zpx := int(roundf(Z_TEXT * R * (0.8 + 0.4 * u)))
		var zat := centre + (HEAD_AT + Vector2(0.4 + 0.12 * u, -0.12 - Z_RISE * u)) * R
		draw_string(font, zat, "z", HORIZONTAL_ALIGNMENT_LEFT, -1.0, zpx,
			Color(Pal.MOON_DEEP, sin(PI * u) if not Motion.reduce else 0.8))
