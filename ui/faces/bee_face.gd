extends "res://ui/faces/face.gd"

## The queen: a chibi bee wearing a small gold crown, the flat Queens' whole
## cast and the tenth screen's one new species. The bar for adding one is
## the snail's (ui/faces/snail_face.gd): nothing in the cast does what this
## needs. Nothing in it is a queen, and the bee is the one thing the board
## seats, so it earns the exception. She replaced a plain crown with a face
## on the evening of 2026-09-19, from the user's second mock
## (docs/art/concept-queens-bee.png), and is weighed number for number
## against the canvas mock (docs/brainstorm/concepts.html#queens, `bee`),
## whose measures are in s, the seat square's side: R = s / 2, so every
## number here is the mock's doubled.
##
## Two layers. The wings behind her, two pale ellipses rooted at her
## shoulder line, are shared by every bee of a size and never carry the
## face; they beat through `_layer_transform`, a squash toward the shoulder
## line by `flap`, so a beat rebuilds no mesh, the way the sun's rays turn
## (ui/faces/sun_face.gd). The body carries the face: a round yellow body,
## two dark stripes cut to its outline, thin antennae framing the crown, the
## crown in SUN over a SUN_DEEP foot sunk into the top of her head, and on
## the crown's middle point a leaf-green gem when `pinned` -- a queen a hint
## seated, the given look every board wears in green. HAPPY at rest, JOY on
## the win, STRAIN for a beat when the finger is refused on her.
##
## No shadow layer: the board draws the soft disc under her on its own
## ground, so a hopping bee leaves it behind (ui/faces/court_lantern.gd's
## `casts` false, always).
##
## Every measure is in R, and the drawing runs from the antennae's tips at
## -0.88 R to the body's foot at 0.80 R and out to the wing tips at 1.0 R,
## so a rect `px` square holds it with R = px / 2 (SEAT).
## Spec: docs/superpowers/specs/2026-09-19-queens-flat-design.md, section 5
## and the amendment of 2026-09-19 evening at its end.

## The rect a bee of radius R needs, in R.
const SEAT := 2.0
## The body: an ellipse, a little below the centre so the crown has room.
const BODY_AT := Vector2(0.0, 0.18)
const BODY_RX := 0.66
const BODY_RY := 0.62
## The two stripes, each [top, bottom] in R, cut to the body's outline.
const STRIPES := [[0.30, 0.47], [0.58, 0.74]]
## Points per stripe edge.
const STRIPE_STEPS := 7
## The wings: centre, tilt and radii of each, mirrored, and the shoulder
## line they beat about.
const WING_AT := Vector2(0.58, -0.24)
const WING_TILT := 0.6
const WING_RX := 0.47
const WING_RY := 0.28
const WING_ALPHA := 0.92
const WING_HI_AT := Vector2(-0.06, -0.05)
const WING_HI_RX := 0.26
const WING_HI_RY := 0.14
const WING_HI_ALPHA := 0.6
const SHOULDER_Y := -0.04
## The beat: the wings squash to FLAP_MIN of their height and back once a
## FLAP_PERIOD, on a sine.
const FLAP_MIN := 0.45
const FLAP_PERIOD := 0.11
## The antennae: from the head to a curled tip with a bead on it.
const ANTENNA_FROM := Vector2(0.20, -0.40)
const ANTENNA_CTRL := Vector2(0.28, -0.80)
const ANTENNA_TO := Vector2(0.52, -0.88)
const ANTENNA_WIDTH := 0.036
const ANTENNA_BEAD := 0.044
## The crown: its half width, the middle tip, the outer tips, the notch
## between them, its foot (sunk into the head) and the deeper rim's height.
const CROWN_HALF := 0.34
const CROWN_TOP := -0.88
const CROWN_TIP_Y := -0.80
const CROWN_NOTCH := Vector2(0.1156, -0.60)
const CROWN_FOOT := -0.38
const CROWN_RIM := 0.06
const CROWN_TIP_R := 0.05
## The pinned gem on the middle point, in R below CROWN_TOP.
const GEM_INSET := 0.14
const GEM_R := 0.064
## The face on the upper body.
const FACE_R := 0.48
const FACE_AT := Vector2(0.0, -0.02)

## A queen a hint seated, who can never be lifted again.
var pinned: bool = false:
	set(v):
		pinned = v
		queue_redraw()

## Where in the beat her wings are, in radians; `flap` is read off it. It
## starts at the top of the beat, wings open, which is also where
## reduce-motion leaves them.
var beat := PI * 0.5:
	set(v):
		beat = v
		queue_redraw()

func _kind() -> String:
	return "bee%d" % int(pinned)

func _radius_for(px: float) -> float:
	return px / SEAT

func _layers() -> Array:
	return [["wings", false], ["body", true]]

## How open the wings are, FLAP_MIN to 1, off the beat.
func flap() -> float:
	return lerpf(FLAP_MIN, 1.0, 0.5 + 0.5 * sin(beat))

## The wings squash toward the shoulder line by flap: y' = flap * y + root *
## (1 - flap), which is a scale about that line and not about the centre.
func _layer_transform(name: String, R: float, centre: Vector2) -> Transform2D:
	if name != "wings":
		return Transform2D(0.0, centre)
	var f := flap()
	var root := SHOULDER_Y * R
	return Transform2D(0.0, Vector2(1.0, f), 0.0, centre + Vector2(0.0, root * (1.0 - f)))

## One beat after another, from wherever the beat stands, so every bee on a
## board is on her own phase: the owner starts each at a random one.
func _idle_motion() -> Tween:
	var from := beat
	var tw := create_tween().set_loops()
	tw.tween_property(self, "beat", from + TAU, FLAP_PERIOD).from(from)
	return tw

func _build_layer(name: String, R: float, eye: float, b: Builder) -> void:
	if name == "wings":
		for sx: float in [-1.0, 1.0]:
			var xf := Transform2D(-sx * WING_TILT, Vector2(sx * WING_AT.x, WING_AT.y) * R)
			b.fan(xf * Builder.ring(Vector2.ZERO, WING_RX * R, WING_RY * R), Color(Pal.CLOUD_TILE, WING_ALPHA))
			b.fan(xf * Builder.ring(WING_HI_AT * R, WING_HI_RX * R, WING_HI_RY * R),
				Color(1.0, 1.0, 1.0, WING_HI_ALPHA))
		return
	var body: Color = Pal.SUN_RAY
	var dark: Color = Pal.PLAQUE_DEEP
	# The antennae first, so the head covers their roots.
	for sx: float in [-1.0, 1.0]:
		var p0 := Vector2(sx * ANTENNA_FROM.x, ANTENNA_FROM.y) * R
		var p1 := Vector2(sx * ANTENNA_TO.x, ANTENNA_TO.y) * R
		var pts := Builder.bezier2(p0, Vector2(sx * ANTENNA_CTRL.x, ANTENNA_CTRL.y) * R, p1)
		pts.append(p1)
		b.stroke(pts, ANTENNA_WIDTH * R, dark)
		b.disc(p1, ANTENNA_BEAD * R, dark)
	# The body, and the stripes cut to its outline.
	b.ellipse(BODY_AT * R, BODY_RX * R, BODY_RY * R, body)
	for band in STRIPES:
		b.fan(_band(R, float(band[0]), float(band[1])), dark)
	# The crown: its deeper foot first, the body over it short of the rim,
	# a disc on each tip so the points are rounded rather than sharp.
	b.polygon(_crown(R, CROWN_FOOT), Pal.SUN_DEEP)
	b.polygon(_crown(R, CROWN_FOOT - CROWN_RIM), Pal.SUN)
	for tip in [Vector2(-CROWN_HALF, CROWN_TIP_Y), Vector2(0.0, CROWN_TOP), Vector2(CROWN_HALF, CROWN_TIP_Y)]:
		b.disc(tip * R, CROWN_TIP_R * R, Pal.SUN)
	if pinned:
		var gem_at := Vector2(0.0, CROWN_TOP + GEM_INSET) * R
		b.disc(gem_at, GEM_R * R, Pal.LEAF_DEEP)
		b.disc(gem_at + Vector2(0.0, -0.01 * R), GEM_R * 0.78 * R, Pal.LEAF)
	_face_parts(b, FACE_R * R, FACE_AT * R, Pal.TEXT, eye)

## The crown's outline down to foot `foot`: shoulders, the two outer tips,
## the notches and the middle tip, one concave polygon.
static func _crown(R: float, foot: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-CROWN_HALF, foot) * R,
		Vector2(-CROWN_HALF, CROWN_TIP_Y) * R,
		Vector2(-CROWN_NOTCH.x, CROWN_NOTCH.y) * R,
		Vector2(0.0, CROWN_TOP) * R,
		Vector2(CROWN_NOTCH.x, CROWN_NOTCH.y) * R,
		Vector2(CROWN_HALF, CROWN_TIP_Y) * R,
		Vector2(CROWN_HALF, foot) * R,
	])

## A horizontal band of the body's ellipse between `y0` and `y1` (in R), as
## one convex outline: the stripes never spill past the body and nothing is
## clipped.
static func _band(R: float, y0: float, y1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in STRIPE_STEPS + 1:
		var y := lerpf(y0, y1, float(i) / STRIPE_STEPS)
		pts.append(Vector2(_body_x(y), y) * R)
	for i in range(STRIPE_STEPS, -1, -1):
		var y := lerpf(y0, y1, float(i) / STRIPE_STEPS)
		pts.append(Vector2(-_body_x(y), y) * R)
	return pts

## The body outline's half width at height `y`, in R.
static func _body_x(y: float) -> float:
	var u := (y - BODY_AT.y) / BODY_RY
	return BODY_RX * sqrt(maxf(0.0, 1.0 - u * u))
