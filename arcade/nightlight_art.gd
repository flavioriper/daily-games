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

## The radius every mesh here is built at.
const R := 64.0
const SIDES := 48
## A body's one colour, by Sim.Kind: meteor, pebble, rock, comet, planetoid,
## ash.
const PAINT := [Color("e6be8e"), Color("bea08a"), Color("92a2cc"), Color("c4ece2"), Color("ce8eb0"), Color("ec9674")]
## The unlit side of everything.
const SHADE := Color("1e1a3e")
## The night, top to foot: indigo to plum, never a black.
const SKY := [Color("171533"), Color("241d45"), Color("33264c")]
## The star's own colour is its mass: an ember at 10, gold at 100, cream at
## 1,000, blue-white past 30,000 (the logarithm of the mass, and the colour).
const TEMPS := [[1.0, Color("ff9660")], [2.0, Color("ffca7a")], [3.0, Color("ffeec8")], [4.5, Color("deeaff")]]
## The cloud a supernova leaves in the sky, one after another.
const CLOUDS := [Color("ec96aa"), Color("96aaf0"), Color("82d2c8"), Color("f0be82")]
const WARM := Color("ffb060")
const COOL := Color("d6dcff")
const TAIL := Color("c8f6ec")
const VEIL := Color("fff4de")
## A mote of light: gold where the other games' energy is blue.
const ORB_DEEP := Color("e08a1e")
const ORB := Color("ffc94d")
const ORB_HI := Color("fff0c2")
## How many lumps there are to be: a body takes one by its id.
const LUMPS := 3

static var _lumps: Array[ArrayMesh] = []
static var _glows := {}
static var _dot: ArrayMesh
static var _star: ArrayMesh
static var _core: ArrayMesh
static var _orb: ArrayMesh
static var _orb_light: ArrayMesh
static var _icons := {}
static var _ramps := {}

static func star_col(mass: float) -> Color:
	var l := log(maxf(1.0, mass)) / log(10.0)
	if l <= float(TEMPS[0][0]):
		return TEMPS[0][1]
	for i in range(1, TEMPS.size()):
		if l <= float(TEMPS[i][0]):
			var from: float = TEMPS[i - 1][0]
			return (TEMPS[i - 1][1] as Color).lerp(TEMPS[i][1], (l - from) / (float(TEMPS[i][0]) - from))
	return TEMPS[TEMPS.size() - 1][1]

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

## A white disc, for the dots of a throw's path.
static func dot() -> ArrayMesh:
	if _dot == null:
		var b := Face.Builder.new()
		b.disc(Vector2.ZERO, R, Color.WHITE)
		_dot = b.mesh()
	return _dot

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

## The star's body, white and R in radius with a soft edge past it: drawn in
## the star's colour.
static func star() -> ArrayMesh:
	if _star == null:
		var b := Face.Builder.new()
		_radial(b, Vector2.ZERO, R * 1.14, [[0.0, Color.WHITE], [0.72, Color.WHITE], [0.816, Color(1, 1, 1, 0.85)], [1.0, Color(1, 1, 1, 0.0)]])
		_star = b.mesh()
	return _star

## Its white heart, drawn over the body.
static func core() -> ArrayMesh:
	if _core == null:
		var b := Face.Builder.new()
		_radial(b, Vector2.ZERO, R, [[0.0, Color.WHITE], [0.45, Color(1, 1, 1, 0.55)], [0.82, Color(1, 1, 1, 0.0)]])
		_core = b.mesh()
	return _core

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

## The night for a field `size` big: its three colours top to foot, the
## clouds `novas` supernovas have left in it, and its specks, each a small
## soft light. One mesh, drawn once.
static func sky(size: Vector2, novas: int) -> ArrayMesh:
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
	for i in mini(novas, 8):
		rng.seed = 900 + i
		var at := size * 0.5 + Vector2(rng.randf_range(-0.33, 0.33) * size.x, rng.randf_range(-0.3, 0.3) * size.y)
		Motes.glow(b, at, rng.randf_range(380.0, 640.0) * u, Color(CLOUDS[i % CLOUDS.size()], 0.2), 1.6)
	rng.seed = 77
	var tints := [Color("fff6e6"), Color("d6e0ff"), Color("ffd6dc")]
	for i in 170:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var r := (1.4 + rng.randf() * rng.randf() * 4.5) * 2.4 * u
		var tint: Color = tints[rng.randi() % 3]
		var a := 0.18 + rng.randf() * 0.5
		_radial(b, at, r, [[0.0, Color(tint, a)], [0.4, Color(tint, a * 0.5)], [1.0, Color(tint, 0.0)]])
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

## A trail's colours for `n` points, oldest first: nothing at its tail,
## brightest at the body. `heat` in four steps, 0 for a body out of the haze.
static func ramp(n: int, heat: float) -> PackedColorArray:
	var step := 0 if heat <= 0.0 else 1 + mini(3, int(heat * 4.0))
	var key := n * 8 + step
	if not _ramps.has(key):
		var h := step / 4.0
		var cols := PackedColorArray()
		cols.resize(n)
		for i in n:
			var k := float(i + 1) / n
			cols[i] = Color(COOL, k * k * 0.22) if step == 0 else Color(1.0, (196.0 + 40.0 * h) / 255.0, (130.0 + 60.0 * h) / 255.0, k * k * (0.2 + 0.3 * h))
		_ramps[key] = cols
	return _ramps[key]

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

## A small star with its light round it, `r` in radius.
static func lay_star(b: Face.Builder, at: Vector2, r: float, col: Color) -> void:
	Motes.glow(b, at, r * 3.2, Color(col, 0.5), 2.2)
	_radial(b, at, r * 1.14, [[0.0, Color.WHITE], [0.4, col.lerp(Color.WHITE, 0.55)], [0.72, col], [0.816, Color(col, 0.85)], [1.0, Color(col, 0.0)]])

## A picture R in radius or less about (0, 0): "mass" and "light" for the
## plates, "dust" for stardust, and one for each tile.
static func icon(what: String) -> ArrayMesh:
	if not _icons.has(what):
		var b := Face.Builder.new()
		var sun := Vector2(-1.0, -1.0)
		match what:
			"mass":
				lay_star(b, Vector2.ZERO, R * 0.42, TEMPS[1][1])
			"light", "glow":
				_lay_orb(b, Vector2.ZERO, R)
			"dust":
				for mote: Array in [[Vector2(-0.3, 0.18), 0.5], [Vector2(0.36, 0.3), 0.36], [Vector2(0.12, -0.36), 0.42]]:
					_lay_orb(b, (mote[0] as Vector2) * R, float(mote[1]) * R)
			"meteor":
				lit(b, Vector2.ZERO, R * 0.6, PAINT[Sim.Kind.METEOR], sun)
			"haze":
				Motes.glow(b, Vector2.ZERO, R, Color(TEMPS[1][1], 0.55), 0.9)
				lay_star(b, Vector2.ZERO, R * 0.22, TEMPS[1][1])
			"sky":
				var head := Vector2(-0.3, 0.3) * R
				b.polygon(PackedVector2Array([head + Vector2(-0.2, -0.26) * R, Vector2(0.86, -0.82) * R, head + Vector2(0.26, 0.2) * R]), Color(TAIL, 0.45))
				lit(b, head, R * 0.36, PAINT[Sim.Kind.COMET], Vector2(-1.0, 1.0))
		_icons[what] = b.mesh()
	return _icons[what]
