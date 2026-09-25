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

const SLIDE := 0.3
const FADE := 0.2
const OFFSET := 300.0
const MARGIN := 40.0
const ROW := 128.0
## Above anything a board lifts with z_index (its signs and Fx, at 1 and 2):
## z_index outranks tree order, so a sheet at 0 had a board's markers drawn
## over it.
const OVER_BOARD := 10
const SHEET_GAP := 28
const SHEET_INSET := 32.0

var _scrim: ColorRect
var _slot: Control
var _card: PanelContainer
var _tw: Tween
## Set from close() until the next open(): a second tap on a choice while the
## sheet slides away must not set the choice off twice.
var _closing := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = OVER_BOARD
	visible = false
	_scrim = ColorRect.new()
	_scrim.color = Color(Pal.OUTLINE, 0.35)
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
		(style as StyleBoxFlat).content_margin_top = SHEET_INSET
		(style as StyleBoxFlat).content_margin_right = SHEET_INSET
		(style as StyleBoxFlat).content_margin_bottom = SHEET_INSET
	_card.add_theme_stylebox_override("panel", style)
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.offset_left = MARGIN
	_card.offset_right = -MARGIN
	_card.offset_bottom = -MARGIN
	_slot.add_child(_card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", SHEET_GAP)
	_card.add_child(col)
	_build_sheet(col)
	Ads.banner_changed.connect(_on_banner_changed)

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
	_tw = Motion.slide(_slot, "position:y", OFFSET, 0.0, SLIDE)
	Motion.appear(_scrim, 0.0, 1.0, FADE)

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
	var slide: Tween = Motion.slide(_slot, "position:y", 0.0, OFFSET, SLIDE, 0.0, false)
	Motion.appear(_scrim, 1.0, 0.0, FADE)
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
