extends "res://ui/faces/face.gd"

## The paper lantern, the flat Untangle's whole cast: a flat cap over a
## rounded paper body with a rib across its waist, a base and a tassel under
## it, and the face low on the paper. Five papers, taken by index, so a board
## of fourteen repeats a colour rather than inventing a sixth -- the camp
## already stands a lantern on its path, so this borrows from the world the
## way Balance's apple borrowed from Code Break.
##
## The body is drawn about (0, 0) and the cords meet at a ring ARM + 0.86 R
## *above* that, which is the node the rule is about: the board hangs the
## body off the ring, so the point stays a point and the paper still swings.
##
## `lit` is the win: the light runs along the cords hop by hop and each
## lantern warms as it arrives, with a soft halo around it. It is snapped to
## LIT_LEVELS before it reaches the cache key, so a run of fourteen lanterns
## costs at most five meshes a paper rather than one a frame.
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#untangle, `lantern`).
## Spec: docs/superpowers/specs/2026-09-18-untangle-flat-design.md, section 4.

## The seat, in units of R: the drawing runs from the cap at -1.02 R to the
## tassel at 1.28 R, and is 1.72 R across.
const SEAT := 2.4
const RATIO := 1.0 / SEAT
## Where the ring hangs above the body's centre, in R. The arm is the rest.
const HANG := 0.86
const ARM := 0.62
## The halo's reach and its strength at full light.
const GLOW_R := 2.5
const GLOW_INNER := 0.4
const GLOW_ALPHA := 0.34
const GLOW_SEGMENTS := 36
## The shadow under the paper: a touch stronger than the family's, because a
## lantern hangs over parchment rather than sitting on a tile.
const DROP_ALPHA := 0.1
## `lit` is snapped to one of these for the cache key.
const LIT_LEVELS: Array[float] = [0.0, 0.25, 0.5, 0.75, 1.0]

## Which paper, by the lantern's index on the board.
var hue: int = 0:
	set(v):
		hue = v
		queue_redraw()
## 0 unlit to 1 fully lit.
var lit: float = 0.0:
	set(v):
		lit = clampf(v, 0.0, 1.0)
		queue_redraw()

func _kind() -> String:
	return "lantern%d_%d" % [hue % Pal.LANTERN_PAPER.size(), int(_lit_level() * 4.0)]

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	# The halo is only a layer while there is light in it: an empty mesh is
	# a surface with no vertices, which is not worth building or drawing.
	if _lit_level() > 0.0:
		return [["glow", false], ["shadow", false], ["body", true]]
	return [["shadow", false], ["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	var paper: Array = Pal.LANTERN_PAPER[hue % Pal.LANTERN_PAPER.size()]
	var level := _lit_level()
	var body: Color = paper[0].lerp(Pal.LANTERN_LIT, 0.38 * level)
	var deep: Color = paper[1].lerp(Pal.SUN, 0.4 * level)
	match name:
		"glow":
			_halo(b, R, GLOW_ALPHA * level)
		"shadow":
			b.ellipse(Vector2(0.1, 1.16) * R, 0.82 * R, 0.2 * R, Color(Pal.TEXT, DROP_ALPHA))
		"body":
			b.fan(Builder.round_rect(Vector2(-0.42, -1.02) * R, Vector2(0.84, 0.24) * R, 0.1 * R), deep)
			b.fan(Builder.round_rect(Vector2(-0.86, -0.86) * R, Vector2(1.72, 1.72) * R, 0.62 * R), body)
			b.fan(Builder.round_rect(Vector2(-0.7, -0.7) * R, Vector2(0.4, 1.36) * R, 0.2 * R),
				Color(1.0, 1.0, 1.0, 0.2))
			# The rib keeps the paper's own deep colour whatever the light is
			# doing, so a lit lantern still reads as folded paper.
			b.stroke(PackedVector2Array([Vector2(-0.86, -0.06) * R, Vector2(0.86, -0.06) * R]),
				0.07 * R, Color(paper[1], 0.45))
			b.fan(Builder.round_rect(Vector2(-0.34, 0.8) * R, Vector2(0.68, 0.2) * R, 0.08 * R), deep)
			b.stroke(PackedVector2Array([Vector2(0.0, 1.0) * R, Vector2(0.0, 1.28) * R]), 0.1 * R, deep)
			_face_parts(b, 0.9 * R, Vector2(0.0, -0.04 * R), Pal.TEXT, eye)

## The halo: a disc of light at GLOW_INNER fading to nothing at GLOW_R, built
## as two rings and the band between them, which is what a canvas radial
## gradient comes to once it is triangles.
func _halo(b: Builder, R: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var warm := Color(Pal.SUN, alpha)
	var clear := Color(Pal.SUN, 0.0)
	var centre := b.vertex(Vector2.ZERO, warm)
	var inner := b.verts.size()
	for i in GLOW_SEGMENTS:
		b.vertex(Vector2.from_angle(TAU * i / GLOW_SEGMENTS) * GLOW_INNER * R, warm)
	var outer := b.verts.size()
	for i in GLOW_SEGMENTS:
		b.vertex(Vector2.from_angle(TAU * i / GLOW_SEGMENTS) * GLOW_R * R, clear)
	for i in GLOW_SEGMENTS:
		var j := (i + 1) % GLOW_SEGMENTS
		b.tri(centre, inner + i, inner + j)
		b.tri(inner + i, outer + i, outer + j)
		b.tri(inner + i, outer + j, inner + j)

func _lit_level() -> float:
	var best: float = LIT_LEVELS[0]
	for lv in LIT_LEVELS:
		if absf(lv - lit) < absf(best - lit):
			best = lv
	return best
