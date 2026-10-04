extends SceneTree

## The friends' screens, shot with nobody on the other end: Social answers
## from `Social.fake(...)`, the Match is tests/_fake_match.gd, and the main
## scene is built with tests/_offline_main.gd on it, so Analytics, Backend,
## Ads and Social are never started (the first frame prints that they are not,
## and the harness quits there if one is).
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top \
##         --script res://tests/_shot_friends.gd -- <outdir> [lang=pt|es] [rm]
##
## 01 the Versus tab with its Friends row (five friends, two online), 02 the
## sheet with them, 03 after Invite and the copy button ("Link copied", "Code
## copied"), 04 the picker Play leads to, 05 the question before a remove, 06
## the sheet with one fewer; 07 the sheet with nobody yet, 08 the code dialog,
## 09-12 its refusals (unknown, your own, already, offline -- the last is said
## by hand: the fake never answers it), 13 Paste with no code on the clipboard,
## 14 a pasted link added, 15 the sheet with that friend; 16 the sheet
## offline; 17 an invite card over the tab, 18 one over a board, 19 the lobby
## waiting after its Play closed the board, 20 the lobby after the picker's
## asking, 21 no answer, 22 gone; 23 the new friend card, 24 its picker; 25 the
## line an invite link that failed says. Prints the draw calls at each shot and
## the checks along the way (FAILED on a line is a failure).
## user://versus.cfg, user://friends.cfg and the clipboard are put back.

const Fake = preload("res://tests/_fake_match.gd")
const Social = preload("res://core/social.gd")
const Share = preload("res://core/share.gd")
const Record = preload("res://versus/versus_record.gd")
const Registry = preload("res://ui/registry.gd")
const InviteCard = preload("res://ui/menu/invite_card.gd")

const ME := "K7M2QX9P"
const FIVE := ["shot-uid-berry-7", "a-friend-of-mine", "third-one-here-22", "uid-number-four", "the-fifth-friend-x"]
const ONLINE := ["shot-uid-berry-7", "uid-number-four"]
const NEW := "shot-friend-new"
const NEW_CODE := "HEDG3H2G"
const KEPT := ["user://versus.cfg", "user://friends.cfg"]

var _menu: Node
var _sheet: Node
var _t := 0.0
var _out := "/tmp"
var _lang := ""
var _rm := false
var _quiet := false
var _step := 0
var _wait := 0.0
var _poked := false
var _saved := {}
var _clip := ""

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	for path: String in KEPT:
		if FileAccess.file_exists(path):
			_saved[path] = FileAccess.get_file_as_string(path)
	_clip = DisplayServer.clipboard_get()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			_lang = a.substr(5)
		elif a == "rm":
			_rm = true
		else:
			_out = a
	if _lang != "":
		load("res://core/locale.gd")._current = _lang
	load("res://versus/online/online.gd").stand_in = Fake
	_fake_five()
	var main: Node = load("res://world/main.tscn").instantiate()
	# world/main.gd's _ready is what starts Analytics, Backend, Ads and Social,
	# against the live project: this is main without it.
	main.set_script(load("res://tests/_offline_main.gd"))
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _fake_five() -> void:
	Social.fake({"code": ME, "friends": FIVE, "online": ONLINE,
		"codes": {NEW_CODE: NEW, "AAAA2222": FIVE[0]}, "invites": {}})

func _done() -> void:
	for path: String in KEPT:
		if _saved.has(path):
			var f := FileAccess.open(path, FileAccess.WRITE)
			f.store_string(_saved[path])
			f.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DisplayServer.clipboard_set(_clip)
	quit()

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var tag := "" if _lang == "" else "_" + _lang
	if _rm:
		tag += "_rm"
	root.get_texture().get_image().save_png("%s/fr_%s%s.png" % [_out, name, tag])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

## Each step pokes on one frame and is shot `hold` seconds later, on a frame
## of its own.
func _beat(hold: float, poke: Callable, name: String) -> bool:
	if not _poked:
		_poked = true
		poke.call()
		_wait = _t + hold
		return false
	_poked = false
	_shot(name)
	return true

func _check(what: String, ok: bool) -> void:
	print("%s: %s" % [what, "ok" if ok else "FAILED"])

func _dialog() -> Node:
	return _sheet.get_node_or_null("CodeDialog")

func _type(code: String) -> void:
	var d := _dialog()
	d.field.text = code
	d._on_typed(code)
	d.add_button.pressed.emit()

func _friend_button(uid: String, which: String) -> Button:
	return _sheet.find_child("Friend_" + uid, true, false).find_child(which, true, false)

func _card() -> Node:
	return _menu.friend_card if is_instance_valid(_menu.friend_card) else null

func _card_up() -> bool:
	return _card() != null and _card().is_open()

func _press(card: Node, i: int) -> void:
	var b: Button = card.find_child("Buttons", true, false).get_child(i)
	b.pressed.emit()

func _lobby() -> Node:
	var s := _menu.get_node_or_null("Chess")
	return s.get_node_or_null("Lobby") if s != null else null

func _process(delta: float) -> bool:
	if not _quiet:
		_quiet = true
		var live := [load("res://core/backend.gd").started(), load("res://core/analytics.gd").started(),
			bool(root.get_node("Ads")._started), bool(Social._started)]
		print("first frame: backend started %s, analytics started %s, ads started %s, social started %s" % live)
		if live.has(true):
			print("FAILED: the main scene started the network; stopping and quitting")
			load("res://core/backend.gd").stop()
			load("res://core/analytics.gd").stop()
			_done()
			return true
		if _rm:
			load("res://core/motion.gd").reduce = true
		_sheet = _menu.friends_sheet
	_t += delta
	if _t < _wait:
		return false
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("versus")
				_step = 1
				_wait = _t + 0.8
		1:
			if _beat(0.2, func() -> void: pass, "01_tab"):
				var tab: Control = _menu.versus_tab
				var bar: Control = _menu.bar
				print("tab: row %.0f tall, the tab's foot %.0f, the bar's top %.0f, blurbs shown %s, art %.0f" % [
					tab.friends_row.size.y, tab.global_position.y + tab.size.y, bar.global_position.y,
					tab._blurbs[0].visible, tab._arts[0].size.y])
				_check("the tab ends above the bar", tab.global_position.y + tab.size.y <= bar.global_position.y + 0.5)
				_step = 2
		2:
			if _beat(0.9, func() -> void: _menu.versus_tab.friends_row.pressed.emit(), "02_sheet_friends"):
				_step = 3
		3:
			if _beat(0.4, func() -> void:
					_sheet.invite_button.pressed.emit()
					_sheet.copy_button.pressed.emit(), "03_copied"):
				_check("share fell to the clipboard", Share.last == "clipboard")
				_check("the code is on the clipboard", DisplayServer.clipboard_get() == ME)
				_step = 4
		4:
			if _beat(0.6, func() -> void: _friend_button(FIVE[0], "Play").pressed.emit(), "04_picker"):
				_step = 5
		5:
			if _beat(0.6, func() -> void:
					_menu.go_back()  # Android's back closes the picker, not the sheet
					_friend_button(FIVE[2], "Remove").pressed.emit(), "05_remove_ask"):
				_check("back closed the picker and left the sheet", _sheet.is_open())
				_step = 6
		6:
			if _beat(0.6, func() -> void: _press(_sheet._asking, 1), "06_removed"):
				_check("removed", not Social.is_friend(FIVE[2]) and Social.friends().size() == 4)
				_step = 7
		7:
			if _beat(1.2, func() -> void:
					_sheet.close()
					Social.fake({"code": ME, "friends": [], "online": [],
						"codes": {NEW_CODE: NEW}, "invites": {}})
					Social.hub().changed.emit(), "07_tab_nobody"):
				_step = 8
		8:
			if _beat(0.9, func() -> void: _menu.versus_tab.friends_row.pressed.emit(), "07_sheet_empty"):
				_step = 9
		9:
			if _beat(0.6, func() -> void: _sheet.code_button.pressed.emit(), "08_code_dialog"):
				_step = 10
		10:
			if _beat(0.5, func() -> void: _type("zzzz-2222"), "09_code_unknown"):
				_check("typed code is cleaned", _dialog().field.text == "ZZZZ2222")
				_step = 11
		11:
			if _beat(0.5, func() -> void: _type(ME), "10_code_self"):
				_step = 12
		12:
			if _beat(0.5, func() -> void:
					Social._fake.codes["AAAA2222"] = NEW
					Social._friends.append(NEW)
					_type("AAAA2222")
					Social._friends.erase(NEW), "11_code_already"):
				_step = 13
		13:
			if _beat(0.5, func() -> void: _dialog()._say("FRIENDS_ADD_OFFLINE", _dialog().Pal.BERRY_DEEP), "12_code_offline"):
				_step = 14
		14:
			if _beat(0.5, func() -> void:
					DisplayServer.clipboard_set("see you at eight")
					_dialog().paste_button.pressed.emit(), "13_paste_nothing"):
				_step = 15
		15:
			if _beat(0.6, func() -> void:
					DisplayServer.clipboard_set(Social.link(NEW_CODE))
					_dialog().paste_button.pressed.emit()
					_dialog().add_button.pressed.emit(), "14_code_added"):
				_check("a pasted link added the friend", Social.is_friend(NEW))
				_check("no new-friend card over the dialog", not _card_up())
				_step = 16
		16:
			if _beat(0.6, func() -> void: _menu.go_back(), "15_sheet_one"):
				_check("back closed the dialog and left the sheet", _dialog() == null or not _dialog().is_open())
				_step = 17
		17:
			if _beat(1.2, func() -> void:
					_sheet.close()
					Social._faked = false, "15b_closed"):
				_step = 18
		18:
			if _beat(0.9, func() -> void: _menu.versus_tab.friends_row.pressed.emit(), "16_sheet_offline"):
				_check("offline offers only Try again", _sheet.state == _sheet.State.OFFLINE \
					and _sheet.find_child("Invite", true, false) == null)
				_step = 19
		19:
			if _beat(1.0, func() -> void:
					_sheet.close()
					_fake_five()
					Social.hub().changed.emit()
					Social._invites[FIVE[3]] = "chess"
					Social.hub().invited.emit(FIVE[3], "chess"), "17_invite"):
				_step = 20
		20:
			# The invite is taken back: the card goes by itself.
			_poke_once(func() -> void:
				Social._invites.erase(FIVE[3])
				Social.hub().withdrawn.emit(FIVE[3]), 0.5)
			if not _poked:
				_check("withdrawn took the card down", not _card_up())
				_step = 21
		21:
			# Over a board, and Not now through Android's back.
			if _beat(1.2, func() -> void:
					_menu._show_tab("home")
					_menu._open_at(Registry.PUZZLES[0], 1)
					Social._invites[FIVE[0]] = "checkers"
					Social.hub().invited.emit(FIVE[0], "checkers"), "18_invite_over_board"):
				_check("the card is the menu's last child", _menu.get_child(_menu.get_child_count() - 1) == _card())
				_menu.go_back()
				_check("back said not now", Social.invite_from(FIVE[0]) == "" and not _card_up())
				_step = 22
		22:
			if _beat(1.0, func() -> void:
					Social._invites[FIVE[3]] = "chess"
					Social.hub().invited.emit(FIVE[3], "chess")
					_press(_card(), 0), "19_lobby_accepting"):
				var s := _menu.get_node_or_null("Chess")
				var hosts := 0
				for c in _menu.get_children():
					if c.is_in_group("puzzle_host") and not c.is_queued_for_deletion():
						hosts += 1
				_check("Play closed the board and opened chess", s != null and hosts == 0)
				_check("chess is with the friend, accepting", s != null and s.online != null \
					and s.online.friend == FIVE[3] and s.online._match.accepting and s.level == Record.ONLINE)
				_step = 23
		23:
			# That game is closed; the sheet's way in: Play, a game, the lobby.
			_poke_once(func() -> void:
				_menu.get_node("Chess").closed.emit()
				_menu.versus_tab.friends_row.pressed.emit(), 0.9)
			if not _poked:
				_step = 24
		24:
			_poke_once(func() -> void:
				_friend_button(FIVE[0], "Play").pressed.emit()
				_sheet._asking.find_child("Pick_chess", true, false).pressed.emit(), 0.1)
			if not _poked:
				_step = 25
		25:
			if _beat(1.4, func() -> void: pass, "20_lobby_waiting"):
				var s := _menu.get_node_or_null("Chess")
				_check("the picker opened chess asking the friend", s != null and s.online != null \
					and s.online.friend == FIVE[0] and not s.online._match.accepting and not _sheet.visible)
				_step = 26
		26:
			if _beat(0.6, func() -> void: _menu.get_node("Chess").online._match.say_nobody(), "21_lobby_no_answer"):
				_step = 27
		27:
			if _beat(0.6, func() -> void: _menu.get_node("Chess").online._match.say_gone("declined"), "22_lobby_gone"):
				_step = 28
		28:
			if _beat(1.0, func() -> void:
					_menu.get_node("Chess").closed.emit()
					Social._friends.append(NEW)
					Social.hub().befriended.emit(NEW), "23_new_friend"):
				_step = 29
		29:
			if _beat(0.6, func() -> void: _press(_card(), 0), "24_new_friend_picker"):
				_step = 30
		30:
			if _beat(0.8, func() -> void:
					_menu.go_back()
					_menu.friend_link_failed("unknown"), "25_link_failed"):
				_check("back closed the picker", not _card_up())
				_step = 99
		99:
			_done()
			_step = 100
	return false

## A step with nothing to shoot: pokes on one frame and is over `hold` later.
func _poke_once(poke: Callable, hold: float) -> void:
	if not _poked:
		_poked = true
		poke.call()
		_wait = _t + hold
		return
	_poked = false
