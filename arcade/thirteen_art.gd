extends RefCounted

## Lucky Thirteen's drawings (spec
## docs/superpowers/specs/2026-09-27-arcade-thirteen-design.md): painted
## river pebbles, one colour a number, the gold thirteen with its
## four-leaf clover, the clover the tools are bought with, and the five
## tools' pictures. Each is built once per look and size, its origin at the
## centre, and moved by the draw transform; shared with the Arcade tab's
## banner. The number is lettered over the mesh by the caller (`number()`),
## because a glyph is not a mesh.

const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const INK := Color("3b3028")
const SAND := Color("efe2c6")
const SAND_DEEP := Color("dcc9a4")
const MOSS := Color("8dba58")
const MOSS_DEEP := Color("6f9c46")
const CLOVER := Color("5fae5a")
const CLOVER_DEEP := Color("3f8a45")
const GOLD := Color("f2b632")
const WOOD := Color("c89664")
const WOOD_DEEP := Color("9c6b45")

## A number's paint: 1 rose and 2 sky as the reference has them, round the
## wheel to 12's deep teal, 13 gold, and the dark stones past it.
const PAINT := [
	Color("efe6d8"),  # 0 (unused)
	Color("ec7f8c"),  # 1
	Color("6fb4e2"),  # 2
	Color("98c96c"),  # 3
	Color("f5b77e"),  # 4
	Color("c98ac6"),  # 5
	Color("5fc1ad"),  # 6
	Color("ee8d6e"),  # 7
	Color("9391dc"),  # 8
	Color("c9c052"),  # 9
	Color("d9774a"),  # 10
	Color("8a5a9e"),  # 11
	Color("3f7f8c"),  # 12
	Color("f2b632"),  # 13
	Color("4a4250"),  # 14
	Color("a8455a"),  # 15
	Color("2f3a4a"),  # 16
]

## The lit stones (shaders/pebble_bake_2d.gdshader), one cell a number, baked
## once by ensure_skin(); null until then and for good where nothing renders,
## and pebble() falls back to its flat drawing.
const PEBBLE_SHADER = preload("res://shaders/pebble_bake_2d.gdshader")
const SKIN_CELL := 320
const SKIN_SIDE := 4
const SKIN_SPAN := 1.3

static var _cache := {}
static var _skin: ImageTexture
static var _skin_busy := false

## A stone's line: its own paint deepened and cooled (the shader's deepen()).
static func line_colour(v: int) -> Color:
	var c := paint(v)
	return c.lerp(Color(c.r * c.r * 0.72, c.g * c.g * 0.66, c.b * c.b * 0.86), 0.92)

## The atlas pebble()'s quads are cut from; pass it as draw_mesh's texture.
static func skin() -> Texture2D:
	return _skin

## Draw `items` ([Rect2, Material] each, or [Rect2, Control] for a node laid
## over them) into a picture `size` pixels, once,
## off screen. Null where nothing renders (headless) or `host` left the tree.
static func bake(host: Node, items: Array, size: Vector2i, mipmaps := false) -> ImageTexture:
	if DisplayServer.get_name() == "headless" or not host.is_inside_tree():
		return null
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	for it: Array in items:
		var rect: Control = ColorRect.new() if it[1] is Material else it[1]
		rect.position = it[0].position
		rect.size = it[0].size
		if it[1] is Material:
			rect.material = it[1]
		vp.add_child(rect)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	if not is_instance_valid(vp) or not vp.is_inside_tree():
		return null
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return null
	if mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Bake the stones if they are not baked yet, then call `done` (to redraw).
static func ensure_skin(host: Node, done := Callable()) -> void:
	if _skin == null and not _skin_busy:
		_skin_busy = true
		var items := []
		for v in range(1, PAINT.size()):
			var m := ShaderMaterial.new()
			m.shader = PEBBLE_SHADER
			m.set_shader_parameter("value", float(v))
			m.set_shader_parameter("base", PAINT[v])
			m.set_shader_parameter("px", 2.0 * SKIN_SPAN / SKIN_CELL)
			var cell := Rect2(Vector2((v - 1) % SKIN_SIDE, (v - 1) / SKIN_SIDE) * SKIN_CELL, Vector2(SKIN_CELL, SKIN_CELL))
			items.append([cell, m])
			# the number, lettered into the picture: paper, lined in the
			# stone's own deep colour, with the line's lip under it
			var deep := line_colour(v)
			for k in 2:
				var word := Label.new()
				word.text = str(v)
				word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				word.add_theme_font_override("font", font())
				word.add_theme_font_size_override("font_size", int(SKIN_CELL * (0.37 if v < 10 else 0.31)))
				word.add_theme_color_override("font_color", deep if k == 0 else Color("fffaf0"))
				word.add_theme_color_override("font_outline_color", deep)
				word.add_theme_constant_override("outline_size", int(SKIN_CELL * 0.075))
				var lift := SKIN_CELL * (-0.048 + (0.022 if k == 0 else 0.0))
				items.append([Rect2(cell.position + Vector2(0, lift), cell.size), word])
		var side := SKIN_CELL * SKIN_SIDE
		_skin = await bake(host, items, Vector2i(side, side), true)
		_skin_busy = false
		_cache.clear()
	while _skin_busy and is_instance_valid(host) and host.is_inside_tree():
		await host.get_tree().process_frame
	if _skin != null and done.is_valid():
		done.call()

## The quad a baked stone is drawn on: its cell of the atlas, `s` across the
## stone itself (the cell is wider, for the shadow).
static func _skin_quad(v: int, s: float) -> ArrayMesh:
	var half := s * 0.5 * SKIN_SPAN
	var cell := Vector2((v - 1) % SKIN_SIDE, (v - 1) / SKIN_SIDE)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([cell / SKIN_SIDE, (cell + Vector2(1, 0)) / SKIN_SIDE, (cell + Vector2(1, 1)) / SKIN_SIDE, (cell + Vector2(0, 1)) / SKIN_SIDE])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

static func paint(v: int) -> Color:
	return PAINT[clampi(v, 0, PAINT.size() - 1)]

## Ink or paper, whichever reads on the pebble's paint.
static func number_colour(v: int) -> Color:
	if v == 13:
		return Color("7a4a10")
	return Color("fffaf0") if paint(v).get_luminance() < 0.56 else INK

## The pebble's outline: a circle pressed a little out of round, each number
## its own way, so a tray of them reads as stones and not as buttons.
static func _outline(v: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 40
	var ph := float(v) * 1.7
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + 0.035 * sin(a * 2.0 + ph) + 0.02 * sin(a * 3.0 + ph * 1.3)
		pts.append(Vector2(cos(a) * r * k * 1.03, sin(a) * r * k * 0.97))
	return pts

## A pebble of number `v`, `s` pixels across, centred on the origin: a soft
## shadow, a darker underside, the painted face lit from the top left, a
## few speckles and a sheen. 13 is gold with a clover in its lap.
static func pebble(v: int, s: float) -> ArrayMesh:
	var key := "p%d_%d" % [v, roundi(s)]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 300:
		_cache.clear()
	if _skin != null and v >= 1 and v < PAINT.size():
		_cache[key] = _skin_quad(v, s)
		return _cache[key]
	var b := Face.Builder.new()
	var r := s * 0.5
	var base := paint(v)
	var deep := base.darkened(0.3)
	# the shadow it casts on the sand, down and to the right
	var shadow := _outline(v, r * 0.98)
	for i in shadow.size():
		shadow[i] = shadow[i] + Vector2(r * 0.06, r * 0.12)
	b.fan(shadow, Color(0.3, 0.2, 0.08, 0.2))
	# the underside, then the face lifted off it
	b.fan(_outline(v, r), deep)
	var face := _outline(v, r * 0.93)
	for i in face.size():
		face[i] = face[i] + Vector2(-r * 0.025, -r * 0.05)
	b.fan(face, base)
	# the lit crown, a paler oval up and to the left
	b.ellipse(Vector2(-r * 0.12, -r * 0.2), r * 0.66, r * 0.56, base.lightened(0.1))
	# the shade round the lower right, a crescent inside the rim
	var shade := PackedVector2Array()
	for i in 17:
		shade.append(Vector2.from_angle(lerpf(-0.25, PI * 0.95, i / 16.0)) * r * 0.88 + Vector2(-r * 0.02, -r * 0.04))
	for i in 17:
		shade.append(Vector2.from_angle(lerpf(PI * 0.95, -0.25, i / 16.0)) * r * 0.7 + Vector2(-r * 0.12, -r * 0.14))
	b.polygon(shade, Color(deep, 0.35))
	# speckles, seeded by the number so every 5 wears the same ones
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + v
	for i in 7:
		var p := Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.2, 0.75)
		b.disc(p, r * rng.randf_range(0.018, 0.035), Color(deep if i % 2 == 0 else base.lightened(0.3), 0.45))
	# a stone dresses up as it grows: a painted band round it from 5, a
	# second one from 9, and flecks of gold from 10
	if v >= 5 and v < 13:
		var band := _outline(v, r * 0.74)
		for i in band.size():
			band[i] = band[i] + Vector2(-r * 0.025, -r * 0.05)
		b.stroke(band, maxf(1.5, s * 0.03), Color(base.lightened(0.42), 0.55), true)
		if v >= 9:
			var inner := _outline(v, r * 0.64)
			for i in inner.size():
				inner[i] = inner[i] + Vector2(-r * 0.025, -r * 0.05)
			b.stroke(inner, maxf(1.0, s * 0.014), Color(base.darkened(0.2), 0.45), true)
		if v >= 10:
			for i in 5:
				var a := TAU * (i + 0.3) / 5.0 + float(v)
				b.disc(Vector2.from_angle(a) * r * 0.74 + Vector2(-r * 0.025, -r * 0.05), maxf(1.2, r * 0.035), Color(GOLD.lightened(0.2), 0.9))
	# the rim light along the upper left edge, and the sheen
	b.stroke(Face.Builder.arc_points(Vector2(-r * 0.025, -r * 0.05), r * 0.86, PI * 1.02, PI * 1.62), maxf(1.5, s * 0.022), Color(1, 1, 1, 0.3))
	b.ellipse(Vector2(-r * 0.36, -r * 0.46), r * 0.2, r * 0.1, Color(1, 1, 1, 0.55))
	b.disc(Vector2(-r * 0.12, -r * 0.6), r * 0.045, Color(1, 1, 1, 0.5))
	if v == 13:
		# gilt: a bright rim and a clover tucked at the lower right
		b.stroke(_outline(v, r * 0.86), maxf(1.5, s * 0.02), Color("fff1b8", 0.8), true)
		_clover(b, Vector2(r * 0.5, r * 0.46), r * 0.26, 0.4)
	elif v > 13:
		b.stroke(_outline(v, r * 0.86), maxf(1.5, s * 0.02), Color(GOLD, 0.7), true)
	var m := b.mesh()
	_cache[key] = m
	return m

## The chain's soft glow under a picked pebble: a ring of its own paint.
static func halo(v: int, s: float) -> ArrayMesh:
	var key := "h%d_%d" % [v, roundi(s)]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := s * 0.5
	var c := paint(v).lightened(0.35)
	b.disc(Vector2.ZERO, r * 1.2, Color("fffaf0"))
	b.disc(Vector2.ZERO, r * 1.2 - maxf(3.0, s * 0.05), Color(c, 1.0).lerp(Color("fffaf0"), 0.25))
	var m := b.mesh()
	_cache[key] = m
	return m

## A four-pointed twinkle of radius `r` at `c`, turned by `turn`, laid into
## a builder: the glint that runs over a pebble now and then.
static func glint(b: Face.Builder, c: Vector2, r: float, turn: float, col := Color(1, 1, 0.95, 0.95)) -> void:
	b.disc(c, r * 0.45, Color(col, col.a * 0.26))
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + turn)
		var side := d.orthogonal() * r * 0.13
		b.polygon(PackedVector2Array([c + side, c + d * r * (1.0 if k % 2 == 0 else 0.7), c - side]), col)
	b.disc(c, r * 0.14, Color(1, 1, 1, col.a))

## A five-pointed star of radius `r`, with a darker drop and a shine.
static func star(b: Face.Builder, c: Vector2, r: float, col: Color, turn := 0.0) -> void:
	for pass_ in 2:
		var pts := PackedVector2Array()
		var at := c + (Vector2(r * 0.04, r * 0.1) if pass_ == 0 else Vector2.ZERO)
		var rr := r * (1.08 if pass_ == 0 else 1.0)
		for i in 10:
			var a := TAU * i / 10.0 - PI * 0.5 + turn
			pts.append(at + Vector2.from_angle(a) * (rr if i % 2 == 0 else rr * 0.52))
		b.polygon(pts, Color(col.darkened(0.35), col.a) if pass_ == 0 else col)
	b.ellipse(c + Vector2(-r * 0.18, -r * 0.2), r * 0.18, r * 0.11, Color(1, 1, 1, 0.5 * col.a))

## A sunburst laid into a builder: `n` rays between `r0` and `r1`.
static func sunrays(b: Face.Builder, c: Vector2, r0: float, r1: float, n: int, turn: float, col: Color) -> void:
	var half := PI / n * 0.5
	for i in n:
		var a := TAU * i / n + turn
		b.polygon(PackedVector2Array([c + Vector2.from_angle(a - half * 0.4) * r0, c + Vector2.from_angle(a - half) * r1,
			c + Vector2.from_angle(a + half) * r1, c + Vector2.from_angle(a + half * 0.4) * r0]), col)

## An ellipse turned by `rot`: a scrap of confetti.
static func petal(b: Face.Builder, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	b.fan(pts, col)

## A chip knocked off a pebble by a merge: a lopsided shard in its paint,
## lit on one face.
static func chip(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 5:
		var a := TAU * i / 5.0 + rot
		pts.append(c + Vector2.from_angle(a) * r * (1.0 if i % 2 == 0 else 0.62))
	b.polygon(pts, Color(col.darkened(0.2), col.a))
	b.polygon(PackedVector2Array([c, pts[0], pts[1]]), Color(col.lightened(0.35), col.a))

## A gold coin turning over: `turn` in 0..1 is how much of its face shows.
static func coin(b: Face.Builder, c: Vector2, r: float, turn: float, a := 1.0) -> void:
	var w := maxf(0.12, absf(turn))
	b.ellipse(c, r * w, r, Color(Color("b9811c"), a))
	b.ellipse(c, r * w * 0.8, r * 0.8, Color(GOLD, a))
	b.ellipse(c + Vector2(-r * w * 0.25, -r * 0.3), r * w * 0.22, r * 0.2, Color(1, 1, 0.9, 0.7 * a))

## A sunburst of `n` soft rays, `s` across, in `c`, for a new number.
static func rays(s: float, c: Color, n := 12) -> ArrayMesh:
	var key := "r%d_%s_%d" % [roundi(s), c.to_html(), n]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := s * 0.5
	b.disc(Vector2.ZERO, r * 0.55, Color(c, 0.22))
	b.disc(Vector2.ZERO, r * 0.4, Color(c, 0.25))
	for k in n:
		var a := TAU * k / n
		var w := PI / n * 0.55
		var i0 := b.vertex(Vector2.from_angle(a) * r * 0.2, Color(c, 0.5))
		var i1 := b.vertex(Vector2.from_angle(a - w) * r, Color(c, 0.0))
		var i2 := b.vertex(Vector2.from_angle(a + w) * r, Color(c, 0.0))
		b.tri(i0, i1, i2)
	var m := b.mesh()
	_cache[key] = m
	return m

## A four-leaf clover, `s` across, centred.
static func clover(s: float) -> ArrayMesh:
	var key := "c%d" % roundi(s)
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	_clover(b, Vector2.ZERO, s * 0.5, 0.0)
	var m := b.mesh()
	_cache[key] = m
	return m

static func _clover(b: Face.Builder, c: Vector2, r: float, turn: float) -> void:
	# the stem, curling down to the right
	b.stroke(Face.Builder.bezier2(c, c + Vector2(r * 0.3, r * 0.6).rotated(turn), c + Vector2(r * 0.75, r * 0.85).rotated(turn), 8), maxf(1.5, r * 0.14), CLOVER_DEEP)
	for k in 4:
		var a := turn + TAU * k / 4.0 - PI * 0.25
		var dir := Vector2.from_angle(a)
		var at := c + dir * r * 0.42
		# a heart-shaped leaf: two lobes and a point toward the middle
		var side := dir.orthogonal()
		b.disc(at + side * r * 0.16 + dir * r * 0.06, r * 0.27, CLOVER_DEEP)
		b.disc(at - side * r * 0.16 + dir * r * 0.06, r * 0.27, CLOVER_DEEP)
		b.polygon(PackedVector2Array([c + dir * r * 0.05, at + side * r * 0.4 + dir * r * 0.1, at - side * r * 0.4 + dir * r * 0.1]), CLOVER_DEEP)
		b.disc(at + side * r * 0.15 + dir * r * 0.05, r * 0.22, CLOVER)
		b.disc(at - side * r * 0.15 + dir * r * 0.05, r * 0.22, CLOVER)
		b.polygon(PackedVector2Array([c + dir * r * 0.1, at + side * r * 0.33 + dir * r * 0.08, at - side * r * 0.33 + dir * r * 0.08]), CLOVER)
		b.stroke(PackedVector2Array([c + dir * r * 0.1, at + dir * r * 0.18]), maxf(1.0, r * 0.05), Color(1, 1, 1, 0.35))
	b.disc(c, r * 0.1, CLOVER_DEEP)

## A tool's picture, `s` across, centred: "undo" a curling arrow, "swap" two
## pebbles trading places, "pluck" a pebble lifted out of its hollow,
## "shuffle" three pebbles in a swirl, "lift" a pebble with an arrow up.
static func tool_icon(tool: String, s: float) -> ArrayMesh:
	var key := "t%s_%d" % [tool, roundi(s)]
	if _cache.has(key):
		return _cache[key]
	var b := Face.Builder.new()
	var r := s * 0.5
	var ink := Color("5a3f2e")
	match tool:
		"undo":
			var arc := Face.Builder.arc_points(Vector2(0, r * 0.08), r * 0.55, PI * 1.05, PI * 2.75)
			b.stroke(arc, r * 0.2, ink)
			var tip: Vector2 = arc[0]
			b.polygon(PackedVector2Array([tip + Vector2(-r * 0.3, -r * 0.02), tip + Vector2(r * 0.22, -r * 0.1), tip + Vector2(-r * 0.02, r * 0.34)]), ink)
		"swap":
			_mini(b, Vector2(-r * 0.42, r * 0.28), r * 0.34, 1)
			_mini(b, Vector2(r * 0.42, -r * 0.28), r * 0.34, 2)
			b.stroke(Face.Builder.bezier2(Vector2(-r * 0.5, -r * 0.2), Vector2(-r * 0.2, -r * 0.75), Vector2(r * 0.12, -r * 0.62), 10), r * 0.12, ink)
			b.polygon(PackedVector2Array([Vector2(r * 0.02, -r * 0.84), Vector2(r * 0.28, -r * 0.6), Vector2(r * 0.0, -r * 0.44)]), ink)
			b.stroke(Face.Builder.bezier2(Vector2(r * 0.5, r * 0.2), Vector2(r * 0.2, r * 0.75), Vector2(-r * 0.12, r * 0.62), 10), r * 0.12, ink)
			b.polygon(PackedVector2Array([Vector2(-r * 0.02, r * 0.84), Vector2(-r * 0.28, r * 0.6), Vector2(r * 0.0, r * 0.44)]), ink)
		"pluck":
			b.ellipse(Vector2(0, r * 0.62), r * 0.6, r * 0.2, Color(SAND_DEEP.darkened(0.25), 0.9))
			b.ellipse(Vector2(0, r * 0.6), r * 0.48, r * 0.13, Color(SAND_DEEP.darkened(0.4), 0.9))
			_mini(b, Vector2(0, -r * 0.2), r * 0.44, 7)
			for dx in [-1.0, 1.0]:
				b.stroke(PackedVector2Array([Vector2(dx * r * 0.62, r * 0.18), Vector2(dx * r * 0.74, -r * 0.05)]), r * 0.09, Color(ink, 0.7))
		"shuffle":
			var swirl := Face.Builder.arc_points(Vector2.ZERO, r * 0.62, -PI * 0.2, PI * 1.5)
			b.stroke(swirl, r * 0.08, Color(ink, 0.55))
			_mini(b, Vector2.from_angle(-PI * 0.5) * r * 0.5, r * 0.28, 1)
			_mini(b, Vector2.from_angle(PI * 0.17) * r * 0.5, r * 0.28, 2)
			_mini(b, Vector2.from_angle(PI * 0.83) * r * 0.5, r * 0.28, 3)
		"lift":
			_mini(b, Vector2(-r * 0.18, r * 0.2), r * 0.52, 5)
			var a := Vector2(r * 0.55, r * 0.3)
			b.stroke(PackedVector2Array([a, a + Vector2(0, -r * 0.7)]), r * 0.16, Color(GOLD.darkened(0.2)))
			b.polygon(PackedVector2Array([a + Vector2(-r * 0.3, -r * 0.55), a + Vector2(r * 0.3, -r * 0.55), a + Vector2(0, -r * 0.95)]), Color(GOLD.darkened(0.2)))
	var m := b.mesh()
	_cache[key] = m
	return m

## A plain little pebble for a picture: no speckles, no number.
static func _mini(b: Face.Builder, c: Vector2, r: float, v: int) -> void:
	b.disc(c + Vector2(r * 0.06, r * 0.1), r, Color(0.3, 0.2, 0.08, 0.18))
	b.disc(c, r, paint(v).darkened(0.25))
	b.disc(c + Vector2(-r * 0.04, -r * 0.06), r * 0.9, paint(v))
	b.ellipse(c + Vector2(-r * 0.34, -r * 0.42), r * 0.22, r * 0.11, Color(1, 1, 1, 0.5))

## The number on a pebble, lettered centred on `c` with a soft drop.
static func number(ci: CanvasItem, font: Font, c: Vector2, v: int, s: float, alpha := 1.0) -> void:
	if _skin != null and v >= 1 and v < PAINT.size():
		return
	var text := str(v)
	var fs := int(s * (0.46 if text.length() == 1 else 0.4))
	var col := number_colour(v)
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var at := c + Vector2(-size.x * 0.5 - s * 0.012, (font.get_ascent(fs) - font.get_descent(fs)) * 0.5 - s * 0.05)
	var drop := Color(0.2, 0.12, 0.05, 0.25 * alpha) if col == INK else Color(0.15, 0.08, 0.05, 0.4 * alpha)
	ci.draw_string(font, at + Vector2(0, s * 0.025), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, drop)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col, alpha))

## The display face every number is lettered in.
static func font() -> Font:
	return CozyTheme.display(700)
