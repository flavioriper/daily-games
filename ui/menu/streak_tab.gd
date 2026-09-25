extends VBoxContainer

## Streak: the current run huge beside a flame, the totals and rest days in a
## list beside it, today's three hearts, and a month calendar that is the
## history.
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4;
## redrawn 2026-09-25 to the user's mock: a painted picture set into the side
## of the run's card and today's, a best/days/solved list (plus rest days,
## which the mock left out and the user kept), and a calendar of paper tiles
## with the neighbouring months' days greyed in.
## Every figure is derived (core/streak.gd); refresh() re-reads the log.

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Progress = preload("res://core/progress.gd")
const Streak = preload("res://core/streak.gd")
const PlayerStats = preload("res://core/player_stats.gd")
const Ink = preload("res://ui/menu/ink.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")

const GAP := 20
const PAD := 20
const STREAK_H := 300.0
const TODAY_H := 150.0
const RADIUS := 36
## The card's paper: a shade warmer than SURFACE, so the calendar's day tiles
## (SURFACE) stand off it the way the mock's white tiles do.
const FILL := Color("fcf7ef")
const HEART := 62.0
const HEART_STEP := 74.0
const CHEVRON := 76.0
## The pictures set into the right of the run's card and today's.
const STREAK_ART_W := 300.0
const TODAY_ART_W := 250.0
const ART_R := 26.0
const LIST_ROW := 62.0
const TILE_GAP := 10.0
## The mocks' paper is clean: a plain material keeps CozyTheme.dress()'s
## painterly wash, which blotches a card this large, off these cards.
static var PLAIN := CanvasItemMaterial.new()

var _log := {}
var _today := 0
var _st := {}
var _sum := {}
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
	_side_art(_streak_ci, Vistas.STREAK, STREAK_ART_W)
	_today_ci = _card(TODAY_H, _draw_today)
	var today_art := _side_art(_today_ci, Vistas.TODAY, TODAY_ART_W)
	var sprout := SproutFace.new()
	sprout.size = Vector2(92, 92)
	sprout.set_anchors_preset(Control.PRESET_CENTER)
	sprout.offset_left = 10
	sprout.offset_right = 102
	sprout.offset_top = -40
	sprout.offset_bottom = 52
	today_art.add_child(sprout)
	_cal_ci = _card(0.0, _draw_calendar)
	_cal_ci.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	_prev = _chevron("chevron_left", -1)
	_prev.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_next = _chevron("chevron_right", 1)
	_next.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_next.offset_left = -CHEVRON

func _card(h: float, painter: Callable) -> Control:
	var card := PanelContainer.new()
	var box := CozyTheme.lifted(FILL, RADIUS, PAD)
	card.add_theme_stylebox_override("panel", box)
	card.material = PLAIN
	card.custom_minimum_size.y = h
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	var ci := Control.new()
	ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ci.draw.connect(painter.bind(ci))
	card.add_child(ci)
	return ci

## A painted plate down the right edge of `ci`, `w` wide, washed into the
## card's paper on its left (one draw call).
func _side_art(ci: Control, row: Array, w: float) -> Control:
	var plate := Vistas.side_plate(row, ART_R, FILL)
	plate.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	plate.offset_left = -w
	plate.offset_right = 0
	plate.offset_top = 0
	plate.offset_bottom = 0
	ci.add_child(plate)
	return plate

func _chevron(icon: String, step: int) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	b.size = Vector2(CHEVRON, CHEVRON)
	var up := CozyTheme.lifted(Pal.SUN_TILE, 22, 0)
	up.shadow_size = 6
	up.shadow_offset = Vector2(0.0, 3.0)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, up)
	b.pressed.connect(func() -> void: _turn_month(step))
	_cal_ci.add_child(b)
	return b

func refresh() -> void:
	_log = Progress.solve_log()
	_today = Daily.date_key()
	_st = Streak.compute(_log, _today)
	_sum = PlayerStats.summary(_log)
	_month = _today / 100
	_first_month = int(_st.first) / 100 if int(_st.first) > 0 else _month
	_repaint()

func _turn_month(step: int) -> void:
	_month = clampi(_shift(_month, step), _first_month, _today / 100)
	_repaint()

## The yyyymm `step` months from `ym`.
func _shift(ym: int, step: int) -> int:
	var y := ym / 100
	var m := ym % 100 + step
	if m < 1:
		m = 12
		y -= 1
	elif m > 12:
		m = 1
		y += 1
	return y * 100 + m

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

func _divider(ci: Control, x: float) -> void:
	ci.draw_line(Vector2(x, 16), Vector2(x, ci.size.y - 16), Color(Pal.LINE, 0.3), 2.0, true)

# --- the run ---

func _draw_streak(ci: Control) -> void:
	if _st.is_empty():
		return
	var h := ci.size.y
	var cur := int(_st.current)
	var going := cur > 0
	# The flame and the number, "day streak" under the number, and the pill.
	var flame := Rect2(0, 18, 120, 150)
	if going:
		Icons.paint(ci, "flame", flame, Pal.ACCENT_2, Pal.SUN_RAY)
	else:
		Icons.paint(ci, "flame", flame, Color(Pal.LINE, 0.55), Pal.SURFACE_HI)
	var num := str(cur)
	var num_size := Ink.fit(_big, num, 150, 170)
	Ink.text(ci, _big, num, Vector2(122, 140), num_size, Pal.ACCENT_2 if going else Pal.TEXT_DIM)
	var days := tr("STREAK_DAYS")
	Ink.text(ci, _head, days, Vector2(122, 186), Ink.fit(_head, days, 34, 186), Pal.TEXT)
	var pill_line := tr("STATS_KEEP_GOING" if going else "STATS_START_STREAK")
	var pill_size := Ink.fit(_body, pill_line, 28, 210)
	var pw := _body.get_string_size(pill_line, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_size).x + 86
	var pill := Rect2(20, h - 66, pw, 56)
	ci.draw_style_box(CozyTheme.card(Pal.SUN_TILE, 28, Pal.LINE, 0, 0), pill)
	Icons.paint(ci, "sparkle", Rect2(pill.position + Vector2(18, 12), Vector2(32, 32)), Pal.SUN)
	Ink.text(ci, _body, pill_line, pill.position + Vector2(62, 38), pill_size, Pal.ACCENT_2)
	var div := 318.0
	_divider(ci, div)
	# The list: best, days, solved, and the rest days held.
	var x := div + 26.0
	var right := ci.size.x - STREAK_ART_W - 20.0
	var rows := [
		["crown", Pal.SUN, "STREAK_BEST_STREAK", str(int(_st.best))],
		["calendar", Pal.ACCENT_2, "STREAK_TOTAL_DAYS", str(int(_sum.get("days", 0)))],
		["bars", Pal.ACCENT_2, "STREAK_SOLVED", str(int(_sum.get("solved", 0)))],
		["leaf", Pal.LEAF, "STREAK_REST", ""],
	]
	var top := (h - LIST_ROW * rows.size()) * 0.5
	for i in rows.size():
		var cy := top + LIST_ROW * (i + 0.5)
		Icons.paint(ci, rows[i][0], Rect2(x, cy - 16, 32, 32), rows[i][1])
		var label := tr(rows[i][2])
		var room := right - (x + 46) - (84.0 if i == 3 else 50.0)
		Ink.text(ci, _body, label, Vector2(x + 46, cy + 10), Ink.fit(_body, label, 26, room), Pal.TEXT_DIM)
		if i < 3:
			Ink.text(ci, _head, rows[i][3], Vector2(right, cy + 12), 34, Pal.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
		else:
			for k in Streak.REST_CAP:
				var c := Vector2(right - 14 - (Streak.REST_CAP - 1 - k) * 34, cy)
				if k < int(_st.rest):
					ci.draw_circle(c, 14, Pal.LEAF, true, -1.0, true)
				else:
					ci.draw_arc(c, 12, 0, TAU, 32, Pal.LINE, 3, true)

# --- today ---

func _draw_today(ci: Control) -> void:
	var n := Streak.hearts(_log.get(_today, []))
	Ink.text(ci, _head, tr("TODAY_TITLE"), Vector2(8, 30), 30, Pal.TEXT)
	for i in Streak.KEPT:
		var box := Rect2(Vector2(4 + i * HEART_STEP, 44), Vector2(HEART, HEART))
		if i < n:
			Icons.paint(ci, "heart", box, Pal.HEART)
		else:
			Icons.paint(ci, "heart_line", box.grow(-3), Pal.LINE)
	var div := 4 + Streak.KEPT * HEART_STEP + 12.0
	_divider(ci, div)
	var x := div + 30.0
	var room := ci.size.x - TODAY_ART_W - 20.0 - x
	var line := tr("TODAY_LINE_%d" % n)
	Ink.text(ci, _body, line, Vector2(x, 44), Ink.fit(_body, line, 28, room), Pal.TEXT)
	var seg := (room - 2 * 12.0) / Streak.KEPT
	for i in Streak.KEPT:
		var r := Rect2(x + i * (seg + 12.0), 70, seg, 24)
		ci.draw_style_box(CozyTheme.card(Color(Pal.ACCENT_2, 0.8) if i < n else Pal.SURFACE_HI, 12, Pal.LINE, 0, 0), r)

# --- the month ---

func _draw_calendar(ci: Control) -> void:
	if _month == 0:
		return
	var w := ci.size.x
	var h := ci.size.y
	var y := _month / 100
	var m := _month % 100
	Ink.text(ci, _head, "%s %d" % [tr("MONTH_%d" % m), y], Vector2(w * 0.5, 52), 44, Pal.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var names := tr("WEEKDAY_SHORT").split(" ")
	var cw := w / 7.0
	for i in 7:
		var name: String = names[i] if i < names.size() else ""
		Ink.text(ci, _body, name, Vector2(cw * (i + 0.5), 124), 24, Pal.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# Monday-first column of the 1st: Godot's weekday is 0 = Sunday.
	var first := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_dict(
		{"year": y, "month": m, "day": 1, "hour": 12})))
	var lead := (int(first.weekday) + 6) % 7
	var in_month := _days_in(_month)
	var rows := int(ceil((lead + in_month) / 7.0))
	var top := 146.0
	var row_h := minf(120.0, (h - top) / rows)
	var prev_days := _days_in(_shift(_month, -1))
	for cell in rows * 7:
		var r := Rect2(cw * (cell % 7) + TILE_GAP * 0.5, top + row_h * (cell / 7) + TILE_GAP * 0.5,
			cw - TILE_GAP, row_h - TILE_GAP)
		var d := cell - lead + 1
		if d < 1 or d > in_month:
			# A neighbouring month's day: a grey tile, its number faint.
			var other := prev_days + d if d < 1 else d - in_month
			ci.draw_style_box(CozyTheme.card(Color(Pal.SURFACE_HI, 0.55), 16, Pal.LINE, 0, 0), r)
			Ink.text(ci, _body, str(other), r.get_center() + Vector2(0, 9), 26, Color(Pal.LINE, 0.7),
				HORIZONTAL_ALIGNMENT_CENTER)
			continue
		_draw_day(ci, r, y * 10000 + m * 100 + d)

## One day of the month on show, by what the streak made of it.
func _draw_day(ci: Control, r: Rect2, key: int) -> void:
	var c := r.get_center()
	var day := str(key % 100)
	var n := Streak.hearts(_log.get(key, []))
	var status := String(_st.days.get(key, ""))
	var mark := Rect2(c + Vector2(-13, 8), Vector2(26, 26))
	match status:
		"kept":
			ci.draw_style_box(CozyTheme.card(Pal.ACCENT_2, 18, Pal.ACCENT_2.darkened(0.15), 4, 0), r)
			Ink.text(ci, _body, day, c + Vector2(0, -4), 26, Pal.SURFACE, HORIZONTAL_ALIGNMENT_CENTER)
			Icons.paint(ci, "check", mark, Pal.SURFACE)
		"rest":
			ci.draw_style_box(CozyTheme.card(Pal.LEAF_TILE, 18, Pal.LINE, 0, 0), r)
			Ink.text(ci, _body, day, c + Vector2(0, -4), 26, Pal.LEAF_DEEP, HORIZONTAL_ALIGNMENT_CENTER)
			Icons.paint(ci, "leaf", mark, Pal.LEAF_DEEP)
		_:
			var today := key == _today
			var future := key > _today
			var fill: Color = Pal.SUN_TILE if today else Color(Pal.SURFACE, 0.6 if future else 1.0)
			var box := CozyTheme.card(fill, 18, Pal.LINE, 0, 0)
			if today:
				box.set_border_width_all(4)
				box.border_color = Pal.ACCENT_2
			ci.draw_style_box(box, r)
			var col: Color = Color(Pal.TEXT_DIM, 0.45) if future else Pal.TEXT
			if n > 0:
				# A partial day (or today, started): its count under the number.
				Ink.text(ci, _body, day, c + Vector2(0, -4), 26, col, HORIZONTAL_ALIGNMENT_CENTER)
				Ink.text(ci, _body, "%d/3" % n, c + Vector2(0, 30), 20, Pal.ACCENT_2, HORIZONTAL_ALIGNMENT_CENTER)
			elif today:
				Ink.text(ci, _head, day, c + Vector2(0, 13), 36, Pal.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			else:
				Ink.text(ci, _body, day, c + Vector2(0, 9), 26, col, HORIZONTAL_ALIGNMENT_CENTER)

func _days_in(ym: int) -> int:
	var y := ym / 100
	var m := ym % 100
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31
