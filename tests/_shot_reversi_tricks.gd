extends SceneTree

## Reversi's new parts through the screen, by real touches on the board:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --rendering-driver opengl3_angle --script res://tests/_shot_reversi_tricks.gd -- <outdir> [level]
##
## Level 0-2: a read under a finger (`read`), each trick from the row (`armed`,
## `stone`, `swipe`, `encore`), a game to its end card (`end`), the worst move
## tried again (`retry`), that run's record left alone. Level 4 (two on a
## phone): the turn passing between hands and the row following it. Prints PASS
## or FAIL lines, the draw calls, and puts user://versus.cfg back.

const Rules = preload("res://versus/reversi_rules.gd")
const AI = preload("res://versus/reversi_ai.gd")
const Record = preload("res://versus/versus_record.gd")
## The screen's states by number: preloading it here will not compile, the
## autoloads are not up yet.
const YOURS := 2

var _screen: Control
var _board: Control
var _out := "/tmp"
var _level := 1
var _cfg := ""
var _had := false
var _t := 0.0
var _wait := 0.6
var _step := "open"
var _shots := {}
var _fails := 0
var _record := Vector2i.ZERO

func _initialize() -> void:
	_had = FileAccess.file_exists("user://versus.cfg")
	if _had:
		_cfg = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_level = int(args[1])
	load("res://ui/hud/screen_tutor.gd").no_first_play = true
	_screen = load("res://versus/reversi_screen.gd").new(_level)
	root.add_child(_screen)
	Engine.time_scale = 2.0
	# Whatever happens, this window goes.
	create_timer(100.0, true, false, true).timeout.connect(func() -> void:
		_fails += 1
		print("FAIL ran out of time at step %s, state %d, ply %d, turn %d, task %d (%s), over %s, interactive %s, moves %s" % [_step, _screen._state,
			_screen.rules.ply, _screen.rules.turn, _screen._task, _screen._task_for, _screen.rules.over, _board.interactive, str(_screen.rules.legal_moves())])
		_finish())

func _ok(what: String, yes: bool) -> void:
	if not yes:
		_fails += 1
	print("%s %s" % ["PASS" if yes else "FAIL", what])

func _shot(name: String) -> void:
	if _shots.has(name):
		return
	_shots[name] = true
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/rt_%s.png" % [_out, name])
	print("shot %s draws=%d" % [name, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])

func _press(cell: int, on: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = on
	ev.position = _board.point_of(_board.mid(cell))
	_board._gui_input(ev)

func _tap(cell: int) -> void:
	_press(cell, true)
	_press(cell, false)

func _finish() -> void:
	Engine.time_scale = 1.0
	if _had:
		FileAccess.open("user://versus.cfg", FileAccess.WRITE).store_string(_cfg)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))
	print("FAILS %d" % _fails)
	quit(1 if _fails > 0 else 0)

## The worst square by the reads: one that hands over a corner if there is one.
func _bad_move(r: RefCounted) -> int:
	var moves: PackedInt32Array = r.legal_moves()
	for m in moves:
		if String(AI.read(r, m).kind) == "gives":
			return m
	return moves[0]

func _process(delta: float) -> bool:
	if _screen == null:
		# Never a window standing blank: a harness that cannot run leaves.
		print("FAIL the screen did not build")
		quit(1)
		return true
	if _board == null:
		# The screen builds in its _ready, a frame after this tree's start.
		_board = _screen.board
		if _board == null:
			return false
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t += delta
	if _t < _wait:
		return false
	_t = 0.0
	_wait = 0.25
	var r: RefCounted = _screen.rules
	var mine: bool = _screen._state == YOURS
	match _step:
		"open":
			if mine and r.ply >= Rules.TRICKS_FROM:
				_step = "local" if _level == 4 else "read"
			elif mine:
				var before: int = r.turn
				_tap(r.legal_moves()[0])
				if _level == 4:
					_ok("the hands take turns", _screen.rules.ply > 0 or before == r.turn)
		"local":
			_shot("local")
			_ok("two on a phone: no bulb, no undo", not _screen.can_undo() and _screen.hints_left() == 0)
			_ok("the row is the hand's to move", _screen._tricks.visible and not _screen._tricks.button(Rules.STONE).disabled)
			_finish()
		"read":
			var bad := _bad_move(r)
			_press(bad, true)
			_step = "read2"
		"read2":
			_shot("read")
			var c: int = _board._over
			_press(c, false)
			_board._over = -1
			_step = "stone_a"
			_wait = 1.8
		"stone_a":
			if mine:
				_screen._tricks.button(Rules.STONE).pressed.emit()
				_ok("the stone in hand", _board.armed == Rules.STONE)
				_step = "stone_b"
		"stone_b":
			_shot("armed")
			var at := -1
			for c in Rules.CELLS:
				if r.can_stone(c) and r.flips(c, r.turn).is_empty():
					at = c
					break
			_tap(at)
			_ok("a stone lies there", r.cells[at] == Rules.ROCK)
			_ok("and a turn is spent", r.turn != _screen.player or r.passed)
			_step = "swipe_a"
			_wait = 0.6
		"swipe_a":
			_shot("stone")
			if mine:
				_screen._tricks.button(Rules.SWIPE).pressed.emit()
				_step = "swipe_b"
		"swipe_b":
			var at := -1
			for c in Rules.CELLS:
				if r.can_swipe(c):
					at = c
					break
			var was: int = r.count(_screen.player)
			_tap(at)
			_ok("a disc swiped", r.count(_screen.player) == was + 1)
			_step = "encore_a"
			_wait = 0.6
		"encore_a":
			_shot("swipe")
			if mine:
				_screen._tricks.button(Rules.ENCORE).pressed.emit()
				_ok("an encore armed", r.encore_on)
				_tap(_bad_move(r))
				_step = "encore_b"
				_wait = 0.9
		"encore_b":
			_shot("encore")
			_ok("the turn is still yours", _screen._state == YOURS or r.over or r.passed)
			_step = "game"
		"game":
			if _screen._end != null:
				_shot("end")
				_ok("the end card offers the worst move", not _screen._worst_move().is_empty())
				_record = Record.get_record("reversi", _level)
				var m: Dictionary = _screen._worst_move()
				if m.is_empty():
					_finish()
					return false
				_screen._retry(m)
				_ok("back on that move", _screen.rules.cells == (m.before as RefCounted).cells and _screen._state == YOURS)
				_step = "retry"
				_wait = 0.5
			elif mine:
				_tap(_bad_move(r))
		"retry":
			_shot("retry")
			_step = "after"
		"after":
			if _screen._end != null:
				_ok("a retried game is not recorded", Record.get_record("reversi", _level) == _record)
				_shot("after")
				_finish()
			elif mine:
				_tap(_bad_move(r))
	return false
