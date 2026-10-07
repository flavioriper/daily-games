extends RefCounted

## Nightlight's drawings, each a cached mesh (arcade/nightlight_sky.gd draws
## them, the screen and the Arcade tab's card borrow the icons). Everything
## is built R across and drawn scaled, so a feather stays a pixel wide.
##
## **The star is the only lamp.** A body is one flat colour and a white lump;
## its lit side, its deep violet far side and its warmth in the haze are
## shaders/nightlight_body_2d.gdshader's. What is light itself (the star's
## glow on the dust, a body's warmth, the motes) is
## a soft round falloff with no rim, no shine and no rays (ui/motes.gd:
## cozy light has no shape), drawn on a layer that adds.

const Face = preload("res://ui/faces/face.gd")
const Motes = preload("res://ui/motes.gd")
const Sim = preload("res://arcade/nightlight_sim.gd")
const BODY := preload("res://shaders/nightlight_body_2d.gdshader")
const STAR := preload("res://shaders/nightlight_star_2d.gdshader")

## The radius every mesh here is built at.
const R := 64.0
const SIDES := 48
## A solid's one colour, by Sim.Kind: gas (never a lump), grain, rock,
## comet, planet, giant.
const PAINT := [Color("b4aef2"), Color("cdb69c"), Color("b89a86"), Color("c4ece2"), Color("8fa6d4"), Color("e9b98a")]
## The unlit side of everything.
const SHADE := Color("1e1a3e")
## The night, top to foot: indigo to plum, never a black.
const SKY := [Color("171533"), Color("241d45"), Color("33264c")]
## The star's own colour is its temperature, in kelvin: a red giant's
## ember, a Sun's orange, cream, white, blue-white. The shader paints three
## tones out of it.
const TEMPS := [[2600.0, Color("e2502c")], [3600.0, Color("ff7d3c")], [5800.0, Color("ffab48")], [9000.0, Color("ffdc9c")],
	[14000.0, Color("fff3df")], [22000.0, Color("e2ecff")], [40000.0, Color("b8d0ff")]]
const WARM := Color("ffb060")
const COOL := Color("d6dcff")
const TAIL := Color("c8f6ec")
## A body that is ice, a puff of gas far from the star, and a star with
## nothing left to burn.
const ICE := Color("c4ece2")
const GAS := Color("a49ef0")
const DIMMED := Color("a8483a")
## A white dwarf's light and a neutron star's, and the dark a world takes from
## a dead star's iron.
const WD := Color("dfe8ff")
const NS := Color("cfc4ff")
const PAINT_IRON := Color("5c5a6e")
## What the star is made of, on its bar and in what it throws off, in
## Sim.CHAIN's order with rock last: hydrogen, helium, carbon, neon, oxygen,
## silicon, iron, rock.
const MADE := [Color("f2b441"), Color("c3b2e6"), Color("76c7b4"), Color("f08c8c"), Color("8fb8f0"), Color("e9dba6"), Color("c9643c"), Color("8f8078")]
const VEIL := Color("fff4de")
## The cream a star's heart goes toward (the shader's CREAM).
const HEART := Color("fff6de")
## A mote of light: gold where the other games' energy is blue.
const ORB_DEEP := Color("e08a1e")
const ORB := Color("ffc94d")
const ORB_HI := Color("fff0c2")
## How many lumps there are to be: a body takes one by its id.
const LUMPS := 3

static var _lumps: Array[ArrayMesh] = []
static var _glows := {}
static var _star: ArrayMesh
static var _orb: ArrayMesh
static var _orb_light: ArrayMesh
static var _icons := {}

static func star_col(kelvin: float) -> Color:
	var l := kelvin
	if l <= float(TEMPS[0][0]):
		return TEMPS[0][1]
	for i in range(1, TEMPS.size()):
		if l <= float(TEMPS[i][0]):
			var from: float = TEMPS[i - 1][0]
			return (TEMPS[i - 1][1] as Color).lerp(TEMPS[i][1], (l - from) / (float(TEMPS[i][0]) - from))
	return TEMPS[TEMPS.size() - 1][1]

## The colour of `sim`'s star as it burns: its temperature's while lit, a
## dull ember with nothing left to burn.
static func burning_col(sim: RefCounted) -> Color:
	return DIMMED.lerp(star_col(sim.temp()), lerpf(0.35, 1.0, sim.lit))

## A solid's paint: its kind's, paler the icier it is and darker the more of
## a dead star's iron is in it.
static func paint_of(kind: int, ice: float, metal := 0.0) -> Color:
	return (PAINT[kind] as Color).lerp(ICE, clampf(ice, 0.0, 1.0) * 0.7).lerp(PAINT_IRON, clampf(metal, 0.0, 1.0) * 0.8)

## A number in a few characters: 0.5, 12.4, 999, 1.23K, 45.6K, 1.2M and on
## through B, T and Q. The star has no last mass.
static func short(v: float, comma := false) -> String:
	var text := ""
	if v < 100.0:
		text = ("%.1f" % (floorf(v * 10.0) / 10.0)).trim_suffix(".0")
	elif v < 1000.0:
		text = str(int(v))
	else:
		var i := 0
		while v >= 1000.0 and i < 5:
			v /= 1000.0
			i += 1
		text = ("%.2f" % v) if v < 10.0 else (("%.1f" % v) if v < 100.0 else ("%d" % int(v)))
		if text.contains("."):
			text = text.rstrip("0").rstrip(".")
		text += " KMBTQ"[i]
	return text.replace(".", ",") if comma else text

# --- the bodies ---

## One of the lumps a body is drawn as: white, a soft-cornered stone a
## little off round.
static func lump(which: int) -> ArrayMesh:
	if _lumps.is_empty():
		for v in LUMPS:
			var rng := RandomNumberGenerator.new()
			rng.seed = 4100 + v
			var n := 9
			var corners := PackedVector2Array()
			for i in n:
				corners.append(Vector2.from_angle(TAU * i / n) * R * rng.randf_range(0.86, 1.1))
			var outline := PackedVector2Array()
			for i in n:
				var p := corners[i]
				outline.append_array(Face.Builder.bezier2((corners[(i - 1 + n) % n] + p) * 0.5, p, (p + corners[(i + 1) % n]) * 0.5, 6))
			var b := Face.Builder.new()
			b.fan(outline, Color.WHITE)
			_lumps.append(b.mesh())
	return _lumps[which % LUMPS]

## The material of the layer the bodies are drawn on.
static func body_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = BODY
	m.set_shader_parameter("built", R)
	return m

static func adding() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

## A white light R in radius, thinning to nothing along a curve (`fall`: the
## higher, the smaller its bright heart). Tinted by what draws it.
static func glow(fall := 2.0) -> ArrayMesh:
	if not _glows.has(fall):
		var b := Face.Builder.new()
		Motes.glow(b, Vector2.ZERO, R, Color.WHITE, fall)
		_glows[fall] = b.mesh()
	return _glows[fall]

## Rings of colour about the middle: `stops` are [share of `r`, colour], the
## first at the middle itself.
static func _radial(b: Face.Builder, c: Vector2, r: float, stops: Array) -> void:
	var mid := b.vertex(c, stops[0][1])
	var first := b.verts.size()
	for s in range(1, stops.size()):
		for k in SIDES:
			b.vertex(c + Vector2.from_angle(TAU * k / SIDES) * r * float(stops[s][0]), stops[s][1])
	for k in SIDES:
		var next := (k + 1) % SIDES
		b.tri(mid, first + k, first + next)
		for ring in stops.size() - 2:
			var a := first + ring * SIDES
			var o := a + SIDES
			b.tri(a + k, o + k, o + next)
			b.tri(a + k, o + next, a + next)

## The square the star's shader draws on, WIDE of R each way: the star
## itself is R, and the rest is room for what stands off its edge.
const WIDE := 1.45

static func star_quad() -> ArrayMesh:
	if _star == null:
		var b := Face.Builder.new()
		var w := R * WIDE
		b.polygon(PackedVector2Array([Vector2(-w, -w), Vector2(w, -w), Vector2(w, w), Vector2(-w, w)]), Color.WHITE)
		_star = b.mesh()
	return _star

## The material of the layer the star is drawn on
## (shaders/nightlight_star_2d.gdshader).
static func star_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = STAR
	m.set_shader_parameter("built", R)
	return m

# --- the light that is counted ---

## A mote of light, as ui/motes.gd's orb is and in gold: a wide amber glow
## thinning to nothing, a paler one in it and a white heart, none with an
## edge.
static func orb() -> ArrayMesh:
	if _orb == null:
		var b := Face.Builder.new()
		_lay_orb(b, Vector2.ZERO, Motes.ORB_R)
		_orb = b.mesh()
	return _orb

static func _lay_orb(b: Face.Builder, c: Vector2, r: float) -> void:
	Motes.glow(b, c, r, Color(ORB_DEEP, 0.62), 1.5)
	Motes.glow(b, c, 0.62 * r, Color(ORB, 0.95), 1.4)
	Motes.glow(b, c, 0.4 * r, Color(ORB_HI, 1.0), 1.2)
	Motes.glow(b, c, 0.26 * r, Color.WHITE, 0.9)

static func orb_light() -> ArrayMesh:
	if _orb_light == null:
		var b := Face.Builder.new()
		Motes.glow(b, Vector2.ZERO, Motes.ORB_R, Color(1.0, 0.7, 0.3, 0.42), 1.8)
		_orb_light = b.mesh()
	return _orb_light

# --- the sky ---

## The night for a field `size` big: its three colours top to foot and its
## specks, each a small soft light. One mesh, drawn once. (`novas` is kept
## for the callers: what a supernova leaves is a relic and its nebula now,
## drawn where it is.)
static func sky(size: Vector2, _novas: int) -> ArrayMesh:
	var b := Face.Builder.new()
	var u := size.x / 1080.0
	var ys := [0.0, size.y * 0.55, size.y]
	for band in 2:
		var first := b.verts.size()
		b.vertex(Vector2(0.0, ys[band]), SKY[band])
		b.vertex(Vector2(size.x, ys[band]), SKY[band])
		b.vertex(Vector2(size.x, ys[band + 1]), SKY[band + 1])
		b.vertex(Vector2(0.0, ys[band + 1]), SKY[band + 1])
		b.tri(first, first + 1, first + 2)
		b.tri(first, first + 2, first + 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var tints := [Color("fff6e6"), Color("d6e0ff"), Color("ffd6dc")]
	for i in 170:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r := (1.4 + rng.randf() * rng.randf() * 4.5) * 2.4 * u
		var tint: Color = tints[rng.randi() % 3]
		var a := 0.18 + rng.randf() * 0.5
		_radial(b, at, r, [[0.0, Color(tint, a)], [0.4, Color(tint, a * 0.5)], [1.0, Color(tint, 0.0)]])
	return b.mesh()

## The stars far behind everything, over a `wide` square round the origin:
## one mesh, slid a little with the camera.
static func far_field(rng_seed: int, wide: float) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var tints := [Color("fff6e6"), Color("d6e0ff"), Color("ffd6dc")]
	for i in 90:
		var at := Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * wide
		var r := (1.6 + rng.randf() * rng.randf() * 5.0) * 2.4
		_radial(b, at, r, [[0.0, Color(tints[rng.randi() % 3], 0.2 + rng.randf() * 0.5)], [0.4, Color(tints[rng.randi() % 3], 0.3)], [1.0, Color(tints[0], 0.0)]])
	return b.mesh()

## A filled disc of radius R, white: a black hole's dark body, drawn scaled.
static func disc() -> ArrayMesh:
	var b := Face.Builder.new()
	b.disc(Vector2.ZERO, R, Color.WHITE)
	return b.mesh()

## The field's four corners in `col`, to round a square sky off: what flies
## through a corner goes under them.
static func corners(size: Vector2, r: float, col: Color) -> ArrayMesh:
	var b := Face.Builder.new()
	for c: Array in [[Vector2.ZERO, PI, PI * 1.5], [Vector2(size.x, 0.0), PI * 1.5, TAU], [size, 0.0, PI * 0.5], [Vector2(0.0, size.y), PI * 0.5, PI]]:
		var corner: Vector2 = c[0]
		var mid := corner + Vector2(r if corner.x == 0.0 else -r, r if corner.y == 0.0 else -r)
		var outline := PackedVector2Array([corner])
		outline.append_array(Face.Builder.arc_points(mid, r, c[2], c[1]))
		b.polygon(outline, col)
	return b.mesh()

# --- pictures: a plate's, a tile's, the Arcade card's ---

## A body with its light baked in, for a picture that stands still: `paint`
## at `at`, `r` in radius, lit from `to_light`.
static func lit(b: Face.Builder, at: Vector2, r: float, paint: Color, to_light: Vector2, tint := Color("ffca7a")) -> void:
	var l := to_light.normalized()
	var p := l.orthogonal()
	b.disc(at, r, SHADE.lerp(paint, 0.3))
	var day := PackedVector2Array()
	var n := 16
	for i in n + 1:
		var a := lerpf(-PI * 0.5, PI * 0.5, float(i) / n)
		day.append(at + (l * cos(a) + p * sin(a)) * r)
	for i in range(1, n):
		var a := lerpf(PI * 0.5, -PI * 0.5, float(i) / n)
		day.append(at + (l * -0.35 * cos(a) + p * sin(a)) * r)
	b.polygon(day, paint.lerp(tint, 0.25).lerp(Color.WHITE, 0.1))

## A small star with its light round it, `r` in radius: the sky's star
## standing still (shaders/nightlight_star_2d.gdshader), its three flat
## tones, a deeper limb, its own colour and a pale heart of dabs run
## together.
static func lay_star(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	Motes.glow(b, at, r * 3.2, Color(col, 0.5), 2.2)
	b.disc(at, r, Color(col.r * 0.92, col.g * 0.66, col.b * 0.5))
	b.disc(at + Vector2(-0.02, -0.03) * r, r * 0.87, col)
	var pale := col.lerp(HEART, 0.6)
	for dab: Array in [[Vector2(-0.14, -0.12), 0.44], [Vector2(0.2, 0.06), 0.34], [Vector2(-0.04, 0.22), 0.3]]:
		b.disc(at + (dab[0] as Vector2) * r, float(dab[1]) * r, pale)

## A puff of gas for a picture: a soft light with no edge and a paler heart.
static func lay_puff(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	Motes.glow(b, at, r, Color(col, 0.55 * col.a), 1.3)
	Motes.glow(b, at, r * 0.5, Color(col.lerp(Color.WHITE, 0.6), 0.7 * col.a), 1.2)

## A picture R in radius or less about (0, 0): "mass" and "light" for the
## plates, "dust" for stardust, one for each of the hand's tiles and one for
## each of the star's powers.
static func icon(what: String) -> ArrayMesh:
	if not _icons.has(what):
		var b := Face.Builder.new()
		var sun := Vector2(-1.0, -1.0)
		match what:
			"mass":
				lay_star(b, Vector2.ZERO, R * 0.42, star_col(5800.0))
			"light", "glow":
				_lay_orb(b, Vector2.ZERO, R)
			"dust":
				for mote: Array in [[Vector2(-0.3, 0.18), 0.5], [Vector2(0.36, 0.3), 0.36], [Vector2(0.12, -0.36), 0.42]]:
					_lay_orb(b, (mote[0] as Vector2) * R, float(mote[1]) * R)
			"rich":
				lay_puff(b, Vector2.ZERO, R * 0.95, GAS)
			"reach":
				for k in 3:
					lay_puff(b, Vector2(-0.46 + 0.46 * k, 0.24 - 0.24 * k) * R, R * 0.52, GAS)
			"flow":
				# one after another down the same way, the last still faint
				for k in 4:
					lay_puff(b, Vector2(0.54 - 0.36 * k, 0.54 - 0.36 * k) * R, R * (0.5 - 0.07 * k), Color(GAS, 1.0 - 0.2 * k))
			"pure":
				lay_puff(b, Vector2.ZERO, R * 0.95, MADE[0])
			"haze":
				Motes.glow(b, Vector2.ZERO, R, Color(star_col(5800.0), 0.55), 0.9)
				lay_star(b, Vector2.ZERO, R * 0.22, star_col(5800.0))
			"sky", "beacon":
				var head := Vector2(-0.3, 0.3) * R
				b.polygon(PackedVector2Array([head + Vector2(-0.2, -0.26) * R, Vector2(0.86, -0.82) * R, head + Vector2(0.26, 0.2) * R]), Color(TAIL, 0.45))
				lit(b, head, R * 0.36, PAINT[Sim.Kind.COMET], Vector2(-1.0, 1.0))
			"radiance":
				_lay_orb(b, Vector2.ZERO, R)
			"wind":
				# the star, and what it blows on winding in toward it
				lay_star(b, Vector2.ZERO, R * 0.2, star_col(5800.0))
				for k in 7:
					var a := -0.4 + 0.72 * k
					var far := R * (0.42 + 0.075 * k)
					Motes.glow(b, Vector2.from_angle(a) * far, R * (0.09 + 0.022 * k), Color(COOL, 0.35 + 0.08 * k), 1.2)
				var end := Vector2.from_angle(-0.4 + 0.72 * 7.0)
				lit(b, end * R * 0.78, R * 0.17, PAINT[Sim.Kind.ROCK], -end)
			"furnace":
				# a body in pieces, warm where it broke
				Motes.glow(b, Vector2.ZERO, R * 0.9, Color(WARM, 0.5), 1.3)
				for piece: Array in [[Vector2(-0.34, -0.2), 0.3], [Vector2(0.3, -0.3), 0.22], [Vector2(0.1, 0.34), 0.26], [Vector2(-0.38, 0.36), 0.14]]:
					lit(b, (piece[0] as Vector2) * R, float(piece[1]) * R, PAINT[Sim.Kind.PLANET], -(piece[0] as Vector2))
			"fusion":
				# two lights becoming one
				_lay_orb(b, Vector2(-0.3, 0.0) * R, R * 0.62)
				_lay_orb(b, Vector2(0.3, 0.0) * R, R * 0.62)
				Motes.glow(b, Vector2.ZERO, R * 0.3, Color.WHITE, 0.9)
			"thrift":
				# a small ember that lasts
				lay_star(b, Vector2.ZERO, R * 0.26, star_col(3000.0))
		_icons[what] = b.mesh()
	return _icons[what]
