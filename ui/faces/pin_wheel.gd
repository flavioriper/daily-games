extends RefCounted

## A paper pinwheel, as builder shapes rather than as a Control: the pin a
## Pinwheel piece is held down through, and the board's only tap target. It is
## a drawing and not a character -- there is no face on it -- so it is static
## and batched the way `ui/faces/mosaic_tile.gd`'s tiles and
## `ui/faces/patch_cloth.gd`'s patches are: up to thirteen of them go into one
## mesh, and a Control per pin would be a node per pin of a thing with nothing
## to blink.
##
## The wheel takes its turn as an angle rather than as a tween, so it reads
## `Motion.turn_angle` off the board's clock like everything else drawn on
## these screens (docs/art/flat-motion.md, rule 8) -- and the hub reads it with
## a longer `time`, so the blades carry the overshoot the cloth does not.
##
## Ported number for number from the canvas mock
## (docs/brainstorm/concepts.html#pinwheel: `pinwheelHub`), so the game and the
## mock stay the same drawing. Every measure is a fraction of the wheel's
## radius `r`, so one pinwheel is every pinwheel at another size.
## Spec: docs/superpowers/specs/2026-09-20-pinwheel-flat-design.md, section 7.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## One vane, in radii: out along a quadratic to the tip and back along a
## shallower one, both bowed the same way round. The sweep is the whole of the
## drawing -- four vanes bowed *apart* would be a flower, and a flower does not
## point anywhere.
const TIP := Vector2(0.82, 0.64)
const OUT_C := Vector2(0.98, -0.30)
const BACK_C := Vector2(0.38, 0.32)
const VANES := 4
const CURVE_STEPS := 10

## The outline: `LINE` rather than `TEXT`, at three quarters, so white on
## butter still reads without a pinwheel becoming the loudest thing on a cell.
const LINE_W := 0.075
const LINE_ALPHA := 0.75

## The hub over the middle: a brass pin head with a darker rim and a glint
## that turns with the wheel. Since the polish of 2026-09-26 the hub is brass
## on every wheel and the piece's own cloth rides on the vanes instead, which
## says whose handle it is at four times the area.
const HUB_R := 0.26
const HUB_RIM := 0.06
const GLINT_AT := Vector2(-0.08, -0.09)
const GLINT_R := 0.09
const GLINT_ALPHA := 0.7
const BRASS := Color("dcb562")
const BRASS_DEEP := Color("a47c35")

## Each vane is a sheet of paper folded once: the sliver between the vane's
## chord and its back curve is the fold's shadow, `FOLD` toward the ink, and
## the chord itself a crease in light.
const FOLD := 0.2
const CREASE_W := 0.035
const CREASE_ALPHA := 0.5

## A pin that cannot turn: a brass push-pin, no vanes at all. **A pinwheel
## that does not turn is a lie**, and drawing the difference is cheaper than
## explaining it in the tip card after the tap.
const TACK_R := 0.52
const TACK_TOP := 0.36
const TACK_TOP_AT := Vector2(-0.06, -0.08)

## The shadow: the family's soft disc, a shade below and right of the wheel and
## a hair wider than it, at the dressing rules' `TEXT` alpha.
const SHADOW_AT := Vector2(0.06, 0.12)
const SHADOW_R := 1.02
const SHADOW_ALPHA := 0.16

## One vane's closed outline, turned `angle` about `at`.
static func _vane(at: Vector2, r: float, angle: float) -> PackedVector2Array:
	var tip := TIP * r
	var pts := Face.Builder.bezier2(Vector2.ZERO, OUT_C * r, tip, CURVE_STEPS)
	pts.append_array(Face.Builder.bezier2(tip, BACK_C * r, Vector2.ZERO, CURVE_STEPS))
	return Transform2D(angle, at) * pts

## The fold's shadow on one vane: the back curve closed by the chord.
static func _fold(at: Vector2, r: float, angle: float) -> PackedVector2Array:
	return Transform2D(angle, at) * Face.Builder.bezier2(TIP * r, BACK_C * r, Vector2.ZERO, CURVE_STEPS)

## The wheel, centred on `at`, `r` to the tip of a vane, turned `angle`
## clockwise. The vanes alternate `face` (the paper) and `alt` -- the piece's
## own cloth, so a pinwheel says which piece it turns without a line drawn to
## it -- and `ink` is the outline round them. `hub` is the pin's head.
static func wheel(b, at: Vector2, r: float, angle: float, ink: Color, face: Color,
		hub: Color = BRASS, alt := Color(0, 0, 0, 0)) -> void:
	if r <= 0.0:
		return
	var other := alt if alt.a > 0.0 else face.lerp(ink, 0.16)
	var edge := Color(ink, ink.a * LINE_ALPHA)
	var crease := Color(1.0, 1.0, 1.0, CREASE_ALPHA)
	for k in VANES:
		var a := angle + float(k + 1) * PI * 0.5
		var paper := other if k % 2 else face
		var pts := _vane(at, r, a)
		b.polygon(pts, paper)
		b.polygon(_fold(at, r, a), paper.lerp(ink, FOLD))
		b.stroke(PackedVector2Array([at, Transform2D(a, at) * (TIP * r)]),
			r * CREASE_W, crease)
		b.stroke(pts, r * LINE_W, edge, true)
	b.disc(at, r * HUB_R, hub.lerp(ink, 0.35))
	b.disc(at, r * (HUB_R - HUB_RIM), hub)
	b.disc(at + (GLINT_AT * r).rotated(angle), r * GLINT_R,
		Color(1.0, 1.0, 1.0, GLINT_ALPHA))

## The pin of a piece that is pinned fast: a brass push-pin, no vanes, so
## "nothing to turn" is readable before the tap and not only after it.
static func pin(b, at: Vector2, r: float, ink: Color, _face: Color = BRASS) -> void:
	if r <= 0.0:
		return
	b.disc(at, r * TACK_R, BRASS_DEEP)
	b.stroke(Face.Builder.ring(at, r * TACK_R, r * TACK_R), r * LINE_W,
		Color(ink, ink.a * LINE_ALPHA), true)
	b.disc(at + TACK_TOP_AT * r, r * TACK_TOP, BRASS)
	b.disc(at + (TACK_TOP_AT + GLINT_AT * 1.4) * r, r * GLINT_R * 1.2,
		Color(1.0, 1.0, 1.0, GLINT_ALPHA))

## The wheel's own shadow on whatever it stands over: the family's soft disc
## (`ui/flat/scenery.gd`), never a second one of this file's own.
static func shadow(b, at: Vector2, r: float, ink: Color) -> void:
	if r <= 0.0:
		return
	Scenery.soft_disc(b, at + SHADOW_AT * r, r * SHADOW_R, r * SHADOW_R,
		Color(ink, SHADOW_ALPHA))
