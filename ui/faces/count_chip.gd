extends "res://ui/faces/face.gd"

## One of the numbers beside a line: a small card with a numeral on it, no
## face. It wears the state of its own line and nothing else -- cream while
## the line is unfinished, green the moment it holds exactly its number, rose
## the moment it holds too many -- which is the information the island's
## marker stones carry worst, being the smallest and most foreshortened thing
## on a board pitched at seven degrees.
##
## Built on Face for its mesh cache rather than for its face: three states, one
## mesh each per size, and the numeral drawn over the top with one draw_string
## exactly as `ui/faces/marker_face.gd` does it, because a digit in the cache
## key would multiply three states by nine for a single command per chip.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#tents, `countChip`).
## Spec: docs/superpowers/specs/2026-09-18-tents-flat-design.md, section 5.

const CozyTheme = preload("res://ui/theme.gd")

## R is the cell, the mock's `s`; the chip is drawn smaller than one.
const RATIO := 1.0
const CARD_AT := Vector2(-0.34, -0.3)
const CARD_SIZE := Vector2(0.68, 0.62)
const CARD_RADIUS := 0.18
const CARD_EDGE := 0.05
const NUM_Y := -0.03
const NUM_SIZE := 0.42

var number: int = 0:
	set(v):
		number = v
		queue_redraw()

func _init() -> void:
	super()
	plain = true

func _kind() -> String:
	return "chip"

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	return [["card", true]]

## Fill, rim and ink, from the line's state on `expression`: HAPPY is a line
## still short of its number, JOY one that holds it exactly, STRAIN one that
## holds too many.
func _skin() -> Array:
	match expression:
		Expr.JOY:
			return [Pal.LEAF, Pal.LEAF_DEEP, Pal.SURFACE]
		Expr.STRAIN:
			return [Pal.BAD, Pal.MARKER_DEEP, Pal.SURFACE]
		_:
			return [Pal.SURFACE, Pal.LINE, Pal.TEXT]

func _build_layer(name: String, R: float, _eye: float, b: Builder) -> void:
	if name != "card":
		return
	var skin := _skin()
	# The rim is the card at full height and the fill the same card short of
	# its bottom edge: the soft lip every cream card on these screens wears.
	b.fan(Builder.round_rect(CARD_AT * R, CARD_SIZE * R, CARD_RADIUS * R), skin[1])
	b.fan(Builder.round_rect(CARD_AT * R,
		(CARD_SIZE - Vector2(0.0, CARD_EDGE)) * R, CARD_RADIUS * R), skin[0])

func _draw() -> void:
	super()
	# A board that draws its chips' numerals itself (Tents, checkup
	# 2026-10-01: every numeral one batched run of glyphs) says "numeral".
	if skip_layers.has("numeral"):
		return
	var n := numeral()
	if not n.is_empty():
		draw_string(CozyTheme.display(700), n[0], n[1], HORIZONTAL_ALIGNMENT_LEFT, -1.0, n[2], n[3])

## The numeral as _draw writes it, [baseline point, text, px, colour] in this
## Control's own space, or [] for none.
func numeral() -> Array:
	var R := _R_for(minf(size.x, size.y))
	if R <= 0.0:
		return []
	var font: Font = CozyTheme.display(700)
	var px := int(roundf(NUM_SIZE * R))
	if px <= 0:
		return []
	# A count taken off its line (Tents' Insane) shows a soft question mark.
	var text := str(number) if number >= 0 else "?"
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var at := size * 0.5 + Vector2(-wide * 0.5, NUM_Y * R + font.get_ascent(px) * 0.5)
	return [at, text, px, _skin()[2] if number >= 0 else Color(Pal.TEXT, 0.35)]
