extends "res://ui/hud/sheet.gd"

## The door to the old game: one row per entry in `Registry.LEGACY`, plus
## the campsite menu itself at the end, so the first screen the game used to
## open on is still reachable rather than merely still on disk.
##
## Opening any of these mounts the 3D stage, which the live game no longer
## carries (ui/menu.gd `_open_legacy`); the menu frees it again on the way
## back. Nothing new belongs in here.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 5.

## An entry was picked; the menu opens it on the stage.
signal chose(entry: Dictionary)
## The campsite menu itself was picked.
signal chose_camp

const Registry = preload("res://ui/registry.gd")
const Icons = preload("res://ui/icons.gd")

const TITLE := "LEGACY_TITLE"
const BLURB := "LEGACY_BLURB"
const ROW_H := 120.0
const CHEVRON := 42.0

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = TITLE
	col.add_child(title)
	var blurb := Label.new()
	blurb.theme_type_variation = "SheetBodyDim"
	blurb.text = BLURB
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 1000.0
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 14)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var i := 0
	for entry in Registry.LEGACY:
		list.add_child(_row(_name_of(entry), i, func() -> void: chose.emit(entry)))
		i += 1
	list.add_child(_row("LEGACY_CAMP", i, func() -> void: chose_camp.emit()))

## An island board says so; the four that were never drawn flat, and the
## turn, carry their own name alone.
func _name_of(entry: Dictionary) -> String:
	var title := String(entry.get("title", ""))
	if String(entry.get("id", "")).ends_with("_island"):
		return "%s · island" % title
	if Registry.kind(entry) == "turn":
		return "%s · a turn" % title
	return title

func _row(text: String, index: int, on_press: Callable) -> Control:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = ROW_H
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = text
	button.add_theme_font_override("font", CozyTheme.body(600))
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color", Pal.TEXT)
	button.add_theme_color_override("font_hover_color", Pal.TEXT)
	button.add_theme_color_override("font_pressed_color", Pal.TEXT)
	# Alternating fill, so fifteen rows read as a list rather than a wall.
	var fill: Color = Pal.SURFACE_HI if index % 2 == 0 else Pal.SURFACE
	button.add_theme_stylebox_override("normal", CozyTheme.card(fill, 18, fill, 0, 24))
	button.add_theme_stylebox_override("hover", CozyTheme.card(fill, 18, fill, 0, 24))
	button.add_theme_stylebox_override("pressed", CozyTheme.card(fill.darkened(0.06), 18, fill, 0, 24))
	button.pressed.connect(on_press)
	var chevron := Control.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -CHEVRON - 24.0
	chevron.offset_right = -24.0
	chevron.offset_top = -CHEVRON * 0.5
	chevron.offset_bottom = CHEVRON * 0.5
	chevron.draw.connect(func() -> void:
		Icons.paint(chevron, "chevron_right", Rect2(Vector2.ZERO, chevron.size), Pal.TEXT_DIM))
	button.add_child(chevron)
	return button
