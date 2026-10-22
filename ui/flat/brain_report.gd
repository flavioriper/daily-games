extends Control

## The win's brain report: a paper plate over the board's world, between the
## compact art and the bottom rows. What the board trains, the skill's score
## on a ring with today against the player's usual, one tip for next time,
## and all five skills with today's gain. The eye at its top right, held,
## fades the plate so the solved board shows through.
## Spec: docs/superpowers/specs/2026-10-22-brain-skills-design.md, section 5.

const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Icons = preload("res://ui/icons.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Brain = preload("res://core/brain.gd")
const Registry = preload("res://ui/registry.gd")

const RADIUS := 40
const PAD := 36.0
const HEAD_H := 104.0
const SKILL_ICON := 60.0
const EYE := 88.0
const RING := 176.0
const RING_W := 22.0
const SCORE_H := 196.0
const TIP_H := 168.0
const TIP_RADIUS := 28
const BRAIN_LABEL_H := 46.0
## A skill's row, and the least it shrinks to before the rows fold into one.
const ROW_H := 76.0
const ROW_MIN := 52.0
const FOLD_H := 120.0
const ROW_ICON := 44.0
const NAME_W := 230.0
const NUM_W := 90.0
const BAR_H := 18.0
const LOW_H := 44.0
const GAP := 18.0
## The ring and the bars filling, and the plate's entrance.
const FILL := 0.6
const ENTER := 0.35
const PEEK := 0.15

var _report := {}
var _skill := ""
var _colour := Pal.ACCENT
## 0..1 while the ring and the bars fill.
var _t := 1.0
var _row_h := ROW_H
var _folded := false

var _title: Label
var _line: Label
var _score: Label
var _facts: Array[Label] = []
var _tip_head: Label
var _tip: Label
var _brain_head: Label
var _names: Array[Label] = []
var _nums: Array[Label] = []
var _low: Label
var _eye: Button
var _peek_tw: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_title = _label("CardTitle", 40)
	_title.add_theme_font_override("font", CozyTheme.display(700))
	_line = _label("CardBodyDim", 26)
	_score = _label("CardTitle", 64)
	_score.add_theme_font_override("font", CozyTheme.display(700))
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i in 4:
		var f := _label("CardBody", 30)
		_facts.append(f)
	_facts[0].add_theme_font_override("font", CozyTheme.body(800))
	_tip_head = _label("CardBodyDim", 24)
	_tip_head.add_theme_font_override("font", CozyTheme.body(800))
	_tip_head.text = "BRAIN_NEXT_TIME"
	_tip = _label("CardBody", 30)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_brain_head = _label("CardBodyDim", 24)
	_brain_head.add_theme_font_override("font", CozyTheme.body(800))
	_brain_head.text = "BRAIN_YOURS"
	for k in Brain.SKILLS:
		var n := _label("CardBody", 30)
		_names.append(n)
		var v := _label("CardBody", 30)
		v.add_theme_font_override("font", CozyTheme.body(800))
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_nums.append(v)
	_low = _label("CardBodyDim", 26)
	_low.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_eye = IconButton.new("eye", "", "IconButton")
	_eye.name = "PeekButton"
	_eye.size = Vector2(EYE, EYE)
	CozyTheme.lift_button(_eye, Pal.SURFACE, int(EYE * 0.5))
	_eye.button_down.connect(_peek.bind(true))
	_eye.button_up.connect(_peek.bind(false))
	add_child(_eye)
	resized.connect(_layout)

func _label(variation: String, font_size: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## Fills the plate from Brain.report() for board `id`; `seconds` and `hints`
## are this solve's, `q` its quality (-1 for none).
func show_report(id: String, report: Dictionary, seconds: float, hints: int, q: float) -> void:
	_report = report
	_skill = String(report.get("skill", ""))
	_colour = _skill_colour(_skill)
	var board := String(Registry.find(id).get("title", ""))
	_title.text = tr("BRAIN_TRAINS") % [board, tr("SKILL_" + _skill.to_upper())]
	_line.text = "SKILL_%s_LINE" % _skill.to_upper()
	var gain := int(report.get("gain", 0))
	_facts[0].text = ("+%d" % gain if gain > 0 else "−%d" % -gain) if gain != 0 else ""
	# A gain is news in leaf green; a slip is said quietly.
	_facts[0].add_theme_color_override("font_color", Pal.LEAF_DEEP if gain > 0 else Pal.TEXT_DIM)
	var timed := not id in Brain.UNTIMED
	if bool(report.get("first", false)):
		_facts[1].text = "BRAIN_START"
		_facts[2].text = _hints_text(hints)
	else:
		_facts[1].text = _time_text(seconds, float(report.get("mean_t", 0.0))) if timed else ""
		_facts[2].text = _hints_text(hints) + " · " + _compare(float(hints), float(report.get("mean_h", 0.0)))
	_facts[3].text = tr("BRAIN_PRECISION") % int(round(q * 100.0)) if q >= 0.0 else ""
	_tip.text = "BRAIN_%s_%d" % [Brain.prefix(id), int(report.get("tip", 1))]
	var scores: Dictionary = report.get("scores", {})
	for i in Brain.SKILLS.size():
		var k: String = Brain.SKILLS[i]
		_names[i].text = "SKILL_" + k.to_upper()
		var s := float(scores.get(k, -1.0))
		_nums[i].text = "%d" % int(round(s)) if s >= 0.0 else "—"
	var low := String(report.get("lowest", ""))
	var suggest := String(report.get("suggest", ""))
	if suggest != "":
		var low_name := tr("SKILL_" + low.to_upper())
		var key := "BRAIN_UNTRAINED" if float(scores.get(low, -1.0)) < 0.0 else "BRAIN_LOWEST"
		_low.text = tr(key) % [low_name, String(Registry.find(suggest).get("title", ""))]
	else:
		_low.text = ""
	_layout()
	queue_redraw()

func _time_text(t: float, mean: float) -> String:
	if mean <= 0.0 or t <= 0.0:
		return _clock(t)
	var d := int(round(mean - t))
	if absi(d) < 2:
		return _clock(t) + " · " + tr("BRAIN_PACE")
	return _clock(t) + " · " + tr("BRAIN_FASTER" if d > 0 else "BRAIN_SLOWER") % _clock(absi(d))

func _clock(secs: float) -> String:
	var s := int(round(secs))
	return "%d:%02d" % [s / 60, s % 60]

func _hints_text(h: int) -> String:
	if h == 0:
		return tr("BRAIN_NO_HINTS")
	return tr("WIN_ONE_HINT") if h == 1 else tr("WIN_N_HINTS") % h

func _compare(v: float, mean: float) -> String:
	if absf(v - mean) < 0.5:
		return tr("BRAIN_AS_USUAL")
	return tr("BRAIN_FEWER" if v < mean else "BRAIN_MORE")

static func _skill_colour(skill: String) -> Color:
	var i := Brain.SKILLS.find(skill)
	return Pal.CAT[i] if i >= 0 else Pal.ACCENT

## The height everything wants at full size.
static func full_height() -> float:
	return PAD * 2.0 + HEAD_H + SCORE_H + TIP_H + BRAIN_LABEL_H + ROW_H * 5.0 + LOW_H + GAP * 3.0

func _layout() -> void:
	var w := size.x
	var inner := w - PAD * 2.0
	var fixed := PAD * 2.0 + HEAD_H + SCORE_H + TIP_H + BRAIN_LABEL_H + LOW_H + GAP * 3.0
	var room := size.y - fixed
	_row_h = clampf(room / 5.0, ROW_MIN, ROW_H)
	_folded = room < ROW_MIN * 5.0
	var y := PAD
	_eye.position = Vector2(w - PAD - EYE, y)
	_place(_title, Vector2(PAD + SKILL_ICON + 20.0, y - 4.0), Vector2(inner - SKILL_ICON - 20.0 - EYE - 10.0, 52.0))
	_place(_line, Vector2(PAD + SKILL_ICON + 20.0, y + 50.0), Vector2(inner - SKILL_ICON - 20.0 - EYE - 10.0, 36.0))
	y += HEAD_H
	_place(_score, Vector2(PAD, y + (SCORE_H - RING) * 0.5), Vector2(RING, RING))
	var fx := PAD + RING + 36.0
	var shown: Array[Label] = []
	for f in _facts:
		f.visible = f.text != ""
		if f.visible:
			shown.append(f)
	var fy := y + (SCORE_H - shown.size() * 44.0) * 0.5
	for f in shown:
		_place(f, Vector2(fx, fy), Vector2(w - PAD - fx, 44.0))
		fy += 44.0
	y += SCORE_H + GAP
	_place(_tip_head, Vector2(PAD + 28.0, y + 16.0), Vector2(inner - 56.0, 32.0))
	_place(_tip, Vector2(PAD + 28.0, y + 50.0), Vector2(inner - 56.0, TIP_H - 60.0))
	y += TIP_H + GAP
	_place(_brain_head, Vector2(PAD, y), Vector2(inner, BRAIN_LABEL_H))
	y += BRAIN_LABEL_H
	for i in Brain.SKILLS.size():
		if _folded:
			var cell := inner / 5.0
			_names[i].visible = false
			_place(_nums[i], Vector2(PAD + cell * i, y + ROW_ICON + 8.0), Vector2(cell, 40.0))
			_nums[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			_names[i].visible = true
			var ry := y + _row_h * i
			_place(_names[i], Vector2(PAD + ROW_ICON + 16.0, ry), Vector2(NAME_W, _row_h))
			_names[i].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_place(_nums[i], Vector2(w - PAD - NUM_W, ry), Vector2(NUM_W, _row_h))
			_nums[i].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_nums[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	y += FOLD_H if _folded else _row_h * 5.0
	_place(_low, Vector2(PAD, y), Vector2(inner, LOW_H))
	_low.visible = _low.text != ""
	queue_redraw()

func _place(l: Control, at: Vector2, s: Vector2) -> void:
	l.position = at
	l.size = s

func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	draw_style_box(CozyTheme.lifted(Pal.SURFACE, RADIUS, 0), Rect2(Vector2.ZERO, size))
	var y := PAD
	Icons.paint(self, Brain.icon(_skill), Rect2(Vector2(PAD, y + 4.0), Vector2(SKILL_ICON, SKILL_ICON)), _colour)
	y += HEAD_H
	# The ring: a pale track, the score's share in the skill's colour.
	var c := Vector2(PAD + RING * 0.5, y + SCORE_H * 0.5)
	var r := (RING - RING_W) * 0.5
	draw_arc(c, r, 0.0, TAU, 64, Pal.SURFACE_HI, RING_W, true)
	var after := float(_report.get("after", -1.0))
	if after > 0.0:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(after / 100.0, 0.0, 1.0) * _t, 64, _colour, RING_W, true)
	y += SCORE_H + GAP
	draw_style_box(CozyTheme.card(Pal.SUN_TILE, TIP_RADIUS, Color.TRANSPARENT, 0, 0), Rect2(PAD, y, size.x - PAD * 2.0, TIP_H))
	y += TIP_H + GAP + BRAIN_LABEL_H
	var scores: Dictionary = _report.get("scores", {})
	var gain := float(_report.get("gain", 0))
	var inner := size.x - PAD * 2.0
	for i in Brain.SKILLS.size():
		var k: String = Brain.SKILLS[i]
		var col: Color = Pal.CAT[i]
		var s := float(scores.get(k, -1.0))
		var today := k == _skill
		if _folded:
			var cell := inner / 5.0
			Icons.paint(self, Brain.icon(k), Rect2(Vector2(PAD + cell * (i + 0.5) - ROW_ICON * 0.5, y), Vector2(ROW_ICON, ROW_ICON)), col if today or s >= 0.0 else Pal.LINE)
			continue
		var ry := y + _row_h * i
		if today:
			draw_style_box(CozyTheme.card(Color(col, 0.12), 22, Color.TRANSPARENT, 0, 0), Rect2(PAD - 12.0, ry + 4.0, inner + 24.0, _row_h - 8.0))
		Icons.paint(self, Brain.icon(k), Rect2(Vector2(PAD, ry + (_row_h - ROW_ICON) * 0.5), Vector2(ROW_ICON, ROW_ICON)), col if s >= 0.0 else Pal.LINE)
		var bx := PAD + ROW_ICON + 16.0 + NAME_W
		var bw := size.x - PAD - NUM_W - 20.0 - bx
		var by := ry + (_row_h - BAR_H) * 0.5
		draw_style_box(CozyTheme.card(Pal.SURFACE_HI, int(BAR_H * 0.5), Color.TRANSPARENT, 0, 0), Rect2(bx, by, bw, BAR_H))
		if s > 0.0:
			var fill := bw * clampf(s / 100.0, 0.0, 1.0) * _t
			var old := fill
			if today and gain > 0.0:
				old = maxf(0.0, fill - bw * gain / 100.0 * _t)
			draw_style_box(CozyTheme.card(col, int(BAR_H * 0.5), Color.TRANSPARENT, 0, 0), Rect2(bx, by, maxf(old, BAR_H), BAR_H))
			if old < fill:
				draw_style_box(CozyTheme.card(Pal.GOOD, int(BAR_H * 0.5), Color.TRANSPARENT, 0, 0), Rect2(bx + old - BAR_H, by, fill - old + BAR_H, BAR_H))

## Slides up and fades in after `delay`, then fills the ring and the bars.
func enter(delay := 0.0) -> void:
	visible = true
	modulate.a = 1.0
	Motion.slide(self, "position:y", position.y + 120.0, position.y, ENTER, delay)
	Motion.appear(self, 0.0, 1.0, ENTER * 0.6, delay)
	if Motion.reduce:
		_set_t(1.0)
		return
	_set_t(0.0)
	Motion.fade(self, _set_t, 0.0, 1.0, FILL, 24, delay + ENTER, true)

func _set_t(v: float) -> void:
	_t = v
	var after := float(_report.get("after", -1.0))
	_score.text = "%d" % int(round(after * v)) if after >= 0.0 else "—"
	queue_redraw()

## Gone with the win (a New board, Redo), every fade put back.
func close() -> void:
	if _peek_tw != null:
		_peek_tw.kill()
	visible = false
	self_modulate.a = 1.0
	for child in get_children():
		if child is CanvasItem:
			child.modulate.a = 1.0

## Held, the plate fades so the solved board shows; let go, it comes back.
## The eye itself stays, so the finger has something to let go of.
func _peek(on: bool) -> void:
	if _peek_tw != null:
		_peek_tw.kill()
	var to := 0.0 if on else 1.0
	var faded: Array = [self]
	for child in get_children():
		if child != _eye and child is CanvasItem:
			faded.append(child)
	if Motion.reduce:
		for item in faded:
			_fade_prop(item, to)
		return
	_peek_tw = create_tween().set_parallel(true)
	for item in faded:
		_peek_tw.tween_property(item, "self_modulate:a" if item == self else "modulate:a", to, PEEK)

func _fade_prop(item: CanvasItem, to: float) -> void:
	if item == self:
		self_modulate.a = to
	else:
		item.modulate.a = to
