extends Control

## The opening: what is on the screen from the game's first frame until the
## first screen is ready under it (world/boot.gd), in place of the black the
## game used to open on. It is the app icon coming together: nine soft tiles
## drop onto the paper in a diagonal run, a sprout grows out of the middle
## one and unfurls its two leaves, and `Daily` is lettered under them with
## its golden sun for the dot of the i, the wordmark the first screen
## carries. Warm motes of light drift up through it while it waits (cozy
## light has no shape: a mote is a round falloff and nothing else). Then the
## leaves sway, a ripple runs over the tiles now and then, and it holds for
## as long as the first screen takes to load; told to `leave`, the tiles pop
## out in the run they came in, the lettering lifts off and the paper thins
## to the first screen rising under it.
##
## The ground is GROUND, the app icon's own cream: the colour the phone's
## launch screen, the window behind the engine and the engine's first clear
## are all set to (docs/agents/opening.md), so the first tile drops onto a
## screen that has been this colour since the icon was tapped.
##
## Everything is read off one clock (`clock`, in seconds since the first
## frame) through core/motion.gd's curve readers, and drawn from meshes built
## once: a harness sets `auto` false and calls `step`. A tap asks to be let
## through (`skip`); nothing here decides when to go. Under reduce motion it
## stands finished from the first frame and leaves in a short plain fade.

## A tap on the opening: the player has seen it and wants the game.
signal skip
## Gone: the paper has thinned to nothing and nothing here draws any more.
signal left

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const CozyTheme = preload("res://ui/theme.gd")
const SunDot = preload("res://ui/sun_dot.gd")
const GROUND_SHADER := preload("res://shaders/opening_ground_2d.gdshader")

## The app icon's ground (assets/icon/adaptive_background.png), six levels
## paler than the first screen's paper: too near to see in the fade.
const GROUND := Color("fcf5e9")
## The icon's nine tiles, row by row, and the cream one the sprout is in.
const GREEN := Color("a9c783")
const YELLOW := Color("fdd36c")
const BLUE := Color("95c6e8")
const CORAL := Color("fb8f7a")
const CREAM := Color("fbe8c9")
const TILES: Array[Color] = [GREEN, YELLOW, BLUE, CORAL, CREAM, GREEN, BLUE, YELLOW, CORAL]
const MIDDLE := 4
## What a tile's lit corner is mixed toward, and how far its far corner is
## taken down: the light is from the upper left, as on the icon.
const HILITE := Color("fffbe6")
const LIGHT := Vector2(-0.6, -0.8)
const SHADE := 0.24
const SHADOW := Color("b98455")
const DENT := Color("b08c5c")
const LEAF_HI := Color("cfe06a")
const LEAF_MID := Color("86bb42")
const LEAF_LO := Color("4f8f33")
const STEM_HI := Color("8dbd4a")
const STEM_MID := Color("679c3b")
const STEM_LO := Color("4b7b30")
const MOTE := Color("ffc978")
const MOTE_HEART := Color("ffbe4a")
const PEACH := Color("ffd2a0")

## The layout, in the 1080 by 1920 the game is drawn for. The block (the
## grid and the lettering under it) is centred on the screen; `LIFT` is how
## far the grid's own middle sits above that.
const TILE := 216.0
const GAP := 13.0
const RADIUS := 56.0
const BEVEL := 38.0
const CORNER_STEPS := 10
const SHADOW_OFF := Vector2(10.0, 18.0)
const LIFT := 150.0
const STEM := 108.0
const LEAF := 228.0
const LEAF_STEPS := 22
const REST_RIGHT := -0.44
const REST_LEFT := -2.36
const FONT := 216
const WORD := "Daıly"
const BASELINE := 590.0
const SOFT_R := 64.0
const SOFT_RINGS := 18
const SOFT_SIDES := 48

## The score, in seconds from the first frame. A tile is `TILE_STEP` behind
## the one before it along the diagonals; the sprout comes as the middle
## tile lands; the letters follow the leaves, the sun last. SETTLED is when
## the last of it has landed: the soonest the opening is taken off unasked.
const TILE_AT := 0.12
const TILE_STEP := 0.05
const TILE_TIME := 0.32
const TILE_DROP := 54.0
const SPROUT_AT := 0.66
const STEM_TIME := 0.34
const LEAF_RIGHT_AT := 0.84
const LEAF_LEFT_AT := 0.94
const LEAF_TIME := 0.44
const WORD_AT := 1.0
const LETTER_STEP := 0.05
const LETTER_TIME := 0.3
const LETTER_RISE := 34.0
const SUN_AT := 1.3
const SUN_TIME := 0.28
const GLOW_TIME := 0.7
const MOTES_AT := 0.5
const SETTLED := 1.7
## Under reduce motion nothing lands; it is only looked at this long.
const HELD := 0.8
## The wait: the leaves' sway, and a ripple over the tiles every so often.
const SWAY := 0.05
const SWAY_RATE := 1.9
const RIPPLE_EVERY := 2.6
const RIPPLE_STEP := 0.06
const RIPPLE_HOP := -9.0
const RIPPLE_TIME := 0.36
## Leaving: a tile pops out `LEAVE_STEP` after the one that came in after
## it, the paper thins from GROUND_FROM, and it is all gone at LEAVE_TIME.
const LEAVE_STEP := 0.022
const LEAVE_POP := 0.16
const LEAVE_WORD := 0.2
const GROUND_FROM := 0.16
const LEAVE_TIME := 0.5
## The most one frame moves the clock: the frame the first screen is built
## in is a long one, and the opening waits for it rather than jumping.
const MAX_STEP := 0.05
const MOTE_COUNT := 16

## Seconds since the first frame.
var clock := 0.0
## False on an opening something else steps (a harness, with `step`).
var auto := true

var _leave_at := INF
var _gone := false
var _tiles: Array[ArrayMesh] = []
var _ranks := PackedInt32Array()
var _shadow: ArrayMesh
var _stem: ArrayMesh
var _leaf: ArrayMesh
var _soft: ArrayMesh
var _mote: ArrayMesh
var _sun: ArrayMesh
var _motes: Array = []
var _ground: ColorRect
var _ground_mat: ShaderMaterial
var _font: Font
var _advances := PackedFloat32Array()
var _advances_for := 0

func _init() -> void:
	name = "Opening"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = CozyTheme.display(700)
	# The paper and the light on it, under everything this draws.
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = GROUND_SHADER
	_ground_mat.set_shader_parameter("ground", GROUND)
	_ground_mat.set_shader_parameter("heart", Color(1.0, 1.0, 1.0, 0.75))
	_ground_mat.set_shader_parameter("skirt", Color(PEACH, 0.22))
	_ground_mat.set_shader_parameter("lit", 0.0)
	_ground = ColorRect.new()
	_ground.name = "Ground"
	_ground.color = GROUND
	_ground.material = _ground_mat
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ground.show_behind_parent = true
	_ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_ground)
	for colour in TILES:
		_tiles.append(_tile_mesh(colour))
	# The run the tiles come in: along the diagonals from the upper left.
	var order: Array = range(9)
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := a / 3 + a % 3
		var db := b / 3 + b % 3
		return da < db or (da == db and a < b))
	_ranks.resize(9)
	for rank in 9:
		_ranks[order[rank]] = rank
	_shadow = _shadow_mesh()
	_stem = _stem_mesh()
	_leaf = _leaf_mesh()
	_sun = _sun_mesh()
	var soft := Face.Builder.new()
	_soften(soft, Vector2.ZERO, SOFT_R, Color.WHITE)
	_soft = soft.mesh()
	var mote := Face.Builder.new()
	_soften(mote, Vector2.ZERO, SOFT_R, Color(MOTE, 0.34))
	_soften(mote, Vector2.ZERO, SOFT_R * 0.36, Color(MOTE_HEART, 0.95))
	_mote = mote.mesh()
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for i in MOTE_COUNT:
		_motes.append({
			"x": rng.randf_range(-500.0, 500.0), "at": rng.randf(),
			"rate": rng.randf_range(0.035, 0.075), "amp": rng.randf_range(10.0, 30.0),
			"turn": rng.randf_range(0.5, 1.2), "seed": rng.randf_range(0.0, TAU),
			"r": rng.randf_range(20.0, 40.0), "front": i % 2 == 0,
		})

func _process(delta: float) -> void:
	if auto:
		step(minf(delta, MAX_STEP))

func _gui_input(event: InputEvent) -> void:
	# The project has mouse-from-touch off: a finger is a ScreenTouch.
	if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
		accept_event()
		skip.emit()

## Moves the clock on and draws; says `left` once the leaving is over.
func step(delta: float) -> void:
	clock += delta
	queue_redraw()
	if not _gone and clock - _leave_at >= (Motion.REDUCED_TIME if Motion.reduce else LEAVE_TIME):
		_gone = true
		left.emit()

## Starts the leaving, from wherever the opening has got to.
func leave() -> void:
	if _leave_at == INF:
		_leave_at = clock

func leaving() -> bool:
	return _leave_at != INF

## Whether the opening has played: the soonest it is taken off unasked.
func settled() -> bool:
	return clock >= (HELD if Motion.reduce else SETTLED)

# --- the drawing ---

func _draw() -> void:
	_ground.visible = not _gone
	if _gone:
		return
	var u := minf(size.x / 1080.0, size.y / 1920.0)
	var mid := Vector2(size.x * 0.5, size.y * 0.5 - LIFT * u)
	var away := clock - _leave_at
	# Under reduce motion the whole of it goes in one plain fade.
	var fade := 1.0 - clampf(away / Motion.REDUCED_TIME, 0.0, 1.0) if Motion.reduce else 1.0
	var ground := fade if Motion.reduce else 1.0 - smoothstep(GROUND_FROM, LEAVE_TIME, away)
	# The paper, and the light on it behind the grid: a pale heart and a
	# warm skirt (shaders/opening_ground_2d.gdshader).
	_ground_mat.set_shader_parameter("size", size)
	_ground_mat.set_shader_parameter("heart_at", mid)
	_ground_mat.set_shader_parameter("heart_reach", 680.0 * u)
	_ground_mat.set_shader_parameter("skirt_at", mid + Vector2(0.0, 170.0) * u)
	_ground_mat.set_shader_parameter("skirt_reach", 1040.0 * u)
	_ground_mat.set_shader_parameter("lit", _eased(0.0, GLOW_TIME))
	_ground_mat.set_shader_parameter("level", ground)
	var t := 0.0 if Motion.reduce else clock
	_draw_motes(mid, u, t, false, ground)

	var pitch := (TILE + GAP) * u
	var places := PackedVector2Array()
	var scales := PackedVector2Array()
	var levels := PackedFloat32Array()
	for i in 9:
		var e := clock - (TILE_AT + _ranks[i] * TILE_STEP)
		var out := _pop_out(away - (8 - _ranks[i]) * LEAVE_STEP)
		var s := Motion.pop_in_scale(e, TILE_TIME) * out
		if i == MIDDLE:
			s *= Motion.bump_scale(clock - SPROUT_AT, 0.07)
		var drop := Motion.drop_in_lift(e, TILE_DROP, TILE_TIME)
		var hop := Motion.hop_lift(_ripple() - _ranks[i] * RIPPLE_STEP, RIPPLE_HOP, RIPPLE_TIME)
		var at := mid + Vector2((i % 3 - 1) * pitch, (i / 3 - 1) * pitch)
		var level := Motion.appear_level(e) * fade * out
		if level > 0.0:
			# The shadow stays on the paper: it thins and spreads under a
			# tile still in the air.
			var high := (drop - hop) / TILE_DROP
			draw_mesh(_shadow, null, Transform2D(0.0, s * u * (1.0 + 0.1 * high), 0.0, at + SHADOW_OFF * u),
				Color(SHADOW, 0.32 * level * (1.0 - 0.6 * clampf(high, 0.0, 1.0))))
		places.append(at + Vector2(0.0, hop - drop) * u)
		scales.append(s * u)
		levels.append(level)
	for i in 9:
		if levels[i] > 0.0:
			draw_mesh(_tiles[i], null, Transform2D(0.0, scales[i], 0.0, places[i]), Color(1.0, 1.0, 1.0, levels[i]))

	_draw_sprout(places[MIDDLE], scales[MIDDLE], levels[MIDDLE], t)
	_draw_motes(mid, u, t, true, ground)
	_draw_word(mid, u, fade, away)

## The sprout, out of the middle tile at `at`: the hollow it stands in, the
## stem, and a leaf to either side of its tip. It grows straight up and the
## leaves fall open from there; each is one mesh under a transform.
func _draw_sprout(at: Vector2, sc: Vector2, level: float, t: float) -> void:
	var stem := _eased(SPROUT_AT, STEM_TIME, true)
	if stem <= 0.0 or level <= 0.0:
		return
	var tint := Color(1.0, 1.0, 1.0, level)
	var root := at + Vector2(0.0, 30.0) * sc
	draw_mesh(_soft, null, Transform2D(0.0, Vector2(58.0, 24.0) / SOFT_R * sc, 0.0, root + Vector2(0.0, 2.0) * sc),
		Color(DENT, 0.5 * level * minf(stem * 2.0, 1.0)))
	var lean := sin(t * SWAY_RATE) * SWAY * 0.4
	var grown := Transform2D(lean, Vector2(minf(stem * 1.6, 1.0), stem) * sc, 0.0, root)
	draw_mesh(_stem, null, grown, tint)
	var tip := grown * Vector2(3.0, -STEM + 6.0)
	for side in 2:
		var right := side == 1
		var open := _eased(LEAF_RIGHT_AT if right else LEAF_LEFT_AT, LEAF_TIME, true)
		if open <= 0.0:
			continue
		var rest := REST_RIGHT if right else REST_LEFT
		var sway := sin(t * SWAY_RATE + (0.0 if right else 0.9)) * SWAY * (1.0 if right else -1.0)
		var angle := lerpf(-PI * 0.5, rest, open) + sway + lean
		# The left leaf is the right one turned over, so both are lit from
		# above.
		var size_now := sc * open * (1.0 if right else 0.94)
		draw_mesh(_leaf, null, Transform2D(angle, Vector2(size_now.x, size_now.y if right else -size_now.y), 0.0, tip), tint)

## `Daily`, a letter at a time, each rising into its place, and the sun over
## the i. Leaving, the word lifts off whole.
func _draw_word(mid: Vector2, u: float, fade: float, away: float) -> void:
	var px := maxi(int(FONT * u), 8)
	if px != _advances_for:
		_advances_for = px
		_advances.resize(WORD.length() + 1)
		for i in WORD.length() + 1:
			_advances[i] = _font.get_string_size(WORD.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var width := _advances[WORD.length()]
	var gone := 0.0 if Motion.reduce else smoothstep(0.0, LEAVE_WORD, away)
	var base := Vector2(mid.x - width * 0.5, mid.y + BASELINE * u - 18.0 * u * gone)
	for i in WORD.length():
		var e := clock - (WORD_AT + i * LETTER_STEP)
		var level := Motion.appear_level(e, 0.14) * fade * (1.0 - gone)
		if level <= 0.0:
			continue
		var rise := Motion.drop_in_lift(e, LETTER_RISE, LETTER_TIME) * u
		draw_string(_font, base + Vector2(_advances[i], rise), WORD[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(Pal.TEXT, level))
	var dot := WORD.find(SunDot.DOTLESS)
	var sun := Motion.pop_in_scale(clock - SUN_AT, SUN_TIME)
	if dot < 0 or sun.x <= 0.0:
		return
	var seat := base + Vector2((_advances[dot] + _advances[dot + 1]) * 0.5, -px * (SunDot.DOT_CENTRE_EM + SunDot.RAY_LIFT_EM))
	# It turns into its seat, then keeps the first screen's slow turn.
	var spin := (1.0 - _eased(SUN_AT, SUN_TIME * 1.6)) * -PI * 0.5
	if not Motion.reduce:
		spin += maxf(clock - SUN_AT, 0.0) * TAU / 40.0
	draw_mesh(_sun, null, Transform2D(spin, sun * (px / float(FONT)), 0.0, seat), Color(1.0, 1.0, 1.0, fade * (1.0 - gone)))

## The motes behind the tiles (`front` false) or over them: each rises
## through the block, swaying, and is brightest in the middle of its way.
func _draw_motes(mid: Vector2, u: float, t: float, front: bool, ground: float) -> void:
	var shown := _eased(MOTES_AT, 0.6) * ground
	if shown <= 0.0:
		return
	for m: Dictionary in _motes:
		if m.front != front:
			continue
		var along := fposmod(m.at + m.rate * t, 1.0)
		var at := mid + Vector2(m.x + sin(t * m.turn + m.seed) * m.amp, lerpf(700.0, -520.0, along)) * u
		var level := pow(sin(along * PI), 0.8) * (0.72 + 0.28 * sin(t * m.turn * 1.7 + m.seed)) * shown
		draw_mesh(_mote, null, Transform2D(0.0, Vector2.ONE * (m.r / SOFT_R * u), 0.0, at), Color(1.0, 1.0, 1.0, level))

# --- the clock's readers ---

## 0 to 1 over `time` from `at`, eased out; with `spring`, on the back ease,
## which overshoots. One under reduce motion.
func _eased(at: float, time: float, spring := false) -> float:
	if Motion.reduce:
		return 1.0
	var p := clampf((clock - at) / time, 0.0, 1.0)
	return Motion.back_out(p) if spring else 1.0 - pow(1.0 - p, 3.0)

## A leaving thing's scale, `e` seconds into its own leaving: one before
## it, and one all through under reduce motion, where the fade takes it.
func _pop_out(e: float) -> float:
	if Motion.reduce or e <= 0.0:
		return 1.0
	return Motion.pop_out_scale(e, LEAVE_POP)

## Seconds into the ripple now running over the tiles; below zero before
## the first, and once leaving.
func _ripple() -> float:
	var since := clock - SETTLED - 0.5
	if since < 0.0 or leaving():
		return -1.0
	return fmod(since, RIPPLE_EVERY)

# --- the meshes ---

## A square of half side `h` with corners of `r`, CORNER_STEPS + 1 points a
## corner, clockwise from the top right: the same count whatever the size,
## so two of them join point to point.
static func _round_square(h: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c := h - r
	var corners := [Vector2(c, -c), Vector2(c, c), Vector2(-c, c), Vector2(-c, -c)]
	for k in 4:
		for i in CORNER_STEPS + 1:
			pts.append(corners[k] + Vector2.from_angle(-PI * 0.5 + (k + float(i) / CORNER_STEPS) * PI * 0.5) * r)
	return pts

## Joins two outlines of one count, already in `b`, in a band.
static func _band(b: Face.Builder, a: int, o: int, n: int) -> void:
	for i in n:
		var j := (i + 1) % n
		b.tri(a + i, o + i, o + j)
		b.tri(a + i, o + j, a + j)

## A light with no edge, into `b`: `colour` at `c`, thinning to nothing at
## `r` along a curve level at both ends (ui/motes.gd's glow, in more rings:
## these are drawn large).
static func _soften(b: Face.Builder, c: Vector2, r: float, colour: Color) -> void:
	var heart := b.vertex(c, colour)
	var first := b.verts.size()
	for ring in SOFT_RINGS:
		var t := float(ring + 1) / SOFT_RINGS
		var tint := Color(colour, colour.a * pow(cos(t * PI * 0.5), 2.0))
		for k in SOFT_SIDES:
			b.vertex(c + Vector2.from_angle(TAU * k / SOFT_SIDES) * r * t, tint)
	for k in SOFT_SIDES:
		b.tri(heart, first + k, first + (k + 1) % SOFT_SIDES)
	for ring in SOFT_RINGS - 1:
		_band(b, first + ring * SOFT_SIDES, first + (ring + 1) * SOFT_SIDES, SOFT_SIDES)

## A tile, centred: a soft pillow, its rim lit toward the upper left and
## shaded toward the lower right, the face inside it nearly flat.
static func _tile_mesh(base: Color) -> ArrayMesh:
	var b := Face.Builder.new()
	var h := TILE * 0.5
	var hi := base.lerp(HILITE, 0.62)
	# Shade keeps the tile's own hue and deepens it, as paint does; a grey
	# mixed in made the yellow olive.
	var lo := Color.from_hsv(base.h, minf(base.s * 1.3 + 0.04, 1.0), base.v * (1.0 - SHADE))
	var rings := [
		[_round_square(h + Face.FEATHER, RADIUS + Face.FEATHER), 1.0, 0.0],
		[_round_square(h, RADIUS), 1.0, 1.0],
		[_round_square(h - BEVEL * 0.45, RADIUS - BEVEL * 0.3), 0.5, 1.0],
		[_round_square(h - BEVEL, RADIUS - BEVEL * 0.62), 0.14, 1.0],
	]
	var n: int = rings[0][0].size()
	var first := b.verts.size()
	for ring in rings:
		for p: Vector2 in ring[0]:
			var light := clampf((p / h).dot(LIGHT), -1.0, 1.0) * float(ring[1])
			var colour := base.lerp(hi, light) if light > 0.0 else base.lerp(lo, -light)
			b.vertex(p, Color(colour, ring[2]))
	for k in rings.size() - 1:
		_band(b, first + k * n, first + (k + 1) * n, n)
	var heart := b.vertex(Vector2.ZERO, base.lerp(hi, 0.06))
	var inner := first + (rings.size() - 1) * n
	for i in n:
		b.tri(heart, inner + i, inner + (i + 1) % n)
	# The sheen where the light lands, with no edge of its own.
	_soften(b, Vector2(-0.36, -0.4) * h, 0.5 * h, Color(HILITE, 0.34))
	return b.mesh()

## A tile's shadow on the paper, centred, in white for the draw to tint:
## whole under the tile and thinning to nothing well outside it.
static func _shadow_mesh() -> ArrayMesh:
	var b := Face.Builder.new()
	var h := TILE * 0.5
	var rings := [[-18.0, 1.0], [0.0, 0.62], [16.0, 0.24], [36.0, 0.0]]
	var n := 0
	var first := b.verts.size()
	for ring in rings:
		var pts := _round_square(h + ring[0], RADIUS + ring[0] * 0.8)
		n = pts.size()
		for p in pts:
			b.vertex(p, Color(1.0, 1.0, 1.0, ring[1]))
	for k in rings.size() - 1:
		_band(b, first + k * n, first + (k + 1) * n, n)
	var heart := b.vertex(Vector2.ZERO, Color.WHITE)
	for i in n:
		b.tri(heart, first + i, first + (i + 1) % n)
	return b.mesh()

## Rows of points along a shape, each row one colour, joined row to row:
## how the stem and the leaf carry a wash across them. The first and last
## rows are the feather, clear.
static func _ribbon(b: Face.Builder, rows: Array, colours: Array) -> void:
	var n: int = rows[0].size()
	var first := b.verts.size()
	for k in rows.size():
		for p: Vector2 in rows[k]:
			b.vertex(p, colours[k])
	for k in rows.size() - 1:
		for i in n - 1:
			var a := first + k * n + i
			var o := a + n
			b.tri(a, o, o + 1)
			b.tri(a, o + 1, a + 1)

## The stem, its foot at the origin and its tip STEM above it: a little
## bent, thinner toward the tip, lit on its left.
static func _stem_mesh() -> ArrayMesh:
	var b := Face.Builder.new()
	var line := Face.Builder.bezier3(Vector2.ZERO, Vector2(-5.0, -36.0), Vector2(9.0, -66.0), Vector2(3.0, -STEM), 16)
	line.append(Vector2(3.0, -STEM))
	var rows: Array = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	for i in line.size():
		var dir := (line[mini(i + 1, line.size() - 1)] - line[maxi(i - 1, 0)]).normalized()
		var side := Vector2(dir.y, -dir.x)
		var half := lerpf(16.0, 12.0, float(i) / (line.size() - 1))
		var across := [-half - Face.FEATHER, -half, 0.0, half, half + Face.FEATHER]
		for k in 5:
			rows[k].append(line[i] + side * across[k])
	_ribbon(b, rows, [Color(STEM_HI, 0.0), STEM_HI, STEM_MID, STEM_LO, Color(STEM_LO, 0.0)])
	return b.mesh()

## A leaf, its foot at the origin and its tip LEAF along x: a full curve
## above, a shallower one below, washed from a lit upper edge to a deep
## lower one, with a pale vein.
static func _leaf_mesh() -> ArrayMesh:
	var b := Face.Builder.new()
	var tip := Vector2(1.0, -0.06) * LEAF
	var upper := Face.Builder.bezier3(Vector2.ZERO, Vector2(0.16, -0.4) * LEAF, Vector2(0.74, -0.46) * LEAF, tip, LEAF_STEPS)
	var lower := Face.Builder.bezier3(Vector2.ZERO, Vector2(0.26, 0.3) * LEAF, Vector2(0.82, 0.3) * LEAF, tip, LEAF_STEPS)
	upper.append(tip)
	lower.append(tip)
	var rows: Array = [PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array(), PackedVector2Array()]
	var vein := PackedVector2Array()
	for i in upper.size():
		var mid := upper[i].lerp(lower[i], 0.56)
		# Outward of either edge; at the foot and the tip, where the two
		# edges meet, both feather along the leaf.
		var ends := i == 0 or i == upper.size() - 1
		var up := Vector2(-1.0 if i == 0 else 1.0, 0.0) if ends else (upper[i] - lower[i]).normalized()
		var down := up if ends else -up
		rows[0].append(upper[i] + up * Face.FEATHER)
		rows[1].append(upper[i])
		rows[2].append(upper[i].lerp(mid, 0.55))
		rows[3].append(mid)
		rows[4].append(lower[i])
		rows[5].append(lower[i] + down * Face.FEATHER)
		if i >= 2 and i <= upper.size() - 4:
			vein.append(mid)
	_ribbon(b, rows, [Color(LEAF_HI, 0.0), LEAF_HI, LEAF_HI.lerp(LEAF_MID, 0.6), LEAF_MID, LEAF_LO, Color(LEAF_LO, 0.0)])
	b.stroke(vein, 4.0, Color(LEAF_HI, 0.42))
	return b.mesh()

## The i's sun at FONT: ui/sun_dot.gd's own, a disc and eight capsule rays.
static func _sun_mesh() -> ArrayMesh:
	var b := Face.Builder.new()
	var r := FONT * SunDot.DOT_RADIUS_EM
	var half := SunDot.RAY_WIDTH * 0.5 * r
	for i in 8:
		var dir := Vector2.from_angle(-PI * 0.5 + PI * 0.125 + i * PI * 0.25)
		b.stroke(PackedVector2Array([dir * (SunDot.RAY_FROM * r + half), dir * (SunDot.RAY_TO * r - half)]), SunDot.RAY_WIDTH * r, Pal.SUN_RAY)
	b.disc(Vector2.ZERO, r, Pal.SUN)
	return b.mesh()
