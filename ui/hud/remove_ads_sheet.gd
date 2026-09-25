extends "res://ui/hud/sheet.gd"

## The purchase sheet: what remove_ads buys, the store's own price on Buy,
## Restore, and a thank-you once it is owned. The banner tab, the menu
## header and settings all open this one sheet (open_from names which, for
## analytics). A failure is a line on the sheet, never a silence; a
## cancelled purchase says nothing.
##
## Store's signals are connected to methods, not lambdas: the puzzle host's
## copy of this sheet is freed with the board, and a method connection is
## dropped with its object where a lambda's is not.
## Spec: docs/superpowers/specs/2026-09-25-ads-and-remove-ads-design.md, section 4.

const Analytics = preload("res://core/analytics.gd")

var buy_button: Button
var restore_button: Button
var close_button: Button
var _body: Label
var _note: Label

func _card_style() -> StyleBox:
	return CozyTheme.parchment_card()

func _build_sheet(col: VBoxContainer) -> void:
	var title := Label.new()
	title.theme_type_variation = "SheetTitle"
	title.text = "STORE_TITLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_body = Label.new()
	_body.theme_type_variation = "SheetBody"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_body)
	_note = Label.new()
	_note.theme_type_variation = "SheetBodyDim"
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_note)
	# IconButton keeps Button.text empty and letters a child Label, so the
	# formatted price goes through set_label(), never .text.
	buy_button = IconButton.new("no_ads", "STORE_BUY_NO_PRICE", "PrimaryButton")
	buy_button.custom_minimum_size.y = ROW
	buy_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_button.pressed.connect(Store.buy)
	col.add_child(buy_button)
	restore_button = IconButton.new("reset", "STORE_RESTORE", "IconButton")
	restore_button.custom_minimum_size.y = ROW
	restore_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore_button.pressed.connect(Store.restore)
	col.add_child(restore_button)
	close_button = IconButton.new("check", "BTN_CLOSE", "IconButton")
	close_button.custom_minimum_size.y = ROW
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	col.add_child(close_button)
	Store.owned_changed.connect(_on_owned_changed)
	Store.price_ready.connect(_refresh)
	Store.busy_changed.connect(_on_busy_changed)
	Store.purchase_failed.connect(_on_failed)

func open_from(door: String) -> void:
	Analytics.track("store_opened", {"door": door})
	open()

func _on_open() -> void:
	# A wrapped label measures its height at the width it has when first
	# asked; hand it the card's width so the sheet opens at its real height.
	var w := maxf(content_width(), 1.0)
	_body.custom_minimum_size.x = w
	_note.custom_minimum_size.x = w
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
	_body.text = tr("STORE_THANKS") if owned else tr("STORE_BODY")
	buy_button.visible = not owned
	restore_button.visible = not owned
	var price := Store.price_text()
	if not Store.available():
		buy_button.set_label(tr("STORE_UNAVAILABLE"))
	elif price.is_empty():
		buy_button.set_label(tr("STORE_BUY_NO_PRICE"))
	else:
		buy_button.set_label(tr("STORE_BUY") % price)
	buy_button.set_enabled(Store.available() and not Store.is_busy())
	restore_button.set_enabled(Store.available() and not Store.is_busy())

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
