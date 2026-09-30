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
const MarkerFace = preload("res://ui/faces/marker_face.gd")
const TentFace = preload("res://ui/faces/tent_face.gd")
const ConiferFace = preload("res://ui/faces/conifer_face.gd")
const CourtLantern = preload("res://ui/faces/court_lantern.gd")
const SnailFace = preload("res://ui/faces/snail_face.gd")
const BeeFace = preload("res://ui/faces/bee_face.gd")
const MushroomFace = preload("res://ui/faces/mushroom_face.gd")
const Cloth = preload("res://ui/faces/patch_cloth.gd")

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
			pass
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
	# Bridges lays three planks and Quilt drags two patches in one loop, so
	# they take their time.
	_loop.tween_property(self, "_progress", 1.0, 2.4 if puzzle_id in ["bridges", "quilt"] else 0.9).from(0.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(1.35)
	_loop.tween_property(self, "_progress", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_interval(0.55)

func _draw() -> void:
	var board := _board_rect()
	var cell := (board.size.x - GAP * (GRID - 1)) / GRID
	if puzzle_id == "bridges":
		_draw_bridges(board, cell)
		return
	if puzzle_id == "quilt":
		_draw_quilt(board, cell)
		return
	for r in GRID:
		for c in GRID:
			var rect := Rect2(board.position + Vector2(c, r) * (cell + GAP), Vector2(cell, cell))
			draw_style_box(_tile(_cell_fill(r, c)), rect)
	_draw_game_marks(board, cell)

func _draw_game_marks(board: Rect2, cell: float) -> void:
	var p := _ease(_progress)
	match puzzle_id:
		"untangle":
			# Two cords that cross, the coral one lying on top of the yellow;
			# the top cord's peg lifts from the top right into the empty hole
			# below and it slides off. Rims so over and under read.
			var peg := _centre(board, cell, 3, 0).lerp(_centre(board, cell, 3, 2), p)
			var under := [_centre(board, cell, 0, 0), _centre(board, cell, 3, 1)]
			var over := [_centre(board, cell, 0, 1), peg]
			draw_line(under[0], under[1], Color("b98d2e"), 14.0, true)
			draw_line(under[0], under[1], Color("f0c35a"), 9.0, true)
			draw_line(over[0] + Vector2(1.5, 4.0), over[1] + Vector2(1.5, 4.0), Color(Pal.TEXT, 0.18), 13.0, true)
			draw_line(over[0], over[1], Color("b9573f"), 14.0, true)
			draw_line(over[0], over[1], Color("e8806a"), 9.0, true)
			draw_circle(_centre(board, cell, 3, 2), cell * 0.3, Color("5f4229"))
			for point in [_centre(board, cell, 0, 0), _centre(board, cell, 3, 1), _centre(board, cell, 0, 1), peg]:
				draw_circle(point, cell * 0.3, Pal.WOOD_DEEP)
				draw_circle(point, cell * 0.24, Color("d7a56e"))
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
		"planes":
			var from := _centre(board, cell, 0, 3)
			var to := _centre(board, cell, 3, 0)
			draw_line(from, from.lerp(to, p), Pal.ACCENT, 8.0, true)
			_draw_plane(from.lerp(to, p))
		"rings":
			var centre := _centre(board, cell, 1, 1)
			for i in 3: draw_arc(centre, cell * (0.18 + i * 0.14), 0.0, TAU * p, 32, [Pal.BERRY, Pal.SUN, Pal.ACCENT][i], 8.0, true)

## Bridges' lesson on its own sea (the polish, 2026-09-30; the first cut was
## two white dots and a line with no numbers, which taught nothing). Three
## islets, 2, 3 and 1: a finger lays two planks from the 2 to the 3, then one
## down from the 3 to the 1, and every ring round a number fills a slot per
## plank until all three coins turn green -- the whole rule in one loop.
func _draw_bridges(board: Rect2, cell: float) -> void:
	var p := _progress
	draw_rect(board, Pal.WATER_HI.lerp(Pal.PAPER, 0.1), true)
	draw_rect(board, Pal.WATER.lerp(Pal.TEXT, 0.18), false, 4.0)
	var a := _centre(board, cell, 0, 0)
	var b := _centre(board, cell, 3, 0)
	var c := _centre(board, cell, 3, 3)
	var r := cell * 0.36
	var gap := cell * 0.13
	# The three planks, each growing out of the islet the finger left.
	var segs := [[a + Vector2(r, -gap), b + Vector2(-r, -gap), 0.0, 0.33],
		[a + Vector2(r, gap), b + Vector2(-r, gap), 0.33, 0.66],
		[b + Vector2(0.0, r), c + Vector2(0.0, -r), 0.66, 1.0]]
	var tip := a
	var laid := [0, 0, 0]
	for i in segs.size():
		var sg: Array = segs[i]
		var u := clampf((p - float(sg[2])) / (float(sg[3]) - float(sg[2])), 0.0, 1.0)
		if u <= 0.0:
			continue
		var from: Vector2 = sg[0]
		var to: Vector2 = sg[1]
		draw_line(from, from.lerp(to, _ease(u)), Pal.WOOD_DEEP, cell * 0.13, true)
		draw_line(from, from.lerp(to, _ease(u)), Pal.DECK, cell * 0.09, true)
		if u < 1.0:
			tip = (a if i < 2 else b).lerp(b if i < 2 else c, _ease(u))
		else:
			tip = b if i < 2 else c
			if i < 2:
				laid[0] += 1
				laid[1] += 1
			else:
				laid[1] += 1
				laid[2] += 1
	var islets := [[a, 2, laid[0]], [b, 3, laid[1]], [c, 1, laid[2]]]
	for isl in islets:
		var at: Vector2 = isl[0]
		var want: int = isl[1]
		var got: int = isl[2]
		draw_circle(at + Vector2(0.0, r * 0.3), r, Pal.CAMP_SOIL)
		draw_circle(at, r, Pal.BANK)
		var met := got == want
		draw_circle(at, r * 0.62, Pal.LEAF_TILE.lerp(Pal.GOOD, 0.22) if met else Pal.SURFACE)
		var step := TAU / float(want)
		for k in want:
			var a0 := -PI * 0.5 + step * k + 0.12
			draw_arc(at, r * 0.8, a0, a0 + step - 0.24, 16,
				Pal.LEAF_DEEP if met else (Pal.WOOD_DEEP if k < got else Color(Pal.SURFACE, 0.9)), 6.0, true)
		_draw_number(str(want), at, Pal.LEAF_DEEP if met else Pal.TEXT)
	# The finger, riding the plank being laid.
	if p > 0.0 and p < 1.0:
		draw_circle(tip + Vector2(4.0, 8.0), cell * 0.2, Color(Pal.TEXT, 0.16))
		draw_circle(tip, cell * 0.17, Color(Pal.SURFACE, 0.95))
		draw_arc(tip, cell * 0.17, 0.0, TAU, 24, Pal.LINE, 3.0, true)

## Quilt's lesson on its own little quilt (the polish, 2026-09-30; the first
## cut was four squares in a row captioned "join matching patches", which is
## not the game). A pale 3 x 2 backing, and under it a felt rack holding two
## L-shaped patches. A finger drags the first one up -- it grows to the
## quilt's size, its landing outline shows as it nears, and it snaps on --
## then the second, and the covered quilt glows green: drag, snap, cover.
func _draw_quilt(board: Rect2, cell: float) -> void:
	var p := _progress
	var q := cell * 0.92
	var back_at := board.position + Vector2(board.size.x * 0.5 - q * 1.5, cell * 0.2)
	var rack := Rect2(board.position + Vector2(0.0, board.size.y * 0.66), Vector2(board.size.x, board.size.y * 0.34))
	var small := q * 0.55
	var shapes := [[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
		[Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]]
	var homes := [back_at, back_at + Vector2(q, 0.0)]
	var bays := [rack.position + Vector2(rack.size.x * 0.28 - small, rack.size.y * 0.5 - small),
		rack.position + Vector2(rack.size.x * 0.72 - small, rack.size.y * 0.5 - small)]
	# The felt rack, and the backing with its faint rules.
	draw_rect(rack, Color("e4e2c6"), true)
	draw_rect(rack.grow(-8.0), Color("f7f3e4"), false, 2.5)
	var cover := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	var done := p >= 0.97
	_quilt_shape(cover, back_at, q, Pal.QUILT_BACK, Pal.LINE)
	for c in 3:
		for r in 2:
			draw_rect(Rect2(back_at + Vector2(c, r) * q + Vector2.ONE * q * 0.08, Vector2.ONE * q * 0.84), Color(Pal.SURFACE, 0.3), true)
	var tip := Vector2(-1.0, -1.0)
	for i in 2:
		var u := clampf((p - 0.08 - 0.45 * i) / 0.36, 0.0, 1.0)
		var e := _ease(u)
		var size_now := lerpf(small, q, e)
		var at: Vector2 = (bays[i] as Vector2).lerp(homes[i], e)
		if u > 0.0 and u < 1.0:
			# Lifted: held above the finger with its shadow under it, and the
			# landing outline on the backing once it is near.
			at.y -= sin(u * PI) * q * 0.25
			if u > 0.6:
				_quilt_outline(shapes[i], homes[i], q, Cloth.cloth_stitch(i))
			_quilt_shape(shapes[i], at + Vector2(4.0, 9.0), size_now, Color(Pal.TEXT, 0.14), Color(Pal.TEXT, 0.0))
			tip = at + Vector2(size_now * 0.5, size_now * 1.5)
		_quilt_shape(shapes[i], at, size_now, Cloth.cloth(i), Cloth.cloth_deep(i))
		if u >= 1.0:
			_quilt_outline(shapes[i], at, size_now, Color(Cloth.cloth_thread(i), 0.9), 2.5)
	if done:
		_quilt_outline(cover, back_at, q, Pal.GOOD, 6.0)
	if tip.x >= 0.0:
		draw_circle(tip + Vector2(4.0, 8.0), cell * 0.2, Color(Pal.TEXT, 0.16))
		draw_circle(tip, cell * 0.17, Color(Pal.SURFACE, 0.95))
		draw_arc(tip, cell * 0.17, 0.0, TAU, 24, Pal.LINE, 3.0, true)

func _quilt_shape(cells: Array, at: Vector2, cell: float, face: Color, deep: Color) -> void:
	for loop: PackedVector2Array in Cloth.loops(cells):
		var pts := PackedVector2Array()
		for v in loop:
			pts.append(at + v * cell)
		pts = Cloth.round_loop(pts, cell * 0.16)
		if deep.a > 0.0:
			var low := PackedVector2Array()
			for v in pts:
				low.append(v + Vector2(0.0, cell * 0.07))
			draw_colored_polygon(low, deep)
		draw_colored_polygon(pts, face)

func _quilt_outline(cells: Array, at: Vector2, cell: float, ink: Color, width := 3.5) -> void:
	for loop: PackedVector2Array in Cloth.loops(cells):
		var pts := PackedVector2Array()
		for v in loop:
			pts.append(at + v * cell)
		pts = Cloth.round_loop(pts, cell * 0.16)
		pts.append(pts[0])
		draw_polyline(pts, ink, width, true)

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
