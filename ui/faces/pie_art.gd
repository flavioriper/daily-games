extends RefCounted

## Who Ate the Pie?'s pieces (puzzles/pie2d.gd, its tutorial and its menu
## card): the baker's name card, the two verdict badges (a leaf tick for
## "didn't", a slice of pie for "ate pie"), the pie in its dish, the baker's
## hat, the bubble the clues are read in and the two verdict buttons. Builder
## shapes, cached per size, as teacup.gd's are; the bakers themselves are
## the house's own faces (teacup.gd's friends and more), never new drawings.
##
## A card says its baker's verdict by its paper and its badge, never by a
## shade of the face: a cleared card is leaf paper with a tick, a card that
## ate is berry paper with a slice.

const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Scenery = preload("res://ui/flat/scenery.gd")

## The bakers, by face: twenty silhouettes, one each on Insane's grid.
const FACES := [
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
	"res://ui/faces/bee_face.gd",
	"res://ui/faces/hedgehog_face.gd",
	"res://ui/faces/kitten_face.gd",
	"res://ui/faces/snail_face.gd",
	"res://ui/faces/sprout_face.gd",
	"res://ui/faces/conifer_face.gd",
	"res://ui/faces/oak_face.gd",
	"res://ui/faces/troll_face.gd",
	"res://ui/faces/lantern_face.gd",
	"res://ui/faces/tent_face.gd",
]

enum Paper { OPEN, CLEAR, ATE }

const CARD := Color("fffaf0")
const CARD_EDGE := Color("e2d3ba")
const CLEAR := Color("e9f3dd")
const CLEAR_EDGE := Color("a9cc8c")
const ATE := Color("fbe2dc")
const ATE_EDGE := Color("e3a39a")
const SHADE := Color("6b4a33")
const CRUST := Color("e3b46e")
const CRUST_DEEP := Color("c08a45")
const CRUST_LIT := Color("f2cf8f")
const FILLING := Color("b8455a")
const FILLING_DEEP := Color("8f3046")
const DISH := Color("f4efe6")
const DISH_DEEP := Color("cfc3b0")
const DISH_RIM := Color("a9c9d9")
const CRUMB := Color("d6a865")
const HAT := Color("fffdf9")
const HAT_SHADE := Color("e8e0d2")
const BUBBLE := Color("fffdf8")
const BUBBLE_EDGE := Color("dccbb0")

static var _cache := {}

## A baker's face node for kind `k`, not in any tree; the owner sizes it and
## draws `layers_now()` under its own transform.
static func baker(k: int) -> Control:
	var f: Control = load(FACES[k % FACES.size()]).new()
	f.shadowless = true
	return f

## A name card `sz`, its top left at the origin, on `paper`.
static func card(sz: Vector2, paper: int) -> ArrayMesh:
	var key := "card:%d:%d:%d" % [roundi(sz.x), roundi(sz.y), paper]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := minf(sz.x, sz.y) * 0.1
	var fill: Color = [CARD, CLEAR, ATE][paper]
	var edge: Color = [CARD_EDGE, CLEAR_EDGE, ATE_EDGE][paper]
	b.polygon(Face.Builder.round_rect(Vector2(0.0, sz.y * 0.035), sz, r), Color(SHADE, 0.16))
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, sz, r), edge)
	var inset := maxf(2.0, sz.x * 0.014)
	b.polygon(Face.Builder.round_rect(Vector2(inset, inset), sz - Vector2(inset, inset) * 2.0, r - inset), fill)
	return _keep(key, b)

## A ring around a card `sz` (origin at its top left): the picked baker's
## (thick, sun) or a baker a clue speaks of (thin).
static func halo(sz: Vector2, colour: Color, width: float) -> ArrayMesh:
	var key := "halo:%d:%d:%d:%s" % [roundi(sz.x), roundi(sz.y), roundi(width * 4.0), colour.to_html()]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := minf(sz.x, sz.y) * 0.1
	var out := width * 0.6
	b.stroke(Face.Builder.round_rect(Vector2(-out, -out), sz + Vector2(out, out) * 2.0, r + out), width, colour, true)
	return _keep(key, b)

## The cleared badge: a leaf disc with a cream tick, `r` its radius, its
## centre at the origin.
static func tick(r: float) -> ArrayMesh:
	var key := "tick:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2(0.0, r * 0.08), r, Pal.LEAF_DEEP)
	b.disc(Vector2.ZERO, r, Pal.LEAF)
	b.stroke(PackedVector2Array([Vector2(-r * 0.45, r * 0.02), Vector2(-r * 0.12, r * 0.34), Vector2(r * 0.46, -r * 0.32)]),
		r * 0.24, Pal.SURFACE)
	return _keep(key, b)

## The ate badge: a slice of berry pie, its point down-left, `r` its reach,
## centred on the origin.
static func slice(r: float) -> ArrayMesh:
	var key := "slice:%d" % roundi(r * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	b.disc(Vector2(0.0, r * 0.08), r, Pal.BERRY_DEEP)
	b.disc(Vector2.ZERO, r, Pal.BERRY_TILE)
	_wedge(b, Vector2(-r * 0.5, r * 0.42), r * 1.05, -PI * 0.42, -PI * 0.08)
	return _keep(key, b)

## One wedge of pie from `tip` out to `reach`, between two angles: filling,
## the crust's rim and its lit lip.
static func _wedge(b: Face.Builder, tip: Vector2, reach: float, from: float, to: float) -> void:
	var outer := Face.Builder.arc_points(tip, reach, from, to)
	var pts := PackedVector2Array([tip])
	pts.append_array(outer)
	b.polygon(pts, FILLING_DEEP)
	var inner := PackedVector2Array([tip])
	inner.append_array(Face.Builder.arc_points(tip, reach * 0.86, from + 0.03, to - 0.03))
	b.polygon(inner, FILLING)
	b.stroke(outer, reach * 0.16, CRUST_DEEP, false, true)
	b.stroke(outer, reach * 0.1, CRUST, false, true)
	# a lattice strip across the slice
	var mid := (from + to) * 0.5
	b.stroke(PackedVector2Array([tip + Vector2.from_angle(mid) * reach * 0.2, tip + Vector2.from_angle(mid) * reach * 0.8]),
		reach * 0.08, CRUST_LIT)

## The pie in its dish, `r` the dish's radius, centre at the origin: `slices`
## wedges (one per baker who ate), the first `gone` of them eaten down to
## crumbs. `slices` < 0 is Insane's empty dish: crumbs and no count.
static func pie(r: float, slices: int, gone: int) -> ArrayMesh:
	var key := "pie:%d:%d:%d" % [roundi(r * 2.0), slices, gone]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	Scenery.soft_disc(b, Vector2(0.0, r * 0.22), r * 1.05, r * 0.4, Color(SHADE, 0.18))
	b.ellipse(Vector2(0.0, r * 0.1), r, r * 0.62, DISH_DEEP)
	b.ellipse(Vector2.ZERO, r, r * 0.6, DISH)
	b.stroke(Face.Builder.ring(Vector2.ZERO, r * 0.9, r * 0.53), r * 0.04, DISH_RIM, true)
	var pr := r * 0.74
	if slices <= 0:
		_crumbs(b, Vector2.ZERO, pr, 11)
		return _keep(key, b)
	# the pie seen from a little above: wedges squashed onto the ellipse
	var b2 := Face.Builder.new()
	for s in slices:
		var from := -PI * 0.5 + TAU * s / slices
		var to := from + TAU / slices
		if s < gone:
			continue
		_wedge(b2, Vector2.ZERO, pr, from + 0.02, to - 0.02)
	if gone < slices:
		b.append(b2.mesh(), Transform2D(0.0, Vector2(1.0, 0.6), 0.0, Vector2(0.0, -r * 0.04)))
	for s in gone:
		var mid := -PI * 0.5 + TAU * (s + 0.5) / slices
		_crumbs(b, Vector2.from_angle(mid) * pr * 0.5 * Vector2(1.0, 0.6), pr * 0.3, 3)
	return _keep(key, b)

static func _crumbs(b: Face.Builder, at: Vector2, spread: float, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = n * 977 + roundi(at.x * 3.0)
	for i in n:
		var p := at + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.6, 0.6)) * spread
		b.disc(p, spread * rng.randf_range(0.08, 0.14), CRUMB)

## Crumbs round a caught baker's mouth, `w` the face's width, centred on
## the origin: one under each cheek and a few on the chin.
static func crumbs(w: float) -> ArrayMesh:
	var key := "crumbs:%d" % roundi(w * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	for p in [Vector2(-w * 0.2, 0.0), Vector2(w * 0.22, w * 0.03), Vector2(0.0, w * 0.1)]:
		_crumbs(b, p, w * 0.17, 3)
	return _keep(key, b)

## A baker's hat: a tall white cook's hat, its band's middle at the origin,
## `w` its band's width.
static func hat(w: float) -> ArrayMesh:
	var key := "hat:%d" % roundi(w * 2.0)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var band := Face.Builder.round_rect(Vector2(-w * 0.5, -w * 0.12), Vector2(w, w * 0.3), w * 0.08)
	for p in [Vector2(-w * 0.32, -w * 0.38), Vector2(w * 0.32, -w * 0.38), Vector2(0.0, -w * 0.52)]:
		b.disc(p + Vector2(0.0, w * 0.04), w * 0.34, HAT_SHADE)
	for p in [Vector2(-w * 0.32, -w * 0.38), Vector2(w * 0.32, -w * 0.38), Vector2(0.0, -w * 0.52)]:
		b.disc(p, w * 0.32, HAT)
	b.polygon(band, HAT_SHADE)
	b.polygon(Face.Builder.round_rect(Vector2(-w * 0.5, -w * 0.12), Vector2(w, w * 0.22), w * 0.08), HAT)
	return _keep(key, b)

## The bubble clues are read in, `sz`, its top left at the origin, with a
## little tail up at `tail_x` (no tail when negative).
static func bubble(sz: Vector2, tail_x: float) -> ArrayMesh:
	var key := "bubble:%d:%d:%d" % [roundi(sz.x), roundi(sz.y), roundi(tail_x)]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := minf(sz.y * 0.22, 36.0)
	b.polygon(Face.Builder.round_rect(Vector2(0.0, sz.y * 0.04), sz, r), Color(SHADE, 0.14))
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, sz, r), BUBBLE_EDGE)
	var t := r * 0.6
	if tail_x >= 0.0:
		b.polygon(PackedVector2Array([Vector2(tail_x - t, 2.0), Vector2(tail_x, -t), Vector2(tail_x + t, 2.0)]), BUBBLE_EDGE)
	b.polygon(Face.Builder.round_rect(Vector2(3.0, 3.0), sz - Vector2(6.0, 6.0), r - 3.0), BUBBLE)
	if tail_x >= 0.0:
		b.polygon(PackedVector2Array([Vector2(tail_x - t + 4.0, 4.0), Vector2(tail_x, -t + 5.0), Vector2(tail_x + t - 4.0, 4.0)]), BUBBLE)
	return _keep(key, b)

## A verdict button `sz` (top left at the origin): leaf for "didn't", berry
## for "ate pie", with its badge at the left; `down` is pressed.
static func button(sz: Vector2, eat: bool, down: bool) -> ArrayMesh:
	var key := "btn:%d:%d:%s:%s" % [roundi(sz.x), roundi(sz.y), eat, down]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := sz.y * 0.5
	var fill: Color = Pal.BERRY if eat else Pal.LEAF
	var deep: Color = Pal.BERRY_DEEP if eat else Pal.LEAF_DEEP
	var lift := 0.0 if down else sz.y * 0.08
	b.polygon(Face.Builder.round_rect(Vector2(0.0, sz.y * 0.08), sz, r), deep)
	b.polygon(Face.Builder.round_rect(Vector2(0.0, sz.y * 0.08 - lift), sz, r), fill)
	var at := Vector2(r, sz.y * 0.5 + sz.y * 0.08 - lift)
	b.disc(at, r * 0.62, Pal.SURFACE)
	if eat:
		_wedge(b, at + Vector2(-r * 0.3, r * 0.26), r * 0.62, -PI * 0.42, -PI * 0.08)
	else:
		b.stroke(PackedVector2Array([at + Vector2(-r * 0.28, 0.0), at + Vector2(-r * 0.07, r * 0.22), at + Vector2(r * 0.3, -r * 0.2)]),
			r * 0.15, Pal.LEAF_DEEP)
	return _keep(key, b)

static func _keep(key: String, b: Face.Builder) -> ArrayMesh:
	var m := b.mesh()
	_cache[key] = m
	return m
