extends Control

## The age question, once, at first launch on a phone and before any ad
## SDK call (core/ads.gd waits for it). Neutral by design, as Google Play's
## Families policy asks of a mixed-audience app: no year chosen for the
## player, the list opens on this year, and nothing says which answer does
## what. Plan docs/superpowers/plans/2026-09-29-fair-ads.md, task 2.

signal answered(year: int)

const AgeGate = preload("res://core/age_gate.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Dialog = preload("res://ui/hud/dialog.gd")
const Pal = preload("res://core/palette.gd")

var _chosen := 0
var _buttons := {}
var _go: Button

static func wanted() -> bool:
	if AgeGate.known():
		return false
	return OS.has_feature("mobile") or (OS.is_debug_build() and OS.get_environment("AGE_SCREEN") == "1")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CozyTheme.make()
	z_index = 20
	add_child(Dialog.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := Dialog.card(880)
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	col.add_child(Dialog.head("AGE_TITLE", "heart"))
	var body := Label.new()
	body.theme_type_variation = "SheetBody"
	body.text = "AGE_BODY"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 800
	col.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(800, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(grid)
	var now := int(Time.get_datetime_dict_from_system(true).year)
	for y in range(now, now - 101, -1):
		var b := Button.new()
		b.text = str(y)
		b.add_theme_font_size_override("font_size", 36)
		b.custom_minimum_size = Vector2(0, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick.bind(y))
		grid.add_child(b)
		_buttons[y] = b
		_paint(b, false)
	_go = Dialog.primary("chevron_right", "AGE_CONTINUE")
	_go.disabled = true
	_go.pressed.connect(_on_go)
	Dialog.buttons(col, _go)

## The chosen year is the sun's pill, the rest white paper.
func _paint(b: Button, chosen: bool) -> void:
	var fill := Pal.SUN if chosen else Pal.SURFACE
	var up := CozyTheme.soft_button(fill, 28, false, 12)
	var down := CozyTheme.soft_button(fill, 28, true, 12)
	for st in ["normal", "hover", "focus"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)

func _pick(y: int) -> void:
	_chosen = y
	for k: int in _buttons:
		_paint(_buttons[k], k == y)
	_go.disabled = false

func _on_go() -> void:
	if _chosen <= 0:
		return
	answered.emit(_chosen)
	queue_free()
