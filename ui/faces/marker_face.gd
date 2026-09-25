extends "res://ui/faces/face.gd"

## Shikaku's clue marker: a wooden plaque on a stake, carrying its number and
## a face. It is the only character on the flat field, and it wears exactly
## the state the board already computes for it -- four, no more: idle (cream,
## a smile), settled (green, eyes shut and grinning), the wrong size (rose,
## strained) and lost (puzzled, its bed blushing under it).
##
## The state is carried by `expression` alone, because the four states and
## the four faces map one to one: the plaque's fill, its rim and the ink its
## numeral is written in all follow from it. That keeps the mesh cache key
## the base already builds -- kind, layer, R, expression, eye -- sufficient,
## and every marker of a state on the board shares one mesh.
##
## The numeral is the exception. It is drawn over the mesh with one
## draw_string rather than built into it, because a digit in the cache key
## would multiply every state by nine for a single command per marker; a
## hard board carries fourteen of them.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#shikaku, `marker`).
## Spec: docs/superpowers/specs/2026-09-18-shikaku-flat-design.md, section 4.

const CozyTheme = preload("res://ui/theme.gd")

## R as a fraction of the seat. The mock draws the marker at s = 0.86 of a
## cell and measures every part of it in s, so R is s and the ratios below
## are the mock's own numbers.
const RATIO := 1.0
## The plaque, in R: the mock's card(-0.46, -0.52, 0.92, 0.78) with a 0.2
## corner and a 0.06 bottom edge.
const PLAQUE_AT := Vector2(-0.46, -0.52)
const PLAQUE_SIZE := Vector2(0.92, 0.78)
const PLAQUE_RADIUS := 0.2
const PLAQUE_EDGE := 0.06
## The stake behind it and the shadow it casts on the ground.
const STAKE_AT := Vector2(-0.05, -0.1)
const STAKE_SIZE := Vector2(0.1, 0.62)
const STAKE_RADIUS := 0.04
const SHADOW_AT := Vector2(0.0, 0.54)
const SHADOW_RX := 0.26
const SHADOW_RY := 0.07
## The numeral's baseline and its size, and the face's centre under it.
const NUM_Y := -0.27
const NUM_SIZE := 0.4
const FACE_AT := Vector2(0.0, -0.02)
## The face is drawn at 52 units in the mock and scaled by s * 0.0042.
const FACE_R := 52.0 * 0.0042
## The plaque for each clue shape (puzzles/shikaku_gen.gd's Shape: any,
## square, tall, wide), so the sign *is* the shape it asks for: [corner,
## size, numeral centre, face centre], in R. ANY is the mock's own card
## above. Every plaque keeps the mock's centre line, -0.13, so a row of mixed
## signs stands level on its stakes.
const PLAQUES := [
	[PLAQUE_AT, PLAQUE_SIZE, Vector2(0.0, NUM_Y), FACE_AT],
	[Vector2(-0.45, -0.58), Vector2(0.9, 0.9), Vector2(0.0, -0.3), Vector2(0.0, 0.03)],
	[Vector2(-0.31, -0.66), Vector2(0.62, 1.06), Vector2(0.0, -0.41), Vector2(0.0, 0.09)],
	[Vector2(-0.6, -0.44), Vector2(1.2, 0.62), Vector2(-0.25, -0.15), Vector2(0.27, -0.12)],
]
## A square, tall or wide sign has its corner drawn tighter than the card's
## and a thin frame inked inside its edge -- the outline is the rule -- so it
## never reads as the plain card, whose proportions a square is close to.
const SHAPED_RADIUS := 0.07
const FRAME_INSET := 0.07
const FRAME_WIDTH := 0.035

## The number on the plaque, 0 for none. It is drawn over the cached mesh,
## so changing it only asks for a redraw -- except to or from none, which
## moves the face to the middle of the sign.
var number: int = 1:
	set(v):
		number = v
		queue_redraw()
## The shape the sign asks for, and is drawn as.
var shape: int = 0:
	set(v):
		shape = clampi(v, 0, PLAQUES.size() - 1)
		queue_redraw()
## Whether the marker casts its own shadow layer. A board that draws the
## shadows on its own ground (Shikaku builds them into one mesh, so a hopping
## marker leaves its shadow where it stood) turns this off.
var casts: bool = true:
	set(v):
		casts = v
		queue_redraw()

func _kind() -> String:
	return "marker%d%s" % [shape, "" if number > 0 else "_"]

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	var layers: Array = []
	if casts:
		layers.append(["shadow", false])
	layers.append(["stake", false])
	layers.append(["plaque", true])
	return layers

## The plaque's fill, its rim and the ink on it, from the state the
## expression carries.
func _skin() -> Array:
	match expression:
		Expr.JOY:
			return [Pal.LEAF, Pal.LEAF_DEEP, Pal.SURFACE]
		Expr.STRAIN:
			return [Pal.BAD, Pal.MARKER_DEEP, Pal.SURFACE]
		_:
			return [Pal.SURFACE, Pal.LINE, Pal.TEXT]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	match name:
		"shadow":
			b.ellipse(SHADOW_AT * R, SHADOW_RX * R, SHADOW_RY * R, Color(Pal.TEXT, 0.10))
		"stake":
			b.fan(Builder.round_rect(STAKE_AT * R, STAKE_SIZE * R, STAKE_RADIUS * R), Pal.FENCE_DARK)
		"plaque":
			var skin := _skin()
			var plaque: Array = PLAQUES[shape]
			var at: Vector2 = plaque[0]
			var span: Vector2 = plaque[1]
			var corner := PLAQUE_RADIUS if shape == 0 else SHAPED_RADIUS
			# The rim is the card at full height and the fill the same card
			# short of its bottom edge, which is how every cream card on the
			# flat screens gets its soft lip.
			b.fan(Builder.round_rect(at * R, span * R, corner * R), skin[1])
			b.fan(Builder.round_rect(at * R,
				(span - Vector2(0.0, PLAQUE_EDGE)) * R, corner * R), skin[0])
			if shape != 0:
				var inset := Vector2.ONE * FRAME_INSET
				b.stroke(Builder.round_rect((at + inset) * R,
					(span - Vector2(0.0, PLAQUE_EDGE) - inset * 2.0) * R, corner * 0.5 * R),
					FRAME_WIDTH * R, Color(skin[2], 0.35), true)
			# A sign with no number wears its face in the middle.
			var face: Vector2 = plaque[3] if number > 0 \
				else at + (span - Vector2(0.0, PLAQUE_EDGE)) * 0.5
			_face_parts(b, FACE_R * R * (1.0 if number > 0 else 1.25), face * R, skin[2], eye)

## The numeral, over the plaque's mesh. Centred on the mock's own baseline.
func _draw() -> void:
	super()
	var R := _R_for(minf(size.x, size.y))
	if R <= 0.0:
		return
	if number <= 0:
		return
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(NUM_SIZE * R))
	if px <= 0:
		return
	var text := str(number)
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	# draw_string sits on the baseline; the mock's text() centres on the
	# glyph, so half the ascent puts the two in the same place.
	var centre: Vector2 = PLAQUES[shape][2]
	var at := size * 0.5 + Vector2(centre.x * R - wide * 0.5, centre.y * R + font.get_ascent(px) * 0.5)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px, _skin()[2])
