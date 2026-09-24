extends Control

## The shared tutorial stage. Each puzzle gets its own miniature board, its
## production character where one exists, and one calm animated move. This is
## deliberately a lesson rather than menu art: the caption says what the move
## means and the motion demonstrates the verb the player uses.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Face = preload("res://ui/faces/face.gd")
const Friends = preload("res://ui/faces/friends.gd")
const Fruit = preload("res://ui/faces/fruit.gd")
const LanternFace = preload("res://ui/faces/lantern_face.gd")
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")

const GRID := 4
const GAP := 10.0

var puzzle_id := ""
var _pieces: Array[Control] = []
var _caption: Label
var _progress := 0.0:
	set(value):
		_progress = value
		_layout_pieces()
		queue_redraw()
var _loop: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_build_pieces()
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.text = _lesson()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(_layout)
	call_deferred("_layout")
	call_deferred("_animate")

func _exit_tree() -> void:
	Motion.stop(_loop)

func _build_pieces() -> void:
	match puzzle_id:
		"mastermind":
			_add_piece(Friends.make(2, 100.0, Vector2.ZERO))
			_add_piece(Friends.make(3, 100.0, Vector2.ZERO))
		"balance":
			_add_piece(Fruit.make(0, 100.0, Vector2.ZERO))
			_add_piece(Fruit.make(2, 100.0, Vector2.ZERO))
		"untangle":
			_add_piece(LanternFace.new())
			_add_piece(LanternFace.new())
		"shikaku":
			var marker := MarkerFace.new()
			marker.number = 6
			_add_piece(marker)
		"tents":
			_add_piece(ConiferFace.new())
			_add_piece(TentFace.new())
		"lightup":
			var lamp := CourtLantern.new()
			lamp.lit = 1.0
			_add_piece(lamp)
		"oneline": _add_piece(SnailFace.new())
		"queens": _add_piece(BeeFace.new())
		"mushroom":
			var mushroom := MushroomFace.new()
			mushroom.sprig = true
			_add_piece(mushroom)

func _add_piece(piece: Control) -> void:
	piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if "expression" in piece:
		piece.expression = Face.Expr.HAPPY
	if piece.has_method("set_idle"):
		piece.set_idle(true)
	add_child(piece)
	_pieces.append(piece)

func _layout() -> void:
	_layout_pieces()
	var board := _board_rect()
	_caption.position = Vector2(0.0, board.end.y + 10.0)
	_caption.size = Vector2(size.x, 48.0)
	queue_redraw()

func _layout_pieces() -> void:
	if _pieces.is_empty() or size.x <= 0.0:
		return
	var board := _board_rect()
	var cell := (board.size.x - GAP * (GRID - 1)) / GRID
	var a := board.position + Vector2(cell * 1.5 + GAP, cell * 1.5 + GAP)
	var b := board.position + Vector2(cell * 2.5 + GAP * 2.0, cell * 2.5 + GAP * 2.0)
	var moving := puzzle_id in ["untangle", "oneline", "wordtrail", "bridges", "planes"]
	for i in _pieces.size():
		var piece := _pieces[i]
		var extent := cell * (0.82 if puzzle_id != "shikaku" else 0.95)
		piece.size = Vector2(extent, extent)
		piece.pivot_offset = piece.size * 0.5
		var centre := a if i == 0 else b
		if moving and i == 0:
			centre = a.lerp(b, _ease(_progress))
		piece.position = centre - piece.size * 0.5
		if i == _pieces.size() - 1 and puzzle_id in ["mastermind", "tents", "queens", "mushroom"]:
			piece.scale = Vector2.ONE * (0.25 + 0.75 * _ease(_progress))
			piece.modulate.a = _ease(_progress)
		else:
			piece.scale = Vector2.ONE
			piece.modulate.a = 1.0

func _animate() -> void:
	if Motion.reduce:
		_progress = 1.0
		return
	_loop = create_tween().set_loops()
	_loop.tween_property(self, "_progress", 1.0, 0.9).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(1.35)
	_loop.tween_property(self, "_progress", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.55)

func _draw() -> void:
	var board := _board_rect()
	var cell := (board.size.x - GAP * (GRID - 1)) / GRID
	for r in GRID:
		for c in GRID:
			var rect := Rect2(board.position + Vector2(c, r) * (cell + GAP), Vector2(cell, cell))
			draw_style_box(_tile(_cell_fill(r, c)), rect)
	_draw_game_marks(board, cell)

func _draw_game_marks(board: Rect2, cell: float) -> void:
	var p := _ease(_progress)
	match puzzle_id:
		"untangle":
			var left := _centre(board, cell, 0, 0)
			var right := _centre(board, cell, 3, 3)
			draw_line(left, right, Pal.CORD if p > 0.5 else Pal.BAD, 7.0, true)
			draw_line(_centre(board, cell, 3, 0), _centre(board, cell, 0, 3), Pal.CORD, 7.0, true)
		"shikaku":
			_draw_outline(Rect2(_cell_at(board, cell, 0, 1), Vector2(cell * 3.0 + GAP * 2.0, cell * 2.0 + GAP)), Pal.GOOD, 7.0 * p)
		"lightup":
			for point in [_centre(board, cell, 1, 0), _centre(board, cell, 1, 2), _centre(board, cell, 0, 1), _centre(board, cell, 2, 1)]:
				draw_circle(point, cell * 0.36, Color(Pal.SUN, 0.08 + 0.22 * p))
		"oneline":
			var path := PackedVector2Array([_centre(board, cell, 0, 1), _centre(board, cell, 1, 1), _centre(board, cell, 1, 2), _centre(board, cell, 2, 2)])
			_draw_path(path, p, Pal.ACCENT, 9.0)
		"nonogram":
			for c in 3:
				if float(c + 1) / 3.0 <= p + 0.01:
					draw_rect(Rect2(_cell_at(board, cell, c, 1) + Vector2(9, 9), Vector2(cell - 18, cell - 18)), Pal.MOON_INK, true)
			_draw_number("3", _centre(board, cell, 3, 1), Pal.TEXT)
		"hiddenword":
			_draw_letters(board, cell, ["C", "A", "M", "P"], p)
		"wordtrail":
			_draw_letters(board, cell, ["P", "A", "T", "H"], 1.0)
			_draw_path(PackedVector2Array([_centre(board, cell, 0, 1), _centre(board, cell, 1, 1), _centre(board, cell, 2, 1), _centre(board, cell, 3, 1)]), p, Pal.MOON_INK, 8.0)
		"sudoku":
			for i in 4: _draw_number(str(i + 1), _centre(board, cell, i, i), Pal.TEXT)
			if p > 0.45: _draw_number("3", _centre(board, cell, 2, 0), Pal.ACCENT)
		"bridges":
			var a := _centre(board, cell, 0, 1)
			var b := _centre(board, cell, 3, 1)
			draw_circle(a, cell * 0.18, Pal.SURFACE)
			draw_circle(b, cell * 0.18, Pal.SURFACE)
			draw_line(a, a.lerp(b, p), Pal.WOOD, 10.0, true)
		"quilt":
			for i in 4:
				var fill: Color = [Pal.BERRY_TILE, Pal.SUN_TILE, Pal.LEAF_TILE, Pal.MOON_TILE][i]
				draw_rect(Rect2(_cell_at(board, cell, i, 1) + Vector2(7, 7), Vector2(cell - 14, cell - 14)), fill, true)
			if p > 0.5: _draw_outline(Rect2(_cell_at(board, cell, 0, 1), Vector2(cell * 4.0 + GAP * 3.0, cell)), Pal.GOOD, 6.0)
		"planes":
			var from := _centre(board, cell, 0, 3)
			var to := _centre(board, cell, 3, 0)
			draw_line(from, from.lerp(to, p), Pal.ACCENT, 8.0, true)
			_draw_plane(from.lerp(to, p))
		"rings":
			var centre := _centre(board, cell, 1, 1)
			for i in 3: draw_arc(centre, cell * (0.18 + i * 0.14), 0.0, TAU * p, 32, [Pal.BERRY, Pal.SUN, Pal.ACCENT][i], 8.0, true)

func _lesson() -> String:
	match puzzle_id:
		"mastermind": return tr("HTP_LESSON_CB")
		"balance": return tr("HTP_LESSON_BAL")
		"untangle": return tr("HTP_LESSON_UT")
		"shikaku": return tr("HTP_LESSON_SK")
		"tents": return tr("HTP_LESSON_TN")
		"lightup": return tr("HTP_LESSON_LU")
		"oneline": return tr("HTP_LESSON_OL")
		"nonogram": return tr("HTP_LESSON_NG")
		"queens": return tr("HTP_LESSON_QN")
		"hiddenword": return tr("HTP_LESSON_HW")
		"wordtrail": return tr("HTP_LESSON_WT")
		"mushroom": return tr("HTP_LESSON_MP")
		"sudoku": return tr("HTP_LESSON_SD")
		"bridges": return tr("HTP_LESSON_BR")
		"quilt": return tr("HTP_LESSON_QL")
		"planes": return tr("HTP_LESSON_PP")
		"rings": return tr("HTP_LESSON_RG")
		_: return tr("HTP_LESSON_ANY")

func _board_rect() -> Rect2:
	var side := minf(size.x - 180.0, size.y - 64.0)
	return Rect2(Vector2((size.x - side) * 0.5, 0.0), Vector2(side, side))

func _cell_at(board: Rect2, cell: float, c: int, r: int) -> Vector2:
	return board.position + Vector2(c, r) * (cell + GAP)

func _centre(board: Rect2, cell: float, c: int, r: int) -> Vector2:
	return _cell_at(board, cell, c, r) + Vector2.ONE * cell * 0.5

func _cell_fill(r: int, c: int) -> Color:
	if puzzle_id == "queens":
		return [Pal.BERRY_TILE, Pal.SUN_TILE, Pal.LEAF_TILE, Pal.MOON_TILE][(r + c) % 4]
	return Pal.SURFACE_HI if (r + c) % 3 == 0 else Pal.SURFACE

func _tile(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 4
	sb.border_color = Pal.LINE
	return sb

func _draw_outline(rect: Rect2, colour: Color, width: float) -> void:
	if width > 0.0:
		draw_rect(rect.grow(-3.0), colour, false, width)

func _draw_number(value: String, centre: Vector2, colour: Color) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 38
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, centre + Vector2(-width * 0.5, font_size * 0.35), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

func _draw_letters(board: Rect2, cell: float, letters: Array[String], reveal: float) -> void:
	for i in letters.size():
		var colour := Pal.GOOD if float(i + 1) / letters.size() <= reveal + 0.01 else Pal.TEXT
		_draw_number(letters[i], _centre(board, cell, i, 1), colour)

func _draw_path(points: PackedVector2Array, amount: float, colour: Color, width: float) -> void:
	if points.size() < 2:
		return
	var scaled := amount * float(points.size() - 1)
	var whole := int(floor(scaled))
	for i in mini(whole, points.size() - 1):
		draw_line(points[i], points[i + 1], colour, width, true)
	if whole < points.size() - 1:
		draw_line(points[whole], points[whole].lerp(points[whole + 1], scaled - whole), colour, width, true)

func _draw_plane(at: Vector2) -> void:
	var points := PackedVector2Array([at + Vector2(0, -18), at + Vector2(14, 16), at, at + Vector2(-14, 16)])
	draw_colored_polygon(points, Pal.ACCENT)

func _ease(value: float) -> float:
	return value * value * (3.0 - 2.0 * value)
