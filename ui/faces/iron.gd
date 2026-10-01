extends RefCounted

## Pixel Garden's iron: a small mint household iron with a face, seen from
## above as it glides over a plate of beads. Builder shapes, not a Control:
## it rides the board's live mesh, turned to the way it is going, for the
## reason ui/faces/bead.gd gives.
##
## A teardrop body (round heel, pointed nose), the steel soleplate showing a
## rim round it, a cream handle along its top, and a face on the heel: happy
## (closed smiling eyes, a blush) or worried (round eyes, a small wavy
## mouth) when the plate under it was wrong.
## Spec: docs/superpowers/specs/2026-10-01-pixel-garden-polish-design.md.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

const BODY := Color("9fd8c9")
const BODY_DEEP := Color("6fb3a3")
const BODY_HI := Color("d4f0e8")
const SOLE := Color("d9dde3")
const SOLE_DEEP := Color("a9b0ba")
const HANDLE := Color("fff4dc")

enum Mood { HAPPY, WORRIED }

## The iron at `at`, `s` px from heel to nose, pointing along `angle`,
## raised `lift` px (its shade stays on the board). `glow` (0..1) lights
## the little lamp on its heel.
static func iron(b, at: Vector2, s: float, angle: float, mood := Mood.HAPPY, alpha := 1.0,
		lift := 0.0, glow := 0.0) -> void:
	if alpha <= 0.0 or s <= 0.0:
		return
	var xf := Transform2D(angle, at - Vector2(0.0, lift))
	Scenery.soft_disc(b, at + Vector2(s * 0.06, s * 0.1), s * 0.62, s * 0.42, Color(Pal.TEXT, 0.2 * alpha))
	# The cord, curling off the heel.
	var cord := Face.Builder.bezier3(Vector2(-0.46, 0.0), Vector2(-0.7, 0.05), Vector2(-0.72, -0.28), Vector2(-0.95, -0.22))
	for k in cord.size():
		cord[k] = xf * (cord[k] * s)
	b.stroke(cord, s * 0.05, Color(Pal.LINE, alpha))
	b.stroke(cord, s * 0.025, Color(HANDLE, alpha))
	b.polygon(_shape(xf, s * 1.06, Vector2(0.0, s * 0.05)), Color(SOLE_DEEP, alpha))
	b.polygon(_shape(xf, s * 1.03, Vector2.ZERO), Color(SOLE, alpha))
	b.polygon(_shape(xf, s * 0.94, Vector2(0.0, s * 0.03)), Color(BODY_DEEP, alpha))
	b.polygon(_shape(xf, s * 0.9, Vector2.ZERO), Color(BODY, alpha))
	# A lit sweep along the upper side.
	var hi := PackedVector2Array()
	for k in 9:
		var u := k / 8.0
		hi.append(xf * Vector2(lerpf(-0.3, 0.28, u) * s, (-0.2 + 0.08 * u * u) * s))
	b.stroke(hi, s * 0.07, Color(BODY_HI, 0.8 * alpha))
	# The handle: a cream bar along the middle, on two posts.
	var handle := PackedVector2Array()
	for p in [Vector2(-0.24, -0.07), Vector2(0.22, -0.07), Vector2(0.22, 0.07), Vector2(-0.24, 0.07)]:
		handle.append(xf * (p * s))
	b.polygon(_offset(handle, Vector2(0.0, s * 0.035)), Color(Pal.LINE, alpha))
	b.polygon(handle, Color(HANDLE, alpha))
	# The grip's gap, so the handle reads as a loop.
	var slot := PackedVector2Array()
	for p in [Vector2(-0.14, -0.025), Vector2(0.12, -0.025), Vector2(0.12, 0.025), Vector2(-0.14, 0.025)]:
		slot.append(xf * (p * s))
	b.polygon(slot, Color(BODY_DEEP, alpha))
	# The lamp on the heel, warm while it irons.
	var lamp := xf * Vector2(-0.36 * s, 0.0)
	b.disc(lamp, s * 0.055, Color(Pal.SUN.lerp(Color("f06a4a"), glow), alpha))
	if glow > 0.0:
		b.disc(lamp, s * 0.1, Color(Pal.SUN, 0.25 * glow * alpha))
	# The face, on the near flank so it is always upright to the player.
	var f := at - Vector2(0.0, lift) + Vector2(0.0, s * 0.16)
	var e := s * 0.11
	match mood:
		Mood.HAPPY:
			for sx in [-1.0, 1.0]:
				b.stroke(Face.Builder.arc_points(f + Vector2(sx * e, -e * 0.2), e * 0.42, PI * 1.15, PI * 1.85),
					s * 0.03, Color(Pal.OUTLINE, alpha))
				b.ellipse(f + Vector2(sx * e * 1.7, e * 0.45), e * 0.4, e * 0.24, Color(Pal.CHEEK, 0.8 * alpha))
			b.stroke(Face.Builder.arc_points(f + Vector2(0.0, e * 0.2), e * 0.4, PI * 0.15, PI * 0.85),
				s * 0.03, Color(Pal.OUTLINE, alpha))
		Mood.WORRIED:
			for sx in [-1.0, 1.0]:
				b.disc(f + Vector2(sx * e, -e * 0.15), e * 0.26, Color(Pal.OUTLINE, alpha))
				b.disc(f + Vector2(sx * e - e * 0.08, -e * 0.25), e * 0.08, Color(Color.WHITE, alpha))
				b.stroke(PackedVector2Array([f + Vector2(sx * e * 0.5, -e * 0.75), f + Vector2(sx * e * 1.4, -e * 0.95)]),
					s * 0.022, Color(Pal.OUTLINE, alpha))
			var w := PackedVector2Array()
			for k in 7:
				var u := k / 6.0
				w.append(f + Vector2(lerpf(-0.4, 0.4, u) * e, e * 0.55 + sin(u * TAU) * e * 0.1))
			b.stroke(w, s * 0.026, Color(Pal.OUTLINE, alpha))

## The body's outline, heel round and nose pointed, along +x, scaled to `s`.
static func _shape(xf: Transform2D, s: float, off: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	const STEPS := 28
	for i in STEPS + 1:
		var a := lerpf(PI * 0.5, PI * 1.5, float(i) / STEPS)
		# A squarish heel (a superellipse), the way an iron's back is flat.
		var cx := cos(a)
		var sy := sin(a)
		pts.append(Vector2(-0.12 + 0.36 * signf(cx) * pow(absf(cx), 0.4), 0.3 * signf(sy) * pow(absf(sy), 0.4)))
	for i in range(1, 12):
		var u := float(i) / 12.0
		# The flank sweeping to the nose and back.
		var y := -0.3 * (1.0 - u * u)
		pts.append(Vector2(-0.12 + u * 0.66, y))
	pts.append(Vector2(0.55, 0.0))
	for i in range(11, 0, -1):
		var u := float(i) / 12.0
		pts.append(Vector2(-0.12 + u * 0.66, 0.3 * (1.0 - u * u)))
	var out := PackedVector2Array()
	for p in pts:
		out.append(xf * (p * s) + off)
	return out

static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out
