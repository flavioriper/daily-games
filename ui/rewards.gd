extends Control

## The loud rewards Firefly and Molehill share: a layer laid over the whole
## screen that owns the bits flung about (sparks, stars, coins, confetti,
## clods, shards, hearts, motes and rings), the stickers (words lettered a
## hopping letter at a time, over a turning sunburst when they are loud) and
## the rain that falls after a big moment. The kit is the one Stackwood,
## Lucky Thirteen and Posy each carry in their own screen, lifted here once
## so a screen only says *when* to celebrate.
##
## Everything is in this layer's own pixels; `at(c, p)` maps a point of any
## control into them. The screen steps it (`step`) from its own clock, so a
## pause stops it, and it draws itself as one mesh plus the stickers'
## letters. Under reduce motion the bits, rings and rain are never made and
## a sticker is lettered still.
##
## The bits are copies (Drumbeat's checkup, 2026-10-03): each kind is one
## look made once in slot colours (`_bit_shape`), and a frame's bits are that
## look under each bit's place, turn and size, appended natively, its colours
## painted a run at a time and its indices tiled -- a mesh a kind in the air.
## Drawing every bit in script cost 2-4 ms a frame through a win's rain. A
## bit's fade is cut into FADE_STEPS so its painted colours are found again.

const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")

const STICKER_COLS := [Color("ff6f61"), Color("ffb03b"), Color("ffd84d"), Color("7fd66a"), Color("5cb8ff"), Color("b77be6")]
const CONFETTI := [Color("f7dc9c"), Color("ee8d6e"), Color("9391dc"), Color("5fc1ad"), Color("f2b632"), Color("f4a7a0")]
const GOLD := Color("f2c14e")
const GOLD_DEEP := Color("c98f22")
## The most bits alive at once.
const MAX_BITS := 480
const RunMesh = preload("res://ui/flat/run_mesh.gd")
## The kinds drawn as copies, in paint order; a mote is its glow and its heart.
const KINDS := ["confetti", "star", "spark", "coin", "heart", "clod", "shard", "note", "mote", "mote_in"]
const FADE_STEPS := 16.0
## Indices are tiled this many copies at a time.
const TILE_CHUNK := 16
## The looks, shared by every layer: they are in pixels at size 1.
static var _kit: RunMesh
static var _tiled: Array = []

## {pos, vel, rot, spin, t, life, kind, col, size, float?, to?}
var bits: Array = []
## {text, at, t, life, size, rainbow, col, rays, tilt, id, rise}
var stickers: Array = []
## Seconds of rain still falling, and what it is made of.
var _rain := 0.0
var _rain_kinds: Array = ["confetti"]
var _rain_cols: Array = CONFETTI
## A rainbow sticker's letters, one after another: a screen in softer paint
## hands its own (Peapod's pastels).
var sticker_cols: Array = STICKER_COLS
## Where stickers must stay inside, in this layer's pixels; empty = anywhere.
var bounds := Rect2()
var _clock := 0.0
var _mesh: ArrayMesh
var _meshes: Array = []
var _ray_mesh: ArrayMesh
var _font: Font
## Words a screen will letter later, [text, size, next letter]: see warm().
var _warm: Array = []
## Sunbursts drawn added to what is under them rather than laid over it: on
## a night sky pale gold laid over navy reads as grey haze, added it glows.
var _rays: Control
## The sunburst's glow, outer rays and inner rays.
var _ray_cols := [Color(Color("fff4c2"), 0.35), Color(Color("ffe39a"), 0.34), Color(Color("fffaf0"), 0.24)]

func _init() -> void:
	name = "Rewards"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = CozyTheme.display(700)
	_rays = Control.new()
	_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rays.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rays.show_behind_parent = true
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

## Sunbursts glow (added) rather than lie over what is under them; for a
## dark ground.
func set_additive(on: bool) -> void:
	if on:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_rays.material = m
		# added light stacks, so it is warm and faint to start with
		_ray_cols = [Color(Color("b87a1e"), 0.3), Color(Color("c98f22"), 0.32), Color(Color("8a6a3a"), 0.28)]
	else:
		_rays.material = null
		_ray_cols = [Color(Color("fff4c2"), 0.35), Color(Color("ffe39a"), 0.34), Color(Color("fffaf0"), 0.24)]

func clear() -> void:
	bits.clear()
	stickers.clear()
	_rain = 0.0
	queue_redraw()

## A point `p` of control `c`, in this layer's pixels.
func at(c: CanvasItem, p: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * (c.get_global_transform() * p)

func font() -> Font:
	return _font

# --- making ---

## Throws `n` bits of `kind` out of `from` at up to `speed` px/s. A bit may
## be sent home (`to`): it flies out, then is pulled in and dies on arrival.
func spray(from: Vector2, col: Color, n: int, speed: float, kind := "spark", size := 1.0, delay := 0.0, to := Vector2.INF) -> void:
	if Motion.reduce:
		return
	n = mini(n, MAX_BITS - bits.size())
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * speed * randf_range(0.35, 1.0) + Vector2(0, -speed * 0.4)
		var bit := {"pos": from, "vel": v, "rot": randf() * TAU, "spin": randf_range(-10.0, 10.0), "t": -delay - (0.03 * i if to != Vector2.INF else 0.0),
			"life": randf_range(0.55, 0.95) + (0.6 if kind in ["confetti", "coin", "heart", "note"] else 0.0), "kind": kind,
			"col": col, "size": size * randf_range(0.7, 1.25)}
		if to != Vector2.INF:
			bit.to = to
			bit.life = 1.6
		bits.append(bit)

## A ring swelling out of `from` to `radius` and thinning away.
func ring(from: Vector2, radius: float, col: Color, delay := 0.0, life := 0.45) -> void:
	if Motion.reduce:
		return
	bits.append({"pos": from, "vel": Vector2.ZERO, "rot": 0.0, "spin": 0.0, "t": -delay, "life": life, "kind": "ring",
		"col": col, "size": radius})

## Rain over the whole layer for `seconds`: `kinds` picked at random, in
## `cols`.
func rain(seconds: float, kinds: Array = ["confetti", "star"], cols: Array = CONFETTI) -> void:
	_rain = maxf(_rain, seconds)
	_rain_kinds = kinds
	_rain_cols = cols

## Letters `text` at `fs` off screen a glyph a frame from now on, so its
## first sticker draws from the glyph cache: an outlined letter is four
## glyphs, each rasterised at its size the first time it is drawn, and a
## big word drawn cold cost Balance's solve a 30-45 ms frame on the M1.
func warm(text: String, fs: int) -> void:
	_warm.append([text, fs, 0])
	queue_redraw()

## A word lettered at `where`, each letter hopping in on its own, fitted to
## `bounds`. `rainbow` letters it in the sticker colours, else in `col`;
## `rays` turns a sunburst behind it. A sticker with an `id` replaces the one
## before it with the same id; `rise` lifts it a little as it lives. Any
## other live sticker it would cover pushes it down, unless it is `keep`.
func sticker(text: String, where: Vector2, fs: int, life: float, rainbow := true, col := Color.WHITE, rays := false, id := "", rise := 0.0, keep := false) -> Dictionary:
	if id != "":
		stickers = stickers.filter(func(st: Dictionary) -> bool: return String(st.id) != id)
	fs = _fit(text, fs)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if bounds.has_area():
		where.x = clampf(where.x, bounds.position.x + w * 0.5 + 20.0, bounds.end.x - w * 0.5 - 20.0)
		where.y = clampf(where.y, bounds.position.y + fs * 0.8, bounds.end.y - fs * 0.4)
	# make room: a sticker lands under any live one it would cover
	var h := fs * 1.05
	for pass_ in (0 if keep else 4):
		var moved := false
		for o: Dictionary in stickers:
			if float(o.t) > float(o.life) - 0.3:
				continue
			var ow := _font.get_string_size(o.text, HORIZONTAL_ALIGNMENT_LEFT, -1, o.size).x
			var oa: Vector2 = o.at
			var oh := float(o.size) * 1.05
			if absf(oa.x - where.x) < (ow + w) * 0.5 and absf(oa.y - where.y) < (oh + h) * 0.5:
				where.y = oa.y + (oh + h) * 0.5 + 6.0
				moved = true
		if not moved:
			break
	var st := {"text": text, "at": where, "t": 0.0, "life": life, "size": fs, "rainbow": rainbow, "col": col,
		"rays": rays and not Motion.reduce, "tilt": 0.0 if Motion.reduce else randf_range(-0.08, 0.08), "id": id,
		"rise": 0.0 if Motion.reduce else rise}
	stickers.append(st)
	return st

## The size `text` is lettered at: `fs`, or less if it would not fit across.
func _fit(text: String, fs: int) -> int:
	var room := (bounds.size.x if bounds.has_area() else self.size.x) - 40.0
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > room and w > 0.0 and room > 0.0:
		return int(fs * room / w)
	return fs

func has_sticker(id: String) -> bool:
	for st: Dictionary in stickers:
		if String(st.id) == id:
			return true
	return false

# --- the clock ---

func step(delta: float) -> void:
	_clock += delta
	if not bits.is_empty():
		var drag := exp(-delta * 2.2)
		for b: Dictionary in bits:
			b.t += delta
			if b.t < 0.0 or String(b.kind) == "ring":
				continue
			var v: Vector2 = b.vel
			if b.has("to"):
				# out along the throw, then pulled home ever harder
				var pull := clampf((b.t - 0.18) / 0.5, 0.0, 1.0)
				var home: Vector2 = b.to
				v = v * drag + (home - (b.pos as Vector2)) * 30.0 * pull * delta
				v = v.lerp((home - (b.pos as Vector2)) * 6.0, pull * pull * 0.5)
				b.pos += v * delta
				if pull > 0.3 and (b.pos as Vector2).distance_to(home) < 18.0:
					b.t = b.life
			elif b.get("float", false):
				v.y = minf(v.y + 120.0 * delta, 300.0)
				b.pos += Vector2(v.x + sin(b.t * 3.0 + b.rot) * 70.0, v.y) * delta
			else:
				v *= drag
				var fall := 1700.0
				match String(b.kind):
					"confetti", "heart":
						fall = 700.0
					"mote":
						fall = -120.0
					"note":
						fall = -420.0
						v.x += sin(b.t * 6.0 + b.rot) * 260.0 * delta
				v.y += fall * delta
				b.pos += v * delta
			b.vel = v
			b.rot += float(b.spin) * delta
		bits = bits.filter(func(b: Dictionary) -> bool: return b.t < b.life)
	for st: Dictionary in stickers:
		st.t += delta
	stickers = stickers.filter(func(st: Dictionary) -> bool: return st.t < st.life)
	if _rain > 0.0:
		_rain -= delta
		if not Motion.reduce and randf() < delta * 34.0 and bits.size() < MAX_BITS:
			bits.append({"pos": Vector2(randf_range(0.0, size.x), -40.0), "vel": Vector2(randf_range(-60.0, 60.0), randf_range(160.0, 300.0)),
				"rot": randf() * TAU, "spin": randf_range(-4.0, 4.0), "t": 0.0, "life": 4.2,
				"kind": _rain_kinds[randi() % _rain_kinds.size()], "col": _rain_cols[randi() % _rain_cols.size()],
				"size": randf_range(1.0, 1.5), "float": true})
	queue_redraw()

func busy() -> bool:
	return not bits.is_empty() or not stickers.is_empty() or _rain > 0.0

# --- drawing ---

func _draw() -> void:
	_rays.queue_redraw()
	_draw_bits()
	_draw_stickers()

func _draw_rays() -> void:
	var b := Face.Builder.new()
	for st: Dictionary in stickers:
		if not st.rays:
			continue
		var grow := Motion.back_out(clampf(st.t / 0.35, 0.0, 1.0))
		var a := 1.0 - clampf((st.t - (st.life - 0.35)) / 0.35, 0.0, 1.0)
		var w := _font.get_string_size(st.text, HORIZONTAL_ALIGNMENT_LEFT, -1, st.size).x
		var r := maxf(w * 0.62, float(st.size) * 1.5) * grow
		var c := _sticker_at(st)
		var c0: Color = _ray_cols[0]
		var c1: Color = _ray_cols[1]
		var c2: Color = _ray_cols[2]
		b.disc(c, r * 0.6, Color(c0, c0.a * a))
		sunrays(b, c, r * 0.2, r, 16, _clock * 0.8, Color(c1, c1.a * a))
		sunrays(b, c, r * 0.2, r * 0.8, 16, -_clock * 0.5 + 0.1, Color(c2, c2.a * a))
	if not b.verts.is_empty():
		_ray_mesh = b.mesh()
		_rays.draw_mesh(_ray_mesh, null)

func _sticker_at(st: Dictionary) -> Vector2:
	return (st.at as Vector2) + Vector2(0, -float(st.rise) * minf(1.0, st.t / maxf(0.01, st.life)))

## Every bit in the air: a mesh a kind of copies of its look, and the rings
## (whose width changes) made on the frame.
func _draw_bits() -> void:
	if bits.is_empty():
		return
	if _kit == null:
		_kit = RunMesh.new(_bit_shape)
		for k in KINDS.size():
			_tiled.append([PackedInt32Array(), 0])
	# each kind's copies this frame, as [transform, paint] pairs
	var copies: Array = []
	for k in KINDS.size():
		copies.append([])
	var rings: Face.Builder = null
	for bit: Dictionary in bits:
		if bit.t < 0.0:
			continue
		var life: float = bit.life
		var a := clampf((life - bit.t) / (life * 0.35), 0.0, 1.0)
		if bit.has("to"):
			a = 1.0
		var col: Color = bit.col
		var fade := col.a * roundf(a * FADE_STEPS) / FADE_STEPS
		var p: Vector2 = bit.pos
		var sz: float = bit.size
		var rot: float = bit.rot
		var k := -1
		var xf: Transform2D
		var paint: Array
		match String(bit.kind):
			"confetti":
				k = 0
				xf = Transform2D(rot, Vector2(sz, (6.0 * sz * absf(cos(bit.t * 5.0 + rot)) + 1.0) / 11.0), 0.0, p)
				paint = [Color(col, fade)]
			"star":
				k = 1
				var s := sz * (0.6 + 0.4 * a)
				xf = Transform2D(rot, Vector2(s, s), 0.0, p)
				paint = [Color(col.darkened(0.35), fade), Color(col, fade), Color(1, 1, 1, 0.5 * fade)]
			"spark":
				if 22.0 * sz * a <= 0.5:
					continue
				k = 2
				xf = Transform2D(rot, Vector2(sz * a, sz * a), 0.0, p)
				paint = [Color(col, fade * 0.26), Color(col, fade), Color(1, 1, 1, fade)]
			"coin":
				k = 3
				var w := absf(cos(bit.t * 9.0 + rot))
				var ca := roundf(a * FADE_STEPS) / FADE_STEPS
				xf = Transform2D(0.0, Vector2(sz * maxf(0.18, w), sz), 0.0, p)
				paint = [Color(GOLD_DEEP, ca), Color(GOLD, ca), Color(1, 1, 0.9, 0.7 * ca if w > 0.4 else 0.0)]
			"heart":
				k = 4
				xf = Transform2D(sin(rot) * 0.4, Vector2(sz, sz), 0.0, p)
				paint = [Color(col, fade), Color(1, 1, 1, 0.45 * fade)]
			"clod":
				k = 5
				xf = Transform2D(0.0, Vector2(sz, sz), 0.0, p)
				paint = [Color(col, fade), Color(col.lightened(0.3), fade)]
			"shard":
				k = 6
				xf = Transform2D(rot, Vector2(sz, sz), 0.0, p)
				paint = [Color(col, fade), Color(col.lightened(0.3), fade)]
			"note":
				k = 7
				xf = Transform2D(sin(bit.t * 5.0 + rot) * 0.3, Vector2(sz, sz), 0.0, p)
				paint = [Color(col, fade), Color(col.darkened(0.45), fade), Color(1, 1, 1, 0.55 * fade)]
			"mote":
				(copies[8] as Array).append([Transform2D(0.0, Vector2(sz * a, sz * a), 0.0, p), [Color(col, fade * 0.25)]])
				k = 9
				xf = Transform2D(0.0, Vector2(sz, sz), 0.0, p)
				paint = [Color(col, fade)]
			"ring":
				if rings == null:
					rings = Face.Builder.new()
				var rk := clampf(bit.t / life, 0.0, 1.0)
				var r := sz * (0.3 + 0.7 * (1.0 - pow(1.0 - rk, 3.0)))
				rings.stroke(Face.Builder.ring(p, r, r), maxf(2.0, 14.0 * (1.0 - rk)), Color(bit.col, (bit.col as Color).a * (1.0 - rk)), true)
		if k < 0:
			continue
		(copies[k] as Array).append([xf, paint])
	_meshes.clear()
	for k in KINDS.size():
		var of: Array = copies[k]
		if of.is_empty():
			continue
		var look: PackedVector2Array = _kit.shape(k)[0]
		var v := PackedVector2Array()
		var c := PackedColorArray()
		for copy: Array in of:
			v.append_array((copy[0] as Transform2D) * look)
			c.append_array(_kit.ink(k, copy[1]))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_INDEX] = _tiled_for(k, of.size())
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes.append(m)
		draw_mesh(m, null)
	if rings != null:
		_mesh = rings.mesh()
		draw_mesh(_mesh, null)

## Kind `k`'s indices tiled for `n` copies, grown a chunk at a time.
static func _tiled_for(k: int, n: int) -> PackedInt32Array:
	var s := _kit.shape(k)
	var idx: PackedInt32Array = s[1]
	var per := idx.size()
	var have: Array = _tiled[k]
	if n > int(have[1]):
		var count := (s[0] as PackedVector2Array).size()
		var from := int(have[1])
		var to := int(ceilf(float(n) / TILE_CHUNK)) * TILE_CHUNK
		var ix := PackedInt32Array()
		ix.resize((to - from) * per)
		for m in to - from:
			var base := (from + m) * count
			var w := m * per
			for j in per:
				ix[w + j] = idx[j] + base
		var all: PackedInt32Array = have[0]
		have[0] = null
		all.append_array(ix)
		have[0] = all
		have[1] = to
	var tiled: PackedInt32Array = have[0]
	return tiled.slice(0, n * per)

## Kind `id`'s look at size 1, about its own place, in slot colours.
static func _bit_shape(id: int) -> Face.Builder:
	var b := Face.Builder.new()
	var o := Vector2.ZERO
	match id:
		0:
			petal(b, o, 11.0, 11.0, 0.0, RunMesh.slot(0))
		1:
			_star(b, o, 14.0, 0.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
		2:
			_glint(b, o, 22.0, 0.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
		3:
			_coin(b, o, 13.0, 1.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2), true)
		4:
			_heart(b, o, 13.0, 0.0, RunMesh.slot(0), RunMesh.slot(1))
		5:
			b.ellipse(o, 7.0, 5.5, RunMesh.slot(0))
			b.ellipse(Vector2(-1.5, -1.8), 3.0, 2.0, RunMesh.slot(1))
		6:
			var d := Vector2.RIGHT
			var n := d.orthogonal()
			b.polygon(PackedVector2Array([-d * 10.0, n * 5.0, d * 9.0, -n * 4.0]), RunMesh.slot(0))
			b.stroke(PackedVector2Array([-d * 10.0, n * 5.0]), 2.0, RunMesh.slot(1), false, false)
		7:
			_music_note(b, o, 16.0, 0.0, RunMesh.slot(0), RunMesh.slot(1), RunMesh.slot(2))
		8:
			b.disc(o, 9.0, RunMesh.slot(0))
		9:
			b.disc(o, 3.4, RunMesh.slot(0))
	return b

## Each letter hops in on its own, rocks for a moment, and the word swells
## away at the end; a pale rim and a dark one under the colour, so it reads
## over anything. Lettered a pass at a time -- every letter's shadow, then
## every pale rim, every dark one, every face -- and not a letter at a time:
## each pass's glyphs live in one atlas, so the renderer draws a pass in one
## call where a letter's four passes were four (Trestle's win, five stickers
## up at once, was 300 draw calls of lettering).
func _draw_stickers() -> void:
	for st: Dictionary in stickers:
		var text: String = st.text
		var fs: int = st.size
		var total := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var x := -total * 0.5
		var out_a := 1.0 - clampf((st.t - (st.life - 0.3)) / 0.3, 0.0, 1.0)
		var swell := 1.0 + 0.2 * (1.0 - out_a)
		var tilt: float = st.tilt
		var base := _sticker_at(st)
		# each letter on show: [its place, its turn, its swell, where its glyph
		# is drawn from, the letter, its colour]
		var letters: Array = []
		for i in text.length():
			var ch := text[i]
			var adv := _font.get_char_size(ch.unicode_at(0), fs).x
			var k := clampf((st.t - i * 0.035) / 0.28, 0.0, 1.0)
			if k <= 0.0 and not Motion.reduce:
				x += adv
				continue
			var sc := 1.0 if Motion.reduce else Motion.back_out(k)
			var hop := 0.0 if Motion.reduce else -sin(st.t * 8.0 - i * 0.55) * fs * 0.09 * exp(-st.t * 1.4)
			var centre: Vector2 = base + (Vector2(x + adv * 0.5, hop) * swell).rotated(tilt)
			var rock := 0.0 if Motion.reduce else sin(st.t * 7.0 + i) * 0.08 * exp(-st.t * 1.2)
			var col: Color = sticker_cols[i % sticker_cols.size()] if st.rainbow else st.col
			letters.append([centre, tilt + rock, Vector2(sc, sc) * swell, Vector2(-adv * 0.5, fs * 0.36), ch, col])
			x += adv
		for pass_ in 4:
			for l: Array in letters:
				draw_set_transform(l[0], l[1], l[2])
				var o: Vector2 = l[3]
				var col: Color = l[5]
				match pass_:
					0:
						draw_char_outline(_font, o + Vector2(0, fs * 0.09), l[4], fs, int(fs * 0.34), Color(0.25, 0.15, 0.05, 0.35 * out_a))
					1:
						draw_char_outline(_font, o, l[4], fs, int(fs * 0.3), Color(Color("fffaf0"), out_a))
					2:
						draw_char_outline(_font, o, l[4], fs, int(fs * 0.13), Color(col.darkened(0.5), out_a))
					3:
						draw_char(_font, o, l[4], fs, Color(col, out_a))
	draw_set_transform(Vector2.ZERO)
	_warm_one()

## One glyph of the warm list (a letter's rim, rim, edge or face), drawn
## as a sticker draws it, out of sight: a glyph a frame keeps the cost of
## rasterising it, about a millisecond at 112 px on the M1, off any one frame.
func _warm_one() -> void:
	if _warm.is_empty() or size.x <= 0.0:
		return
	var w: Array = _warm[0]
	var text: String = w[0]
	var fs := _fit(text, int(w[1]))
	var i := int(w[2])
	var ch := text[i / 4]
	w[2] = i + 1
	if int(w[2]) >= text.length() * 4:
		_warm.pop_front()
	var o := Vector2(-fs * 4.0, -fs * 4.0)
	if i % 4 == 3:
		draw_char(_font, o, ch, fs, Color.WHITE)
	else:
		draw_char_outline(_font, o, ch, fs, int(fs * [0.34, 0.3, 0.13][i % 4]), Color.WHITE)
	queue_redraw()

# --- shapes, laid into a builder ---

## A four-pointed glint: a spark.
static func glint(b: Face.Builder, c: Vector2, r: float, turn: float, col := Color(1, 1, 0.95, 0.95)) -> void:
	if r <= 0.5:
		return
	_glint(b, c, r, turn, Color(col, col.a * 0.26), col, Color(1, 1, 1, col.a))

static func _glint(b: Face.Builder, c: Vector2, r: float, turn: float, halo: Color, col: Color, core: Color) -> void:
	b.disc(c, r * 0.45, halo)
	for k in 4:
		var d := Vector2.from_angle(TAU * k / 4.0 + turn)
		var side := d.orthogonal() * r * 0.13
		b.polygon(PackedVector2Array([c + side, c + d * r * (1.0 if k % 2 == 0 else 0.7), c - side]), col)
	b.disc(c, r * 0.14, core)

## A five-pointed star with a darker drop and a shine.
static func star(b: Face.Builder, c: Vector2, r: float, col: Color, turn := 0.0) -> void:
	_star(b, c, r, turn, Color(col.darkened(0.35), col.a), col, Color(1, 1, 1, 0.5 * col.a))

static func _star(b: Face.Builder, c: Vector2, r: float, turn: float, drop: Color, col: Color, shine: Color) -> void:
	for pass_ in 2:
		var pts := PackedVector2Array()
		var from := c + (Vector2(r * 0.04, r * 0.1) if pass_ == 0 else Vector2.ZERO)
		var rr := r * (1.08 if pass_ == 0 else 1.0)
		for i in 10:
			var a := TAU * i / 10.0 - PI * 0.5 + turn
			pts.append(from + Vector2.from_angle(a) * (rr if i % 2 == 0 else rr * 0.52))
		b.polygon(pts, drop if pass_ == 0 else col)
	b.ellipse(c + Vector2(-r * 0.18, -r * 0.2), r * 0.18, r * 0.11, shine)

## A sunburst: `n` rays between `r0` and `r1`.
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

## A gold coin spinning about its upright axis (`spin`), its face narrowing
## to its rim and back.
static func coin(b: Face.Builder, c: Vector2, r: float, spin: float, a := 1.0) -> void:
	var w := absf(cos(spin))
	_coin(b, c, r, w, Color(GOLD_DEEP, a), Color(GOLD, a), Color(1, 1, 0.9, 0.7 * a), w > 0.4)

static func _coin(b: Face.Builder, c: Vector2, r: float, w: float, rim: Color, face: Color, shine: Color, shining: bool) -> void:
	b.ellipse(c, maxf(r * 0.18, r * w), r, rim)
	b.ellipse(c + Vector2(-r * 0.06 * w, 0), maxf(r * 0.1, r * 0.82 * w), r * 0.82, face)
	if shining:
		b.ellipse(c + Vector2(-r * 0.3 * w, -r * 0.3), r * 0.16 * w, r * 0.26, shine)

## An eighth note, its head at `c`, tipped by `rot`: a music bit.
static func music_note(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color) -> void:
	_music_note(b, c, r, rot, col, Color(col.darkened(0.45), col.a), Color(1, 1, 1, 0.55 * col.a))

static func _music_note(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color, dark: Color, shine: Color) -> void:
	var t := Transform2D(rot, c)
	var head := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		head.append(t * Vector2(cos(a) * r * 0.62, sin(a) * r * 0.46).rotated(-0.4))
	b.polygon(head, col)
	var top := Vector2(r * 0.5, -r * 1.9)
	b.stroke(PackedVector2Array([t * Vector2(r * 0.5, -r * 0.1), t * top]), r * 0.2, dark)
	b.polygon(PackedVector2Array([t * top, t * (top + Vector2(r * 0.75, r * 0.55)), t * (top + Vector2(r * 0.6, r * 0.8)), t * (top + Vector2(0, r * 0.45))]), dark)
	b.ellipse(t * Vector2(-r * 0.2, -r * 0.14), r * 0.18, r * 0.1, shine)

## A heart tipped by `rot`.
static func heart(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color) -> void:
	_heart(b, c, r, rot, col, Color(1, 1, 1, 0.45 * col.a))

static func _heart(b: Face.Builder, c: Vector2, r: float, rot: float, col: Color, shine: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + (Vector2(x, y) * r / 16.0).rotated(rot))
	b.polygon(pts, col)
	b.ellipse(c + Vector2(-r * 0.4, -r * 0.35).rotated(rot), r * 0.2, r * 0.13, shine)

## A warm glow breathing in from the edges of `rect`, `amount` 0..1 strong.
static func edge_glow(b: Face.Builder, rect: Rect2, tint: Color, amount: float, beat: float) -> void:
	var s := rect.size
	var o := rect.position
	var edge := Color(tint, (0.25 + 0.2 * beat) * amount)
	var none := Color(tint, 0.0)
	var w := (70.0 + 40.0 * beat) * (0.6 + 0.4 * amount)
	_quad(b, [o, o + Vector2(s.x, 0), o + Vector2(s.x - w, w), o + Vector2(w, w)], [edge, edge, none, none])
	_quad(b, [o + Vector2(0, s.y), o + Vector2(w, s.y - w), o + Vector2(s.x - w, s.y - w), o + s], [edge, none, none, edge])
	_quad(b, [o, o + Vector2(w, w), o + Vector2(w, s.y - w), o + Vector2(0, s.y)], [edge, none, none, edge])
	_quad(b, [o + Vector2(s.x, 0), o + s, o + Vector2(s.x - w, s.y - w), o + Vector2(s.x - w, w)], [edge, edge, none, none])

static func _quad(b: Face.Builder, p: Array, c: Array) -> void:
	var i0 := b.vertex(p[0], c[0])
	var i1 := b.vertex(p[1], c[1])
	var i2 := b.vertex(p[2], c[2])
	var i3 := b.vertex(p[3], c[3])
	b.tri(i0, i1, i2)
	b.tri(i0, i2, i3)
