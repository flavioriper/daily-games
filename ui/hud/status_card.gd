extends PanelContainer

## A one-line slate card in the action row, for a board that keeps a running
## count rather than a working line -- fences left and meadow penned, say.
## Reads PuzzleBase.status_text(); the action bar shows it for puzzles with the
## "status" capability and hides it for the rest.

const CozyTheme = preload("res://ui/theme.gd")

const MIN_WIDTH := 420.0

var _label: Label

func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.slate_card())
	custom_minimum_size.x = MIN_WIDTH
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label = Label.new()
	_label.theme_type_variation = "OnSlateBody"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_label)

func refresh(puzzle) -> void:
	_label.text = puzzle.status_text() if puzzle != null else ""
