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
## An unlit paper washed out, for a board where being unlit is the state the
## screen is mostly in: 55% of the way to STONE, its deep edge half-way to
## FLAGSTONE. Both are the canvas mock's own pair (Fairy Lights' spec,
## section 5), and both are **off by default** -- Untangle, Light Up and the
## menu card are untouched to the pixel.
const DIM_BODY := 0.55
const DIM_DEEP := 0.5

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
## Whether the paper casts its own shadow layer. A board that draws the
## shadows on its own ground (Untangle builds them into its cord mesh, so a
## lifted lantern's shadow can part from it) turns this off; Light Up's lamp
## and the menu's card keep it.
var casts: bool = true:
	set(v):
		casts = v
		queue_redraw()
## Whether an unlit paper is washed out by DIM_BODY and DIM_DEEP. Untangle
## hangs five lanterns that are unlit only until the win, so full paper is
## right there; Fairy Lights fills a garden with them and being unlit is the
## board's ordinary state, so a wall of full-saturation paper cannot read as
## dark -- and its unlit *amber* comes out warmer than the gold wire it is
## the whole point of the screen to tell apart. **Off by default**, and it
## rides the mesh cache key, so a washed paper and a plain one never share a
## mesh.
var dims: bool = false:
	set(v):
		dims = v
		queue_redraw()

## Whether the paper is drawn folded: a pleat bowing down each side, a band
## of shade low in the belly, a lit edge on the cap and, as the light comes
## up, a candle's warmth in the middle of the paper. Untangle's lanterns hang
## large and alone on a bare card, where the plain paper read as a sweet;
## **off by default**, so Light Up's lamp, Fairy Lights' garden and the menu
## card are untouched to the pixel. It rides the cache key.
var pleats: bool = false:
	set(v):
		pleats = v
		queue_redraw()

func _kind() -> String:
	return "lantern%d_%d%s%s" % [hue % Pal.LANTERN_PAPER.size(),
		int(_lit_level() * 4.0), "d" if dims else "", "p" if pleats else ""]

func _radius_for(px: float) -> float:
	return px * RATIO

func _layers() -> Array:
	# The halo is only a layer while there is light in it: an empty mesh is
	# a surface with no vertices, which is not worth building or drawing.
	var layers: Array = []
	if _lit_level() > 0.0:
		layers.append(["glow", false])
	if casts:
		layers.append(["shadow", false])
	layers.append(["body", true])
	return layers

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	var paper: Array = Pal.LANTERN_PAPER[hue % Pal.LANTERN_PAPER.size()]
	var level := _lit_level()
	var body: Color = paper[0].lerp(Pal.LANTERN_LIT, 0.38 * level)
	var deep: Color = paper[1].lerp(Pal.SUN, 0.4 * level)
	if dims and level <= 0.0:
		body = paper[0].lerp(Pal.STONE, DIM_BODY)
		deep = paper[1].lerp(Pal.FLAGSTONE, DIM_DEEP)
	match name:
		"glow":
			_halo(b, R, GLOW_ALPHA * level)
		"shadow":
			b.ellipse(Vector2(0.1, 1.16) * R, 0.82 * R, 0.2 * R, Color(Pal.TEXT, DROP_ALPHA))
		"body":
			b.fan(Builder.round_rect(Vector2(-0.42, -1.02) * R, Vector2(0.84, 0.24) * R, 0.1 * R), deep)
			b.fan(Builder.round_rect(Vector2(-0.86, -0.86) * R, Vector2(1.72, 1.72) * R, 0.62 * R), body)
			if pleats:
				_folds(b, R, paper, deep, level)
			b.fan(Builder.round_rect(Vector2(-0.7, -0.7) * R, Vector2(0.4, 1.36) * R, 0.2 * R),
				Color(1.0, 1.0, 1.0, 0.2))
			# The rib keeps the paper's own deep colour whatever the light is
			# doing, so a lit lantern still reads as folded paper.
			b.stroke(PackedVector2Array([Vector2(-0.86, -0.06) * R, Vector2(0.86, -0.06) * R]),
				0.07 * R, Color(paper[1], 0.45))
			b.fan(Builder.round_rect(Vector2(-0.34, 0.8) * R, Vector2(0.68, 0.2) * R, 0.08 * R), deep)
			b.stroke(PackedVector2Array([Vector2(0.0, 1.0) * R, Vector2(0.0, 1.28) * R]), 0.1 * R, deep)
			_face_parts(b, 0.9 * R, Vector2(0.0, -0.04 * R), Pal.TEXT, eye)

## The folded paper, drawn over the body and under its sheen: the belly's
## shade, the candle's warmth once lit, two pleats bowing out from the cap to
## the base, and a lit edge along the cap's top.
func _folds(b: Builder, R: float, paper: Array, deep: Color, level: float) -> void:
	b.fan(Builder.round_rect(Vector2(-0.8, 0.26) * R, Vector2(1.6, 0.54) * R, 0.5 * R),
		Color(deep, 0.2 * (1.0 - 0.6 * level)))
	if level > 0.0:
		b.ellipse(Vector2(0.0, 0.08) * R, 0.5 * R, 0.56 * R, Color(Pal.LANTERN_LIT, 0.55 * level))
	for side in [-1.0, 1.0]:
		var pleat := Builder.bezier2(Vector2(0.3 * side, -0.82) * R,
			Vector2(0.62 * side, 0.0) * R, Vector2(0.3 * side, 0.82) * R, 10)
		pleat.append(Vector2(0.3 * side, 0.82) * R)
		b.stroke(pleat, 0.05 * R, Color(paper[1], 0.32))
	b.stroke(PackedVector2Array([Vector2(-0.32, -0.98) * R, Vector2(0.32, -0.98) * R]),
		0.05 * R, Color(1.0, 1.0, 1.0, 0.3))

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
