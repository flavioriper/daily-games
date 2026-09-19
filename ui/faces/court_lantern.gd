extends "res://ui/faces/lantern_face.gd"

## The lamp the flat Light Up sets down on a flagstone: Untangle's paper
## lantern (ui/faces/lantern_face.gd) with the cord and the tassel taken off
## it and an iron foot put under it, so the seventh flat screen adds no new
## species to the cast -- it shares the parent's seat, its halo and its mesh
## cache.
##
## What changes is what `lit` means. On Untangle the light was the reward at
## the very end; here it is the state -- a lamp you set down is burning, and
## reading how far its light travels is the whole game -- so a court lamp is
## drawn lit from the moment it lands, and the only lamp on the board that is
## dark is one being taken away.
##
## Two more states ride on the drawing. `bad` is a lamp that can see another,
## which blushes and strains; it is *both* lamps, because neither is more
## wrong than the other. `locked` is a lamp a hint lit: green iron and a green
## arc at its foot, the language every board uses for a given. Both are in the
## cache key, so a court of ten lamps still shares one mesh a state.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#lightup, `lantern`).
## Spec: docs/superpowers/specs/2026-09-18-lightup-flat-design.md, section 4.

## The halo at full light. Untangle's reach (GLOW_R, GLOW_INNER) is kept, and
## with it the parent's `_halo`: ten lamps on a hard court is already a great
## deal of warm light in one card, and two subtly different glows in the
## family would be worse than one shared one.
const GLOW_COURT := 0.3
## The paper, by index into Pal.LANTERN_PAPER: the court's lamps are all amber,
## because here the colour is a state and not a name.
const PAPER := 0

## A lamp that can see another lamp down a line.
var bad: bool = false:
	set(v):
		bad = v
		queue_redraw()
## A lamp a hint lit, which can never be taken up again.
var pinned: bool = false:
	set(v):
		pinned = v
		queue_redraw()

func _kind() -> String:
	return "courtlamp%d%d_%d" % [int(bad), int(pinned), int(_lit_level() * 4.0)]

func _layers() -> Array:
	# The shadow is the parent's `casts` flag here too: the flat Light Up
	# draws it on the court's own ground, so a hopping lamp leaves it behind.
	var layers: Array = []
	if _lit_level() > 0.0:
		layers.append(["glow", false])
	if casts:
		layers.append(["shadow", false])
	layers.append(["body", true])
	return layers

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	var level := _lit_level()
	match name:
		"glow":
			_halo(b, R, GLOW_COURT * level)
		"shadow":
			# A touch tighter than the parent's, because this lantern stands on
			# a stone rather than hanging over parchment.
			b.ellipse(Vector2(0.05, 1.1) * R, 0.78 * R, 0.19 * R, Color(Pal.TEXT, 0.13))
		"body":
			var paper: Array = Pal.LANTERN_PAPER[PAPER]
			var skin: Color = Pal.BAD if bad else paper[0]
			var edge: Color = Pal.MARKER_DEEP if bad else paper[1]
			# A blushing lamp warms far less with the light: at the paper's own
			# 0.34 the rose went a redder amber that nobody reads as wrong.
			var body: Color = skin.lerp(Pal.LANTERN_LIT, (0.16 if bad else 0.34) * level)
			var deep: Color = edge.lerp(Pal.BAD if bad else Pal.SUN, 0.34 * level)
			var iron: Color = Pal.LEAF_DEEP if pinned else Pal.LANTERN
			b.fan(Builder.round_rect(Vector2(-0.5, -1.08) * R, Vector2(1.0, 0.24) * R, 0.09 * R), iron)
			b.fan(Builder.round_rect(Vector2(-0.86, -0.86) * R, Vector2(1.72, 1.72) * R, 0.62 * R), deep)
			b.fan(Builder.round_rect(Vector2(-0.86, -0.86) * R, Vector2(1.72, 1.56) * R, 0.6 * R), body)
			b.fan(Builder.round_rect(Vector2(-0.7, -0.68) * R, Vector2(0.38, 1.3) * R, 0.19 * R),
				Color(1.0, 1.0, 1.0, 0.2))
			b.stroke(PackedVector2Array([Vector2(-0.84, -0.04) * R, Vector2(0.84, -0.04) * R]),
				0.07 * R, Color(edge, 0.42))
			b.fan(Builder.round_rect(Vector2(-0.42, 0.82) * R, Vector2(0.84, 0.2) * R, 0.08 * R), iron)
			b.fan(Builder.round_rect(Vector2(-0.24, 1.0) * R, Vector2(0.48, 0.12) * R, 0.05 * R), iron)
			if pinned:
				# The arc at its foot, in cell units on the mock: the lamp is
				# drawn at 0.38 of a cell, so 0.4 and 0.28 of a cell come to
				# these in R.
				b.stroke(Builder.arc_points(Vector2(0.0, 1.05) * R, 0.74 * R, 0.1 * PI, 0.9 * PI),
					0.12 * R, Color(Pal.LEAF, 0.9), false, false)
			_face_parts(b, 0.88 * R, Vector2(0.0, -0.02 * R), Pal.TEXT, eye)
