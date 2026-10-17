extends "res://ui/hud/sheet.gd"

## Start over, asked (the user, 2026-10-17: "all arcade games must have a
## button to reset all progress"): opened from the settings sheet, over it,
## so the game behind stays paused as it does for the sheet, and Keep lands
## back there. It names the game and says nothing comes back; Start over
## only says so (`confirmed`), and the menu puts the game back to nothing.

signal confirmed

var game_title := ""
var keep_button: Button
var yes_button: Button
var _body: Label

func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "ARC_RESET_TITLE", "reset")
	_body = Label.new()
	_body.theme_type_variation = "SheetBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)
	col.add_child(SheetParts.Divider.new())
	keep_button = _wide_primary("check", "ARC_RESET_NO")
	keep_button.pressed.connect(close)
	col.add_child(keep_button)
	yes_button = IconButton.new("bin", "ARC_RESET_YES", "IconButton")
	yes_button.custom_minimum_size = Vector2(WIDE, ROW * 0.8)
	yes_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var up := CozyTheme.soft_button(Pal.SURFACE, IconButton.SLAB_R, false, 20)
	var down := CozyTheme.soft_button(Pal.SURFACE, IconButton.SLAB_R, true, 20)
	for st in ["normal", "hover", "disabled"]:
		yes_button.add_theme_stylebox_override(st, up)
	yes_button.add_theme_stylebox_override("pressed", down)
	yes_button.pressed.connect(func() -> void: close_then(confirmed.emit))
	col.add_child(yes_button)

func _on_open() -> void:
	_body.text = tr("ARC_RESET_BODY") % game_title
