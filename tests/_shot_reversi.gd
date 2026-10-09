extends SceneTree

## A game of Reversi, shot at fixed beats, the screen built by hand so
## nothing of the menu (or the network) is started:
##
##     caffeinate -d -i -u godot --path . --resolution 810x1440 --always-on-top --script res://tests/_shot_reversi.gd -- <outdir> [level] [rm] [lang=pt|es] [lose] [speed=N]
##
## The hand is real touches on the board: a finger put down on a square that
## may be played, let go; then a disc a turn on the square the best computer
## would pick (`lose`: on any square, so the end card is the lost one), the
## bulb once, a taken square tried once, Undo once. Shots: start, over (the
## finger down), turning, landed, hint, refused, back (a move taken back),
## pass (the first turn skipped, if one is), count, end, sweep (Play again
## clearing the board). After the first move the clock runs `speed` times as
## fast (3). Prints the draw calls at each and puts user://versus.cfg back.

const AI = preload("res://versus/reversi_ai.gd")
const Rules = preload("res://versus/reversi_rules.gd")

var _screen: Control
var _board: Control
var _t := 0.0
var _out := "/tmp"
var _level := 1
var _lose := false
var _speed := 3.0
var _step := 0
var _wait := 0.0
var _done := {}
var _rng := RandomNumberGenerator.new()
var _record_before := ""
var _had_record := false
var _undone := false
var _hinted := false
var _refused := false
var _first := -1
var _passes := 0
var _seen_ply := -1
var _peak := 0

func _initialize() -> void:
	_had_record = FileAccess.file_exists("user://versus.cfg")
	if _had_record:
		_record_before = FileAccess.get_file_as_string("user://versus.cfg")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	for a in args.slice(1):
		if a == "rm":
			load("res://core/motion.gd").reduce = true
		elif a == "lose":
			_lose = true
		elif a.begins_with("lang="):
			TranslationServer.set_locale(a.trim_prefix("lang="))
		elif a.begins_with("speed="):
			_speed = float(a.trim_prefix("speed="))
		elif a.is_valid_int():
			_level = int(a)
	_rng.seed = 4
	_screen = load("res://versus/reversi_screen.gd").new(_level)
	root.add_child(_screen)

func _restore() -> void:
	if _had_record:
		var f := FileAccess.open("user://versus.cfg", FileAccess.WRITE)
		f.store_string(_record_before)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://versus.cfg"))

func _shot(name: String) -> void:
	if _done.has(name):
		return
	_done[name] = true
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/rvs_%s.png" % [_out, name])
	print("shot %s at %.1f draws=%d state %d" % [name, _t, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _screen._state])

## The middle of a square, in the board's own points.
func _at(cell: int) -> Vector2:
	return _board.point_of(_board.mid(cell))

func _touch(at: Vector2, down: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = down
	ev.position = at
	_board._gui_input(ev)

func _process(delta: float) -> bool:
	_t += delta
	if _board == null:
		_board = _screen.board
		# The real pointer over the window must not set a disc.
		_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return false
	_peak = maxi(_peak, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	var S = _screen.State
	var r: RefCounted = _screen.rules
	if r.ply != _seen_ply:
		_seen_ply = r.ply
		if r.passed and not r.over:
			_passes += 1
			print("  a pass at ply ", r.ply, ": side ", r.turn, " moves again; said: ", _screen._toast_label.text)
	_wait -= delta
	if _wait > 0.0:
		return false
	match _step:
		0:
			if _screen._state == S.YOURS and _t > 1.8:
				_shot("start")
				_first = _pick()
				_touch(_at(_first), true)
				_step = 1
				_wait = 0.3
		1:
			_shot("over")
			_touch(_at(_first), false)
			_step = 2
			_wait = 0.3
		2:
			_shot("turning")
			_step = 3
			_wait = 0.6
		3:
			_shot("landed")
			Engine.time_scale = _speed
			_step = 4
		4:
			if _screen._state == S.YOURS:
				if _passes > 0:
					_shot("pass")
				if not _hinted and r.ply >= 4 and _level < 3:
					_hinted = true
					_screen._on_hint()
					_step = 5
					return false
				if not _refused and r.ply >= 6:
					_refused = true
					_touch(_at(Rules.cell(3, 3)), true)
					_step = 7
					_wait = 0.2
					return false
				if not _undone and r.ply >= 8 and _level < 3:
					_undone = true
					print("  undo: can ", _screen.can_undo(), " at ply ", r.ply, " discs ", r.count(0), "-", r.count(1))
					_screen._on_undo()
					_step = 6
					_wait = 0.12
					return false
				var cell := _pick()
				_touch(_at(cell), true)
				_touch(_at(cell), false)
				_wait = 0.1
			elif _screen._state == S.OVER:
				print("  over: status %d winner %d discs %d-%d ply %d passes %d, player %d" % [r.status(), r.winner(),
					r.count(0), r.count(1), r.ply, _passes, _screen.player])
				Engine.time_scale = 1.0
				_step = 8
				_wait = 0.9
		5:
			if _screen._hint_cell >= 0:
				_wait = 0.3
				_step = 51
		51:
			_shot("hint")
			_step = 4
		6:
			_shot("back")
			_step = 61
		61:
			if _screen._state == S.YOURS:
				print("  after undo: ply ", r.ply, " discs ", r.count(0), "-", r.count(1))
				_step = 4
		7:
			_shot("refused_down")
			var before: int = r.ply
			_touch(_at(Rules.cell(3, 3)), false)
			print("  refused: ply still ", r.ply == before, ", said: ", _screen._toast_label.text)
			_step = 71
			_wait = 0.25
		71:
			_shot("refused")
			_step = 4
			_wait = 0.3
		8:
			_shot("count")
			_step = 9
			_wait = 3.0
		9:
			_shot("end")
			if _screen._end != null and _screen.online == null:
				# Play again is the card's first button.
				(_screen._end.find_children("*", "Button", true, false)[0] as Button).pressed.emit()
			_step = 10
			_wait = 0.3
		10:
			_shot("sweep")
			_step = 11
			_wait = 1.2
		11:
			_shot("again")
			print("peak draws ", _peak)
			_restore()
			return true
	return false

func _pick() -> int:
	var r: RefCounted = _screen.rules
	if _lose:
		var open: PackedInt32Array = r.legal_moves()
		return open[_rng.randi() % open.size()]
	return AI.new().plan(r, 2, _rng.randi(), 80)
