extends "res://ui/hud/panel.gd"

## One puzzle on the menu: a paper card with a lettered medallion in the
## puzzle's own colour, the title, the blurb wrapped to the card, and a sun
## chevron pill as the play affordance. The whole card is the button: a flat
## Button lies over the paper and squashes it on press. Emits open; the menu
## decides what that means.

signal open

const Icons = preload("res://ui/icons.gd")

const MEDALLION := 88.0
const PILL := 72.0
const MIN_HEIGHT := 148.0
const LETTER_SIZE := 44
const LETTER_OUTLINE := 6
const EDGE := 4.0
const SQUASH := 0.06
const SQUASH_TIME := 0.18
const PRESS_TINT := Color(0.93, 0.91, 0.88)

var entry: Dictionary
var colour: Color
var _tap: Button
var _press_tw: Tween

func _init(the_entry: Dictionary, the_colour: Color) -> void:
	entry = the_entry
	colour = the_colour
	enter_from = Vector2(0, 60)

func _build() -> void:
	var card := _inner as PanelContainer
	card.add_theme_stylebox_override("panel", CozyTheme.paper_card())
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size.y = MIN_HEIGHT
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	card.add_child(row)
	row.add_child(_medallion())
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 2)
	row.add_child(words)
	var title := Label.new()
	title.theme_type_variation = "CardTitle"
	title.text = String(entry.get("title", ""))
	words.add_child(title)
	var blurb := Label.new()
	blurb.theme_type_variation = "CardBody"
	blurb.add_theme_color_override("font_color", Pal.TEXT_DIM)
	blurb.text = String(entry.get("blurb", ""))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(blurb)
	row.add_child(_pill())
	# The tap surface lies over the paper, drawn by nothing: the paper itself
	# answers the press.
	_tap = Button.new()
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.button_down.connect(_press)
	_tap.button_up.connect(_release)
	_tap.pressed.connect(func() -> void: open.emit())
	add_child(_tap)

## A disc in the puzzle's colour with a darker bottom edge, the buttons'
## language, and the title's initial on it in the wordmark's outlined white.
func _medallion() -> Control:
	var disc := Control.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(MEDALLION, MEDALLION)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.draw.connect(func() -> void:
		var c := disc.size * 0.5
		var r := MEDALLION * 0.5 - EDGE * 0.5
		disc.draw_circle(c + Vector2(0.0, EDGE), r, colour.darkened(0.3), true, -1.0, true)
		disc.draw_circle(c, r, colour, true, -1.0, true))
	var letter := Label.new()
	letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	letter.theme_type_variation = "Badge"
	letter.add_theme_font_size_override("font_size", LETTER_SIZE)
	letter.add_theme_color_override("font_outline_color", Pal.OUTLINE)
	letter.add_theme_constant_override("outline_size", LETTER_OUTLINE)
	letter.text = String(entry.get("title", "?")).left(1).to_upper()
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	letter.offset_bottom = -EDGE
	disc.add_child(letter)
	return disc

## The play affordance: a sun pill with the primary button's deep edge and a
## chevron pointing into the puzzle.
func _pill() -> Control:
	var pill := Control.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.custom_minimum_size = Vector2(PILL, PILL)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := CozyTheme.card(Pal.SUN, int(PILL * 0.5), Pal.SUN_DEEP, int(EDGE) + 2, 0)
	pill.draw.connect(func() -> void:
		pill.draw_style_box(style, Rect2(Vector2.ZERO, pill.size))
		var glyph := Rect2(Vector2.ZERO, pill.size).grow(-PILL * 0.2)
		glyph.position.y -= EDGE * 0.5
		Icons.paint(pill, "chevron_right", glyph, Pal.TEXT))
	return pill

func _press() -> void:
	Motion.stop(_press_tw)
	_inner.scale = Vector2.ONE
	_inner.self_modulate = PRESS_TINT
	_press_tw = Motion.squash(_inner, SQUASH, SQUASH_TIME)

func _release() -> void:
	_inner.self_modulate = Color.WHITE
