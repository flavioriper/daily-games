extends RefCounted

## The Grove's drawings: the pond and the land seen in isometric (`see`,
## `ground`, `light`), the five trees, the shadow each throws (`shade`,
## `cast`) and the stump it leaves, the log, and
## a picture for each tile. Energy is a mote of light, Peapod's own
## (ui/motes.gd), and has no drawing here. Every one is built once into a
## mesh and kept, so the screen pays one draw_mesh a tree and one for the
## whole ground (CLAUDE.md, the 855 budget). The grass's tufts and flowers
## are a MultiMesh each (`grass`), and what stands leans in the wind in the
## vertex stage (`wind`, shaders/wind_2d.gdshader), with nothing rebuilt. Trees have no faces: they are
## what is chopped. Shared by the screen (valley/grove_screen.gd), the tab's
## card (ui/menu/valley_tab.gd) and the tutorial's pages.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://valley/grove_sim.gd")
const Pal = preload("res://core/palette.gd")
const Motes = preload("res://ui/motes.gd")
const Motion = preload("res://core/motion.gd")
const Beaver = preload("res://ui/faces/beaver.gd")
const WIND := preload("res://shaders/wind_2d.gdshader")

## The painted land (2026-10-06, the isometric pass): a pond pale far off
## and deep at the foot, grass in forest greens under a wash of warm light
## and cool shade, earth warm where it looks at the sun (upper left) and
## cool where it looks away, and a shadow that is a colour, never a grey.
const WATER_FAR := Color("b9e8e0")
const WATER := Color("7fd0cc")
const WATER_DEEP := Color("4ba9b3")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.42)
const LILY := Color("4f9f63")
const LILY_HI := Color("74c07e")
const GRASS := Color("82b95b")
const GRASS_LIT := Color("a3cf66")
const GRASS_DEEP := Color("5f9c55")
const WASH_WARM := Color("deec8a")
const WASH_COOL := Color("4c8f58")
const LIP := Color("4d8748")
const LIP_LIT := Color("67a650")
## The earth under the turf, top and foot, and the clay under that; each
## lit and in shade.
const EARTH := [Color("d8ad75"), Color("c2925e")]
const EARTH_SHADE := [Color("96694a"), Color("7f573f")]
const CLAY := [Color("b68253"), Color("966642")]
const CLAY_SHADE := [Color("76503b"), Color("5f4133")]
const SEAM := Color(0.34, 0.2, 0.13, 0.3)
const STONE := Color("e0cfae")
const STONE_SHADE := Color("a98f76")
const SHADE := Color(0.09, 0.27, 0.34, 0.26)
## A tuft's greens: most deeper than the grass, one in four lit.
const TUFTS := [Color("4f8f4c"), Color("5a964a"), Color("63a04e"), Color("b9da74")]
## What a flower's petals are tinted (its stem with them, so all pale).
const PETALS := [Color("ffffff"), Color("ffe3e0"), Color("fff0b8"), Color("ffffff")]
## A crown's four tones by look, its shade first, and a trunk's two.
const CROWN := {
	1: [Color("6aa53e"), Color("7fb548"), Color("97ca5a"), Color("c6e888")],
	2: [Color("437b30"), Color("539036"), Color("66a544"), Color("90cc66")],
	4: [Color("d0749f"), Color("e58fb5"), Color("f1a8c8"), Color("fdd6e6")],
}
const TRUNK := {
	1: [Color("f3eee2"), Color("d8cfbc")],
	2: [Color("8a5c3a"), Color("6f482c")],
	4: [Color("8a5c3a"), Color("6f482c")],
}
## A loose leaf's colour by look: what the wind takes off a tree.
const LEAF := [Color("a6d96e"), Color("b5dd74"), Color("7fbb55"), Color("5fa377"), Color("fbd0e2")]
const BARK := Color("9c6b45")
const PITH := Color("f0d9ae")
const MARK := Color("ffd66b")
## The log's length as built; the screen scales it.
const LOG := 48.0
## A tile's picture is drawn about its middle, inside this half width.
const ICON := 56.0
## What the tree's pictures are made of beside wood: rope, planks, a crate's
## boards, an axe's steel, a feather.
const ROPE := Color("ecd9a6")
const ROPE_DEEP := Color("c9a968")
const PLANK := Color("cfa26d")
const PLANK_DEEP := Color("a57a48")
const STEEL := Color("9ba5ad")
const STEEL_LIT := Color("d5dde3")
const STEEL_DEEP := Color("7d8890")
const CLOVER := Color("6fae4c")
const CLOVER_LIT := Color("93cc66")

## How the land is seen: a point of the ground lands across as it is and
## DEEP as deep, in view units (land units as the screen lays them: a screen
## scales and places them). DEPTH is the earth showing over the water, ROUND
## how far a corner of the land is rounded off, and VIEW the box the land
## and its earth take.
const DEEP := Sim.DEEP
const DEPTH := 116.0
const ROUND := 96.0
const VIEW := Rect2(0.0, 0.0, 1040.0, 802.4)
## A tree is drawn this much over its footprint: seen from the side of the
## land, a crown only overlaps what is behind it.
const TREE := 1.25

## A shadow's tone, and how a standing drawing is laid on the ground to be
## one (`cast`): where a unit of its width goes, and a unit of its height.
const CAST := Color(0.09, 0.27, 0.34, 0.24)
const CAST_ACROSS := Vector2(-0.16, 0.44)
const CAST_ALONG := Vector2(0.8, 0.14)

static var _trees := {}
static var _shades := {}
static var _stumps := {}
static var _shade_winds: Array[WeakRef] = []
static var _icons := {}
static var _log: ArrayMesh
static var _tuft: ArrayMesh
static var _flower: ArrayMesh
static var _leaf_mesh: ArrayMesh
static var _winds := {}
static var _outline := PackedVector2Array()

## A tree of `look` (0 sapling, 1 birch, 2 oak, 3 pine, 4 blossom) standing
## on (0, 0), in land units. Redrawn on
## 2026-10-06 (the user: "polish design of trees, grass, add some wind
## movement"): lit from the upper left, so a crown is a shade under it, a
## body, a lit side and a few bright clumps, with loose leaves dabbed across
## the tones, and a trunk flares at its foot and is darker down its right.
## The shadow it throws is not in it (it was, an oval, and turned over with
## a falling tree): that is `shade`, laid on the ground by `cast`.
static func tree(look: int) -> ArrayMesh:
	if not _trees.has(look):
		var b := Face.Builder.new()
		_tree_into(b, look, Sim.RADIUS[look])
		_trees[look] = b.mesh()
	return _trees[look]

# --- the shadow a tree throws ---

## Collects what a drawing is made of as outlines, the colours dropped: a
## tree drawn into one gives the shape its shadow has.
class Outline extends Face.Builder:
	var shapes: Array[PackedVector2Array] = []

	func fan(points: PackedVector2Array, _colour: Color) -> void:
		shapes.append(points)

	func polygon(points: PackedVector2Array, _colour: Color) -> void:
		shapes.append(points)

	func stroke(points: PackedVector2Array, width: float, _colour: Color, _closed := false, _caps := true) -> void:
		for poly: PackedVector2Array in Geometry2D.offset_polyline(points, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND):
			shapes.append(poly)

	## Every shape melted into the others it touches, so nothing lies over
	## anything: a shadow drawn of overlapping pieces is darker where they do.
	func melted() -> Array[PackedVector2Array]:
		var acc: Array[PackedVector2Array] = []
		for shape in shapes:
			var top := 0.0
			for p in shape:
				top = minf(top, p.y)
			if top > -1.0:
				continue   # what lies on the ground (a dropped petal) throws none
			var cur := shape
			if Geometry2D.is_polygon_clockwise(cur):
				cur = cur.duplicate()
				cur.reverse()
			var again := true
			while again:
				again = false
				var rest: Array[PackedVector2Array] = []
				for q in acc:
					var outer: Array[PackedVector2Array] = []
					for m: PackedVector2Array in Geometry2D.merge_polygons(cur, q):
						if not Geometry2D.is_polygon_clockwise(m):
							outer.append(m)
					if outer.size() == 1:
						cur = outer[0]
						again = true
					else:
						rest.append(q)
				acc = rest
			acc.append(cur)
		return acc

## The shadow of a tree of `look`: its own outline in one piece and one
## tone, still standing on (0, 0). `cast` lays it on the ground; drawn
## under `shade_wind` it moves as its tree does.
static func shade(look: int) -> ArrayMesh:
	if not _shades.has(look):
		var o := Outline.new()
		_tree_into(o, look, Sim.RADIUS[look])
		var b := Face.Builder.new()
		for shape in o.melted():
			b.polygon(shape, CAST)
		_shades[look] = b.mesh()
	return _shades[look]

## Lays a standing drawing on the ground as the shadow of what stands at
## `at`, the sun upper left and behind: a tree's width goes back into the
## land (CAST_ACROSS a unit) and its height off to the right (CAST_ALONG).
## `lean` is how far the tree has turned over, in radians, to the right when
## over 0: its shadow does not turn with it but runs out along the ground
## and ends lying under it.
static func cast(at: Vector2, scale: Vector2, lean := 0.0) -> Transform2D:
	var along := CAST_ALONG * cos(lean) + Vector2(sin(lean), 0.05 * absf(sin(lean)))
	return Transform2D(CAST_ACROSS * scale.x, -along * scale.y, at)

## A material for a Control that draws shadows: the trees' own wind, turned
## into the way a shadow goes when its crown leans. A new one each call,
## since each holder keeps its shadows to its own land (`keep_to`); `blow`
## winds them all.
static func shade_wind() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WIND
	m.set_shader_parameter("tall", 120.0)
	m.set_shader_parameter("reach", 9.0)
	m.set_shader_parameter("rustle", 0.5)
	m.set_shader_parameter("droop", 0.0)
	m.set_shader_parameter("along", Transform2D(CAST_ACROSS, -CAST_ALONG, Vector2.ZERO).affine_inverse().basis_xform(Vector2.RIGHT))
	_shade_winds.append(weakref(m))
	return m

## Keeps what `m` draws to the land, as it lies for a Control whose own
## place on the screen is `xf`, the view's (0, 0) at `origin` in it and `u`
## pixels a unit.
static func keep_to(m: ShaderMaterial, xf: Transform2D, origin: Vector2, u: float) -> void:
	m.set_shader_parameter("land_half", Sim.HALF)
	m.set_shader_parameter("land_at", xf * (origin + see(Sim.LAND * 0.5) * u))
	m.set_shader_parameter("land_u", u * xf.get_scale().x)
	m.set_shader_parameter("land_deep", DEEP)

## What a felled tree leaves standing a moment: its foot, gnawed to a point,
## the pale wood showing. A sapling leaves none.
static func stump(look: int) -> ArrayMesh:
	if look == 0:
		return null
	if not _stumps.has(look):
		var b := Face.Builder.new()
		var r: float = Sim.RADIUS[look]
		var tones: Array = [Color("7a5236"), Color("63412a")] if look == 3 else TRUNK[look]
		var w := r * (0.16 if look == 3 else 0.13 * (0.82 if look == 1 else (1.25 if look == 2 else 1.0)))
		var flare := 1.0 if look == 3 else 2.3
		var waist := -r * 0.2
		var tip := Vector2(w * 0.15, -r * 0.4)
		var left := Face.Builder.bezier2(Vector2(-w * flare, 0.0), Vector2(-w * 1.05, -r * 0.05), Vector2(-w, waist), 6)
		var right := Face.Builder.bezier2(Vector2(w, waist), Vector2(w * 1.05, -r * 0.05), Vector2(w * flare, 0.0), 6)
		var pts := left.duplicate()
		pts.append_array([Vector2(-w, waist), Vector2(w, waist)])
		pts.append_array(right)
		pts.append(Vector2(w * flare, 0.0))
		b.polygon(pts, tones[0])
		var dark := PackedVector2Array([Vector2(w * 0.25, waist)])
		dark.append_array(right)
		dark.append_array([Vector2(w * flare, 0.0), Vector2(w * 0.8, 0.0)])
		b.polygon(dark, tones[1])
		b.polygon(PackedVector2Array([Vector2(-w, waist), tip, Vector2(w, waist)]), PITH)
		b.polygon(PackedVector2Array([Vector2(w * 0.3, waist), tip, Vector2(w, waist)]), PITH.darkened(0.12))
		_stumps[look] = b.mesh()
	return _stumps[look]

## Half a trunk's width where a beaver bites it, as the tree is drawn.
static func girth(look: int) -> float:
	var r: float = Sim.RADIUS[look]
	match look:
		0:
			return 3.0 * TREE
		3:
			return r * 0.16 * TREE
	return r * 0.13 * (0.82 if look == 1 else (1.25 if look == 2 else 1.0)) * 1.2 * TREE

static func _tree_into(b: Face.Builder, look: int, r: float) -> void:
	match look:
		0:
			var stem := Face.Builder.bezier2(Vector2.ZERO, Vector2(-r * 0.16, -r * 0.7), Vector2(r * 0.03, -r * 1.4), 8)
			stem.append(Vector2(r * 0.03, -r * 1.4))
			b.stroke(stem, 6.0, Color("6f9f3e"))
			for side: float in [-1.0, 1.0]:
				var at := Vector2(side * r * 0.5, -r * (1.2 if side < 0.0 else 1.4))
				_leaf(b, at, r * 0.55, r * 0.3, -side * 0.5, Color("83bf5a"))
				_leaf(b, at + Vector2(-r * 0.05, -r * 0.07), r * 0.42, r * 0.19, -side * 0.5, Color("a4d86f"))
				b.stroke(PackedVector2Array([at - Vector2(side * r * 0.36, -r * 0.2), at + Vector2(side * r * 0.3, -r * 0.16)]), 2.0, Color("6f9f3e"))
			b.disc(Vector2(r * 0.07, -r * 1.76), r * 0.5, Color("86c05a"))
			b.disc(Vector2(0.0, -r * 1.8), r * 0.47, Color("a6d96e"))
			b.disc(Vector2(-r * 0.14, -r * 1.94), r * 0.2, Color("cdf09a"))
		3:
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.16, -r * 0.7), Vector2(r * 0.32, r * 0.7), 4.0), Color("7a5236"))
			b.polygon(Face.Builder.round_rect(Vector2(r * 0.03, -r * 0.7), Vector2(r * 0.13, r * 0.7), 4.0), Color("63412a"))
			_tier(b, r, -r * 0.45, r * 1.0, r * 1.1, Color("3a785a"), Color("4b8f6b"))
			b.ellipse(Vector2(r * 0.05, -r * 1.1), r * 0.6, r * 0.13, Color("2f6a4c"))
			_tier(b, r, -r * 1.2, r * 0.8, r * 1.0, Color("44866a"), Color("569c79"))
			b.ellipse(Vector2(r * 0.04, -r * 1.78), r * 0.42, r * 0.1, Color("397758"))
			_tier(b, r, -r * 1.85, r * 0.58, r * 0.95, Color("4f9370"), Color("67ad88"))
		_:
			var stout := 0.82 if look == 1 else (1.25 if look == 2 else 1.0)
			_trunk(b, r, TRUNK[look], stout)
			if look == 1:
				for m: Array in [[-0.9, -0.34, 0.9], [0.2, -0.62, 0.8], [-0.7, -0.9, 0.7]]:
					var w := r * 0.13 * stout
					b.polygon(Face.Builder.round_rect(Vector2(w * float(m[0]), r * float(m[1])), Vector2(w * float(m[2]), 3.6), 1.8), Color("6e6057"))
			_crown(b, r, CROWN[look], 0.9 if look == 1 else (1.08 if look == 2 else 1.0), look)
			if look == 4:
				for o: Vector2 in [Vector2(-0.7, -1.25), Vector2(0.5, -1.62), Vector2(0.1, -2.12), Vector2(0.78, -1.14),
						Vector2(-0.34, -1.72), Vector2(0.28, -1.28), Vector2(-0.92, -1.56)]:
					b.disc(o * r, r * 0.075, Color("fff6e6"))
				# petals it has dropped
				for o: Vector2 in [Vector2(-0.86, 0.1), Vector2(0.72, 0.16), Vector2(0.34, 0.26), Vector2(-0.4, 0.24)]:
					b.ellipse(o * r, r * 0.07, r * 0.045, Color("f7b9d2"))

## A trunk up to where the crown hides it: flared at the foot, forked at the
## top, the side away from the light a tone darker.
static func _trunk(b: Face.Builder, r: float, tones: Array, stout: float) -> void:
	var w := r * 0.13 * stout
	var top := -r * 1.3
	var waist := -r * 0.5
	var right := Face.Builder.bezier2(Vector2(w, waist), Vector2(w * 1.05, -r * 0.06), Vector2(w * 2.3, 0.0), 8)
	var pts := Face.Builder.bezier2(Vector2(-w * 2.3, 0.0), Vector2(-w * 1.05, -r * 0.06), Vector2(-w, waist), 8)
	pts.append_array([Vector2(-w, waist), Vector2(-w * 0.8, top), Vector2(w * 0.8, top)])
	pts.append_array(right)
	pts.append(Vector2(w * 2.3, 0.0))
	b.polygon(pts, tones[0])
	var shade := PackedVector2Array([Vector2(w * 0.1, top), Vector2(w * 0.8, top)])
	shade.append_array(right)
	shade.append_array([Vector2(w * 2.3, 0.0), Vector2(w * 0.8, 0.0), Vector2(w * 0.25, waist)])
	b.polygon(shade, tones[1])
	b.stroke(PackedVector2Array([Vector2(0.0, -r * 1.0), Vector2(-r * 0.4, -r * 1.5)]), w * 1.1, tones[0])
	b.stroke(PackedVector2Array([Vector2(0.0, -r * 1.05), Vector2(r * 0.38, -r * 1.48)]), w * 1.1, tones[1])

## A crown about (0, -1.7 r), `wide` times as broad: its shade showing under
## it, its body, the side the light is on and the brightest clumps, then
## leaves of one tone dabbed over another so no edge between them is clean.
static func _crown(b: Face.Builder, r: float, tones: Array, wide: float, seed: int) -> void:
	var layers := [
		[[-0.56, -1.2, 0.54], [0.6, -1.18, 0.54], [0.03, -1.16, 0.54]],
		[[-0.68, -1.44, 0.6], [0.7, -1.42, 0.58], [-0.3, -1.95, 0.66], [0.38, -1.9, 0.64], [0.0, -1.5, 0.7]],
		[[-0.56, -1.58, 0.5], [0.3, -1.66, 0.5], [-0.16, -2.02, 0.56], [-0.08, -1.56, 0.52]],
		[[-0.44, -2.1, 0.25], [-0.76, -1.66, 0.19], [0.1, -2.26, 0.17], [0.3, -1.78, 0.16]],
	]
	for i in layers.size():
		for d: Array in layers[i]:
			b.disc(Vector2(float(d[0]) * wide, float(d[1])) * r, float(d[2]) * r, tones[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + seed
	var dabs := [
		[2, [[0.62, -1.5], [0.84, -1.34], [0.56, -2.0], [0.3, -1.28], [0.78, -1.78], [-0.24, -1.16], [0.08, -1.22]]],
		[1, [[-0.3, -1.7], [0.08, -1.86], [-0.56, -1.38], [0.02, -1.44], [0.36, -1.5]]],
		[3, [[-0.2, -1.78], [-0.64, -1.9], [0.22, -2.06], [-0.9, -1.46], [0.5, -1.72]]],
	]
	for group: Array in dabs:
		for d: Array in group[1]:
			_leaf(b, Vector2(float(d[0]) * wide, float(d[1])) * r, r * rng.randf_range(0.1, 0.15), r * rng.randf_range(0.055, 0.08),
				rng.randf_range(-0.9, 0.9), tones[int(group[0])])

## One skirt of the pine: a foot that hangs in three scallops, drawn up to a
## point, its left side `lit`.
static func _tier(b: Face.Builder, r: float, foot: float, half: float, high: float, colour: Color, lit: Color) -> void:
	var pts := PackedVector2Array()
	for i in 3:
		var x0 := lerpf(-half, half, i / 3.0)
		var x1 := lerpf(-half, half, (i + 1) / 3.0)
		pts.append_array(Face.Builder.bezier2(Vector2(x0, foot), Vector2((x0 + x1) * 0.5, foot + r * 0.24), Vector2(x1, foot), 6))
	pts.append(Vector2(half, foot))
	pts.append(Vector2(r * 0.1, foot - high))
	pts.append(Vector2(-r * 0.1, foot - high))
	b.polygon(pts, colour)
	b.polygon(PackedVector2Array([Vector2(-half, foot), Vector2(-half * 0.36, foot + r * 0.02),
		Vector2(-r * 0.01, foot - high * 0.94), Vector2(-r * 0.1, foot - high)]), lit)

static func _leaf(b: Face.Builder, centre: Vector2, rx: float, ry: float, turn: float, colour: Color) -> void:
	var xf := Transform2D(turn, centre)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, rx, ry), colour)

# --- the wind ---

## The material that leans what a Control draws: trees, or (`grass`) what is
## a hand high. One of each, shared by every screen that shows the land.
static func wind(grass := false) -> ShaderMaterial:
	if not _winds.has(grass):
		var m := ShaderMaterial.new()
		m.shader = WIND
		m.set_shader_parameter("tall", 14.0 if grass else 120.0)
		m.set_shader_parameter("reach", 2.6 if grass else 9.0)
		m.set_shader_parameter("rustle", 0.0 if grass else 1.2)
		_winds[grass] = m
	return _winds[grass]

## Called every frame by whatever shows the land: the wind's clock, and none
## of it under reduce motion. Returns the clock, for `gust`.
static func blow() -> float:
	var t := Time.get_ticks_msec() / 1000.0
	var all: Array = [wind(false), wind(true)]
	var live: Array[WeakRef] = []
	for ref in _shade_winds:
		var m: ShaderMaterial = ref.get_ref()
		if m != null:
			all.append(m)
			live.append(ref)
	_shade_winds = live
	for m: ShaderMaterial in all:
		m.set_shader_parameter("clock", t)
		m.set_shader_parameter("amp", 0.0 if Motion.reduce else 1.0)
	return t

## How hard it blows (0 to 1) at `x` across the screen at `t`: the shader's
## own gust, for what the screen moves by hand.
static func gust(x: float, t: float) -> float:
	return 0.5 + 0.5 * sin(t * 0.55 - x * 0.0035 + 1.7 * sin(t * 0.19))

## A tuft of grass on (0, 0): four thin blades, each to its own lean, in
## greys the instance's colour tints.
static func tuft() -> ArrayMesh:
	if _tuft == null:
		var b := Face.Builder.new()
		for bl: Array in [[-4.5, -4.5, 9.0, 0.93], [-1.5, -1.0, 14.0, 1.0], [1.5, 3.0, 11.0, 0.9], [4.5, 6.5, 7.0, 0.96]]:
			var x: float = bl[0]
			var lean: float = bl[1]
			var high: float = bl[2]
			var g: float = bl[3]
			b.polygon(PackedVector2Array([Vector2(x - 1.7, 0.0), Vector2(x - 1.2 + lean * 0.35, -high * 0.55), Vector2(x + lean, -high),
				Vector2(x + 1.2 + lean * 0.45, -high * 0.5), Vector2(x + 1.7, 0.0)]), Color(g, g, g))
		_tuft = b.mesh()
	return _tuft

## A flower on (0, 0): a stem, a leaf and five petals round a yellow eye.
static func flower() -> ArrayMesh:
	if _flower == null:
		var b := Face.Builder.new()
		var head := Vector2(1.5, -15.0)
		b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(-0.6, -8.0), head]), 2.4, Color("7fae4a"))
		_leaf(b, Vector2(-3.4, -6.0), 3.6, 1.7, 0.5, Color("8cc152"))
		for i in 5:
			b.disc(head + Vector2.from_angle(TAU * i / 5.0 - 0.3) * 3.6, 3.1, Color("fffaf0"))
		b.disc(head, 2.6, Pal.SUN)
		_flower = b.mesh()
	return _flower

## A loose leaf about (0, 0), pale, for the instance's colour to tint.
static func leaf() -> ArrayMesh:
	if _leaf_mesh == null:
		var b := Face.Builder.new()
		_leaf(b, Vector2.ZERO, 6.0, 3.2, 0.0, Color.WHITE)
		b.stroke(PackedVector2Array([Vector2(-4.5, 0.0), Vector2(4.5, 0.0)]), 1.0, Color(0.82, 0.82, 0.82))
		_leaf_mesh = b.mesh()
	return _leaf_mesh

## The grass that stands on the land seen from `origin` at `u` pixels a
## unit: its tufts, and its flowers in a few drifts, a MultiMesh each, for a
## Control wearing `wind(true)` to draw over the ground. The same every time.
static func grass(origin: Vector2, u: float) -> Array[MultiMesh]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var spots := [[], []]
	while spots[0].size() < 84:
		var p := _on_land(rng, 34.0)
		spots[0].append(origin + see(p) * u)
	for drift in 8:
		var c := _on_land(rng, 90.0)
		for i in rng.randi_range(3, 5):
			spots[1].append(origin + see(c + Vector2(rng.randf_range(-52.0, 52.0), rng.randf_range(-52.0, 52.0))) * u)
	var out: Array[MultiMesh] = []
	for kind in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = tuft() if kind == 0 else flower()
		mm.instance_count = spots[kind].size()
		var tints: Array = TUFTS if kind == 0 else PETALS
		for i in spots[kind].size():
			var s := rng.randf_range(0.8, 1.25) * u
			var flip := -1.0 if rng.randf() < 0.5 else 1.0
			mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(s * flip, s), 0.0, spots[kind][i]))
			mm.set_instance_color(i, tints[rng.randi() % tints.size()])
		out.append(mm)
	return out

## How tall a tree of `look` stands above its foot, for what is drawn over it.
static func height(look: int) -> float:
	var r: float = Sim.RADIUS[look]
	return r * (2.3 if look == 0 else (2.8 if look == 3 else 2.6))

# --- how the land is seen ---

## A point of the ground, in view units.
static func see(p: Vector2) -> Vector2:
	return Vector2(p.x, p.y * DEEP)

## The circle, `r` pixels across its half, about `c` on a screen: one lying
## on the ground, so as much flatter than wide as the ground is seen deep.
static func oval(c: Vector2, r: float, n := 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = c + Vector2(cos(a) * r, sin(a) * r * DEEP)
	return pts

## The land's edge in view units, clockwise from its back corner: a square
## of ground seen corner on, each corner rounded off.
static func outline() -> PackedVector2Array:
	if _outline.is_empty():
		var h := Sim.HALF
		var corners := [see(Vector2(h, 0.0)), see(Vector2(h * 2.0, h)), see(Vector2(h, h * 2.0)), see(Vector2(0.0, h))]
		for i in 4:
			var c: Vector2 = corners[i]
			var r := ROUND * (1.0 if i % 2 == 1 else 1.5)
			var from := c + ((corners[(i + 3) % 4] as Vector2) - c).normalized() * r
			var to := c + ((corners[(i + 1) % 4] as Vector2) - c).normalized() * r
			_outline.append_array(Face.Builder.bezier2(from, c, to, 14))
			_outline.append(to)
	return _outline

## The edge the earth shows under, from the land's right corner round its
## front to its left, and how far each point of it looks away from the sun
## (0 lit, 1 in shade): a face that looks left is lit, the corner between
## goes over from one to the other.
static func _front() -> Array:
	var o := outline()
	var n := o.size()
	var hi := 0
	var lo := 0
	for i in n:
		if o[i].x > o[hi].x:
			hi = i
		if o[i].x < o[lo].x:
			lo = i
	var pts := PackedVector2Array()
	var shade := PackedFloat32Array()
	var i := hi
	while true:
		pts.append(o[i])
		var d := (o[(i + 1) % n] - o[(i + n - 1) % n]).normalized()
		shade.append(smoothstep(0.0, 1.0, clampf(0.5 + d.y * 1.4, 0.0, 1.0)))
		if i == lo:
			break
		i = (i + 1) % n
	return [pts, shade]

## A point of the ground at least `inside` from the land's edge.
static func _on_land(rng: RandomNumberGenerator, inside: float) -> Vector2:
	var h := Sim.HALF
	var most := h - inside * sqrt(2.0)
	for attempt in 40:
		var d := Vector2(rng.randf_range(-most, most), rng.randf_range(-most, most))
		if absf(d.x) + absf(d.y) <= most and maxf(absf(d.x), absf(d.y)) <= h - inside - 80.0:
			return Vector2(h, h) + d
	return Vector2(h, h)

## Whether a point of the view is open water: no grass and no earth there,
## nor the land's mirror under its foot.
static func _wet(v: Vector2) -> bool:
	var o := outline()
	for k in 6:
		if Geometry2D.is_point_in_polygon(v - Vector2(0.0, (DEPTH + 56.0) * k / 5.0), o):
			return false
	return true

## A patch of soft colour: `alpha` at its middle, nothing at its edge.
static func _glow(b: Face.Builder, c: Vector2, rx: float, ry: float, colour: Color, alpha: float) -> void:
	var n := 28
	var mid := b.vertex(c, Color(colour, alpha))
	var first := b.verts.size()
	for ring: Array in [[0.55, alpha * 0.48], [1.0, 0.0]]:
		for i in n:
			var a := TAU * i / n
			b.vertex(c + Vector2(cos(a) * rx, sin(a) * ry) * float(ring[0]), Color(colour, ring[1]))
	for i in n:
		var j := (i + 1) % n
		b.tri(mid, first + i, first + j)
		b.tri(first + i, first + n + i, first + n + j)
		b.tri(first + i, first + n + j, first + j)

## A band between two rows of points, each point with its own colours.
static func _band(b: Face.Builder, top: PackedVector2Array, foot: PackedVector2Array, top_c: PackedColorArray, foot_c: PackedColorArray) -> void:
	var first := b.verts.size()
	for i in top.size():
		b.vertex(top[i], top_c[i])
		b.vertex(foot[i], foot_c[i])
	for i in top.size() - 1:
		var k := first + i * 2
		b.tri(k, k + 2, k + 3)
		b.tri(k, k + 3, k + 1)

## The pond and the land in it, for a field of `size` with the view's (0, 0)
## at `origin` and `u` pixels a unit: the still part of the screen, one mesh.
static func ground(size: Vector2, origin: Vector2, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	_water_into(b, size, origin, u, rng)
	_land_into(b, origin, u, rng)
	return b.mesh()

## The pond: pale at the top of the field, deep at its foot, the clouds of a
## slow sky lying soft on it, the light on a ripple here and there, lilies
## in twos and threes flat on the water, one of them in flower, and a stone.
static func _water_into(b: Face.Builder, size: Vector2, origin: Vector2, u: float, rng: RandomNumberGenerator) -> void:
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, 36.0), WATER_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, Vector2(size.x, minf(size.y, 90.0)), 36.0), WATER_FAR)
	if size.y > 100.0:
		var rows := [[40.0, WATER_FAR], [lerpf(40.0, size.y - 40.0, 0.5), WATER], [size.y - 40.0, WATER_DEEP]]
		for i in 2:
			var v0 := b.vertex(Vector2(0.0, rows[i][0]), rows[i][1])
			var v1 := b.vertex(Vector2(size.x, rows[i][0]), rows[i][1])
			var v2 := b.vertex(Vector2(size.x, rows[i + 1][0]), rows[i + 1][1])
			var v3 := b.vertex(Vector2(0.0, rows[i + 1][0]), rows[i + 1][1])
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	var open := func(at: Vector2, wide: float) -> bool:
		for o: Vector2 in [Vector2(-wide, 0.0), Vector2.ZERO, Vector2(wide, 0.0), Vector2(0.0, -wide * 0.5), Vector2(0.0, wide * 0.5)]:
			var p := at + o
			if p.x < 16.0 or p.x > size.x - 16.0 or p.y < 16.0 or p.y > size.y - 16.0 or not _wet((p - origin) / u):
				return false
		return true
	for i in 7:
		var at := Vector2(rng.randf_range(size.x * 0.1, size.x * 0.9), rng.randf_range(size.y * 0.06, size.y * 0.94))
		var s := rng.randf_range(0.7, 1.3) * u
		for o: Array in [[0, 0, 190, 44], [-120, 12, 130, 30], [130, 14, 140, 32], [30, -20, 110, 30]]:
			_glow(b, at + Vector2(o[0], o[1]) * s, float(o[2]) * s, float(o[3]) * s, Color.WHITE, 0.15)
	for i in 30:
		var at := Vector2(rng.randf_range(30.0, size.x - 90.0), rng.randf_range(24.0, size.y - 24.0))
		var long := rng.randf_range(18.0, 46.0)
		if open.call(at + Vector2(long * 0.5, 0.0), long * 0.5 + 12.0):
			b.stroke(PackedVector2Array([at, at + Vector2(long, 0.0)]), 3.2, Color(RIPPLE, rng.randf_range(0.22, 0.55)))
	var groups := 0
	for attempt in 80:
		if groups >= 5:
			break
		var at := Vector2(rng.randf_range(40.0, size.x - 40.0), rng.randf_range(40.0, size.y - 40.0))
		if not open.call(at, 74.0 * u):
			continue
		groups += 1
		if groups == 3:
			b.ellipse(at + Vector2(6.0, 12.0) * u, 34.0 * u, 10.0 * u, SHADE)
			b.ellipse(at, 30.0 * u, 18.0 * u, Pal.ROCK)
			b.ellipse(at + Vector2(-8.0, -6.0) * u, 14.0 * u, 7.0 * u, Color("d8cdb6"))
			b.ellipse(at + Vector2(34.0, 10.0) * u, 13.0 * u, 8.0 * u, Pal.ROCK)
			continue
		var pads := rng.randi_range(2, 3)
		for i in pads:
			var c := at + Vector2.from_angle(TAU * i / pads + rng.randf()) * Vector2(58.0, 34.0) * u * (0.0 if i == 0 else 1.0)
			var r := rng.randf_range(28.0, 38.0) * u * (1.0 if i == 0 else 0.74)
			_lily(b, c, r, rng.randf_range(0.0, TAU))
			if i == 0 and groups % 2 == 1:
				for k in 6:
					b.ellipse(c + Vector2(cos(TAU * k / 6.0) * 6.0, sin(TAU * k / 6.0) * 3.4 - 4.0) * u, 5.4 * u, 3.6 * u, Color("fbd0e2"))
				b.ellipse(c + Vector2(0.0, -4.5) * u, 3.6 * u, 2.6 * u, Color("fff0b8"))

## The land: its mirror on the pond, the earth and the clay under it from
## the lit left round to the shaded right, a pale line and rings where they
## meet the water, turf hanging over, then the grass in one piece with a
## wash of warm and cool on it, the sun on its near edges, and the small
## things: combed strokes, pale dabs, a pebble.
static func _land_into(b: Face.Builder, origin: Vector2, u: float, rng: RandomNumberGenerator) -> void:
	var front: Array = _front()
	var edge: PackedVector2Array = front[0]
	var shade: PackedFloat32Array = front[1]
	var n := edge.size()
	var row := func(down: float, wave := 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		pts.resize(n)
		for i in n:
			pts[i] = origin + (edge[i] + Vector2(0.0, down + wave * (sin(i * 0.9) + 0.6 * sin(i * 0.37 + 1.0)))) * u
		return pts
	var tint := func(lit: Color, dark: Color, alpha := 1.0) -> PackedColorArray:
		var cs := PackedColorArray()
		cs.resize(n)
		for i in n:
			cs[i] = Color(lit.lerp(dark, shade[i]), alpha)
		return cs
	var dark := Color(0.07, 0.27, 0.33)
	_band(b, row.call(DEPTH - 2.0), row.call(DEPTH + 58.0), tint.call(dark, dark, 0.34), tint.call(dark, dark, 0.0))
	var waist: PackedVector2Array = row.call(DEPTH * 0.5, DEPTH * 0.05)
	_band(b, row.call(0.0), waist, tint.call(EARTH[0], EARTH_SHADE[0]), tint.call(EARTH[1], EARTH_SHADE[1]))
	_band(b, waist, row.call(DEPTH), tint.call(CLAY[0], CLAY_SHADE[0]), tint.call(CLAY[1], CLAY_SHADE[1]))
	b.stroke(waist.slice(1, n - 1), 3.0 * u, SEAM)
	for i in 14:
		var k := rng.randi_range(3, n - 5)
		var at: Vector2 = origin + (edge[k] + Vector2(0.0, DEPTH * rng.randf_range(0.16, 0.36))) * u
		b.stroke(PackedVector2Array([at, origin + (edge[k + 1] + Vector2(0.0, at.y / u - origin.y / u - edge[k].y)) * u]), 2.4 * u, Color(SEAM, 0.2))
	for i in 9:
		var k := rng.randi_range(2, n - 3)
		var at: Vector2 = origin + (edge[k] + Vector2(0.0, DEPTH * rng.randf_range(0.6, 0.8))) * u
		var s := rng.randf_range(0.8, 1.3) * u
		b.ellipse(at, 11.0 * s, 7.0 * s, STONE.lerp(STONE_SHADE, shade[k]))
		if shade[k] < 0.5:
			b.ellipse(at + Vector2(-3.0, -2.0) * s, 5.0 * s, 3.0 * s, Color("f1e6cf"))
	_band(b, row.call(DEPTH - 20.0), row.call(DEPTH), tint.call(dark, dark, 0.0), tint.call(dark, dark, 0.3))
	b.stroke(row.call(DEPTH).slice(1, n - 1), 3.6 * u, Color(1.0, 1.0, 1.0, 0.72))
	# rings going out from the foot, broken
	var middle := see(Sim.LAND * 0.5)
	for ring in 2:
		var i := rng.randi_range(1, 4)
		while i < n - 3:
			var long := rng.randi_range(3, 6)
			var dash := PackedVector2Array()
			for k in range(i, mini(n - 1, i + long)):
				dash.append(origin + (middle + (edge[k] - middle) * (1.035 + 0.04 * ring) + Vector2(0.0, DEPTH + 5.0 + 3.0 * ring)) * u)
			if dash.size() > 1:
				b.stroke(dash, 2.6 * u, Color(1.0, 1.0, 1.0, 0.3 - 0.13 * ring))
			i += long + rng.randi_range(4, 9)
	# the turf, hanging over the earth in scallops
	_band(b, row.call(-1.0), row.call(12.0), tint.call(LIP_LIT, LIP), tint.call(LIP_LIT, LIP))
	for i in n - 1:
		var steps := maxi(1, int(edge[i].distance_to(edge[i + 1]) / 13.0))
		for k in steps:
			var t := float(k) / steps
			var at: Vector2 = origin + (edge[i].lerp(edge[i + 1], t) + Vector2(0.0, 11.0)) * u
			b.disc(at, rng.randf_range(6.5, 11.0) * u, LIP_LIT.lerp(LIP, lerpf(shade[i], shade[i + 1], t)))
	var top := PackedVector2Array()
	for p in outline():
		top.append(origin + p * u)
	b.polygon(top, GRASS)
	# the wash: warm toward the sun, cool away from it, and patches of both
	var h := Sim.HALF
	_glow(b, origin + see(Vector2(h - 105.0, h - 105.0)) * u, 215.0 * u, 215.0 * DEEP * u, WASH_WARM, 0.5)
	_glow(b, origin + see(Vector2(h + 110.0, h + 110.0)) * u, 205.0 * u, 205.0 * DEEP * u, WASH_COOL, 0.34)
	for i in 16:
		var r := rng.randf_range(90.0, 190.0)
		var p := _on_land(rng, r * 1.06)
		var sunny := (2.0 * h - p.x - p.y) / h
		if rng.randf() < 0.5 + 0.4 * sunny:
			_glow(b, origin + see(p) * u, r * u, r * DEEP * u, WASH_WARM, rng.randf_range(0.3, 0.5))
		else:
			_glow(b, origin + see(p) * u, r * u, r * DEEP * u, WASH_COOL, rng.randf_range(0.2, 0.34))
	# the sun on the near edge it looks at, and along the back of the land
	var lit := PackedVector2Array()
	for i in n:
		if shade[i] < 0.3 and i > 2:
			lit.append(origin + (edge[i] + Vector2(0.0, -4.0)) * u)
	if lit.size() > 3:
		b.stroke(lit.slice(0, lit.size() - 2), 3.4 * u, Color(0.94, 0.97, 0.7, 0.5))
	var o := outline()
	var back := PackedVector2Array()
	for i in o.size():
		if o[i].x < h * 0.92 and o[i].y < h * DEEP - 30.0:
			back.append(origin + (o[i] + Vector2(1.0, 2.5)) * u)
	if back.size() > 2:
		b.stroke(back, 2.6 * u, Color(0.9, 0.96, 0.66, 0.42))
	for i in 80:
		var at := origin + see(_on_land(rng, 30.0)) * u
		var long := rng.randf_range(8.0, 17.0) * u
		b.stroke(PackedVector2Array([at, at + Vector2(long, -long * 0.2)]), 2.6 * u, Color(GRASS_LIT, 0.6) if i % 2 else Color(GRASS_DEEP, 0.5))
	for i in 18:
		var r := rng.randf_range(22.0, 46.0)
		_glow(b, origin + see(_on_land(rng, r + 20.0)) * u, r * u, r * DEEP * u, WASH_WARM.lerp(GRASS_LIT, rng.randf()), 0.42)
	for i in 6:
		var at := origin + see(_on_land(rng, 40.0)) * u
		b.ellipse(at + Vector2(2.0, 3.0) * u, 9.0 * u, 4.6 * u, SHADE)
		b.ellipse(at, 8.0 * u, 5.4 * u, Pal.ROCK)
		b.ellipse(at + Vector2(-2.0, -1.8) * u, 3.6 * u, 2.2 * u, Color("d8cdb6"))

## What lies over the land and its trees: warm light from where the sun is,
## and the frame falling away a little toward its edges. One mesh for a
## field of `size`.
static func light(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	_glow(b, Vector2(size.x * 0.14, size.y * 0.08), size.length() * 0.8, size.length() * 0.8, Color(1.0, 0.9, 0.64), 0.2)
	var rim := Face.Builder.round_rect(Vector2.ZERO, size, 36.0)
	var centre := size * 0.5
	var start := b.verts.size()
	for p: Vector2 in rim:
		b.vertex(p, Color(0.07, 0.26, 0.33, 0.15))
		b.vertex(centre + (p - centre) * 0.66, Color(0.07, 0.26, 0.33, 0.0))
	var m := rim.size()
	for i in m:
		var j := (i + 1) % m
		b.tri(start + i * 2, start + j * 2, start + j * 2 + 1)
		b.tri(start + i * 2, start + j * 2 + 1, start + i * 2 + 1)
	return b.mesh()

## A lily pad lying flat on the pond, its shade on the water under it.
static func _lily(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var flat := Transform2D(0.0, Vector2(1.0, DEEP), 0.0, at)
	var pts := Face.Builder.arc_points(Vector2.ZERO, r, turn + 0.35, turn + 6.0)
	pts.append(Vector2.ZERO)
	b.polygon(Transform2D(0.0, Vector2(1.0, DEEP), 0.0, at + Vector2(1.0, 4.0)) * pts, Color(SHADE, 0.2))
	b.polygon(flat * pts, LILY)
	b.stroke(flat * Face.Builder.arc_points(Vector2.ZERO, r * 0.6, turn + 0.9, turn + 5.2), maxf(1.6, r * 0.09), LILY_HI)

## A log lying across (0, 0), LOG long: wood, on its way to the inventory.
static func log_mesh() -> ArrayMesh:
	if _log == null:
		var b := Face.Builder.new()
		_log_into(b, Vector2.ZERO, LOG)
		_log = b.mesh()
	return _log

static func _log_into(b: Face.Builder, at: Vector2, long: float) -> void:
	var s := long / 1.24
	b.polygon(Face.Builder.round_rect(at + Vector2(-s * 0.62, -s * 0.3), Vector2(s * 1.24, s * 0.6), s * 0.3), BARK)
	b.ellipse(at + Vector2(s * 0.4, 0.0), s * 0.2, s * 0.3, PITH)
	b.stroke(Face.Builder.ring(at + Vector2(s * 0.4, 0.0), s * 0.09, s * 0.14), s * 0.05, BARK, true)

## A tile's picture, about (0, 0). Seeds shows the tree its next level opens,
## so it takes that tree's `look`. Energy's is the mote itself.
static func icon(tile: String, look := 1) -> ArrayMesh:
	if tile == "energy":
		return Motes.orb()
	var key := "%s%d" % [tile, look if tile == "seeds" else 0]
	if _icons.has(key):
		return _icons[key]
	var b := Face.Builder.new()
	match tile:
		"axe":
			var xf := Transform2D(0.6, Vector2.ZERO)
			var handle := Face.Builder.round_rect(Vector2(-6.0, -44.0), Vector2(12.0, 92.0), 6.0)
			var head := PackedVector2Array([Vector2(-6.0, -40.0)])
			head.append_array(Face.Builder.bezier2(Vector2(-6.0, -40.0), Vector2(-46.0, -46.0), Vector2(-48.0, -8.0), 10))
			head.append_array(Face.Builder.bezier2(Vector2(-48.0, -8.0), Vector2(-26.0, -16.0), Vector2(-6.0, -10.0), 10))
			head.append(Vector2(-6.0, -10.0))
			var edge := Face.Builder.bezier2(Vector2(-40.0, -40.0), Vector2(-50.0, -26.0), Vector2(-48.0, -8.0), 8)
			b.polygon(xf * handle, BARK)
			b.polygon(xf * head, Color("9ba5ad"))
			b.stroke(xf * edge, 5.0, Color("d5dde3"))
		"reach":
			for i in 10:
				var a := TAU * i / 10.0
				b.stroke(Face.Builder.arc_points(Vector2.ZERO, 42.0, a, a + 0.36), 5.0, Pal.TEXT_DIM)
			b.disc(Vector2.ZERO, 22.0, Pal.SUN)
			b.disc(Vector2.ZERO, 16.0, Color("fde3b0"))
		"swing":
			for r: float in [20.0, 34.0, 48.0]:
				b.stroke(Face.Builder.arc_points(Vector2(-18.0, 16.0), r, -1.5, -0.1), 7.0, Pal.SUN)
		"sprout":
			b.ellipse(Vector2(0.0, 30.0), 44.0, 13.0, Color("8f6b47"))
			b.append(_bare(0), Transform2D(0.0, Vector2(1.5, 1.5), 0.0, Vector2(0.0, 28.0)))
		"room":
			b.append(_bare(1), Transform2D(0.0, Vector2(0.62, 0.62), 0.0, Vector2(-30.0, 34.0)))
			b.append(_bare(1), Transform2D(0.0, Vector2(0.62, 0.62), 0.0, Vector2(30.0, 34.0)))
			b.append(_bare(1), Transform2D(0.0, Vector2(0.78, 0.78), 0.0, Vector2(0.0, 44.0)))
		"seeds":
			var s: float = 40.0 / Sim.RADIUS[look]
			b.append(_bare(look), Transform2D(0.0, Vector2(s, s), 0.0, Vector2(0.0, 44.0)))
		"wood":
			_log_into(b, Vector2.ZERO, 64.0)
		_:
			_node_into(b, tile)
	_icons[key] = b.mesh()
	return _icons[key]

## The pictures of the tree's nodes (valley/grove_tree.gd), each about (0, 0)
## inside ICON like a tile's: the two boughs every kind has (`soft`, `rich`)
## and the roots' nodes by id. Room and Sprout are the tiles they were.
static func _node_into(b: Face.Builder, id: String) -> void:
	match id:
		"soft":
			# a feather: wood that gives way
			var turn := Transform2D(0.62, Vector2(2.0, 4.0))
			b.stroke(turn * PackedVector2Array([Vector2(0.0, 30.0), Vector2(0.0, 52.0)]), 5.0, Pal.CLOUD_DEEP)
			b.fan(turn * Face.Builder.ring(Vector2(0.0, -8.0), 21.0, 44.0), Pal.CLOUD)
			var lit := PackedVector2Array()
			for p: Vector2 in Face.Builder.ring(Vector2(0.0, -8.0), 21.0, 44.0):
				if p.x <= 0.5:
					lit.append(p)
			b.polygon(turn * lit, Pal.CLOUD_TILE)
			b.stroke(turn * PackedVector2Array([Vector2(0.0, -46.0), Vector2(0.0, 34.0)]), 3.4, Pal.CLOUD_DEEP)
			for y: float in [-22.0, 2.0, 22.0]:
				b.stroke(turn * PackedVector2Array([Vector2(1.0, y), Vector2(17.0, y - 11.0)]), 2.4, Pal.CLOUD_DEEP)
				b.stroke(turn * PackedVector2Array([Vector2(-1.0, y + 4.0), Vector2(-17.0, y - 7.0)]), 2.4, Pal.CLOUD)
		"rich":
			# a pile of logs and the light they hold
			_log_end(b, Vector2(-22.0, 22.0), 21.0)
			_log_end(b, Vector2(21.0, 22.0), 21.0)
			_log_end(b, Vector2(-1.0, -13.0), 21.0)
			b.append(Motes.orb(), Transform2D(0.0, Vector2(0.4, 0.4), 0.0, Vector2(32.0, -32.0)))
		"jetty":
			for w: Array in [[40.0, -44.0, 44.0, 6.0], [50.0, -30.0, 16.0, 4.5]]:
				b.stroke(PackedVector2Array([Vector2(w[1], w[0]), Vector2(w[2], w[0])]), w[3], WATER)
			for x: float in [-32.0, 28.0]:
				b.polygon(Face.Builder.round_rect(Vector2(x - 6.0, -30.0), Vector2(13.0, 70.0), 4.0), PLANK_DEEP)
				b.polygon(Face.Builder.round_rect(Vector2(x - 6.0, -30.0), Vector2(6.0, 70.0), 3.0), PLANK_DEEP.lightened(0.14))
			b.polygon(Face.Builder.round_rect(Vector2(-50.0, -6.0), Vector2(100.0, 9.0), 3.0), PLANK_DEEP.darkened(0.12))
			b.polygon(Face.Builder.round_rect(Vector2(-52.0, -22.0), Vector2(104.0, 19.0), 5.0), PLANK)
			b.polygon(Face.Builder.round_rect(Vector2(-52.0, -22.0), Vector2(104.0, 7.0), 3.5), PLANK.lightened(0.2))
			for x: float in [-26.0, 0.0, 26.0]:
				b.stroke(PackedVector2Array([Vector2(x, -20.0), Vector2(x, -5.0)]), 2.4, PLANK_DEEP, false, false)
		"tying":
			# a bow of rope
			for side: float in [-1.0, 1.0]:
				b.stroke(PackedVector2Array([Vector2(0.0, 4.0), Vector2(side * 14.0, 26.0), Vector2(side * 30.0, 40.0)]), 8.0, ROPE_DEEP)
				var loop := Transform2D(side * 0.5, Vector2(side * 25.0, -8.0)) * Face.Builder.ring(Vector2.ZERO, 22.0, 13.0)
				b.stroke(loop, 9.0, ROPE, true)
				b.stroke(Transform2D(side * 0.5, Vector2(side * 25.0, -8.0)) * Face.Builder.arc_points(Vector2.ZERO, 22.0, PI * 0.15, PI * 0.85), 3.0, ROPE_DEEP)
			b.polygon(Face.Builder.round_rect(Vector2(-11.0, -11.0), Vector2(22.0, 24.0), 8.0), ROPE_DEEP)
			b.polygon(Face.Builder.round_rect(Vector2(-11.0, -11.0), Vector2(22.0, 10.0), 6.0), ROPE)
		"bundle":
			_bundle_into(b, Vector2.ZERO, 1.0)
		"raft":
			_raft_into(b)
			b.stroke(PackedVector2Array([Vector2(-4.0, 12.0), Vector2(-4.0, -46.0)]), 5.5, PLANK_DEEP)
			b.polygon(PackedVector2Array([Vector2(0.0, -46.0), Vector2(38.0, -12.0), Vector2(0.0, -4.0)]), Color("fff6e6"))
			b.polygon(PackedVector2Array([Vector2(0.0, -24.0), Vector2(38.0, -12.0), Vector2(0.0, -4.0)]), Color("eadfc8"))
		"load":
			_raft_into(b)
			_bundle_into(b, Vector2(-21.0, 0.0), 0.44)
			_bundle_into(b, Vector2(21.0, 0.0), 0.44)
			_bundle_into(b, Vector2(0.0, -30.0), 0.44)
		"beaver":
			var s := 1.55
			var foot := Vector2(-4.0, 46.0)
			b.append(Beaver.tail(), Transform2D(-0.2, Vector2(s, s), 0.0, foot + Beaver.TAIL_AT * s))
			b.append(Beaver.body(), Transform2D(0.0, Vector2(s, s), 0.0, foot))
			b.append(Beaver.head(false), Transform2D(0.0, Vector2(s, s), 0.0, foot + Beaver.NECK * s))
		"teeth":
			# a beaver looked at from the front, all teeth
			for side: float in [-1.0, 1.0]:
				b.disc(Vector2(side * 33.0, -40.0), 11.0, Beaver.FUR_DEEP)
				b.disc(Vector2(side * 33.0, -39.0), 5.5, Beaver.EAR_IN)
			b.ellipse(Vector2(0.0, -12.0), 46.0, 38.0, Beaver.FUR)
			for side: float in [-1.0, 1.0]:
				b.disc(Vector2(side * 19.0, -24.0), 5.2, Beaver.NOSE)
				b.disc(Vector2(side * 19.0 - 1.6, -25.8), 1.7, Color.WHITE)
				b.disc(Vector2(side * 30.0, -6.0), 7.0, Color(Pal.CHEEK, 0.8))
				b.ellipse(Vector2(side * 13.0, 2.0), 17.0, 13.0, Beaver.BELLY)
			b.ellipse(Vector2(0.0, -9.0), 9.5, 6.5, Beaver.NOSE)
			b.polygon(Face.Builder.round_rect(Vector2(-17.0, 6.0), Vector2(34.0, 42.0), 8.0), Beaver.TOOTH_LINE)
			b.polygon(Face.Builder.round_rect(Vector2(-14.5, 6.0), Vector2(29.0, 39.5), 6.0), Beaver.TOOTH)
			b.stroke(PackedVector2Array([Vector2(0.0, 9.0), Vector2(0.0, 43.0)]), 2.4, Beaver.TOOTH_LINE, false, false)
		"crit":
			# the tile's axe turned about, its edge ground bright and a glint on it
			var xf := Transform2D(-0.55, Vector2(4.0, 6.0))
			b.polygon(xf * Face.Builder.round_rect(Vector2(-7.0, -50.0), Vector2(14.0, 100.0), 7.0), BARK)
			_blade(b, xf * Transform2D(0.0, Vector2(0.0, -12.0)), -1.0, 1.35)
			var glint := PackedVector2Array()
			for i in 8:
				glint.append(xf * (Vector2(-27.0, -30.0) + Vector2.from_angle(TAU * i / 8.0) * (15.0 if i % 2 == 0 else 4.2)))
			b.polygon(glint, Color.WHITE)
		"critsize":
			# two heads on one handle: a heavier axe
			var xf := Transform2D(0.0, Vector2(0.0, 0.0))
			b.polygon(xf * Face.Builder.round_rect(Vector2(-6.5, -46.0), Vector2(13.0, 98.0), 6.5), BARK)
			_blade(b, Transform2D(0.0, Vector2(-19.0, 3.0)), -1.0, 0.92)
			_blade(b, Transform2D(0.0, Vector2(19.0, 3.0)), 1.0, 0.92)
			b.polygon(Face.Builder.round_rect(Vector2(-9.0, -33.0), Vector2(18.0, 30.0), 4.0), STEEL_DEEP)
		"luck":
			_log_into(b, Vector2(0.0, 34.0), 84.0)
			b.stroke(PackedVector2Array([Vector2(2.0, -12.0), Vector2(8.0, 6.0), Vector2(4.0, 18.0)]), 5.0, CLOVER)
			for i in 4:
				var leaf := Transform2D(PI * 0.25 + PI * 0.5 * i, Vector2(0.0, -16.0))
				for side: float in [-1.0, 1.0]:
					b.disc(leaf * Vector2(side * 8.5, -15.0), 11.5, CLOVER)
				b.polygon(leaf * PackedVector2Array([Vector2(-17.0, -10.0), Vector2(17.0, -10.0), Vector2(0.0, 0.0)]), CLOVER)
			for i in 4:
				var leaf := Transform2D(PI * 0.25 + PI * 0.5 * i, Vector2(0.0, -16.0))
				b.disc(leaf * Vector2(-7.0, -17.0), 5.0, CLOVER_LIT)
		"crate":
			_crate_into(b, Vector2(0.0, 2.0), 1.0)
		"cratesize":
			for o: Array in [[-17.0, -30.0, 0.34], [15.0, -36.0, 0.4], [0.0, -18.0, 0.3]]:
				b.append(Motes.orb(), Transform2D(0.0, Vector2(o[2], o[2]), 0.0, Vector2(o[0], o[1])))
			_crate_into(b, Vector2(0.0, 20.0), 0.82)

## The end of a log, looked at along it.
static func _log_end(b: Face.Builder, at: Vector2, r: float) -> void:
	b.disc(at, r, BARK)
	b.disc(at, r * 0.76, PITH)
	b.stroke(Face.Builder.ring(at, r * 0.4, r * 0.4), r * 0.12, Color(BARK, 0.65), true)
	b.disc(at, r * 0.1, Color(BARK, 0.65))

## Three logs lying one on another, tied round twice.
static func _bundle_into(b: Face.Builder, at: Vector2, s: float) -> void:
	for row: Array in [[-2.0, -26.0], [3.0, 0.0], [-3.0, 26.0]]:
		var c := at + Vector2(row[0], row[1]) * s
		b.polygon(Face.Builder.round_rect(c + Vector2(-46.0, -12.5) * s, Vector2(92.0, 25.0) * s, 12.5 * s), BARK)
		b.polygon(Face.Builder.round_rect(c + Vector2(-38.0, -9.0) * s, Vector2(62.0, 6.0) * s, 3.0 * s), BARK.lightened(0.16))
		b.ellipse(c + Vector2(37.0, 0.0) * s, 7.0 * s, 10.5 * s, PITH)
	for x: float in [-22.0, 12.0]:
		b.polygon(Face.Builder.round_rect(at + Vector2(x - 5.0, -42.0) * s, Vector2(10.0, 84.0) * s, 5.0 * s), ROPE_DEEP)
		b.polygon(Face.Builder.round_rect(at + Vector2(x - 5.0, -42.0) * s, Vector2(5.0, 84.0) * s, 2.5 * s), ROPE)

## A raft on the water, seen along its logs.
static func _raft_into(b: Face.Builder) -> void:
	b.stroke(PackedVector2Array([Vector2(-50.0, 40.0), Vector2(50.0, 40.0)]), 6.0, WATER)
	b.stroke(PackedVector2Array([Vector2(-26.0, 50.0), Vector2(30.0, 50.0)]), 4.5, WATER)
	for i in 5:
		_log_end(b, Vector2(-40.0 + 20.0 * i, 26.0), 11.5)
	b.stroke(PackedVector2Array([Vector2(-48.0, 15.0), Vector2(48.0, 15.0)]), 4.0, ROPE_DEEP)

## An axe's head on a handle at x 0, its edge out to `side`, `s` times the
## tile's.
static func _blade(b: Face.Builder, xf: Transform2D, side: float, s: float) -> void:
	var flip := xf * Transform2D(Vector2(-side * s, 0.0), Vector2(0.0, s), Vector2.ZERO)
	var head := PackedVector2Array([Vector2(6.0, -30.0)])
	head.append_array(Face.Builder.bezier2(Vector2(6.0, -30.0), Vector2(-28.0, -40.0), Vector2(-34.0, 4.0), 10))
	head.append_array(Face.Builder.bezier2(Vector2(-34.0, 4.0), Vector2(-14.0, -4.0), Vector2(6.0, 0.0), 10))
	head.append(Vector2(6.0, 0.0))
	if side > 0.0:
		head.reverse()
	b.polygon(flip * head, STEEL)
	var edge := Face.Builder.bezier2(Vector2(-22.0, -30.0), Vector2(-33.0, -18.0), Vector2(-34.0, 4.0), 8)
	edge.append(Vector2(-34.0, 4.0))
	b.stroke(flip * edge, 7.0 * s, STEEL_LIT)
	b.stroke(flip * edge.slice(2, 7), 2.6 * s, Color.WHITE)

## A crate of boards about `at`.
static func _crate_into(b: Face.Builder, at: Vector2, s: float) -> void:
	b.polygon(Face.Builder.round_rect(at + Vector2(-40.0, -34.0) * s, Vector2(80.0, 70.0) * s, 8.0 * s), Pal.WOOD_DEEP)
	b.polygon(Face.Builder.round_rect(at + Vector2(-34.0, -28.0) * s, Vector2(68.0, 58.0) * s, 4.0 * s), Pal.WOOD)
	for y: float in [-9.0, 10.0]:
		b.stroke(PackedVector2Array([at + Vector2(-34.0, y) * s, at + Vector2(34.0, y) * s]), 2.6 * s, Pal.WOOD_DEEP, false, false)
	b.stroke(PackedVector2Array([at + Vector2(-31.0, 26.0) * s, at + Vector2(31.0, -26.0) * s]), 9.0 * s, Pal.WOOD_DEEP, false, false)
	b.stroke(PackedVector2Array([at + Vector2(-31.0, 26.0) * s, at + Vector2(31.0, -26.0) * s]), 4.5 * s, Pal.WOOD.lightened(0.12), false, false)
	b.polygon(Face.Builder.round_rect(at + Vector2(-43.0, -38.0) * s, Vector2(86.0, 13.0) * s, 5.0 * s), Pal.WOOD_DEEP)
	b.polygon(Face.Builder.round_rect(at + Vector2(-43.0, -38.0) * s, Vector2(86.0, 7.0) * s, 3.5 * s), Pal.WOOD.lightened(0.1))

## A tree for a picture.
static func _bare(look: int) -> ArrayMesh:
	return tree(look)

## Whether the language writes 0,47 for 0.47 (pt, es), and a line of figures
## as it does.
static func comma() -> bool:
	return not TranslationServer.get_locale().begins_with("en")

static func decimal(text: String) -> String:
	return text.replace(".", ",") if comma() else text

## What a chop takes, which may be a half: 1, 1.5, 2, 31.5, and past a
## thousand as `short` writes it. `comma` for a language that writes 1,5.
static func amount(v: float, comma := false) -> String:
	if v >= 1000.0 or is_equal_approx(v, roundf(v)):
		return short(roundi(v))
	var text := "%.1f" % v
	return text.replace(".", ",") if comma else text

## A count in a few characters: 999, 1.23K, 45.6K, 789K, 1.2M, and on
## through B, T and Q. Trees and tiles have no last level, so every number
## on the screen goes through here.
static func short(n: int) -> String:
	if n < 1000:
		return str(n)
	var v := float(n)
	var i := 0
	while v >= 1000.0 and i < 5:
		v /= 1000.0
		i += 1
	var text := ("%.2f" % v) if v < 10.0 else (("%.1f" % v) if v < 100.0 else ("%d" % int(v)))
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	return text + " KMBTQ"[i]

