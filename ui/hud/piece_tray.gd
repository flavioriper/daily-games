extends PanelContainer

## The wooden piece tray: one button per kind of piece the puzzle hands out,
## in order, each showing the kind's icon over how many are left. Reads
## PuzzleBase.pieces(); the action bar hides it for puzzles without one.
## Spec: docs/superpowers/specs/2026-09-15-pipes-iso-design.md, section 5.

signal pick(index: int)

const CozyTheme = preload("res://ui/theme.gd")
const Icons = preload("res://ui/icons.gd")
const Motion = preload("res://core/motion.gd")
const Pal = preload("res://core/palette.gd")

const GAP := 14

var buttons: Array = []
var _row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", CozyTheme.wood_card())
	material = CozyTheme.wood_grain()
	# The same trough the colour tray has, so the two trays read as one part
	# of the HUD seen on different boards.
	var channel := PanelContainer.new()
	channel.name = "Channel"
	channel.add_theme_stylebox_override("panel", CozyTheme.wood_channel())
	channel.material = CozyTheme.wood_grain()
	add_child(channel)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", GAP)
	channel.add_child(_row)

## Rebuilds the buttons when the tray's size changes (a new puzzle), then
## updates every entry's count, selection and enabled state.
func refresh(puzzle) -> void:
	var entries: Array = puzzle.pieces() if puzzle != null else []
	if entries.size() != buttons.size():
		for b in buttons:
			_row.remove_child(b)
			b.queue_free()
		buttons = []
		for i in entries.size():
			var b := PieceButton.new()
			b.name = "Piece%d" % i
			b.pressed.connect(func() -> void: pick.emit(i))
			_row.add_child(b)
			buttons.append(b)
	for i in entries.size():
		var e: Dictionary = entries[i]
		buttons[i].set_entry(String(e.kind), int(e.count), bool(e.selected), bool(e.enabled))

## One kind on the tray. A PegButton would not do: these entries carry an icon
## and a count instead of a colour and a pip mark, and one of them is the
## selected one, which a peg never is. The look is the same otherwise -- the
## HUD's paper button, dimmed when there is nothing left to place, squishing
## on press.
class PieceButton extends Button:
	const SIZE := Vector2(140, 156)
	const GLYPH := 68.0
	const RADIUS := 28
	const EDGE := 6
	const PAD := 10
	const SQUASH := 0.10
	const SQUASH_TIME := 0.18

	var kind := ""
	var count: int = 0
	var selected := false
	var _press_tw: Tween
	var _glyph: Control
	var _count: Label

	func _init() -> void:
		theme_type_variation = "IconButton"
		text = ""
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = SIZE

	func _ready() -> void:
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(col)
		_glyph = Control.new()
		_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.custom_minimum_size = Vector2(GLYPH, GLYPH)
		_glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_glyph.draw.connect(_draw_glyph)
		col.add_child(_glyph)
		_count = Label.new()
		_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(_count)
		button_down.connect(_squish)
		resized.connect(func() -> void: pivot_offset = size * 0.5)
		pivot_offset = size * 0.5
		_apply_ring()
		_apply_ink()

	func _notification(what: int) -> void:
		# Only the ink follows a theme change: the ring's own overrides raise
		# this notification, and re-applying them here would never stop.
		if what == NOTIFICATION_THEME_CHANGED and _count != null:
			_apply_ink()

	## An empty stack takes no picks, the way a spent colour does on the peg
	## tray; `enabled` on top of that is the board saying it is not listening.
	func set_entry(kind_: String, count_: int, selected_: bool, enabled: bool) -> void:
		kind = kind_
		count = count_
		selected = selected_
		disabled = not enabled or count_ <= 0
		_apply_ring()
		_apply_ink()

	func _squish() -> void:
		Motion.stop(_press_tw)
		scale = Vector2.ONE
		_press_tw = Motion.squash(self, SQUASH, SQUASH_TIME)

	## The selected kind wears a ring of SUN all the way round, the way the
	## peg tray rings a peg in OUTLINE: one glance says what a tap will place.
	func _apply_ring() -> void:
		if _count == null:
			return
		for state in ["normal", "hover", "pressed", "disabled"]:
			if selected:
				# The disabled ring fades with its tile, as the theme's own
				# disabled card does, so a spent selection still reads as spent.
				var fade := 0.55 if state == "disabled" else 1.0
				var sb: StyleBoxFlat = CozyTheme.card(Color(Pal.SURFACE_HI, fade), RADIUS, Color(Pal.SUN, fade), EDGE, PAD)
				sb.set_border_width_all(EDGE)
				add_theme_stylebox_override(state, sb)
			else:
				remove_theme_stylebox_override(state)

	## The count in the button's own font, dimmed with the glyph when the
	## stack is spent.
	func _apply_ink() -> void:
		if _count == null:
			return
		_count.text = str(count)
		_count.add_theme_font_override("font", get_theme_font("font"))
		_count.add_theme_font_size_override("font_size", get_theme_font_size("font_size"))
		_count.add_theme_color_override("font_color", _ink())
		_glyph.queue_redraw()

	func _ink() -> Color:
		return get_theme_color("font_disabled_color") if disabled else get_theme_color("font_color")

	func _draw_glyph() -> void:
		Icons.paint(_glyph, kind, Rect2(Vector2.ZERO, _glyph.size), _ink())
