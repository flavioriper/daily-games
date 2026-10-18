extends RefCounted

## Bagatelle's drawings (arcade/bagatelle_board.gd lays them). Redrawn on
## 2026-10-18 (the user: "something more cozier and elegant ... with
## deep"): a deep plum velvet under a pool of lamplight with a vignette at
## the edges; walnut rails at the sides and a walnut head bar the dropper's
## little cannon rides, a glass return tube up the right rail and along
## the head bar; domed brass pins set into the nap, each with its cast
## shadow; glass marbles with a contact shadow, a lower crescent, a rim
## light and a bright window; seven turned walnut cups with a brass band
## and an engraved brass plate, drawn in two halves (back and front) so a
## marble is seen dropping in; brass fins between the cups. Everything is
## built once in the sim's field units and laid by the board's transform,
## so nothing is keyed by a size that changes.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://arcade/bagatelle_sim.gd")

const VELVET_TOP := Color("3f2e55")
const VELVET_MID := Color("2e2140")
const VELVET_LOW := Color("1a1324")
const LAMP := Color("ffd9a6")
const BRASS := Color("e2b55a")
const BRASS_DEEP := Color("9c7230")
const BRASS_HI := Color("fff0c2")
const WALNUT := Color("6a4530")
const WALNUT_DEEP := Color("3f2619")
const WALNUT_HI := Color("956a48")
const WOOD := WALNUT_HI
const WOOD_DEEP := WALNUT_DEEP
const FELT := Color("2e4a3a")
const FELT_DEEP := Color("1f3328")
const CREAM := Color("fff6e4")
const INK := Color("3b3028")
const SHADE := Color(0.05, 0.02, 0.08, 0.42)
const PLUS := Color("f5c542")
const TIMES := Color("f08aa0")
## The fifth and tenth investments' pegs: the +100 in jade, the ×5 in violet.
const MEGA := Color("6fd6a8")
const ULT := Color("b48cf2")
const HALO := Color("ffe2a6")
## The tiers' colours, Clay to Sun.
const TIER := [
	Color("eadbc4"), Color("8fd0e6"), Color("e8a07a"), Color("97c785"),
	Color("f2cd5c"), Color("c6b0e6"), Color("dfe7f0"), Color("f6e1e6"),
	Color("e2645c"), Color("9fdcd2"), Color("7f93d6"), Color("f5a623"),
	Color("7fe0b0"), Color("f58fd0"), Color("5b4a86"), Color("ffe27a"),
]
## The rails' width (the right one holds the return tube), and where the
## head bar lies.
const RAIL := 18.0
const RAIL_R := 44.0
const HEAD_Y := Sim.DROP_Y - 82.0
const HEAD_H := 38.0
## The foot bar under the cups, mirroring the head bar.
const FOOT_Y := Sim.H + 12.0
const FOOT_H := 38.0
## The return tube (the user, 2026-10-18: "a vacuum pipe that come from
## the bottom and connect to the dropper"): a glass tube along the foot bar
## under every cup, up the right rail and along the head bar to its capped
## end, the marbles in it laid at PIPE_K. Its bore's half width, the
## corners' radius, where it runs, and where it starts and ends.
const PIPE_R := 15.0
const PIPE_K := 0.7
const PIPE_X := Sim.W + RAIL_R * 0.5
const PIPE_Y := HEAD_Y + HEAD_H * 0.5
const PIPE_FOOT := FOOT_Y + FOOT_H * 0.5
const PIPE_CORNER := 26.0
const PIPE_START := Sim.CUP_W * 0.5 - 24.0
const PIPE_CAP := Sim.W * Sim.AIM_LO - 70.0
## The dropper's housing round the tube, half its width: the queue starts
## at its side.
const HOUSING := 32.0

static var _cache := {}

static func _keep(key, b: Face.Builder) -> ArrayMesh:
	var m := b.mesh()
	_cache[key] = m
	return m

static func tier_colour(k: int) -> Color:
	return TIER[clampi(k, 0, TIER.size() - 1)]

# --- marbles ---

## A marble of tier `k`, radius `r`, about (0, 0): glass, lit from the
## top left.
static func marble(k: int, r := Sim.BALL_R) -> ArrayMesh:
	var key := ["marble", k, r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.detail = maxf(1.0, r / 15.0)
	var c := tier_colour(k)
	b.disc(Vector2.ZERO, r, c.darkened(0.3))
	b.disc(Vector2(-r * 0.06, -r * 0.08), r * 0.94, c)
	# the lower side in shade, and a rim light under it
	b.ellipse(Vector2(r * 0.04, r * 0.34), r * 0.8, r * 0.56, c.darkened(0.22))
	b.ellipse(Vector2(r * 0.06, r * 0.5), r * 0.62, r * 0.3, Color(c.lightened(0.35), 0.45))
	b.disc(Vector2(-r * 0.1, -r * 0.14), r * 0.66, c)
	# glass from the second tier: a pale inner ring
	if k >= 1:
		b.stroke(Face.Builder.ring(Vector2(-r * 0.04, -r * 0.06), r * 0.74, r * 0.74), maxf(1.5, r * 0.08), Color(1, 1, 1, 0.14), true)
	# bands from the fourth tier: one, then two from the seventh, then three
	# (the last four tiers wear three)
	var bands := 0 if k < 3 else (1 if k < 6 else (2 if k < 9 else 3))
	for i in bands:
		var a := -0.5 + 1.1 * i
		var pts := PackedVector2Array()
		for j in 9:
			var u := lerpf(-1.0, 1.0, j / 8.0)
			pts.append(Vector2(u * r * 0.8, sin(u * 2.2 + a) * r * 0.28 + (i - (bands - 1) * 0.5) * r * 0.4))
		b.stroke(pts, maxf(2.0, r * 0.15), Color(CREAM, 0.8))
	# the window: a bright ellipse and a point
	b.ellipse(Vector2(-r * 0.34, -r * 0.4), r * 0.3, r * 0.19, Color(1, 1, 1, 0.55))
	b.disc(Vector2(-r * 0.44, -r * 0.5), r * 0.1, Color(1, 1, 1, 0.9))
	return _keep(key, b)

## The shadow a marble casts on the velvet, about (0, 0); laid a little
## down and right of it.
static func marble_shadow(r := Sim.BALL_R) -> ArrayMesh:
	var key := ["mshadow", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.ellipse(Vector2.ZERO, r * 1.15, r * 0.95, Color(0.04, 0.02, 0.07, 0.16))
	b.ellipse(Vector2.ZERO, r * 0.9, r * 0.74, Color(0.04, 0.02, 0.07, 0.22))
	return _keep(key, b)

## A marble's trail: one soft disc of its colour (laid with an alpha).
static func trail(k: int, r := Sim.BALL_R) -> ArrayMesh:
	var key := ["trail", k, r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, r * 0.92, tier_colour(k).lightened(0.2))
	return _keep(key, b)

## The ring a marble wears once a bonus pin has touched it.
static func boost_ring(kind: String, r := Sim.BALL_R) -> ArrayMesh:
	var key := ["ring", kind, r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.stroke(Face.Builder.ring(Vector2.ZERO, r + 5.0, r + 5.0), 3.5, peg_colour(kind), true)
	return _keep(key, b)

# --- pins ---

## One brass pin.
static func pin(r := Sim.PIN_R) -> ArrayMesh:
	var key := ["pin", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	_pin_into(b, Vector2.ZERO, r, BRASS)
	return _keep(key, b)

static func _pin_into(b: Face.Builder, p: Vector2, r: float, col: Color) -> void:
	# pressed into the nap, a shadow cast down and right, then the dome
	b.disc(p + Vector2(0, 1.5), r * 1.5, Color(0.03, 0.01, 0.05, 0.22))
	b.disc(p + Vector2(2.5, 4.0), r * 1.05, SHADE)
	b.disc(p, r, col.darkened(0.42))
	b.disc(p + Vector2(-0.5, -1.0), r * 0.82, col)
	b.disc(p + Vector2(r * 0.34, r * 0.38), r * 0.22, Color(BRASS_HI, 0.22))
	b.disc(p + Vector2(-r * 0.3, -r * 0.36), r * 0.3, Color(BRASS_HI, 0.95))

## Every pin of the board, one mesh.
static func pins() -> ArrayMesh:
	if _cache.has("pins"):
		return _cache["pins"]
	var b := Face.Builder.new()
	for r in Sim.ROWS:
		for i in Sim.row_count(r):
			if Sim.has_pin(r, i):
				_pin_into(b, Sim.pin_at(r, i), Sim.PIN_R, BRASS)
	return _keep("pins", b)

static func peg_colour(kind: String) -> Color:
	match kind:
		"times":
			return TIMES
		"mega":
			return MEGA
		"ult":
			return ULT
	return PLUS

## A bonus pin: a larger pin of its colour with a soft halo and its mark
## (a + for the adding pegs, a × for the multiplying ones; the mega and
## ultimate pegs a size bigger).
static func bonus_pin(kind: String) -> ArrayMesh:
	var key := ["bonus", kind]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var col := peg_colour(kind)
	var big := 1.2 if kind == "mega" or kind == "ult" else 1.0
	b.disc(Vector2.ZERO, Sim.PIN_R * 2.8 * big, Color(col, 0.14))
	b.disc(Vector2.ZERO, Sim.PIN_R * 2.0 * big, Color(col, 0.2))
	_pin_into(b, Vector2.ZERO, Sim.PIN_R * 1.35 * big, col)
	var s := Sim.PIN_R * 0.55 * big
	if kind == "plus" or kind == "mega":
		b.stroke(PackedVector2Array([Vector2(-s, 0), Vector2(s, 0)]), 2.6, INK)
		b.stroke(PackedVector2Array([Vector2(0, -s), Vector2(0, s)]), 2.6, INK)
	else:
		b.stroke(PackedVector2Array([Vector2(-s, -s), Vector2(s, s)]), 2.6, INK)
		b.stroke(PackedVector2Array([Vector2(-s, s), Vector2(s, -s)]), 2.6, INK)
	return _keep(key, b)

## A pin's glow as it is touched: a soft disc, never rays.
static func halo() -> ArrayMesh:
	if _cache.has("halo"):
		return _cache["halo"]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, Sim.PIN_R * 3.2, Color(HALO, 0.14))
	b.disc(Vector2.ZERO, Sim.PIN_R * 2.1, Color(HALO, 0.28))
	b.disc(Vector2.ZERO, Sim.PIN_R * 1.2, Color(HALO, 0.8))
	return _keep("halo", b)

## A tiny spark a struck pin throws (laid with an alpha).
static func spark() -> ArrayMesh:
	if _cache.has("spark"):
		return _cache["spark"]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, 3.2, Color(HALO, 0.5))
	b.disc(Vector2.ZERO, 1.8, CREAM)
	return _keep("spark", b)

# --- the cups ---

static func _cup_w() -> float:
	return Sim.CUP_W - FIN_GAP * 2.0

const FIN_GAP := Sim.FIN_W + 1.0
const CUP_H := Sim.H - Sim.CUP_TOP + 8.0
## The front wall starts this far under the rim, so the inside shows.
const LIP := 16.0
const PLATE_Y := 38.0
const PLATE_H := 30.0

## The seven cups' insides, one mesh: the hollow a marble drops into.
static func cups_back() -> ArrayMesh:
	if _cache.has("cups_back"):
		return _cache["cups_back"]
	var b := Face.Builder.new()
	var w := _cup_w()
	for c in Sim.CUPS:
		var x0 := (c + 0.5) * Sim.CUP_W - w * 0.5
		var y0 := Sim.CUP_TOP - 6.0
		b.polygon(Face.Builder.round_rect(Vector2(x0, y0), Vector2(w, CUP_H + 6.0), 14.0), WALNUT_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(x0 + 7.0, y0 + 5.0), Vector2(w - 14.0, CUP_H - 10.0), 10.0), FELT_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(x0 + 10.0, y0 + 12.0), Vector2(w - 20.0, CUP_H - 24.0), 8.0), FELT.lerp(FELT_DEEP, 0.12 * absf(c - 3)))
		# the hollow's shadow under the rim
		var a := b.vertex(Vector2(x0 + 7.0, y0 + 5.0), Color(0, 0, 0, 0.45))
		var bb := b.vertex(Vector2(x0 + w - 7.0, y0 + 5.0), Color(0, 0, 0, 0.45))
		var cc := b.vertex(Vector2(x0 + w - 7.0, y0 + 30.0), Color(0, 0, 0, 0.0))
		var d := b.vertex(Vector2(x0 + 7.0, y0 + 30.0), Color(0, 0, 0, 0.0))
		b.tri(a, bb, cc)
		b.tri(a, cc, d)
	return _keep("cups_back", b)

## One cup's front: its wall, brass band and plate, its top at y 0 and its
## middle across at x 0 (laid under a squash as a marble lands).
static func cup(c: int) -> ArrayMesh:
	var key := ["cup", c]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var w := _cup_w()
	var x0 := -w * 0.5
	var h := CUP_H - LIP
	var edge := 1.0 - 0.1 * absf(c - 3)
	var wood := WALNUT.lerp(Color("7a4a2a"), 1.0 - edge)
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 3.0, LIP + 8.0), Vector2(w, h), 14.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(x0, LIP), Vector2(w, h), 14.0), WALNUT_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 4.0, LIP + 3.0), Vector2(w - 8.0, h - 10.0), 11.0), wood)
	# the grain: three soft lighter lines
	for i in 3:
		var y := LIP + 30.0 + i * 24.0
		b.stroke(PackedVector2Array([Vector2(x0 + 12.0, y), Vector2(x0 + w - 12.0, y + 2.0)]), 2.0, Color(WALNUT_HI, 0.18))
	# the turned lip and the brass band under it
	b.polygon(Face.Builder.round_rect(Vector2(x0 - 2.0, LIP - 4.0), Vector2(w + 4.0, 12.0), 6.0), WALNUT_HI)
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 2.0, LIP + 9.0), Vector2(w - 4.0, 7.0), 3.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(x0 + 2.0, LIP + 9.0), Vector2(w - 4.0, 4.0), 2.0), BRASS)
	# the plate the multiplier is engraved on
	var pw := w - 26.0
	var py := PLATE_Y - PLATE_H * 0.5
	b.polygon(Face.Builder.round_rect(Vector2(-pw * 0.5 + 1.0, py + 3.0), Vector2(pw, PLATE_H), 8.0), Color(0, 0, 0, 0.3))
	b.polygon(Face.Builder.round_rect(Vector2(-pw * 0.5, py), Vector2(pw, PLATE_H), 8.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-pw * 0.5 + 2.0, py + 2.0), Vector2(pw - 4.0, PLATE_H - 5.0), 7.0), BRASS)
	b.polygon(Face.Builder.round_rect(Vector2(-pw * 0.5 + 4.0, py + 3.0), Vector2(pw - 8.0, PLATE_H * 0.4), 5.0), Color(BRASS_HI, 0.35))
	return _keep(key, b)

## The fins between the cups, one mesh: thin brass walls that send a
## marble into one cup or the other.
static func fins() -> ArrayMesh:
	if _cache.has("fins"):
		return _cache["fins"]
	var b := Face.Builder.new()
	for c in range(1, Sim.CUPS):
		var x := c * Sim.CUP_W
		var top := Sim.FIN_TOP
		var bottom := Sim.CUP_TOP + 10.0
		b.polygon(Face.Builder.round_rect(Vector2(x - Sim.FIN_W + 2.0, top + 4.0), Vector2(Sim.FIN_W * 2.0, bottom - top), Sim.FIN_W), SHADE)
		b.polygon(Face.Builder.round_rect(Vector2(x - Sim.FIN_W, top), Vector2(Sim.FIN_W * 2.0, bottom - top), Sim.FIN_W), BRASS_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(x - Sim.FIN_W + 1.5, top + 1.0), Vector2(Sim.FIN_W * 2.0 - 3.0, bottom - top - 4.0), Sim.FIN_W - 1.5), BRASS)
		b.disc(Vector2(x - 1.0, top + Sim.FIN_W), Sim.FIN_W * 0.45, Color(BRASS_HI, 0.9))
	return _keep("fins", b)

## The light that rises out of a cup as a marble drops in (the user,
## 2026-10-18: "a light coming from the box", then "it should only show
## the light that come from inside the cup"): a soft column, bright at
## its foot and nothing at its top, its foot at (0, 0) and its top at
## -LIGHT_H (laid under a scale and an alpha, its foot down inside the cup
## behind the front wall; no rays, no shape).
const LIGHT_H := 300.0
static func cup_light() -> ArrayMesh:
	if _cache.has("light"):
		return _cache["light"]
	var b := Face.Builder.new()
	var w := Sim.CUP_W - 16.0
	for layer: Array in [[w * 0.5, 1.0, 0.3], [w * 0.3, 0.85, 0.42], [w * 0.14, 0.6, 0.55]]:
		var hw: float = layer[0]
		var top: float = -LIGHT_H * float(layer[1])
		var a: float = layer[2]
		var foot := Color(HALO, a)
		var head := Color(HALO, 0.0)
		var p0 := b.vertex(Vector2(-hw * 0.7, top), head)
		var p1 := b.vertex(Vector2(hw * 0.7, top), head)
		var p2 := b.vertex(Vector2(hw, 0.0), foot)
		var p3 := b.vertex(Vector2(-hw, 0.0), foot)
		b.tri(p0, p1, p2)
		b.tri(p0, p2, p3)
	return _keep("light", b)

# --- the rails and the dropper ---

## The walnut rails at the sides and the head bar across the top; the
## right rail and the head bar carry the return tube's seat and dark bore
## (its glass is `pipe_front`, laid over the marbles in it).
static func rails() -> ArrayMesh:
	if _cache.has("rails"):
		return _cache["rails"]
	var b := Face.Builder.new()
	var top := HEAD_Y - 6.0
	var bottom := FOOT_Y + 6.0
	for side in 2:
		var x := -RAIL if side == 0 else Sim.W
		var w := RAIL if side == 0 else RAIL_R
		b.polygon(PackedVector2Array([Vector2(x - 2.0, top), Vector2(x + w + 2.0, top), Vector2(x + w + 2.0, bottom), Vector2(x - 2.0, bottom)]), SHADE)
		b.polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w, top), Vector2(x + w, bottom), Vector2(x, bottom)]), WALNUT_DEEP)
		var in_x := x + 3.0
		b.polygon(PackedVector2Array([Vector2(in_x, top + 3.0), Vector2(in_x + w - 6.0, top + 3.0), Vector2(in_x + w - 6.0, bottom), Vector2(in_x, bottom)]), WALNUT)
		var hx := x + 4.0 if side == 0 else x + w - 7.0
		b.polygon(PackedVector2Array([Vector2(hx, top + 4.0), Vector2(hx + 3.0, top + 4.0), Vector2(hx + 3.0, bottom), Vector2(hx, bottom)]), Color(WALNUT_HI, 0.5))
	# the head bar
	var span := Sim.W + RAIL + RAIL_R
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL - 2.0, HEAD_Y + 5.0), Vector2(span + 4.0, HEAD_H + 4.0), 8.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL, HEAD_Y), Vector2(span, HEAD_H), 8.0), WALNUT_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL + 3.0, HEAD_Y + 3.0), Vector2(span - 6.0, HEAD_H - 8.0), 6.0), WALNUT)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL + 6.0, HEAD_Y + 4.0), Vector2(span - 12.0, 5.0), 2.5), Color(WALNUT_HI, 0.55))
	# the foot bar
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL - 2.0, FOOT_Y + 5.0), Vector2(span + 4.0, FOOT_H + 4.0), 8.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL, FOOT_Y), Vector2(span, FOOT_H), 8.0), WALNUT_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL + 3.0, FOOT_Y + 3.0), Vector2(span - 6.0, FOOT_H - 8.0), 6.0), WALNUT)
	b.polygon(Face.Builder.round_rect(Vector2(-RAIL + 6.0, FOOT_Y + 4.0), Vector2(span - 12.0, 5.0), 2.5), Color(WALNUT_HI, 0.55))
	# the tube's seat and its bore
	var path := pipe_path()
	b.stroke(path, PIPE_R * 2.0 + 10.0, Color(0.05, 0.02, 0.05, 0.5))
	b.stroke(path, PIPE_R * 2.0 + 6.0, BRASS_DEEP)
	b.stroke(path, PIPE_R * 2.0, Color("140d18"))
	b.stroke(_offset(path, PIPE_R * 0.45), 6.0, Color(VELVET_TOP, 0.55))
	# brass nails at the left corners
	for p: Vector2 in [Vector2(-RAIL * 0.5, HEAD_Y + HEAD_H * 0.5), Vector2(-RAIL * 0.5, FOOT_Y + FOOT_H * 0.5)]:
		b.disc(p + Vector2(1.0, 1.5), 5.0, SHADE)
		b.disc(p, 5.0, BRASS_DEEP)
		b.disc(p + Vector2(-0.6, -0.8), 3.8, BRASS)
		b.disc(p + Vector2(-1.4, -1.6), 1.4, BRASS_HI)
	return _keep("rails", b)

## The return tube's centreline, from its capped start under the first cup
## along the foot bar, up the right rail and round to its capped end on the
## head bar.
static func pipe_path() -> PackedVector2Array:
	if _cache.has("pipe_path"):
		return _cache["pipe_path"]
	var pts := PackedVector2Array([Vector2(PIPE_START, PIPE_FOOT)])
	var low := Vector2(PIPE_X - PIPE_CORNER, PIPE_FOOT - PIPE_CORNER)
	for i in 9:
		pts.append(low + Vector2.from_angle(lerpf(PI * 0.5, 0.0, i / 8.0)) * PIPE_CORNER)
	var c := Vector2(PIPE_X - PIPE_CORNER, PIPE_Y + PIPE_CORNER)
	for i in 9:
		pts.append(c + Vector2.from_angle(lerpf(0.0, -PI * 0.5, i / 8.0)) * PIPE_CORNER)
	pts.append(Vector2(PIPE_CAP, PIPE_Y))
	_cache["pipe_path"] = pts
	return pts

## A line moved `d` to the left of its way along it.
static func _offset(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var a := pts[maxi(i - 1, 0)]
		var z := pts[mini(i + 1, pts.size() - 1)]
		var t := (z - a).normalized()
		out[i] = pts[i] + Vector2(t.y, -t.x) * d
	return out

## The tube's glass over the marbles in it: a faint tint, a long bright
## streak along its lit side, brass bands, a brass socket under each cup
## and a cap at each end.
static func pipe_front() -> ArrayMesh:
	if _cache.has("pipe_front"):
		return _cache["pipe_front"]
	var b := Face.Builder.new()
	var path := pipe_path()
	b.stroke(path, PIPE_R * 2.0, Color(LAMP, 0.07))
	b.stroke(_offset(path, -PIPE_R * 0.55), 3.5, Color(CREAM, 0.38))
	b.stroke(_offset(path, PIPE_R * 0.6), 2.0, Color(CREAM, 0.12))
	# bands up the rail and along the head bar
	for y in [Sim.H - 200.0, Sim.H - 560.0, Sim.H - 900.0]:
		_band(b, Vector2(PIPE_X, y), false)
	for x in [Sim.W - 120.0, Sim.W * 0.5 + 230.0]:
		_band(b, Vector2(x, PIPE_Y), true)
	# the sockets a cup lets its marbles down through
	for c in Sim.CUPS:
		var x := (c + 0.5) * Sim.CUP_W
		b.polygon(Face.Builder.round_rect(Vector2(x - 20.0, PIPE_FOOT - PIPE_R - 6.0), Vector2(40.0, 10.0), 4.0), BRASS_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(x - 18.0, PIPE_FOOT - PIPE_R - 5.0), Vector2(36.0, 4.0), 2.0), BRASS)
	# the caps
	for at: Vector2 in [Vector2(PIPE_CAP, PIPE_Y), Vector2(PIPE_START, PIPE_FOOT)]:
		b.polygon(Face.Builder.round_rect(Vector2(at.x - 8.0, at.y - PIPE_R - 4.0), Vector2(14.0, PIPE_R * 2.0 + 8.0), 4.0), BRASS_DEEP)
		b.polygon(Face.Builder.round_rect(Vector2(at.x - 6.0, at.y - PIPE_R - 2.0), Vector2(6.0, PIPE_R * 2.0 + 2.0), 3.0), BRASS)
	return _keep("pipe_front", b)

static func _band(b: Face.Builder, at: Vector2, across: bool) -> void:
	var sz := Vector2(10.0, PIPE_R * 2.0 + 8.0) if across else Vector2(PIPE_R * 2.0 + 8.0, 10.0)
	b.polygon(Face.Builder.round_rect(at - sz * 0.5, sz, 3.0), BRASS_DEEP)
	var hi := Vector2(4.0, sz.y - 4.0) if across else Vector2(sz.x - 4.0, 4.0)
	b.polygon(Face.Builder.round_rect(at - sz * 0.5 + Vector2(2.0, 2.0), hi, 2.0), BRASS)

## The dropper, a little brass cannon: a housing clamped round the tube on
## the head bar and a barrel under it, its bore wide enough for a marble
## (`Sim.SPAWN_Y` lies inside it), its muzzle's mouth at (0, 0).
static func dropper() -> ArrayMesh:
	if _cache.has("dropper"):
		return _cache["dropper"]
	var b := Face.Builder.new()
	var ty := PIPE_Y - Sim.DROP_Y
	var bw := Sim.BALL_R + 9.0
	var top := ty + 14.0
	# the barrel's shadow, then the barrel
	b.polygon(Face.Builder.round_rect(Vector2(-bw + 4.0, top + 6.0), Vector2(bw * 2.0, -top), 8.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(-bw, top), Vector2(bw * 2.0, -top - 4.0), 6.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-bw + 3.0, top), Vector2(bw * 2.0 - 6.0, -top - 8.0), 5.0), BRASS)
	b.polygon(Face.Builder.round_rect(Vector2(-bw + 6.0, top + 2.0), Vector2(6.0, -top - 12.0), 3.0), Color(BRASS_HI, 0.6))
	b.polygon(Face.Builder.round_rect(Vector2(bw - 9.0, top + 2.0), Vector2(5.0, -top - 12.0), 2.5), Color(BRASS_DEEP, 0.7))
	# a band round the middle
	b.polygon(Face.Builder.round_rect(Vector2(-bw - 2.0, top * 0.45 - 4.0), Vector2(bw * 2.0 + 4.0, 8.0), 3.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-bw - 1.0, top * 0.45 - 3.0), Vector2(bw * 2.0 + 2.0, 3.0), 1.5), BRASS_HI)
	# the muzzle and the bore seen inside it
	b.polygon(Face.Builder.round_rect(Vector2(-bw - 4.0, -12.0), Vector2(bw * 2.0 + 8.0, 13.0), 5.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-bw - 2.0, -11.0), Vector2(bw * 2.0 + 4.0, 5.0), 2.5), BRASS_HI)
	b.ellipse(Vector2(0.0, 0.5), Sim.BALL_R + 3.0, 4.0, Color("140d18"))
	# the housing round the tube
	var hy := ty - PIPE_R - 9.0
	var hh := PIPE_R * 2.0 + 18.0
	b.polygon(Face.Builder.round_rect(Vector2(-HOUSING + 3.0, hy + 5.0), Vector2(HOUSING * 2.0, hh), 9.0), SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(-HOUSING, hy), Vector2(HOUSING * 2.0, hh), 9.0), BRASS_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2(-HOUSING + 3.0, hy + 2.0), Vector2(HOUSING * 2.0 - 6.0, hh - 6.0), 7.0), BRASS)
	b.polygon(Face.Builder.round_rect(Vector2(-HOUSING + 6.0, hy + 3.0), Vector2(HOUSING * 2.0 - 12.0, 6.0), 3.0), Color(BRASS_HI, 0.6))
	# its rivets
	for x in [-HOUSING + 9.0, HOUSING - 9.0]:
		b.disc(Vector2(x, ty + 2.0), 3.6, BRASS_DEEP)
		b.disc(Vector2(x - 0.6, ty + 1.2), 2.4, BRASS_HI)
	return _keep("dropper", b)

# --- the velvet ---

## The velvet, `size` pixels: a deep fall from top to foot, a pool of
## lamplight high in the middle, and a vignette at the edges.
static func velvet(size: Vector2) -> ArrayMesh:
	var key := ["velvet", size]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var steps := 8
	for i in steps:
		var y0 := size.y * i / steps
		var y1 := size.y * (i + 1) / steps + 1.0
		var c0 := _velvet_at(float(i) / steps)
		var c1 := _velvet_at(float(i + 1) / steps)
		var a := b.vertex(Vector2(0, y0), c0)
		var bb := b.vertex(Vector2(size.x, y0), c0)
		var cc := b.vertex(Vector2(size.x, y1), c1)
		var d := b.vertex(Vector2(0, y1), c1)
		b.tri(a, bb, cc)
		b.tri(a, cc, d)
	# the lamplight: a fan whose middle is warm and whose rim is nothing
	var mid := Vector2(size.x * 0.5, size.y * 0.3)
	var rx := size.x * 0.85
	var ry := size.y * 0.5
	var n := 48
	var centre := b.vertex(mid, Color(LAMP, 0.24))
	var rim := PackedInt32Array()
	for i in n:
		var ang := TAU * i / n
		rim.append(b.vertex(mid + Vector2(cos(ang) * rx, sin(ang) * ry), Color(LAMP, 0.0)))
	for i in n:
		b.tri(centre, rim[i], rim[(i + 1) % n])
	# the vignette: four bands fading inward
	var dark := Color(0.02, 0.0, 0.04, 1.0)
	var bands := [
		[Vector2(0, 0), Vector2(size.x * 0.22, 0), Vector2(size.x * 0.22, size.y), Vector2(0, size.y), 0.42],
		[Vector2(size.x, 0), Vector2(size.x * 0.78, 0), Vector2(size.x * 0.78, size.y), Vector2(size.x, size.y), 0.42],
		[Vector2(0, size.y), Vector2(0, size.y * 0.72), Vector2(size.x, size.y * 0.72), Vector2(size.x, size.y), 0.5],
		[Vector2(0, 0), Vector2(0, size.y * 0.12), Vector2(size.x, size.y * 0.12), Vector2(size.x, 0), 0.25],
	]
	for band: Array in bands:
		var a := b.vertex(band[0], Color(dark, float(band[4])))
		var bb := b.vertex(band[1], Color(dark, 0.0))
		var cc := b.vertex(band[2], Color(dark, 0.0))
		var d := b.vertex(band[3], Color(dark, float(band[4])))
		b.tri(a, bb, cc)
		b.tri(a, cc, d)
	return _keep(key, b)

static func _velvet_at(u: float) -> Color:
	if u < 0.45:
		return VELVET_TOP.lerp(VELVET_MID, u / 0.45)
	return VELVET_MID.lerp(VELVET_LOW, pow((u - 0.45) / 0.55, 1.2))

## A mote of dust in the lamplight (laid with an alpha).
static func mote() -> ArrayMesh:
	if _cache.has("mote"):
		return _cache["mote"]
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, 7.0, Color(LAMP, 0.1))
	b.disc(Vector2.ZERO, 3.6, Color(LAMP, 0.3))
	b.disc(Vector2.ZERO, 1.6, Color(CREAM, 0.7))
	return _keep("mote", b)

# --- the plates' marks ---

## A star (the second currency), radius `r`.
static func star(r: float) -> ArrayMesh:
	var key := ["star", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + TAU * i / 10.0
		pts.append(Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.48))
	var sh := PackedVector2Array()
	for p in pts:
		sh.append(p + Vector2(0, r * 0.12))
	b.polygon(sh, Color(0.3, 0.2, 0.1, 0.25))
	b.polygon(pts, Color("f5b83d"))
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.62 + Vector2(-r * 0.05, -r * 0.06))
	b.polygon(inner, Color("fbd06a"))
	return _keep(key, b)

## A coin, radius `r`.
static func coin(r: float) -> ArrayMesh:
	var key := ["coin", r]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2(0, r * 0.12), r, Color(0.3, 0.2, 0.1, 0.25))
	b.disc(Vector2.ZERO, r, Color("d99a2b"))
	b.disc(Vector2(0, -r * 0.05), r * 0.8, Color("f5c04a"))
	b.stroke(Face.Builder.ring(Vector2(0, -r * 0.05), r * 0.56, r * 0.56), maxf(1.5, r * 0.1), Color("d99a2b"), true)
	return _keep(key, b)
