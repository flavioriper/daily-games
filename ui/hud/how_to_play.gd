extends Control

## Shared first-play introduction for every puzzle. The card deliberately has
## the same calm shape as Binairo's original introduction, while the copy and
## illustration come from the puzzle currently on screen.

signal completed

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Progress = preload("res://core/progress.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")

var _entry: Dictionary
var _puzzle: Control
var _diagram: Control
var _pages: Array = []
var _page := 0
var _diagram_slot: Control
var _title: Label
var _body: Label
var _note: Label
var _dots: Control
var _back_button: Button
var _next_button: Button
## The room the card is centred in: the screen less the safe-area insets,
## the banner and its tab included, so the card never sits under the ad.
var _area: Control
var _decor: ArrayMesh
var _decor_size := Vector2.ZERO

func setup(entry: Dictionary, puzzle: Control) -> void:
	_entry = entry
	_puzzle = puzzle

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Over the board's own lifted layers, as the sheets are (sheet.gd).
	z_index = preload("res://ui/hud/sheet.gd").OVER_BOARD
	_build()
	_fit_area()
	Ads.banner_changed.connect(func(_visible: bool, _height: float) -> void: _fit_area())

## Re-read on every banner change: the card is up on a board's first open,
## which is also when the first banner is most likely to arrive.
func _fit_area() -> void:
	var insets := SafeArea.insets(self)
	_area.offset_top = insets.x
	_area.offset_bottom = -insets.y

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(Pal.OUTLINE, 0.62)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_area)

	var dialog := PanelContainer.new()
	dialog.name = "HowToPlayCard"
	dialog.add_theme_stylebox_override("panel", _card_style())
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	dialog.custom_minimum_size = Vector2(900, 1360)
	_area.add_child(dialog)
	# The sheets' leaf sprigs, drawn on the card under its content.
	dialog.draw.connect(func() -> void:
		if dialog.size != _decor_size:
			_decor_size = dialog.size
			_decor = SheetParts.decor_mesh(dialog.size)
		dialog.draw_mesh(_decor, null))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 24)
	dialog.add_child(col)

	var heading := Label.new()
	heading.theme_type_variation = "SheetTitle"
	heading.text = tr("HTP_TITLE") % String(_entry.get("title", ""))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.custom_minimum_size.y = 74
	col.add_child(heading)

	# A board that teaches in steps hands over its pages (tutorial_pages():
	# [{diagram, title, body}], each diagram a fresh Control); any other gets
	# the one-page card: the shared lesson diagram, its rules and a tip.
	if _puzzle != null and _puzzle.has_method("tutorial_pages"):
		_pages = _puzzle.tutorial_pages()
	if _pages.is_empty():
		var diagram = preload("res://ui/hud/how_to_play_diagram.gd").new()
		diagram.puzzle_id = String(_entry.get("id", ""))
		_pages = [{"diagram": diagram, "title": "HTP_START", "body": _rules_text(),
			"note": tr("HTP_TIP") % _tip_text()}]

	_diagram_slot = Control.new()
	_diagram_slot.custom_minimum_size = Vector2(0, 475)
	_diagram_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_child(_diagram_slot)

	_title = Label.new()
	_title.theme_type_variation = "CardTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size.x = 760
	col.add_child(_title)

	_body = Label.new()
	_body.theme_type_variation = "SheetBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size.x = 760
	# Every page the same height, so the buttons never jump as it turns.
	_body.custom_minimum_size.y = 230 if _pages.size() > 1 else 0
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	col.add_child(_body)

	_note = Label.new()
	_note.theme_type_variation = "SheetBodyDim"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.custom_minimum_size.x = 760
	col.add_child(_note)

	_dots = Control.new()
	_dots.custom_minimum_size = Vector2(0, 28)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.visible = _pages.size() > 1
	_dots.draw.connect(_draw_dots)
	col.add_child(_dots)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	col.add_child(row)
	_back_button = Button.new()
	_back_button.theme_type_variation = "IconButton"
	_back_button.text = "HTP_BACK"
	_back_button.custom_minimum_size = Vector2(250, 108)
	_back_button.pressed.connect(func() -> void: _turn(-1))
	row.add_child(_back_button)
	_next_button = Button.new()
	_next_button.theme_type_variation = "PrimaryButton"
	_next_button.custom_minimum_size = Vector2(430, 108)
	_next_button.focus_mode = Control.FOCUS_ALL
	_next_button.pressed.connect(func() -> void:
		if _page >= _pages.size() - 1:
			_continue()
		else:
			_turn(1))
	row.add_child(_next_button)
	_show_page(0)

## Turns `step` pages, never past either end.
func _turn(step: int) -> void:
	_show_page(clampi(_page + step, 0, _pages.size() - 1))

func _show_page(i: int) -> void:
	_page = i
	var page: Dictionary = _pages[i]
	if is_instance_valid(_diagram) and _diagram.get_parent() == _diagram_slot:
		_diagram_slot.remove_child(_diagram)
	# A page's diagram is made once and kept, so turning back finds it as it
	# was; only the one on show is in the tree, and so animating.
	_diagram = page.diagram
	_diagram.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_diagram_slot.add_child(_diagram)
	_title.text = String(page.get("title", ""))
	_body.text = String(page.get("body", ""))
	_note.text = String(page.get("note", ""))
	_note.visible = _note.text != ""
	_back_button.visible = _pages.size() > 1
	_back_button.disabled = i == 0
	_next_button.text = "HTP_CONTINUE" if i == _pages.size() - 1 else "HTP_NEXT"
	_dots.queue_redraw()

## The page dots under the text: the one on show filled and wider.
func _draw_dots() -> void:
	var n := _pages.size()
	var w := 0.0
	for k in n:
		w += (34.0 if k == _page else 14.0) + (12.0 if k < n - 1 else 0.0)
	var x := (_dots.size.x - w) * 0.5
	var y := _dots.size.y * 0.5
	for k in n:
		var dw := 34.0 if k == _page else 14.0
		var colour: Color = Pal.ACCENT if k == _page else Color(Pal.LINE, 0.8)
		_dots.draw_style_box(_pill(colour), Rect2(x, y - 7.0, dw, 14.0))
		x += dw + 12.0

func _pill(colour: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.set_corner_radius_all(7)
	return sb

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
	var sb := CozyTheme.sheet_card(Pal.PAPER, 44, 36)
	sb.content_margin_top = 34
	sb.content_margin_bottom = 34
	return sb

func _exit_tree() -> void:
	# Pages off the tree were never freed with it.
	for page in _pages:
		var d: Control = page.get("diagram")
		if is_instance_valid(d) and d.get_parent() == null:
			d.free()

func _continue() -> void:
	Progress.mark_tutorial_seen(String(_entry.get("id", "")))
	completed.emit()
	queue_free()
