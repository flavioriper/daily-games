extends VBoxContainer

## Streak: the current run huge, best and rest days beside it, today's three
## hearts, and a month calendar that is the history.
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4.
## Every figure is derived (core/streak.gd); refresh() re-reads the log.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const Ink = preload("res://ui/menu/ink.gd")

const GAP := 20
const STREAK_H := 330.0
const TODAY_H := 190.0
const HEART := 70.0
const HEART_STEP := 86.0
const CHEVRON := 90.0

var _log := {}
var _today := 0
var _st := {}
var _month := 0        # yyyymm on show
var _first_month := 0
var _streak_ci: Control
var _today_ci: Control
var _cal_ci: Control
var _prev: Button
var _next: Button
var _big: Font
var _head: Font
var _body: Font

func _init() -> void:
	add_theme_constant_override("separation", GAP)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_big = CozyTheme.display(700)
	_head = CozyTheme.display(700)
	_body = CozyTheme.body(800)
	_streak_ci = _card(STREAK_H, _draw_streak)
	_today_ci = _card(TODAY_H, _draw_today)
	_cal_ci = _card(0.0, _draw_calendar)
	_cal_ci.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev = _chevron("chevron_left", -1)
	_prev.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_next = _chevron("chevron_right", 1)
	_next.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_next.offset_left = -CHEVRON

func _card(h: float, painter: Callable) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CozyTheme.card(Pal.SURFACE, 36, Pal.LINE, 6, 24))
	card.custom_minimum_size.y = h
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var ci := Control.new()
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ci.draw.connect(painter.bind(ci))
	card.add_child(ci)
	return ci

func _chevron(icon: String, step: int) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	b.size = Vector2(CHEVRON, CHEVRON)
	b.pressed.connect(func() -> void: _turn_month(step))
	_cal_ci.add_child(b)
	return b

func refresh() -> void:
	_log = Progress.solve_log()
	_today = Daily.date_key()
	_st = Streak.compute(_log, _today)
	_month = _today / 100
	_first_month = int(_st.first) / 100 if int(_st.first) > 0 else _month
	_repaint()

func _turn_month(step: int) -> void:
	var y := _month / 100
	var m := _month % 100 + step
	if m < 1:
		m = 12
		y -= 1
	elif m > 12:
		m = 1
		y += 1
	_month = clampi(y * 100 + m, _first_month, _today / 100)
	_repaint()

func _repaint() -> void:
	_prev.disabled = _month <= _first_month
	_next.disabled = _month >= _today / 100
	_prev.modulate.a = 0.35 if _prev.disabled else 1.0
	_next.modulate.a = 0.35 if _next.disabled else 1.0
	_streak_ci.queue_redraw()
	_today_ci.queue_redraw()
	_cal_ci.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _cal_ci != null:
		_repaint()

func _draw_streak(ci: Control) -> void:
	if _st.is_empty():
		return
	var w := ci.size.x
	var cur := int(_st.current)
	Ink.text(ci, _big, str(cur), Vector2(16, 190), 160, Pal.ACCENT_2 if cur > 0 else Pal.TEXT_DIM)
	Ink.text(ci, _body, tr("STREAK_DAYS"), Vector2(22, 252), 38, Pal.TEXT_DIM)
	var x := w * 0.56
	Ink.text(ci, _body, tr("STREAK_BEST"), Vector2(x, 62), 32, Pal.TEXT_DIM)
	Ink.text(ci, _head, str(int(_st.best)), Vector2(w - 8, 66), 46, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	Ink.text(ci, _body, tr("STREAK_REST"), Vector2(x, 140), 32, Pal.TEXT_DIM)
	for i in Streak.REST_CAP:
		var c := Vector2(w - 40 - (Streak.REST_CAP - 1 - i) * 70, 128)
		if i < int(_st.rest):
			ci.draw_circle(c, 30, Pal.LEAF_TILE)
			Icons.paint(ci, "leaf", Rect2(c - Vector2(22, 22), Vector2(44, 44)), Pal.LEAF_DEEP)
		else:
			ci.draw_arc(c, 27, 0, TAU, 40, Pal.LINE, 4, true)
	Ink.text(ci, _body, tr("STREAK_NEXT_REST"), Vector2(x, 222), 28, Pal.TEXT_DIM)
	var step := (w - 20 - x - 16) / float(Streak.EARN - 1)
	for i in Streak.EARN:
		var c := Vector2(x + 16 + i * step, 262)
		if i < int(_st.toward):
			ci.draw_circle(c, 17, Pal.LEAF)
		else:
			ci.draw_arc(c, 15, 0, TAU, 32, Pal.LINE, 4, true)

func _draw_today(ci: Control) -> void:
	var n := Streak.hearts(_log.get(_today, []))
	Ink.text(ci, _body, tr("MENU_TODAY"), Vector2(18, 40), 28, Pal.TEXT_DIM)
	for i in Streak.KEPT:
		var box := Rect2(Vector2(18 + i * HEART_STEP, 62), Vector2(HEART, HEART))
		if i < n:
			Icons.paint(ci, "heart", box, Pal.ACCENT_2)
		else:
			Icons.paint(ci, "heart_line", box, Pal.LINE)
	Ink.text(ci, _body, tr("TODAY_LINE_%d" % n), Vector2(18 + 3 * HEART_STEP + 24, 110), 34, Pal.TEXT)

func _draw_calendar(ci: Control) -> void:
	if _month == 0:
		return
	var w := ci.size.x
	var h := ci.size.y
	var y := _month / 100
	var m := _month % 100
	Ink.text(ci, _head, "%s %d" % [tr("MONTH_%d" % m), y], Vector2(w * 0.5, 62), 46, Pal.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var initials := tr("WEEKDAY_INITIALS")
	var cw := w / 7.0
	for i in 7:
		Ink.text(ci, _body, initials.substr(i, 1), Vector2(cw * (i + 0.5), 136), 28, Pal.TEXT_DIM,
			HORIZONTAL_ALIGNMENT_CENTER)
	# Monday-first column of the 1st: Godot's weekday is 0 = Sunday.
	var first := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_dict(
		{"year": y, "month": m, "day": 1, "hour": 12})))
	var lead := (int(first.weekday) + 6) % 7
	var row_h := minf(112.0, (h - 170.0) / 6.0)
	var r := row_h * 0.36
	var key := y * 10000 + m * 100 + 1
	var cell := lead
	while key / 100 == _month:
		var c := Vector2(cw * (cell % 7 + 0.5), 170 + row_h * (cell / 7 + 0.5))
		var status := String(_st.days.get(key, ""))
		var day := str(key % 100)
		match status:
			"kept":
				ci.draw_circle(c, r, Pal.ACCENT_2)
				Ink.text(ci, _head, day, c + Vector2(0, 11), 32, Pal.SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
			"rest":
				ci.draw_circle(c, r, Pal.LEAF_TILE)
				Icons.paint(ci, "leaf", Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), Pal.LEAF_DEEP)
			"partial":
				ci.draw_arc(c, r - 3, 0, TAU, 40, Pal.ACCENT_2, 5, true)
				var n := Streak.hearts(_log.get(key, []))
				Ink.text(ci, _head, "%d/3" % n, c + Vector2(0, 9), 26, Pal.ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER)
			_:
				var col := Pal.TEXT_DIM
				if key > _today:
					col.a = 0.35
				Ink.text(ci, _head, day, c + Vector2(0, 11), 32, col, HORIZONTAL_ALIGNMENT_CENTER)
		if key == _today:
			ci.draw_arc(c, r + 8, 0, TAU, 48, Pal.TEXT, 5, true)
		key = Streak.next_day(key)
		cell += 1
