extends RefCounted

## Birdsong's bird (puzzles/birdsong2d.gd, its tutorial and its menu card):
## one round little bird in the memory skill's blue (Pal.CAT[5]), a cream
## belly, a sun-orange beak, a tuft and a tail, perched with its feet on the
## origin and facing right (a transform with a negative x scale turns it).
## It earns a face because it is the mechanic: the one who sings the tune.
##
## Builder shapes, cached per size and pose, as drumbeat_parts.gd's are: a
## board lays it into its own mesh or draws it under a transform.
##
## `beak` 0 shut to 1 wide (cut to three steps), `mood` one of Mood, `wing`
## 0 folded to 1 raised (three steps).

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

enum Mood { REST, SING, JOY, PUZZLED, SLEEP }

const BODY := Color("6bb1d6")
const DEEP := Color("4a8fb8")
const HI := Color("a6d4ec")
const BELLY := Color("fff4e2")
const BELLY_DEEP := Color("f1dfc2")
const BEAK := Color("f5a623")
const BEAK_DEEP := Color("d98516")
const INK := Color("3b3028")
const LEG := Color("c98a4a")

static var _cache := {}

## The bird, `r` its body's radius.
static func bird(r: float, mood := Mood.REST, beak := 0.0, wing := 0.0) -> ArrayMesh:
	var bk := clampi(roundi(beak * 2.0), 0, 2)
	var wg := clampi(roundi(wing * 2.0), 0, 2)
	var key := "bird:%d:%d:%d:%d" % [roundi(r * 2.0), mood, bk, wg]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var c := Vector2(0.0, -r * 1.22)
	# the shadow on the branch, the feet
	b.ellipse(Vector2(0.0, r * 0.04), r * 0.7, r * 0.12, Color(INK, 0.18))
	for sx: float in [-0.22, 0.2]:
		var hip := c + Vector2(sx * r, r * 0.8)
		var foot := Vector2(sx * r * 1.1, 0.0)
		b.stroke(PackedVector2Array([hip, foot]), r * 0.07, LEG)
		b.stroke(PackedVector2Array([foot + Vector2(-r * 0.14, r * 0.01), foot + Vector2(r * 0.16, r * 0.01)]), r * 0.065, LEG)
	# the tail, behind, tipped up
	var tail := PackedVector2Array([c + Vector2(-r * 0.62, r * 0.18), c + Vector2(-r * 1.52, -r * 0.22),
		c + Vector2(-r * 1.6, r * 0.06), c + Vector2(-r * 0.7, r * 0.58)])
	b.polygon(tail, DEEP)
	b.stroke(PackedVector2Array([c + Vector2(-r * 0.8, r * 0.3), c + Vector2(-r * 1.42, r * 0.02)]), r * 0.05, Color(HI, 0.6))
	# the body, one round ball with its belly
	b.disc(c + Vector2(0.0, r * 0.05), r * 1.02, DEEP)
	b.disc(c, r, BODY)
	b.ellipse(c + Vector2(r * 0.22, r * 0.36), r * 0.66, r * 0.56, BELLY_DEEP)
	b.ellipse(c + Vector2(r * 0.2, r * 0.32), r * 0.6, r * 0.5, BELLY)
	b.ellipse(c + Vector2(-r * 0.3, -r * 0.56), r * 0.3, r * 0.16, Color(HI, 0.55))
	# the tuft
	for i in 3:
		var a := -PI * 0.5 - 0.5 + 0.32 * i
		var root := c + Vector2.from_angle(a) * r * 0.9
		b.stroke(PackedVector2Array([root, root + Vector2.from_angle(a - 0.35) * r * 0.32]), r * 0.1, DEEP)
	# the wing, folded down the side or raised
	var lift := [0.0, 0.55, 1.1][wg] as float
	var wc := c + Vector2(-r * 0.2, r * 0.12 - r * 0.3 * lift)
	var wing_pts := PackedVector2Array()
	for i in 17:
		var t := float(i) / 16.0 * TAU
		wing_pts.append(wc + Vector2(cos(t) * r * 0.5, sin(t) * r * 0.32).rotated(-0.35 - lift * 0.7))
	b.polygon(wing_pts, DEEP)
	b.stroke(PackedVector2Array([wc + Vector2(-r * 0.32, r * 0.05).rotated(-lift * 0.7), wc + Vector2(r * 0.2, r * 0.12).rotated(-lift * 0.7)]), r * 0.05, Color(HI, 0.5))
	# the cheek, the eye
	var eye := c + Vector2(r * 0.42, -r * 0.22)
	b.ellipse(eye + Vector2(r * 0.04, r * 0.26), r * 0.15, r * 0.09, Color(Pal.CHEEK, 0.85))
	match mood:
		Mood.SING, Mood.JOY:
			b.stroke(Face.Builder.arc_points(eye + Vector2(0.0, r * 0.06), r * 0.13, PI * 1.1, PI * 1.9), r * 0.075, INK)
		Mood.SLEEP:
			b.stroke(Face.Builder.arc_points(eye + Vector2(0.0, -r * 0.06), r * 0.12, PI * 0.15, PI * 0.85), r * 0.07, INK)
		_:
			b.ellipse(eye, r * 0.11, r * 0.13, INK)
			b.disc(eye + Vector2(-r * 0.035, -r * 0.045), r * 0.04, Color(1, 1, 1, 0.9))
			if mood == Mood.PUZZLED:
				b.stroke(PackedVector2Array([eye + Vector2(-r * 0.16, -r * 0.3), eye + Vector2(r * 0.14, -r * 0.24)]), r * 0.06, INK)
	# the beak, shut or open by its three steps
	var root := c + Vector2(r * 0.86, -r * 0.08)
	var gape := [0.0, 0.14, 0.3][bk] as float
	b.polygon(PackedVector2Array([root + Vector2(0.0, -r * 0.16), root + Vector2(r * 0.42, -r * 0.02 - gape * r * 0.5),
		root + Vector2(0.0, r * 0.02 - gape * r * 0.2)]), BEAK)
	b.polygon(PackedVector2Array([root + Vector2(0.0, r * 0.03 + gape * r * 0.2), root + Vector2(r * 0.34, r * 0.04 + gape * r * 0.6),
		root + Vector2(0.0, r * 0.15)]), BEAK_DEEP)
	if bk > 0:
		b.polygon(PackedVector2Array([root + Vector2(0.0, -r * 0.02), root + Vector2(r * 0.22, r * 0.01),
			root + Vector2(0.0, r * 0.06)]), Color(INK, 0.7))
	var m := b.mesh()
	_cache[key] = m
	return m

## A sung note, a little quaver at `s` its head's radius, centred on the
## origin, in `col`.
static func quaver(s: float, col: Color) -> ArrayMesh:
	var key := "quaver:%d:%s" % [roundi(s * 4.0), col.to_html()]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var head := Vector2(-s * 0.3, s * 0.7)
	b.ellipse(head, s, s * 0.78, col)
	var top := head + Vector2(s * 0.86, -s * 2.6)
	b.stroke(PackedVector2Array([head + Vector2(s * 0.86, -s * 0.1), top]), s * 0.26, col)
	b.stroke(Face.Builder.bezier2(top, top + Vector2(s * 0.9, s * 0.5), top + Vector2(s * 0.8, s * 1.5)), s * 0.24, col)
	var m := b.mesh()
	_cache[key] = m
	return m
