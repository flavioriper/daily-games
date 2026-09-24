extends Control

## A tiny playable-looking Binairo lesson. It deliberately uses the same tile
## treatment, SunFace, MoonFace and motion recipes as the board: two moons in
## the teaching row force a sun into the empty cell.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const SunFace = preload("res://ui/faces/sun_face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")

const N := 4
const GAP := 12.0
const TILE_EDGE := 4
const TILE_RADIUS := 18
const SUN_SIZE := 0.26 * 2.0 * 1.55
const MOON_SIZE := 0.34 * 2.0
const TARGET := Vector2i(2, 1)

var _tiles: Array[Panel] = []
var _faces: Array[Control] = []
var _target_face: Control
var _target_glow: Panel
var _caption: Label
var _loop: Tween
var _tile := 0.0
var _origin := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build_board()
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_start_lesson")

func _exit_tree() -> void:
	Motion.stop(_loop)

func _build_board() -> void:
	# The second row is the lesson: moon, moon, empty, sun. The other rows
	# make this read as the real board rather than a row of explanatory icons.
	var values := [
		[0, -1, 1, -1],
		[1, 1, -1, 0],
		[-1, 0, -1, 1],
		[1, -1, 0, -1],
	]
	for r in N:
		for c in N:
			var tile := Panel.new()
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.add_theme_stylebox_override("panel", _tile_style(values[r][c] != -1))
			add_child(tile)
			_tiles.append(tile)

			if Vector2i(c, r) == TARGET:
				_target_glow = Panel.new()
				_target_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_target_glow.add_theme_stylebox_override("panel", _glow_style())
				tile.add_child(_target_glow)

			var face: Control
			if values[r][c] == 0:
				face = SunFace.new()
			elif values[r][c] == 1:
				face = MoonFace.new()
			else:
				_faces.append(null)
				continue
			tile.add_child(face)
			face.expression = Face.Expr.HAPPY
			face.set_idle(true)
			_faces.append(face)

	_target_face = SunFace.new()
	_tiles[TARGET.y * N + TARGET.x].add_child(_target_face)
	_target_face.expression = Face.Expr.JOY
	_target_face.visible = false
	_target_face.set_idle(true)

	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.text = "HTP_TWO_MOONS"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)

func _layout() -> void:
	if _tiles.is_empty():
		return
	var board_side := minf(size.x - 180.0, size.y - 64.0)
	_tile = (board_side - GAP * (N - 1)) / N
	_origin = Vector2((size.x - board_side) * 0.5, 0.0)
	for r in N:
		for c in N:
			var index := r * N + c
			var tile := _tiles[index]
			tile.position = _origin + Vector2(c, r) * (_tile + GAP)
			tile.size = Vector2(_tile, _tile)
			tile.pivot_offset = tile.size * 0.5
			if Vector2i(c, r) == TARGET:
				_target_glow.position = Vector2.ZERO
				_target_glow.size = Vector2(_tile, _tile - TILE_EDGE)
			var face: Control = _faces[index]
			if face != null:
				_fit_face(face, 0 if face is SunFace else 1)
	_fit_face(_target_face, 0)
	_caption.position = Vector2(0.0, board_side + 12.0)
	_caption.size = Vector2(size.x, 52.0)

func _fit_face(face: Control, value: int) -> void:
	var extent := _tile * (SUN_SIZE if value == 0 else MOON_SIZE)
	face.size = Vector2(extent, extent)
	face.pivot_offset = face.size * 0.5
	face.position = (Vector2(_tile, _tile - TILE_EDGE) - face.size) * 0.5

func _start_lesson() -> void:
	if not is_inside_tree() or _tile <= 0.0:
		return
	if Motion.reduce:
		_show_answer(true)
		return
	_loop = create_tween().set_loops()
	_loop.tween_callback(_reset_lesson)
	_loop.tween_interval(0.75)
	_loop.tween_callback(_press_target)
	_loop.tween_interval(Motion.PRESS_TIME + 0.08)
	_loop.tween_callback(_show_answer.bind(false))
	_loop.tween_interval(2.0)

func _reset_lesson() -> void:
	_target_face.visible = false
	_target_face.scale = Vector2.ONE
	_target_glow.modulate.a = 1.0
	_caption.text = "HTP_TWO_MOONS"
	var tile := _tiles[TARGET.y * N + TARGET.x]
	tile.scale = Vector2.ONE
	var pulse := create_tween()
	pulse.tween_property(_target_glow, "modulate:a", 0.35, 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_target_glow, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)

func _press_target() -> void:
	var tile := _tiles[TARGET.y * N + TARGET.x]
	Motion.press(tile, true)
	var release := create_tween()
	release.tween_interval(Motion.PRESS_TIME)
	release.tween_callback(func() -> void: Motion.press(tile, false))

func _show_answer(immediate: bool) -> void:
	_target_face.visible = true
	_target_glow.modulate.a = 0.0
	_caption.text = tr("HTP_TWO_MOONS") + "  ✓"
	if immediate:
		_target_face.scale = Vector2.ONE
		return
	Motion.pop_in(_target_face, Motion.POP_IN)

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
