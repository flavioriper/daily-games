extends RefCounted

## Millstream's valley and its buildings, drawn as builder shapes in world
## pixels (TILE a tile), shared by the game (arcade/millstream_screen.gd),
## its panel's chips and its card on the Arcade tab. The screen draws them
## through the camera's transform, so a pan or a zoom never rebuilds a mesh.
##
## A soft three-quarter look from above: a building stands on its footprint
## and rises a little up the screen. The valley is grass with a stream down
## its left side; the Mill is a timber mill with its wheel in the stream;
## a deposit is a heap of rocks veined in its ore's colour, more rocks the
## richer it is; a kiln is a brick dome with a glowing mouth and a chimney.

const Sim = preload("res://arcade/millstream_sim.gd")
const Face = preload("res://ui/faces/face.gd")

const TILE := 64.0
const INK := Color("3b3028")
const GRASS := Color("a9cf78")
const GRASS_DEEP := Color("8fbd62")
const GRASS_HI := Color("bddb8e")
const BANK := Color("c9b98c")
const BANK_DEEP := Color("a8966a")
const WATER := Color("8ecbe8")
const WATER_DEEP := Color("62a9d2")
const WATER_HI := Color("d4eef8")
const ROCK := Color("a39c92")
const ROCK_DEEP := Color("7e776e")
const ROCK_HI := Color("c7c0b5")
const ORE := {
	"iron": [Color("c0684b"), Color("8e4a37"), Color("e29575")],
	"copper": [Color("e0904a"), Color("b0662c"), Color("63b3a5")],
	"stone": [Color("e2dbcd"), Color("b8ae9c"), Color("f5f0e6")],
}
const WOOD := Color("b98556")
const WOOD_DEEP := Color("8a5c3b")
const WOOD_HI := Color("d4a574")
const ROOF := Color("c9624f")
const ROOF_DEEP := Color("9e4538")
const ROOF_HI := Color("e0806a")
const PLASTER := Color("f3e6cc")
const BRICK := Color("c77b5a")
const BRICK_DEEP := Color("9b5840")
const BRICK_HI := Color("e0a07e")
const EMBER := Color("ffb347")
const EMBER_HOT := Color("fff1a8")
const SOOT := Color("4a3c34")
const INGOT := Color("b9c2c9")
const INGOT_DEEP := Color("86919a")
const INGOT_HI := Color("e4eaee")
const TAG_PAPER := Color("fffaf0")
const SACK := Color("d9b98a")
const SACK_DEEP := Color("b08e5f")
const SACK_HI := Color("ecd4ac")
const OK := Color("7fd08a")
const BAD := Color("e2645c")

static var _cache := {}

## The whole valley that never changes: grass, the stream, its banks and
## the deposits. One mesh, built once.
static func ground() -> ArrayMesh:
	if _cache.has("ground"):
		return _cache["ground"]
	var b := Face.Builder.new()
	var w := Sim.COLS * TILE
	var h := Sim.ROWS * TILE
	b.fan(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), GRASS)
	# a soft checker of mown stripes, so the grid can be read without lines
	for y in Sim.ROWS:
		for x in Sim.COLS:
			if (x + y) % 2 == 0:
				var at := Vector2(x, y) * TILE
				b.fan(PackedVector2Array([at, at + Vector2(TILE, 0), at + Vector2(TILE, TILE), at + Vector2(0, TILE)]), Color(GRASS_HI, 0.35))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 220:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var c := Vector2i(p / TILE)
		if Sim.is_water(c):
			continue
		if rng.randf() < 0.18:
			_flower(b, p, rng)
		else:
			_tuft(b, p, rng.randf_range(0.7, 1.2))
	_stream(b)
	for i in Sim.DEPOSITS.size():
		deposit(b, i)
	var m := b.mesh()
	_cache["ground"] = m
	return m

static func _tuft(b: Face.Builder, p: Vector2, s: float) -> void:
	for k in 3:
		var a := -PI * 0.5 + (k - 1) * 0.45
		b.stroke(PackedVector2Array([p, p + Vector2.from_angle(a) * 9.0 * s]), 2.6 * s, GRASS_DEEP)

static func _flower(b: Face.Builder, p: Vector2, rng: RandomNumberGenerator) -> void:
	var col: Color = [Color("fff6e0"), Color("f7c4cf"), Color("ffd95e")][rng.randi() % 3]
	for k in 5:
		b.disc(p + Vector2.from_angle(k * TAU / 5.0) * 3.4, 2.6, col)
	b.disc(p, 2.0, Color("f0a830"))

## The stream: a band two tiles wide meandering down the left edge, with
## sandy banks, a darker channel and a few glints.
static func _stream(b: Face.Builder) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in Sim.ROWS * 4 + 1:
		var row := k / 4.0
		var s := 0.5 + 0.5 * sin((row - 0.5) * 0.42 + 0.6)
		left.append(Vector2(s * TILE - 4.0, row * TILE))
		right.append(Vector2((s + 2.0) * TILE + 4.0, row * TILE))
	_band(b, left, right, -10.0, BANK_DEEP)
	_band(b, left, right, -6.0, BANK)
	_band(b, left, right, 6.0, WATER)
	_band(b, left, right, 30.0, WATER_DEEP)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 40:
		var i := rng.randi() % (left.size() - 1)
		var p := left[i].lerp(right[i], rng.randf_range(0.25, 0.75))
		b.stroke(PackedVector2Array([p, p + Vector2(rng.randf_range(8, 16), 0)]), 2.4, Color(WATER_HI, 0.8))

static func _band(b: Face.Builder, left: PackedVector2Array, right: PackedVector2Array, inset: float, col: Color) -> void:
	for i in left.size() - 1:
		b.fan(PackedVector2Array([left[i] + Vector2(inset, 0), right[i] - Vector2(inset, 0),
			right[i + 1] - Vector2(inset, 0), left[i + 1] + Vector2(inset, 0)]), col)

## A deposit's heap of rocks over its 2x2, veined in its ore; a locked
## one is paler, under a small wooden "later" stake.
static func deposit(b: Face.Builder, i: int) -> void:
	var r := Sim.deposit_rect(i)
	var res := String(Sim.DEPOSITS[i][0])
	var purity := int(Sim.DEPOSITS[i][2])
	var live := Sim.is_live(i)
	var c := (Vector2(r.position) + Vector2(1, 1)) * TILE
	var cols: Array = ORE[res]
	var fade := 1.0 if live else 0.55
	b.ellipse(c + Vector2(0, 14), TILE * 0.95, TILE * 0.62, Color(GRASS_DEEP, 0.7))
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + i
	var n: int = [4, 6, 8][purity]
	var rocks := []
	for k in n:
		var a := k * TAU / n + rng.randf_range(-0.3, 0.3)
		var d := 0.0 if k == 0 else rng.randf_range(20.0, 40.0)
		rocks.append([c + Vector2(cos(a) * d, sin(a) * d * 0.7), rng.randf_range(17.0, 25.0) if k > 0 else 28.0])
	rocks.sort_custom(func(p: Array, q: Array) -> bool: return p[0].y < q[0].y)
	for rk: Array in rocks:
		var p: Vector2 = rk[0]
		var s: float = rk[1]
		b.ellipse(p + Vector2(0, s * 0.35), s * 1.05, s * 0.7, _fade(ROCK_DEEP, fade))
		b.ellipse(p, s, s * 0.82, _fade(ROCK, fade))
		b.ellipse(p + Vector2(-s * 0.25, -s * 0.3), s * 0.45, s * 0.3, _fade(ROCK_HI, fade))
		# veins and nuggets of the ore
		b.ellipse(p + Vector2(s * 0.3, s * 0.1), s * 0.34, s * 0.24, _fade(cols[1], fade))
		b.ellipse(p + Vector2(s * 0.24, s * 0.02), s * 0.26, s * 0.18, _fade(cols[0], fade))
		b.disc(p + Vector2(-s * 0.35, s * 0.25), s * 0.13, _fade(cols[2], fade))
	if not live:
		var at := c + Vector2(TILE * 0.62, -TILE * 0.5)
		b.fan(Face.Builder.round_rect(at + Vector2(-3, 0), Vector2(6, 34), 2.0), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(at + Vector2(-20, -8), Vector2(40, 20), 5.0), WOOD)
		b.fan(Face.Builder.round_rect(at + Vector2(-17, -5), Vector2(34, 5), 2.0), WOOD_HI)
		b.disc(at + Vector2(0, 2), 3.2, INK)

static func _fade(c: Color, k: float) -> Color:
	return c if k >= 1.0 else c.lerp(Color("d8d3c8"), 1.0 - k)

## The Mill: a timber mill on its 3x3 with a red roof, a door facing down
## the valley and, on the stream side, a wheel (drawn live, it turns).
static func mill(b: Face.Builder) -> void:
	var r := Rect2(Vector2(Sim.MILL.position) * TILE, Vector2(Sim.MILL.size) * TILE)
	var foot := r.grow(-10.0)
	b.fan(Face.Builder.round_rect(foot.position + Vector2(-6, 18), foot.size + Vector2(12, 4), 22.0), Color(0.2, 0.3, 0.1, 0.22))
	# walls: plaster over a stone plinth, timber posts
	var wall := Rect2(foot.position + Vector2(0, 50), Vector2(foot.size.x, foot.size.y - 50))
	b.fan(Face.Builder.round_rect(wall.position, wall.size, 14.0), BANK_DEEP)
	b.fan(Face.Builder.round_rect(wall.position, wall.size - Vector2(0, 14), 12.0), PLASTER)
	for k in 4:
		var x := wall.position.x + 8.0 + k * (wall.size.x - 16.0) / 3.0
		b.fan(Face.Builder.round_rect(Vector2(x - 5, wall.position.y), Vector2(10, wall.size.y - 14), 3.0), WOOD)
	# the door and a window either side
	var door := Rect2(Vector2(wall.get_center().x - 22, wall.end.y - 72), Vector2(44, 58))
	b.fan(Face.Builder.round_rect(door.position, door.size, 16.0), WOOD_DEEP)
	b.fan(Face.Builder.round_rect(door.position + Vector2(5, 6), door.size - Vector2(10, 6), 12.0), WOOD)
	for sx in [-1.0, 1.0]:
		var win := Vector2(wall.get_center().x + sx * 58.0, wall.position.y + 34.0)
		b.fan(Face.Builder.round_rect(win - Vector2(15, 13), Vector2(30, 26), 6.0), WOOD_DEEP)
		b.fan(Face.Builder.round_rect(win - Vector2(11, 9), Vector2(22, 18), 4.0), Color("fbe7a6"))
	# the roof, seen from above and in front: a ridge, two slopes
	var roof := Rect2(foot.position + Vector2(-14, -8), Vector2(foot.size.x + 28, 84))
	b.fan(Face.Builder.round_rect(roof.position + Vector2(0, 8), roof.size, 18.0), ROOF_DEEP)
	b.fan(Face.Builder.round_rect(roof.position, roof.size, 18.0), ROOF)
	b.fan(Face.Builder.round_rect(roof.position + Vector2(10, 8), Vector2(roof.size.x - 20, 22), 10.0), ROOF_HI)
	for k in 7:
		var x := roof.position.x + 18.0 + k * (roof.size.x - 36.0) / 6.0
		b.stroke(PackedVector2Array([Vector2(x, roof.position.y + 36), Vector2(x, roof.end.y - 6)]), 3.0, Color(ROOF_DEEP, 0.5))
	# a sign over the door: the millstone
	var stone := Vector2(wall.get_center().x, wall.position.y + 8)
	b.disc(stone, 20.0, ROCK_DEEP)
	b.disc(stone, 16.0, ROCK_HI)
	b.disc(stone, 5.0, ROCK_DEEP)

## The mill's wheel in the stream beside it, at `turn` radians.
static func wheel(b: Face.Builder, turn: float) -> void:
	var r := Rect2(Vector2(Sim.MILL.position) * TILE, Vector2(Sim.MILL.size) * TILE)
	var c := Vector2(r.position.x - 4.0, r.get_center().y + 20.0)
	b.ellipse(c + Vector2(0, 10), 46.0, 16.0, Color(WATER_HI, 0.6))
	b.fan(Face.Builder.round_rect(c - Vector2(12, 50), Vector2(24, 100), 8.0), WOOD_DEEP)
	for k in 8:
		var a := turn + k * TAU / 8.0
		var y := sin(a) * 44.0
		var depth := cos(a)
		var col := WOOD_HI if depth > 0.0 else WOOD_DEEP
		b.fan(Face.Builder.round_rect(c + Vector2(-16, y - 5), Vector2(32, 10), 3.0), col)
	b.disc(c, 9.0, WOOD_DEEP)
	b.disc(c, 5.0, WOOD_HI)

## A kiln on its 2x2 with its top-left at `at` (world px): a brick dome,
## its mouth to the front, a chimney at the back. `alpha` fades it (the
## placing ghost), `tint` washes it (red where it cannot go).
static func kiln(b: Face.Builder, at: Vector2, alpha := 1.0, tint := Color(1, 1, 1, 0)) -> void:
	var c := at + Vector2(TILE, TILE)
	var t := func(col: Color) -> Color:
		var o := col.lerp(Color(tint.r, tint.g, tint.b), tint.a)
		o.a *= alpha
		return o
	b.ellipse(c + Vector2(0, 30), 58.0, 26.0, t.call(Color(0.2, 0.3, 0.1, 0.25)))
	# the chimney behind
	b.fan(Face.Builder.round_rect(c + Vector2(14, -66), Vector2(24, 50), 6.0), t.call(BRICK_DEEP))
	b.fan(Face.Builder.round_rect(c + Vector2(12, -70), Vector2(28, 10), 4.0), t.call(SOOT))
	# the dome
	b.ellipse(c + Vector2(0, 6), 54.0, 44.0, t.call(BRICK_DEEP))
	b.ellipse(c, 52.0, 42.0, t.call(BRICK))
	b.ellipse(c + Vector2(-14, -16), 26.0, 16.0, t.call(BRICK_HI))
	# courses of brick
	for k in 3:
		var y := c.y - 22.0 + k * 16.0
		var half := sqrt(maxf(0.0, 1.0 - pow((y - c.y) / 42.0, 2.0))) * 50.0
		b.stroke(PackedVector2Array([Vector2(c.x - half, y), Vector2(c.x + half, y)]), 2.2, t.call(Color(BRICK_DEEP, 0.6)))
	# the mouth, dark until the fire is drawn in it
	b.ellipse(c + Vector2(0, 18), 20.0, 16.0, t.call(SOOT))
	b.fan(Face.Builder.round_rect(c + Vector2(-26, 28), Vector2(52, 10), 4.0), t.call(ROCK_DEEP))

## One lump of ore, `r` across.
static func ore(b: Face.Builder, c: Vector2, r: float, res := "iron") -> void:
	var cols: Array = ORE[res]
	b.ellipse(c + Vector2(0, r * 0.25), r, r * 0.75, cols[1])
	b.ellipse(c, r * 0.95, r * 0.72, cols[0])
	b.disc(c + Vector2(-r * 0.3, -r * 0.25), r * 0.28, cols[2])

## One ingot, a small bar `w` long.
static func ingot(b: Face.Builder, c: Vector2, w: float) -> void:
	var h := w * 0.42
	b.fan(Face.Builder.round_rect(c - Vector2(w * 0.5, h * 0.5 - h * 0.18), Vector2(w, h), h * 0.3), INGOT_DEEP)
	b.fan(Face.Builder.round_rect(c - Vector2(w * 0.5, h * 0.5), Vector2(w, h * 0.82), h * 0.3), INGOT)
	b.fan(Face.Builder.round_rect(c - Vector2(w * 0.36, h * 0.38), Vector2(w * 0.72, h * 0.22), h * 0.1), INGOT_HI)

## The bag: a burlap sack `s` across, centred on `c`, tied at the neck,
## a lump of ore peeking out of its mouth.
static func sack(b: Face.Builder, c: Vector2, s: float) -> void:
	var body := PackedVector2Array()
	for k in 28:
		var a := k * TAU / 28.0
		var r := Vector2(0.4, 0.34) * s
		# wider at the foot than at the shoulders
		var widen := 1.0 + 0.16 * sin(a)
		body.append(c + Vector2(cos(a) * r.x * widen, 0.1 * s + sin(a) * r.y))
	var deep := PackedVector2Array()
	for v in body:
		deep.append(v + Vector2(0, s * 0.05))
	b.fan(deep, SACK_DEEP)
	b.fan(body, SACK)
	b.ellipse(c + Vector2(-0.14, 0.0) * s, s * 0.14, s * 0.1, SACK_HI)
	# the mouth, gathered above the tie, and what peeks out of it
	ore(b, c + Vector2(0.02, -0.3) * s, s * 0.12)
	b.fan(PackedVector2Array([c + Vector2(-0.2, -0.3) * s, c + Vector2(-0.08, -0.2) * s, c + Vector2(0.08, -0.2) * s,
		c + Vector2(0.22, -0.32) * s, c + Vector2(0.1, -0.14) * s, c + Vector2(-0.1, -0.14) * s]), SACK)
	b.fan(Face.Builder.round_rect(c + Vector2(-0.16, -0.2) * s, Vector2(0.32, 0.08) * s, s * 0.03), WOOD_DEEP)
	b.stroke(PackedVector2Array([c + Vector2(0.1, -0.16) * s, c + Vector2(0.2, -0.06) * s]), s * 0.035, WOOD_DEEP)
	# a patch, stitched on
	b.fan(Face.Builder.round_rect(c + Vector2(0.08, 0.1) * s, Vector2(0.16, 0.14) * s, s * 0.03), SACK_DEEP)
	for k in 3:
		var y := 0.13 + k * 0.045
		b.stroke(PackedVector2Array([c + Vector2(0.1, y) * s, c + Vector2(0.14, y) * s]), s * 0.015, SACK_HI)

## A chip's picture, `s` pixels across, centred on the origin: "kiln",
## "eraser" or "drill" (the one still to come, drawn quiet).
static func icon(kind: String, s: float) -> ArrayMesh:
	var key := "icon/%s/%.1f" % [kind, s]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var k := s / (TILE * 2.2)
	match kind:
		"kiln":
			var tmp := Face.Builder.new()
			kiln(tmp, Vector2(-TILE, -TILE * 0.9))
			_scaled(b, tmp, k)
		"eraser":
			var body := PackedVector2Array([Vector2(-0.34, 0.1), Vector2(0.06, -0.3), Vector2(0.34, -0.02), Vector2(-0.06, 0.38)])
			var tip := PackedVector2Array([Vector2(-0.34, 0.1), Vector2(-0.12, -0.12), Vector2(0.16, 0.16), Vector2(-0.06, 0.38)])
			for i in body.size():
				body[i] *= s
				tip[i] *= s
			b.fan(body, Color("f28b8b"))
			b.fan(tip, Color("fbe3d4"))
			b.stroke(PackedVector2Array([Vector2(-0.4, 0.44) * s, Vector2(0.4, 0.44) * s]), s * 0.04, INK)
		"drill":
			b.fan(Face.Builder.round_rect(Vector2(-0.28, -0.3) * s, Vector2(0.56, 0.42) * s, s * 0.08), Color("c9c2b5"))
			b.fan(PackedVector2Array([Vector2(-0.14, 0.12) * s, Vector2(0.14, 0.12) * s, Vector2(0, 0.42) * s]), Color("a39c92"))
		"sack":
			sack(b, Vector2.ZERO, s)
		"bag_iron_ore":
			# a small heap: three lumps
			ore(b, Vector2(-0.2, 0.14) * s, s * 0.2)
			ore(b, Vector2(0.2, 0.16) * s, s * 0.19)
			ore(b, Vector2(0.0, -0.1) * s, s * 0.22)
		"bag_iron_ingot":
			# a small stack: two bars and one across them
			ingot(b, Vector2(-0.14, 0.2) * s, s * 0.5)
			ingot(b, Vector2(0.16, 0.2) * s, s * 0.5)
			ingot(b, Vector2(0.0, -0.06) * s, s * 0.56)
	var m := b.mesh()
	_cache[key] = m
	return m

static func _scaled(into: Face.Builder, from: Face.Builder, k: float) -> void:
	var base := into.verts.size()
	for i in from.verts.size():
		into.verts.append(from.verts[i] * k)
		into.cols.append(from.cols[i])
	for i in from.idx:
		into.idx.append(base + i)
