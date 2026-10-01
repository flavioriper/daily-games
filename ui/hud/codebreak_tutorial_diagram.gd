extends Control

## One page of Code Break's tutorial, drawn with the board's own pieces --
## its friends, sockets, wooden lids, score pouch and Shell Game arc -- and
## one move played on a loop over a caption that says what it means. `lesson`
## picks the page (set before it enters the tree):
##
## - SEAT: friends hop from the palette into the next seat; a seated one is
##   tapped and hops back.
## - SCORE: a full row is checked, the pouch fills (one filled pip, two
##   rings) and the lids lift on the code that scored it.
## - CRACK: two played rows, then the row that cracks it: four filled pips
##   and the lids fly off.
## - HINT: a friend of the code drops into a seat and takes the sun rim.
## - SHELL: Insane's swap: two lids hop past each other and the arc under
##   the row records it.
##
## Performance checkup, 2026-10-01: the one generic card became these pages.

const CB = preload("res://puzzles/codebreak2d.gd")
const Friends = preload("res://ui/faces/friends.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

enum Lesson { SEAT, SCORE, CRACK, HINT, SHELL }

const SEATS := 4
## The code every page hides, and SCORE's guess against it: the sun in
## place, the berry and the leaf in the wrong seats, the cloud nowhere.
const CODE := [0, 2, 3, 1]
const GUESS := [0, 3, 4, 2]
const PIECE_MAX := 112.0
const PITCH := 1.22
const SMALL := 0.62
const FLY_ARC := 80.0

var lesson: int = Lesson.SEAT

var _caption: Label
var _stage: Control
var _loop: Tween
var _p := 0.0
## Seat-row origin x and the pouch's left edge, at full size.
var _x0 := 0.0
var _room := 0.0
## Per row made by _row(): {y, p, sockets, faces, pouch}.
var _rows: Array = []
var _lids: Array = []        # [s] -> CB.Lid
var _code_faces: Array = []  # [s] -> the friend under lid s
var _chips: Array = []       # [i] -> chip Panel
var _mark: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_caption = Label.new()
	_caption.theme_type_variation = "SheetBodyDim"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# One short line: a wrapping label measured before layout grows tall.
	_caption.clip_text = true
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	resized.connect(func() -> void: call_deferred("_start"))
	call_deferred("_start")

func _enter_tree() -> void:
	# A page turned back to starts its lesson again.
	if _p > 0.0 and _loop == null:
		call_deferred("_start")

func _exit_tree() -> void:
	Motion.stop(_loop)
	_loop = null

func _start() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	Motion.stop(_loop)
	_caption.position = Vector2(20.0, size.y - 92.0)
	_caption.size = Vector2(size.x - 40.0, 88.0)
	_room = size.y - 96.0
	_p = minf(PIECE_MAX, (size.x - 120.0) / (SEATS * PITCH + 1.3))
	if lesson == Lesson.CRACK:
		# The code, two played rows and the row in hand, one over another.
		_p = minf(_p, (_room - 30.0) / (2.0 + SMALL * 2.5))
	var pouch_w: float = CB.POUCH.x * _p / CB.PIECE_MAX
	var row_w := SEATS * _p * PITCH + pouch_w
	_x0 = (size.x - row_w) * 0.5
	_scene()
	if Motion.reduce:
		_still()
		return
	_loop = create_tween().set_loops()
	match lesson:
		Lesson.SEAT:
			_loop.tween_callback(_scene)
			for k in 3:
				_loop.tween_interval(0.7)
				_loop.tween_callback(_seat_from_chip.bind(k))
			_loop.tween_interval(1.0)
			_loop.tween_callback(_send_back.bind(1))
			_loop.tween_interval(1.8)
		Lesson.SCORE:
			_loop.tween_callback(_scene)
			_loop.tween_interval(1.0)
			_loop.tween_callback(_check.bind(0, 1, 2))
			_loop.tween_interval(1.6)
			_loop.tween_callback(_lift_lids)
			_loop.tween_interval(2.6)
		Lesson.CRACK:
			_loop.tween_callback(_scene)
			for s in SEATS:
				_loop.tween_interval(0.35)
				_loop.tween_callback(_drop_in.bind(2, s, CODE[s], false))
			_loop.tween_interval(0.6)
			_loop.tween_callback(_check.bind(2, SEATS, 0))
			_loop.tween_interval(1.3)
			_loop.tween_callback(_toss_lids)
			_loop.tween_interval(2.4)
		Lesson.HINT:
			_loop.tween_callback(_scene)
			_loop.tween_interval(1.0)
			_loop.tween_callback(_drop_in.bind(0, 2, CODE[2], true))
			_loop.tween_interval(2.6)
		Lesson.SHELL:
			_loop.tween_callback(_scene)
			_loop.tween_interval(1.0)
			_loop.tween_callback(_swap.bind(1, 3))
			_loop.tween_interval(2.8)

## Reduce-motion: the lesson's result, standing still.
func _still() -> void:
	match lesson:
		Lesson.SEAT:
			for k in 3:
				_place(0, k, k)
			_caption.text = tr("HTP_CB_SEAT_CAP")
		Lesson.SCORE:
			_check(0, 1, 2)
			_lift_lids()
		Lesson.CRACK:
			for s in SEATS:
				_place(2, s, CODE[s])
			_check(2, SEATS, 0)
			_toss_lids()
		Lesson.HINT:
			_drop_in(0, 2, CODE[2], true)
		Lesson.SHELL:
			_swap(1, 3)

# --- the scene each loop starts from ---

func _scene() -> void:
	if is_instance_valid(_stage):
		_stage.free()
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	move_child(_stage, 0)
	_rows = []
	_lids = []
	_code_faces = []
	_chips = []
	_mark = null
	var lids_y := 0.0
	match lesson:
		Lesson.SEAT:
			_row(_room * 0.12, 1.0)
			_palette(_room * 0.62)
			_caption.text = tr("HTP_CB_SEAT_CAP")
		Lesson.SCORE:
			_code(lids_y)
			_row(_room * 0.5, 1.0, GUESS)
			_caption.text = tr("HTP_CB_SCORE_CAP")
		Lesson.CRACK:
			_code(lids_y)
			var y := _p + 22.0
			var small := _p * SMALL
			_row(y, SMALL, [3, 0, 2, 4], Vector2i(0, 3))
			_row(y + small * 1.25, SMALL, [0, 2, 1, 3], Vector2i(2, 2))
			_row(y + small * 2.5 + 8.0, 1.0)
			_caption.text = tr("HTP_CB_CRACK_CAP")
		Lesson.HINT:
			_code(lids_y)
			_row(_room * 0.5, 1.0, [-1, -1, -1, -1])
			_caption.text = tr("HTP_CB_HINT_CAP")
		Lesson.SHELL:
			_code(lids_y)
			_row(_room * 0.5, 1.0, [0, 2, 1, 3], Vector2i(2, 2))
			_caption.text = tr("HTP_CB_SHELL_CAP")

func _seat_x(s: int) -> float:
	return _x0 + (s + 0.5) * _p * PITCH

## A row of sockets at height `y`, at `k` of full size, with `friends`
## seated (-1 empty) and, when `score` is given, its pouch filled.
func _row(y: float, k: float, friends: Array = [-1, -1, -1, -1], score := Vector2i(-1, -1)) -> void:
	var p := _p * k
	var row := {"y": y, "p": p, "sockets": [], "faces": [], "sbs": []}
	for s in SEATS:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(p * 0.22))
		sb.border_width_bottom = maxi(2, int(5.0 * k))
		var socket := Panel.new()
		socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
		socket.add_theme_stylebox_override("panel", sb)
		_stage.add_child(socket)
		socket.material = null
		socket.position = Vector2(_seat_x(s) - p * 0.5, y)
		socket.size = Vector2(p, p)
		socket.pivot_offset = socket.size * 0.5
		row.sockets.append(socket)
		row.sbs.append(sb)
		row.faces.append(null)
	var pouch = CB.Pouch.new()
	_stage.add_child(pouch)
	var pk: float = _p / CB.PIECE_MAX * k
	pouch.fit(pk)
	pouch.position = Vector2(_x0 + SEATS * _p * PITCH + 10.0, y + (p - pouch.size.y) * 0.5)
	if score.x >= 0:
		pouch.set_score(score.x, score.y)
	# Seating and the hint are about seats; an empty pouch there is only a
	# puzzle.
	pouch.visible = lesson not in [Lesson.SEAT, Lesson.HINT]
	row["pouch"] = pouch
	_rows.append(row)
	var g := _rows.size() - 1
	for s in SEATS:
		if friends[s] >= 0:
			_place(g, s, friends[s])
		else:
			_paint(g, s)
	if lesson == Lesson.SHELL and score.x >= 0:
		_mark = CB.SwapMark.new()
		_stage.add_child(_mark)
		_mark.position = Vector2(0.0, y)
		_mark.size = Vector2(size.x, p + 30.0)

## A socket's fill and rim, as the board paints them.
func _paint(g: int, s: int, hinted := false) -> void:
	var sb: StyleBoxFlat = _rows[g].sbs[s]
	var face: Control = _rows[g].faces[s]
	if face != null:
		var v := int(face.get_meta("friend"))
		sb.bg_color = Friends.tile(v).lerp(Friends.colour(v), CB.SEAT_TINT)
		sb.border_color = Color(Friends.colour(v), CB.SEAT_RIM)
	else:
		sb.bg_color = Pal.SURFACE_HI.lerp(Pal.PARCHMENT, 0.6)
		sb.border_color = Pal.LINE
	if hinted:
		sb.set_border_width_all(5)
		sb.border_color = Pal.SUN

## Seats friend `v` at (g, s) with no motion.
func _place(g: int, s: int, v: int) -> Control:
	var row: Dictionary = _rows[g]
	var p: float = row.p
	var face := Friends.make(v, p, Vector2(p, p) * 0.5, p < _p * 0.8)
	face.set_meta("friend", v)
	_stage.add_child(face)
	face.position = Vector2(_seat_x(s) - p * 0.5, row.y)
	if p >= _p * 0.8:
		face.set_idle(true)
	row.faces[s] = face
	_paint(g, s)
	return face

## The code's lids along the top, each over its friend.
func _code(y: float) -> void:
	for s in SEATS:
		var face := Friends.make(CODE[s], _p, Vector2(_p, _p) * 0.5)
		face.visible = false
		_stage.add_child(face)
		face.position = Vector2(_seat_x(s) - _p * 0.5, y)
		_code_faces.append(face)
		var lid = CB.Lid.new()
		_stage.add_child(lid)
		lid.fit(_p)
		lid.position = face.position
		_lids.append(lid)

## SEAT's palette: five chips in a tray.
func _palette(y: float) -> void:
	var n := 5
	var chip := _p * 0.86
	var pitch := chip * 1.18
	var x := (size.x - pitch * (n - 1) - chip) * 0.5
	for i in n:
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", CozyTheme.card(Friends.tile(i), int(chip * 0.24), Color(Friends.colour(i), 0.5), 5, 0))
		_stage.add_child(panel)
		panel.material = null
		panel.position = Vector2(x + i * pitch, y)
		panel.size = Vector2(chip, chip)
		panel.pivot_offset = panel.size * 0.5
		var face := Friends.make(i, chip, Vector2(chip, chip) * 0.5)
		panel.add_child(face)
		_chips.append(panel)

# --- the moves ---

## SEAT: chip `k` is pressed and its friend arcs into seat `k`.
func _seat_from_chip(k: int) -> void:
	var chip: Panel = _chips[k]
	Motion.press(chip, true)
	var release := chip.create_tween()
	release.tween_interval(Motion.PRESS_TIME)
	release.tween_callback(func() -> void: Motion.press(chip, false))
	var face := _place(0, k, k)
	var to := face.position
	var from := chip.position + (chip.size - face.size) * 0.5
	_fly(face, from, to)
	_caption.text = tr("HTP_CB_SEAT_CAP")

## SEAT: the friend in seat `s` is tapped and hops back to its chip.
func _send_back(s: int) -> void:
	var face: Control = _rows[0].faces[s]
	if face == null:
		return
	var socket: Panel = _rows[0].sockets[s]
	Motion.press(socket, true)
	var release := socket.create_tween()
	release.tween_interval(Motion.PRESS_TIME)
	release.tween_callback(func() -> void: Motion.press(socket, false))
	_rows[0].faces[s] = null
	_paint(0, s)
	var chip: Panel = _chips[int(face.get_meta("friend"))]
	var tw := _fly(face, face.position, chip.position + (chip.size - face.size) * 0.5)
	if tw != null:
		tw.tween_callback(face.queue_free)
	_caption.text = tr("HTP_CB_BACK_CAP")

func _fly(face: Control, from: Vector2, to: Vector2) -> Tween:
	face.position = from
	var step := func(u: float) -> void:
		face.position = from.lerp(to, u) - Vector2(0.0, FLY_ARC * sin(PI * u))
	var tw := face.create_tween()
	tw.tween_method(step, 0.0, 1.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw

## A friend comes into (g, s): from below on CRACK, from the lid above on
## HINT, where the seat then takes the sun rim and a ring pulses out.
func _drop_in(g: int, s: int, v: int, hinted: bool) -> void:
	var face := _place(g, s, v)
	if hinted:
		_paint(g, s, true)
		face.expression = Face.Expr.JOY
		_caption.text = tr("HTP_CB_HINT_DONE")
	if Motion.reduce:
		return
	if hinted:
		Motion.drop_in(face)
	else:
		Motion.pop_in(face, Motion.POP_IN)

## The row is checked: its friends squash, the pouch takes `exact` filled
## pips and `colour` rings.
func _check(g: int, exact: int, colour: int) -> void:
	var row: Dictionary = _rows[g]
	for face in row.faces:
		if face != null and not Motion.reduce:
			Motion.squash(face, CB.CHECK_SQUASH, CB.CHECK_SQUASH_TIME)
	var pouch = row.pouch
	pouch.set_score(exact, colour)
	pouch.reveal_from(0.15)
	_caption.text = tr("HTP_CB_SCORE_READ") if lesson == Lesson.SCORE else tr("HTP_CB_CRACK_DONE")
	if exact == SEATS:
		for face in row.faces:
			face.expression = Face.Expr.JOY

## SCORE: the lids lift off the code that scored the row.
func _lift_lids() -> void:
	for s in SEATS:
		_code_faces[s].visible = true
		var lid: Control = _lids[s]
		if Motion.reduce:
			lid.visible = false
			continue
		var tw := lid.create_tween().set_parallel()
		tw.tween_property(lid, "position:y", lid.position.y - _p * 0.5, 0.4).set_delay(s * 0.08).set_trans(Tween.TRANS_SINE)
		tw.tween_property(lid, "modulate:a", 0.0, 0.4).set_delay(s * 0.08)
	_caption.text = tr("HTP_CB_SCORE_CODE")

## CRACK: the lids are tossed off and the code beams.
func _toss_lids() -> void:
	for s in SEATS:
		var face: Control = _code_faces[s]
		face.visible = true
		face.expression = Face.Expr.JOY
		var lid: Control = _lids[s]
		if Motion.reduce:
			lid.visible = false
			continue
		var tw := lid.create_tween().set_parallel()
		var d := s * 0.1
		tw.tween_property(lid, "position", lid.position + Vector2((s - 1.5) * 40.0, -_p * 0.9), 0.5).set_delay(d).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(lid, "rotation", (s - 1.5) * 0.6, 0.5).set_delay(d)
		tw.tween_property(lid, "modulate:a", 0.0, 0.5).set_delay(d)
		Motion.hop(face, -16.0, Motion.HOP_TIME, 0.5 + d, face.position.y)

## SHELL: lids `a` and `b` hop past each other, one high and one low, and
## the arc under the played row draws on.
func _swap(a: int, b: int) -> void:
	var la: Control = _lids[a]
	var lb: Control = _lids[b]
	var pa := la.position
	var pb := lb.position
	_mark.set_pair(_seat_x(a), _seat_x(b), not Motion.reduce)
	_caption.text = tr("HTP_CB_SHELL_DONE")
	if Motion.reduce:
		la.position = pb
		lb.position = pa
		return
	for pair: Array in [[la, pa, pb, CB.SWAP_HIGH], [lb, pb, pa, -CB.SWAP_LOW]]:
		var lid: Control = pair[0]
		var from: Vector2 = pair[1]
		var to: Vector2 = pair[2]
		var lift: float = pair[3]
		lid.z_index = 1 if lift > 0.0 else 0
		var step := func(u: float) -> void:
			lid.position = from.lerp(to, u) - Vector2(0.0, lift * 0.6 * sin(PI * u))
		var tw := lid.create_tween()
		tw.tween_method(step, 0.0, 1.0, CB.SWAP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
