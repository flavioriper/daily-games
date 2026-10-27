extends Control

## The first screen's header: the icon's DAILY / PUZZLES letter tiles
## (ui/menu/word_tiles.gd) with the motto under them, and remove-ads, gifts,
## settings and calendar above, all over the day's own dusk painting
## (ui/menu.gd's backdrop, Vistas.set_header_vista). The remove-ads button is
## the purchase sheet's door from the first screen and goes for good once
## remove_ads is owned (spec 2026-09-25-ads-and-remove-ads-design.md, section 4).
##
## The sun and the moon, the i's small sun and the sprig that stood here
## went on 2026-10-27 (spec 2026-10-27-peeplet-brand-design.md, Part B): the
## header is the tiles, the motto and the buttons, and nothing in it idles, so
## `Power`'s rest has nothing here to still.
##
## The entrance lays the tiles one at a time, as the opening does, while the
## block lifts into place; the motto fades in after the first tiles and the
## utility buttons simply scale into place. Under reduce-motion everything
## stands finished.
##
## **The calendar badge shows the current streak** and hides at 0; **the
## calendar opens Streak** (spec `2026-09-24-stats-streak-design.md`,
## section 4).
## Spec: docs/superpowers/specs/2026-09-18-flat-menu-design.md, sections 1
## and 4.

signal settings
signal remove_ads
## The gift button: the daily gifts sheet (spec 2026-09-28-gold-gifts).
signal gifts

const Pal = preload("res://core/palette.gd")
const CozyTheme = preload("res://ui/theme.gd")
const Motion = preload("res://core/motion.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")

## A translation key (locale/ui.csv): the label re-translates itself live.
const MOTTO := "MENU_MOTTO"
## Measured against the vertical budget rather than chosen: at 1080 by 1920
## the screen owes 80 to margins, 180 to the day row, 150 to the bar and 60
## to the three gaps, and four rows of cards want the rest. 380 is what is
## left, and the lettering below is sized to fit inside it: 120 of air, the
## ~127 tall tiles and the two 38 motto lines.
const HEIGHT := 380.0
const BUTTON := Vector2(110.0, 110.0)
const BUTTON_GAP := 20.0
const BADGE := 48.0
## The tiles' own side at the 1080 design width: DAILY over PUZZLES is about
## 490 by 127 of the 380 the header has, leaving the motto's two lines under it.
const TILE := 60.0
## Where the block stands. The buttons end 110 down on the right, and the
## tiles reach 490 across from the left, so 120 clears them with the tilts.
const TITLE_TOP := 120.0
## The entrance is deliberately short enough that the day row can follow it
## without making the whole menu wait. Values are offsets from enter(delay).
const TITLE_LIFT := 18.0
const TITLE_TIME := 0.34
const BUTTON_TIME := 0.28
## One tile every 0.085 s, as the opening lays them.
const TILE_STEP := 0.085
const TITLE_AT := 0.0
const BUTTON_AT := 0.04
const MOTTO_AT := 0.10

var gear: Button
var no_ads: Button
var calendar: Button
var gift: Button
var _badge: Control
var _streak := 0
var _motto: Label
var _title_block: VBoxContainer
var _tiles: WordTiles
var _entrance_tw: Tween

## Built in _init rather than _ready, so the menu can wire `gear` and
## `calendar` the moment it makes one.
func _init() -> void:
	custom_minimum_size.y = HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	# --- the three buttons, top right ---
	calendar = _button("calendar")
	calendar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	calendar.offset_left = -BUTTON.x
	calendar.offset_bottom = BUTTON.y
	var badge := Control.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -BADGE - BUTTON.x * 0.06
	badge.offset_right = -BUTTON.x * 0.06
	badge.offset_top = -BADGE * 0.3
	badge.offset_bottom = BADGE * 0.7
	badge.draw.connect(_draw_badge.bind(badge))
	badge.visible = false
	calendar.add_child(badge)
	_badge = badge

	gear = _button("gear")
	gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -BUTTON.x * 2.0 - BUTTON_GAP
	gear.offset_right = -BUTTON.x - BUTTON_GAP
	gear.offset_bottom = BUTTON.y
	gear.pressed.connect(func() -> void: settings.emit())

	gift = _button("gift")
	gift.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	gift.offset_left = -BUTTON.x * 3.0 - BUTTON_GAP * 2.0
	gift.offset_right = -BUTTON.x * 2.0 - BUTTON_GAP * 2.0
	gift.offset_bottom = BUTTON.y
	gift.pressed.connect(func() -> void: gifts.emit())

	no_ads = _button("no_ads")
	no_ads.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	no_ads.offset_left = -BUTTON.x * 4.0 - BUTTON_GAP * 3.0
	no_ads.offset_right = -BUTTON.x * 3.0 - BUTTON_GAP * 3.0
	no_ads.offset_bottom = BUTTON.y
	no_ads.pressed.connect(func() -> void: remove_ads.emit())
	no_ads.visible = Store.SELLING and not Store.owns_remove_ads()
	Store.owned_changed.connect(func(owned: bool) -> void: no_ads.visible = Store.SELLING and not owned)

	# --- the lettering ---
	_title_block = VBoxContainer.new()
	_title_block.name = "Title"
	_title_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_block.add_theme_constant_override("separation", 0)
	_title_block.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_title_block.offset_top = TITLE_TOP
	add_child(_title_block)
	_tiles = WordTiles.new()
	_tiles.name = "Tiles"
	_tiles.tile = TILE
	_title_block.add_child(_tiles)
	_motto = Label.new()
	_motto.theme_type_variation = "MenuMotto"
	_motto.text = MOTTO
	_title_block.add_child(_motto)
	_set_entrance_final()

func _button(icon: String) -> Button:
	var b := IconButton.new(icon)
	b.custom_minimum_size = BUTTON
	b.size = BUTTON
	var r := int(BUTTON.x * 0.29)
	CozyTheme.lift_button(b, Pal.SURFACE, r)
	add_child(b)
	return b

## Gifts waiting on the gift button's badge; hidden at 0.
func set_gifts(n: int) -> void:
	if gift != null:
		gift.badge = maxi(n, 0)

## The current streak on the calendar; hidden at 0, a pill past one digit.
func set_streak(n: int) -> void:
	_streak = maxi(n, 0)
	if _badge == null:
		return
	_badge.visible = _streak > 0
	var w := maxf(BADGE, _badge_font().get_string_size(str(_streak), HORIZONTAL_ALIGNMENT_LEFT, -1, int(BADGE * 0.56)).x + BADGE * 0.5)
	_badge.offset_left = -w - BUTTON.x * 0.06
	_badge.queue_redraw()

func _badge_font() -> Font:
	return CozyTheme.display(700)

func _draw_badge(ci: Control) -> void:
	var r := BADGE * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.ACCENT_2
	sb.set_corner_radius_all(int(r))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, Rect2(Vector2.ZERO, Vector2(ci.size.x, BADGE)))
	var sz := int(BADGE * 0.56)
	var s := str(_streak)
	var w := _badge_font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	ci.draw_string(_badge_font(), Vector2(ci.size.x * 0.5 - w * 0.5, r + sz * 0.36), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Pal.SURFACE)

## The entrance: the tiles are laid a tile at a time while the block lifts into
## place, the motto fades in and the buttons scale in.
func enter(delay: float, fade: float) -> void:
	Motion.stop(_entrance_tw)
	modulate.a = 1.0
	if Motion.reduce:
		_set_entrance_final()
		return

	_title_block.position.y = TITLE_TOP + TITLE_LIFT
	_tiles.shown = 0
	_motto.modulate.a = 0.0
	_prepare_button(no_ads)
	_prepare_button(gear)
	_prepare_button(calendar)
	_prepare_button(gift)

	# One parallel score keeps the individual beats related. `fade` still
	# controls the motto's fade time as it did in the original entrance.
	var text_fade := maxf(fade, 0.18)
	var n := WordTiles.count()
	_entrance_tw = create_tween().set_parallel(true)
	_entrance_tw.tween_property(_title_block, "position:y", TITLE_TOP, TITLE_TIME).set_delay(delay + TITLE_AT) \
		.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	# Stepped by int: tile k stands at (k - 1) steps, the twelfth last.
	_entrance_tw.tween_method(func(v: float) -> void: _tiles.shown = ceili(v), 0.0, float(n), TILE_STEP * n) \
		.set_delay(delay + TITLE_AT).set_trans(Tween.TRANS_LINEAR)
	_entrance_tw.tween_property(_motto, "modulate:a", 1.0, text_fade).set_delay(delay + MOTTO_AT)
	_scale_in(gear, delay + BUTTON_AT, BUTTON_TIME)
	_scale_in(calendar, delay + BUTTON_AT + 0.06, BUTTON_TIME)
	_scale_in(gift, delay + BUTTON_AT + 0.12, BUTTON_TIME)
	_scale_in(no_ads, delay + BUTTON_AT + 0.18, BUTTON_TIME)

func _prepare_button(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * 0.90
	button.modulate.a = 0.0

func _scale_in(node: Control, at: float, time: float) -> void:
	_entrance_tw.tween_property(node, "scale", Vector2.ONE, time).set_delay(at) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tw.tween_property(node, "modulate:a", 1.0, time * 0.55).set_delay(at)

func _set_entrance_final() -> void:
	_title_block.position.y = TITLE_TOP
	_tiles.shown = WordTiles.count()
	_motto.modulate.a = 1.0
	for button in [no_ads, gear, calendar, gift]:
		button.scale = Vector2.ONE
		button.modulate.a = 1.0

## Settings can change while the menu stays on screen: a running entrance
## stands finished, with the motion on or off (nothing here idles).
func refresh_motion(_reduced: bool) -> void:
	Motion.stop(_entrance_tw)
	_set_entrance_final()
