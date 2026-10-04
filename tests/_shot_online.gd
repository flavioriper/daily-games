extends SceneTree

## Versus online, shot with nobody on the other end: the Match is
## tests/_fake_match.gd, handed to versus/online/online.gd as its stand-in,
## and says what this harness tells it to. No network, no Backend: the main
## scene is built with tests/_offline_main.gd on it, so Analytics, Backend and
## Ads are never started (the first frame prints that they are not, and the
## harness quits there if one is).
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top \
##         --script res://tests/_shot_online.gd -- <outdir> [lang=pt|es] [rm] [tab] [checkers] [snooker]
##
## 01 the tab with chess on its Online chip, 02 looking, 03 nobody around,
## 04 no connection, 05 found, 06 the board mid-game with the clock quiet,
## 07 the clock warning, 08 the dialog Back asks with, 09 the end card for a
## timeout, 10 for a player who left, 11 for a resignation, 12 a loss on the
## clock, 13 the computer's game after the offline card's Play the computer;
## then it checks that Cancel while looking closes the screen. `tab` stops
## after 01. Then checkers (`checkers` alone skips chess): c02 looking, c06 the
## board mid-game after a capture each way with the clock quiet on your move,
## c07 after your man has taken two and been crowned, the clock warning on the
## other player's move, c09 the end card for a player who left, c12 a loss by
## resignation with the other player's face. Then snooker (`snooker` alone skips
## the other two; `checkers` alone stops before it): s02 looking over the racked
## table, s05 the other player aiming their break with their clock, s06 the cue
## showing their shot, s07 your turn with the clock quiet after their table has
## been taken, s08 the clock warning, s09 the end card for a player who left,
## s12 a loss by resignation. The other player's shot is the computer's break,
## rolled here on a copy and refereed there, as their end would.
## `rm` is reduce motion. Prints the draw calls at each
## shot. user://versus.cfg is put back at the end.

const Rules = preload("res://versus/chess_rules.gd")
const Fake = preload("res://tests/_fake_match.gd")
const Record = preload("res://versus/versus_record.gd")
const Sim = preload("res://versus/snooker_sim.gd")
const SnRules = preload("res://versus/snooker_rules.gd")
const SnAI = preload("res://versus/snooker_ai.gd")

const RIVAL := "shot-rival-uid-7"
## Checkers' line, as tests/_probe_online.gd plays it: this seat opens.
const CK_LINE := [
	[18, 1, 25], [43, 1, 34], [25, 1, 43, 34], [50, 1, 36, 43],
	[20, 1, 29], [57, 1, 50], [29, 2, 43, 57, 36, 50],
]

var _menu: Node
var _s: Node
var _t := 0.0
var _out := "/tmp"
var _lang := ""
var _tab_only := false
var _ck_only := false
var _sn_only := false
## The table the other player's end sends once its shot has stopped.
var _their_table := {}
var _ply := 0
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
		elif a == "checkers":
			_ck_only = true
		elif a == "snooker":
			_sn_only = true
		else:
			_out = a
	if _lang != "":
		# world/main.gd applies Locale.current() as it enters the tree; this is
		# what that reads, and nothing is saved.
		load("res://core/locale.gd")._current = _lang
	load("res://versus/online/online.gd").stand_in = Fake
	var main: Node = load("res://world/main.tscn").instantiate()
	# world/main.gd's _ready is what starts Analytics, Backend and Ads, and
	# against the live project: this is main without it.
	main.set_script(load("res://tests/_offline_main.gd"))
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
		# the loop starts, and it is what loads the settings. By now its _ready
		# has run; nothing may have been started by it.
		_quiet = true
		var live := _started()
		print("first frame: backend started %s, analytics started %s, ads started %s" % live)
		if live.has(true):
			print("FAILED: the main scene started the network; stopping and quitting")
			load("res://core/backend.gd").stop()
			load("res://core/analytics.gd").stop()
			_done()
			return true
		if _rm:
			load("res://core/motion.gd").reduce = true
	_t += delta
	if _t < _wait:
		return false
	match _step:
		0:
			if _t > 0.8:
				_menu._show_tab("versus")
				_step = 40 if _sn_only else (30 if _ck_only else 1)
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
				_say_quiet()
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
			_step = 30
		30:
			if _beat(0.7, func() -> void:
					_menu._open_versus("checkers", Record.ONLINE)
					_s = _menu.get_node("Checkers")
					_ply = 0, "c02_looking"):
				_fake().say_found(0, 0, RIVAL)
				_step = 31
		31:
			# The line's first four plies: a capture each way.
			if _ck_line(4):
				_say_quiet()
				_step = 32
		32:
			if _beat(2.6, func() -> void: _fake().say_clock(42), "c06_board_quiet"):
				_step = 33
		33:
			# On to the seventh: this seat's man takes two and is crowned.
			if _ck_line(7):
				_step = 34
		34:
			if _s._state == _s.State.THINK and not _s.board.is_busy():
				if _beat(1.2, func() -> void: _fake().say_clock(9), "c07_board_crowned_warning"):
					print("checkers sent: %s" % [_fake().sent])
					_step = 35
		35:
			if _beat(3.4, func() -> void: _fake().say_ended(0, "left"), "c09_end_left"):
				_step = 36
		36:
			if _again(37):
				_fake().say_ended(1, "resign")
		37:
			if _beat(3.4, func() -> void: pass, "c12_end_resign_lost"):
				_step = 99 if _ck_only else 40
		40:
			if is_instance_valid(_s):
				_s.closed.emit()
			_step = 41
			_wait = _t + 0.4
		41:
			if _beat(0.7, func() -> void:
					_menu._open_versus("snooker", Record.ONLINE)
					_s = _menu.get_node("Snooker"), "s02_looking"):
				# The other player opens: this end watches the break.
				_fake().say_found(0, 1, RIVAL)
				_step = 42
		42:
			if _s._state == _s.State.THINK:
				if _beat(0.5, func() -> void:
						_say_quiet()
						_fake().say_clock(37), "s05_rival_aiming"):
					_step = 43
		43:
			if _beat(1.0, _their_shot, "s06_rival_shot"):
				_step = 44
		44:
			if _s._state == _s.State.SETTLE:
				_fake().say_move(_their_table)
				_step = 45
		45:
			if _s._state == _s.State.AIM:
				if _beat(1.0, func() -> void: _fake().say_clock(42), "s07_your_turn"):
					print("snooker: %d shots, score %s, their roll here ended %.6f mm from theirs (%d slid)" % [
						_s._shots, _s.rules.scores, float(_s.drift.worst) * 1000.0, int(_s.drift.moved)])
					_step = 46
			elif _s._state == _s.State.THINK:
				print("snooker: the break kept the other player at the table; no turn of yours to shoot")
				_step = 47
		46:
			if _beat(0.5, func() -> void: _fake().say_clock(9), "s08_your_turn_warning"):
				_step = 47
		47:
			if _beat(1.0, func() -> void: _fake().say_ended(0, "left"), "s09_end_left"):
				_step = 48
		48:
			_press(_s._end, 0)
			_fake().say_found(0, 0, RIVAL)
			_step = 49
		49:
			if _s._state == _s.State.AIM:
				_step = 50
				_wait = _t + 0.6
		50:
			if _beat(1.0, func() -> void: _fake().say_ended(1, "resign"), "s12_end_resign_lost"):
				_step = 99
		99:
			_done()
			_step = 100
	return false

func _say_quiet() -> void:
	print("reduce motion %s, backend started %s, analytics started %s, ads started %s" % ([
		load("res://core/motion.gd").reduce] + _started()))

## Whether Backend, Analytics and the Ads autoload have been started.
func _started() -> Array:
	return [load("res://core/backend.gd").started(), load("res://core/analytics.gd").started(),
		bool(root.get_node("Ads")._started)]

## The other player's break: the computer's, sent as their end sends a shot,
## and the table their end will send after it -- the same shot rolled on a
## copy and refereed from their side.
func _their_shot() -> void:
	var sim: RefCounted = _s.sim
	var plan: Dictionary = SnAI.plan(sim, {"phase": _s.rules.phase, "free_ball": false, "in_hand": true, "break_off": true}, 2)
	var cue: Vector2 = plan.get("cue_at", sim.pos[Sim.CUE])
	var packed := Sim.pack(PackedFloat32Array([plan.dir.x, plan.dir.y, float(plan.speed), plan.tip.x, plan.tip.y, cue.x, cue.y]))
	var f := Sim.unpack(packed, 7)
	var theirs: RefCounted = sim.copy()
	theirs.pos[Sim.CUE] = Vector2(f[5], f[6])
	theirs.strike(Vector2(f[0], f[1]), f[2], Vector2(f[3], f[4]))
	theirs.settle()
	var referee := SnRules.new(theirs, 0)
	referee.from_dict(_s.rules.to_dict(), true)
	referee.judge()
	_their_table = {"table": theirs.snapshot(), "rules": referee.to_dict()}
	_fake().say_move({"shot": packed})
	_fake().to_act = 1  # the shot keeps the turn; their table passes it

## Plays checkers' line up to ply `until`, this seat's moves as if tapped and
## the other's as the match hands them on; true once the board has them all.
func _ck_line(until: int) -> bool:
	if _s.board.is_busy():
		return false
	if _ply >= until:
		return _s._history.size() >= until and _s._state != _s.State.ANIM
	if _s._history.size() != _ply:
		return false
	if _s._state == _s.State.YOURS and _ply % 2 == 0:
		_s._on_chosen(PackedInt32Array(CK_LINE[_ply]))
		_ply += 1
	elif _s._state == _s.State.THINK and _ply % 2 == 1:
		_fake().say_move({"m": CK_LINE[_ply]})
		_ply += 1
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
