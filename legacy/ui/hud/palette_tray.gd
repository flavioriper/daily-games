extends PanelContainer

## The wooden colour tray: one PegButton per palette entry, in order. Reads
## PuzzleBase.palette(); the action bar hides it for puzzles without one.
## Spec: docs/superpowers/specs/2026-09-14-codebreak-3d-design.md, section 3.

signal pick(index: int)

const CozyTheme = preload("res://ui/theme.gd")
const PegButton = preload("res://legacy/ui/hud/peg_button.gd")

const GAP := 14

var buttons: Array = []
var _row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.wood_card())
	material = CozyTheme.wood_grain(1.0)
	# The trough: a darker inset the buttons sit in, so the tray reads as
	# carved rather than painted.
	var channel := PanelContainer.new()
	channel.name = "Channel"
	channel.add_theme_stylebox_override("panel", CozyTheme.wood_channel())
	channel.material = CozyTheme.wood_grain(2.0)
	add_child(channel)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", GAP)
	channel.add_child(_row)

## Rebuilds the buttons when the palette's size changes (a new puzzle), then
## updates every entry's colour, mark and enabled state.
func refresh(puzzle) -> void:
	var entries: Array = puzzle.palette() if puzzle != null else []
	if entries.size() != buttons.size():
		for b in buttons:
			_row.remove_child(b)
			b.queue_free()
		buttons = []
		for i in entries.size():
			var b := PegButton.new()
			b.name = "Peg%d" % i
			b.pressed.connect(func() -> void: pick.emit(i))
			_row.add_child(b)
			buttons.append(b)
	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].set_entry(e.colour, int(e.mark), bool(e.enabled))
