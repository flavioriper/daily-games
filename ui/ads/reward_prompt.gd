extends Control

## A small centred question laid over a screen: watch a short video for a
## reward, or not. Asked, never pushed -- no timer, the screen waits. Built
## like arcade/second_chance.gd. Answers once through `chosen(watch)` and
## frees itself.

signal chosen(watch: bool)

const Dialog = preload("res://ui/hud/dialog.gd")
const Motion = preload("res://core/motion.gd")

var _title_key := ""
var _body_key := ""
var _icon := ""
var _done := false

func _init(title_key: String, body_key: String, icon: String) -> void:
	_title_key = title_key
	_body_key = body_key
	_icon = icon

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 8
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(800)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	col.add_child(Dialog.head(_title_key, _icon))
	var line := Label.new()
	line.theme_type_variation = "SheetBody"
	line.text = _body_key
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 720
	col.add_child(line)
	var watch := Dialog.primary("play", tr("AD_WATCH"))
	watch.name = "Watch"
	watch.pressed.connect(_answer.bind(true))
	var no := Dialog.secondary("chevron_right", tr("AD_NO"))
	no.name = "No"
	no.pressed.connect(_answer.bind(false))
	Dialog.buttons(col, watch, no)
	if not Motion.reduce:
		card.pivot_offset = Vector2(400, 300)
		card.scale = Vector2.ONE * 0.86
		card.create_tween().tween_property(card, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Motion.appear(self, 0.0, 1.0, 0.2)

func _answer(watch: bool) -> void:
	if _done:
		return
	_done = true
	chosen.emit(watch)
	queue_free()
