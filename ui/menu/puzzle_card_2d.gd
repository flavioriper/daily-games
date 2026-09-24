extends "res://ui/hud/panel.gd"

## One puzzle on the first screen: a paper card with a drawn picture of that
## puzzle's own characters (ui/menu/card_art.gd), its name in the shared
## sun-dotted title face, a two-line blurb and a round go button in the
## puzzle's colour. The whole card is the button and squashes on press.
## Emits `open`; the menu decides what that means.
##
## A card whose registry entry says `soon` names a board nobody has drawn
## flat yet. It keeps its picture and its name, wears a pale SOON pill over
## the picture's corner where the go button would have been, sits at
## SOON_INK, and emits `blocked` rather than `open`. It is deliberately quiet
## rather than disabled-looking: the row is a roadmap, not a fault.
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, section 3.

signal open
signal blocked

const CardArt = preload("res://ui/menu/card_art.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const SunDot = preload("res://ui/sun_dot.gd")

## The picture's slot, the card's own inset, and the go button. Both are
## measured against the vertical budget: at 1080 by 1920 a row of cards gets
## 252, of which the inset takes 32 and the name and the two blurb lines
## about 111. The HUD's usual 24 inset and a 118 picture came to 277, which
## pushed the bottom bar off the screen.
const ART_H := 92.0
## The row's own budgeted height. The card's content (the inset, the art
## plate, the name and the two blurb lines) only ever measures to about 240:
## GridContainer sizes every row to the tallest cell's own minimum and does
## not hand a row any of the grid's leftover height, whether the grid has
## four rows or one. `_update_min` below floors this card's reported
## minimum at CARD_H so every row is exactly the budget regardless of how
## many rows share the page -- the twelve-card page and the pager's short
## last page alike (task 8, 2026-09-20).
const CARD_H := 252.0
## How much taller than ART_H a picture may grow when the menu hands a card
## spare height on a tall screen (`fit_height`): 118 is the mock's picture,
## and past it the plate only gains empty paper, so the rest of the spare
## height goes into the gaps between rows instead (ui/menu.gd, `_fit_grid`).
const ART_GROW := 26.0
const INSET := 16
const GO := 68.0
const PILL := Vector2(88.0, 40.0)
## The done seal: a green disc in a paper ring, pinned over the picture's
## top right corner and hanging SEAL_HANG past it on both edges.
const SEAL_R := 23.0
const SEAL_RING := 4
const SEAL_HANG := 9.0
const SQUASH := 0.06
const SQUASH_SOON := 0.03
const SQUASH_TIME := 0.18
## How far a soon card's picture and words fade back.
const SOON_INK := 0.55
## Each puzzle picture sits on a pale swatch of its own category colour. The
## swatch is the grid's one expressive device: it makes twelve small pictures
## scan as distinct puzzles without adding another label or taking height from
## their art.
const ART_TINT := 0.13
const ART_RADIUS := 18

var entry: Dictionary
var colour: Color
var art: Control
var soon := false
var completed := false
var _tap: Button
var _art_plate: PanelContainer
var _seal: Control
## This card's row height: CARD_H on a 1080x1920 screen, more on a taller
## one (see `fit_height`).
var card_h := CARD_H
var _press_tw: Tween

func _init(the_entry: Dictionary, the_colour: Color, is_completed := false) -> void:
	entry = the_entry
	colour = the_colour
	soon = bool(the_entry.get("soon", false))
	completed = is_completed and not soon
	enter_from = Vector2(0, 60)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _make_inner() -> Container:
	var box := PanelContainer.new()
	var paper := CozyTheme.card(Color(Pal.SURFACE, 0.96), 28, Pal.LINE, 6, INSET)
	# The old bottom edge stays the tactile shadow. A fine outline completes
	# the silhouette against the page, especially on bright phone screens.
	paper.border_width_left = 2
	paper.border_width_top = 2
	paper.border_width_right = 2
	box.add_theme_stylebox_override("panel", paper)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box

func _build() -> void:
	_inner.resized.connect(func() -> void: _inner.pivot_offset = _inner.size * 0.5)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	_inner.add_child(col)

	var art_plate := PanelContainer.new()
	_art_plate = art_plate
	art_plate.custom_minimum_size = Vector2(0.0, ART_H + clampf(card_h - CARD_H, 0.0, ART_GROW))
	art_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_plate.add_theme_stylebox_override("panel", _art_style())
	col.add_child(art_plate)
	art = CardArt.new(String(entry.get("id", "")))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.modulate.a = SOON_INK if soon else 1.0
	art_plate.add_child(art)

	var name_label := Label.new()
	name_label.theme_type_variation = "CardName"
	name_label.text = "BINAiRO" if String(entry.get("id", "")) == "binairo" else String(entry.get("title", ""))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if soon:
		name_label.add_theme_color_override("font_color", Pal.TEXT_DIM)
	col.add_child(name_label)
	name_label.add_child(SunDot.new(name_label, SOON_INK if soon else 1.0))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	col.add_child(row)
	var blurb := Label.new()
	blurb.theme_type_variation = "CardBlurb"
	# The registry's `short` is written to two lines at this width; `blurb`
	# is the long one the rules sheet wants.
	# Every `short` is a translation key, which the Label translates itself.
	blurb.text = String(entry.get("short", entry.get("blurb", "")))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.max_lines_visible = 2
	blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blurb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	blurb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(blurb)
	if not soon:
		var go := IconButton.new("chevron_right")
		go.custom_minimum_size = Vector2(GO, GO)
		go.size_flags_vertical = Control.SIZE_SHRINK_END
		go.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_paint_go(go)
		row.add_child(go)
	else:
		_build_pill()

	# The tap surface lies over the card, drawn by nothing: the card itself
	# answers the press.
	_tap = Button.new()
	_tap.flat = true
	_tap.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap.button_down.connect(_press)
	_tap.button_up.connect(_release)
	_tap.pressed.connect(func() -> void:
		if soon:
			blocked.emit()
		else:
			open.emit())
	add_child(_tap)
	if completed:
		_build_done_badge()

## The completion marker: a check seal pinned over the picture's corner like
## a sticker, with no word on it. It rides a layer laid over the art plate
## (a PanelContainer stretches it to the picture's own rect, and nothing up
## the chain clips) so it squashes with the card, and it covers only the
## plate's empty corner: the old DONE pill sat over the picture itself and cut
## into Code Break's pouch, Nonogram's clues and Word Trail's tiles, and a
## page of them read louder than the one card still to play. The chevron is
## still the way back in. Two draw commands: the stylebox and the check.
func _build_done_badge() -> void:
	if _seal != null or _art_plate == null:
		return
	_seal = Control.new()
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc := CozyTheme.card(Pal.GOOD, int(SEAL_R), Pal.SURFACE, 0, 0)
	disc.set_border_width_all(SEAL_RING)
	disc.shadow_color = Color(Pal.GOOD.darkened(0.45), 0.35)
	disc.shadow_size = 2
	disc.shadow_offset = Vector2(0.0, 3.0)
	disc.anti_aliasing_size = 1.2
	_seal.draw.connect(func() -> void:
		var c := Vector2(_seal.size.x - SEAL_R + SEAL_HANG, SEAL_R - SEAL_HANG)
		var box := Rect2(c - Vector2.ONE * SEAL_R, Vector2.ONE * SEAL_R * 2.0)
		_seal.draw_style_box(disc, box)
		var k := SEAL_R - float(SEAL_RING)
		var tick := PackedVector2Array([
			c + Vector2(-0.46, 0.02) * k, c + Vector2(-0.14, 0.34) * k, c + Vector2(0.48, -0.30) * k])
		_seal.draw_polyline(tick, Pal.SURFACE, k * 0.30, true))
	_art_plate.add_child(_seal)

func set_completed(value: bool) -> void:
	if completed == value or soon:
		return
	completed = value
	if value:
		_build_done_badge()
	elif _seal != null:
		_seal.queue_free()
		_seal = null

## The SOON pill, over the picture's top right corner. It rides the art
## rather than the blurb's row: two lines of text and a pill in the same
## corner collided at 320 wide, and the pill is the louder of the two.
##
## It hangs off the card itself rather than `_inner`, which is a
## PanelContainer: a second child there is stretched to fill the card and
## covers the picture, the name and the blurb entirely.
func _build_pill() -> void:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel",
		CozyTheme.card(Pal.SURFACE_HI, int(PILL.y * 0.5), Pal.LINE, 0, 6))
	pill.custom_minimum_size = PILL
	pill.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pill.offset_left = -PILL.x - 14.0
	pill.offset_right = -14.0
	pill.offset_top = 14.0
	pill.offset_bottom = 14.0 + PILL.y
	var label := Label.new()
	label.text = "CARD_SOON"
	label.theme_type_variation = "CardBlurb"
	label.add_theme_color_override("font_color", Pal.TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(label)
	add_child(pill)

## The go button as a round disc in the puzzle's colour with a cream chevron:
## the same paper button, re-dressed.
func _paint_go(go: Button) -> void:
	var r := int(GO * 0.5)
	go.add_theme_stylebox_override("normal", CozyTheme.card(colour, r, colour.darkened(0.28), 5, 8))
	go.add_theme_stylebox_override("hover", CozyTheme.card(colour, r, colour.darkened(0.28), 5, 8))
	go.add_theme_stylebox_override("pressed", CozyTheme.card(colour.darkened(0.12), r, colour.darkened(0.28), 2, 8))
	go.add_theme_stylebox_override("disabled", CozyTheme.card(Color(colour, 0.55), r, Color(colour.darkened(0.28), 0.55), 5, 8))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		go.add_theme_color_override(state, Pal.SURFACE)

func _art_style() -> StyleBoxFlat:
	var fill := Pal.SURFACE_HI.lerp(colour, ART_TINT)
	var plate := StyleBoxFlat.new()
	plate.bg_color = fill
	plate.set_corner_radius_all(ART_RADIUS)
	plate.set_border_width_all(2)
	plate.border_color = Color(colour, 0.22 if soon else 0.34)
	return plate

func _press() -> void:
	Motion.stop(_press_tw)
	_inner.scale = Vector2.ONE
	_inner.self_modulate = Color.WHITE.lerp(colour, 0.08 if soon else 0.13)
	_press_tw = Motion.squash(_inner, SQUASH_SOON if soon else SQUASH, SQUASH_TIME)

func _release() -> void:
	_inner.self_modulate = Color.WHITE

## Turns off this card's own tap surface. For a card the menu is fading out
## on a page turn: it still sits over the incoming page's cards for the
## fade's duration, and `_tap` is a full-rect Button that wins every tap
## over whatever is underneath it, so a card leaving has to give that up
## before it can be trusted to sit on top of one arriving.
func disable_tap() -> void:
	_tap.mouse_filter = Control.MOUSE_FILTER_IGNORE

## ui/hud/panel.gd reports `_inner`'s own combined minimum (about 240) as
## this Control's minimum; floored at CARD_H so a GridContainer row -- which
## sizes to the tallest cell's minimum and never redistributes its own
## leftover height to a row -- lands on the budget however many rows the
## page it is on has.
func _update_min() -> void:
	super._update_min()
	custom_minimum_size.y = maxf(custom_minimum_size.y, card_h)

## Gives this card a row of `h` (never under CARD_H), spending what is over
## the budget on the picture up to ART_GROW. The menu calls it with the
## height its grid can afford a row on this screen.
func fit_height(h: float) -> void:
	card_h = maxf(h, CARD_H)
	if not is_node_ready():
		return
	if _art_plate != null:
		_art_plate.custom_minimum_size.y = ART_H + clampf(card_h - CARD_H, 0.0, ART_GROW)
	_update_min()
