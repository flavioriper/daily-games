extends "res://ui/hud/sheet.gd"

## The Friends sheet, behind the row on the Versus tab: Invite a friend (the
## sun button: the player's link, out through the phone's share sheet), the
## player's code with a copy button, Enter a code (ui/menu/code_dialog.gd),
## and the friends -- each a face, a name, Online or Away, Play and a remove
## that asks first. With nobody yet: a face and one line that says a link is
## all it takes. Play asks which game (ui/menu/invite_card.gd's picker),
## closes the sheet and says `play`; ui/menu.gd opens the screen.
##
## Opening it is what makes a player social (`Social.enable()`): from then on
## the stream and the presence beat run. Presence is read as it opens and
## every REFRESH seconds while it is up. Offline -- Social never started, or
## no code came back -- it says so and offers Try again, nothing else: every
## other button here needs the network.
## Spec: docs/superpowers/specs/2026-10-04-friends-design.md, section 4.

## A game picked for a friend; the sheet is closed by the time it is said.
signal play(game: String, uid: String)

const Social = preload("res://core/social.gd")
const Share = preload("res://core/share.gd")
const Names = preload("res://versus/online/names.gd")
const Face = preload("res://ui/faces/face.gd")
const MoonFace = preload("res://ui/faces/moon_face.gd")
const Haptics = preload("res://core/haptics.gd")
const Analytics = preload("res://core/analytics.gd")
const InviteCard = preload("res://ui/menu/invite_card.gd")
const CodeDialog = preload("res://ui/menu/code_dialog.gd")
const Dialog = preload("res://ui/hud/dialog.gd")

enum State { LOADING, READY, OFFLINE }

## Seconds between two reads of the friends' presence while the sheet is up.
const REFRESH := 15.0
## How long "Link copied" and "Code copied" stand in for the words they took.
const SAID := 2.0
const SMALL_H := 104.0
const FRIEND_H := 116.0
const FRIEND_GAP := 14
const FRIEND_FACE := 84.0
const REMOVE := 72.0
## The list scrolls past this many rows; the half says there is more.
const ROWS_MAX := 5.5
const EMPTY_FACE := 150.0
const LINE_INSET := 200.0
## Who stands on the empty sheet: the hedgehog (Names.CAST).
const EMPTY_CAST := 8
const ONLINE_INK := Color("4f8a31")

var invite_button: Button
var copy_button: Button
var code_button: Button
var retry_button: Button
var state: int = State.LOADING
var _body: VBoxContainer
var _list: VBoxContainer
var _code_label: Label
var _code_caption: Label
var _code := ""
var _run := 0
var _timer: Timer
var _dialog: Control
var _asking: Control
## What each thing that says "copied" for a moment is counting (_after_said).
var _said := {}

func _build_sheet(col: VBoxContainer) -> void:
	_title_row(col, "FRIENDS_TITLE", "friends")
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", SHEET_GAP)
	col.add_child(_body)

func _ready() -> void:
	super()
	_timer = Timer.new()
	_timer.name = "Presence"
	_timer.wait_time = REFRESH
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	closed.connect(_timer.stop)
	Social.hub().changed.connect(_on_changed)

func _on_open() -> void:
	Social.enable()
	_code = ""
	state = State.LOADING
	_paint()
	_load()
	_timer.start()

## True while the code dialog is up: it says who was added itself, so the
## menu raises no new-friend card over it.
func adding() -> bool:
	return is_instance_valid(_dialog) and _dialog.is_open()

## The player's code, made on the first ask; none is what offline means here.
func _load() -> void:
	_run += 1
	var run := _run
	var code := ""
	if Social.started():
		@warning_ignore("redundant_await")
		code = await Social.my_code()
	if run != _run or not visible:
		return
	_code = code
	state = State.OFFLINE if code.is_empty() else State.READY
	_paint()
	if state == State.READY:
		_refresh()

func _refresh() -> void:
	if state != State.READY or not is_open():
		return
	@warning_ignore("redundant_await")
	await Social.refresh_presence()
	if state == State.READY and visible:
		_paint_list()

func _on_changed() -> void:
	if visible and state != State.OFFLINE:
		_paint_list()

# --- the body ---

func _paint() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_list = null
	if state == State.OFFLINE:
		_paint_offline()
		return
	invite_button = _wide_primary("share", "FRIENDS_INVITE")
	invite_button.name = "Invite"
	invite_button.pressed.connect(_share)
	_body.add_child(invite_button)
	_body.add_child(_code_tile())
	code_button = IconButton.new("plus", "FRIENDS_ENTER_CODE", "IconButton")
	code_button.name = "EnterCode"
	code_button.custom_minimum_size = Vector2(WIDE, SMALL_H)
	code_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var up := CozyTheme.soft_button(Pal.SURFACE, 28, false, 20)
	var off := CozyTheme.soft_button(Color(Pal.SURFACE, 0.55), 28, false, 20)
	off.shadow_color = Color(off.shadow_color, 0.0)
	for st in ["normal", "hover"]:
		code_button.add_theme_stylebox_override(st, up)
	code_button.add_theme_stylebox_override("pressed", CozyTheme.soft_button(Pal.SURFACE, 28, true, 20))
	code_button.add_theme_stylebox_override("disabled", off)
	code_button.pressed.connect(_enter_code)
	_body.add_child(code_button)
	_body.add_child(SheetParts.Divider.new())
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.add_theme_constant_override("separation", 16)
	_body.add_child(_list)
	var live := state == State.READY
	for b: Button in [invite_button, copy_button, code_button]:
		b.set_enabled(live)
	_paint_list()

func _paint_offline() -> void:
	var face := MoonFace.new()
	face.expression = Face.Expr.SLEEPY
	_body.add_child(_seat(face, EMPTY_FACE))
	var head := Label.new()
	head.text = "VS_OFFLINE"
	head.theme_type_variation = "DayBig"
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(head)
	_body.add_child(_line("FRIENDS_OFFLINE"))
	retry_button = _wide_primary("reset", "FRIENDS_RETRY")
	retry_button.name = "Retry"
	retry_button.pressed.connect(func() -> void:
		state = State.LOADING
		_paint()
		_load())
	_body.add_child(retry_button)

## The player's own code on a white tile, spelled wide, with the copy button.
func _code_tile() -> Control:
	var tile := PanelContainer.new()
	tile.name = "Code"
	var face := Dialog.tile(Pal.SURFACE, 18)
	face.content_margin_left = 32
	face.content_margin_right = 22
	tile.add_theme_stylebox_override("panel", face)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	tile.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", -4)
	row.add_child(words)
	_code_caption = Label.new()
	_code_caption.text = "FRIENDS_YOUR_CODE"
	_code_caption.add_theme_font_override("font", CozyTheme.body(700))
	_code_caption.add_theme_font_size_override("font_size", 27)
	_code_caption.add_theme_color_override("font_color", Pal.TEXT_DIM)
	words.add_child(_code_caption)
	_code_label = Label.new()
	_code_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_code_label.text = _code if not _code.is_empty() else "· · · ·"
	_code_label.add_theme_font_override("font", CozyTheme.display(700, 8))
	_code_label.add_theme_font_size_override("font_size", 54)
	_code_label.add_theme_color_override("font_color", Pal.TEXT if not _code.is_empty() else Pal.LINE)
	words.add_child(_code_label)
	copy_button = IconButton.new("copy", "", "IconButton")
	copy_button.name = "Copy"
	copy_button.custom_minimum_size = Vector2(X_SIZE, X_SIZE)
	copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(X_SIZE * 0.5)
	for s in ["normal", "hover", "disabled"]:
		copy_button.add_theme_stylebox_override(s, CozyTheme.soft_button(Pal.SUN_TILE, r, false, 0))
	copy_button.add_theme_stylebox_override("pressed", CozyTheme.soft_button(Pal.SUN_TILE, r, true, 0))
	copy_button.pressed.connect(_copy)
	row.add_child(copy_button)
	return tile

## The friends, oldest first, or the line that says how to have one. Past
## ROWS_MAX rows they scroll.
func _paint_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var friends := Social.friends()
	if friends.is_empty():
		if state == State.LOADING and not Social.loaded():
			return
		var face := Names.CAST[EMPTY_CAST][1].new() as Control
		_list.add_child(_seat(face, EMPTY_FACE))
		_list.add_child(_line("FRIENDS_EMPTY"))
		return
	var online := 0
	for uid in friends:
		if Social.is_online(uid):
			online += 1
	var count := Label.new()
	count.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	count.text = _counted("FRIENDS_COUNT", friends.size())
	if online > 0:
		count.text += "  ·  " + _counted("FRIENDS_ONLINE", online)
	count.add_theme_font_override("font", CozyTheme.body(700))
	count.add_theme_font_size_override("font_size", 28)
	count.add_theme_color_override("font_color", Pal.TEXT_DIM)
	_list.add_child(count)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", FRIEND_GAP)
	for uid in friends:
		rows.add_child(_friend_row(uid))
	var shown := minf(float(friends.size()), ROWS_MAX)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if float(friends.size()) <= ROWS_MAX:
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The rows' shadows hang a little under them.
	scroll.custom_minimum_size.y = shown * FRIEND_H + (ceilf(shown) - 1.0) * FRIEND_GAP + 12.0
	scroll.add_child(rows)
	_list.add_child(scroll)

func _counted(key: String, n: int) -> String:
	return tr(key + ("_ONE" if n == 1 else "_N")) % n

func _friend_row(uid: String) -> Control:
	var on := Social.is_online(uid)
	var tile := PanelContainer.new()
	tile.name = "Friend_" + uid
	tile.custom_minimum_size.y = FRIEND_H
	# A drag that starts on a row still scrolls the list.
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	var paper := CozyTheme.lifted(Pal.SURFACE, 26, 14)
	paper.content_margin_left = 20
	paper.content_margin_right = 18
	tile.add_theme_stylebox_override("panel", paper)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 18)
	tile.add_child(row)
	var face := Names.face_of(uid)
	if not on:
		face.expression = Face.Expr.SLEEPY
	var seat := _seat(face, FRIEND_FACE)
	seat.custom_minimum_size.x = FRIEND_FACE
	seat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seat)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", -2)
	row.add_child(words)
	var name_l := Label.new()
	name_l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name_l.text = Names.name_of(uid)
	name_l.add_theme_font_override("font", CozyTheme.body(800))
	name_l.add_theme_font_size_override("font_size", 36)
	name_l.add_theme_color_override("font_color", Pal.TEXT)
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_l.clip_text = true
	words.add_child(name_l)
	var status := HBoxContainer.new()
	status.add_theme_constant_override("separation", 10)
	words.add_child(status)
	# Online is a filled dot and its word, Away a ring and its word: never the
	# colour alone.
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(18, 18)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.draw.connect(func() -> void:
		var c := dot.size * 0.5
		if on:
			dot.draw_circle(c, 8.0, Pal.GOOD, true, -1.0, true)
		else:
			dot.draw_arc(c, 6.5, 0.0, TAU, 20, Pal.LINE, 2.5, true))
	status.add_child(dot)
	var status_l := Label.new()
	status_l.text = "FRIENDS_STATUS_ONLINE" if on else "FRIENDS_STATUS_AWAY"
	status_l.add_theme_font_override("font", CozyTheme.body(700))
	status_l.add_theme_font_size_override("font_size", 27)
	status_l.add_theme_color_override("font_color", ONLINE_INK if on else Pal.TEXT_DIM)
	status.add_child(status_l)
	for c: Control in [words, name_l, status, dot, status_l]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The sun for a friend who is here now, paper for one who may not answer.
	var go := IconButton.new("play", tr("VS_PLAY"), "SunButton" if on else "IconButton")
	go.name = "Play"
	go.custom_minimum_size.y = 84.0
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 34)
	go.pressed.connect(_pick_game.bind(uid))
	row.add_child(go)
	var x := IconButton.new("cross", "", "IconButton")
	x.name = "Remove"
	x.custom_minimum_size = Vector2(REMOVE, REMOVE)
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var r := int(REMOVE * 0.5)
	for s in ["normal", "hover", "disabled"]:
		x.add_theme_stylebox_override(s, CozyTheme.soft_button(Pal.PAPER, r, false, 0))
	x.add_theme_stylebox_override("pressed", CozyTheme.soft_button(Pal.PAPER, r, true, 0))
	x.add_theme_color_override("font_color", Pal.TEXT_DIM)
	x.pressed.connect(_ask_remove.bind(uid))
	row.add_child(x)
	return tile

## A face standing in the middle of a row of its own height.
func _seat(face: Control, side: float) -> Control:
	var seat := Control.new()
	seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.custom_minimum_size = Vector2(side, side)
	face.size = Vector2(side, side)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seat.add_child(face)
	seat.resized.connect(func() -> void: face.position = (seat.size - face.size) * 0.5)
	return seat

func _line(key: String) -> Label:
	var l := Label.new()
	l.text = key
	l.theme_type_variation = "SheetBodyDim"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Narrower than the card, so two lines break near their middle.
	l.custom_minimum_size.x = content_width() - LINE_INSET
	l.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return l

# --- what the buttons do ---

## The link, out through the phone's share sheet; where there is none it is on
## the clipboard and the button says so for a moment.
func _share() -> void:
	if _code.is_empty():
		return
	var took := Share.text(tr("FRIENDS_INVITE_TEXT") % Social.link(_code), tr("FRIENDS_INVITE"))
	Analytics.track("friends_invite_shared", {"how": "sheet" if took else "copy"})
	if took:
		return
	invite_button.set_icon("check")
	invite_button.set_label(tr("FRIENDS_LINK_COPIED"))
	_after_said("link", func() -> void:
		invite_button.set_icon("share")
		invite_button.set_label(tr("FRIENDS_INVITE")))

func _copy() -> void:
	if _code.is_empty():
		return
	DisplayServer.clipboard_set(_code)
	Analytics.track("friends_invite_shared", {"how": "copy"})
	_code_caption.text = "FRIENDS_CODE_COPIED"
	_code_caption.add_theme_color_override("font_color", ONLINE_INK)
	copy_button.set_icon("check")
	_after_said("code", func() -> void:
		_code_caption.text = "FRIENDS_YOUR_CODE"
		_code_caption.add_theme_color_override("font_color", Pal.TEXT_DIM)
		copy_button.set_icon("copy"))

## Runs `back` once SAID has passed, unless the body was painted again or
## the same thing was pressed again since.
func _after_said(what: String, back: Callable) -> void:
	var run := int(_said.get(what, 0)) + 1
	_said[what] = run
	var holds := invite_button
	get_tree().create_timer(SAID).timeout.connect(func() -> void:
		if run == int(_said.get(what, 0)) and is_instance_valid(holds) and holds == invite_button:
			back.call())

func _enter_code() -> void:
	if adding():
		return
	_dialog = CodeDialog.new()
	add_child(_dialog)

func _pick_game(uid: String) -> void:
	if _up():
		return
	_asking = InviteCard.pick(uid)
	# versus_friend_invite is Online's, sent as the asking begins.
	_asking.play.connect(func(game: String) -> void:
		close_then(func() -> void: play.emit(game, uid)))
	add_child(_asking)

func _ask_remove(uid: String) -> void:
	if _up():
		return
	_asking = InviteCard.remove(uid)
	_asking.confirmed.connect(func() -> void:
		Haptics.play(Haptics.TICK)
		@warning_ignore("redundant_await")
		var went: bool = await Social.remove(uid)
		if went:
			Analytics.track("friends_removed"))
	add_child(_asking)

## A card of this sheet's own is already up.
func _up() -> bool:
	return is_instance_valid(_asking) and _asking.is_open()
