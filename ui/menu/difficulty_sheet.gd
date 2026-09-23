extends "res://ui/hud/sheet.gd"

## Asks which board to play before a card whose registry entry carries
## `"pick_difficulty"` opens: one row per entry in its `"levels"` (a name and
## a short line each), with a check on the rows already finished today. The
## menu opens the host at the difficulty picked; tapping the scrim closes
## the sheet and leaves the player on the menu.
##
## Sudoku is the first to ask (2026-09-23): easy and medium are the 6x6 mini
## and hard is the 9x9, so the choice is a different board and not a harder
## seed of one, and a player has to be able to say which.

## A row was picked; the menu opens `entry` at `difficulty`.
signal chose(entry: Dictionary, difficulty: int)

const Registry = preload("res://ui/registry.gd")
const Progress = preload("res://core/progress.gd")
const Icons = preload("res://ui/icons.gd")

## The registry names its levels in English; these are their keys.
const LEVEL_KEYS := {"Easy": "DIFF_EASY", "Medium": "DIFF_MEDIUM", "Hard": "DIFF_HARD"}

const ROW_H := 128.0
const MARK := 44.0

var _entry: Dictionary = {}
var _title: Label
var _list: VBoxContainer

func _build_sheet(col: VBoxContainer) -> void:
	_title = Label.new()
	_title.theme_type_variation = "SheetTitle"
	col.add_child(_title)
	var blurb := Label.new()
	blurb.theme_type_variation = "SheetBodyDim"
	blurb.text = "DIFF_PICK"
	col.add_child(blurb)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 14)
	col.add_child(_list)

## Shows the sheet for `entry`, its rows rebuilt so each reads today's state.
func ask(entry: Dictionary) -> void:
	_entry = entry
	_title.text = String(entry.get("title", ""))
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var levels: Array = entry.get("levels", [])
	for i in levels.size():
		var level: Dictionary = levels[i]
		var d := int(level.get("difficulty", i))
		var done := Progress.completed(Registry.progress_id(entry, d))
		_list.add_child(_row(level, i, done, func() -> void:
			close()
			chose.emit(_entry, d)))
	open()

func _row(level: Dictionary, index: int, done: bool, on_press: Callable) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = ROW_H
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill: Color = Pal.SURFACE_HI if index % 2 == 0 else Pal.SURFACE
	button.add_theme_stylebox_override("normal", CozyTheme.card(fill, 18, fill, 0, 24))
	button.add_theme_stylebox_override("hover", CozyTheme.card(fill, 18, fill, 0, 24))
	button.add_theme_stylebox_override("pressed", CozyTheme.card(fill.darkened(0.06), 18, fill, 0, 24))
	button.pressed.connect(on_press)
	# The name and its line are labels over the button rather than its own
	# text, so the two can take two faces.
	var text := HBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.offset_left = 32.0
	text.offset_right = -(MARK + 48.0)
	text.add_theme_constant_override("separation", 20)
	button.add_child(text)
	var name := Label.new()
	name.text = LEVEL_KEYS.get(String(level.get("name", "")), String(level.get("name", "")))
	name.add_theme_font_override("font", CozyTheme.body(700))
	name.add_theme_font_size_override("font_size", 38)
	name.add_theme_color_override("font_color", Pal.TEXT)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(name)
	var line := Label.new()
	line.text = String(level.get("line", ""))
	line.add_theme_font_override("font", CozyTheme.body(600))
	line.add_theme_font_size_override("font_size", 30)
	line.add_theme_color_override("font_color", Pal.TEXT_DIM)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(line)
	var mark := Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	mark.offset_left = -MARK - 28.0
	mark.offset_right = -28.0
	mark.offset_top = -MARK * 0.5
	mark.offset_bottom = MARK * 0.5
	mark.draw.connect(func() -> void:
		var r := Rect2(Vector2.ZERO, mark.size)
		if done:
			Icons.paint(mark, "check", r, Pal.LEAF_DEEP)
		else:
			Icons.paint(mark, "chevron_right", r, Pal.TEXT_DIM))
	button.add_child(mark)
	return button
