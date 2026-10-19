extends Control

## Tally's flow sheet, laid over the paper by the screen from the plate
## row's bars button (the user, 2026-10-19: "a button to show a sheet with
## numbers by seconds of numbers going into the core"): every number coming
## into the counting box and how many a second, over the last
## Sim.FLOW_FOR seconds, the quickest first, each with a bar against the
## quickest; the target's token wears its sun, and the head line says the
## whole flow and the target's share. Live while it is up (a few times a
## second, so the figures can be read).

signal closed

const Sim = preload("res://arcade/tally_sim.gd")
const Art = preload("res://arcade/tally_art.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Face = preload("res://ui/faces/face.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")

const WIDE := 860.0
const ROWS := 9
const ROW_H := 74.0
const HEAD_H := 112.0
const EVERY := 0.25

var sim: RefCounted
var _font: Font
var _live: Control
var _bars: ArrayMesh
var _rows: Array = []
var _since := 0.0

## A rate as the sheet writes it: two decimals under one, one under ten,
## whole past it.
static func rate_text(r: float) -> String:
	if r >= 10.0:
		return Sim.short(int(roundf(r)))
	if r < 1.0 and r > 0.0:
		return String.num(r, 2)
	return String.num(r, 1).trim_suffix(".0")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	_font = CozyTheme.display(700)
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(WIDE)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)
	col.add_child(Dialog.head("TL_FLOW", "bars"))
	_rows = sim.flow()
	_live = Control.new()
	_live.draw.connect(_draw_flow)
	col.add_child(_live)
	_fit()
	var done := Dialog.primary("check", tr("TL_DONE"))
	done.pressed.connect(_close)
	Dialog.buttons(col, done)
	if not Motion.reduce:
		card.pivot_offset = Vector2(WIDE * 0.5, 300)
		card.scale = Vector2.ONE * 0.9
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _close() -> void:
	closed.emit()
	queue_free()

func _process(delta: float) -> void:
	_since += delta
	if _since >= EVERY:
		_since = 0.0
		_rows = sim.flow()
		_fit()
		_live.queue_redraw()

## The sheet as tall as its rows (three at least), grown as numbers come.
func _fit() -> void:
	var n := clampi(_rows.size(), 3, ROWS)
	var h := HEAD_H + n * ROW_H + 40.0
	if _live.custom_minimum_size.y < h:
		_live.custom_minimum_size = Vector2(WIDE - 80, h)

func _text(s: String, at: Vector2, fs: int, col: Color, right := false) -> void:
	var x := at.x
	if right:
		x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_live.draw_string(_font, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _draw_flow() -> void:
	var w := _live.size.x
	var total := 0.0
	var aim := 0.0
	var top := 0.0
	for row: Array in _rows:
		total += float(row[1])
		top = maxf(top, float(row[1]))
		if int(row[0]) == sim.target():
			aim = float(row[1])
	_text(tr("TL_FLOW_TOTAL") % rate_text(total), Vector2(0, 40), 34, Pal.TEXT)
	_text(tr("TL_FLOW_TARGET") % [rate_text(aim), Sim.short(sim.target())], Vector2(0, 82), 26, Pal.ACCENT_DEEP if aim > 0.0 else Pal.TEXT_DIM)
	if _rows.is_empty():
		_text(tr("TL_FLOW_NONE"), Vector2(0, HEAD_H + 50.0), 28, Pal.TEXT_DIM)
	# the bars, one mesh: a pale track and the share against the quickest
	var b := Face.Builder.new()
	var bx := 250.0
	var bw := w - bx - 130.0
	for j in mini(_rows.size(), ROWS):
		var y := HEAD_H + j * ROW_H + ROW_H * 0.5
		var hit: bool = int(_rows[j][0]) == sim.target()
		b.polygon(Face.Builder.round_rect(Vector2(bx, y - 9.0), Vector2(bw, 18.0), 9.0), Color(Pal.TEXT, 0.08))
		var u := float(_rows[j][1]) / maxf(top, 0.001)
		b.polygon(Face.Builder.round_rect(Vector2(bx, y - 9.0), Vector2(maxf(18.0, bw * u), 18.0), 9.0), Pal.GOOD if hit else Color(Art.WALNUT, 0.75))
	_bars = b.mesh() if not b.verts.is_empty() else null
	if _bars != null:
		_live.draw_mesh(_bars, null)
	for j in mini(_rows.size(), ROWS):
		var v := int(_rows[j][0])
		var y := HEAD_H + j * ROW_H + ROW_H * 0.5
		_live.draw_mesh(Art.token(v == sim.target()), null, Transform2D(0.0, Vector2.ONE * 0.8, 0.0, Vector2(40, y)))
		var txt := Sim.short(v)
		var fs := 24 if txt.length() <= 2 else (20 if txt.length() == 3 else 16)
		_text(txt, Vector2(40 - _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x * 0.5, y + fs * 0.36 - 2.0), fs, Art.INK)
		_text(tr("TL_PER_S") % rate_text(float(_rows[j][1])), Vector2(bx - 24.0, y + 11.0), 30, Pal.TEXT, true)
		var share := int(roundf(100.0 * float(_rows[j][1]) / maxf(total, 0.001)))
		_text("%d%%" % share, Vector2(w - 10.0, y + 10.0), 26, Pal.TEXT_DIM, true)
	var foot := _live.size.y - 10.0
	if _rows.size() > ROWS:
		_text(tr("TL_FLOW_MORE") % (_rows.size() - ROWS), Vector2(0, foot), 22, Pal.TEXT_DIM)
	else:
		_text(tr("TL_FLOW_OVER") % Sim.FLOW_FOR, Vector2(0, foot), 22, Pal.TEXT_DIM)
