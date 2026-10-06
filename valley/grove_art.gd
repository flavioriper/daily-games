extends RefCounted

## The Grove's drawings: the pond and the land seen in isometric (`see`,
## `ground`, `light`), the five trees, the log, and
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
const WIND := preload("res://shaders/wind_2d.gdshader")

## The painted land (2026-10-06, the isometric pass): the pond hazy far off
## and deep at the foot, grass in forest greens under a wash of warm light
## and cool shade, earth warm where it looks at the sun (upper left) and
## cool where it looks away, and a shadow that is a colour, never a grey.
const WATER_FAR := Color("a2ded6")
const WATER := Color("6cbfc0")
const WATER_DEEP := Color("3f97a3")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.42)
const LILY := Color("4f9f63")
const LILY_HI := Color("74c07e")
const GRASS_LIT := Color("98c862")
const GRASS_LOW := Color("5f9c55")
const WASH_WARM := Color("deec8a")
const WASH_COOL := Color("2c7060")
const LIP := Color("4d8748")
const LIP_LIT := Color("5f9d4d")
const EARTH := [Color("d2a56c"), Color("b17f4e")]
const EARTH_SHADE := [Color("93684a"), Color("74503c")]
const SEAM := Color(0.34, 0.2, 0.13, 0.26)
const STONE := Color("e0cfae")
const STONE_SHADE := Color("a98f76")
const SHADE := Color(0.09, 0.27, 0.34, 0.26)
const MIRROR := Color(0.08, 0.29, 0.35, 0.2)
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

## How the land is seen: a point of the ground lands across as it is and
## half as deep, lifted LIFT for every step it is on, in view units (land
## units as the screen lays them: a screen scales and places them). DEPTH is
## the earth showing over the water and VIEW the box the whole land takes.
const LIFT := Sim.RISE
const DEPTH := 68.0
const VIEW := Rect2(0.0, -96.0, 720.0, 1064.0)
## A tree is drawn this much over its footprint: seen from the side of the
## land, a crown only overlaps what is behind it.
const TREE := 1.25

static var _trees := {}
static var _icons := {}
static var _log: ArrayMesh
static var _tuft: ArrayMesh
static var _flower: ArrayMesh
static var _leaf_mesh: ArrayMesh
static var _winds := {}
static var _wash: Array = []

## A tree of `look` (0 sapling, 1 birch, 2 oak, 3 pine, 4 blossom) standing
## on (0, 0), its shade on the grass under it, in land units. Redrawn on
## 2026-10-06 (the user: "polish design of trees, grass, add some wind
## movement"): lit from the upper left, so a crown is a shade under it, a
## body, a lit side and a few bright clumps, with loose leaves dabbed across
## the tones, and a trunk flares at its foot and is darker down its right.
static func tree(look: int) -> ArrayMesh:
	if not _trees.has(look):
		var b := Face.Builder.new()
		var r: float = Sim.RADIUS[look]
		# the shadow it throws to its right, the sun being upper left, and a
		# darker foot under the trunk
		b.ellipse(Vector2(r * 0.5, r * 0.1), r * 1.2, r * 0.4, SHADE)
		b.ellipse(Vector2(r * 0.08, 1.0), r * 0.46, r * 0.16, Color(SHADE, 0.2))
		_tree_into(b, look, r)
		_trees[look] = b.mesh()
	return _trees[look]

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
	for grass: bool in [false, true]:
		var m := wind(grass)
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
## unit: its tufts and its flowers, a MultiMesh each, for a Control wearing
## `wind(true)` to draw over the ground. The same on the same tiles every time.
static func grass(origin: Vector2, u: float) -> Array[MultiMesh]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261006
	var land := Sim.land()
	var spots := [[], []]
	for t: Vector2i in _back_to_front():
		for kind in 2:
			for i in (2 if kind == 0 else 1):
				if rng.randf() > (0.42 if kind == 0 else 0.2):
					continue
				var dx := rng.randf_range(-0.5, 0.5) * Sim.TILE_HALF
				var dy := rng.randf_range(-0.5, 0.5) * (Sim.TILE_HALF - absf(dx))
				spots[kind].append(_put(Sim.centre_of(t) + Vector2(dx, dy), int(land[t]), origin, u))
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
	return Vector2(p.x, p.y * 0.5 - maxi(0, Sim.step_at(p)) * LIFT)

## The circle, `r` pixels across its half, about `c` on a screen: one lying
## on the ground, so half as tall as it is wide.
static func oval(c: Vector2, r: float, n := 72) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(n)
	for i in n:
		var a := TAU * i / n
		pts[i] = c + Vector2(cos(a) * r, sin(a) * r * 0.5)
	return pts

## A point of a tile on `step`, in a screen's pixels. A tile's corner is
## four tiles' corner, so the step is said, not looked up.
static func _put(p: Vector2, step: int, origin: Vector2, u: float, down := 0.0) -> Vector2:
	return origin + Vector2(p.x, p.y * 0.5 - step * LIFT + down) * u

static func _back_to_front() -> Array:
	var tiles := Sim.land().keys()
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return tiles

## Whether a point of the view is open water: no grass and no earth there,
## nor the land's mirror under its foot.
static func _wet(v: Vector2) -> bool:
	for step in Sim.STEPS:
		var y := v.y - DEPTH - 40.0
		while y <= v.y + step * LIFT:
			if Sim.step_at(Vector2(v.x, (y + step * LIFT) * 2.0)) == step:
				return false
			y += 14.0
	return true

## The grass's green at a point of the ground on `step`: lighter toward the
## sun and on a higher step, under a wash of warm and cool patches that
## takes no notice of the tiles. Tiles share their corners' colours, so the
## wash crosses them without a seam.
static func _tone(p: Vector2, step: int) -> Color:
	if _wash.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261007
		for i in 24:
			_wash.append([Vector2(rng.randf_range(-40.0, Sim.LAND.x + 40.0), rng.randf_range(0.0, Sim.LAND.y)),
				rng.randf_range(120.0, 270.0), i % 5 < 3])
	var sun := 0.55 - (p.x / Sim.LAND.x - 0.5) * 0.55 - (p.y / Sim.LAND.y - 0.5) * 0.5 + step * 0.07
	var c := GRASS_LOW.lerp(GRASS_LIT, clampf(0.24 + 0.6 * sun, 0.0, 1.0))
	for w: Array in _wash:
		var d := p.distance_to(w[0]) / float(w[1])
		if d >= 1.0:
			continue
		var f := pow(1.0 - d, 1.5)
		c = c.lerp(WASH_WARM, 0.6 * f) if w[2] else c.lerp(WASH_COOL, 0.4 * f)
	return c

## The pond and the land in it, for a field of `size` with the view's (0, 0)
## at `origin` and `u` pixels a unit: the still part of the screen, one mesh.
static func ground(size: Vector2, origin: Vector2, u: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	_water_into(b, size, origin, u, rng)
	_land_into(b, origin, u, rng)
	return b.mesh()

## The pond: pale and hazy at the top of the field, deep at its foot, with
## the clouds of a slow sky lying on it, lilies flat on the water, a stone
## or two and the light catching a ripple.
static func _water_into(b: Face.Builder, size: Vector2, origin: Vector2, u: float, rng: RandomNumberGenerator) -> void:
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, 36.0), WATER_DEEP)
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, Vector2(size.x, minf(size.y, 90.0)), 36.0), WATER_FAR)
	if size.y > 100.0:
		var rows := [[40.0, WATER_FAR], [lerpf(40.0, size.y - 40.0, 0.45), WATER], [size.y - 40.0, WATER_DEEP]]
		for i in 2:
			var v0 := b.vertex(Vector2(0.0, rows[i][0]), rows[i][1])
			var v1 := b.vertex(Vector2(size.x, rows[i][0]), rows[i][1])
			var v2 := b.vertex(Vector2(size.x, rows[i + 1][0]), rows[i + 1][1])
			var v3 := b.vertex(Vector2(0.0, rows[i + 1][0]), rows[i + 1][1])
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
	var open := func(at: Vector2, wide: float) -> bool:
		for dx: float in [-wide, 0.0, wide]:
			var p := at + Vector2(dx, 0.0)
			if p.x < 20.0 or p.x > size.x - 20.0 or not _wet((p - origin) / u):
				return false
		return true
	# clouds: a few pale ovals run together, anywhere, the land over them
	for i in 6:
		var at := Vector2(rng.randf_range(0.0, size.x), rng.randf_range(60.0, maxf(70.0, size.y - 120.0)))
		var s := rng.randf_range(0.6, 1.3) * u
		for o: Array in [[0, 0, 150, 34], [-110, 10, 100, 24], [120, 12, 110, 26], [30, -18, 90, 26], [-40, 18, 130, 22]]:
			var c := at + Vector2(o[0], o[1]) * s
			var rx: float = minf(float(o[2]) * s, minf(c.x, size.x - c.x) - 4.0)
			if rx > 20.0 and c.y - float(o[3]) * s > 4.0 and c.y + float(o[3]) * s < size.y - 4.0:
				b.ellipse(c, rx, float(o[3]) * s, Color(1.0, 1.0, 1.0, 0.085))
	for i in 26:
		var at := Vector2(rng.randf_range(30.0, size.x - 90.0), rng.randf_range(24.0, size.y - 24.0))
		var long := rng.randf_range(22.0, 50.0)
		if open.call(at + Vector2(long * 0.5, 0.0), long * 0.5 + 10.0):
			b.stroke(PackedVector2Array([at, at + Vector2(long, 0.0)]), 3.6, Color(RIPPLE, rng.randf_range(0.2, 0.5)))
	var laid := 0
	for i in 60:
		if laid >= 9:
			break
		var at := Vector2(rng.randf_range(34.0, size.x - 34.0), rng.randf_range(30.0, size.y - 30.0))
		var r := rng.randf_range(22.0, 32.0) * u
		if not open.call(at, r + 8.0):
			continue
		if laid % 5 == 4:
			b.ellipse(at + Vector2(5.0, 10.0) * u, 30.0 * u, 9.0 * u, SHADE)
			b.ellipse(at, 26.0 * u, 15.0 * u, Pal.ROCK)
			b.ellipse(at + Vector2(-7.0, -5.0) * u, 12.0 * u, 6.0 * u, Color("d2c6ae"))
		else:
			_lily(b, at, r, rng.randf_range(0.0, TAU))
		laid += 1

## The land, tile by tile from the back: the pond's mirror under its foot,
## each top with the earth it shows (left faces lit, right ones in shade, a
## seam and a stone in them, turf hanging over, a pale line where they meet
## the water), the shadow a step throws on the one below, and dabs of
## lighter grass.
static func _land_into(b: Face.Builder, origin: Vector2, u: float, rng: RandomNumberGenerator) -> void:
	var land := Sim.land()
	var tiles := _back_to_front()
	var a := Sim.TILE_HALF
	var px := u / 1.34   # the concept page's pixels
	var drop := func(step: int, t: Vector2i) -> float:
		return (step - int(land[t])) * LIFT if land.has(t) else DEPTH + step * LIFT
	for t: Vector2i in tiles:
		var step: int = land[t]
		var c := Sim.centre_of(t)
		for side: int in [-1, 1]:
			var n := t + Vector2i(side, 1)
			if land.has(n):
				continue
			var d: float = drop.call(step, n)
			var p0 := _put(c + Vector2(side * a, 0.0), step, origin, u, d)
			var p1 := _put(c + Vector2(0.0, a), step, origin, u, d)
			b.polygon(PackedVector2Array([p0, p1, p1 + Vector2(0.0, 33.0 * u), p0 + Vector2(0.0, 33.0 * u)]), Color(MIRROR, 0.2 if side < 0 else 0.26))
	for t: Vector2i in tiles:
		var step: int = land[t]
		var c := Sim.centre_of(t)
		var corners := [c + Vector2(0.0, -a), c + Vector2(a, 0.0), c + Vector2(0.0, a), c + Vector2(-a, 0.0)]
		var mid := b.vertex(_put(c, step, origin, u), _tone(c, step))
		var first := b.verts.size()
		for p: Vector2 in corners:
			b.vertex(_put(p, step, origin, u), _tone(p, step))
		for i in 4:
			b.tri(mid, first + i, first + (i + 1) % 4)
		# where the land ends behind a tile nothing covers its edge: soften it
		for side: int in [-1, 1]:
			if not land.has(t + Vector2i(side, -1)):
				var e: Vector2 = corners[1] if side > 0 else corners[3]
				b.stroke(PackedVector2Array([_put(corners[0], step, origin, u), _put(e, step, origin, u)]), 1.6, _tone((corners[0] + e) * 0.5, step))
		for side: int in [-1, 1]:
			var n := t + Vector2i(side, 1)
			var d: float = drop.call(step, n)
			if d <= 0.0:
				continue
			var lit := side < 0
			var wet := not land.has(n)
			var p0 := _put(c + Vector2(side * a, 0.0), step, origin, u)
			var p1 := _put(corners[2], step, origin, u)
			var down := Vector2(0.0, d * u)
			var tones: Array = EARTH if lit else EARTH_SHADE
			var v0 := b.vertex(p0, tones[0])
			var v1 := b.vertex(p1, tones[0])
			var v2 := b.vertex(p1 + down, tones[1])
			var v3 := b.vertex(p0 + down, tones[1])
			b.tri(v0, v1, v2)
			b.tri(v0, v2, v3)
			var k := rng.randf_range(0.42, 0.6)
			b.stroke(PackedVector2Array([p0.lerp(p1, 0.06) + down * k, p1.lerp(p0, 0.06) + down * k]), 3.0 * px, SEAM)
			if d > 100.0:
				b.stroke(PackedVector2Array([p0.lerp(p1, 0.06) + down * (k + 0.3), p1.lerp(p0, 0.06) + down * (k + 0.3)]), 3.0 * px, SEAM)
			if rng.randf() < 0.5:
				var at := p0.lerp(p1, rng.randf_range(0.25, 0.75)) + down * rng.randf_range(0.62, 0.82)
				b.ellipse(at, 11.0 * px, 7.0 * px, STONE if lit else STONE_SHADE)
				if lit:
					b.ellipse(at + Vector2(-3.0, -2.0) * px, 5.0 * px, 3.0 * px, Color("f1e6cf"))
			if wet:
				b.polygon(PackedVector2Array([p0 + down - Vector2(0.0, 16.0 * px), p1 + down - Vector2(0.0, 16.0 * px), p1 + down, p0 + down]), Color(0.12, 0.24, 0.26, 0.22))
				b.stroke(PackedVector2Array([p0.lerp(p1, 0.04) + down, p1.lerp(p0, 0.04) + down]), 4.0 * px, Color(1.0, 1.0, 1.0, 0.6))
			# the turf hanging over the earth
			var lip: Color = LIP_LIT if lit else LIP
			b.polygon(PackedVector2Array([p0 - Vector2(0.0, 1.0), p1 - Vector2(0.0, 1.0), p1 + Vector2(0.0, 10.0 * px), p0 + Vector2(0.0, 10.0 * px)]), lip)
			for i in 4:
				b.disc(p0.lerp(p1, (i + 0.5) / 4.0) + Vector2(0.0, 9.0 * px), rng.randf_range(6.0, 11.0) * px, lip)
			if lit:
				b.stroke(PackedVector2Array([p0.lerp(p1, 0.12) - Vector2(0.0, 4.0 * px), p1.lerp(p0, 0.08) - Vector2(0.0, 5.0 * px)]), 4.0 * px, Color(0.94, 0.97, 0.69, 0.5))
	for t: Vector2i in tiles:
		var step: int = land[t]
		var n := t + Vector2i(1, 1)
		if not land.has(n) or int(land[n]) >= step:
			continue
		var c := Sim.centre_of(t)
		var low: int = land[n]
		var p0 := _put(c + Vector2(0.0, a), low, origin, u)
		var p1 := _put(c + Vector2(a, 0.0), low, origin, u)
		var over := Vector2(a, a * 0.5) * 0.42 * u
		b.polygon(PackedVector2Array([p0, p1, p1 + over, p0 + over]), SHADE)
	for t: Vector2i in tiles:
		var step: int = land[t]
		for i in 2:
			if rng.randf() < 0.45:
				continue
			var off := Vector2(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.35, 0.35)) * a
			off.y *= 1.0 - absf(off.x) / a
			var s := rng.randf_range(0.22, 0.4)
			b.ellipse(_put(Sim.centre_of(t) + off, step, origin, u), a * s * u, a * s * 0.5 * u, Color(WASH_WARM.lerp(GRASS_LIT, rng.randf()), 0.4))

## What lies over the land and its trees: warm light from where the sun is,
## and the frame falling away toward its edges into the pond's deep colour.
## One mesh for a field of `size`.
static func light(size: Vector2) -> ArrayMesh:
	var b := Face.Builder.new()
	var sun := Vector2(size.x * 0.12, 60.0)
	var far := size.length() * 0.9
	var mid := b.vertex(sun, Color(1.0, 0.9, 0.65, 0.2))
	var n := 20
	var first := b.verts.size()
	for i in n:
		var a := TAU * i / n
		var p := sun + Vector2(cos(a), sin(a)) * far
		b.vertex(Vector2(clampf(p.x, 0.0, size.x), clampf(p.y, 0.0, size.y)), Color(1.0, 0.9, 0.65, 0.0))
	for i in n:
		b.tri(mid, first + i, first + (i + 1) % n)
	var rim := Face.Builder.round_rect(Vector2.ZERO, size, 36.0)
	var centre := size * 0.5
	var start := b.verts.size()
	for p: Vector2 in rim:
		b.vertex(p, Color(0.07, 0.26, 0.33, 0.28))
		b.vertex(centre + (p - centre) * 0.62, Color(0.07, 0.26, 0.33, 0.0))
	var m := rim.size()
	for i in m:
		var j := (i + 1) % m
		b.tri(start + i * 2, start + j * 2, start + j * 2 + 1)
		b.tri(start + i * 2, start + j * 2 + 1, start + i * 2 + 1)
	return b.mesh()

## A lily pad lying flat on the pond: half as deep as it is wide.
static func _lily(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var flat := Transform2D(0.0, Vector2(1.0, 0.5), 0.0, at)
	var pts := Face.Builder.arc_points(Vector2.ZERO, r, turn + 0.35, turn + 6.0)
	pts.append(Vector2.ZERO)
	b.polygon(flat * pts, LILY)
	b.stroke(flat * Face.Builder.arc_points(Vector2.ZERO, r * 0.62, turn + 0.7, turn + 5.5), 3.0, LILY_HI)

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
	_icons[key] = b.mesh()
	return _icons[key]

## A tree without its shade, for a picture.
static func _bare(look: int) -> ArrayMesh:
	var b := Face.Builder.new()
	_tree_into(b, look, Sim.RADIUS[look])
	return b.mesh()

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

