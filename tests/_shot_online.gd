extends SceneTree

## Versus online, shot with nobody on the other end: the Match is
## tests/_fake_match.gd, handed to versus/online/online.gd as its stand-in,
## and says what this harness tells it to. No network, no Backend.
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top \
##         --script res://tests/_shot_online.gd -- <outdir> [lang=pt|es] [rm] [tab]
##
## 01 the tab with chess on its Online chip, 02 looking, 03 nobody around,
## 04 no connection, 05 found, 06 the board mid-game with the clock quiet,
## 07 the clock warning, 08 the dialog Back asks with, 09 the end card for a
## timeout, 10 for a player who left, 11 for a resignation, 12 a loss on the
## clock, 13 the computer's game after the offline card's Play the computer;
## then it checks that Cancel while looking closes the screen. `tab` stops
## after 01. `rm` is reduce motion. Prints the draw calls at each
## shot. user://versus.cfg is put back at the end.

const Rules = preload("res://versus/chess_rules.gd")
const Fake = preload("res://tests/_fake_match.gd")
const Record = preload("res://versus/versus_record.gd")

const RIVAL := "shot-rival-uid-7"

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _lang := ""
var _tab_only := false
var _rm := false
var _quiet := false
var _step := 0
var _wait := 0.0
var _poked := false
var _had := false
var _saved := ""

func _initialize() -> void:
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_saved = FileAccess.get_file_as_string("user://versus.cfg")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("lang="):
			_lang = a.substr(5)
		elif a == "rm":
			_rm = true
		elif a == "tab":
			_tab_only = true
		else:
			_out = a
	if _lang != "":
		# world/main.gd applies Locale.current() as it enters the tree; this is
		# what that reads, and nothing is saved.
		load("res://core/locale.gd")._current = _lang
	load("res://versus/online/online.gd").stand_in = Fake
	var main: Node = load("res://world/main.tscn").instantiate()
	root.add_child(main)
	_menu = main.get_node("UI/Menu")

func _done() -> void:
	if _had:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_saved)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
	quit()

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	var tag := "" if _lang == "" else "_" + _lang
	root.get_texture().get_image().save_png("%s/onl_%s%s.png" % [_out, name, tag])
	print("shot %s at %.1f draws=%d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _fake() -> Node:
	return _s.online._match

func sq(n: String) -> int:
	return "abcdefgh".find(n[0]) + (int(n[1]) - 1) * 8

func find(a: String, b: String) -> int:
	for m in _s.rules.legal_moves():
		if Rules.mv_from(m) == sq(a) and Rules.mv_to(m) == sq(b):
			return m
	return -1

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

func _process(delta: float) -> bool:
	if not _quiet:
		# Here and not in _initialize: the main scene enters the tree only once
		# the loop starts, and it is what starts these and loads the settings.
		_quiet = true
		load("res://core/backend.gd").stop()
		load("res://core/analytics.gd").stop()
		if _rm:
			load("res://core/motion.gd").reduce = true
	_t += delta
	if _t < _wait:
		return false
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("versus")
				_step = 1
				_wait = _t + 0.6
		1:
			if _beat(0.6, func() -> void: _menu.versus_tab._pick("chess", Record.ONLINE), "01_tab"):
				_step = 99 if _tab_only else 2
		2:
			if _beat(0.7, func() -> void:
					_menu._open_versus("chess", Record.ONLINE)
					_s = _menu.get_node("Chess"), "02_looking"):
				_step = 3
		3:
			if _beat(0.5, func() -> void: _fake().say_nobody(), "03_nobody"):
				_step = 4
		4:
			if _beat(0.5, func() -> void: _fake().say_offline(), "04_offline"):
				_step = 5
		5:
			# Back to looking (the offline card's own way there is a new screen).
			if _beat(0.6, func() -> void:
					_s.online.open()
					_fake().say_found(0, 0, RIVAL), "05_found"):
				_step = 6
		6:
			if _s._state == _s.State.YOURS:
				print("reduce motion %s, backend started %s, analytics started %s" % [
					load("res://core/motion.gd").reduce, load("res://core/backend.gd").started(),
					load("res://core/analytics.gd").started()])
				_s._on_chosen(find("e2", "e4"))
				_step = 7
		7:
			if _s._state == _s.State.THINK and not _s.board.is_busy():
				_fake().say_move({"m": find("e7", "e5")})
				_step = 8
		8:
			if _s._state == _s.State.YOURS and not _s.board.is_busy():
				_s._on_chosen(find("g1", "f3"))
				_step = 9
		9:
			if _s._state == _s.State.THINK and not _s.board.is_busy():
				_fake().say_move({"m": find("b8", "c6")})
				_step = 10
		10:
			if _s._state == _s.State.YOURS and not _s.board.is_busy():
				if _beat(2.6, func() -> void: _fake().say_clock(42), "06_board_quiet"):
					_step = 11
		11:
			if _beat(0.5, func() -> void: _fake().say_clock(9), "07_board_warning"):
				_step = 12
		12:
			if _beat(0.5, func() -> void: _s._on_back(), "08_resign_dialog"):
				_step = 13
		13:
			if _beat(2.8, func() -> void:
					_s.go_back()  # Android's back closes the dialog
					_fake().say_ended(0, "timeout"), "09_end_timeout"):
				_step = 14
		14:
			if _again(15):
				_fake().say_ended(0, "left")
		15:
			if _beat(2.8, func() -> void: pass, "10_end_left"):
				_step = 16
		16:
			if _again(17):
				_fake().say_ended(0, "resign")
		17:
			if _beat(2.8, func() -> void: pass, "11_end_resign"):
				_step = 18
		18:
			# A loss on the clock, for the other wording and the rival's face.
			if _again(19):
				_fake().say_ended(1, "timeout")
		19:
			if _beat(2.8, func() -> void: pass, "12_end_timeout_lost"):
				_step = 20
		20:
			# Find another, no network this time, and the card's Play the
			# computer: a normal game at the level last played against it.
			if _beat(2.2, func() -> void:
					_press(_s._end, 0)
					_fake().say_offline()
					_press(_s.get_node("Lobby"), 0), "13_computer"):
				print("play the computer: %s (level %d, last against the computer %d, online %s, far seat %s)" % [
					"ok" if _s.online == null and _s.level == Record.last_bot_level("chess") \
						and _s._state != _s.State.WAIT else "FAILED",
					_s.level, Record.last_bot_level("chess"), _s.online, _s._names[1].text])
				_step = 21
		21:
			# And Cancel while looking: the screen closes, back to the tab.
			_s.closed.emit()
			_step = 22
			_wait = _t + 0.4
		22:
			_menu._open_versus("chess", Record.ONLINE)
			_s = _menu.get_node("Chess")
			_step = 23
			_wait = _t + 0.4
		23:
			_press(_s.get_node("Lobby"), 0)
			_step = 24
			_wait = _t + 0.4
		24:
			print("cancel: %s" % ("ok" if not is_instance_valid(_s) and _menu.get_node_or_null("Chess") == null \
				and _menu.versus_tab.is_visible_in_tree() else "FAILED"))
			_step = 99
		99:
			_done()
			_step = 100
	return false

## Presses button `i` of a card's stack (Dialog.buttons).
func _press(card: Node, i: int) -> void:
	var b: Button = card.find_child("Buttons", true, false).get_child(i)
	b.pressed.emit()

## Presses Find another on the end card, finds the same rival again and
## waits for the board to be ready; true once it is, moving on to `next`.
func _again(next: int) -> bool:
	if not is_instance_valid(_s._end) and _s._state == _s.State.OVER:
		return false  # the card is still on its way
	if _s._state == _s.State.OVER:
		var b: Button = _s._end.find_child("Buttons", true, false).get_child(0)
		b.pressed.emit()
		_fake().say_found(0, 0, RIVAL)
		return false
	if _s._state != _s.State.YOURS:
		return false
	_step = next
	_wait = _t + 0.2
	return true
