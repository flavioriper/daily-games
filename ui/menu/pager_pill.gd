extends PanelContainer

## The pager every paged list of the first screen wears: prev, dots, next in
## one paper pill, as the Puzzles grid's (ui/menu.gd) and the Stats tab's are
## drawn. The page shown is a filled disc and every other an outlined ring,
## so "which page" is a shape and not two shades of one dot. A list owns one
## of these, tells it where it stands (`show_page`) and turns when it says
## `turned`.

signal turned(by: int)

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")

## The pill's own height with its padding, for a list to leave it room.
const H := 64.0
const BTN := Vector2(44.0, 44.0)
const ICON := 20.0
const DOT := 14.0
const DOT_GAP := 10.0

var _prev: Button
var _next: Button
var _dots: Control
var _page := 0
var _pages := 1
var _silent := false

## `silent`: the list plays a turn's own sound (a page that slides), so the
## buttons keep their click to themselves.
func _init(silent := false) -> void:
	_silent = silent
	add_theme_stylebox_override("panel", CozyTheme.lifted(Pal.SURFACE, 24, 8))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_prev = _button("chevron_left")
	_prev.name = "Prev"
	_prev.pressed.connect(func() -> void: turned.emit(-1))
	row.add_child(_prev)
	_dots = Control.new()
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.draw.connect(_draw_dots)
	row.add_child(_dots)
	_next = _button("chevron_right")
	_next.name = "Next"
	_next.pressed.connect(func() -> void: turned.emit(1))
	row.add_child(_next)
	show_page(0, 1)

## Stands the pill at `page` of `pages`.
func show_page(page: int, pages: int) -> void:
	_page = page
	_pages = maxi(pages, 1)
	_prev.disabled = page <= 0
	_next.disabled = page >= _pages - 1
	(_prev.get_meta("glyph") as Control).queue_redraw()
	(_next.get_meta("glyph") as Control).queue_redraw()
	_dots.custom_minimum_size = Vector2(_pages * DOT + (_pages - 1) * DOT_GAP, DOT)
	_dots.queue_redraw()

func _draw_dots() -> void:
	for i in _pages:
		var c := Vector2(i * (DOT + DOT_GAP) + DOT * 0.5, DOT * 0.5)
		if i == _page:
			_dots.draw_circle(c, DOT * 0.5, Pal.TEXT)
		else:
			_dots.draw_arc(c, DOT * 0.5 - 1.5, 0.0, TAU, 24, Pal.TEXT_DIM, 2.5, true)

func _button(icon: String) -> Button:
	var btn := Button.new()
	if _silent:
		btn.set_meta("silent", true)
	btn.custom_minimum_size = BTN
	btn.focus_mode = Control.FOCUS_NONE
	CozyTheme.lift_button(btn, Pal.SURFACE, int(BTN.y * 0.5), 0)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(center)
	var glyph := Control.new()
	glyph.custom_minimum_size = Vector2(ICON, ICON)
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.draw.connect(func() -> void:
		Icons.paint(glyph, icon, Rect2(Vector2.ZERO, glyph.size),
			Pal.TEXT_DIM if btn.disabled else Pal.TEXT))
	center.add_child(glyph)
	btn.set_meta("glyph", glyph)
	return btn
