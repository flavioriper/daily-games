extends "res://ui/hud/sheet.gd"

## What the Swarm knows about the player (the plan's Task 14): the memory
## file on the phone (bot/bot_memory.gd) shown on the house's paper sheet
## (ui/hud/sheet.gd), opened from the call screen's "what I know about you"
## pill (bot/bot_screen.gd). Facts are chips, episodes rows under them, each
## list newest first. A tap on either asks first, the bin's way
## (ui/flat/flat_host.gd's _ask_clear: a centred Dialog card, keep as the sun
## button and the forgetting as the white pill under it), then forgets it from
## the file and, while a call is on, tells the server (BotCall.forget; it does
## nothing with no call). The call goes on under the sheet; a `memory` frame
## that lands while it is up refreshes the list (refresh(), from BotScreen).
##
## The sheet is paper over the dark room: the house's sheets are paper
## everywhere, and this one is the game's, not the Swarm's.

const Dialog = preload("res://ui/hud/dialog.gd")
const TouchScroll = preload("res://ui/touch_scroll.gd")

## The list's tallest before it scrolls.
const LIST_MAX := 820.0
## Room round the list inside the scroll, so the chips' soft shadows are not
## clipped at its edges.
const SHADOW_PAD := 12
const CHIP_H := 72.0
const CHIP_PAD := 26
const CHIP_FONT := 30
const ROW_PAD := 22
## The ask's card, the bin's own width.
const ASK_CARD := 760.0

var close_button: Button
var _scroll: ScrollContainer
var _touch: Node
var _list: VBoxContainer
var _ask: Ask
var _dirty := false


## The centred card that asks before a memory goes. A child of the sheet, so
## it rides the sheet's z_index and Android's back (ui/menu.gd's go_back
## walks the tree last-first) closes it before the sheet.
class Ask extends ColorRect:
	signal answered(forget: bool)

	func is_open() -> bool:
		return visible and not is_queued_for_deletion()

	func close() -> void:
		answered.emit(false)


func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "BOT_KNOWN_TITLE", "heart")
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_touch = TouchScroll.attach(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 22)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top"]:
		pad.add_theme_constant_override("margin_" + side, SHADOW_PAD)
	pad.add_theme_constant_override("margin_bottom", SHADOW_PAD * 2)
	_scroll.add_child(pad)
	pad.add_child(_list)
	# As tall as the list, up to LIST_MAX, then it scrolls. Read whenever the
	# list's size settles: a flow of chips knows its height only once laid
	# out at the card's width.
	_list.minimum_size_changed.connect(_fit_list)
	close_button = _wide_primary("check", "BTN_CLOSE")
	close_button.pressed.connect(close)
	col.add_child(close_button)


func _on_open() -> void:
	_rebuild()


## A `memory` frame was kept while the sheet is up: the list is read again
## (deferred, once a frame, so a burst of frames rebuilds it once).
func refresh() -> void:
	if not is_open() or _dirty:
		return
	_dirty = true
	_rebuild.call_deferred()


func close() -> void:
	_drop_ask()
	super.close()


static func _newest_first(rows: Array, stamp: String) -> Array:
	var out := rows.duplicate()
	out.sort_custom(func(a, b) -> bool: return String(a.get(stamp, "")) > String(b.get(stamp, "")))
	return out


func _rebuild() -> void:
	_dirty = false
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var m := BotMemory.load()
	var facts := _newest_first(m["facts"], "since")
	var episodes := _newest_first(m["episodes"], "at")
	var w := content_width() - 2.0 * SHADOW_PAD
	if facts.is_empty() and episodes.is_empty():
		var none := Label.new()
		none.theme_type_variation = "SheetBodyDim"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = w
		none.text = "BOT_KNOWN_NONE"
		_list.add_child(none)
	if not facts.is_empty():
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 14)
		flow.add_theme_constant_override("v_separation", 14)
		_list.add_child(flow)
		for f in facts:
			flow.add_child(_chip(String(f["id"]), String(f["text"]), w))
	for e in episodes:
		_list.add_child(_row(String(e["id"]), String(e["summary"]), w))
	_fit_list()


func _fit_list() -> void:
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y + 3.0 * SHADOW_PAD, LIST_MAX)


## A fact: a chip of white paper, one line when it fits, wrapped at the
## card's width when it does not.
func _chip(id: String, text: String, w: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = text
	var font := CozyTheme.body(600)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", CHIP_FONT)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Pal.TEXT)
	var up := CozyTheme.chip(Pal.SURFACE, int(CHIP_H * 0.5))
	var down := CozyTheme.chip(Pal.SURFACE, int(CHIP_H * 0.5), Color.TRANSPARENT, 0, true)
	for sb: StyleBoxFlat in [up, down]:
		sb.content_margin_left = CHIP_PAD
		sb.content_margin_right = CHIP_PAD
		sb.content_margin_top = 12
		sb.content_margin_bottom = 12
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.custom_minimum_size.y = CHIP_H
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, CHIP_FONT).x + 2.0 * CHIP_PAD > w:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size.x = w
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(_on_item.bind(id, text))
	return b


## An episode: a row of white paper, the summary wrapped.
func _row(id: String, text: String, w: float) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = text
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.x = w
	b.add_theme_font_override("font", CozyTheme.body(500))
	b.add_theme_font_size_override("font_size", CHIP_FONT)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Pal.TEXT_DIM)
	var up := Dialog.tile(Pal.SURFACE, ROW_PAD)
	var down := CozyTheme.chip(Pal.SURFACE, Dialog.TILE_R, Color.TRANSPARENT, 0, true)
	down.set_content_margin_all(ROW_PAD)
	for st in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, up)
	b.add_theme_stylebox_override("pressed", down)
	b.add_theme_stylebox_override("hover_pressed", down)
	b.pressed.connect(_on_item.bind(id, text))
	return b


func _on_item(id: String, text: String) -> void:
	# The end of a drag through the list is no tap.
	if _closing or is_instance_valid(_ask) or (_touch != null and _touch.dragged()):
		return
	_ask_forget(id, text)


## The bin's card: Forget at the head, the memory itself, keep it as the sun
## button and Forget as the white pill. The scrim keeps it too.
func _ask_forget(id: String, text: String) -> void:
	var ask := Ask.new()
	ask.name = "ForgetCard"
	ask.color = Dialog.SCRIM
	ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ask = ask
	ask.answered.connect(func(forget: bool) -> void:
		_drop_ask()
		if forget:
			BotMemory.forget(id)
			BotCall.forget(id)
			_rebuild())
	ask.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and event.pressed:
			ask.answered.emit(false))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ask.add_child(center)
	var card := Dialog.card(minf(ASK_CARD, size.x - 2.0 * MARGIN))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	card.add_child(col)
	col.add_child(Dialog.head("BOT_FORGET", "bin"))
	var body := Label.new()
	body.text = text
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	body.theme_type_variation = "CardBlurb"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	var keep := Dialog.primary("check", tr("BOT_KEEP"))
	keep.name = "Keep"
	keep.pressed.connect(func() -> void: ask.answered.emit(false))
	var yes := Dialog.secondary("bin", tr("BOT_FORGET"))
	yes.name = "Forget"
	yes.pressed.connect(func() -> void: ask.answered.emit(true))
	Dialog.buttons(col, keep, yes)
	add_child(ask)
	Motion.appear(ask, 0.0, 1.0, 0.2)


func _drop_ask() -> void:
	if is_instance_valid(_ask):
		_ask.visible = false
		_ask.queue_free()
	_ask = null
