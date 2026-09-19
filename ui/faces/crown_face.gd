extends "res://ui/faces/face.gd"

## The queen: a gold crown with a face on its band, the flat Queens' whole
## cast and the tenth screen's one new species. The bar for adding one is
## the snail's (ui/faces/snail_face.gd): nothing in the cast does what this
## needs. Nothing in it is a queen, and the crown is the one thing the board
## seats, so it earns the exception.
##
## Three points over a band, the middle one taller, a deeper edge along the
## band's foot and a highlight on its shoulder; a small deep gem on each
## outer point, and on the middle point a leaf-green gem when `pinned` -- a
## queen a hint seated, the given look every board wears in green. HAPPY at
## rest, JOY on the win, STRAIN for a beat when the finger is refused on her.
## One layer, one cached mesh per state, shared by every crown on the board.
## No shadow layer: the board draws the soft disc under her on its own
## ground, so a hopping crown leaves it behind (ui/faces/court_lantern.gd's
## `casts` false, always).
##
## Every measure is in R, and the drawing is 1.6 R wide and runs from the
## middle tip at -0.92 R to the band's foot at 0.56 R, so a rect `px` square
## holds it with R = px / 2 (SEAT). Weighed number for number against the
## canvas mock (docs/brainstorm/concepts.html#queens, `crown`) and against
## the crown drawn on docs/art/concept-queens.png's Check button: the mock's
## own body is a single unrounded outline whose "points" are only the
## trapezoid's own top corners, softened with a disc, which reads flatter
## than the three-point crown both the mock's neighbouring PNG and the
## approved concept actually draw; this file keeps the separate lean-in tips
## the PNG shows and takes the mock's overall width, height and band/rim
## proportions, which agree with it once converted from its `s` (a full
## SEAT-square side, so R = s / 2) into R.
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 5.

## The rect a crown of radius R needs, in R.
const SEAT := 2.0
const BAND_TOP := -0.05
const BAND_BOTTOM := 0.56
const BAND_HALF := 0.8
const BAND_RADIUS := 0.16
## The deeper edge along the band's foot.
const EDGE := 0.1
## The three points: the outer tips and the taller middle one.
const TIP_X := 0.6
const TIP_Y := -0.68
const MID_Y := -0.92
const TIP_R := 0.12
## Where the points meet between the tips, in R.
const NOTCH := Vector2(0.3, -0.2)
const GEM_R := 0.11
## The pinned gem sits a little below the middle tip's own point, inset the
## way the mock's does, so the tip's rounding disc still frames it.
const GEM_MID_INSET := 0.2
const HI_AT := Vector2(-0.6, -0.05)
const HI_SIZE := Vector2(0.28, 0.09)
const HI_RADIUS := 0.05
const HI_ALPHA := 0.28
## The face sits on the band, a little below its middle, at this R.
const FACE_R := 0.45
const FACE_AT := Vector2(0.0, 0.2)

## A queen a hint seated, who can never be lifted again.
var pinned: bool = false:
	set(v):
		pinned = v
		queue_redraw()

func _kind() -> String:
	return "crown%d" % int(pinned)

func _radius_for(px: float) -> float:
	return px / SEAT

func _layers() -> Array:
	return [["body", true]]

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	if name != "body":
		return
	var body: Color = Pal.SUN
	var deep: Color = Pal.SUN_DEEP
	# The points, one concave outline from shoulder to shoulder, with a disc
	# on each tip so the points are rounded rather than sharp.
	var points := PackedVector2Array([
		Vector2(-BAND_HALF, BAND_TOP + 0.2) * R,
		Vector2(-TIP_X, TIP_Y) * R,
		Vector2(-NOTCH.x, NOTCH.y) * R,
		Vector2(0.0, MID_Y) * R,
		Vector2(NOTCH.x, NOTCH.y) * R,
		Vector2(TIP_X, TIP_Y) * R,
		Vector2(BAND_HALF, BAND_TOP + 0.2) * R,
	])
	b.polygon(points, body)
	for tip in [Vector2(-TIP_X, TIP_Y), Vector2(0.0, MID_Y), Vector2(TIP_X, TIP_Y)]:
		b.disc(tip * R, TIP_R * R, body)
	# The band: its deeper foot first, the body over it short of the edge.
	var band_at := Vector2(-BAND_HALF, BAND_TOP) * R
	var band := Vector2(2.0 * BAND_HALF, BAND_BOTTOM - BAND_TOP) * R
	b.fan(Builder.round_rect(band_at, band, BAND_RADIUS * R), deep)
	b.fan(Builder.round_rect(band_at, band - Vector2(0.0, EDGE * R), BAND_RADIUS * R), body)
	b.fan(Builder.round_rect(HI_AT * R, HI_SIZE * R, HI_RADIUS * R), Color(1.0, 1.0, 1.0, HI_ALPHA))
	# The gems: deep on the outer points, and the given's leaf on the middle.
	b.disc(Vector2(-TIP_X, TIP_Y) * R, GEM_R * 0.55 * R, Color(deep, 0.8))
	b.disc(Vector2(TIP_X, TIP_Y) * R, GEM_R * 0.55 * R, Color(deep, 0.8))
	if pinned:
		var gem_at := Vector2(0.0, MID_Y + GEM_MID_INSET) * R
		b.disc(gem_at, GEM_R * R, Pal.LEAF_DEEP)
		b.disc(gem_at + Vector2(0.0, -0.02 * R), GEM_R * 0.72 * R, Pal.LEAF)
	_face_parts(b, FACE_R * R, FACE_AT * R, Pal.TEXT, eye)
