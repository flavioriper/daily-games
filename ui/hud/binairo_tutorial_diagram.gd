extends Control

## One page of Binairo's tutorial: a few real-looking tiles, the board's own
## SunFace and MoonFace, and one move played on a loop with the board's
## motion recipes, over a caption that says what the move means. `lesson`
## picks the page (set before it enters the tree):
##
## - TAP: a tile cycles under the finger, empty to sun to moon to empty.
## - THREE: two moons in a line force a sun into the gap.
## - HALF: a line of six holding three suns already ends on a moon.
## - SIGNS: = makes its pair the same, x makes it opposite.
## - HEART: a wrong tile cracks, shivers and drops out, and costs a heart.
##
## Performance checkup, 2026-10-01: the one-lesson card became five pages.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

enum Lesson { TAP, THREE, HALF, SIGNS, HEART }

const GAP := 12.0
const TILE_EDGE := 4
const TILE_RADIUS := 18
const TILE_MAX := 140.0
const SUN_SIZE := 0.26 * 2.0 * 1.55
const MOON_SIZE := 0.34 * 2.0
const SIGN_R := 0.16
const HEART_R := 22.0
## -2 is no tile at all (the gap between SIGNS' two pairs), -1 an empty one.
const NONE := -2

var lesson: int = Lesson.THREE

var _values: Array = []
## [cell, answer] the loop fills in turn.
var _targets: Array = []
## [cell a, cell b, kind]: kind 1 is "=", 0 is "x".
var _signs: Array = []
var _rows := 1
var _cols := 1
var _tiles: Dictionary = {}     # Vector2i -> Panel
var _styles: Dictionary = {}    # Vector2i -> StyleBoxFlat
var _glows: Dictionary = {}     # Vector2i -> Panel
var _faces: Dictionary = {}     # Vector2i -> Control (the lesson's own come and go)
var _over: Control
var _caption: Label
var _loop: Tween
var _tile := 0.0
var _origin := Vector2.ZERO
var _hearts_full := 1.0
var _over_shown: ArrayMesh

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_setup()
	_build()
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start")

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _tile > 0.0 and _loop == null:
		call_deferred("_start")

func _setup() -> void:
	match lesson:
		Lesson.TAP:
			_values = [[0, -1, 1, -1]]
			_targets = [[Vector2i(1, 0), 0]]
		Lesson.THREE:
			# The second row is the lesson; the rest make it read as a board.
			_values = [
				[0, -1, 1, -1],
				[1, 1, -1, 0],
				[-1, 0, -1, 1],
				[1, -1, 0, -1],
			]
			_targets = [[Vector2i(2, 1), 0]]
		Lesson.HALF:
			_values = [[0, 1, 0, 1, 0, -1]]
			_targets = [[Vector2i(5, 0), 1]]
		Lesson.SIGNS:
			_values = [[0, -1, NONE, 1, -1]]
			_targets = [[Vector2i(1, 0), 0], [Vector2i(4, 0), 0]]
			_signs = [[Vector2i(0, 0), Vector2i(1, 0), 1], [Vector2i(3, 0), Vector2i(4, 0), 0]]
		Lesson.HEART:
			_values = [[1, 1, -1, 0]]
			_targets = [[Vector2i(2, 0), 1]]
	_rows = _values.size()
	_cols = (_values[0] as Array).size()

func _build() -> void:
	for r in _rows:
		for c in _cols:
			var v: int = _values[r][c]
			if v == NONE:
				continue
			var cell := Vector2i(c, r)
			var tile := Panel.new()
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := _tile_style(v >= 0)
			tile.add_theme_stylebox_override("panel", sb)
			tile.material = null
			add_child(tile)
			_tiles[cell] = tile
			_styles[cell] = sb
			if _is_target(cell):
				var glow := Panel.new()
				glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				glow.add_theme_stylebox_override("panel", _glow_style())
				glow.material = null
				tile.add_child(glow)
				_glows[cell] = glow
			if v >= 0:
				_set_face(cell, v, false)
	# Signs and hearts over the tiles.
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over.draw.connect(_draw_over)
	add_child(_over)
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall and
	# its centred text sinks under the buttons.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_caption.text = _caption_for(0)

func _is_target(cell: Vector2i) -> bool:
	for t in _targets:
		if t[0] == cell:
			return true
	return false

func _layout() -> void:
	if _tiles.is_empty():
		return
	var top := HEART_R * 2.0 + 24.0 if lesson == Lesson.HEART else 0.0
	var room := Vector2(size.x - 120.0, size.y - 96.0 - top)
	_tile = minf(TILE_MAX, minf((room.x - GAP * (_cols - 1)) / _cols, (room.y - GAP * (_rows - 1)) / _rows))
	var board := Vector2(_cols, _rows) * (_tile + GAP) - Vector2(GAP, GAP)
	_origin = Vector2((size.x - board.x) * 0.5, top + (room.y - board.y) * 0.5)
	for cell: Vector2i in _tiles:
		var tile: Panel = _tiles[cell]
		tile.position = _origin + Vector2(cell) * (_tile + GAP)
		tile.size = Vector2(_tile, _tile)
		tile.pivot_offset = tile.size * 0.5
		if _glows.has(cell):
			_glows[cell].position = Vector2.ZERO
			_glows[cell].size = Vector2(_tile, _tile - TILE_EDGE)
		if _faces.has(cell):
			_fit_face(_faces[cell])
	_over.position = Vector2.ZERO
	_over.size = size
	_over.queue_redraw()
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)

func _fit_face(face: Control) -> void:
	var extent := _tile * (SUN_SIZE if face is SunFace else MOON_SIZE)
	face.size = Vector2(extent, extent)
	face.pivot_offset = face.size * 0.5
	face.position = (Vector2(_tile, _tile - TILE_EDGE) - face.size) * 0.5

## Puts `v` (0 sun, 1 moon, -1 none) on `cell`, popping it in when `pop`.
func _set_face(cell: Vector2i, v: int, pop: bool) -> void:
	var old: Control = _faces.get(cell)
	if old != null:
		old.queue_free()
		_faces.erase(cell)
	if v < 0:
		return
	var face: Control = SunFace.new() if v == 0 else MoonFace.new()
	face.expression = Face.Expr.HAPPY
	_tiles[cell].add_child(face)
	_faces[cell] = face
	if _tile > 0.0:
		_fit_face(face)
	face.set_idle(true)
	if pop and not Motion.reduce:
		Motion.pop_in(face, Motion.POP_IN)

# --- the loops ---

func _start() -> void:
	if not is_inside_tree() or _tile <= 0.0:
		return
	Motion.stop(_loop)
	_reset()
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	match lesson:
		Lesson.TAP:
			var cell: Vector2i = _targets[0][0]
			_loop.tween_callback(_reset)
			_loop.tween_interval(0.9)
			for step in 3:
				_loop.tween_callback(_press.bind(cell))
				_loop.tween_interval(Motion.PRESS_TIME + 0.06)
				_loop.tween_callback(_tap_step.bind(cell, step))
				_loop.tween_interval(1.3)
		Lesson.HEART:
			var cell: Vector2i = _targets[0][0]
			_loop.tween_callback(_reset)
			_loop.tween_interval(0.9)
			_loop.tween_callback(_press.bind(cell))
			_loop.tween_interval(Motion.PRESS_TIME + 0.06)
			_loop.tween_callback(_wrong.bind(cell))
			_loop.tween_interval(0.45)
			_loop.tween_callback(_crack.bind(cell))
			_loop.tween_interval(0.9)
			_loop.tween_callback(_drop.bind(cell))
			_loop.tween_interval(1.6)
		_:
			_loop.tween_callback(_reset)
			for i in _targets.size():
				_loop.tween_interval(0.8)
				_loop.tween_callback(_press.bind(_targets[i][0]))
				_loop.tween_interval(Motion.PRESS_TIME + 0.06)
				_loop.tween_callback(_answer.bind(i, true))
			_loop.tween_interval(2.0)

## Every lesson back to its question: the targets empty and glowing.
func _reset() -> void:
	_hearts_full = 1.0
	for t in _targets:
		var cell: Vector2i = t[0]
		_set_face(cell, -1, false)
		_tiles[cell].scale = Vector2.ONE
		_tiles[cell].rotation = 0.0
		_styles[cell].bg_color = Pal.SURFACE
		var glow: Panel = _glows[cell]
		glow.modulate.a = 1.0
		if not Motion.reduce:
			var pulse := glow.create_tween()
			pulse.tween_property(glow, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(glow, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_caption.text = _caption_for(0)
	_over.queue_redraw()

## Reduce-motion: the lesson's result, standing still.
func _still() -> void:
	match lesson:
		Lesson.TAP:
			_tap_step(_targets[0][0], 0)
		Lesson.HEART:
			_hearts_full = 0.0
			_caption.text = _caption_for(1)
			_over.queue_redraw()
		_:
			for i in _targets.size():
				_answer(i, false)

func _press(cell: Vector2i) -> void:
	var tile: Panel = _tiles[cell]
	Motion.press(tile, true)
	var release := tile.create_tween()
	release.tween_interval(Motion.PRESS_TIME)
	release.tween_callback(func() -> void: Motion.press(tile, false))

func _answer(i: int, pop: bool) -> void:
	var cell: Vector2i = _targets[i][0]
	_glows[cell].modulate.a = 0.0
	_set_face(cell, _targets[i][1], pop)
	if _faces.has(cell):
		_faces[cell].expression = Face.Expr.JOY
	if i == _targets.size() - 1:
		_caption.text = _caption_for(0) + "  ✓"

## TAP's cycle: step 0 lays a sun, 1 turns it to a moon, 2 clears it.
func _tap_step(cell: Vector2i, step: int) -> void:
	_glows[cell].modulate.a = 0.0
	_set_face(cell, [0, 1, -1][step], true)
	_caption.text = _caption_for(step)
	if step == 2:
		_glows[cell].modulate.a = 1.0

## HEART: the wrong moon lands (a third moon in the line).
func _wrong(cell: Vector2i) -> void:
	_glows[cell].modulate.a = 0.0
	_set_face(cell, 1, true)

## It blushes, shivers and its face worries; the heart breaks.
func _crack(cell: Vector2i) -> void:
	_styles[cell].bg_color = Pal.BAD_TILE
	if _faces.has(cell):
		_faces[cell].expression = Face.Expr.WORRIED
	var tile: Panel = _tiles[cell]
	var shiver := tile.create_tween()
	for k in 4:
		shiver.tween_property(tile, "rotation", 0.08 * (1 if k % 2 == 0 else -1), 0.05)
	shiver.tween_property(tile, "rotation", 0.0, 0.05)
	var fade := create_tween()
	fade.tween_method(func(a: float) -> void:
		_hearts_full = a
		_over.queue_redraw(), 1.0, 0.0, 0.35)
	_caption.text = _caption_for(1)

## It drops out of its tile and the tile goes back to white.
func _drop(cell: Vector2i) -> void:
	var face: Control = _faces.get(cell)
	_faces.erase(cell)
	_styles[cell].bg_color = Pal.SURFACE
	if face == null:
		return
	var tw := face.create_tween().set_parallel()
	tw.tween_property(face, "position:y", face.position.y + _tile * 0.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(face, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(face.queue_free)

func _caption_for(step: int) -> String:
	match lesson:
		Lesson.TAP:
			return tr(["HTP_BN_TAP_SUN", "HTP_BN_TAP_MOON", "HTP_BN_TAP_CLEAR"][step])
		Lesson.THREE:
			return tr("HTP_TWO_MOONS")
		Lesson.HALF:
			return tr("HTP_BN_HALF_CAP")
		Lesson.SIGNS:
			return tr("HTP_BN_SIGNS_CAP")
		Lesson.HEART:
			return tr("HTP_BN_HEART_CAP") if step == 0 else tr("HTP_BN_HEART_LOST")
	return ""

# --- signs and hearts ---

func _draw_over() -> void:
	if _tile <= 0.0:
		return
	var b := Face.Builder.new()
	for s in _signs:
		var at := (_centre(s[0]) + _centre(s[1])) * 0.5
		var r := _tile * SIGN_R
		var w := r * 0.5
		var line := maxf(3.0, _tile * 0.035)
		b.disc(at, r + 2.0, Pal.LINE)
		b.disc(at, r, Pal.SURFACE)
		if s[2] == 1:
			for dy in [-0.45, 0.45]:
				b.stroke(PackedVector2Array([at + Vector2(-w, dy * w), at + Vector2(w, dy * w)]), line, Pal.ACORN_DEEP)
		else:
			var k := w * 0.8
			b.stroke(PackedVector2Array([at + Vector2(-k, -k), at + Vector2(k, k)]), line, Pal.ACORN_DEEP)
			b.stroke(PackedVector2Array([at + Vector2(-k, k), at + Vector2(k, -k)]), line, Pal.ACORN_DEEP)
	if lesson == Lesson.HEART:
		var at := Vector2(size.x * 0.5, HEART_R + 6.0)
		b.disc(at, HEART_R + 16.0, Color(Pal.LINE, 0.6))
		b.disc(at, HEART_R + 14.0, Pal.SURFACE)
		_heart(b, at, HEART_R, Color(Pal.BAD, 0.25 + 0.75 * _hearts_full))
	if b.verts.is_empty():
		return
	# Kept until the next draw replaces it: a canvas command holds a mesh by RID.
	_over_shown = b.mesh()
	_over.draw_mesh(_over_shown, null)

## A heart of radius-ish `r` about `at`: two lobes and a point.
static func _heart(b, at: Vector2, r: float, colour: Color) -> void:
	var lobe := r * 0.52
	b.disc(at + Vector2(-lobe * 0.95, -r * 0.18), lobe, colour)
	b.disc(at + Vector2(lobe * 0.95, -r * 0.18), lobe, colour)
	b.polygon(PackedVector2Array([
		at + Vector2(-r * 0.98, -r * 0.05),
		at + Vector2(r * 0.98, -r * 0.05),
		at + Vector2(0.0, r * 0.95),
	]), colour)

func _centre(cell: Vector2i) -> Vector2:
	return _origin + Vector2(cell) * (_tile + GAP) + Vector2(_tile, _tile - TILE_EDGE) * 0.5

# --- styles ---

func _tile_style(given: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.STONE_GIVEN if given else Pal.SURFACE
	sb.set_corner_radius_all(TILE_RADIUS)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = TILE_EDGE
	sb.border_color = Pal.LINE if given else Color(Pal.LINE, 0.5)
	return sb

func _glow_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.SUN_TILE
	sb.set_corner_radius_all(TILE_RADIUS - 2)
	return sb
