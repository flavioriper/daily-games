extends VBoxContainer

## Streak: the current run huge beside a flame, the totals and rest days in a
## list beside it, today's three hearts, and a month calendar that is the
## history.
## Spec: docs/superpowers/specs/2026-09-24-stats-streak-design.md, section 4;
## redrawn 2026-09-25 to the user's mock: a painted picture set into the side
## of the run's card and today's, a best/days/solved list (plus rest days,
## which the mock left out and the user kept), and a calendar of paper tiles
## with the neighbouring months' days greyed in.
## Redrawn on 2026-09-28 as a garden: every week of the calendar is a soil
## bed and every day a plant in it that grows with that day's boards -- a
## sprout for one, a bud for two, a flower for three (the day kept) -- with a
## fallen leaf on a rest day, a sun glow round today and a legend under it.
## The run's number, its flame and "day streak" stand centred as one group.
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
const SheetParts = preload("res://ui/hud/sheet_parts.gd")
const Face = preload("res://ui/faces/face.gd")

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
const CHEVRON := 64.0
## The pictures set into the right of the run's card and today's.
const STREAK_ART_W := 220.0
const TODAY_ART_W := 250.0
const ART_R := 26.0
const LIST_ROW := 62.0
## The run's own column, left of the divider.
const RUN_W := 260.0
## The calendar: where the day rows start, the tallest a row may be, and
## the legend's strip under them.
const CAL_TOP := 140.0
const ROW_MAX := 118.0
const LEGEND_H := 60.0
## The garden's colours: a bed's soil, its darker lip, a plant's mound, and
## the flower's petals.
const BED := Color("efe3cc")
const BED_LIP := Color("dcc7a2")
const MOUND := Color("c9a77a")
const PETAL := Color("ef8a68")
const BUD := Color("f3a58c")
const SPECK := Color("e0cfb0")
const GRASS := Color("a9c47c")
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
var _cal_keep: ArrayMesh
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
	_props(_streak_ci.get_child(0), _draw_signpost)
	var today_art := _side_art(_today_ci, Vistas.TODAY, TODAY_ART_W)
	_props(today_art, _draw_rock)
	var sprout := SproutFace.new()
	sprout.size = Vector2(92, 92)
	sprout.set_anchors_preset(Control.PRESET_CENTER)
	sprout.offset_left = 10
	sprout.offset_right = 102
	sprout.offset_top = -50
	sprout.offset_bottom = 42
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

## A layer drawn over one of the side pictures, the mock's props: the
## vistas are the user's paintings, and what the mock stands in them is
## drawn here in the cast's own palette rather than painted in.
func _props(plate: Control, painter: Callable) -> void:
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.clip_contents = true
	layer.draw.connect(painter.bind(layer))
	plate.add_child(layer)

static func _oval(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

## A rounded rock rising out of the picture's bottom edge: a warm stone
## dome, a sunlit cap on its upper left and a cool shade along its foot.
static func _boulder(ci: Control, c: Vector2, rx: float, ry: float) -> void:
	var dome := _oval(c, rx, ry)
	ci.draw_colored_polygon(dome, Pal.ROCK)
	# A polygon has no antialiasing of its own; a feather in its colour does.
	dome.append(dome[0])
	ci.draw_polyline(dome, Pal.ROCK, 1.5, true)
	ci.draw_colored_polygon(_oval(c + Vector2(-rx * 0.18, -ry * 0.28), rx * 0.66, ry * 0.6), Pal.ROCK.lightened(0.3))
	ci.draw_colored_polygon(_oval(c + Vector2(rx * 0.1, ry * 0.55), rx * 0.95, ry * 0.3), Color(Pal.SHADOW_TINT, 0.35))

## A small flower: five petals round a pale eye.
static func _flower(ci: Control, c: Vector2, r: float, col: Color) -> void:
	for i in 5:
		var a := TAU * i / 5.0 - PI * 0.5
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.62, r * 0.48, col, true, -1.0, true)
	ci.draw_circle(c, r * 0.36, Pal.SUN_RAY, true, -1.0, true)

## The run's card: a wooden sign with a heart on it, on a rock among
## flowers, as the mock stands it.
func _draw_signpost(ci: Control) -> void:
	var w := ci.size.x
	var h := ci.size.y
	var foot := Vector2(w * 0.6, h - 30.0)
	_boulder(ci, Vector2(foot.x - 10, h + 10), 96, 50)
	ci.draw_rect(Rect2(foot + Vector2(-9, -128), Vector2(18, 132)), Pal.PLAQUE_DEEP)
	var board := Rect2(foot + Vector2(-72, -150), Vector2(144, 88))
	var sign := CozyTheme.card(Pal.PLAQUE, 14, Pal.PLAQUE_DEEP, 8, 0)
	sign.shadow_color = Color(0.25, 0.15, 0.08, 0.25)
	sign.shadow_size = 6
	sign.shadow_offset = Vector2(0, 4)
	ci.draw_style_box(sign, board)
	Icons.paint(ci, "heart", Rect2(board.get_center() - Vector2(26, 28), Vector2(52, 52)), Pal.FLOWER_TILE)
	_flower(ci, foot + Vector2(-88, -8), 16, Pal.SURFACE)
	_flower(ci, foot + Vector2(78, -2), 18, Pal.FLOWER_TILE)
	_flower(ci, foot + Vector2(104, -34), 13, Pal.SURFACE)

## Today's card: the rock the sprout sits on, and a flower beside it.
func _draw_rock(ci: Control) -> void:
	var c := Vector2(ci.size.x * 0.5 + 56.0, ci.size.y + 8.0)
	_boulder(ci, c, 70, 34)
	_flower(ci, c + Vector2(84, -26), 13, Pal.SURFACE)

func _chevron(icon: String, step: int) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = Vector2(CHEVRON, CHEVRON)
	b.size = Vector2(CHEVRON, CHEVRON)
	var up := CozyTheme.lifted(Pal.SURFACE, int(CHEVRON * 0.5), 0)
	up.shadow_size = 6
	up.shadow_offset = Vector2(0.0, 3.0)
	up.set_border_width_all(2)
	up.border_color = Color(Pal.LINE, 0.3)
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
	# The flame and the number as one group centred over "day streak", and
	# the pill centred under both, all in the run's own column.
	var num := str(cur)
	var num_size := Ink.fit(_big, num, 140, RUN_W - 130.0)
	var nw := _big.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, num_size).x
	var fw := 96.0
	var gx := (RUN_W - (fw + 14.0 + nw)) * 0.5
	var flame := Rect2(gx, 20, fw, 124)
	if going:
		Icons.paint(ci, "flame", flame, Pal.ACCENT_2, Pal.SUN_RAY)
	else:
		Icons.paint(ci, "flame", flame, Color(Pal.ACCENT_2, 0.28), Pal.SURFACE)
	Ink.text(ci, _big, num, Vector2(gx + fw + 14.0, 136), num_size, Pal.ACCENT_2 if going else Pal.TEXT_DIM)
	var days := tr("STREAK_DAYS")
	Ink.text(ci, _head, days, Vector2(RUN_W * 0.5, 190), Ink.fit(_head, days, 32, RUN_W - 20.0), Pal.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var pill_line := tr("STATS_KEEP_GOING" if going else "STATS_START_STREAK")
	var pill_size := Ink.fit(_body, pill_line, 28, RUN_W - 100.0)
	var pw := _body.get_string_size(pill_line, HORIZONTAL_ALIGNMENT_LEFT, -1, pill_size).x + 86
	var pill := Rect2((RUN_W - pw) * 0.5, h - 64, pw, 56)
	ci.draw_style_box(CozyTheme.card(Pal.SUN_TILE, 28, Pal.LINE, 0, 0), pill)
	Icons.paint(ci, "sparkle", Rect2(pill.position + Vector2(18, 12), Vector2(32, 32)), Pal.SUN)
	Ink.text(ci, _body, pill_line, pill.position + Vector2(62, 38), pill_size, Pal.ACCENT_2)
	var div := RUN_W + 18.0
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
			# A rest day held is a leaf in green; one not yet earned, a pale one.
			for k in Streak.REST_CAP:
				var c := Vector2(right - 16 - (Streak.REST_CAP - 1 - k) * 40, cy)
				var col: Color = Pal.LEAF if k < int(_st.rest) else Color(Pal.LINE, 0.4)
				Icons.paint(ci, "leaf", Rect2(c - Vector2(17, 17), Vector2(34, 34)), col)

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

## The month as a garden: a soil bed for each week, only as long as the
## month's days in it, and a plant on every day that has been. The beds, the
## plants, today's glow and the legend's plants are one mesh, built when
## the calendar repaints (a month turn, a refresh, a resize); the numbers
## and the words are text over it.
func _draw_calendar(ci: Control) -> void:
	if _month == 0:
		return
	var w := ci.size.x
	var h := ci.size.y
	var y := _month / 100
	var m := _month % 100
	Ink.text(ci, _head, "%s %d" % [tr("MONTH_%d" % m), y], Vector2(w * 0.5, 46), 42, Pal.TEXT,
		HORIZONTAL_ALIGNMENT_CENTER)
	var names := tr("WEEKDAY_SHORT").split(" ")
	var cw := w / 7.0
	for i in 7:
		var name: String = names[i] if i < names.size() else ""
		Ink.text(ci, _body, name, Vector2(cw * (i + 0.5), 112), 22, Pal.TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	# Monday-first column of the 1st: Godot's weekday is 0 = Sunday.
	var first := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_dict(
		{"year": y, "month": m, "day": 1, "hour": 12})))
	var lead := (int(first.weekday) + 6) % 7
	var in_month := _days_in(_month)
	var rows := int(ceil((lead + in_month) / 7.0))
	var row_h := minf(ROW_MAX, (h - CAL_TOP - LEGEND_H) / rows)
	var b := Face.Builder.new()
	var labels: Array = []
	for row in rows:
		var top := CAL_TOP + row * row_h
		var c0 := maxi(0, lead - row * 7)
		var c1 := mini(6, lead + in_month - 1 - row * 7)
		var bed := Rect2(c0 * cw + 6.0, top + 40.0, (c1 - c0 + 1) * cw - 12.0, row_h - 44.0)
		_bed(b, bed)
		for col in range(c0, c1 + 1):
			var d := row * 7 + col - lead + 1
			var key := y * 10000 + m * 100 + d
			var cell := Rect2(col * cw, top, cw, row_h)
			labels.append(_day(b, cell, bed, key))
	var ly := h - LEGEND_H * 0.5
	var legend := _legend(b, w, ly)
	_cal_keep = b.mesh()
	ci.draw_mesh(_cal_keep, null)
	for l in labels:
		Ink.text(ci, l[0], l[1], l[2], l[3], l[4], HORIZONTAL_ALIGNMENT_CENTER)
	for l in legend:
		Ink.text(ci, _body, l[0], l[1], 22, Pal.TEXT_DIM)

## A week's bed: a rounded strip of soil with a darker lip along its foot,
## a few specks of earth in it and a fringe of grass along its top edge.
func _bed(b: Face.Builder, r: Rect2) -> void:
	b.polygon(_rounded(r, 18.0), BED_LIP)
	b.polygon(_rounded(Rect2(r.position, r.size - Vector2(0, 6)), 18.0), BED)
	var i := 0
	var x := r.position.x + 20.0
	while x < r.end.x - 20.0:
		# Fixed pseudo-random, so the garden looks the same every repaint.
		var j := fposmod(sin(i * 12.9898 + r.position.y * 0.37) * 43758.5453, 1.0)
		var sy := r.position.y + 12.0 + j * maxf(r.size.y - 34.0, 1.0)
		b.disc(Vector2(x + j * 9.0, sy), 1.8 + j * 1.2, SPECK)
		x += 23.0
		i += 1
	x = r.position.x + 14.0
	i = 0
	while x < r.end.x - 14.0:
		var j := fposmod(sin(i * 78.233 + r.position.x * 0.11) * 12345.678, 1.0)
		var tall := 4.0 + j * 5.0
		var lean := (j - 0.5) * 6.0
		b.polygon(PackedVector2Array([Vector2(x - 3.0, r.position.y + 3.0),
			Vector2(x + lean, r.position.y - tall), Vector2(x + 3.0, r.position.y + 3.0)]), GRASS)
		x += 9.0 + j * 6.0
		i += 1

static func _rounded(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var corners := [r.position + Vector2(r.size.x - rad, rad), r.end - Vector2(rad, rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for k in 4:
		for i in 7:
			var a := -PI * 0.5 + (k + i / 6.0) * PI * 0.5
			pts.append(corners[k] + Vector2(cos(a), sin(a)) * rad)
	return pts

## One day: what grows in its bed by what the streak made of it, and its
## number over it -- returned as a text label for after the mesh.
func _day(b: Face.Builder, cell: Rect2, bed: Rect2, key: int) -> Array:
	var n := Streak.hearts(_log.get(key, []))
	var status := String(_st.days.get(key, ""))
	var today := key == _today
	var future := key > _today
	var cx := cell.get_center().x
	var foot := Vector2(cx, bed.end.y - 14.0)
	# The tallest plant (the flower, ~62 at full size) fits the bed's height.
	var s := clampf((bed.size.y - 16.0) / 62.0, 0.45, 1.0)
	if today:
		# A sun glow round today's whole cell, and a ring over it.
		var glow := cell.grow(-4.0)
		b.polygon(_rounded(glow, 22.0), Color(Pal.SUN_TILE, 0.95))
		var ring := _rounded(glow, 22.0)
		ring.append(ring[0])
		b.stroke(ring, 3.0, Pal.ACCENT_2, false, false)
		_bed_patch(b, bed, cell)
	if not future:
		var stage := 3 if status == "kept" else n
		if status == "rest":
			_mound(b, foot, s, Color(Pal.LEAF_TILE.darkened(0.12)))
			SheetParts.Draw.leaf(b, foot + Vector2(-16, -4) * s, foot + Vector2(18, -10) * s, 14.0 * s, Pal.LEAF)
		else:
			_mound(b, foot, s, Color(MOUND, 0.55 if stage == 0 and status == "" else 1.0))
			_plant(b, foot, stage, s)
	var col: Color = Pal.TEXT
	if future:
		col = Color(Pal.TEXT_DIM, 0.45)
	elif today:
		col = Pal.ACCENT_2
	return [_head if today else _body, str(key % 100), Vector2(cx, cell.position.y + 25.0), 22, col]

## Today's glow runs under its bed; a patch of soil puts the bed back over it.
func _bed_patch(b: Face.Builder, bed: Rect2, cell: Rect2) -> void:
	var r := Rect2(maxf(bed.position.x, cell.position.x + 4.0), bed.position.y,
		minf(bed.end.x, cell.end.x - 4.0) - maxf(bed.position.x, cell.position.x + 4.0), bed.size.y - 6.0)
	b.polygon(_rounded(r, 14.0), BED)

func _mound(b: Face.Builder, foot: Vector2, s: float, col: Color) -> void:
	b.ellipse(foot + Vector2(0, 3) * s, 22.0 * s, 8.0 * s, col)

## A plant at `stage`: nothing for none, a sprout for one board, a bud on a
## leafy stem for two, and a flower for three.
func _plant(b: Face.Builder, foot: Vector2, stage: int, s: float) -> void:
	if stage <= 0:
		return
	var Draw = SheetParts.Draw
	var tall: float = [0.0, 14.0, 28.0, 34.0][mini(stage, 3)] * s
	var top := foot + Vector2(0, -tall)
	b.stroke(PackedVector2Array([foot, top]), 3.0 * s, Pal.LEAF_DEEP)
	var leaf_at := foot + Vector2(0, -minf(tall, 12.0 * s))
	var leaf := 16.0 * s
	Draw.leaf(b, leaf_at, leaf_at + Vector2(-leaf, -leaf * 0.6), leaf * 0.55, Pal.LEAF)
	Draw.leaf(b, leaf_at, leaf_at + Vector2(leaf, -leaf * 0.7), leaf * 0.55, Pal.LEAF)
	match stage:
		2:
			b.ellipse(top + Vector2(0, -6) * s, 7.0 * s, 10.0 * s, BUD)
			Draw.leaf(b, top + Vector2(0, 2) * s, top + Vector2(-7, -6) * s, 6.0 * s, Pal.LEAF_DEEP)
			Draw.leaf(b, top + Vector2(0, 2) * s, top + Vector2(7, -6) * s, 6.0 * s, Pal.LEAF_DEEP)
		3:
			var head := top + Vector2(0, -8) * s
			for i in 5:
				var a := TAU * i / 5.0 - PI * 0.5
				b.disc(head + Vector2(cos(a), sin(a)) * 9.0 * s, 8.0 * s, PETAL)
			b.disc(head, 6.0 * s, Pal.SUN_RAY)

## The legend under the month: "Boards a day:" and the three plants with
## their counts, then the fallen leaf for a rest day. Returns its words.
func _legend(b: Face.Builder, w: float, y: float) -> Array:
	var out: Array = []
	var lead := tr("STREAK_LEGEND")
	var rest := tr("STREAK_REST_SHORT")
	var item := 70.0
	var lead_w := _body.get_string_size(lead, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var rest_w := _body.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var total := lead_w + 16.0 + item * 3.0 + 20.0 + 40.0 + rest_w
	var x := (w - total) * 0.5
	out.append([lead, Vector2(x, y + 8.0)])
	x += lead_w + 16.0
	for stage in [1, 2, 3]:
		var foot := Vector2(x + 18.0, y + 14.0)
		_mound(b, foot, 0.7, MOUND)
		_plant(b, foot, stage, 0.7)
		out.append([str(stage), Vector2(x + 40.0, y + 8.0)])
		x += item
	x += 20.0
	var foot := Vector2(x + 16.0, y + 14.0)
	_mound(b, foot, 0.7, Pal.LEAF_TILE.darkened(0.12))
	SheetParts.Draw.leaf(b, foot + Vector2(-11, -3), foot + Vector2(13, -7), 10.0, Pal.LEAF)
	out.append([rest, Vector2(x + 40.0, y + 8.0)])
	return out

func _days_in(ym: int) -> int:
	var y := ym / 100
	var m := ym % 100
	if m == 2:
		return 29 if (y % 4 == 0 and y % 100 != 0) or y % 400 == 0 else 28
	return 30 if m in [4, 6, 9, 11] else 31
