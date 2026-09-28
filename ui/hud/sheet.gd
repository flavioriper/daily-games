extends Control

## Base of the HUD's modal bottom sheets: a scrim and a card anchored to the
## bottom that slides up. Hidden until open(); tapping the scrim closes it.
## Subclasses fill the card's column in _build_sheet, pick the card's style
## in _card_style and re-read state in _on_open.
##
## The slide moves `_slot`, a full-rect wrapper, not the card: writing a
## Control's position bakes its current size into its offsets, and a card
## whose height is still settling (wrapped labels report a line per character
## until their first layout) would be frozen at that height.
## Spec: docs/superpowers/specs/2026-09-14-binairo-hud-design.md, sections 2 and 5.

signal closed

const Motion = preload("res://core/motion.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const SafeArea = preload("res://ui/safe_area.gd")
const SheetParts = preload("res://ui/hud/sheet_parts.gd")

const SLIDE := 0.3
const FADE := 0.2
## The least a sheet slides; a card travels its own height past the screen's
## bottom (_travel), because a fixed 300 left a tall card two thirds on the
## screen when close() hid it -- it stopped mid-slide and blinked out.
const OFFSET := 300.0
## Past the card's foot, so its soft shadow leaves the screen too.
const SHADOW_ROOM := 48.0
const MARGIN := 40.0
const ROW := 128.0
## Above anything a board lifts with z_index (its signs and Fx, at 1 and 2):
## z_index outranks tree order, so a sheet at 0 had a board's markers drawn
## over it.
const OVER_BOARD := 10
const SHEET_GAP := 28
const SHEET_INSET := 32.0
## The grab handle at the top of the card (UI polish, 2026-09-28): a short
## pill, and the room above the content it takes.
const HANDLE := Vector2(76.0, 8.0)
const HANDLE_ROOM := 10.0
## The round close at the title's right, and the wide primary button a sheet
## ends on (the HUD mock, 2026-09-28).
const X_SIZE := 84.0
const WIDE := 460.0

var _scrim: ColorRect
var _slot: Control
var _card: PanelContainer
var _tw: Tween
## Set from close() until the next open(): a second tap on a choice while the
## sheet slides away must not set the choice off twice.
var _closing := false
## The title row's label, for a sheet whose title changes (difficulty).
var title_label: Label
var x_button: Button
## The card's sprigs, rebuilt only when the card changes size.
var _decor: ArrayMesh
var _decor_size := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = OVER_BOARD
	visible = false
	_scrim = ColorRect.new()
	# Warm and a touch deeper than the ink at 0.35 it was: the sheet has to
	# stand off a busy painting, not sit in a grey haze over it.
	_scrim.color = Color(0.22, 0.14, 0.08, 0.42)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed:
			close())
	add_child(_scrim)
	_slot = Control.new()
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_slot)
	_card = PanelContainer.new()
	var style := _card_style()
	# Opaque, whatever the card style's own alpha: the scrim already dims what
	# lies under a sheet, and a see-through card lets the action bar's labels
	# ghost through its face (seen under a narrow Close button).
	if style is StyleBoxFlat:
		style = (style as StyleBoxFlat).duplicate()
		(style as StyleBoxFlat).bg_color.a = 1.0
		(style as StyleBoxFlat).content_margin_left = SHEET_INSET
		(style as StyleBoxFlat).content_margin_top = SHEET_INSET + HANDLE_ROOM
		(style as StyleBoxFlat).content_margin_right = SHEET_INSET
		(style as StyleBoxFlat).content_margin_bottom = SHEET_INSET
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = MARGIN
	_card.offset_right = -MARGIN
	_card.offset_bottom = -MARGIN
	_slot.add_child(_card)
	_card.draw.connect(_draw_handle)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", SHEET_GAP)
	_card.add_child(col)
	_build_sheet(col)
	Ads.banner_changed.connect(_on_banner_changed)

func _draw_handle() -> void:
	if _card.size != _decor_size:
		_decor_size = _card.size
		_decor = SheetParts.decor_mesh(_card.size)
	_card.draw_mesh(_decor, null)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Pal.LINE, 0.45)
	sb.set_corner_radius_all(int(HANDLE.y * 0.5))
	sb.anti_aliasing_size = 1.0
	_card.draw_style_box(sb, Rect2(Vector2((_card.size.x - HANDLE.x) * 0.5, 18.0), HANDLE))

## The sheet's head: its icon badge, the title and a round X that closes it.
## `key` is a translation key. A sheet with something to show beside the title
## (the gold pill) adds it before the X.
func _title_row(col: VBoxContainer, key: String, icon: String) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	head.add_child(SheetParts.Badge.new(icon))
	title_label = Label.new()
	title_label.theme_type_variation = "SheetTitle"
	title_label.text = key
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(title_label)
	x_button = IconButton.new("cross", "", "IconButton")
	x_button.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	x_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	var up := CozyTheme.soft_button(Pal.SURFACE, r, false, 0)
	var down := CozyTheme.soft_button(Pal.SURFACE, r, true, 0)
	for s in ["normal", "hover", "disabled"]:
		x_button.add_theme_stylebox_override(s, up)
	x_button.add_theme_stylebox_override("pressed", down)
	x_button.pressed.connect(close)
	head.add_child(x_button)
	return head

## The wide sun button a sheet ends on, centred.
func _wide_primary(icon: String, key: String) -> Button:
	var b := IconButton.new(icon, key, "PrimaryButton")
	b.custom_minimum_size = Vector2(WIDE, ROW)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return b

## Fill the card's column. Called once from _ready.
func _build_sheet(_col: VBoxContainer) -> void:
	pass

## The card's look; paper unless a subclass says otherwise.
func _card_style() -> StyleBox:
	return CozyTheme.paper_card()

## Re-read whatever the sheet shows. Called at the start of every open().
func _on_open() -> void:
	pass

## Width left for the card's content once the sheet's margins and the card's
## own padding are taken off. Wrapped labels can be sized to this up front so
## their first layout already has the right height.
func content_width() -> float:
	var style := _card.get_theme_stylebox("panel")
	return size.x - 2.0 * MARGIN - style.content_margin_left - style.content_margin_right

func open() -> void:
	visible = true
	_closing = false
	_fit_bottom()
	_on_open()
	Motion.stop(_tw)
	# Eased out, not Motion.slide's overshoot: TRANS_BACK's bounce is a share
	# of the travel, and over a whole card's height it threw the sheet 100
	# px past its seat.
	_slot.position.y = 0.0 if Motion.reduce else _travel()
	if not Motion.reduce:
		_tw = create_tween()
		_tw.tween_property(_slot, "position:y", 0.0, SLIDE + 0.05).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	Motion.appear(_scrim, 0.0, 1.0, FADE)

## How far the slot has to move for the card to be wholly off the bottom of
## the screen. At open() the rows a sheet has just rebuilt are not laid out
## yet, so the card's minimum size stands in for its size; a wrapped label
## can overstate that before its first layout, so it is capped at the screen.
func _travel() -> float:
	var h := maxf(_card.size.y, _card.get_combined_minimum_size().y)
	var d := h - _card.offset_bottom + SHADOW_ROOM
	return clampf(d, OFFSET, maxf(size.y, OFFSET))

## Stand clear of the bottom inset -- the banner and its tab included. A real
## banner is a native view over the whole app, so a card under it would have
## its last row (Close, often) covered. Re-read at every open and whenever the
## banner comes or goes (a purchase takes it away under an open sheet).
func _fit_bottom() -> void:
	_card.offset_bottom = -MARGIN - SafeArea.insets(self).y

func _on_banner_changed(_visible: bool, _height: float) -> void:
	_fit_bottom()

## Up, or on its way up: Android's back closes a sheet that is_open().
func is_open() -> bool:
	return visible and not _closing

func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	Motion.stop(_tw)
	var slide: Tween = Motion.slide(_slot, "position:y", _slot.position.y, _travel(), SLIDE, 0.0, false)
	Motion.appear(_scrim, 1.0, 0.0, SLIDE)
	if slide == null:
		visible = false
		closed.emit()
		return
	_tw = slide
	slide.finished.connect(func() -> void:
		visible = false
		closed.emit())

## Closes, and runs `then` once the slide is over. Anything heavy a choice
## sets off (dealing and building a board) waits for the sheet to be gone:
## on a phone a build in the same frame as the slide's first stalls the
## whole slide.
func close_then(then: Callable) -> void:
	if not visible or _closing:
		return
	closed.connect(then, CONNECT_ONE_SHOT)
	close()
