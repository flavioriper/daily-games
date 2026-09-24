extends Control

## Shared first-play introduction for every puzzle. The card deliberately has
## the same calm shape as Binairo's original introduction, while the copy and
## illustration come from the puzzle currently on screen.

signal completed

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Progress = preload("res://core/progress.gd")

var _entry: Dictionary
var _puzzle: Control
var _diagram: Control

func setup(entry: Dictionary, puzzle: Control) -> void:
	_entry = entry
	_puzzle = puzzle

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

	var dialog := PanelContainer.new()
	dialog.name = "HowToPlayCard"
	dialog.add_theme_stylebox_override("panel", _card_style())
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	dialog.custom_minimum_size = Vector2(900, 1360)
	add_child(dialog)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	dialog.add_child(col)

	var heading := Label.new()
	heading.theme_type_variation = "SheetTitle"
	heading.text = tr("HTP_TITLE") % String(_entry.get("title", ""))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 74
	col.add_child(heading)

	var is_binairo := String(_entry.get("id", "")) == "binairo"
	var diagram = preload("res://ui/hud/binairo_tutorial_diagram.gd").new() if is_binairo else preload("res://ui/hud/how_to_play_diagram.gd").new()
	if not is_binairo:
		diagram.puzzle_id = String(_entry.get("id", ""))
	_diagram = diagram
	_diagram.custom_minimum_size = Vector2(0, 475)
	_diagram.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_diagram)

	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = "HTP_BINAIRO_MOVE" if is_binairo else "HTP_START"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var body := Label.new()
	body.theme_type_variation = "SheetBody"
	body.text = _rules_text()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size.x = 760
	col.add_child(body)

	var note := Label.new()
	note.theme_type_variation = "SheetBodyDim"
	note.text = tr("HTP_TIP") % _tip_text()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.custom_minimum_size.x = 760
	col.add_child(note)

	var button := Button.new()
	button.theme_type_variation = "PrimaryButton"
	button.text = "HTP_CONTINUE"
	button.custom_minimum_size = Vector2(430, 108)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(_continue)
	col.add_child(button)

func _rules_text() -> String:
	if _puzzle != null and _puzzle.has_method("rules"):
		return String(_puzzle.rules())
	return tr(String(_entry.get("blurb", "HTP_FALLBACK_RULES")))

func _tip_text() -> String:
	# The registry's `blurb` is a key; its first sentence, lower-cased, is
	# the tip in whatever language it translated to.
	var blurb := tr(String(_entry.get("blurb", "HTP_FALLBACK_TIP")))
	var first := blurb.split(".", false)[0].strip_edges() if blurb != "" else ""
	return first.to_lower() + "." if first != "" else tr("HTP_FALLBACK_TIP").to_lower()

func _card_style() -> StyleBoxFlat:
	var sb := CozyTheme.card(Pal.PAPER, 34, Pal.LINE, 6, 36)
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	return sb

func _continue() -> void:
	Progress.mark_tutorial_seen(String(_entry.get("id", "")))
	completed.emit()
	queue_free()
