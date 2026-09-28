extends "res://ui/hud/sheet.gd"

## The purchase sheet: what remove_ads buys, the store's own price on Buy,
## Restore, and a thank-you once it is owned. The banner tab, the menu
## header and settings all open this one sheet (open_from names which, for
## analytics). A failure is a line on the sheet, never a silence; a
## cancelled purchase says nothing.
##
## Store's signals are connected to methods, not lambdas, so each slot has a
## name traceable back to this sheet's three doors rather than an anonymous
## closure in a stack trace.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 4.
##
## Redrawn on 2026-09-28: a painted meadow with the sprout on its rock, the
## three things the purchase is as plaque rows in place of a paragraph, one
## wide sun button with the price, and Restore as a quiet text button under
## it. The round X is the only close while there is something to buy; once
## it is owned the perks give way to the thanks and a wide Close.

const Analytics = preload("res://core/analytics.gd")
const Vistas = preload("res://ui/menu/vistas.gd")
const StreakTab = preload("res://ui/menu/streak_tab.gd")
const SproutFace = preload("res://ui/faces/sprout_face.gd")

const HERO_H := 250.0
const HERO_R := 30.0
const PERK := 76.0
const PERKS := [
	["no_ads", "STORE_PERK_1", Color("fde3d6")],
	["puzzle", "STORE_PERK_2", Color("e6f0da")],
	["heart", "STORE_PERK_3", Color("fbe0ec")],
]

var buy_button: Button
var restore_button: Button
var close_button: Button
var _body: Label
var _note: Label
var _perks: VBoxContainer

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "STORE_TITLE", "no_ads")
	col.add_child(_hero())
	_perks = VBoxContainer.new()
	_perks.add_theme_constant_override("separation", 14)
	col.add_child(_perks)
	for perk in PERKS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 22)
		row.add_child(SheetParts.Plaque.new(perk[0], perk[2], PERK))
		var line := Label.new()
		line.theme_type_variation = "SheetBody"
		line.text = perk[1]
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(line)
		_perks.add_child(row)
	# The thanks, once owned; hidden while there is something to buy.
	_body = Label.new()
	_body.theme_type_variation = "SheetBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_body)
	# IconButton keeps Button.text empty and letters a child Label, so the
	# formatted price goes through set_label(), never .text.
	buy_button = _wide_primary("no_ads", "STORE_BUY_NO_PRICE")
	buy_button.pressed.connect(Store.buy)
	col.add_child(buy_button)
	_note = Label.new()
	_note.theme_type_variation = "SheetBodyDim"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	# Restore is a quiet line of text, not a second slab under the sun one.
	restore_button = IconButton.new("reset", "STORE_RESTORE", "IconButton")
	restore_button.custom_minimum_size.y = 72.0
	restore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		restore_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	restore_button.pressed.connect(Store.restore)
	col.add_child(restore_button)
	close_button = _wide_primary("check", "BTN_CLOSE")
	close_button.pressed.connect(close)
	col.add_child(close_button)
	Store.owned_changed.connect(_on_owned_changed)
	Store.price_ready.connect(_refresh)
	Store.busy_changed.connect(_on_busy_changed)
	Store.purchase_failed.connect(_on_failed)

## The sheet's picture: the meadow, clear of any banner, with the sprout
## sitting on its rock among flowers.
func _hero() -> Control:
	var plate := Vistas.picture(Vistas.STORE, HERO_R)
	plate.custom_minimum_size.y = HERO_H
	var props := Control.new()
	props.mouse_filter = Control.MOUSE_FILTER_IGNORE
	props.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	props.clip_contents = true
	props.draw.connect(func() -> void:
		var c := Vector2(props.size.x * 0.5, props.size.y + 18.0)
		StreakTab._boulder(props, c, 130, 66)
		StreakTab._flower(props, c + Vector2(-150, -18), 17, Pal.SURFACE)
		StreakTab._flower(props, c + Vector2(142, -26), 19, Pal.FLOWER_TILE)
		StreakTab._flower(props, c + Vector2(178, -8), 13, Pal.SURFACE))
	plate.add_child(props)
	var sprout := SproutFace.new()
	sprout.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sprout.offset_left = -64
	sprout.offset_right = 64
	sprout.offset_top = -146
	sprout.offset_bottom = -18
	plate.add_child(sprout)
	return plate

func open_from(door: String) -> void:
	if is_open():
		return
	Analytics.track("store_opened", {"door": door})
	open()

func _on_open() -> void:
	# A wrapped label measures its height at the width it has when first
	# asked; hand it the card's width so the sheet opens at its real height.
	var w := maxf(content_width(), 1.0)
	_body.custom_minimum_size.x = w
	_note.custom_minimum_size.x = w
	for row in _perks.get_children():
		row.get_child(1).custom_minimum_size.x = w - PERK - 22.0
	_say("")
	_refresh()

func _on_owned_changed(_owned: bool) -> void:
	_say("")
	_refresh()

## The note under the body; an empty one takes no room.
func _say(text: String) -> void:
	_note.text = text
	_note.visible = text != ""

func _on_busy_changed(_busy: bool) -> void:
	_refresh()

func _refresh() -> void:
	if _body == null:
		return
	var owned := Store.owns_remove_ads()
	_body.text = tr("STORE_THANKS")
	_body.visible = owned
	_perks.visible = not owned
	buy_button.visible = not owned
	restore_button.visible = not owned
	close_button.visible = owned
	var price := Store.price_text()
	if price.is_empty() or not Store.available():
		buy_button.set_label(tr("STORE_BUY_NO_PRICE"))
	else:
		buy_button.set_label(tr("STORE_BUY") % price)
	buy_button.set_enabled(Store.available() and not Store.is_busy())
	restore_button.set_enabled(Store.available() and not Store.is_busy())
	# No store on this device: a quiet line says so under the dimmed button,
	# rather than lettering the button itself with the refusal.
	if not owned and not Store.available() and _note.text == "":
		_say(tr("STORE_UNAVAILABLE_NOTE"))

func _on_failed(reason: String) -> void:
	match reason:
		"user-cancelled":
			_say("")
		"pending":
			_say(tr("STORE_PENDING"))
		"nothing_to_restore":
			_say(tr("STORE_NOTHING"))
		"unavailable":
			_say(tr("STORE_UNAVAILABLE"))
		_:
			_say(tr("STORE_FAIL"))
	_refresh()
