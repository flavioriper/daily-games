extends RefCounted

## The Grove's drawings: the water and the land, the five trees, the log and
## the spark, and a picture for each tile. Every one is built once into a
## mesh and kept, so the screen pays one draw_mesh a tree and one for the
## whole ground (CLAUDE.md, the 855 budget). Trees have no faces: they are
## what is chopped. Shared by the screen (valley/grove_screen.gd), the tab's
## card (ui/menu/valley_tab.gd) and the tutorial's pages.

const Face = preload("res://ui/faces/face.gd")
const Sim = preload("res://valley/grove_sim.gd")
const Pal = preload("res://core/palette.gd")

const WATER := Color("8fd9d2")
const WATER_DEEP := Color("7ccbc6")
const RIPPLE := Color(1.0, 1.0, 1.0, 0.4)
const LILY := Color("63b56a")
const LILY_HI := Color("7cc983")
const GRASS := Color("a9d66b")
const GRASS_HI := Color("b9e07c")
const GRASS_DEEP := Color("8cc152")
const TUFT := Color("86bb4d")
const CLIFF := Color("c9853f")
const CLIFF_DEEP := Color("a96a2c")
const SHADE := Color(0.16, 0.43, 0.43, 0.22)
const BARK := Color("9c6b45")
const PITH := Color("f0d9ae")
const SPARK := Color("7fbf3f")
const SPARK_HI := Color("d9f09a")
const MARK := Color("ffd66b")
## The log's length and the spark's radius as built; the screen scales them.
const LOG := 48.0
const SPARK_R := 22.0
## A tile's picture is drawn about its middle, inside this half width.
const ICON := 56.0

static var _trees := {}
static var _icons := {}
static var _log: ArrayMesh
static var _spark: ArrayMesh

## A tree of `look` (0 sapling, 1 birch, 2 oak, 3 pine, 4 blossom) standing
## on (0, 0), its shade on the grass under it, in land units.
static func tree(look: int) -> ArrayMesh:
	if not _trees.has(look):
		var b := Face.Builder.new()
		var r: float = Sim.RADIUS[look]
		b.ellipse(Vector2(0.0, 2.0), r * 1.05, r * 0.34, Color(0.2, 0.35, 0.12, 0.25))
		_tree_into(b, look, r)
		_trees[look] = b.mesh()
	return _trees[look]

static func _tree_into(b: Face.Builder, look: int, r: float) -> void:
	match look:
		0:
			b.stroke(PackedVector2Array([Vector2.ZERO, Vector2(0.0, -r * 1.2)]), 6.0, Color("6f9f3e"))
			_leaf(b, Vector2(-r * 0.5, -r * 1.2), r * 0.55, r * 0.3, 0.5, Color("8cc763"))
			_leaf(b, Vector2(r * 0.5, -r * 1.4), r * 0.55, r * 0.3, -0.5, Color("8cc763"))
			b.disc(Vector2(0.0, -r * 1.8), r * 0.5, Color("a6d96e"))
		3:
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.16, -r * 0.7), Vector2(r * 0.32, r * 0.7), 4.0), Color("7a5236"))
			_tier(b, r, -r * 0.45, r * 1.0, r * 1.1, Color("3f7f5a"))
			_tier(b, r, -r * 1.2, r * 0.8, r * 1.0, Color("488a63"))
			_tier(b, r, -r * 1.85, r * 0.58, r * 0.95, Color("52966c"))
		_:
			var trunk := Color("f3eee2") if look == 1 else Color("8a5c3a")
			var deep := Color("9ccb5c")
			var mid := Color("a9d46a")
			var hi := Color("c4e486")
			if look == 2:
				deep = Color("559238")
				mid = Color("5f9c3e")
				hi = Color("8cc763")
			elif look == 4:
				deep = Color("e58fb5")
				mid = Color("f0a6c6")
				hi = Color("fbd0e2")
			b.polygon(Face.Builder.round_rect(Vector2(-r * 0.2, -r * 1.1), Vector2(r * 0.4, r * 1.1), r * 0.14), trunk)
			if look == 1:
				b.polygon(Face.Builder.round_rect(Vector2(-r * 0.2, -r * 0.5), Vector2(r * 0.22, 4.0), 2.0), Color("6e6057"))
				b.polygon(Face.Builder.round_rect(Vector2(0.0, -r * 0.82), Vector2(r * 0.2, 4.0), 2.0), Color("6e6057"))
			b.disc(Vector2(-r * 0.62, -r * 1.35), r * 0.66, deep)
			b.disc(Vector2(r * 0.64, -r * 1.3), r * 0.64, deep)
			b.disc(Vector2(0.0, -r * 1.75), r * 0.86, mid)
			b.disc(Vector2(-r * 0.24, -r * 2.0), r * 0.32, hi)
			if look == 4:
				for o: Vector2 in [Vector2(-0.7, -1.2), Vector2(0.5, -1.6), Vector2(0.1, -2.1), Vector2(0.75, -1.1)]:
					b.disc(o * r, r * 0.09, Color("fff6e6"))

## One skirt of the pine: a wide foot that sags a little, drawn up to a point.
static func _tier(b: Face.Builder, r: float, foot: float, half: float, high: float, colour: Color) -> void:
	var pts := Face.Builder.bezier2(Vector2(-half, foot), Vector2(0.0, foot + r * 0.22), Vector2(half, foot), 10)
	pts.append(Vector2(half, foot))
	pts.append(Vector2(r * 0.1, foot - high))
	pts.append(Vector2(-r * 0.1, foot - high))
	b.polygon(pts, colour)

static func _leaf(b: Face.Builder, centre: Vector2, rx: float, ry: float, turn: float, colour: Color) -> void:
	var xf := Transform2D(turn, centre)
	b.fan(xf * Face.Builder.ring(Vector2.ZERO, rx, ry), colour)

## How tall a tree of `look` stands above its foot, for what is drawn over it.
static func height(look: int) -> float:
	var r: float = Sim.RADIUS[look]
	return r * (2.3 if look == 0 else (2.8 if look == 3 else 2.6))

## The pond and the land in it, for a field of `size` with the land at
## `land`: the still part of the screen, one mesh.
static func ground(size: Vector2, land: Rect2) -> ArrayMesh:
	var b := Face.Builder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261005
	var u := land.size.x / Sim.LAND.x
	b.polygon(Face.Builder.round_rect(Vector2.ZERO, size, 36.0), WATER)
	b.polygon(Face.Builder.round_rect(Vector2(0.0, size.y * 0.5), Vector2(size.x, size.y * 0.5), 36.0), WATER_DEEP.lerp(WATER, 0.5))
	for i in 12:
		var at := Vector2(rng.randf_range(30.0, size.x - 90.0), rng.randf_range(24.0, size.y - 24.0))
		if land.grow(10.0).has_point(at) or land.grow(10.0).has_point(at + Vector2(50.0, 0.0)):
			continue
		b.stroke(PackedVector2Array([at, at + Vector2(rng.randf_range(24.0, 54.0), 0.0)]), 4.0, RIPPLE)
	# lily pads and stones keep to the water round the land
	var rim: Array[Vector2] = []
	var side := land.position.x
	var foot := size.y - land.end.y
	if side > 44.0:
		rim.append_array([Vector2(side * 0.45, size.y * 0.22), Vector2(size.x - side * 0.45, size.y * 0.36),
			Vector2(side * 0.5, size.y * 0.72), Vector2(size.x - side * 0.5, size.y * 0.82)])
	if land.position.y > 44.0:
		rim.append_array([Vector2(size.x * 0.46, land.position.y * 0.45), Vector2(size.x * 0.8, land.position.y * 0.5)])
	if foot > 60.0:
		rim.append_array([Vector2(size.x * 0.3, size.y - foot * 0.36), Vector2(size.x * 0.72, size.y - foot * 0.34)])
	for i in rim.size():
		if i % 4 == 2:
			b.ellipse(rim[i] + Vector2(0.0, 9.0), 30.0 * u, 10.0 * u, SHADE)
			b.ellipse(rim[i], 27.0 * u, 18.0 * u, Pal.ROCK)
			b.ellipse(rim[i] + Vector2(-7.0, -6.0) * u, 12.0 * u, 7.0 * u, Color("d2c6ae"))
		else:
			_lily(b, rim[i], rng.randf_range(22.0, 30.0) * u, rng.randf_range(0.0, TAU))
	# the land: its shade on the water, the earth edge, the grass
	b.polygon(Face.Builder.round_rect(land.position + Vector2(-8.0, 40.0) * u, land.size + Vector2(16.0, 18.0) * u, 64.0 * u), SHADE)
	b.polygon(Face.Builder.round_rect(land.position + Vector2(0.0, 30.0) * u, land.size + Vector2(0.0, 6.0) * u, 60.0 * u), CLIFF_DEEP)
	b.polygon(Face.Builder.round_rect(land.position + Vector2(0.0, 18.0) * u, land.size + Vector2(0.0, 6.0) * u, 60.0 * u), CLIFF)
	b.polygon(Face.Builder.round_rect(land.position, land.size, 60.0 * u), GRASS_DEEP)
	b.polygon(Face.Builder.round_rect(land.position + Vector2(10.0, 10.0) * u, land.size - Vector2(20.0, 24.0) * u, 52.0 * u), GRASS)
	for i in 9:
		var at := land.position + Vector2(rng.randf_range(110.0, Sim.LAND.x - 110.0), rng.randf_range(100.0, Sim.LAND.y - 100.0)) * u
		b.ellipse(at, rng.randf_range(60.0, 100.0) * u, rng.randf_range(30.0, 52.0) * u, GRASS_HI)
	for i in 40:
		var at := land.position + Vector2(rng.randf_range(40.0, Sim.LAND.x - 40.0), rng.randf_range(50.0, Sim.LAND.y - 40.0)) * u
		b.stroke(PackedVector2Array([at + Vector2(-6.0, 0.0) * u, at + Vector2(-9.0, -12.0) * u]), 4.0 * u, TUFT)
		b.stroke(PackedVector2Array([at + Vector2(2.0, 0.0) * u, at + Vector2(4.0, -15.0) * u]), 4.0 * u, TUFT)
	for i in 10:
		var at := land.position + Vector2(rng.randf_range(50.0, Sim.LAND.x - 50.0), rng.randf_range(60.0, Sim.LAND.y - 50.0)) * u
		b.disc(at, 6.0 * u, Color("fff6e6") if i % 3 else Color("f4a7a0"))
		b.disc(at, 2.4 * u, Pal.SUN)
	return b.mesh()

static func _lily(b: Face.Builder, at: Vector2, r: float, turn: float) -> void:
	var pts := Face.Builder.arc_points(at, r, turn + 0.35, turn + 6.0)
	pts.append(at)
	b.polygon(pts, LILY)
	b.stroke(Face.Builder.arc_points(at, r * 0.62, turn + 0.7, turn + 5.5), 3.0, LILY_HI)

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

## A green spark about (0, 0), SPARK_R to its points: energy, the Grove's own.
static func spark() -> ArrayMesh:
	if _spark == null:
		var b := Face.Builder.new()
		_spark_into(b, Vector2.ZERO, SPARK_R)
		_spark = b.mesh()
	return _spark

static func _spark_into(b: Face.Builder, at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(at + Vector2.from_angle(TAU * i / 8.0 - PI * 0.5) * (r * 0.36 if i % 2 else r))
	b.polygon(pts, SPARK)
	b.disc(at, r * 0.3, SPARK_HI)

## A tile's picture, about (0, 0). Seeds shows the tree its next level opens,
## so it takes that tree's `look`.
static func icon(tile: String, look := 1) -> ArrayMesh:
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
		"energy":
			_spark_into(b, Vector2.ZERO, 30.0)
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

