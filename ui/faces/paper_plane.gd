extends RefCounted

## A paper plane as builder shapes rather than as a Control: the one drawing
## Paper Planes' board and its menu card both make, so the two cannot drift
## apart. A plane has no face on it and a hard board carries fifty-odd of them,
## so they are batched into a mesh the way `ui/faces/patch_cloth.gd`'s patches
## are.
##
## **Two parts, and only the dart carries a colour.** The body is a groove
## pressed into the paper -- a tan rim, a paper fill a shade under the field,
## and a stitched line down its middle -- with every bend rounded, because a
## trail that turns on a sharp corner reads as a wire and one that curves reads
## as the path a plane took. The dart at the head is folded paper in one of
## three colours, one half lit and one in shade off a light standing up and to
## the left of the board, with a pale fold down the spine and a soft shadow
## under it that drops away as the plane lifts. **The colour is identity and
## never state**: nothing a plane can be in changes it (Quilt's and Pinwheel's
## rule, for pieces coloured by index).
## Spec: docs/superpowers/specs/2026-09-20-paper-planes-flat-design.md,
## section 17's polish amendment.

const Pal = preload("res://core/palette.gd")
const Face = preload("res://ui/faces/face.gd")

# --- the groove, every figure a fraction of the cell ---
const WIDTH := 0.3
const RIM := 0.045
## How round a bend is. A quarter of the way to the next cell leaves the groove's
## inner edge a real curve at WIDTH 0.3 rather than a pinched corner.
const BEND := 0.36
const DROP := 0.035
const STITCH_W := 0.034
const STITCH_ON := 0.11
const STITCH_OFF := 0.085

# --- the dart ---
const TIP := 0.5
const BACK := 0.32
const WING := 0.39
const NOTCH := 0.14
## The shadow's offset at rest, down and to the right of the light, and how
## much further it falls per unit of lift.
const SHADOW := Vector2(0.05, 0.085)
const SHADOW_FALL := 2.6
const SHADOW_ALPHA := 0.2
## Where the light stands, for which half of a dart is lit.
const LIGHT := Vector2(-0.6, -0.8)

static func paper(i: int) -> Color:
	match posmod(i, 3):
		0: return Pal.SUN.lerp(Pal.PUMPKIN, 0.25)
		1: return Pal.BERRY.lerp(Pal.CHEEK, 0.3)
		_: return Pal.WATER.lerp(Pal.CLOUD_DEEP, 0.3)

static func lit(i: int) -> Color:
	return paper(i).lerp(Pal.SURFACE, 0.3)

static func shade(i: int) -> Color:
	return paper(i).lerp(Pal.TEXT, 0.12)

## The stitch down a groove takes a little of its dart's colour, so a trail
## can be followed back to the plane it belongs to on a crowded board.
static func thread(i: int) -> Color:
	return Pal.ACORN_DEEP.lerp(paper(i), 0.18)

## The groove's own colours: its rim and the paper pressed into it.
static func rim_colour() -> Color:
	return Pal.STONE_GIVEN.lerp(Pal.ACORN, 0.28)

static func fill_colour() -> Color:
	return Pal.STONE.lerp(Pal.SURFACE, 0.2)

## A plane's body along `pts` (cell centres, or a slice of its flight):
## shadow, rim, fill and stitch. `phase` slides the stitch along the groove in
## pixels, so it travels with a body that is moving.
static func trail(b, pts: PackedVector2Array, cell: float, i: int, alpha := 1.0,
		phase := 0.0) -> void:
	if pts.size() < 2:
		return
	var path := fillet(pts, BEND * cell)
	var w := WIDTH * cell
	b.stroke(_moved(path, Vector2(0.0, DROP * cell)), w + 1.0,
		Color(Pal.ACORN_DEEP, 0.2 * alpha))
	b.stroke(path, w, Color(rim_colour(), alpha))
	b.stroke(path, w - 2.0 * RIM * cell, Color(fill_colour(), alpha))
	dashes(b, path, STITCH_W * cell, STITCH_ON * cell, STITCH_OFF * cell, phase,
		Color(thread(i), 0.85 * alpha), w * 0.35)

## A glow or a band along the same rounded path a groove takes.
static func band(b, pts: PackedVector2Array, cell: float, width: float, colour: Color) -> void:
	if pts.size() == 1:
		b.disc(pts[0], width * 0.5, colour)
	elif pts.size() > 1:
		b.stroke(fillet(pts, BEND * cell), width, colour)

## The folded dart at `head`, turned to `angle`. `wings` scales it along (x)
## and across (y) -- the wake's beat opens the wings -- and `lift` raises it
## off the paper: bigger, and its shadow further away and fainter.
static func dart(b, head: Vector2, angle: float, cell: float, i: int, alpha := 1.0,
		wings := Vector2.ONE, lift := 0.0) -> void:
	var s := wings * cell * (1.0 + 0.16 * lift)
	var turn := Transform2D(angle, head)
	var tip := turn * (Vector2(TIP, 0.0) * s)
	var right := turn * (Vector2(-BACK, WING) * s)
	var notch := turn * (Vector2(-NOTCH, 0.0) * s)
	var left := turn * (Vector2(-BACK, -WING) * s)
	var fall := SHADOW * cell * (1.0 + SHADOW_FALL * lift)
	b.polygon(_moved(PackedVector2Array([tip, right, notch, left]), fall),
		Color(Pal.TEXT, SHADOW_ALPHA * alpha * (1.0 - 0.45 * lift)))
	# Which half faces the light: the wing whose outward side points more
	# toward it. Only four headings exist, so every plane is one of two cases.
	var left_out := turn.basis_xform(Vector2(0.0, -1.0))
	var left_lit := left_out.dot(LIGHT) >= 0.0
	b.polygon(PackedVector2Array([tip, notch, left]),
		Color(lit(i) if left_lit else shade(i), alpha))
	b.polygon(PackedVector2Array([tip, right, notch]),
		Color(shade(i) if left_lit else lit(i), alpha))
	# The keel showing through the notch, and the fold down the spine.
	var keel := turn * (Vector2(-NOTCH + 0.02, 0.0) * s)
	b.polygon(PackedVector2Array([notch.lerp(tip, 0.28),
		keel + turn.basis_xform(Vector2(0.0, 0.035)) * s.y,
		keel + turn.basis_xform(Vector2(0.0, -0.035)) * s.y]),
		Color(paper(i).lerp(Pal.TEXT, 0.3), alpha))
	b.stroke(PackedVector2Array([tip.lerp(notch, 0.08), tip.lerp(notch, 0.8)]),
		maxf(1.2, 0.028 * cell), Color(Pal.SURFACE, 0.75 * alpha), false, false)

## A leaf sprig lying on the paper at `at`, `r` across, turned `angle`, with a
## small white flower on some of them.
static func sprig(b, at: Vector2, r: float, angle: float, flower: bool, alpha := 1.0) -> void:
	for k in 2:
		var a := angle + (0.0 if k == 0 else 0.95)
		var len := r * (1.0 if k == 0 else 0.78)
		var dir := Vector2.from_angle(a)
		var side := Vector2(-dir.y, dir.x) * len * 0.42
		var tip := at + dir * len
		var mid := at + dir * len * 0.5
		var green: Color = Pal.MOSS if k == 0 else Pal.LEAF_DEEP.lerp(Pal.MOSS, 0.4)
		b.polygon(Face.Builder.bezier2(at, mid + side, tip, 6)
			+ Face.Builder.bezier2(tip, mid - side, at, 6), Color(green, alpha))
		b.stroke(PackedVector2Array([at.lerp(tip, 0.12), at.lerp(tip, 0.78)]),
			maxf(1.0, r * 0.06), Color(Pal.LEAF_TILE, 0.5 * alpha), false, false)
	if flower:
		var p := at + Vector2.from_angle(angle + 0.45) * r * 0.62
		var pr := r * 0.3
		for k in 5:
			b.disc(p + Vector2.from_angle(TAU * k / 5.0 + angle) * pr * 0.62, pr * 0.52,
				Color(Pal.SURFACE, alpha))
		b.disc(p, pr * 0.34, Color(Pal.SUN_RAY, alpha))

## Every interior corner of `pts` replaced by a curve of radius up to `r`. An
## end segment may give its whole length to the curve and an inner one half,
## so a tail sliding round a bend in flight takes the curve with it rather than
## cutting across.
static func fillet(pts: PackedVector2Array, r: float) -> PackedVector2Array:
	var clean := PackedVector2Array()
	for p in pts:
		if clean.is_empty() or clean[clean.size() - 1].distance_squared_to(p) > 0.01:
			clean.append(p)
	var n := clean.size()
	if n < 3:
		return clean
	var out := PackedVector2Array([clean[0]])
	for k in range(1, n - 1):
		var a := clean[k - 1]
		var p := clean[k]
		var c := clean[k + 1]
		var l0 := a.distance_to(p)
		var l1 := p.distance_to(c)
		var u0 := (p - a) / l0
		var u1 := (c - p) / l1
		if absf(u0.cross(u1)) < 0.01:
			out.append(p)
			continue
		var rr := minf(r, minf(l0 if k == 1 else l0 * 0.5, l1 if k == n - 2 else l1 * 0.5))
		out.append_array(Face.Builder.bezier2(p - u0 * rr, p, p + u1 * rr, 7))
		out.append(p + u1 * rr)
	out.append(clean[n - 1])
	return out

## Dashes of `on` every `on + off` along `path`, starting `phase` in, kept
## `margin` clear of both ends so none runs out over a rounded cap.
static func dashes(b, path: PackedVector2Array, width: float, on: float, off: float,
		phase: float, colour: Color, margin := 0.0) -> void:
	var cum := PackedFloat32Array([0.0])
	for k in range(1, path.size()):
		cum.append(cum[k - 1] + path[k - 1].distance_to(path[k]))
	var total := cum[cum.size() - 1]
	var period := on + off
	var x := -fposmod(phase, period)
	while x < total - margin:
		var x0 := maxf(x, margin)
		var x1 := minf(x + on, total - margin)
		if x1 - x0 > width * 0.5:
			b.stroke(sub(path, cum, x0, x1), width, colour, false, false)
		x += period

## The piece of `path` between the distances `x0` and `x1` along it, `cum`
## being its cumulative lengths.
static func sub(path: PackedVector2Array, cum: PackedFloat32Array, x0: float,
		x1: float) -> PackedVector2Array:
	var out := PackedVector2Array([_at(path, cum, x0)])
	for k in range(1, path.size() - 1):
		if cum[k] > x0 and cum[k] < x1:
			out.append(path[k])
	out.append(_at(path, cum, x1))
	return out

static func _at(path: PackedVector2Array, cum: PackedFloat32Array, x: float) -> Vector2:
	for k in range(1, path.size()):
		if x <= cum[k] or k == path.size() - 1:
			var span := maxf(cum[k] - cum[k - 1], 0.0001)
			return path[k - 1].lerp(path[k], clampf((x - cum[k - 1]) / span, 0.0, 1.0))
	return path[0]

static func _moved(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := pts.duplicate()
	for k in out.size():
		out[k] += by
	return out
