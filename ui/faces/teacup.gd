extends RefCounted

## Teacups' cup and saucer (puzzles/teacups2d.gd, its tutorial and its menu
## card), and the ten friends that hide under the cups. The cup is white
## porcelain with a gold rim and a band in the memory skill's blue, drawn
## upside down -- its mouth on the saucer, its foot ring up, its handle on the
## right -- with its origin at the middle of the mouth, so a lift is a
## transform. The saucer is drawn about the same origin. Builder shapes,
## cached per size, as woodpecker.gd's are.
##
## Every cup is the same cup: the friend under it is what tells two apart,
## and a friend is one of the house's own faces (berry_face.gd and the
## rest), never a new drawing. A found pair loses its cups; nothing is ever
## signalled by a shade of a friend's colour.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")

## The friends, by kind: Code Break's and Balance's casts and Binairo's sun
## and moon, each a different silhouette and colour.
const FRIENDS := [
	"res://ui/faces/berry_face.gd",
	"res://ui/faces/pear_face.gd",
	"res://ui/faces/pumpkin_face.gd",
	"res://ui/faces/acorn_face.gd",
	"res://ui/faces/mushroom_face.gd",
	"res://ui/faces/moon_face.gd",
	"res://ui/faces/sun_face.gd",
	"res://ui/faces/cloud_face.gd",
	"res://ui/faces/flower_face.gd",
	"res://ui/faces/leaf_face.gd",
]

const CHINA := Color("fffaf2")
const CHINA_SHADE := Color("e9dfcf")
const CHINA_DEEP := Color("d3c6b2")
const BAND := Color("6bb1d6")
const BAND_DEEP := Color("4a8fb8")
const GOLD := Color("e2b85c")
const GOLD_DEEP := Color("bf9440")
const INK := Color("3b3028")

## The cup's measures in its mouth's half width `r`: the foot ring's half
## width and height, and the cup's height to the top of the foot.
const FOOT := 0.4
const FOOT_H := 0.14
const HIGH := 1.02

static var _cache := {}

## A friend's face node for kind `k`, not in any tree; the owner sizes it
## and draws `layers_now()` under its own transform.
static func friend(k: int) -> Control:
	var f: Control = load(FRIENDS[k % FRIENDS.size()]).new()
	f.shadowless = true
	return f

## The cup upside down, `r` its mouth's half width, its own soft shadow on
## the saucer under it.
static func cup(r: float) -> ArrayMesh:
	var key := "cup:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var top := -r * HIGH
	var foot := r * FOOT
	var crown := top + r * FOOT_H
	# the handle first, under the body: a loop on the right, hanging the
	# wrong way up as an upturned cup's does
	var loop := Face.Builder.arc_points(Vector2(r * 0.9, -r * 0.4), r * 0.3, -PI * 0.5, PI * 0.55)
	b.stroke(loop, r * 0.15, CHINA_DEEP, false, true)
	b.stroke(loop, r * 0.09, CHINA, false, true)
	# the bowl turned over: a dome from the wide mouth to the crown
	var body := _dome(r, crown, foot)
	b.polygon(body, CHINA_SHADE)
	var lit := PackedVector2Array()
	for p in body:
		lit.append(Vector2(p.x * 0.88 - r * 0.08, p.y * 0.97))
	b.polygon(lit, CHINA)
	# the band low on the dome, by the mouth, and three cream dots on it
	var y0 := -r * 0.16
	var y1 := -r * 0.4
	var w0 := _half_at(r, crown, foot, y0)
	var w1 := _half_at(r, crown, foot, y1)
	var band := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		band.append(Vector2(lerpf(-w0, w0, t), y0 + sin(t * PI) * r * 0.1))
	for i in 13:
		var t := float(i) / 12.0
		band.append(Vector2(lerpf(w1, -w1, t), y1 + sin(t * PI) * r * 0.09))
	b.polygon(band, BAND)
	b.stroke(PackedVector2Array([Vector2(w0 * 0.5, y0 + r * 0.07), Vector2(w0 * 0.97, y0 + r * 0.01)]), r * 0.05, Color(BAND_DEEP, 0.8))
	for dx: float in [-0.5, 0.0, 0.5]:
		b.disc(Vector2(dx * r * 0.92, (y0 + y1) * 0.5 + r * 0.09 * (1.0 - absf(dx))), r * 0.055, CHINA)
	# the foot ring standing on the crown: a short drum with a hollow top
	var fr := PackedVector2Array([Vector2(-foot, crown + r * 0.02), Vector2(-foot * 0.96, top + r * 0.02),
		Vector2(foot * 0.96, top + r * 0.02), Vector2(foot, crown + r * 0.02)])
	b.polygon(fr, CHINA_SHADE)
	b.ellipse(Vector2(0.0, top), foot * 0.96, r * 0.09, CHINA_DEEP)
	b.ellipse(Vector2(0.0, top + r * 0.01), foot * 0.78, r * 0.06, CHINA_SHADE)
	b.stroke(Face.Builder.arc_points(Vector2(0.0, crown + r * 0.02), foot, PI * 0.1, PI * 0.9), r * 0.04, GOLD)
	# the gold rim along the mouth
	var rim := PackedVector2Array()
	for i in 13:
		var t := float(i) / 12.0
		rim.append(Vector2(lerpf(-r * 0.98, r * 0.98, t), sin((1.0 - t) * PI) * r * 0.15 - r * 0.02))
	b.stroke(rim, r * 0.07, GOLD)
	# the gloss on the dome's left shoulder
	b.stroke(Face.Builder.arc_points(Vector2(0.0, -r * 0.05), r * 0.72, PI * 1.12, PI * 1.36), r * 0.09, Color(1.0, 1.0, 1.0, 0.8))
	var m := b.mesh()
	_cache[key] = m
	return m

## The upturned bowl's outline: the mouth's curve on the saucer and the dome
## over it, closing on the foot ring at `crown`.
static func _dome(r: float, crown: float, foot: float) -> PackedVector2Array:
	var body := PackedVector2Array()
	body.append_array(Face.Builder.bezier3(Vector2(-r, 0.0), Vector2(-r * 1.04, -r * 0.5),
		Vector2(-r * 0.78, crown), Vector2(-foot * 1.05, crown)))
	body.append_array(Face.Builder.bezier3(Vector2(foot * 1.05, crown), Vector2(r * 0.78, crown),
		Vector2(r * 1.04, -r * 0.5), Vector2(r, 0.0)))
	for i in range(1, 12):
		var t := float(i) / 12.0
		body.append(Vector2(lerpf(r, -r, t), sin(t * PI) * r * 0.16))
	return body

## The dome's half width at height `y` (negative, up from the mouth).
static func _half_at(r: float, crown: float, foot: float, y: float) -> float:
	var t := clampf(y / crown, 0.0, 1.0)
	return lerpf(r * 1.01, foot * 1.05, t * t * t * 0.7 + t * t * 0.3)

## The cup's shadow on its saucer, drawn separately so a lifted cup's can
## shrink and fade as it rises.
static func shadow(r: float) -> ArrayMesh:
	var key := "shadow:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.ellipse(Vector2(r * 0.06, r * 0.06), r * 1.04, r * 0.24, Color(INK, 0.16))
	var m := b.mesh()
	_cache[key] = m
	return m

## The saucer, `r` the cup's mouth's half width: a wide rim with a gold
## line, a shallow well, its shadow on the cloth.
static func saucer(b: Face.Builder, at: Vector2, r: float) -> void:
	var w := r * 1.5
	var h := r * 0.42
	b.ellipse(at + Vector2(r * 0.08, h * 0.32), w * 1.02, h * 1.02, Color(INK, 0.12))
	b.ellipse(at + Vector2(0.0, h * 0.14), w, h, CHINA_DEEP)
	b.ellipse(at, w, h, CHINA)
	b.stroke(Face.Builder.ring(at, w * 0.9, h * 0.86), r * 0.035, Color(GOLD, 0.9), true)
	b.ellipse(at + Vector2(0.0, h * 0.06), w * 0.66, h * 0.6, CHINA_SHADE)
	b.ellipse(at + Vector2(0.0, h * 0.1), w * 0.6, h * 0.5, CHINA)

## The saucer as its own mesh, for the card and the tutorial.
static func saucer_mesh(r: float) -> ArrayMesh:
	var key := "saucer:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	saucer(b, Vector2.ZERO, r)
	var m := b.mesh()
	_cache[key] = m
	return m

## A found pair's mark on a saucer: a ring of gold round the friend.
static func found_ring(r: float) -> ArrayMesh:
	var key := "found:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.stroke(Face.Builder.ring(Vector2.ZERO, r * 1.28, r * 0.36), r * 0.07, GOLD, true)
	b.stroke(Face.Builder.ring(Vector2.ZERO, r * 1.28, r * 0.36), r * 0.025, Color(GOLD_DEEP, 0.7), true)
	var m := b.mesh()
	_cache[key] = m
	return m
