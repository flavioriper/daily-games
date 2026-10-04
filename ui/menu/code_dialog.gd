extends ColorRect

## Enter a code: the way in for a link opened where the game was not (the
## page shows the code) and for a code read out across a table. One field --
## upper-cased as it is typed, the codes' alphabet only, eight characters --
## Paste, which takes a whole link off the clipboard (`Social.code_in`), and
## Add. Under the field it says who was added, or why not: one line for each
## answer of `Social.add`.
##
## The card stands in the top of the screen, not its middle, so the phone's
## keyboard comes up under it. `is_open()` and `close()` are the pair
## ui/menu.gd's go_back looks for.
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, section 4.

## Gone, by the X, Close or Android's back. `added` is the new friend's uid,
## "" when nobody was.
signal closed(added: String)

const Dialog = preload("res://ui/hud/dialog.gd")
const CozyTheme = preload("res://ui/theme.gd")
const IconButton = preload("res://ui/hud/icon_button.gd")
const Pal = preload("res://core/palette.gd")
const Motion = preload("res://core/motion.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const Social = preload("res://core/social.gd")
const Names = preload("res://versus/online/names.gd")
const SafeArea = preload("res://ui/safe_area.gd")

const WIDTH := 820.0
## How far under the top of the screen the card stands.
const TOP := 300.0
const FIELD_H := 136.0
const X_SIZE := 84.0
## Over the sheet it is raised from (ui/menu/invite_card.gd's OVER_SHEET).
const OVER_SHEET := 12
## What each refusal of Social.add says; "already" names the friend.
const WHY := {"offline": "FRIENDS_ADD_OFFLINE", "unknown": "FRIENDS_ADD_UNKNOWN",
	"self": "FRIENDS_ADD_SELF", "already": "FRIENDS_ADD_ALREADY"}

var field: LineEdit
var add_button: Button
var paste_button: Button
var _says: Label
var _added := ""
var _busy := false
var _gone := false

func _init() -> void:
	name = "CodeDialog"
	color = Dialog.SCRIM
	z_index = OVER_SHEET
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _ready() -> void:
	var card := Dialog.card(WIDTH)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = TOP + SafeArea.insets(self).x
	add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	card.add_child(col)
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "X"
	x.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	var r := int(X_SIZE * 0.5)
	for s in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(s, CozyTheme.soft_button(Pal.SURFACE, r, false, 0))
	x.add_theme_stylebox_override("pressed", CozyTheme.soft_button(Pal.SURFACE, r, true, 0))
	x.pressed.connect(close)
	col.add_child(Dialog.head("FRIENDS_ENTER_CODE", "friends", x))

	field = LineEdit.new()
	field.name = "Field"
	field.custom_minimum_size.y = FIELD_H
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.placeholder_text = "········"
	field.context_menu_enabled = false
	field.add_theme_font_override("font", CozyTheme.display(700, 10))
	field.add_theme_font_size_override("font_size", 72)
	field.add_theme_color_override("font_color", Pal.TEXT)
	field.add_theme_color_override("font_uneditable_color", Pal.TEXT)
	field.add_theme_color_override("font_placeholder_color", Color(Pal.LINE, 0.8))
	field.add_theme_color_override("caret_color", Pal.ACCENT_2)
	var box := CozyTheme.card(Pal.SURFACE, 28, Pal.LINE, 3, 20)
	var lit := CozyTheme.card(Pal.SURFACE, 28, Pal.SUN, 4, 20)
	field.add_theme_stylebox_override("normal", box)
	field.add_theme_stylebox_override("read_only", box)
	field.add_theme_stylebox_override("focus", lit)
	field.text_changed.connect(_on_typed)
	field.text_submitted.connect(func(_t: String) -> void: _add())
	# A touch is not a click here (the project does not emulate the mouse from
	# touch), and only a click gives a LineEdit the caret and the keyboard.
	field.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch and ev.pressed and field.editable:
			field.edit())
	col.add_child(field)

	_says = Label.new()
	_says.name = "Says"
	_says.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_says.theme_type_variation = "SheetBodyDim"
	_says.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_says.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Two lines' room, so an answer that wraps does not move the buttons.
	_says.custom_minimum_size.y = 92.0
	col.add_child(_says)
	_say("FRIENDS_CODE_HINT", Pal.TEXT_DIM)

	add_button = Dialog.primary("plus", tr("FRIENDS_ADD"))
	add_button.name = "Add"
	add_button.pressed.connect(_add)
	paste_button = Dialog.secondary("copy", tr("FRIENDS_PASTE"))
	paste_button.name = "Paste"
	paste_button.pressed.connect(_paste)
	Dialog.buttons(col, add_button, paste_button)
	add_button.set_enabled(false)
	Motion.appear(self, 0.0, 1.0, 0.2)
	field.edit.call_deferred()

func is_open() -> bool:
	return not _gone

func close() -> void:
	if _gone:
		return
	_gone = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.release_focus()
	closed.emit(_added)
	var tw := Motion.appear(self, modulate.a, 0.0, 0.18)
	if tw == null:
		queue_free()
	else:
		tw.finished.connect(queue_free)

## Keeps the field to a code as it is typed. A whole link typed or pasted
## into it by the keyboard is cut down to its code.
func _on_typed(text: String) -> void:
	var out := ""
	if text.length() > Social.CODE_LEN:
		out = Social.code_in(text)
	if out.is_empty():
		for ch in text.to_upper():
			if Social.ALPHABET.contains(ch) and out.length() < Social.CODE_LEN:
				out += ch
	if out != text:
		field.text = out
		field.caret_column = out.length()
	add_button.set_enabled(out.length() == Social.CODE_LEN)
	_say("FRIENDS_CODE_HINT", Pal.TEXT_DIM)

func _paste() -> void:
	if _busy:
		return
	var code := Social.code_in(DisplayServer.clipboard_get())
	if code.is_empty():
		_say("FRIENDS_ADD_NO_CODE", Pal.BERRY_DEEP)
		Haptics.play(Haptics.WARN)
		return
	field.text = code
	field.caret_column = code.length()
	add_button.set_enabled(true)
	_say("FRIENDS_CODE_HINT", Pal.TEXT_DIM)

func _add() -> void:
	if not _added.is_empty():
		close()
		return
	var code := field.text
	if _busy or code.length() != Social.CODE_LEN:
		return
	_busy = true
	add_button.set_enabled(false)
	paste_button.set_enabled(false)
	@warning_ignore("redundant_await")
	var answer: Dictionary = await Social.add(code)
	if _gone or not is_inside_tree():
		return
	_busy = false
	var who := str(answer.get("uid", ""))
	if bool(answer.get("ok", false)):
		_added = who
		_say("FRIENDS_ADDED", Pal.LEAF_DEEP, Names.name_of(who))
		field.editable = false
		field.release_focus()
		paste_button.visible = false
		add_button.set_icon("check")
		add_button.set_label(tr("BTN_CLOSE"))
		add_button.set_enabled(true)
		Haptics.play(Haptics.GOOD)
		Analytics.track("friends_added", {"via": "code"})
		return
	var why := str(answer.get("why", "offline"))
	_say(WHY.get(why, "FRIENDS_ADD_OFFLINE"), Pal.BERRY_DEEP, Names.name_of(who) if why == "already" and not who.is_empty() else "")
	Haptics.play(Haptics.WARN)
	if not Motion.reduce:
		Motion.shiver(field)
	add_button.set_enabled(true)
	paste_button.set_enabled(true)

## The line under the field: `key` translated, with `who` in it when given.
func _say(key: String, colour: Color, who := "") -> void:
	var text := tr(key)
	_says.text = text % who if text.contains("%s") else text
	_says.add_theme_color_override("font_color", colour)
