extends Control

## The first-play Binairo introduction. It is intentionally a single calm card:
## the player learns the three things they need before touching the board, then
## the regular rules sheet remains available from the help button.

signal completed

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Progress = preload("res://core/progress.gd")

var _dialog: PanelContainer
var _diagram: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(Pal.OUTLINE, 0.62)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	_dialog = PanelContainer.new()
	_dialog.name = "BinairoTutorialCard"
	_dialog.add_theme_stylebox_override("panel", _card_style())
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.custom_minimum_size = Vector2(900, 1360)
	add_child(_dialog)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	_dialog.add_child(col)

	var heading := Label.new()
	heading.theme_type_variation = "SheetTitle"
	heading.text = "How to play Binairo"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 74
	col.add_child(heading)

	_diagram = preload("res://ui/hud/binairo_tutorial_diagram.gd").new()
	_diagram.custom_minimum_size = Vector2(0, 475)
	_diagram.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_diagram)

	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "Fill the grid"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := Label.new()
	body.theme_type_variation = "SheetBody"
	body.text = "Use suns and moons to fill every cell. Each row and column must contain the same number of each symbol. Never place three matching symbols in a row, and no row or column can be repeated."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size.x = 760
	col.add_child(body)

	var note := Label.new()
	note.theme_type_variation = "SheetBodyDim"
	note.text = "Tip: start with rows that already have two matching symbols side by side."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.x = 760
	col.add_child(note)

	var button := Button.new()
	button.theme_type_variation = "PrimaryButton"
	button.text = "Continue"
	button.custom_minimum_size = Vector2(430, 108)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_continue)
	col.add_child(button)

func _card_style() -> StyleBoxFlat:
	var sb := CozyTheme.card(Pal.PAPER, 34, Pal.LINE, 6, 36)
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	return sb

func _continue() -> void:
	Progress.mark_tutorial_seen("binairo")
	completed.emit()
	queue_free()
